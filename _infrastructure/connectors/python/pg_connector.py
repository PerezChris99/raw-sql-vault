"""
Raw SQL Vault - PostgreSQL Connector Reference Implementation
Python 3.9+

Features:
- Connection pooling with PgBouncer support
- Explicit transaction boundaries and transaction-local request context
- Parameterized query values (when used correctly)
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
import ssl as ssl_module
import threading
from typing import Any, Dict, List, Optional, Tuple, Union
from contextlib import contextmanager, asynccontextmanager
from dataclasses import dataclass, field
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
    # Secure by default: verify the server certificate and hostname.
    # Local development must explicitly choose disable/require only when appropriate.
    ssl_mode: str = "verify-full"


@dataclass
class ConnectorConfig:
    """Full connector configuration."""
    pool: PoolConfig = field(default_factory=PoolConfig)
    # Deprecated compatibility fields. Arbitrary statements are never auto-retried.
    retry_attempts: int = 3
    retry_delay_seconds: float = 1.0
    statement_timeout_ms: int = 30000
    # Reserved for compatibility; this connector does not implement an audit sink.
    enable_audit: bool = False
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
        self._checks = 0
        self._lock = threading.Lock()
    
    def check(self, identifier: str) -> Tuple[bool, int]:
        """Check a sliding-window limit safely across threads in this process.

        Plain language: concurrent requests cannot all pass the same last slot
        because the counter update is protected by a lock. This still is not a
        distributed limit across multiple worker processes or hosts.
        """
        with self._lock:
            now = time.time()
            window_start = now - self.window_seconds

            # Bound memory under high-cardinality identifiers. An unbounded map can
            # turn a simple rate limiter into a memory-exhaustion vector.
            self._checks += 1
            if self._checks % 100 == 0:
                for key in list(self.requests):
                    if not any(t > window_start for t in self.requests[key]):
                        self.requests.pop(key, None)
            if identifier not in self.requests and len(self.requests) >= 10000:
                # Evict one oldest-insertion entry before adding a new identity.
                # This bounds memory but is not a distributed rate-limit policy.
                self.requests.pop(next(iter(self.requests)), None)
            self.requests[identifier] = [
                t for t in self.requests.get(identifier, []) if t > window_start
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
    Reference PostgreSQL connector with bounded resource controls and safe defaults.

    It is not a complete authorization layer, distributed rate limiter, audit service,
    or production operations platform. Deployment-specific verification is mandatory.
    
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
        self._pool_lock = threading.Lock()
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
            ssl_mode=os.getenv('DB_SSL_MODE', 'verify-full'),
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
        """Create one pool safely even when several threads start together.

        Plain language: two first requests arriving at once must not each create
        a separate pool and silently exceed the intended connection budget.
        Technical: a lock and second check serialize lazy initialization.
        """
        if self._pool is None:
            with self._pool_lock:
                if self._pool is None:
                    p = self.config.pool
                    if p.min_connections < 1 or p.max_connections < p.min_connections:
                        raise ValueError("Pool bounds must satisfy 1 <= min_connections <= max_connections.")
                    if p.connect_timeout < 1:
                        raise ValueError("connect_timeout must be positive.")
                    allowed_ssl_modes = {"disable", "allow", "prefer", "require", "verify-ca", "verify-full"}
                    if p.ssl_mode not in allowed_ssl_modes:
                        raise ValueError(f"Unsupported ssl_mode: {p.ssl_mode}")
                    environment = os.getenv("APP_ENV", os.getenv("ENVIRONMENT", "")).lower()
                    if environment == "production" and p.ssl_mode not in {"verify-ca", "verify-full"}:
                        raise ValueError("Production requires DB_SSL_MODE=verify-ca or verify-full.")
                    self._pool = pool.ThreadedConnectionPool(
                        minconn=p.min_connections,
                        maxconn=p.max_connections,
                        host=p.host,
                        port=p.port,
                        dbname=p.database,
                        user=p.user,
                        password=p.password,
                        sslmode=p.ssl_mode,
                        connect_timeout=p.connect_timeout,
                        application_name="raw_sql_vault_app",
                    )
        return self._pool

    @contextmanager
    def _get_connection(self, context: Optional[Dict[str, Any]] = None):
        """Borrow a connection and scope all settings to one transaction.

        Plain language: a connection is shared infrastructure. We set request
        context only while this request's transaction is open, commit on success,
        roll back on failure, and always return a clean connection to the pool.

        Technical: set_config(..., true) is transaction-local. The custom settings
        are trusted only when supplied by a trusted application backend; they do
        not authenticate direct SQL callers and must not carry client-chosen roles.
        """
        conn = self._get_pool().getconn()
        discarded = False
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT set_config('statement_timeout', %s, true)", [f"{self.config.statement_timeout_ms}ms"])
                if context:
                    context_values = (
                        ("app.current_tenant_id", context.get("tenant_id")),
                        ("app.current_user_id", context.get("user_id")),
                        ("app.request_id", context.get("request_id")),
                    )
                    for setting, value in context_values:
                        if value is not None:
                            cur.execute("SELECT set_config(%s, %s, true)", [setting, str(value)])
                # Do not accept context['roles']; authorization must come from
                # database-authenticated roles, not caller-controlled session text.
            yield conn
            conn.commit()
        except Exception:
            try:
                conn.rollback()
            except Exception:
                logger.exception("Rollback failed while returning a PostgreSQL connection.")
                try:
                    discarded = True
                    self._get_pool().putconn(conn, close=True)
                except Exception:
                    logger.exception("Failed to discard a connection after rollback failure.")
                raise
            raise
        finally:
            # psycopg2's pool resets transaction state on return; commit/rollback
            # above ensures the connection is not returned with an open transaction.
            if not discarded and not conn.closed:
                try:
                    self._get_pool().putconn(conn)
                except Exception:
                    logger.exception("Failed to return PostgreSQL connection to the pool.")

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
        Execute a parameterized query.

        Parameter binding protects values when used correctly; it does not make
        interpolated SQL fragments or dynamic identifiers safe.
        
        Args:
            sql_text: SQL with %s placeholders
            params: List of parameter values
            context: Trusted backend context with tenant_id, user_id, and request_id
            fetch: 'all' for fetchall, 'one' for fetchone, 'none' for no fetch
        
        Returns:
            Query results as list of dicts or single dict
        """
        # Rate limiting
        identifier = context.get('user_id', 'anonymous') if context else 'anonymous'
        allowed, remaining = self._rate_limiter.check(identifier)
        if not allowed:
            raise Exception(f"Rate limit exceeded. Try again later.")
        
        # Execute once. Automatic arbitrary-statement retries can duplicate writes.
        return self._execute_once(sql_text, params, context, fetch)
    
    def _execute_once(
        self,
        sql_text: str,
        params: Optional[List[Any]],
        context: Optional[Dict[str, Any]],
        fetch: str,
    ) -> Union[List[Dict], Dict, None]:
        """Execute once; never blindly replay arbitrary SQL after an error.

        Plain language: if a connection drops after a write, we may not know
        whether the server committed it. Repeating the statement can duplicate
        a payment, booking, or allocation. Retry only an explicitly idempotent
        whole transaction after classifying the database error and side effects.
        """
        with self._get_connection(context) as conn:
            with conn.cursor(cursor_factory=extras.RealDictCursor) as cur:
                cur.execute(sql_text, params)
                if fetch == 'all':
                    return [dict(row) for row in cur.fetchall()]
                if fetch == 'one':
                    row = cur.fetchone()
                    return dict(row) if row else None
                if fetch == 'none':
                    return None
                raise ValueError("fetch must be 'all', 'one', or 'none'.")

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
            with conn.cursor(cursor_factory=extras.RealDictCursor) as cur:
                yield cur
    
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
        with self._pool_lock:
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
            environment = os.getenv("APP_ENV", os.getenv("ENVIRONMENT", "")).lower()
            if environment == "production" and p.ssl_mode not in {"verify-ca", "verify-full"}:
                raise ValueError("Production async connections require verified TLS.")
            if p.ssl_mode not in {"disable", "allow", "prefer", "require", "verify-ca", "verify-full"}:
                raise ValueError(f"Unsupported ssl_mode: {p.ssl_mode}")
            # asyncpg accepts an SSLContext, not libpq's sslmode string. Use Python's
            # certificate store and hostname verification for verify-full.
            if p.ssl_mode == "disable":
                ssl_context = False
            elif p.ssl_mode == "verify-full":
                ssl_context = ssl_module.create_default_context()
            elif p.ssl_mode in {"verify-ca", "require"}:
                ssl_context = ssl_module.create_default_context()
                ssl_context.check_hostname = False
            else:
                ssl_context = True
            self._pool = await asyncpg.create_pool(
                host=p.host,
                port=p.port,
                database=p.database,
                user=p.user,
                password=p.password,
                ssl=ssl_context,
                min_size=p.min_connections,
                max_size=p.max_connections,
                command_timeout=self.config.statement_timeout_ms / 1000,
            )
        
        async def query(
            self,
            sql_text: str,
            params: Optional[List[Any]] = None,
            context: Optional[Dict[str, Any]] = None,
        ) -> List[Dict]:
            """Execute once with transaction-local context and safe cleanup.

            Plain language: request context is removed automatically at transaction
            end, so the next pooled borrower cannot inherit the previous tenant.
            """
            if not self._pool:
                raise RuntimeError("Pool not initialized")
            async with self._pool.acquire() as conn:
                async with conn.transaction():
                    if context:
                        for setting, value in (
                            ("app.current_tenant_id", context.get("tenant_id")),
                            ("app.current_user_id", context.get("user_id")),
                            ("app.request_id", context.get("request_id")),
                        ):
                            if value is not None:
                                await conn.fetchval("SELECT set_config($1, $2, true)", setting, str(value))
                    rows = await conn.fetch(sql_text, *(params or []))
                    return [dict(row) for row in rows]

        @asynccontextmanager
        async def transaction(self, context: Optional[Dict[str, Any]] = None):
            """Yield a transaction with trusted, transaction-local request context."""
            if not self._pool:
                raise RuntimeError("Pool not initialized")
            async with self._pool.acquire() as conn:
                async with conn.transaction():
                    if context:
                        for setting, value in (
                            ("app.current_tenant_id", context.get("tenant_id")),
                            ("app.current_user_id", context.get("user_id")),
                            ("app.request_id", context.get("request_id")),
                        ):
                            if value is not None:
                                await conn.fetchval("SELECT set_config($1, $2, true)", setting, str(value))
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
