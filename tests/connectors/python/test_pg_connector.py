"""Dependency-free regression tests for the Python PostgreSQL connector.

The fake psycopg2 driver validates connector control flow. It does not prove
PostgreSQL RLS semantics, network TLS handshakes, or actual driver behaviour.
"""
from __future__ import annotations

import importlib.util
import sys
import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from types import ModuleType

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "_infrastructure" / "connectors" / "python" / "pg_connector.py"


class FakeCursor:
    def __init__(self, connection, cursor_factory=None):
        self.connection = connection
        self.cursor_factory = cursor_factory
        self.rowcount = 1

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def execute(self, statement, params=None):
        self.connection.calls.append((statement, params))
        if self.connection.fail_on == statement:
            raise RuntimeError("simulated query failure")

    def fetchall(self):
        return [{"ok": True}]

    def fetchone(self):
        return {"check": 1, "server_time": datetime.now(timezone.utc)}


class FakeConnection:
    def __init__(self):
        self.calls = []
        self.commits = 0
        self.rollbacks = 0
        self.closed = 0
        self.fail_on = None
        self.fail_rollback = False

    def cursor(self, cursor_factory=None):
        return FakeCursor(self, cursor_factory)

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1
        if self.fail_rollback:
            raise RuntimeError("simulated rollback failure")


class FakeThreadedConnectionPool:
    creations = 0
    creation_lock = threading.Lock()
    last_kwargs = None

    def __init__(self, minconn, maxconn, **kwargs):
        with self.creation_lock:
            type(self).creations += 1
            type(self).last_kwargs = {"minconn": minconn, "maxconn": maxconn, **kwargs}
        self.connection = FakeConnection()
        self.returned = []
        self.closed = False

    def getconn(self):
        return self.connection

    def putconn(self, conn, close=False):
        self.returned.append((conn, close))
        if close:
            conn.closed = 1

    def closeall(self):
        self.closed = True


class FakeSqlFragment:
    def __init__(self, value=""):
        self.value = value

    def format(self, *args, **kwargs):
        return self

    def as_string(self, connection):
        return self.value


def load_connector():
    # Inject a small fake driver before importing the module. This keeps tests
    # runnable without installing psycopg2 or connecting to a database.
    psycopg2 = ModuleType("psycopg2")
    pool_module = ModuleType("psycopg2.pool")
    pool_module.ThreadedConnectionPool = FakeThreadedConnectionPool
    extras_module = ModuleType("psycopg2.extras")
    extras_module.RealDictCursor = object
    extras_module.execute_values = lambda cursor, query, rows: cursor.execute(query, rows)
    sql_module = ModuleType("psycopg2.sql")
    sql_module.SQL = lambda value: FakeSqlFragment(value)
    sql_module.Identifier = lambda value: FakeSqlFragment(str(value))
    sql_module.SQL.join = lambda self, values: FakeSqlFragment(",").join(values)
    extensions_module = ModuleType("psycopg2.extensions")
    extensions_module.connection = FakeConnection
    psycopg2.pool = pool_module
    psycopg2.extras = extras_module
    psycopg2.sql = sql_module
    psycopg2.OperationalError = type("OperationalError", (Exception,), {})
    psycopg2.extensions = extensions_module
    sys.modules.update({
        "psycopg2": psycopg2,
        "psycopg2.pool": pool_module,
        "psycopg2.extras": extras_module,
        "psycopg2.sql": sql_module,
        "psycopg2.extensions": extensions_module,
    })

    spec = importlib.util.spec_from_file_location("raw_sql_vault_pg_connector_under_test", SOURCE)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


CONNECTOR_MODULE = load_connector()


class PythonConnectorRegressionTests(unittest.TestCase):
    def setUp(self):
        FakeThreadedConnectionPool.creations = 0
        FakeThreadedConnectionPool.last_kwargs = None
        self.db = CONNECTOR_MODULE.PostgresConnector(
            CONNECTOR_MODULE.ConnectorConfig(
                pool=CONNECTOR_MODULE.PoolConfig(
                    host="localhost",
                    database="test_db",
                    user="test_user",
                    password="quote ' and space",
                    min_connections=1,
                    max_connections=4,
                    ssl_mode="verify-full",
                ),
                rate_limit_per_minute=100,
            )
        )

    def test_context_is_parameterized_and_transaction_local(self):
        result = self.db.query(
            "SELECT 1",
            context={"tenant_id": "tenant-a", "user_id": "user-a"},
            fetch="all",
        )
        conn = self.db._pool.connection
        self.assertEqual(result, [{"ok": True}])
        self.assertTrue(any(
            sql_text == "SELECT set_config(%s, %s, true)"
            and params[0] == "app.current_tenant_id"
            for sql_text, params in conn.calls
        ))
        self.assertEqual(conn.commits, 1)
        self.assertEqual(conn.rollbacks, 0)

    def test_failed_statement_is_not_retried_and_is_rolled_back(self):
        pool = self.db._get_pool()
        pool.connection.fail_on = "UPDATE payments SET status = %s"
        with self.assertRaisesRegex(RuntimeError, "simulated query failure"):
            self.db.query("UPDATE payments SET status = %s", ["paid"], {"tenant_id": "tenant-a"}, fetch="none")
        self.assertEqual(
            sum(sql_text == "UPDATE payments SET status = %s" for sql_text, _ in pool.connection.calls),
            1,
        )
        self.assertEqual(pool.connection.rollbacks, 1)

    def test_connection_parameters_are_structured_not_interpolated(self):
        self.db._get_pool()
        kwargs = FakeThreadedConnectionPool.last_kwargs
        self.assertNotIn("dsn", kwargs)
        self.assertEqual(kwargs["password"], "quote ' and space")
        self.assertEqual(kwargs["sslmode"], "verify-full")

    def test_concurrent_first_use_creates_only_one_pool(self):
        with ThreadPoolExecutor(max_workers=8) as executor:
            pools = list(executor.map(lambda _: self.db._get_pool(), range(32)))
        self.assertTrue(all(item is pools[0] for item in pools))
        self.assertEqual(FakeThreadedConnectionPool.creations, 1)

    def test_rate_limiter_is_thread_safe_for_one_process(self):
        limiter = CONNECTOR_MODULE.RateLimiter(limit=5)
        with ThreadPoolExecutor(max_workers=16) as executor:
            results = list(executor.map(lambda _: limiter.check("same-user")[0], range(50)))
        self.assertEqual(sum(results), 5)

    def test_tls_defaults_to_hostname_verification(self):
        self.assertEqual(CONNECTOR_MODULE.PoolConfig().ssl_mode, "verify-full")


if __name__ == "__main__":
    unittest.main()
