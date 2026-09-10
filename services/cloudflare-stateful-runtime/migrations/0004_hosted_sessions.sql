CREATE TABLE IF NOT EXISTS hosted_sessions (
  token_sha256 TEXT PRIMARY KEY,
  session_id TEXT NOT NULL UNIQUE,
  provider TEXT NOT NULL CHECK (provider IN ('guest', 'name')),
  display_name TEXT NOT NULL CHECK (length(display_name) BETWEEN 1 AND 40),
  issued_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  revoked_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_hosted_sessions_expires_at
  ON hosted_sessions(expires_at);
