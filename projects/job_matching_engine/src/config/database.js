/**
 * Database Configuration
 * MySQL connection pool configuration for job matching engine
 */

const mysql = require('mysql2/promise');
require('dotenv').config();

// Connection pool configuration
const poolConfig = {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'job_matching',
    
    // Pool settings
    waitForConnections: true,
    connectionLimit: parseInt(process.env.DB_POOL_SIZE) || 10,
    queueLimit: 0,
    
    // Performance settings
    enableKeepAlive: true,
    keepAliveInitialDelay: 10000,
    
    // Character set for full-text search
    charset: 'utf8mb4'
};

// Create connection pool
const pool = mysql.createPool(poolConfig);

/**
 * Execute a raw SQL query
 * @param {string} sql - SQL query string
 * @param {Array} params - Query parameters
 * @returns {Promise<Array>} Query results
 */
async function query(sql, params = []) {
    const [rows] = await pool.execute(sql, params);
    return rows;
}

/**
 * Execute a stored procedure
 * @param {string} procedureName - Name of stored procedure
 * @param {Array} params - Procedure parameters
 * @returns {Promise<Array>} Procedure results
 */
async function callProcedure(procedureName, params = []) {
    const placeholders = params.map(() => '?').join(', ');
    const sql = `CALL ${procedureName}(${placeholders})`;
    const [results] = await pool.execute(sql, params);
    return results;
}

/**
 * Get a connection from the pool for transactions
 * @returns {Promise<Connection>}
 */
async function getConnection() {
    return pool.getConnection();
}

/**
 * Health check function
 * @returns {Promise<boolean>}
 */
async function healthCheck() {
    try {
        const [rows] = await pool.execute('SELECT 1 as health');
        return rows[0].health === 1;
    } catch (error) {
        console.error('Database health check failed:', error.message);
        return false;
    }
}

module.exports = {
    pool,
    query,
    callProcedure,
    getConnection,
    healthCheck
};
