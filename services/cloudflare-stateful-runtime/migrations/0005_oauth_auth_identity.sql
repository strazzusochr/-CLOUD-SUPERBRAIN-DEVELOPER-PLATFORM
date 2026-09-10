PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS oauth_states (
  state TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_oauth_states_expires_at
  ON oauth_states(expires_at);

CREATE TABLE IF NOT EXISTS refresh_token_families (
  family_id TEXT PRIMARY KEY,
  subject TEXT NOT NULL,
  active_token_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revoked_at TEXT,
  revocation_reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_refresh_token_families_subject
  ON refresh_token_families(subject);

CREATE TABLE IF NOT EXISTS refresh_token_history (
  token_hash TEXT PRIMARY KEY,
  family_id TEXT NOT NULL,
  consumed_at TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('rotated', 'revoked', 'blacklisted'))
);

CREATE INDEX IF NOT EXISTS idx_refresh_token_history_family
  ON refresh_token_history(family_id);
