-- Additive personal runtime ledger for the Home activity contract.
CREATE TABLE IF NOT EXISTS runtime_events (
  event_id TEXT PRIMARY KEY,
  owner_subject TEXT NOT NULL,
  event_type TEXT NOT NULL,
  actor_type TEXT NOT NULL DEFAULT 'runtime',
  actor_id TEXT,
  trace_id TEXT,
  span_id TEXT,
  parent_event_id TEXT,
  source_service TEXT NOT NULL,
  environment TEXT NOT NULL,
  source_commit_sha TEXT,
  producer TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  observed_at TEXT NOT NULL,
  owner_sequence INTEGER NOT NULL,
  producer_sequence INTEGER,
  phase TEXT NOT NULL,
  outcome TEXT NOT NULL,
  effect_json TEXT NOT NULL DEFAULT '{}',
  input_hash TEXT,
  output_hash TEXT,
  hash_scope TEXT,
  redaction_status TEXT NOT NULL,
  redaction_version TEXT,
  payload_ref TEXT,
  prev_hash TEXT,
  event_hash TEXT NOT NULL UNIQUE,
  chain_partition TEXT NOT NULL,
  completeness TEXT NOT NULL DEFAULT 'complete',
  missing_refs_json TEXT NOT NULL DEFAULT '[]',
  UNIQUE(owner_subject, chain_partition, owner_sequence),
  CHECK (owner_subject GLOB 'github:[1-9][0-9]*' OR owner_subject GLOB 'local-session:[0-9a-f-]*'),
  CHECK (phase IN ('started', 'chunk', 'committed', 'failed', 'blocked')),
  CHECK (outcome IN ('success', 'failure', 'unknown', 'pending', 'blocked')),
  CHECK (completeness IN ('complete', 'incomplete', 'unverified'))
);

CREATE INDEX IF NOT EXISTS idx_runtime_events_owner_recent
  ON runtime_events(owner_subject, occurred_at DESC, event_id DESC);
CREATE INDEX IF NOT EXISTS idx_runtime_events_owner_trace
  ON runtime_events(owner_subject, trace_id, occurred_at ASC);

CREATE TABLE IF NOT EXISTS runtime_event_chain_heads (
  owner_subject TEXT NOT NULL,
  chain_partition TEXT NOT NULL,
  next_sequence INTEGER NOT NULL DEFAULT 1,
  head_hash TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY(owner_subject, chain_partition),
  CHECK (owner_subject GLOB 'github:[1-9][0-9]*' OR owner_subject GLOB 'local-session:[0-9a-f-]*')
);

CREATE TABLE IF NOT EXISTS runtime_event_outbox (
  outbox_id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL REFERENCES runtime_events(event_id),
  owner_subject TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  attempts INTEGER NOT NULL DEFAULT 0,
  available_at TEXT NOT NULL,
  delivered_at TEXT,
  last_error TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(event_id),
  CHECK (status IN ('pending', 'delivered', 'failed')),
  CHECK (owner_subject GLOB 'github:[1-9][0-9]*' OR owner_subject GLOB 'local-session:[0-9a-f-]*')
);

CREATE INDEX IF NOT EXISTS idx_runtime_event_outbox_pending
  ON runtime_event_outbox(status, available_at);

CREATE TRIGGER IF NOT EXISTS trg_runtime_events_append_only_update
BEFORE UPDATE ON runtime_events
BEGIN
  SELECT RAISE(ABORT, 'runtime event ledger is append-only');
END;

CREATE TRIGGER IF NOT EXISTS trg_runtime_events_append_only_delete
BEFORE DELETE ON runtime_events
BEGIN
  SELECT RAISE(ABORT, 'runtime event ledger is append-only');
END;
