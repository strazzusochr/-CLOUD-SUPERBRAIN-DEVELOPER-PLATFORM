-- Personal workspace recency is separate from build mutation timestamps.
-- Reading a build records use only for the verified owner subject.
CREATE TABLE IF NOT EXISTS workspace_build_usage (
  owner_subject VARCHAR(64) NOT NULL,
  build_id VARCHAR(64) NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  use_count BIGINT NOT NULL DEFAULT 1,
  PRIMARY KEY (owner_subject, build_id),
  CONSTRAINT workspace_build_usage_subject_safe
    CHECK (owner_subject ~ '^(github:[1-9][0-9]{0,18}|local-session:[0-9a-f-]{36})$')
);

CREATE INDEX IF NOT EXISTS idx_workspace_build_usage_owner_recent
  ON workspace_build_usage(owner_subject, last_used_at DESC);
