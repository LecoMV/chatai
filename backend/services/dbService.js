const { Pool } = require('pg');

// Database connection pool
const pool = new Pool({
    user: 'chatai_user',
    host: 'localhost',
    database: 'chatai_analytics',
    password: 'chatai_analytics_2024',
    port: 5432,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Test connection
pool.query('SELECT NOW()', (err, res) => {
    if (err) {
        console.error('Database connection error:', err);
    } else {
        console.log('Database connected successfully at:', res.rows[0].now);
    }
});

module.exports = {
    query: (text, params) => pool.query(text, params),
    pool: pool
};
