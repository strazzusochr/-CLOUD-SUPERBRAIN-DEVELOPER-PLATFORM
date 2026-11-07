-- Personal workspaces are a distinct domain. Existing unowned legacy builds
-- deliberately remain outside every personal list until an explicit migration
-- policy exists; they must never be guessed into a user's workspace.
ALTER TABLE builds
  ADD COLUMN IF NOT EXISTS owner_subject VARCHAR(64);

CREATE INDEX IF NOT EXISTS idx_builds_owner_updated
  ON builds(owner_subject, updated_at DESC)
  WHERE owner_subject IS NOT NULL;

CREATE TABLE IF NOT EXISTS workspace_build_pins (
  owner_subject VARCHAR(64) NOT NULL,
  build_id VARCHAR(64) NOT NULL REFERENCES builds(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (owner_subject, build_id),
  CONSTRAINT workspace_build_pins_subject_safe
    CHECK (owner_subject ~ '^(github:[1-9][0-9]{0,18}|local-session:[0-9a-f-]{36})$')
);

CREATE INDEX IF NOT EXISTS idx_workspace_build_pins_owner_created
  ON workspace_build_pins(owner_subject, created_at DESC);
