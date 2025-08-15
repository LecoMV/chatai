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
