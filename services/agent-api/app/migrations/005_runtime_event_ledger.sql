-- Page 01 runtime ledger. This is additive to the legacy audit_log and keeps
-- personal event history owner-bound. Event, chain head, and outbox rows are
-- written by the same application transaction where the producer can provide
-- a durable effect; external provider effects remain reconciled separately.
CREATE TABLE IF NOT EXISTS runtime_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_subject VARCHAR(64) NOT NULL,
  event_type VARCHAR(128) NOT NULL,
  actor_type VARCHAR(32) NOT NULL DEFAULT 'runtime',
  actor_id VARCHAR(255),
  trace_id VARCHAR(255),
  span_id VARCHAR(255),
  parent_event_id UUID,
  source_service VARCHAR(128) NOT NULL,
  environment VARCHAR(32) NOT NULL,
  source_commit_sha VARCHAR(64),
  producer VARCHAR(128) NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  observed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  owner_sequence BIGINT NOT NULL,
  producer_sequence BIGINT,
  phase VARCHAR(32) NOT NULL,
  outcome VARCHAR(32) NOT NULL,
  effect JSONB NOT NULL DEFAULT '{}',
  input_hash CHAR(64),
  output_hash CHAR(64),
  hash_scope VARCHAR(64),
  redaction_status VARCHAR(32) NOT NULL,
  redaction_version VARCHAR(32),
  payload_ref VARCHAR(255),
  prev_hash CHAR(64),
  event_hash CHAR(64) NOT NULL,
  chain_partition VARCHAR(128) NOT NULL,
  completeness VARCHAR(32) NOT NULL DEFAULT 'complete',
  missing_refs JSONB NOT NULL DEFAULT '[]',
  UNIQUE (owner_subject, chain_partition, owner_sequence),
  UNIQUE (event_hash),
  CHECK (owner_subject ~ '^(github:[1-9][0-9]{0,18}|local-session:[0-9a-f-]{36})$'),
  CHECK (phase IN ('started', 'chunk', 'committed', 'failed', 'blocked')),
  CHECK (outcome IN ('success', 'failure', 'unknown', 'pending', 'blocked')),
  CHECK (completeness IN ('complete', 'incomplete', 'unverified'))
);

CREATE INDEX IF NOT EXISTS idx_runtime_events_owner_recent
  ON runtime_events(owner_subject, occurred_at DESC, event_id DESC);
CREATE INDEX IF NOT EXISTS idx_runtime_events_owner_trace
  ON runtime_events(owner_subject, trace_id, occurred_at ASC);

CREATE TABLE IF NOT EXISTS runtime_event_chain_heads (
  owner_subject VARCHAR(64) NOT NULL,
  chain_partition VARCHAR(128) NOT NULL,
  next_sequence BIGINT NOT NULL DEFAULT 1,
  head_hash CHAR(64),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (owner_subject, chain_partition),
  CHECK (owner_subject ~ '^(github:[1-9][0-9]{0,18}|local-session:[0-9a-f-]{36})$')
);

CREATE TABLE IF NOT EXISTS runtime_event_outbox (
  outbox_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES runtime_events(event_id),
  owner_subject VARCHAR(64) NOT NULL,
  status VARCHAR(24) NOT NULL DEFAULT 'pending',
  attempts INTEGER NOT NULL DEFAULT 0,
  available_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  delivered_at TIMESTAMPTZ,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (event_id),
  CHECK (status IN ('pending', 'delivered', 'failed')),
  CHECK (owner_subject ~ '^(github:[1-9][0-9]{0,18}|local-session:[0-9a-f-]{36})$')
);

CREATE INDEX IF NOT EXISTS idx_runtime_event_outbox_pending
  ON runtime_event_outbox(status, available_at);

CREATE OR REPLACE FUNCTION reject_runtime_event_mutation() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'runtime event ledger is append-only';
END;
$$;

DROP TRIGGER IF EXISTS trg_runtime_events_append_only ON runtime_events;
CREATE TRIGGER trg_runtime_events_append_only
  BEFORE UPDATE OR DELETE ON runtime_events
  FOR EACH ROW EXECUTE FUNCTION reject_runtime_event_mutation();
