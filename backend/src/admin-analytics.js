const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30000
});

/**
 * Extremely simple admin gate:
 *   Send header: Authorization: Bearer <ADMIN_TOKEN>
 */
function requireAdmin(req, res, next) {
  const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (token && process.env.ADMIN_TOKEN && token === process.env.ADMIN_TOKEN) return next();
  // Optionally, allow cookie/session here if you already have admin auth
  res.status(401).json({ error: 'Unauthorized' });
}

function registerAdminAnalytics(app) {
  app.get('/admin/analytics/summary', requireAdmin, async (_req, res) => {
    const { rows } = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM chat_requests WHERE ts >= now() - interval '24 hours')::int AS requests_24h,
        (SELECT COALESCE(SUM(total_tokens),0) FROM chat_requests WHERE ts >= now() - interval '24 hours') AS tokens_24h,
        (SELECT COALESCE(AVG(latency_ms)::int,0) FROM chat_requests WHERE ts >= now() - interval '24 hours') AS avg_latency_ms,
        (SELECT COUNT(*) FROM chat_requests WHERE status_code >= 400 AND ts >= now() - interval '24 hours')::int AS errors_24h
    `);
    res.json(rows[0] || { requests_24h: 0, tokens_24h: 0, avg_latency_ms: 0, errors_24h: 0 });
  });

  app.get('/admin/analytics/timeseries', requireAdmin, async (req, res) => {
    const days = Math.max(1, Math.min(90, parseInt(req.query.days || '14', 10)));
    const { rows } = await pool.query(`
      SELECT date_trunc('day', ts)::date AS day,
             COUNT(*)::int AS requests,
             COALESCE(SUM(total_tokens),0) AS tokens,
             COALESCE(AVG(latency_ms)::int,0) AS avg_latency_ms
      FROM chat_requests
      WHERE ts >= now() - ($1 || ' days')::interval
      GROUP BY 1
      ORDER BY 1 ASC
    `, [days.toString()]);
    res.json(rows);
  });
}

module.exports = { registerAdminAnalytics, requireAdmin };
