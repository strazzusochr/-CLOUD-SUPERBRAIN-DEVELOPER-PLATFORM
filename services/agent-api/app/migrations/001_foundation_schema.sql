CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  owner_id VARCHAR(255) NOT NULL,
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'archived', 'deleted')),
  metadata JSONB DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_projects_owner_id ON projects(owner_id);

CREATE TABLE IF NOT EXISTS agent_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'failed', 'escalated')),
  agent_list TEXT[] DEFAULT '{}',
  total_input_tokens INTEGER DEFAULT 0,
  total_output_tokens INTEGER DEFAULT 0,
  total_cost_cents INTEGER DEFAULT 0,
  escalation_reason TEXT,
  metadata JSONB DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_sessions_project_id ON agent_sessions(project_id);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON agent_sessions(status);

CREATE TABLE IF NOT EXISTS agent_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES agent_sessions(id) ON DELETE CASCADE,
  agent_type VARCHAR(50) NOT NULL CHECK (agent_type IN ('planner', 'coder', 'tester', 'devops', 'orchestrator', 'user')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'tool')),
  content_ref VARCHAR(1024),
  content_short TEXT,
  token_count INTEGER,
  provider VARCHAR(100),
  model VARCHAR(100),
  trace_id VARCHAR(255),
  metadata JSONB DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON agent_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_messages_trace_id ON agent_messages(trace_id);

CREATE TABLE IF NOT EXISTS memory_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  session_id UUID REFERENCES agent_sessions(id) ON DELETE SET NULL,
  content_text TEXT NOT NULL,
  content_embedding vector(1536),
  embedding_model_version VARCHAR(100) DEFAULT 'text-embedding-3-small',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  relevance_score FLOAT,
  chunk_index INTEGER DEFAULT 0,
  total_chunks INTEGER DEFAULT 1,
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'archived', 'deprecated', 'deleted')),
  consolidation_status VARCHAR(50) DEFAULT 'pending' CHECK (consolidation_status IN ('pending', 'consolidating', 'consolidated', 'failed')),
  metadata JSONB DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_memory_project_id ON memory_entries(project_id);
ALTER TABLE memory_entries ADD COLUMN IF NOT EXISTS content_embedding vector(1536);
ALTER TABLE memory_entries ADD COLUMN IF NOT EXISTS embedding_model_version VARCHAR(100) DEFAULT 'text-embedding-3-small';
CREATE INDEX IF NOT EXISTS idx_memory_embedding ON memory_entries USING ivfflat (content_embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_memory_embedding_model_version ON memory_entries(embedding_model_version);
CREATE INDEX IF NOT EXISTS idx_memory_consolidation ON memory_entries(consolidation_status) WHERE consolidation_status = 'pending';

CREATE TABLE IF NOT EXISTS cost_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES agent_sessions(id) ON DELETE SET NULL,
  agent_type VARCHAR(50),
  model_name VARCHAR(100) NOT NULL,
  provider_name VARCHAR(100) NOT NULL,
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  cost_cents INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  from_cache BOOLEAN DEFAULT FALSE,
  trace_id VARCHAR(255)
);
CREATE INDEX IF NOT EXISTS idx_costs_session_id ON cost_tracking(session_id);
CREATE INDEX IF NOT EXISTS idx_costs_created_at ON cost_tracking(created_at);
CREATE INDEX IF NOT EXISTS idx_costs_agent_type ON cost_tracking(agent_type);

CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type VARCHAR(100) NOT NULL,
  user_id VARCHAR(255),
  session_id UUID,
  details JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  ip_address INET,
  severity VARCHAR(20) DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'critical'))
);
CREATE INDEX IF NOT EXISTS idx_audit_event_type ON audit_log(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_user_id ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit_log(created_at);
