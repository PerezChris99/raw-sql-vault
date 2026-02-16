"""
Raw SQL Vault - Production PostgreSQL Connector
Python 3.9+

Features:
- Connection pooling with PgBouncer support
- Automatic retry with exponential backoff
- Query parameterization (injection-safe)
- Rate limiting integration
- Context managers for transactions
- Health checks
- Async support
- TLS/SSL support
"""

import os
import time
import uuid
import logging
from typing import Any, Dict, List, Optional, Tuple, Union
from contextlib import contextmanager, asynccontextmanager
from dataclasses import dataclass, field
from functools import wraps
from collections import defaultdict
from datetime import datetime, timedelta

import psycopg2
from psycopg2 import pool, sql, extras
from psycopg2.extensions import connection as PgConnection

# Optional async support
try:
    import asyncpg
    ASYNC_AVAILABLE = True
except ImportError:
    ASYNC_AVAILABLE = False

logger = logging.getLogger(__name__)

# ============================================================================
# CONFIGURATION
# ============================================================================

@dataclass
class PoolConfig:
    """Database connection pool configuration."""
    host: str = "localhost"
    port: int = 5432
    database: str = "postgres"
    user: str = "app_service"
    password: str = ""
    min_connections: int = 2
    max_connections: int = 20
    connect_timeout: int = 10
    ssl_mode: str = "prefer"  # disable, prefer, require


@dataclass
class ConnectorConfig:
    """Full connector configuration."""
    pool: PoolConfig = field(default_factory=PoolConfig)
    retry_attempts: int = 3
    retry_delay_seconds: float = 1.0
    statement_timeout_ms: int = 30000
    enable_audit: bool = True
    rate_limit_per_minute: int = 100


# ============================================================================
# RATE LIMITER
# ============================================================================

class RateLimiter:
    """Simple in-memory rate limiter using sliding window."""
    
    def __init__(self, limit: int, window_seconds: int = 60):
        self.limit = limit
        self.window_seconds = window_seconds
        self.requests: Dict[str, List[float]] = defaultdict(list)
    
    def check(self, identifier: str) -> Tuple[bool, int]:
        """Check if request is allowed. Returns (allowed, remaining)."""
        now = time.time()
        window_start = now - self.window_seconds
        
        # Clean old requests
        self.requests[identifier] = [
            t for t in self.requests[identifier] if t > window_start
        ]
        
        if len(self.requests[identifier]) >= self.limit:
            return False, 0
        
        self.requests[identifier].append(now)
        return True, self.limit - len(self.requests[identifier])


# ============================================================================
# CONNECTOR CLASS (SYNC)
# ============================================================================

class PostgresConnector:
    """
    Production-ready PostgreSQL connector with security features.
    
    Usage:
        connector = PostgresConnector.create('refugee_aid_allocator')
        
        # Simple query (parameterized - safe from injection)
        result = connector.query(
            "SELECT * FROM refugees WHERE camp_id = %s",
            [camp_id]
        )
        
        # With context (for RLS)
        result = connector.query(
            "SELECT * FROM allocations",
            context={'tenant_id': 'org-123', 'user_id': 'user-456'}
        )
        
        # Transaction
        with connector.transaction() as cursor:
            cursor.execute("UPDATE allocations SET status = %s WHERE id = %s", ['approved', id])
            cursor.execute("INSERT INTO history (id, action) VALUES (%s, %s)", [id, 'approved'])
    """
    
    def __init__(self, config: ConnectorConfig):
        self.config = config
        self._pool: Optional[pool.ThreadedConnectionPool] = None
        self._rate_limiter = RateLimiter(config.rate_limit_per_minute)
    
    @classmethod
    def create(cls, project_name: str, **overrides) -> 'PostgresConnector':
        """Factory method to create connector from environment variables."""
        pool_config = PoolConfig(
            host=os.getenv('DB_HOST', 'localhost'),
            port=int(os.getenv('DB_PORT', '5432')),
            database=os.getenv('DB_NAME', project_name.replace('-', '_')),
            user=os.getenv('DB_USER', 'app_service'),
            password=os.getenv('DB_PASSWORD', ''),
            min_connections=int(os.getenv('DB_POOL_MIN', '2')),
            max_connections=int(os.getenv('DB_POOL_MAX', '20')),
            ssl_mode=os.getenv('DB_SSL_MODE', 'prefer'),
        )
        
        # Apply overrides
        for key, value in overrides.items():
            if hasattr(pool_config, key):
                setattr(pool_config, key, value)
        
        config = ConnectorConfig(pool=pool_config)
        return cls(config)
    
    # ========================================================================
    # CONNECTION POOL
    # ========================================================================
    
    def _get_pool(self) -> pool.ThreadedConnectionPool:
        """Get or create connection pool (lazy initialization)."""
        if self._pool is None:
            p = self.config.pool
            dsn = f"host={p.host} port={p.port} dbname={p.database} user={p.user} password={p.password} sslmode={p.ssl_mode} connect_timeout={p.connect_timeout}"
            
            self._pool = pool.ThreadedConnectionPool(
                minconn=p.min_connections,
                maxconn=p.max_connections,
                dsn=dsn,
                application_name='raw_sql_vault_app',
            )
        return self._pool
    
    @contextmanager
    def _get_connection(self, context: Optional[Dict[str, str]] = None):
        """Get connection from pool with context management."""
        conn = self._get_pool().getconn()
        try:
            # Set statement timeout
            with conn.cursor() as cur:
                cur.execute(f"SET statement_timeout = {self.config.statement_timeout_ms}")
                
                # Set RLS context
                if context:
                    if context.get('tenant_id'):
                        cur.execute("SET app.current_tenant_id = %s", [context['tenant_id']])
                    if context.get('user_id'):
                        cur.execute("SET app.current_user_id = %s", [context['user_id']])
                    if context.get('request_id'):
                        cur.execute("SET app.request_id = %s", [context['request_id']])
                    if context.get('roles'):
                        cur.execute("SET app.current_roles = %s", [','.join(context['roles'])])
                
                conn.commit()
            
            yield conn
        finally:
            self._get_pool().putconn(conn)
    
    # ========================================================================
    # QUERY EXECUTION
    # ========================================================================
    
    def query(
        self,
        sql_text: str,
        params: Optional[List[Any]] = None,
        context: Optional[Dict[str, str]] = None,
        fetch: str = 'all'  # 'all', 'one', 'none'
    ) -> Union[List[Dict], Dict, None]:
        """
        Execute a parameterized query (SAFE from SQL injection).
        
        Args:
            sql_text: SQL with %s placeholders
            params: List of parameter values
            context: Dict with tenant_id, user_id, roles for RLS
            fetch: 'all' for fetchall, 'one' for fetchone, 'none' for no fetch
        
        Returns:
            Query results as list of dicts or single dict
        """
        # Rate limiting
        identifier = context.get('user_id', 'anonymous') if context else 'anonymous'
        allowed, remaining = self._rate_limiter.check(identifier)
        if not allowed:
            raise Exception(f"Rate limit exceeded. Try again later.")
        
        # Execute with retry
        return self._execute_with_retry(sql_text, params, context, fetch)
    
    def _execute_with_retry(
        self,
        sql_text: str,
        params: Optional[List[Any]],
        context: Optional[Dict[str, str]],
        fetch: str,
        attempt: int = 1
    ) -> Union[List[Dict], Dict, None]:
        """Execute query with automatic retry on transient errors."""
        try:
            with self._get_connection(context) as conn:
                with conn.cursor(cursor_factory=extras.RealDictCursor) as cur:
                    cur.execute(sql_text, params)
                    
                    if fetch == 'all':
                        result = cur.fetchall()
                        return [dict(row) for row in result]
                    elif fetch == 'one':
                        row = cur.fetchone()
                        return dict(row) if row else None
                    else:
                        conn.commit()
                        return None
                        
        except psycopg2.OperationalError as e:
            # Retry on transient errors
            if attempt < self.config.retry_attempts:
                delay = self.config.retry_delay_seconds * (2 ** (attempt - 1))
                logger.warning(f"Query failed (attempt {attempt}), retrying in {delay}s: {e}")
                time.sleep(delay)
                return self._execute_with_retry(sql_text, params, context, fetch, attempt + 1)
            raise
    
    # ========================================================================
    # TRANSACTIONS
    # ========================================================================
    
    @contextmanager
    def transaction(self, context: Optional[Dict[str, str]] = None):
        """
        Context manager for transactions with automatic commit/rollback.
        
        Usage:
            with connector.transaction() as cursor:
                cursor.execute("UPDATE ...", params)
                cursor.execute("INSERT ...", params)
        """
        with self._get_connection(context) as conn:
            try:
                with conn.cursor(cursor_factory=extras.RealDictCursor) as cur:
                    yield cur
                conn.commit()
            except Exception:
                conn.rollback()
                raise
    
    # ========================================================================
    # BULK OPERATIONS
    # ========================================================================
    
    def bulk_insert(
        self,
        table: str,
        columns: List[str],
        rows: List[Tuple],
        context: Optional[Dict[str, str]] = None
    ) -> int:
        """
        Efficient bulk insert using execute_values.
        
        Args:
            table: Table name (will be safely quoted)
            columns: List of column names
            rows: List of tuples with values
            context: RLS context
        
        Returns:
            Number of rows inserted
        """
        if not rows:
            return 0
        
        with self._get_connection(context) as conn:
            with conn.cursor() as cur:
                # Safely construct column list
                cols = sql.SQL(',').join(sql.Identifier(c) for c in columns)
                query = sql.SQL("INSERT INTO {} ({}) VALUES %s").format(
                    sql.Identifier(table),
                    cols
                )
                
                extras.execute_values(cur, query.as_string(conn), rows)
                conn.commit()
                return cur.rowcount
    
    # ========================================================================
    # HEALTH CHECK
    # ========================================================================
    
    def health_check(self) -> Dict[str, Any]:
        """Check database connectivity and return health status."""
        start = time.time()
        try:
            result = self.query("SELECT 1 as check, NOW() as server_time", fetch='one')
            latency_ms = (time.time() - start) * 1000
            
            return {
                'healthy': True,
                'latency_ms': round(latency_ms, 2),
                'server_time': result['server_time'].isoformat() if result else None,
                'pool_size': self._pool._maxconn if self._pool else 0,
            }
        except Exception as e:
            return {
                'healthy': False,
                'latency_ms': (time.time() - start) * 1000,
                'error': str(e),
            }
    
    # ========================================================================
    # CLEANUP
    # ========================================================================
    
    def close(self):
        """Close all connections in the pool."""
        if self._pool:
            self._pool.closeall()
            self._pool = None
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
    
    # ========================================================================
    # UTILITIES
    # ========================================================================
    
    @staticmethod
    def generate_request_id() -> str:
        """Generate a unique request ID for tracing."""
        return str(uuid.uuid4())


# ============================================================================
# ASYNC CONNECTOR (if asyncpg available)
# ============================================================================

if ASYNC_AVAILABLE:
    class AsyncPostgresConnector:
        """Async version of PostgresConnector using asyncpg."""
        
        def __init__(self, config: ConnectorConfig):
            self.config = config
            self._pool: Optional[asyncpg.Pool] = None
            self._rate_limiter = RateLimiter(config.rate_limit_per_minute)
        
        @classmethod
        async def create(cls, project_name: str, **overrides) -> 'AsyncPostgresConnector':
            """Factory method for async connector."""
            pool_config = PoolConfig(
                host=os.getenv('DB_HOST', 'localhost'),
                port=int(os.getenv('DB_PORT', '5432')),
                database=os.getenv('DB_NAME', project_name.replace('-', '_')),
                user=os.getenv('DB_USER', 'app_service'),
                password=os.getenv('DB_PASSWORD', ''),
                min_connections=int(os.getenv('DB_POOL_MIN', '2')),
                max_connections=int(os.getenv('DB_POOL_MAX', '20')),
            )
            
            for key, value in overrides.items():
                if hasattr(pool_config, key):
                    setattr(pool_config, key, value)
            
            config = ConnectorConfig(pool=pool_config)
            connector = cls(config)
            await connector._init_pool()
            return connector
        
        async def _init_pool(self):
            """Initialize the connection pool."""
            p = self.config.pool
            self._pool = await asyncpg.create_pool(
                host=p.host,
                port=p.port,
                database=p.database,
                user=p.user,
                password=p.password,
                min_size=p.min_connections,
                max_size=p.max_connections,
                command_timeout=self.config.statement_timeout_ms / 1000,
            )
        
        async def query(
            self,
            sql_text: str,
            params: Optional[List[Any]] = None,
            context: Optional[Dict[str, str]] = None,
        ) -> List[Dict]:
            """Execute async query with parameters."""
            if not self._pool:
                raise Exception("Pool not initialized")
            
            async with self._pool.acquire() as conn:
                # Set context
                if context:
                    if context.get('tenant_id'):
                        await conn.execute("SET app.current_tenant_id = $1", context['tenant_id'])
                    if context.get('user_id'):
                        await conn.execute("SET app.current_user_id = $1", context['user_id'])
                
                # Execute
                rows = await conn.fetch(sql_text, *(params or []))
                return [dict(row) for row in rows]
        
        @asynccontextmanager
        async def transaction(self, context: Optional[Dict[str, str]] = None):
            """Async transaction context manager."""
            async with self._pool.acquire() as conn:
                async with conn.transaction():
                    yield conn
        
        async def close(self):
            """Close the pool."""
            if self._pool:
                await self._pool.close()


# ============================================================================
# USAGE EXAMPLE
# ============================================================================

if __name__ == '__main__':
    # Sync example
    with PostgresConnector.create('refugee_aid_allocator') as db:
        # Health check
        health = db.health_check()
        print(f"Database healthy: {health['healthy']}")
        
        # Query with RLS context
        # refugees = db.query(
        #     "SELECT * FROM refugees WHERE status = %s LIMIT 10",
        #     ['active'],
        #     context={'tenant_id': 'org-123', 'user_id': 'user-456'}
        # )
        
        # Transaction
        # with db.transaction() as cur:
        #     cur.execute("UPDATE allocations SET status = %s WHERE id = %s", ['approved', 1])
