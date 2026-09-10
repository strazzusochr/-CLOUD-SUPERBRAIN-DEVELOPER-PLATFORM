PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS builds (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  title TEXT NOT NULL,
  prompt TEXT NOT NULL,
  model TEXT NOT NULL,
  html TEXT NOT NULL,
  gateway_mode TEXT NOT NULL,
  gateway_provider TEXT NOT NULL,
  live_provider_calls INTEGER NOT NULL DEFAULT 0 CHECK (live_provider_calls IN (0, 1)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_builds_project_created
  ON builds(project_id, created_at DESC);

CREATE TABLE IF NOT EXISTS workspace_artifacts (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  source_page TEXT NOT NULL,
  artifact_type TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  status TEXT NOT NULL,
  run_id TEXT,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_workspace_artifacts_project_created
  ON workspace_artifacts(project_id, created_at DESC);

CREATE TABLE IF NOT EXISTS runtime_runs (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  prompt_sha256 TEXT NOT NULL,
  status TEXT NOT NULL,
  current_node TEXT NOT NULL,
  checkpoint_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS agent_tasks (
  id TEXT PRIMARY KEY,
  run_id TEXT NOT NULL REFERENCES runtime_runs(id) ON DELETE CASCADE,
  agent_role TEXT NOT NULL,
  status TEXT NOT NULL,
  input_json TEXT NOT NULL,
  output_json TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_run_created
  ON agent_tasks(run_id, created_at ASC);

CREATE TABLE IF NOT EXISTS memory_entries (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  run_id TEXT,
  kind TEXT NOT NULL,
  content TEXT NOT NULL,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_memory_entries_project_created
  ON memory_entries(project_id, created_at DESC);

CREATE TABLE IF NOT EXISTS audit_events (
  id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  trace_id TEXT NOT NULL,
  subject_id TEXT,
  details_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_events_trace_created
  ON audit_events(trace_id, created_at ASC);
