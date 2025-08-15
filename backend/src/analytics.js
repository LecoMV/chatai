const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30000
});

function maybeNullIp(ip) {
  // respect anonymization (optional future hash)
  if ((process.env.ANONYMIZE_IP || '').toLowerCase() === 'true') return null;
  return ip || null;
}

async function insertEvent(e) {
  if ((process.env.ANALYTICS_ENABLED || '').toLowerCase() !== 'true') return;
  const q = `
    INSERT INTO chat_requests
      (ts, conversation_id, user_id, ip, model, prompt_tokens, completion_tokens, total_tokens, latency_ms, status_code, route, meta)
    VALUES
      (now(), $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
  `;
  const vals = [
    e.conversationId || 'unknown',
    e.userId || null,
    maybeNullIp(e.ip),
    e.model || null,
    e.promptTokens || 0,
    e.completionTokens || 0,
    (e.promptTokens || 0) + (e.completionTokens || 0),
    e.latencyMs || 0,
    e.statusCode || 200,
    e.route || '/api/chat',
    e.meta || {}
  ];
  try {
    await pool.query(q, vals);
  } catch (err) {
    // don't crash request path
    console.error('[analytics] insert error:', err.message);
  }
}

function analyticsMiddleware() {
  return (req, res, next) => {
    if ((process.env.ANALYTICS_ENABLED || '').toLowerCase() !== 'true') return next();
    const start = Date.now();
    res.on('finish', () => {
      const usage = res.locals.openai_usage || {};
      insertEvent({
        conversationId: req.body?.conversationId || req.headers['x-conversation-id'],
        userId: req.user?.id,
        ip: req.ip,
        model: usage.model,
        promptTokens: usage.prompt_tokens,
        completionTokens: usage.completion_tokens,
        latencyMs: Date.now() - start,
        statusCode: res.statusCode,
        route: req.path,
        meta: {
          origin: req.headers.origin || null,
          ua: req.headers['user-agent'] || null
        }
      });
    });
    next();
  };
}

module.exports = { analyticsMiddleware };
