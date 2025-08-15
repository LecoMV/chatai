#!/usr/bin/env bash
set -euo pipefail

### --- Settings you may tweak ---
APP_DIR="/opt/chatai"
BACKEND_DIR="$APP_DIR/backend"
ENV_FILE="$APP_DIR/.env"
DB_NAME="chatai"
DB_USER="chatai"
DB_PASS="${DB_PASS:-$(openssl rand -base64 24 | tr -d '\n' | head -c 24)}"
ADMIN_TOKEN="${ADMIN_TOKEN:-$(openssl rand -hex 24)}"   # for admin API protection
SYSTEMD_SERVICE="${SYSTEMD_SERVICE:-ai-chat}"           # change if your unit name differs
### -------------------------------

echo "==> Detecting backend entry file..."
ENTRY_FILE=""
if [[ -f "$BACKEND_DIR/server.js" ]]; then
  ENTRY_FILE="$BACKEND_DIR/server.js"
elif [[ -f "$BACKEND_DIR/index.js" ]]; then
  ENTRY_FILE="$BACKEND_DIR/index.js"
else
  echo "ERROR: Could not find server.js or index.js in $BACKEND_DIR"
  exit 1
fi
echo "    Using: $ENTRY_FILE"

echo "==> Ensuring packages are present (PostgreSQL + build deps)..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y postgresql postgresql-client

echo "==> Creating database and user (if not already present)..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 || \
  sudo -u postgres createdb "$DB_NAME"

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"

sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" >/dev/null

echo "==> Preparing .env at $ENV_FILE ..."
mkdir -p "$APP_DIR"
touch "$ENV_FILE"

add_env () {
  local key="$1" val="$2"
  if grep -qE "^${key}=" "$ENV_FILE"; then
    # keep existing
    echo "    ${key} already set"
  else
    echo "${key}=${val}" >> "$ENV_FILE"
    echo "    set ${key}"
  fi
}

# Required env
add_env "ANALYTICS_ENABLED" "true"
add_env "DATABASE_URL" "postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}"
add_env "ADMIN_TOKEN" "$ADMIN_TOKEN"
# Optional, but helpful
grep -q "^ANALYTICS_SAMPLE_RATE=" "$ENV_FILE" || echo "ANALYTICS_SAMPLE_RATE=1" >> "$ENV_FILE"
grep -q "^ANONYMIZE_IP=" "$ENV_FILE" || echo "ANONYMIZE_IP=true" >> "$ENV_FILE"

echo "==> Writing SQL schema..."
SCHEMA_SQL="$BACKEND_DIR/sql/analytics_schema.sql"
mkdir -p "$(dirname "$SCHEMA_SQL")"
cat > "$SCHEMA_SQL" <<'SQL'
-- Analytics base tables
CREATE TABLE IF NOT EXISTS chat_requests (
  id BIGSERIAL PRIMARY KEY,
  ts timestamptz NOT NULL DEFAULT now(),
  conversation_id TEXT NOT NULL,
  user_id TEXT,
  ip INET,
  model TEXT,
  prompt_tokens INT,
  completion_tokens INT,
  total_tokens INT,
  latency_ms INT,
  status_code INT,
  route TEXT,
  meta JSONB
);

CREATE INDEX IF NOT EXISTS idx_chat_requests_ts ON chat_requests (ts);
CREATE INDEX IF NOT EXISTS idx_chat_requests_convo ON chat_requests (conversation_id);
SQL

echo "==> Applying schema..."
psql "$(grep -E '^DATABASE_URL=' "$ENV_FILE" | cut -d= -f2-)" -f "$SCHEMA_SQL"

echo "==> Creating analytics middleware module..."
mkdir -p "$BACKEND_DIR/src"
ANALYTICS_JS="$BACKEND_DIR/src/analytics.js"
cat > "$ANALYTICS_JS" <<'JS'
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
JS

echo "==> Creating admin analytics endpoints..."
ADMIN_API_JS="$BACKEND_DIR/src/admin-analytics.js"
cat > "$ADMIN_API_JS" <<'JS'
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
JS

echo "==> Backing up entry file before patch..."
cp -n "$ENTRY_FILE" "${ENTRY_FILE}.bak.$(date +%s)" || true

echo "==> Ensuring analytics middleware is mounted on /api/chat ..."
if ! grep -q "analyticsMiddleware" "$ENTRY_FILE"; then
  # Try to inject requires near the top
  sed -i "1 i const { analyticsMiddleware } = require('./src/analytics');" "$ENTRY_FILE"
fi

# Mount middleware on /api/chat before your chat handler.
# We'll try to detect an app.use('/api/chat'...) or app.post('/api/chat'...) line and insert above it.
if grep -nE "app\.(use|post|get|all)\s*\(\s*['\"]/api/chat" "$ENTRY_FILE" >/dev/null 2>&1; then
  LINE_NO=$(grep -nE "app\.(use|post|get|all)\s*\(\s*['\"]/api/chat" "$ENTRY_FILE" | head -n1 | cut -d: -f1)
  # Insert middleware one line above the first /api/chat route if not already present
  if ! sed -n "$((LINE_NO-1))p" "$ENTRY_FILE" | grep -q "analyticsMiddleware"; then
    awk -v ln="$LINE_NO" 'NR==ln{print "app.use(\"/api/chat\", analyticsMiddleware());"; print} NR!=ln{print}' "$ENTRY_FILE" > "${ENTRY_FILE}.tmp" && mv "${ENTRY_FILE}.tmp" "$ENTRY_FILE"
  fi
else
  echo "WARNING: Could not find /api/chat route to auto-insert middleware. You may need to add:"
  echo '  app.use("/api/chat", analyticsMiddleware());'
fi

echo "==> Registering admin analytics routes..."
if ! grep -q "registerAdminAnalytics" "$ENTRY_FILE"; then
  sed -i "1 i const { registerAdminAnalytics } = require('./src/admin-analytics');" "$ENTRY_FILE"
  echo -e "\n// Auto-added: admin analytics endpoints\nregisterAdminAnalytics(app);\n" >> "$ENTRY_FILE"
fi

echo "==> Reminder to capture token usage:"
if ! grep -q "res.locals.openai_usage" "$ENTRY_FILE"; then
  cat <<'HINT'

[NOTE] You must set token usage after your OpenAI call in the /api/chat handler, e.g.:

  res.locals.openai_usage = {
    model: openaiResponse.model,
    prompt_tokens: openaiResponse.usage?.prompt_tokens || 0,
    completion_tokens: openaiResponse.usage?.completion_tokens || 0
  };

HINT
fi

echo "==> Restarting service (if systemd unit exists: $SYSTEMD_SERVICE)..."
if systemctl list-units --type=service | grep -q "$SYSTEMD_SERVICE"; then
  sudo systemctl daemon-reload || true
  sudo systemctl restart "$SYSTEMD_SERVICE" || {
    echo "WARNING: Failed to restart $SYSTEMD_SERVICE. Start your Node app manually."
  }
else
  echo "INFO: systemd service '$SYSTEMD_SERVICE' not found. Start/restart your app manually (pm2, node, docker, etc.)."
fi

echo
echo "✅ Analytics wiring complete."
echo "   Admin API uses Bearer token auth."
echo "   Your ADMIN_TOKEN is:"
grep "^ADMIN_TOKEN=" "$ENV_FILE" | cut -d= -f2-
echo
echo "Try:"
echo "  curl -H \"Authorization: Bearer \$(grep ADMIN_TOKEN $ENV_FILE | cut -d= -f2-)\" http://localhost:3000/admin/analytics/summary"
echo "  curl -H \"Authorization: Bearer \$(grep ADMIN_TOKEN $ENV_FILE | cut -d= -f2-)\" 'http://localhost:3000/admin/analytics/timeseries?days=14'"