-- Personal workspace recency is separate from build mutation timestamps.
CREATE TABLE IF NOT EXISTS workspace_build_usage (
  owner_subject TEXT NOT NULL,
  build_id TEXT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
  last_used_at TEXT NOT NULL,
  use_count INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (owner_subject, build_id),
  CHECK (owner_subject GLOB 'github:[1-9][0-9]*' OR owner_subject GLOB 'local-session:[0-9a-f-]*')
);

CREATE INDEX IF NOT EXISTS idx_workspace_build_usage_owner_recent
  ON workspace_build_usage(owner_subject, last_used_at DESC);
