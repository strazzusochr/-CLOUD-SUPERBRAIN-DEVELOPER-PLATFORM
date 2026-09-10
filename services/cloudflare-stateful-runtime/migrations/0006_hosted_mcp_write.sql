CREATE TABLE IF NOT EXISTS mcp_hosted_write_state (
  channel TEXT PRIMARY KEY CHECK(channel IN ('runtime', 'rollback')),
  content_sha256 TEXT NOT NULL,
  content_json TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  source_commit_sha TEXT NOT NULL,
  trace_id TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS mcp_hosted_idempotency (
  idempotency_key TEXT PRIMARY KEY,
  request_sha256 TEXT NOT NULL,
  channel TEXT NOT NULL CHECK(channel IN ('runtime', 'rollback')),
  content_sha256 TEXT NOT NULL,
  prewrite_audit_event_id TEXT NOT NULL,
  postwrite_audit_event_id TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_mcp_hosted_idempotency_created
  ON mcp_hosted_idempotency(created_at DESC);
