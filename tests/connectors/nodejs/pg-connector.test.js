'use strict';

// Mock the pg driver so these regression tests run without a database server.
// These tests validate connector control flow only; PostgreSQL semantics, RLS,
// TLS handshakes, and concurrency still require integration tests on a real engine.
const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');

const originalLoad = Module._load;
const instances = [];

class FakeClient {
  constructor() {
    this.calls = [];
    this.releaseError = undefined;
    this.failOn = null;
    this.failRollback = false;
  }
  async query(text, params = []) {
    this.calls.push({ text, params });
    if (this.failOn && text === this.failOn) throw Object.assign(new Error('simulated query failure'), { code: 'XX000' });
    if (text === 'ROLLBACK' && this.failRollback) throw new Error('simulated rollback failure');
    return { rows: [{ ok: true }], rowCount: 1 };
  }
  release(error) { this.releaseError = error; }
}
class FakePool {
  constructor(config) {
    this.config = config;
    this.client = new FakeClient();
    this.totalCount = 1;
    this.idleCount = 1;
    this.waitingCount = 0;
    instances.push(this);
  }
  on() {}
  async connect() { return this.client; }
  async query() { return { rows: [{ server_time: new Date(), check: 1 }] }; }
  async end() {}
}
Module._load = function(request, parent, isMain) {
  if (request === 'pg') return { Pool: FakePool };
  return originalLoad.call(this, request, parent, isMain);
};
const { PostgresConnector } = require('../../../_infrastructure/connectors/nodejs/pg-connector.js');
Module._load = originalLoad;

function makeConnector() {
  return new PostgresConnector({
    pool: { host: 'localhost', port: 5432, database: 'test', user: 'test', password: 'test', max: 2 },
    statementTimeout: 1000,
    rateLimitPerMinute: 100,
  });
}

test('context values use parameterized transaction-local set_config and commit', async () => {
  const db = makeConnector();
  const result = await db.query('SELECT 1', [], { tenantId: 'tenant-a', userId: 'user-a' });
  const client = instances.at(-1).client;
  assert.equal(result.rowCount, 1);
  assert.ok(client.calls.some(c => c.text === 'SELECT set_config($1, $2, true)' && c.params[0] === 'app.current_tenant_id'));
  assert.ok(client.calls.some(c => c.text === 'COMMIT'));
  assert.equal(client.calls.some(c => c.text.startsWith('SET app.')), false);
  assert.equal(client.releaseError, undefined);
});

test('failed statement is attempted once and rolled back instead of blindly retried', async () => {
  const db = makeConnector();
  const pool = instances.at(-1);
  pool.client.failOn = 'UPDATE payments SET status = $1';
  await assert.rejects(db.query('UPDATE payments SET status = $1', ['paid'], { tenantId: 'tenant-a' }), /simulated query failure/);
  assert.equal(pool.client.calls.filter(c => c.text === 'UPDATE payments SET status = $1').length, 1);
  assert.ok(pool.client.calls.some(c => c.text === 'ROLLBACK'));
});

test('transaction callback failure rolls back and returns the original error', async () => {
  const db = makeConnector();
  const pool = instances.at(-1);
  await assert.rejects(db.transaction(async () => { throw new Error('business rule failed'); }, { tenantId: 'tenant-a' }), /business rule failed/);
  assert.ok(pool.client.calls.some(c => c.text === 'ROLLBACK'));
  assert.equal(pool.client.releaseError, undefined);
});

test('connection is discarded when rollback itself fails', async () => {
  const db = makeConnector();
  const pool = instances.at(-1);
  pool.client.failOn = 'UPDATE inventory SET quantity = $1';
  pool.client.failRollback = true;
  await assert.rejects(db.query('UPDATE inventory SET quantity = $1', [0], { tenantId: 'tenant-a' }), /simulated query failure/);
  assert.ok(pool.client.releaseError instanceof Error);
});
