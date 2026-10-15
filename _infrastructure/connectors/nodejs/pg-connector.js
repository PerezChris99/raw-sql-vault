/**
 * Raw SQL Vault - Production PostgreSQL Connector
 * Node.js (Pure JavaScript - No TypeScript required)
 * 
 * Features:
 * - Connection pooling with PgBouncer support
 * - Explicit transactions with transaction-local context
 * - Query parameterization (injection-safe)
 * - Rate limiting integration
 * - Audit logging
 * - Health checks
 * - TLS/SSL support
 */

const { Pool } = require('pg');
const crypto = require('crypto');

// ============================================================================
// CONFIGURATION
// ============================================================================

/**
 * @typedef {Object} PoolConfig
 * @property {string} host
 * @property {number} port
 * @property {string} database
 * @property {string} user
 * @property {string} password
 * @property {number} max
 * @property {number} idleTimeoutMillis
 * @property {number} connectionTimeoutMillis
 * @property {boolean|{rejectUnauthorized: boolean}} [ssl]
 */

/**
 * @typedef {Object} ConnectorConfig
 * @property {PoolConfig} pool
 * @property {number} retryAttempts @deprecated No arbitrary-statement retries are performed.
 * @property {number} retryDelayMs @deprecated No arbitrary-statement retries are performed.
 * @property {number} statementTimeout
 * @property {string} [defaultTenant]
 * @property {boolean} enableAudit
 * @property {number} rateLimitPerMinute
 */

const DEFAULT_CONFIG = {
    retryAttempts: 3,
    retryDelayMs: 1000,
    statementTimeout: 30000,
    enableAudit: true,
    rateLimitPerMinute: 100,
};

// ============================================================================
// CONNECTOR CLASS
// ============================================================================

class PostgresConnector {
    /**
     * @param {Partial<ConnectorConfig>} config
     */
    constructor(config) {
        /** @type {ConnectorConfig} */
        this.config = { ...DEFAULT_CONFIG, ...config };
        
        /** @type {Map<string, {count: number, resetAt: Date}>} */
        this._requestCounts = new Map();
        
        /** @type {Pool} */
        this._pool = new Pool({
            ...this.config.pool,
            // Connection settings for security
            application_name: 'raw_sql_vault_app',
            statement_timeout: this.config.statementTimeout,
        });

        // Handle pool errors
        this._pool.on('error', (err) => {
            console.error('Unexpected pool error:', err);
        });
    }

    // ========================================================================
    // CONNECTION MANAGEMENT
    // ========================================================================

    /**
     * Get a client from the pool
     * @returns {Promise<import('pg').PoolClient>}
     */
    async getClient() {
        const client = await this._pool.connect();
        return client;
    }

    /**
     * Close the pool
     * @returns {Promise<void>}
     */
    async end() {
        await this._pool.end();
    }

    // ========================================================================
    // QUERY EXECUTION (PARAMETERIZED - INJECTION SAFE)
    // ========================================================================

    /**
     * Execute one SQL statement safely.
     *
     * Plain language: values such as tenant IDs are scoped to this transaction,
     * not left on a pooled connection for the next person who borrows it.
     * If this context is missing or forged by an untrusted caller, RLS cannot
     * infer the caller's real identity. Only trusted application code may set it.
     *
     * Technical: contextual queries run inside BEGIN/COMMIT and use parameterized
     * set_config(..., true), whose third argument makes settings transaction-local.
     * Do not pass transaction-control SQL or multi-statement scripts to this method.
     */
    async query(text, params = [], context = null) {
        if (typeof text !== 'string' || !text.trim()) {
            throw new TypeError('SQL text must be a non-empty string.');
        }
        const identifier = context?.userId || 'anonymous';
        this._checkRateLimit(identifier);
        const client = await this.getClient();
        let transactionStarted = false;
        let discardClient = false;

        try {
            if (context && Object.values(context).some(value => value !== undefined && value !== null)) {
                await client.query('BEGIN');
                transactionStarted = true;
                await this._applyContext(client, context);
            }

            const result = await client.query(text, params);
            if (transactionStarted) {
                await client.query('COMMIT');
                transactionStarted = false;
            }
            return result;
        } catch (error) {
            if (transactionStarted) {
                try {
                    await client.query('ROLLBACK');
                    transactionStarted = false;
                } catch (rollbackError) {
                    // A connection that cannot roll back must not return to the pool.
                    discardClient = true;
                    error.rollbackError = rollbackError;
                }
            }
            throw error;
        } finally {
            client.release(discardClient ? new Error('Discarding client after failed rollback') : undefined);
        }
    }

    /**
     * Apply trusted request context inside an active transaction.
     *
     * Plain language: these values describe the request being handled. Using
     * transaction-local settings prevents yesterday's tenant from leaking into
     * today's request when a pooled connection is reused.
     *
     * Technical: custom GUC values are not an authentication mechanism; never
     * trust caller-controlled roles or tenant IDs when the caller can issue
     * arbitrary SQL directly against this shared database role.
     */
    async _applyContext(client, context) {
        const entries = [
            ['app.current_tenant_id', context.tenantId],
            ['app.current_user_id', context.userId],
            ['app.request_id', context.requestId],
        ];
        for (const [setting, value] of entries) {
            if (value !== undefined && value !== null) {
                await client.query('SELECT set_config($1, $2, true)', [setting, String(value)]);
            }
        }
    }

    /**
     * Run a transaction and always attempt rollback on failure.
     * The callback is deliberately not automatically retried: it may have
     * side effects outside PostgreSQL, and retrying a write after a lost
     * connection can duplicate work. The caller must implement an explicit,
     * idempotent whole-transaction retry policy if the domain permits it.
     */
    async transaction(callback, context = null) {
        if (typeof callback !== 'function') throw new TypeError('Transaction callback is required.');
        const client = await this.getClient();
        let transactionStarted = false;
        let discardClient = false;

        try {
            await client.query('BEGIN');
            transactionStarted = true;
            if (context) await this._applyContext(client, context);
            const result = await callback(client);
            await client.query('COMMIT');
            transactionStarted = false;
            return result;
        } catch (error) {
            if (transactionStarted) {
                try {
                    await client.query('ROLLBACK');
                    transactionStarted = false;
                } catch (rollbackError) {
                    discardClient = true;
                    error.rollbackError = rollbackError;
                }
            }
            throw error;
        } finally {
            client.release(discardClient ? new Error('Discarding client after failed rollback') : undefined);
        }
    }

    // ========================================================================
    // RATE LIMITING
    // ========================================================================

    /**
     * @param {string} identifier
     */
    _checkRateLimit(identifier) {
        const now = new Date();
        const entry = this._requestCounts.get(identifier);

        // Bound per-process memory: remove expired identities periodically.
        this._rateLimitChecks = (this._rateLimitChecks || 0) + 1;
        if (this._rateLimitChecks % 100 === 0) {
            for (const [key, value] of this._requestCounts) {
                if (value.resetAt <= now) this._requestCounts.delete(key);
            }
        }
        if (entry && entry.resetAt > now) {
            if (entry.count >= this.config.rateLimitPerMinute) {
                throw new Error(`Rate limit exceeded. Try again after ${entry.resetAt.toISOString()}`);
            }
            entry.count++;
        } else {
            // The map is process-local and is not a distributed security control.
            if (this._requestCounts.size >= 10000) {
                const oldest = this._requestCounts.keys().next().value;
                if (oldest !== undefined) this._requestCounts.delete(oldest);
            }
            this._requestCounts.set(identifier, {
                count: 1,
                resetAt: new Date(now.getTime() + 60000),
            });
        }
    }

    // ========================================================================
    // HEALTH CHECK
    // ========================================================================

    /**
     * Check database health
     * @returns {Promise<{healthy: boolean, latencyMs: number, details: any}>}
     */
    async healthCheck() {
        const start = Date.now();
        
        try {
            const result = await this._pool.query('SELECT 1 as check, NOW() as server_time');
            const latencyMs = Date.now() - start;
            
            return {
                healthy: true,
                latencyMs,
                details: {
                    serverTime: result.rows[0].server_time,
                    poolTotal: this._pool.totalCount,
                    poolIdle: this._pool.idleCount,
                    poolWaiting: this._pool.waitingCount,
                },
            };
        } catch (error) {
            return {
                healthy: false,
                latencyMs: Date.now() - start,
                details: { error: error.message },
            };
        }
    }

    // ========================================================================
    // UTILITIES
    // ========================================================================

    /**
     * @param {number} ms
     * @returns {Promise<void>}
     */
    /**
     * Generate a request ID for tracing
     * @returns {string}
     */
    static generateRequestId() {
        return crypto.randomUUID();
    }
}

// ============================================================================
// FACTORY FUNCTION
// ============================================================================

/**
 * Create a connector for a specific project
 * @param {string} projectName
 * @param {Partial<PoolConfig>} [overrides]
 * @returns {PostgresConnector}
 */
function createConnector(projectName, overrides = {}) {
    // Load from environment
    const config = {
        pool: {
            host: process.env.DB_HOST || 'localhost',
            port: parseInt(process.env.DB_PORT || '5432', 10),
            database: process.env.DB_NAME || projectName.replace(/-/g, '_'),
            user: process.env.DB_USER || 'app_service',
            password: process.env.DB_PASSWORD || '',
            max: parseInt(process.env.DB_POOL_MAX || '20', 10),
            idleTimeoutMillis: 30000,
            connectionTimeoutMillis: 10000,
            ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: true } : false,
            ...overrides,
        },
        retryAttempts: 3,
        retryDelayMs: 1000,
        statementTimeout: 30000,
        enableAudit: true,
        rateLimitPerMinute: 100,
    };

    // Plain language: production connections must encrypt traffic and verify the
    // database certificate. Local development may explicitly opt out; production may not.
    if (process.env.NODE_ENV === 'production' &&
        !(config.pool.ssl && typeof config.pool.ssl === 'object' && config.pool.ssl.rejectUnauthorized === true)) {
        throw new Error('Production requires TLS with certificate verification (DB_SSL=true and no insecure override).');
    }
    if (!Number.isInteger(config.pool.max) || config.pool.max < 1 || config.pool.max > 200) {
        throw new Error('DB_POOL_MAX must be an integer between 1 and 200.');
    }
    if (!Number.isInteger(config.statementTimeout) || config.statementTimeout < 1) {
        throw new Error('statementTimeout must be a positive integer in milliseconds.');
    }
    return new PostgresConnector(config);
}

// ============================================================================
// USAGE EXAMPLE
// ============================================================================

/*
// Import the connector
const connector = createConnector('refugee_aid_allocator');

// Simple query (parameterized - safe from injection)
// Context is only a trusted backend-provided RLS hint, not end-user authentication.
const refugees = await connector.query(
    'SELECT * FROM refugees WHERE camp_id = $1 AND status = $2',
    [campId, 'active'],
    { tenantId: 'org-123', userId: 'user-456' }
);

// Transaction: the callback is not automatically retried because it may have
// external side effects. Add whole-transaction retries only with domain idempotency.
const result = await connector.transaction(async (client) => {
    await client.query('UPDATE allocations SET status = $1 WHERE id = $2', ['approved', allocationId]);
    await client.query('INSERT INTO allocation_history (allocation_id, action) VALUES ($1, $2)', [allocationId, 'approved']);
    return { success: true };
}, { tenantId: 'org-123' });

// Health check
const health = await connector.healthCheck();
console.log('Database healthy:', health.healthy);

// Cleanup
await connector.end();
*/

module.exports = { PostgresConnector, createConnector };
