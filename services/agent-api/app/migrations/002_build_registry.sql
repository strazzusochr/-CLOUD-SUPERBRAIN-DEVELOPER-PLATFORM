CREATE TABLE IF NOT EXISTS builds (
  id VARCHAR(64) PRIMARY KEY,
  project_id VARCHAR(255) NOT NULL,
  title VARCHAR(160) NOT NULL,
  prompt_sha256 CHAR(64) NOT NULL,
  model VARCHAR(160) NOT NULL,
  html TEXT NOT NULL,
  gateway_mode VARCHAR(80) NOT NULL DEFAULT 'unknown',
  gateway_provider VARCHAR(80) NOT NULL DEFAULT 'unknown',
  live_provider_calls BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT builds_id_safe CHECK (id ~ '^[A-Za-z0-9_-]{1,64}$'),
  CONSTRAINT builds_prompt_sha256_valid CHECK (prompt_sha256 ~ '^[a-f0-9]{64}$')
);

CREATE INDEX IF NOT EXISTS idx_builds_project_created
  ON builds(project_id, created_at DESC);
