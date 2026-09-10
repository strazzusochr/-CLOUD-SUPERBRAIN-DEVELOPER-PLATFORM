ALTER TABLE mcp_hosted_idempotency ADD COLUMN trace_id TEXT;

CREATE TABLE IF NOT EXISTS mcp_hosted_timeout_effects (
  effect_key TEXT PRIMARY KEY,
  attempted_at TEXT NOT NULL,
  source_commit_sha TEXT NOT NULL,
  trace_id TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_mcp_hosted_timeout_effects_attempted
  ON mcp_hosted_timeout_effects(attempted_at DESC);
