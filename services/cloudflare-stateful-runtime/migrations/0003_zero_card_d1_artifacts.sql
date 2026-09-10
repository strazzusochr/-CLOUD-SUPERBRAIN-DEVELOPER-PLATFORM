CREATE TABLE IF NOT EXISTS native_artifacts (
  artifact_ref TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  probe_id TEXT NOT NULL,
  content_sha256 TEXT NOT NULL,
  content_text TEXT NOT NULL,
  content_type TEXT NOT NULL,
  content_bytes INTEGER NOT NULL CHECK (content_bytes > 0 AND content_bytes <= 32768),
  created_at TEXT NOT NULL,
  UNIQUE(project_id, probe_id, content_sha256)
);

CREATE INDEX IF NOT EXISTS idx_native_artifacts_probe
  ON native_artifacts(project_id, probe_id);
