-- A build is not a personal workspace item until it has a verified owner
-- subject. Legacy rows intentionally remain unowned and cannot be guessed
-- into any user's Home list.
ALTER TABLE builds ADD COLUMN owner_subject TEXT;

CREATE INDEX IF NOT EXISTS idx_builds_owner_updated
  ON builds(owner_subject, updated_at DESC);

CREATE TABLE IF NOT EXISTS workspace_build_pins (
  owner_subject TEXT NOT NULL,
  build_id TEXT NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (owner_subject, build_id),
  CHECK (owner_subject GLOB 'github:[1-9][0-9]*' OR owner_subject GLOB 'local-session:[0-9a-f-]*')
);

CREATE INDEX IF NOT EXISTS idx_workspace_build_pins_owner_created
  ON workspace_build_pins(owner_subject, created_at DESC);
