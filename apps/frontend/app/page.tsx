"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";

type AgentStatus = {
  type: string;
  status: string;
  profile_contract_version?: string;
  role?: string;
  primary_model?: string;
  fallbacks?: string[];
  max_execution_seconds?: number;
  max_output_tokens?: number;
  max_retries?: number;
  allowed_tools?: string[];
  blocked_actions?: string[];
  human_review_required_actions?: string[];
  graceful_degradation?: string;
  current_task?: string | null;
  current_session_id?: string | null;
  retries: number;
  latest_task_id?: string | null;
  latest_task_type?: string | null;
  latest_status?: string;
  latest_result?: string | null;
  latest_error?: string | null;
  updated_at?: string | null;
};

type AutonomousTeamMember = {
  logical_role: string;
  execution_agent_type: string;
  task_id?: string | null;
  latest_task_id?: string | null;
  task_type?: string | null;
  status: string;
  latest_status?: string;
  priority?: number | null;
  priority_level?: string | null;
  priority_queue?: string | null;
  allowed_tools: string[];
  planned_capabilities: string[];
  write_scope: string[];
  acceptance_criteria: string[];
  human_review_required: boolean;
  blocked_actions: string[];
  current_status_source: string;
  trace_id?: string | null;
  request_id?: string | null;
  correlation_evidence_ref?: string | null;
  audit_feed_evidence_ref?: string | null;
  latest_result?: string | null;
  latest_error?: string | null;
};

type AutonomousTeamStatus = {
  contract_version: string;
  dispatch_contract_version: string;
  team_mode: string;
  runtime_source?: string;
  status: string;
  dispatch_id?: string | null;
  project_id?: string | null;
  session_id?: string | null;
  objective?: string | null;
  trace_id?: string | null;
  request_id?: string | null;
  correlation_evidence_ref?: string | null;
  audit_feed_evidence_ref?: string | null;
  queue_depth: number;
  queue_depth_by_priority: Record<string, number>;
  logical_roles: string[];
  logical_to_execution_map: Record<string, string>;
  external_runtime?: {
    configured?: boolean;
    provider?: string | null;
    status?: string;
    ready?: boolean;
    agents?: string[];
    error?: string | null;
  };
  runtime_pool_contract_version: string;
  write_scope: string[];
  acceptance_criteria: string[];
  constraints: string[];
  members: AutonomousTeamMember[];
  non_claims: string[];
};

type AutonomousTaskDispatchContract = {
  contract_version: string;
  mode: string;
  endpoint: string;
  runtime_endpoint: string;
  status_endpoint: string;
  evidence_ref: string;
  required_request_fields: string[];
  required_response_fields: string[];
  required_assignment_fields: string[];
  required_logical_roles: string[];
  logical_to_execution_map: Record<string, string>;
  policy_version: string;
  runtime_pool_contract_version: string;
  defaults: {
    write_scope: string[];
    constraints: string[];
    acceptance_criteria: string[];
  };
  non_claims: string[];
};

type AutonomousMasterPlanState = {
  contract_version: string;
  status: string;
  endpoint: string;
  source_document: string;
  binding_document: string;
  progress_manifest: string;
  overall_percent: number;
  integrity_status: string;
  phase_percentages: Record<string, number>;
  layer_percentages: Record<string, number>;
  team_mode: string;
  runtime_source?: string;
  logical_roles: string[];
  dispatch_endpoints: string[];
  external_runtime_adapter?: {
    configured?: boolean;
    provider?: string | null;
    status?: string;
    ready?: boolean;
    agents?: string[];
    error?: string | null;
  };
  anchor_snapshot: string[];
  next_concrete_steps: string[];
  hard_constraints: string[];
  running_containers: string[];
  evidence_ref: string;
  non_claims: string[];
};

type AutonomousMasterPlanContract = {
  contract_version: string;
  endpoint: string;
  runtime_endpoint: string;
  status_endpoint: string;
  evidence_ref: string;
  required_top_level_fields: string[];
  required_logical_roles: string[];
  required_dispatch_endpoints: string[];
  required_documents: string[];
  non_claims: string[];
};

type AutonomousAgentRosterRole = {
  id: string;
  slot?: string;
  name?: string;
  status?: string;
  fallback_agent_types?: string[];
  capabilities?: string[];
  metadata?: {
    blocker?: string;
  };
};

type AutonomousAgentRosterState = {
  contract_version: string;
  status: string;
  endpoint: string;
  source_document: string;
  source_path: string;
  roster_version: string;
  runtime_source: string;
  operating_core: {
    observed_concurrent_subagent_limit?: number;
    default_live_mode?: {
      description?: string;
      live_slots?: string[];
      parked_slot?: string;
    };
  };
  startup_protocol: string[];
  launcher_status: {
    validated_startable?: string[];
    attempted_and_blocked?: Record<string, string>;
    attempted_and_unstable?: Record<string, string>;
  };
  role_count: number;
  roles: AutonomousAgentRosterRole[];
  runtime_bindings: {
    langgraph?: {
      status?: string;
      transport?: string;
      checkpointing?: string;
      runtime_contract?: string;
    };
    crewai?: {
      status?: string;
      mode?: string;
      reason?: string;
    };
    prometheus?: {
      status?: string;
      endpoint?: string;
      contract_endpoint?: string;
    };
    grafana?: {
      status?: string;
      mode?: string;
      reason?: string;
    };
    external_adapter?: {
      configured?: boolean;
      provider?: string | null;
      status?: string;
      ready?: boolean;
      agents?: string[];
      error?: string | null;
    };
  };
  error?: string | null;
  evidence_ref: string;
  non_claims: string[];
};

type AutonomousAgentRosterContract = {
  contract_version: string;
  endpoint: string;
  runtime_endpoint: string;
  status_endpoint: string;
  evidence_ref: string;
  required_top_level_fields: string[];
  required_runtime_binding_keys: string[];
  required_documents: string[];
  non_claims: string[];
};

type LiveAgentProfile = {
  agent_id: string;
  display_name: string;
  execution_role: string;
  has_session?: boolean;
  previous_response_id?: string | null;
  updated_at?: string | null;
  model?: string | null;
};

type LiveAgentContract = {
  contract_version: string;
  mode: string;
  status_endpoint: string;
  steer_endpoint: string;
  reset_endpoint: string;
  history_endpoint?: string;
  compatibility_endpoint: string;
  llm_gateway_endpoint: string;
  default_model: string;
  agents: LiveAgentProfile[];
  metadata_policy?: {
    live_provider_calls_allowed?: boolean;
    system_metadata_wins?: boolean;
    reserved_keys_stripped?: string[];
  };
  evidence_refs?: Record<string, string>;
  non_claims: string[];
};

type LiveAgentStatus = {
  status: string;
  contract_version: string;
  runtime_source: string;
  default_model: string;
  agent_count: number;
  agents: LiveAgentProfile[];
  evidence_ref: string;
};

type LiveAgentHistoryEvent = {
  id: string;
  event_type: string;
  agent_id: string;
  execution_role: string;
  project_id?: string | null;
  response_id?: string | null;
  previous_response_id?: string | null;
  status?: string | null;
  model?: string | null;
  trace_id?: string | null;
  request_id?: string | null;
  response_preview?: string | null;
  runtime_source?: string;
  live_provider_calls?: boolean;
  audit_persisted?: boolean;
  evidence_ref?: string;
  created_at?: string | null;
};

type LiveAgentHistory = {
  contract_version: string;
  status: string;
  mode: string;
  history_endpoint: string;
  history_count: number;
  events: LiveAgentHistoryEvent[];
  evidence_ref: string;
  non_claims: string[];
};

type LiveAgentSteerResponse = {
  contract_version: string;
  runtime_source: string;
  agent_id: string;
  response_id?: string | null;
  responseId?: string | null;
  previous_response_id?: string | null;
  status: string;
  model: string;
  text: string;
  execution_role: string;
  project_id: string;
  metadata_policy?: {
    live_provider_calls_allowed?: boolean;
    user_metadata_fields_forwarded?: string[];
    evidence_ref?: string;
  };
  audit_persisted?: boolean;
  audit_evidence_ref?: string;
  trace_id?: string;
  request_id?: string;
};

type BudgetState = {
  total_cost_cents: number;
  budget_limit_cents: number;
  budget_spent_percentage: number;
  level: string;
  allow_new_calls: boolean;
};

type CostBreakdownItem = {
  agent_type: string | null;
  model_name: string;
  provider_name: string;
  cost_cents: number;
};

type CostState = BudgetState & {
  breakdown: CostBreakdownItem[];
};

type CostExportContract = {
  contract_version: string;
  mode: string;
  endpoint: string;
  supported_formats: string[];
  supported_group_by: string[];
  default_group_by: string;
  budget_limit_cents: number;
  filename_pattern: string;
  columns: string[];
  evidence_refs: Record<string, string>;
  policy_checks: string[];
  non_claims: string[];
};

type AgentActivityContract = {
  contract_version: string;
  mode: string;
  screen: string;
  source_endpoints: string[];
  trace_fields: string[];
  langfuse: {
    live_langfuse_deep_link: boolean;
    auth_proxy_required: boolean;
    auth_proxy_strategy: string;
    public_url_configured: boolean;
    deep_link_template: string;
  };
  filters: string[];
  policy_checks: string[];
  evidence_refs: {
    contract_visible: string;
    trace_link_template: string;
    auth_proxy_required: string;
    filtered_feed?: string;
    per_role_results?: string;
  };
  non_claims: string[];
};

type InfraBudgetItem = {
  name: string;
  monthly_cost_cents: number;
  source: string;
};

type InfraBudgetState = {
  projected_cost_cents: number;
  budget_limit_cents: number;
  warning_limit_cents: number;
  budget_spent_percentage: number;
  level: string;
  allow_new_infra: boolean;
  live_verified: boolean;
  source: string;
  items: InfraBudgetItem[];
  non_claims: string[];
};

type CloudProviderResource = Record<string, string | number | boolean | null | undefined>;

type CloudProviderEnvStatus = {
  key: string;
  configured: boolean;
};

type CloudProvider = {
  id: string;
  label: string;
  role: string;
  layers: string[];
  configured: boolean;
  live_verified: boolean;
  status: string;
  required_env: string[];
  optional_env: string[];
  env_status: CloudProviderEnvStatus[];
  resources: CloudProviderResource[];
  monthly_cost_cents?: number | null;
  last_checked_at?: string | null;
  non_claims: string[];
  error?: string;
};

type CloudLayerMapping = {
  layer_id: string;
  label: string;
  providers: string[];
  evidence_ref: string;
};

type CloudProviderState = {
  contract_version: string;
  status: string;
  endpoint: string;
  evidence_ref: string;
  configured_count: number;
  live_verified_count: number;
  total_count: number;
  providers: CloudProvider[];
  seven_layer_mapping: CloudLayerMapping[];
  policy_checks: string[];
  non_claims: string[];
};

type CloudLayerReadinessItem = {
  layer_id: string;
  label: string;
  status: string;
  required_providers: string[];
  configured_providers: string[];
  live_verified_providers: string[];
  blockers: string[];
  evidence_ref: string;
  next_safe_action: string;
  non_claims: string[];
};

type CloudLayerReadinessState = {
  contract_version: string;
  status: string;
  endpoint: string;
  evidence_ref: string;
  ready_layer_count: number;
  partial_layer_count: number;
  total_layer_count: number;
  layers: CloudLayerReadinessItem[];
  provider_inventory_endpoint: string;
  provider_inventory_evidence_ref: string;
  policy_checks: string[];
  non_claims: string[];
};

type CloudRenderOffloadEnvStatus = {
  key: string;
  configured: boolean;
};

type CloudRenderOffloadGate = {
  id: string;
  required_env: string;
  configured: boolean;
  evidence_ref: string;
};

type CloudRenderOffloadWorkload = {
  id: string;
  label: string;
  local_allowed: boolean;
  required_runtime: string;
  blocker: string | null;
};

type CloudRenderOffloadContract = {
  contract_version: string;
  status: string;
  endpoint: string;
  evidence_ref: string;
  localhost_role: string;
  localhost_heavy_render_allowed: boolean;
  home_pc_protection: boolean;
  required_env: string[];
  optional_env: string[];
  env_status: CloudRenderOffloadEnvStatus[];
  missing_required_env: string[];
  blockers: string[];
  cloud_gates: CloudRenderOffloadGate[];
  workloads: CloudRenderOffloadWorkload[];
  policy_checks: string[];
  non_claims: string[];
};

type CloudDeploymentPreflightGate = {
  id: string;
  label: string;
  required_env: string[];
  required_artifact: string;
  verifier: string;
  configured: boolean;
  evidence_ref: string;
  next_action: string;
};

type CloudDeploymentPreflightContract = {
  contract_version: string;
  status: string;
  endpoint: string;
  evidence_ref: string;
  required_sequence: string[];
  gates: CloudDeploymentPreflightGate[];
  missing_or_blocked_gates: string[];
  preflight_ready: boolean;
  external_execution_ready: boolean;
  cloud_deploy_claim_allowed: boolean;
  production_deploy_claim_allowed: boolean;
  localhost_role: string;
  commands: string[];
  policy_checks: string[];
  non_claims: string[];
};

type RateLimitContract = {
  contract_version: string;
  mode: string;
  protected_endpoints: string[];
  status_endpoint: string;
  limit: number;
  window_seconds: number;
  failure_status: number;
  failure_detail: string;
  redis_key_pattern: string;
  policy_checks: string[];
  evidence_refs: {
    contract_visible: string;
    status_visible: string;
    overflow_blocked: string;
  };
};

type RateLimitStatus = {
  contract_version: string;
  project_id: string;
  status: string;
  limit: number;
  used: number;
  remaining: number;
  window_seconds: number;
  reset_seconds: number;
  evidence_ref: string;
};

type SessionLimitContract = {
  contract_version: string;
  mode: string;
  protected_endpoints: string[];
  status_endpoint: string;
  limit: number;
  ttl_seconds: number;
  failure_status: number;
  failure_detail: string;
  redis_key_pattern: string;
  policy_checks: string[];
  evidence_refs: {
    contract_visible: string;
    status_visible: string;
    overflow_blocked: string;
  };
};

type SessionLimitStatus = {
  contract_version: string;
  session_id: string;
  status: string;
  limit: number;
  used: number;
  remaining: number;
  ttl_seconds: number;
  evidence_ref: string;
};

type PromptContract = {
  contract_version: string;
  mode: string;
  protected_endpoints: string[];
  max_prompt_chars: number;
  min_prompt_chars: number;
  failure_status: number;
  failure_detail: string;
  request_schema: Record<string, string>;
  policy_checks: string[];
  evidence_refs: {
    contract_visible: string;
    frontend_counter_visible: string;
    overflow_blocked: string;
  };
};

type ErrorResponseContract = {
  contract_version: string;
  mode: string;
  source: string;
  covered_statuses: number[];
  sample_errors: Array<{
    status: number;
    error: string;
    source: string;
  }>;
  policy_checks: string[];
  evidence_refs: {
    contract_visible: string;
    validation_error_blocked: string;
    rate_limit_error_blocked: string;
    ui_error_state: string;
    envelope_enforced: string;
  };
};

type SecurityHeadersContract = {
  contract_version: string;
  mode: string;
  enforced_by: string;
  applies_to: string;
  headers: Record<string, string>;
  cors_policy: {
    mode: string;
    reason: string;
    public_cross_origin_enabled: boolean;
  };
  policy_checks: string[];
  evidence_refs: {
    contract_visible: string;
    headers_enforced: string;
    same_origin_cors_policy: string;
    ui_visible: string;
  };
};

type TraceIdContract = {
  contract_version: string;
  mode: string;
  enforced_by: string;
  request_header: string;
  request_query_param: string;
  response_header: string;
  contract_header: string;
  generated_prefix: string;
  applies_to: string;
  policy_checks: string[];
  evidence_refs: {
    contract_visible: string;
    header_roundtrip: string;
    generated_trace_visible: string;
    ui_visible: string;
  };
};

type CacheControlContract = {
  contract_version: string;
  mode: string;
  enforced_by: string;
  applies_to: string;
  headers: Record<string, string>;
  policy_checks: string[];
  evidence_refs: {
    contract_visible: string;
    headers_enforced: string;
    sensitive_payload_no_store: string;
    ui_visible: string;
  };
};

type RequestIdContract = {
  contract_version: string;
  mode: string;
  enforced_by: string;
  request_header: string;
  request_query_param: string;
  response_header: string;
  contract_header: string;
  generated_prefix: string;
  error_envelope_fields: string[];
  audit_correlation_fields: string[];
  applies_to: string;
  policy_checks: string[];
  evidence_refs: {
    contract_visible: string;
    header_roundtrip: string;
    error_envelope_correlation: string;
    audit_correlation: string;
    audit_feed_visibility: string;
    ui_visible: string;
  };
};

type LayerInterfaceItem = {
  id: string;
  source_layer: string;
  target_layer: string;
  transport: string;
  method: string;
  path: string;
  request_schema: string[];
  response_schema: string[];
  evidence_ref: string;
  status: string;
};

type LayerInterfaceContract = {
  contract_version: string;
  mode: string;
  endpoint: string;
  evidence_ref: string;
  coverage: string;
  interfaces: LayerInterfaceItem[];
  policy_checks: string[];
  non_claims: string[];
};

type TaskAssignmentContract = {
  contract_version: string;
  mode: string;
  audit_gap: string;
  endpoint: string;
  evidence_ref: string;
  covered_boundary: string;
  intake: {
    method: string;
    path: string;
    public_validation_path: string;
    status_path: string;
    public_recent_path: string;
    policy_version: string;
    mode: string;
  };
  queue: {
    backend: string;
    queue_key: string;
    priority_queues?: Record<string, string>;
    priority_order?: string[];
    priority_rules?: Record<string, string>;
    status_key_pattern: string;
    ttl_seconds: number;
    consumer_service: string;
    visibility_endpoints: string[];
    metrics: string[];
  };
  assignment_schema: {
    required: string[];
    fields: Record<string, string>;
  };
  result_schema: Record<string, string>;
  backpressure: Record<string, string | boolean>;
  evidence_refs: string[];
  policy_checks: string[];
  non_claims: string[];
};

type AgentLlmStreamingContract = {
  contract_version: string;
  mode: string;
  audit_gap: string;
  endpoint: string;
  evidence_ref: string;
  covered_boundary: string;
  agent_consumer: {
    module: string;
    function: string;
    parser: string;
    required_state_fields: string[];
  };
  gateway_contract: {
    stream_contract_endpoint: string;
    chat_completion_endpoint: string;
    routing_resolve_endpoint: string;
    routing_policy_endpoint: string;
    protocol: string;
    content_type: string;
    request_flag: Record<string, boolean>;
    frames: string[];
  };
  request_schema: Record<string, string>;
  response_schema: Record<string, string>;
  policy_checks: string[];
  evidence_refs: string[];
  non_claims: string[];
};

type ExternalGate = {
  id: string;
  preflight_gate_id: string;
  label: string;
  configured: boolean;
  required_env: string[];
  evidence_ref: string;
  required_for: string;
  fallback: string;
};

type ExternalGatesState = {
  contract_version: string;
  status: string;
  endpoint: string;
  evidence_ref: string;
  configured_count: number;
  total_count: number;
  local_execution_allowed: boolean;
  aligned_with_deployment_preflight: boolean;
  deployment_preflight_endpoint: string;
  blocked_release_gates: string[];
  gates: ExternalGate[];
  non_claims: string[];
};

type ExternalGateMirrorContract = {
  contract_version: string;
  status: string;
  endpoint: string;
  mirrored_workflow: string;
  verifier: string;
  branch_protection_workflow: string;
  branch_protection_verifier: string;
  local_mirror_command: string;
  hosted_command: string;
  external_gate_status: string;
  configured_count: number;
  total_count: number;
  required_external_gates: string[];
  phase2_contracts_mirrored: Array<{
    name: string;
    endpoint: string;
    contract_version: string;
    evidence_ref: string;
    required_event_types?: string[];
  }>;
  hosted_staging_claim_allowed: boolean;
  branch_protection_claim_allowed: boolean;
  branch_protection_evidence_ref: string;
  production_deploy_claim_allowed: boolean;
  evidence_ref: string;
  non_claims: string[];
};

type AuthContract = {
  contract_version: string;
  mode: string;
  live_github_oauth_call: boolean;
  github_oauth_configured: boolean;
  jwt: {
    algorithm: string;
    access_token_ttl_seconds: number;
    issuer: string;
    audience: string;
  };
  refresh_token: {
    ttl_seconds: number;
    rotation_required: boolean;
    blacklist_store: string;
    blacklist_key_pattern: string;
  };
  cookie_flags: {
    HttpOnly: boolean;
    Secure: boolean;
    SameSite: string;
  };
  endpoints: Record<string, string>;
  evidence_refs: Record<string, string>;
  policy_checks: string[];
  non_claims: string[];
};

type MemoryPurgeContract = {
  contract_version: string;
  mode: string;
  endpoint: string;
  job_status_endpoint: string;
  single_entry_endpoint: string;
  requires_confirmation: boolean;
  purge_scope: string[];
  audit: {
    event_type: string;
    retention_days: number;
    stored_after_purge: boolean;
  };
  evidence_refs: Record<string, string>;
  policy_checks: string[];
  non_claims: string[];
};

type WorkflowDispatchPlan = {
  contract_version: string;
  status: string;
  mode: string;
  live_github_call: boolean;
  github_api: {
    method: string;
    endpoint: string;
    required_token_env: string;
    required_permission: string;
  };
  payload: {
    ref: string;
    inputs: Record<string, string>;
  };
  human_gate: {
    required_for: string[];
    approved: boolean;
  };
  violations: string[];
  non_claims: string[];
};

type GithubBranchPrContract = {
  contract_version: string;
  mode: string;
  capability: string;
  toolset: string;
  live_github_call: boolean;
  allowed_branch_pattern: string;
  branch_regex: string;
  default_base: string;
  default_payload: {
    branch: string;
    title: string;
    base: string;
    body: string;
  };
  generated_payloads: {
    branch_payload: {
      ref: string;
      source: string;
    };
    pull_request_payload: {
      title: string;
      head: string;
      base: string;
      body: string;
      draft: boolean;
    };
  };
  policy_checks: string[];
  forbidden_capabilities: string[];
  evidence_refs: {
    accepted: string;
    blocked: string;
  };
  non_claims: string[];
};

type PostgresqlReadonlyContract = {
  contract_version: string;
  mode: string;
  toolset: string;
  capability: string;
  live_database_call: boolean;
  allowed_scope: string;
  allowed_sql: string[];
  forbidden_sql: string[];
  default_payload: {
    sql: string;
    parameters: unknown[];
  };
  policy_checks: string[];
  evidence_refs: {
    accepted: string;
    blocked: string;
  };
  non_claims: string[];
};

type FilesystemWorkspaceContract = {
  contract_version: string;
  mode: string;
  toolset: string;
  capability: string;
  live_filesystem_call: boolean;
  workspace_root: string;
  allowed_operations: string[];
  forbidden_operations: string[];
  default_payload: {
    operation: string;
    path: string;
  };
  policy_checks: string[];
  evidence_refs: {
    accepted: string;
    blocked: string;
  };
  non_claims: string[];
};

type PlaywrightBrowserProofContract = {
  contract_version: string;
  mode: string;
  toolset: string;
  capability: string;
  live_browser_call: boolean;
  allowed_actions: string[];
  allowed_scopes: string[];
  allowed_targets: string[];
  forbidden_targets: string[];
  timeout_ms_cap: number;
  default_payload: {
    action: string;
    target_url: string;
  };
  policy_checks: string[];
  evidence_refs: {
    accepted: string;
    blocked: string;
  };
  non_claims: string[];
};

type E2bSandboxLifecycleContract = {
  contract_version: string;
  mode: string;
  toolset: string;
  capability: string;
  live_e2b_call: boolean;
  api_key_configured: boolean;
  allowed_actions: string[];
  allowed_scopes: string[];
  max_session_timeout_ms: number;
  close_required: boolean;
  default_payload: {
    action: string;
    code: string;
    close_sandbox_finally: boolean;
  };
  policy_checks: string[];
  evidence_refs: {
    accepted: string;
    blocked: string;
    degraded: string;
  };
  non_claims: string[];
};

type McpVersionPinningContract = {
  contract_version: string;
  mode: string;
  audit_gap: string;
  endpoint: string;
  evidence_ref: string;
  gateway: {
    service: string;
    app_version: string;
    runtime: string;
    requirements_file: string;
    dependency_pin_policy: string;
  };
  pinned_dependencies: Array<{
    name: string;
    version: string;
    pin: string;
  }>;
  pinned_tool_contracts: Array<{
    toolset: string;
    capability: string;
    contract_version: string;
    endpoint: string;
    live_mutation: boolean;
  }>;
  request_contract: Record<string, string | boolean>;
  drift_policy: string[];
  evidence_refs: string[];
  non_claims: string[];
};

type MemoryEmbeddingConsistencyContract = {
  contract_version: string;
  mode: string;
  audit_gap: string;
  endpoint: string;
  evidence_ref: string;
  status: string;
  schema: {
    table: string;
    expected_columns: Record<string, string>;
    actual_columns: Record<string, string>;
    mismatches: string[];
    error: string | null;
  };
  current_embedding: {
    model_version: string;
    dimensions: number;
    search_mode: string;
    generation_mode: string;
    live_embedding_provider_calls: boolean;
  };
  write_policy: Record<string, string>;
  read_policy: Record<string, string | boolean>;
  reembedding_policy: {
    trigger: string;
    required_steps: string[];
    stale_row_policy: string;
    rollback: string;
  };
  evidence_refs: string[];
  non_claims: string[];
};

type ServiceHealth = {
  status: string;
  database?: string;
  required_tables?: number;
  extensions?: string[];
  service?: string;
  error?: string;
};

type SystemHealth = {
  status: string;
  service: string;
  time: string;
  services: Record<string, ServiceHealth>;
  budget: BudgetState;
  external_gates?: {
    status: string;
    configured_count: number;
    total_count: number;
    local_execution_allowed: boolean;
  };
};

type SystemFallbackContract = {
  contract_version: string;
  mode: string;
  health_endpoint: string;
  ui_state: string;
  trigger_conditions: string[];
  recovery_actions: string[];
  policy_checks: string[];
  evidence_refs: {
    contract_visible: string;
    unavailable_state: string;
    degraded_service: string;
  };
  non_claims: string[];
};

type PromptResponse = {
  session_id: string;
  stream_url: string;
  task_id: string;
  memory_id: string;
  budget: {
    level: string;
    spent_percentage: number;
    total_cost_cents: number;
    budget_limit_cents: number;
  };
  rate_limit: {
    limit: number;
    remaining: number;
    window_seconds: number;
  };
  session_llm_call_count: number;
};

type MemoryResult = {
  id: string;
  content: string;
  relevance_score: number;
  created_at: string;
  session_id: string | null;
};

type RecentSession = {
  session_id: string;
  project_id: string;
  started_at: string | null;
  status: string;
  latest_task_id: string | null;
  prompt: string | null;
  assistant_result: string | null;
};

type AuditEvent = {
  id: string;
  event_type: string;
  user_id?: string | null;
  session_id: string | null;
  severity: string;
  created_at: string | null;
  details: Record<string, unknown>;
  request_id?: string | null;
  trace_id?: string | null;
  correlation_evidence_ref?: string | null;
  audit_feed_evidence_ref?: string | null;
};

type PerRoleResult = {
  role: string;
  status: string;
  result_ref?: string;
  summary?: string;
  mcp_status?: string;
  mcp_evidence_ref?: string;
  done_validation?: Record<string, boolean>;
};

type AgentActivityEvent = AuditEvent & {
  trace_id: string;
  agent_type: string;
  langfuse_trace_url: string;
  per_role_results?: PerRoleResult[];
  role_summary_count?: number;
  partial_failure?: boolean;
  partial_failure_reasons?: string[];
  aggregation_evidence_ref?: string | null;
};

type RecentTask = {
  task_id: string;
  project_id: string;
  session_id: string;
  agent_type: string;
  task_type: string;
  task_description: string;
  status: string;
  created_at: string;
  updated_at: string | null;
  result: string | null;
  error: string | null;
  retry_count: number;
  max_retries: number;
  result_envelope: Record<string, unknown> | null;
  done_validation: Record<"implemented" | "tested" | "integrated" | "reported" | "logged", boolean> | null;
};

type TaskPolicy = {
  policy_version: string;
  profile_contract_version?: string;
  mode: string;
  required_blocked_actions: string[];
  allowed_tools: string[];
  write_tools: string[];
  profile_gates?: Array<{
    agent_type: string;
    max_retries: number;
    max_execution_seconds: number;
    allowed_tools: string[];
    blocked_actions: string[];
    human_review_required_actions: string[];
  }>;
  write_scope_required_for: {
    agent_type: string;
    tools: string[];
    keywords: string[];
  };
  devops_human_gate: string;
};

type RotationEvent = {
  id: string;
  session_id: string | null;
  severity: string;
  created_at: string | null;
  details: {
    contract_version?: string;
    event_kind?: string;
    agent?: string;
    reason?: string;
    trace_id?: string | null;
    to_provider?: string;
    from_provider?: string;
    to_model?: string | null;
    from_model?: string | null;
    fallback_index?: number;
    routing_policy_decision?: string;
    evidence_ref?: string;
    live_provider_calls?: boolean;
    cost_metadata?: {
      input_tokens?: number;
      output_tokens?: number;
      estimated_cost_cents?: number;
      budget_level?: string;
      live_billing?: boolean;
    };
  };
};

type ModelRoute = {
  agent_type: string;
  primary: string;
  fallbacks: string[];
  max_output_tokens: number;
  context_budget_policy: string;
  memory_injection_budget_percent: number;
  cost_tier: string;
  supports_streaming: boolean;
  configured_only: boolean;
};

type ModelCapabilities = {
  memory_injection_budget_percent_max: number;
  routes: ModelRoute[];
  agent_profiles?: AgentRuntimeProfile[];
  note: string;
};

type AgentRuntimeProfile = {
  agent_type: string;
  role: string;
  primary_model: string;
  fallbacks: string[];
  max_output_tokens: number;
  max_execution_seconds: number;
  max_retries: number;
  allowed_tools: string[];
  blocked_actions: string[];
  human_review_required_actions: string[];
  graceful_degradation: string;
};

type LlmGatewayState = {
  status: string;
  service: string;
  mode: string;
  live_provider_calls: boolean;
  live_provider_calls_available?: boolean;
  openai_compatible: boolean;
  open_source_first?: boolean;
  hf_router?: {
    available: boolean;
    provider: string;
    upstream_base_url: string;
    default_model: string;
    model_downloads: boolean;
  };
  routing_resolver: boolean;
  provider_health: boolean;
  streaming_sse: boolean;
  streaming_protocol: string;
  models_configured: number;
  non_claims: string[];
  routing_resolution?: LlmRoutingResolution;
  provider_snapshot?: LlmProviderSnapshot;
  streaming_contract?: LlmStreamingContract;
  routing_policy_contract?: LlmRoutingPolicyContract;
  runtime_guard_parity?: LlmRuntimeGuardParity;
};

type LlmRuntimeGuardParity = {
  contract_version: string;
  status: string;
  endpoint: string;
  evidence_ref: string;
  live_provider_calls: boolean;
  live_provider_calls_available?: boolean;
  model_downloads: boolean;
  configured_routes: number;
  configured_models: string[];
  guard_matrix: Array<{
    guard: string;
    status: string;
    evidence_ref: string;
    enforced_on: string[];
    fail_closed: boolean;
  }>;
  evidence_refs: string[];
  non_claims: string[];
};

type LlmRoutingResolution = {
  mode: string;
  live_provider_calls: boolean;
  live_provider_calls_available?: boolean;
  agent_type: string;
  task_type: string;
  selected_model: string;
  selected_provider: string;
  selected_model_family?: string;
  reason: string;
  fallback_chain: string[];
  provider_chain: string[];
  max_output_tokens: number;
  supports_streaming: boolean;
  configured_only: boolean;
  live_verified: boolean;
  budget_level: string;
  provider_health: {
    provider: string;
    status: string;
    live_verified: boolean;
    live_provider_calls: boolean;
    live_provider_calls_available?: boolean;
    non_claim: string;
  };
};

type LlmProviderSnapshot = {
  mode: string;
  live_provider_calls: boolean;
  live_verified: boolean;
  providers: Array<{
    provider: string;
    status: string;
    live_verified: boolean;
    live_provider_calls: boolean;
    live_provider_calls_available?: boolean;
    models?: string[];
    configured_models?: string[];
    visible_models_sample?: string[];
    model_count_visible?: number;
    backoff_seconds?: number[];
    reset_after_seconds?: number;
    non_claim?: string;
  }>;
};

type LlmStreamingContract = {
  mode: string;
  protocol: string;
  endpoint: string;
  content_type: string;
  frames: string[];
  event_id_replay: boolean;
  live_provider_calls: boolean;
  non_claim: string;
};

type LlmRoutingPolicyContract = {
  contract_version: string;
  mode: string;
  endpoint: string;
  live_provider_calls: boolean;
  max_fallbacks: number;
  max_retry_cycles: number;
  decisions: string[];
  evidence_refs: {
    contract_visible: string;
    direct_provider_blocked: string;
    fallback_limit_blocked: string;
    retry_limit_blocked: string;
    sensitive_cache_blocked: string;
    budget_blocked: string;
    primary_allowed: string;
  };
  non_claims: string[];
};

type ProgressItem = {
  id: string;
  label: string;
  percent: number;
  status: string;
};

type ProjectProgress = {
  overall_percent: number;
  horizontal: {
    label: string;
    items: ProgressItem[];
  };
  vertical: {
    label: string;
    items: ProgressItem[];
  };
  truth_policy: string;
  binding_document: string;
  last_verified: string;
  non_claims: string[];
};

type ProjectProgressIntegrity = {
  contract_version: string;
  status: string;
  endpoint: string;
  guarded_endpoint: string;
  source_manifest: string;
  binding_document: string;
  manifest_overall_percent: number;
  computed_overall_percent: number;
  horizontal_phase_count: number;
  vertical_layer_count: number;
  horizontal_phase_percentages: Record<string, number>;
  vertical_layer_percentages: Record<string, number>;
  truth_policy: string;
  evidence_ref: string;
  mismatches: string[];
  hard_rules: string[];
  non_claims: string[];
};

type ProjectProgressCompletionItem = {
  id: string;
  label: string;
  current_percent: number;
  target_percent: number;
  remaining_percent: number;
  status: string;
  blockers: string[];
  next_safe_action: string;
};

type ProjectProgressCompletion = {
  contract_version: string;
  status: string;
  endpoint: string;
  requested_target_percent: number;
  current_overall_percent: number;
  can_set_all_to_100: boolean;
  evidence_ref: string;
  truth_policy: string;
  missing_external_gates: string[];
  hard_blockers: string[];
  phase_completion: ProjectProgressCompletionItem[];
  layer_completion: ProjectProgressCompletionItem[];
  safe_autonomy: string[];
  non_claims: string[];
};

type SessionHistoryMessage = {
  id: string;
  role: string;
  agent_type: string | null;
  content: string | null;
  token_count: number;
  created_at: string | null;
};

type SessionHistory = {
  contract_version: string;
  evidence_ref: string;
  session: {
    session_id: string;
    project_id: string;
    started_at: string | null;
    status: string;
    metadata: Record<string, unknown>;
  };
  messages: SessionHistoryMessage[];
  tasks: RecentTask[];
  audit_events: AuditEvent[];
  project_progress: {
    overall_percent: number;
    last_verified: string | null;
    truth_policy: string;
    binding_document: string;
  };
  project_progress_integrity: {
    status: string;
    manifest_overall_percent: number;
    computed_overall_percent: number;
    evidence_ref: string;
    mismatches: string[];
  };
  non_claims: string[];
};

function compactProgressStatus(status: string) {
  if (status.length <= 92) return status;
  const tokens = status.split("-").filter(Boolean);
  if (tokens.length < 12) return `${status.slice(0, 88)}...`;
  return `${tokens.slice(0, 5).join("-")}...${tokens.slice(-3).join("-")}`;
}

type GraphProgressEvent = {
  event: string;
  status?: string;
  agent?: string;
  contract_version?: string;
  evidence_ref?: string;
  required_event_types?: string[];
  node?: string;
  node_name?: string;
  thread_id?: string;
  checkpointing?: string;
  state?: Record<string, unknown>;
};

const defaultAgents: AgentStatus[] = [
  { type: "planner", status: "idle", retries: 0 },
  { type: "coder", status: "idle", retries: 0 },
  { type: "tester", status: "idle", retries: 0 },
  { type: "devops", status: "idle", retries: 0 },
];

function cents(value: number) {
  return (value / 100).toLocaleString("en-US", { style: "currency", currency: "EUR" });
}

function textValue(value: unknown) {
  return typeof value === "string" && value.trim() ? value : null;
}

function recordValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function listText(value: unknown) {
  return Array.isArray(value) && value.length ? value.map((item) => String(item)).join("; ") : null;
}

function stringList(value: unknown): string[] {
  return Array.isArray(value) ? value.map((item) => String(item)) : [];
}

function escalationDetail(event: AuditEvent) {
  const details = event.details;
  const contract = recordValue(details.contract);
  const request = recordValue(details.request);
  const assignment = recordValue(details.assignment);
  return (
    textValue(details.error) ??
    textValue(details.sanitized_summary) ??
    listText(details.violations) ??
    listText(contract?.violations) ??
    textValue(details.code) ??
    textValue(details.error_class) ??
    textValue(request?.reason) ??
    textValue(assignment?.task_description) ??
    "Guard event persisted without a dedicated error string; inspect trace/session details."
  );
}

function escalationEvidence(event: AuditEvent) {
  const details = event.details;
  const contract = recordValue(details.contract);
  return (
    textValue(details.evidence_ref) ??
    textValue(details.audit_evidence_ref) ??
    textValue(contract?.contract_version) ??
    textValue(details.contract_version) ??
    "audit_log"
  );
}

export default function Home() {
  const [projectId, setProjectId] = useState("browser-workspace");
  const [prompt, setPrompt] = useState("Build the next safe platform slice.");
  const [search, setSearch] = useState("platform");
  const [budget, setBudget] = useState<BudgetState | null>(null);
  const [costs, setCosts] = useState<CostState | null>(null);
  const [costExportContract, setCostExportContract] = useState<CostExportContract | null>(null);
  const [agentActivityContract, setAgentActivityContract] = useState<AgentActivityContract | null>(null);
  const [infraBudget, setInfraBudget] = useState<InfraBudgetState | null>(null);
  const [clouds, setClouds] = useState<CloudProviderState | null>(null);
  const [cloudLayers, setCloudLayers] = useState<CloudLayerReadinessState | null>(null);
  const [cloudRenderOffload, setCloudRenderOffload] = useState<CloudRenderOffloadContract | null>(null);
  const [cloudDeploymentPreflight, setCloudDeploymentPreflight] =
    useState<CloudDeploymentPreflightContract | null>(null);
  const [rateLimitContract, setRateLimitContract] = useState<RateLimitContract | null>(null);
  const [rateLimitStatus, setRateLimitStatus] = useState<RateLimitStatus | null>(null);
  const [sessionLimitContract, setSessionLimitContract] = useState<SessionLimitContract | null>(null);
  const [sessionLimitStatus, setSessionLimitStatus] = useState<SessionLimitStatus | null>(null);
  const [promptContract, setPromptContract] = useState<PromptContract | null>(null);
  const [errorResponseContract, setErrorResponseContract] = useState<ErrorResponseContract | null>(null);
  const [securityHeadersContract, setSecurityHeadersContract] = useState<SecurityHeadersContract | null>(null);
  const [traceIdContract, setTraceIdContract] = useState<TraceIdContract | null>(null);
  const [cacheControlContract, setCacheControlContract] = useState<CacheControlContract | null>(null);
  const [requestIdContract, setRequestIdContract] = useState<RequestIdContract | null>(null);
  const [layerInterfaceContract, setLayerInterfaceContract] = useState<LayerInterfaceContract | null>(null);
  const [taskAssignmentContract, setTaskAssignmentContract] = useState<TaskAssignmentContract | null>(null);
  const [agentLlmStreamingContract, setAgentLlmStreamingContract] =
    useState<AgentLlmStreamingContract | null>(null);
  const [externalGates, setExternalGates] = useState<ExternalGatesState | null>(null);
  const [externalGateMirror, setExternalGateMirror] = useState<ExternalGateMirrorContract | null>(null);
  const [authContract, setAuthContract] = useState<AuthContract | null>(null);
  const [memoryPurgeContract, setMemoryPurgeContract] = useState<MemoryPurgeContract | null>(null);
  const [workflowDispatch, setWorkflowDispatch] = useState<WorkflowDispatchPlan | null>(null);
  const [githubBranchPrContract, setGithubBranchPrContract] = useState<GithubBranchPrContract | null>(null);
  const [postgresqlReadonlyContract, setPostgresqlReadonlyContract] = useState<PostgresqlReadonlyContract | null>(null);
  const [filesystemWorkspaceContract, setFilesystemWorkspaceContract] = useState<FilesystemWorkspaceContract | null>(null);
  const [playwrightBrowserProofContract, setPlaywrightBrowserProofContract] =
    useState<PlaywrightBrowserProofContract | null>(null);
  const [e2bSandboxLifecycleContract, setE2bSandboxLifecycleContract] =
    useState<E2bSandboxLifecycleContract | null>(null);
  const [mcpVersionPinningContract, setMcpVersionPinningContract] =
    useState<McpVersionPinningContract | null>(null);
  const [memoryEmbeddingConsistencyContract, setMemoryEmbeddingConsistencyContract] =
    useState<MemoryEmbeddingConsistencyContract | null>(null);
  const [systemFallbackContract, setSystemFallbackContract] = useState<SystemFallbackContract | null>(null);
  const [health, setHealth] = useState<SystemHealth | null>(null);
  const [agents, setAgents] = useState<AgentStatus[]>(defaultAgents);
  const [autonomousTeam, setAutonomousTeam] = useState<AutonomousTeamStatus | null>(null);
  const [autonomousDispatchContract, setAutonomousDispatchContract] = useState<AutonomousTaskDispatchContract | null>(
    null,
  );
  const [autonomousMasterPlan, setAutonomousMasterPlan] = useState<AutonomousMasterPlanState | null>(null);
  const [autonomousMasterPlanContract, setAutonomousMasterPlanContract] =
    useState<AutonomousMasterPlanContract | null>(null);
  const [autonomousAgentRoster, setAutonomousAgentRoster] = useState<AutonomousAgentRosterState | null>(null);
  const [autonomousAgentRosterContract, setAutonomousAgentRosterContract] =
    useState<AutonomousAgentRosterContract | null>(null);
  const [liveAgentContract, setLiveAgentContract] = useState<LiveAgentContract | null>(null);
  const [liveAgentStatus, setLiveAgentStatus] = useState<LiveAgentStatus | null>(null);
  const [liveAgentId, setLiveAgentId] = useState("supervisor");
  const [liveAgentMessage, setLiveAgentMessage] = useState("");
  const [liveAgentSendStatus, setLiveAgentSendStatus] = useState("idle");
  const [liveAgentResponse, setLiveAgentResponse] = useState<LiveAgentSteerResponse | null>(null);
  const [liveAgentHistory, setLiveAgentHistory] = useState<LiveAgentHistory | null>(null);
  const [liveAgentHistoryStatus, setLiveAgentHistoryStatus] = useState("loading");
  const [lastRun, setLastRun] = useState<PromptResponse | null>(null);
  const [memoryResults, setMemoryResults] = useState<MemoryResult[]>([]);
  const [memoryDeleteStatus, setMemoryDeleteStatus] = useState("No memory entry delete requested.");
  const [recentSessions, setRecentSessions] = useState<RecentSession[]>([]);
  const [selectedSessionHistory, setSelectedSessionHistory] = useState<SessionHistory | null>(null);
  const [sessionHistoryStatus, setSessionHistoryStatus] = useState("No run opened.");
  const [auditEvents, setAuditEvents] = useState<AuditEvent[]>([]);
  const [agentActivityEvents, setAgentActivityEvents] = useState<AgentActivityEvent[]>([]);
  const [activitySeverityFilter, setActivitySeverityFilter] = useState("");
  const [activityEventTypeFilter, setActivityEventTypeFilter] = useState("");
  const [activityAgentFilter, setActivityAgentFilter] = useState("");
  const [activityTraceFilter, setActivityTraceFilter] = useState("");
  const [mcpAuditEvents, setMcpAuditEvents] = useState<AuditEvent[]>([]);
  const [memoryConsolidationEvents, setMemoryConsolidationEvents] = useState<AuditEvent[]>([]);
  const [escalations, setEscalations] = useState<AuditEvent[]>([]);
  const [recentTasks, setRecentTasks] = useState<RecentTask[]>([]);
  const [taskPolicy, setTaskPolicy] = useState<TaskPolicy | null>(null);
  const [rotationEvents, setRotationEvents] = useState<RotationEvent[]>([]);
  const [modelCapabilities, setModelCapabilities] = useState<ModelCapabilities | null>(null);
  const [llmGateway, setLlmGateway] = useState<LlmGatewayState | null>(null);
  const [projectProgress, setProjectProgress] = useState<ProjectProgress | null>(null);
  const [projectProgressIntegrity, setProjectProgressIntegrity] = useState<ProjectProgressIntegrity | null>(null);
  const [projectProgressCompletion, setProjectProgressCompletion] =
    useState<ProjectProgressCompletion | null>(null);
  const [graphEvents, setGraphEvents] = useState<GraphProgressEvent[]>([]);
  const [graphStatus, setGraphStatus] = useState("idle");
  const [phase2RuntimeContract, setPhase2RuntimeContract] = useState<Record<string, unknown> | null>(null);
  const [phase2RuntimeStart, setPhase2RuntimeStart] = useState<Record<string, unknown> | null>(null);
  const [phase2RuntimeRuns, setPhase2RuntimeRuns] = useState<Array<Record<string, unknown>>>([]);
  const [taskQueueDepth, setTaskQueueDepth] = useState(0);
  const [events, setEvents] = useState<string[]>([]);
  const [status, setStatus] = useState("ready");
  const [error, setError] = useState<string | null>(null);

  const budgetLabel = useMemo(() => {
    if (!budget) return "Budget loading";
    return `${budget.level.toUpperCase()} ${budget.budget_spent_percentage}% (${cents(
      budget.total_cost_cents,
    )} / ${cents(budget.budget_limit_cents)})`;
  }, [budget]);
  const latestGraphEvent = graphEvents.length ? graphEvents[graphEvents.length - 1] : null;
  const phase2RuntimeState = (phase2RuntimeStart?.state ?? null) as Record<string, unknown> | null;
  const phase2RuntimeEvidenceRaw = phase2RuntimeState?.evidence_refs;
  const phase2RuntimeEvidenceRefs = Array.isArray(phase2RuntimeEvidenceRaw)
    ? phase2RuntimeEvidenceRaw.map(String)
    : [];
  const latestPhase2RuntimeRun = phase2RuntimeRuns[0] ?? null;
  const doneValidationKeys = ["implemented", "tested", "integrated", "reported", "logged"] as const;
  const cloudProviderLabels = useMemo(
    () => new Map((clouds?.providers ?? []).map((provider) => [provider.id, provider.label])),
    [clouds],
  );
  const liveAgentProfiles = liveAgentStatus?.agents?.length
    ? liveAgentStatus.agents
    : liveAgentContract?.agents ?? [];
  const selectedLiveAgent =
    liveAgentProfiles.find((agent) => agent.agent_id === liveAgentId) ?? liveAgentProfiles[0] ?? null;
  const liveAgentEvidenceRefs = {
    contract_visible: "live_agent_steering_contract_visible",
    ui_visible: "live_agent_steering_ui_visible",
    security_guard: "live_agent_metadata_guard_enforced",
    history_visible: "live_agent_steering_history_visible",
    ...(liveAgentContract?.evidence_refs ?? {}),
  };

  async function loadBudget() {
    const response = await fetch("/api/v1/budget", { cache: "no-store" });
    if (!response.ok) throw new Error(`budget ${response.status}`);
    setBudget(await response.json());
  }

  async function loadCosts() {
    const response = await fetch("/api/v1/costs", { cache: "no-store" });
    if (!response.ok) throw new Error(`costs ${response.status}`);
    setCosts(await response.json());
  }

  async function loadCostExportContract() {
    const response = await fetch("/api/v1/costs/export/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`cost export contract ${response.status}`);
    setCostExportContract(await response.json());
  }

  async function loadAgentActivityContract() {
    const response = await fetch("/api/v1/agent-activity/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`agent activity contract ${response.status}`);
    setAgentActivityContract(await response.json());
  }

  async function loadAgentActivityEvents() {
    const params = new URLSearchParams({ limit: "12" });
    if (activitySeverityFilter) params.set("severity", activitySeverityFilter);
    if (activityEventTypeFilter.trim()) params.set("event_type", activityEventTypeFilter.trim());
    if (activityAgentFilter.trim()) params.set("agent_type", activityAgentFilter.trim());
    if (activityTraceFilter.trim()) params.set("trace_id", activityTraceFilter.trim());
    const response = await fetch(`/api/v1/agent-activity/recent?${params.toString()}`, { cache: "no-store" });
    if (!response.ok) throw new Error(`agent activity recent ${response.status}`);
    const payload = await response.json();
    setAgentActivityEvents(payload.events ?? []);
  }

  async function loadInfraBudget() {
    const response = await fetch("/api/v1/infra/budget", { cache: "no-store" });
    if (!response.ok) throw new Error(`infra budget ${response.status}`);
    setInfraBudget(await response.json());
  }

  async function loadClouds() {
    const response = await fetch("/api/v1/clouds", { cache: "no-store" });
    if (!response.ok) throw new Error(`cloud inventory ${response.status}`);
    setClouds(await response.json());
  }

  async function loadCloudLayers() {
    const response = await fetch("/api/v1/clouds/layers", { cache: "no-store" });
    if (!response.ok) throw new Error(`cloud layer readiness ${response.status}`);
    setCloudLayers(await response.json());
  }

  async function loadCloudRenderOffload() {
    const response = await fetch("/api/v1/clouds/render-offload/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`cloud render offload ${response.status}`);
    setCloudRenderOffload(await response.json());
  }

  async function loadCloudDeploymentPreflight() {
    const response = await fetch("/api/v1/clouds/deployment-preflight/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`cloud deployment preflight ${response.status}`);
    setCloudDeploymentPreflight(await response.json());
  }

  async function loadRateLimitContract() {
    const response = await fetch("/api/v1/rate-limit/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`rate limit contract ${response.status}`);
    setRateLimitContract(await response.json());
  }

  async function loadRateLimitStatus(nextProjectId = projectId) {
    const params = new URLSearchParams({ project_id: nextProjectId });
    const response = await fetch(`/api/v1/rate-limit/status?${params.toString()}`, { cache: "no-store" });
    if (!response.ok) throw new Error(`rate limit status ${response.status}`);
    setRateLimitStatus(await response.json());
  }

  async function loadSessionLimitContract() {
    const response = await fetch("/api/v1/session-limits/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`session limit contract ${response.status}`);
    setSessionLimitContract(await response.json());
  }

  async function loadSessionLimitStatus(nextSessionId = lastRun?.session_id ?? "browser-session") {
    const params = new URLSearchParams({ session_id: nextSessionId });
    const response = await fetch(`/api/v1/session-limits/status?${params.toString()}`, { cache: "no-store" });
    if (!response.ok) throw new Error(`session limit status ${response.status}`);
    setSessionLimitStatus(await response.json());
  }

  async function loadPromptContract() {
    const response = await fetch("/api/v1/prompt/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`prompt contract ${response.status}`);
    setPromptContract(await response.json());
  }

  async function loadErrorResponseContract() {
    const response = await fetch("/api/v1/errors/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`error response contract ${response.status}`);
    setErrorResponseContract(await response.json());
  }

  async function loadSecurityHeadersContract() {
    const response = await fetch("/api/v1/security/headers/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`security headers contract ${response.status}`);
    setSecurityHeadersContract(await response.json());
  }

  async function loadTraceIdContract() {
    const response = await fetch("/api/v1/trace/contract", {
      cache: "no-store",
      headers: { "x-trace-id": "frontend-trace-contract-proof" },
    });
    if (!response.ok) throw new Error(`trace id contract ${response.status}`);
    setTraceIdContract(await response.json());
  }

  async function loadCacheControlContract() {
    const response = await fetch("/api/v1/cache/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`cache control contract ${response.status}`);
    setCacheControlContract(await response.json());
  }

  async function loadRequestIdContract() {
    const response = await fetch("/api/v1/request/contract", {
      cache: "no-store",
      headers: { "x-request-id": "frontend-request-contract-proof" },
    });
    if (!response.ok) throw new Error(`request id contract ${response.status}`);
    setRequestIdContract(await response.json());
  }

  async function loadLayerInterfaceContract() {
    const response = await fetch("/api/v1/layer-interfaces/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`layer interface contract ${response.status}`);
    setLayerInterfaceContract(await response.json());
  }

  async function loadTaskAssignmentContract() {
    const response = await fetch("/api/v1/tasks/assignment-contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`task assignment contract ${response.status}`);
    setTaskAssignmentContract(await response.json());
  }

  async function loadAgentLlmStreamingContract() {
    const response = await fetch("/api/v1/agents/llm-streaming-contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`agent llm streaming contract ${response.status}`);
    setAgentLlmStreamingContract(await response.json());
  }

  async function loadExternalGates() {
    const response = await fetch("/api/v1/external-gates", { cache: "no-store" });
    if (!response.ok) throw new Error(`external gates ${response.status}`);
    setExternalGates(await response.json());
  }

  async function loadExternalGateMirror() {
    const response = await fetch("/api/v1/external-gates/mirror", { cache: "no-store" });
    if (!response.ok) throw new Error(`external gates mirror ${response.status}`);
    setExternalGateMirror(await response.json());
  }

  async function loadAuthContract() {
    const response = await fetch("/api/v1/auth/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`auth contract ${response.status}`);
    setAuthContract(await response.json());
  }

  async function loadMemoryPurgeContract() {
    const response = await fetch("/api/v1/memory/purge/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`memory purge contract ${response.status}`);
    setMemoryPurgeContract(await response.json());
  }

  async function loadWorkflowDispatch() {
    const response = await fetch("/api/v1/devops/workflow-dispatch/plan", { cache: "no-store" });
    if (!response.ok) throw new Error(`workflow dispatch ${response.status}`);
    setWorkflowDispatch(await response.json());
  }

  async function loadGithubBranchPrContract() {
    const response = await fetch("/mcp/api/v1/github/branch-pr/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`github branch pr contract ${response.status}`);
    setGithubBranchPrContract(await response.json());
  }

  async function loadPostgresqlReadonlyContract() {
    const response = await fetch("/mcp/api/v1/postgresql/readonly-query/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`postgresql readonly query contract ${response.status}`);
    setPostgresqlReadonlyContract(await response.json());
  }

  async function loadFilesystemWorkspaceContract() {
    const response = await fetch("/mcp/api/v1/filesystem/workspace-scope/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`filesystem workspace scope contract ${response.status}`);
    setFilesystemWorkspaceContract(await response.json());
  }

  async function loadPlaywrightBrowserProofContract() {
    const response = await fetch("/mcp/api/v1/playwright/browser-proof/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`playwright browser proof contract ${response.status}`);
    setPlaywrightBrowserProofContract(await response.json());
  }

  async function loadE2bSandboxLifecycleContract() {
    const response = await fetch("/mcp/api/v1/e2b/sandbox-lifecycle/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`e2b sandbox lifecycle contract ${response.status}`);
    setE2bSandboxLifecycleContract(await response.json());
  }

  async function loadMcpVersionPinningContract() {
    const response = await fetch("/mcp/api/v1/version-pinning/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`mcp version pinning contract ${response.status}`);
    setMcpVersionPinningContract(await response.json());
  }

  async function loadMemoryEmbeddingConsistencyContract() {
    const response = await fetch("/api/v1/memory/embedding-consistency/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`memory embedding consistency contract ${response.status}`);
    setMemoryEmbeddingConsistencyContract(await response.json());
  }

  async function loadHealth() {
    const response = await fetch("/api/v1/health", { cache: "no-store" });
    if (!response.ok) throw new Error(`health ${response.status}`);
    setHealth(await response.json());
  }

  async function loadSystemFallbackContract() {
    const response = await fetch("/api/v1/system/fallback/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`system fallback contract ${response.status}`);
    setSystemFallbackContract(await response.json());
  }

  async function loadAgents() {
    const response = await fetch("/api/v1/agents/status", { cache: "no-store" });
    if (!response.ok) throw new Error(`agents ${response.status}`);
    const payload = await response.json();
    setAgents(payload.agents ?? defaultAgents);
  }

  async function loadAutonomousTeamStatus() {
    const response = await fetch("/api/v1/team/status", { cache: "no-store" });
    if (!response.ok) throw new Error(`autonomous team ${response.status}`);
    setAutonomousTeam(await response.json());
  }

  async function loadAutonomousDispatchContract() {
    const response = await fetch("/api/v1/task/dispatch/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`autonomous dispatch contract ${response.status}`);
    setAutonomousDispatchContract(await response.json());
  }

  async function loadAutonomousMasterPlan() {
    const response = await fetch("/api/v1/team/master-plan", { cache: "no-store" });
    if (!response.ok) throw new Error(`autonomous master plan ${response.status}`);
    setAutonomousMasterPlan(await response.json());
  }

  async function loadAutonomousMasterPlanContract() {
    const response = await fetch("/api/v1/team/master-plan/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`autonomous master plan contract ${response.status}`);
    setAutonomousMasterPlanContract(await response.json());
  }

  async function loadAutonomousAgentRoster() {
    const response = await fetch("/api/v1/team/roster", { cache: "no-store" });
    if (!response.ok) throw new Error(`autonomous agent roster ${response.status}`);
    setAutonomousAgentRoster(await response.json());
  }

  async function loadAutonomousAgentRosterContract() {
    const response = await fetch("/api/v1/team/roster/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`autonomous agent roster contract ${response.status}`);
    setAutonomousAgentRosterContract(await response.json());
  }

  async function loadLiveAgents() {
    const [contractResponse, statusResponse] = await Promise.all([
      fetch("/api/v1/live-agents/contract", { cache: "no-store" }),
      fetch("/api/v1/live-agents/status", { cache: "no-store" }),
    ]);
    if (!contractResponse.ok) throw new Error(`live agent contract ${contractResponse.status}`);
    if (!statusResponse.ok) throw new Error(`live agent status ${statusResponse.status}`);
    const contractPayload = (await contractResponse.json()) as LiveAgentContract;
    const statusPayload = (await statusResponse.json()) as LiveAgentStatus;
    setLiveAgentContract(contractPayload);
    setLiveAgentStatus(statusPayload);
    const nextAgents = statusPayload.agents?.length ? statusPayload.agents : contractPayload.agents ?? [];
    if (nextAgents.length && !nextAgents.some((agent) => agent.agent_id === liveAgentId)) {
      setLiveAgentId(nextAgents[0].agent_id);
    }
  }

  async function loadLiveAgentHistory(nextAgentId = liveAgentId, nextProjectId = projectId) {
    setLiveAgentHistoryStatus("loading");
    const params = new URLSearchParams({ limit: "8" });
    if (nextAgentId.trim()) params.set("agent_id", nextAgentId.trim());
    if (nextProjectId.trim()) params.set("project_id", nextProjectId.trim());
    const response = await fetch(`/api/v1/live-agents/history?${params.toString()}`, { cache: "no-store" });
    if (!response.ok) throw new Error(`live agent history ${response.status}`);
    const payload = (await response.json()) as LiveAgentHistory;
    setLiveAgentHistory(payload);
    setLiveAgentHistoryStatus(`loaded ${payload.history_count}`);
  }

  async function steerLiveAgent(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const message = liveAgentMessage.trim();
    if (!message) {
      setError("live agent steering guard: message is required");
      return;
    }
    setLiveAgentSendStatus("sending");
    setError(null);
    try {
      const response = await fetch("/api/v1/live-agents/steer", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          agentId: liveAgentId,
          projectId,
          message,
          metadata: {
            source: "frontend_live_agent_control",
            ui_evidence_ref: "live_agent_steering_ui_visible",
          },
        }),
      });
      if (!response.ok) {
        const body = await response.text();
        throw new Error(`live agent steer ${response.status}: ${body}`);
      }
      const payload = (await response.json()) as LiveAgentSteerResponse;
      setLiveAgentResponse(payload);
      setLiveAgentMessage("");
      setLiveAgentSendStatus("sent");
      await Promise.all([loadLiveAgents(), loadLiveAgentHistory(payload.agent_id, payload.project_id)]);
    } catch (caught) {
      setLiveAgentSendStatus("error");
      setError(caught instanceof Error ? caught.message : "live agent steer failed");
    }
  }

  async function resetLiveAgentSession() {
    setLiveAgentSendStatus("resetting");
    setError(null);
    try {
      const response = await fetch(`/api/v1/live-agents/${encodeURIComponent(liveAgentId)}/reset`, {
        method: "POST",
      });
      if (!response.ok) {
        const body = await response.text();
        throw new Error(`live agent reset ${response.status}: ${body}`);
      }
      setLiveAgentResponse(null);
      setLiveAgentSendStatus("reset");
      await Promise.all([loadLiveAgents(), loadLiveAgentHistory(liveAgentId, projectId)]);
    } catch (caught) {
      setLiveAgentSendStatus("error");
      setError(caught instanceof Error ? caught.message : "live agent reset failed");
    }
  }

  async function loadRecentSessions() {
    const response = await fetch("/api/v1/sessions/recent?limit=6", { cache: "no-store" });
    if (!response.ok) throw new Error(`sessions ${response.status}`);
    const payload = await response.json();
    setRecentSessions(payload.sessions ?? []);
  }

  async function openSessionHistory(sessionId: string) {
    setSessionHistoryStatus("loading");
    setError(null);
    try {
      const response = await fetch(`/api/v1/sessions/${encodeURIComponent(sessionId)}/history`, { cache: "no-store" });
      if (!response.ok) {
        const body = await response.text();
        throw new Error(`session history ${response.status}: ${body}`);
      }
      const payload = (await response.json()) as SessionHistory;
      setSelectedSessionHistory(payload);
      setSessionHistoryStatus(`opened ${payload.session.session_id}`);
    } catch (caught) {
      setSessionHistoryStatus("error");
      setError(caught instanceof Error ? caught.message : "session history failed");
    }
  }

  async function loadAuditEvents() {
    const response = await fetch("/api/v1/audit/recent?limit=8", { cache: "no-store" });
    if (!response.ok) throw new Error(`audit ${response.status}`);
    const payload = await response.json();
    setAuditEvents(payload.events ?? []);
  }

  async function loadMcpAuditEvents() {
    const response = await fetch("/api/v1/audit/mcp?limit=8", { cache: "no-store" });
    if (!response.ok) throw new Error(`mcp audit ${response.status}`);
    const payload = await response.json();
    setMcpAuditEvents(payload.events ?? []);
  }

  async function loadMemoryConsolidationEvents() {
    const response = await fetch("/api/v1/memory/consolidation/recent?limit=8", { cache: "no-store" });
    if (!response.ok) throw new Error(`memory consolidation ${response.status}`);
    const payload = await response.json();
    setMemoryConsolidationEvents(payload.events ?? []);
  }

  async function loadEscalations() {
    const response = await fetch("/api/v1/escalations/recent?limit=8", { cache: "no-store" });
    if (!response.ok) throw new Error(`escalations ${response.status}`);
    const payload = await response.json();
    setEscalations(payload.events ?? []);
  }

  async function loadRecentTasks() {
    const response = await fetch("/api/v1/tasks/recent?limit=8", { cache: "no-store" });
    if (!response.ok) throw new Error(`tasks ${response.status}`);
    const payload = await response.json();
    setRecentTasks(payload.tasks ?? []);
    setTaskQueueDepth(payload.queue_depth ?? 0);
  }

  async function loadTaskPolicy() {
    const response = await fetch("/api/v1/tasks/policy", { cache: "no-store" });
    if (!response.ok) throw new Error(`task policy ${response.status}`);
    setTaskPolicy(await response.json());
  }

  async function loadRotationEvents() {
    const response = await fetch("/api/v1/rotation/events?limit=8", { cache: "no-store" });
    if (!response.ok) throw new Error(`rotation events ${response.status}`);
    const payload = await response.json();
    setRotationEvents(payload.events ?? []);
  }

  async function loadModelCapabilities() {
    const response = await fetch("/api/v1/models/capabilities", { cache: "no-store" });
    if (!response.ok) throw new Error(`model capabilities ${response.status}`);
    setModelCapabilities(await response.json());
  }

  async function loadLlmGateway() {
    const [
      healthResponse,
      routingResponse,
      providerResponse,
      streamingResponse,
      policyResponse,
      runtimeGuardResponse,
    ] = await Promise.all([
      fetch("/llm/api/v1/health", { cache: "no-store" }),
      fetch("/llm/api/v1/routing/resolve", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          agent_type: "planner",
          task_type: "phase2_orchestration_dry_run",
          requires_streaming: true,
          budget_level: budget?.level ?? "ok",
        }),
      }),
      fetch("/llm/api/v1/providers/status", { cache: "no-store" }),
      fetch("/llm/api/v1/streaming/contract", { cache: "no-store" }),
      fetch("/llm/api/v1/routing/policy/contract", { cache: "no-store" }),
      fetch("/llm/api/v1/runtime/guard-parity", { cache: "no-store" }),
    ]);
    if (!healthResponse.ok) throw new Error(`llm gateway ${healthResponse.status}`);
    if (!routingResponse.ok) throw new Error(`llm routing ${routingResponse.status}`);
    if (!providerResponse.ok) throw new Error(`llm providers ${providerResponse.status}`);
    if (!streamingResponse.ok) throw new Error(`llm streaming ${streamingResponse.status}`);
    if (!policyResponse.ok) throw new Error(`llm routing policy ${policyResponse.status}`);
    if (!runtimeGuardResponse.ok) throw new Error(`llm runtime guard parity ${runtimeGuardResponse.status}`);
    const health = (await healthResponse.json()) as LlmGatewayState;
    const routing = (await routingResponse.json()) as LlmRoutingResolution;
    const providerSnapshot = (await providerResponse.json()) as LlmProviderSnapshot;
    const streamingContract = (await streamingResponse.json()) as LlmStreamingContract;
    const routingPolicyContract = (await policyResponse.json()) as LlmRoutingPolicyContract;
    const runtimeGuardParity = (await runtimeGuardResponse.json()) as LlmRuntimeGuardParity;
    setLlmGateway({
      ...health,
      routing_resolution: routing,
      provider_snapshot: providerSnapshot,
      streaming_contract: streamingContract,
      routing_policy_contract: routingPolicyContract,
      runtime_guard_parity: runtimeGuardParity,
    });
  }

  async function loadProjectProgress() {
    const response = await fetch("/api/v1/project/progress", { cache: "no-store" });
    if (!response.ok) throw new Error(`project progress ${response.status}`);
    setProjectProgress(await response.json());
  }

  async function loadProjectProgressIntegrity() {
    const response = await fetch("/api/v1/project/progress/integrity", { cache: "no-store" });
    if (!response.ok) throw new Error(`project progress integrity ${response.status}`);
    setProjectProgressIntegrity(await response.json());
  }

  async function loadProjectProgressCompletion() {
    const response = await fetch("/api/v1/project/progress/completion", { cache: "no-store" });
    if (!response.ok) throw new Error(`project progress completion ${response.status}`);
    setProjectProgressCompletion(await response.json());
  }

  async function loadPhase2RuntimeContract() {
    const response = await fetch("/api/v1/phase2/runtime/contract", { cache: "no-store" });
    if (!response.ok) throw new Error(`phase2 runtime contract ${response.status}`);
    setPhase2RuntimeContract(await response.json());
  }

  async function loadPhase2RuntimeRuns() {
    const response = await fetch("/api/v1/phase2/runtime/runs?limit=6", { cache: "no-store" });
    if (!response.ok) throw new Error(`phase2 runtime runs ${response.status}`);
    const payload = await response.json();
    setPhase2RuntimeRuns(payload.runs ?? []);
  }

  async function runMemorySearch(nextSearch = search) {
    if (!nextSearch.trim()) return;
    const params = new URLSearchParams({
      q: nextSearch,
      project_id: projectId,
      limit: "5",
    });
    const response = await fetch(`/api/v1/memory/search?${params.toString()}`, { cache: "no-store" });
    if (!response.ok) throw new Error(`memory ${response.status}`);
    const payload = await response.json();
    setMemoryResults(payload.results ?? []);
  }

  async function deleteMemoryEntry(memoryId: string) {
    setMemoryDeleteStatus(`Deleting ${memoryId}`);
    const params = new URLSearchParams({
      project_id: projectId,
      confirm: "true",
      reason: "user_requested_single_memory_delete",
    });
    const response = await fetch(`/api/v1/memory/${encodeURIComponent(memoryId)}?${params.toString()}`, {
      method: "DELETE",
    });
    if (!response.ok) throw new Error(`memory delete ${response.status}`);
    const payload = await response.json();
    setMemoryResults((items) => items.filter((item) => item.id !== memoryId));
    setMemoryDeleteStatus(`${payload.evidence_ref}: ${memoryId}`);
    await Promise.all([loadAuditEvents(), loadAgentActivityEvents(), runMemorySearch()]);
  }

  async function startRun(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setStatus("starting");
    setEvents([]);
    const maxPromptChars = promptContract?.max_prompt_chars ?? 10_000;
    const minPromptChars = promptContract?.min_prompt_chars ?? 1;
    if (prompt.length > maxPromptChars || prompt.trim().length < minPromptChars) {
      setStatus("error");
      setError(`prompt input guard: prompt must be between ${minPromptChars} and ${maxPromptChars} characters`);
      return;
    }
    try {
      const response = await fetch("/api/v1/prompt", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ project_id: projectId, prompt, stream: true }),
      });
      if (!response.ok) {
        const body = await response.text();
        throw new Error(`prompt ${response.status}: ${body}`);
      }
      const payload: PromptResponse = await response.json();
      setLastRun(payload);
      setStatus("streaming");
      await streamRun(payload.stream_url);
      await Promise.all([
        loadBudget(),
        loadCosts(),
        loadCostExportContract(),
        loadAgentActivityContract(),
        loadAgentActivityEvents(),
        loadInfraBudget(),
        loadCloudDeploymentPreflight(),
        loadRateLimitContract(),
        loadRateLimitStatus(),
        loadSessionLimitContract(),
        loadSessionLimitStatus(payload.session_id),
        loadPromptContract(),
        loadErrorResponseContract(),
        loadSecurityHeadersContract(),
        loadTraceIdContract(),
        loadCacheControlContract(),
        loadRequestIdContract(),
        loadLayerInterfaceContract(),
        loadTaskAssignmentContract(),
        loadAgentLlmStreamingContract(),
        loadExternalGates(),
        loadExternalGateMirror(),
        loadAuthContract(),
        loadMemoryPurgeContract(),
        loadWorkflowDispatch(),
        loadGithubBranchPrContract(),
        loadPostgresqlReadonlyContract(),
        loadFilesystemWorkspaceContract(),
        loadPlaywrightBrowserProofContract(),
        loadE2bSandboxLifecycleContract(),
        loadMcpVersionPinningContract(),
        loadMemoryEmbeddingConsistencyContract(),
        loadHealth(),
        loadSystemFallbackContract(),
        loadAgents(),
        loadAutonomousTeamStatus(),
        loadAutonomousDispatchContract(),
        loadAutonomousMasterPlan(),
        loadAutonomousMasterPlanContract(),
        loadAutonomousAgentRoster(),
        loadAutonomousAgentRosterContract(),
        loadRecentTasks(),
        loadLiveAgentHistory(liveAgentId, projectId),
        loadTaskPolicy(),
        loadRotationEvents(),
        loadModelCapabilities(),
        loadLlmGateway(),
        loadProjectProgress(),
        loadProjectProgressIntegrity(),
        loadProjectProgressCompletion(),
        loadPhase2RuntimeContract(),
        loadPhase2RuntimeRuns(),
        loadRecentSessions(),
        loadAuditEvents(),
        loadMcpAuditEvents(),
        loadMemoryConsolidationEvents(),
        loadEscalations(),
        runMemorySearch(prompt.split(" ").slice(-2).join(" ")),
      ]);
      setSearch(prompt.split(" ").slice(-2).join(" "));
      setStatus("ready");
    } catch (caught) {
      setStatus("error");
      setError(caught instanceof Error ? caught.message : "unknown error");
    }
  }

  async function streamRun(url: string) {
    const response = await fetch(url, { cache: "no-store" });
    if (!response.ok || !response.body) throw new Error(`stream ${response.status}`);
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const chunks = buffer.split("\n\n");
      buffer = chunks.pop() ?? "";
      for (const chunk of chunks) {
        if (chunk.trim()) setEvents((current) => [...current.slice(-10), chunk]);
      }
    }
  }

  async function runLangGraphProgress() {
    setError(null);
    setGraphStatus("streaming");
    setGraphEvents([]);
    try {
      const response = await fetch("/api/v1/orchestrator/dry-run/stream", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          project_id: projectId,
          prompt: `frontend langgraph progress probe: ${prompt}`,
          session_id: lastRun?.session_id,
        }),
      });
      if (!response.ok || !response.body) throw new Error(`graph stream ${response.status}`);
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const chunks = buffer.split("\n\n");
        buffer = chunks.pop() ?? "";
        for (const chunk of chunks) {
          const lines = chunk.split("\n");
          const eventName = lines.find((line) => line.startsWith("event: "))?.slice(7) ?? "message";
          const dataText = lines.find((line) => line.startsWith("data: "))?.slice(6) ?? "{}";
          try {
            const parsed = JSON.parse(dataText) as Omit<GraphProgressEvent, "event">;
            setGraphEvents((current) => [...current.slice(-11), { event: eventName, ...parsed }]);
          } catch {
            setGraphEvents((current) => [...current.slice(-11), { event: eventName, status: "parse_error" }]);
          }
        }
      }
      setGraphStatus("ready");
    } catch (caught) {
      setGraphStatus("error");
      setError(caught instanceof Error ? caught.message : "graph stream failed");
    }
  }

  async function startPhase2RuntimeGraph() {
    setError(null);
    setGraphStatus("phase2-runtime-starting");
    try {
      const response = await fetch("/api/v1/phase2/runtime/start", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          project_id: projectId,
          prompt: `frontend phase2 runtime start probe: ${prompt}`,
          session_id: lastRun?.session_id,
        }),
      });
      if (!response.ok) throw new Error(`phase2 runtime start ${response.status}`);
      const payload = (await response.json()) as Record<string, unknown>;
      setPhase2RuntimeStart(payload);
      setGraphStatus("phase2-runtime-started");
      await Promise.all([
        loadPhase2RuntimeContract(),
        loadPhase2RuntimeRuns(),
        loadAuditEvents(),
        loadProjectProgress(),
        loadProjectProgressIntegrity(),
        loadProjectProgressCompletion(),
      ]);
    } catch (caught) {
      setGraphStatus("error");
      setError(caught instanceof Error ? caught.message : "phase2 runtime start failed");
    }
  }

  useEffect(() => {
    let cancelled = false;
    let liveRefreshInFlight = false;
    let activityRefreshInFlight = false;

    const runLoadGroup = async (
      loads: Array<() => Promise<unknown>>,
      label: string,
      reportError = false,
    ) => {
      const results = await Promise.allSettled(loads.map((load) => load()));
      if (cancelled) return;
      const failed = results.find((result): result is PromiseRejectedResult => result.status === "rejected");
      if (failed && reportError) {
        const message = failed.reason instanceof Error ? failed.reason.message : String(failed.reason ?? "unknown");
        setError(`${label}: ${message}`);
      }
    };

    const primaryLoads: Array<() => Promise<unknown>> = [
      loadBudget,
      loadCosts,
      loadHealth,
      loadSystemFallbackContract,
      loadAgents,
      loadAutonomousTeamStatus,
      loadAutonomousMasterPlan,
      loadAutonomousAgentRoster,
      loadLiveAgents,
      loadRecentTasks,
      loadProjectProgress,
      loadProjectProgressIntegrity,
      loadProjectProgressCompletion,
      loadPhase2RuntimeContract,
      loadPhase2RuntimeRuns,
      loadRecentSessions,
    ];
    const backgroundLoads: Array<() => Promise<unknown>> = [
      loadCostExportContract,
      loadAgentActivityContract,
      loadAgentActivityEvents,
      loadInfraBudget,
      loadClouds,
      loadCloudLayers,
      loadCloudRenderOffload,
      loadCloudDeploymentPreflight,
      loadRateLimitContract,
      loadRateLimitStatus,
      loadSessionLimitContract,
      loadSessionLimitStatus,
      loadPromptContract,
      loadErrorResponseContract,
      loadSecurityHeadersContract,
      loadTraceIdContract,
      loadCacheControlContract,
      loadRequestIdContract,
      loadLayerInterfaceContract,
      loadTaskAssignmentContract,
      loadAutonomousDispatchContract,
      loadAutonomousMasterPlanContract,
      loadAutonomousAgentRosterContract,
      loadLiveAgents,
      loadAgentLlmStreamingContract,
      loadExternalGates,
      loadExternalGateMirror,
      loadAuthContract,
      loadMemoryPurgeContract,
      loadWorkflowDispatch,
      loadGithubBranchPrContract,
      loadPostgresqlReadonlyContract,
      loadFilesystemWorkspaceContract,
      loadPlaywrightBrowserProofContract,
      loadE2bSandboxLifecycleContract,
      loadMcpVersionPinningContract,
      loadMemoryEmbeddingConsistencyContract,
      loadTaskPolicy,
      loadRotationEvents,
      loadModelCapabilities,
      loadLlmGateway,
      loadAuditEvents,
      loadMcpAuditEvents,
      loadMemoryConsolidationEvents,
      loadEscalations,
    ];
    const liveLoads: Array<() => Promise<unknown>> = [
      loadHealth,
      loadAgents,
      loadAutonomousTeamStatus,
      loadAutonomousMasterPlan,
      loadAutonomousAgentRoster,
      loadLiveAgents,
      loadRecentTasks,
      loadRecentSessions,
      loadProjectProgress,
      loadProjectProgressIntegrity,
      loadProjectProgressCompletion,
      loadPhase2RuntimeRuns,
      loadCosts,
      loadRateLimitStatus,
      loadSessionLimitStatus,
    ];
    const activityLoads: Array<() => Promise<unknown>> = [
      loadAuditEvents,
      loadMcpAuditEvents,
      loadMemoryConsolidationEvents,
      loadEscalations,
      loadAgentActivityEvents,
      loadRotationEvents,
      loadInfraBudget,
      loadClouds,
      loadCloudLayers,
      loadCloudRenderOffload,
      loadCloudDeploymentPreflight,
      loadLlmGateway,
    ];

    void runLoadGroup(primaryLoads, "initial load", true);
    const backgroundTimer = window.setTimeout(() => {
      void runLoadGroup(backgroundLoads, "background load");
    }, 8_000);
    const liveTimer = window.setInterval(() => {
      if (liveRefreshInFlight) return;
      liveRefreshInFlight = true;
      void runLoadGroup(liveLoads, "live refresh").finally(() => {
        liveRefreshInFlight = false;
      });
    }, 15_000);
    const activityTimer = window.setInterval(() => {
      if (activityRefreshInFlight) return;
      activityRefreshInFlight = true;
      void runLoadGroup(activityLoads, "activity refresh").finally(() => {
        activityRefreshInFlight = false;
      });
    }, 60_000);

    return () => {
      cancelled = true;
      window.clearTimeout(backgroundTimer);
      window.clearInterval(liveTimer);
      window.clearInterval(activityTimer);
    };
  }, []);

  const degradedServices = health
    ? Object.entries(health.services).filter(([, service]) => service.status !== "healthy")
    : [];
  const systemUnavailable = Boolean(error) || health?.status === "degraded" || health?.status === "down";
  const fallbackEvidenceRefs = systemFallbackContract?.evidence_refs ?? {
    contract_visible: "system_fallback_contract_visible",
    unavailable_state: "system_unavailable_ui_state",
    degraded_service: "system_degraded_service_visible",
  };
  const errorEvidenceRefs = errorResponseContract?.evidence_refs ?? {
    contract_visible: "error_response_contract_visible",
    validation_error_blocked: "error_response_422_visible",
    rate_limit_error_blocked: "error_response_429_visible",
    ui_error_state: "error_response_ui_state_visible",
    envelope_enforced: "error_response_envelope_enforced",
  };
  const securityHeaderEntries = Object.entries(
    securityHeadersContract?.headers ?? {
      "X-Content-Type-Options": "nosniff",
      "X-Frame-Options": "DENY",
      "Referrer-Policy": "no-referrer",
      "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
    },
  );
  const securityHeaderEvidenceRefs = securityHeadersContract?.evidence_refs ?? {
    contract_visible: "security_headers_contract_visible",
    headers_enforced: "security_headers_enforced",
    same_origin_cors_policy: "security_headers_same_origin_policy",
    ui_visible: "security_headers_ui_visible",
  };
  const traceIdEvidenceRefs = traceIdContract?.evidence_refs ?? {
    contract_visible: "trace_id_contract_visible",
    header_roundtrip: "trace_id_header_roundtrip",
    generated_trace_visible: "trace_id_generated_visible",
    ui_visible: "trace_id_ui_visible",
  };
  const cacheControlEntries = Object.entries(
    cacheControlContract?.headers ?? {
      "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
      Pragma: "no-cache",
      Expires: "0",
    },
  );
  const cacheControlEvidenceRefs = cacheControlContract?.evidence_refs ?? {
    contract_visible: "cache_control_contract_visible",
    headers_enforced: "cache_control_headers_enforced",
    sensitive_payload_no_store: "cache_control_sensitive_payload_no_store",
    ui_visible: "cache_control_ui_visible",
  };
  const requestIdEvidenceRefs = requestIdContract?.evidence_refs ?? {
    contract_visible: "request_id_contract_visible",
    header_roundtrip: "request_id_header_roundtrip",
    error_envelope_correlation: "request_id_error_envelope_correlation",
    audit_correlation: "request_id_audit_correlation",
    audit_feed_visibility: "request_id_audit_feed_visible",
    ui_visible: "request_id_ui_visible",
  };
  const projectProgressMismatches = stringList(projectProgressIntegrity?.mismatches);
  const projectProgressHardBlockers = stringList(projectProgressCompletion?.hard_blockers);
  const horizontalProgressItems = Array.isArray(projectProgress?.horizontal?.items)
    ? projectProgress.horizontal.items
    : [];
  const verticalProgressItems = Array.isArray(projectProgress?.vertical?.items) ? projectProgress.vertical.items : [];
  const agentActivityLangfuse = agentActivityContract?.langfuse;
  const agentActivitySourceEndpoints = stringList(agentActivityContract?.source_endpoints);
  const agentActivityFilters = stringList(agentActivityContract?.filters);
  const agentActivityNonClaims = stringList(agentActivityContract?.non_claims);
  const agentActivityEvidenceRefs = agentActivityContract?.evidence_refs ?? {
    contract_visible: "agent_activity_contract_visible",
    trace_link_template: "agent_activity_trace_link_template",
    auth_proxy_required: "langfuse_auth_proxy_required",
    filtered_feed: "agent_activity_filtered_feed_visible",
    per_role_results: "agent_activity_per_role_results_visible",
  };
  const mcpGateway = mcpVersionPinningContract?.gateway;
  const mcpPinnedDependencies = Array.isArray(mcpVersionPinningContract?.pinned_dependencies)
    ? mcpVersionPinningContract.pinned_dependencies
    : [
        { name: "fastapi", version: "0.115.8", pin: "fastapi==0.115.8" },
        { name: "uvicorn[standard]", version: "0.34.0", pin: "uvicorn[standard]==0.34.0" },
        { name: "pydantic", version: "2.10.6", pin: "pydantic==2.10.6" },
      ];
  const mcpPinnedToolContracts = Array.isArray(mcpVersionPinningContract?.pinned_tool_contracts)
    ? mcpVersionPinningContract.pinned_tool_contracts
    : [
        { toolset: "github", capability: "plan_branch_pr", contract_version: "github-branch-pr-plan-v1", endpoint: "", live_mutation: false },
        { toolset: "postgresql", capability: "query_readonly", contract_version: "postgresql-readonly-query-v1", endpoint: "", live_mutation: false },
        { toolset: "filesystem", capability: "plan_workspace_access", contract_version: "filesystem-workspace-scope-v1", endpoint: "", live_mutation: false },
        { toolset: "playwright", capability: "plan_browser_proof", contract_version: "playwright-browser-proof-v1", endpoint: "", live_mutation: false },
        { toolset: "e2b", capability: "plan_sandbox_lifecycle", contract_version: "e2b-sandbox-lifecycle-v1", endpoint: "", live_mutation: false },
      ];
  const mcpRequestContract = recordValue(mcpVersionPinningContract?.request_contract) ?? {
    model: "ToolRequest",
    session_id: "uuid-or-null",
    retry_budget: "0..2",
  };
  const mcpDriftPolicy = stringList(mcpVersionPinningContract?.drift_policy);
  const mcpEvidenceRefs = stringList(mcpVersionPinningContract?.evidence_refs);
  const mcpNonClaims = stringList(mcpVersionPinningContract?.non_claims);
  const memoryCurrentEmbedding = memoryEmbeddingConsistencyContract?.current_embedding;
  const memorySchema = memoryEmbeddingConsistencyContract?.schema;
  const memoryReadPolicy = recordValue(memoryEmbeddingConsistencyContract?.read_policy);
  const memoryReembeddingPolicy = memoryEmbeddingConsistencyContract?.reembedding_policy;
  const memoryExpectedColumns = recordValue(memorySchema?.expected_columns) ?? {
    content_embedding: "vector(1536)",
    embedding_model_version: "character varying(100)",
  };
  const memoryRequiredSteps = stringList(memoryReembeddingPolicy?.required_steps);
  const memoryEvidenceRefs = stringList(memoryEmbeddingConsistencyContract?.evidence_refs);
  const memoryNonClaims = stringList(memoryEmbeddingConsistencyContract?.non_claims);

  return (
    <main className="shell">
      <section className="workspace">
        <header className="topbar">
          <div>
            <p className="eyebrow">Phase 1 Runtime</p>
            <h1>Cloud Superbrain</h1>
          </div>
          <div className={`budget budget-${budget?.level ?? "loading"}`}>{budgetLabel}</div>
        </header>

        <form className="promptPanel" onSubmit={startRun} aria-label="Prompt workspace">
          <label>
            <span>Project</span>
            <input value={projectId} onChange={(event) => setProjectId(event.target.value)} />
          </label>
          <label>
            <span>Prompt</span>
            <textarea
              value={prompt}
              maxLength={promptContract?.max_prompt_chars ?? 10_000}
              onChange={(event) => setPrompt(event.target.value)}
            />
            <small>
              Prompt Input Guard · {prompt.length}/{promptContract?.max_prompt_chars ?? 10_000} ·{" "}
              {promptContract?.evidence_refs?.contract_visible ?? "prompt_input_contract_visible"} /{" "}
              {promptContract?.evidence_refs?.frontend_counter_visible ?? "prompt_input_counter_visible"} /{" "}
              {promptContract?.evidence_refs?.overflow_blocked ?? "prompt_input_422_enforced"}
            </small>
          </label>
          <div className="actions">
            <button type="submit" disabled={status === "starting" || status === "streaming"}>
              Start
            </button>
            <button type="button" onClick={() => void loadBudget()}>
              Refresh
            </button>
          </div>
        </form>

        {error ? <p className="error">{error}</p> : null}

        <section className="panel" aria-label="Error response contract">
          <header className="panelHeader">
            <h2>Error Response Contract</h2>
            <button type="button" onClick={() => void loadErrorResponseContract()}>
              Refresh Contract
            </button>
          </header>
          <div className="healthSummary">
            <div>
              <span>Contract</span>
              <strong>{errorResponseContract?.contract_version ?? "error-response-contract-v1"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{errorResponseContract?.mode ?? "structured_http_error_contract"}</strong>
            </div>
            <div>
              <span>Status Codes</span>
              <strong>{(errorResponseContract?.covered_statuses ?? [400, 401, 402, 403, 404, 422, 429, 503]).join(", ")}</strong>
            </div>
            <div>
              <span>UI Evidence</span>
              <strong>{errorEvidenceRefs.ui_error_state}</strong>
            </div>
          </div>
          <p className="muted evidenceLine">
            Evidence: {errorEvidenceRefs.contract_visible} / {errorEvidenceRefs.validation_error_blocked} /{" "}
            {errorEvidenceRefs.rate_limit_error_blocked} / {errorEvidenceRefs.ui_error_state} /{" "}
            {errorEvidenceRefs.envelope_enforced}
          </p>
          <div className="policyGrid">
            {(errorResponseContract?.policy_checks ?? [
              "Error responses expose a stable HTTP status.",
              "Validation errors fail before persistence/task/memory mutation.",
              "Rate/session overflow returns 429 and no done claim.",
              "UI surfaces error text instead of marking completion.",
            ]).map((check) => (
              <span key={check}>{check}</span>
            ))}
          </div>
          <div className="healthList">
            {(errorResponseContract?.sample_errors ?? [
              { status: 422, error: "string_too_long", source: "prompt max_length validation" },
              { status: 429, error: "prompt rate limit exceeded", source: "rate limit guard" },
            ]).slice(0, 4).map((sample) => (
              <article className="healthItem" key={`${sample.status}-${sample.error}`}>
                <div>
                  <strong>{sample.status}</strong>
                  <span>{sample.error}</span>
                </div>
                <small>{sample.source}</small>
              </article>
            ))}
          </div>
        </section>

        <section
          className={`panel fallbackPanel ${systemUnavailable ? "fallbackPanel-active" : ""}`}
          aria-label="System unavailable fallback"
        >
          <header className="panelHeader">
            <h2>System Unavailable Fallback</h2>
            <button
              type="button"
              onClick={() => void Promise.all([loadHealth(), loadSystemFallbackContract()])}
            >
              Retry Health
            </button>
          </header>
          <div className="healthSummary">
            <div>
              <span>UI State</span>
              <strong>{systemUnavailable ? "System Unavailable" : "Healthy Watch"}</strong>
            </div>
            <div>
              <span>Contract</span>
              <strong>{systemFallbackContract?.contract_version ?? "system-unavailable-fallback-v1"}</strong>
            </div>
            <div>
              <span>Health Endpoint</span>
              <strong>{systemFallbackContract?.health_endpoint ?? "GET /api/v1/health"}</strong>
            </div>
            <div>
              <span>Degraded Services</span>
              <strong>{degradedServices.length}</strong>
            </div>
          </div>
          <p className="muted evidenceLine">
            Evidence: {fallbackEvidenceRefs.contract_visible} / {fallbackEvidenceRefs.unavailable_state} /{" "}
            {fallbackEvidenceRefs.degraded_service}
          </p>
          {degradedServices.length ? (
            <div className="healthList">
              {degradedServices.map(([name, service]) => (
                <article className="healthItem" key={name}>
                  <div>
                    <strong>{name}</strong>
                    <span className={`healthState health-${service.status}`}>{service.status}</span>
                  </div>
                  {service.error ? <small className="agentError">{service.error}</small> : null}
                </article>
              ))}
            </div>
          ) : (
            <p className="muted">No degraded service currently reported by health endpoint.</p>
          )}
          <div className="policyGrid">
            {(systemFallbackContract?.policy_checks ?? [
              "no_fake_healthy_claim",
              "failed_service_visible",
              "manual_retry_available",
              "health_endpoint_named",
            ]).map((check) => (
              <span key={check}>{check}</span>
            ))}
          </div>
        </section>

        <section className="panel" aria-label="Security headers contract">
          <header className="panelHeader">
            <h2>Security Headers Contract</h2>
            <button type="button" onClick={() => void loadSecurityHeadersContract()}>
              Refresh Contract
            </button>
          </header>
          <div className="healthSummary">
            <div>
              <span>Contract</span>
              <strong>{securityHeadersContract?.contract_version ?? "security-headers-v1"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{securityHeadersContract?.mode ?? "api_response_security_headers"}</strong>
            </div>
            <div>
              <span>CORS</span>
              <strong>{securityHeadersContract?.cors_policy.mode ?? "same_origin_by_default"}</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{securityHeaderEvidenceRefs.ui_visible}</strong>
            </div>
          </div>
          <p className="muted evidenceLine">
            Evidence: {securityHeaderEvidenceRefs.contract_visible} / {securityHeaderEvidenceRefs.headers_enforced} /{" "}
            {securityHeaderEvidenceRefs.same_origin_cors_policy} / {securityHeaderEvidenceRefs.ui_visible}
          </p>
          <div className="healthList">
            {securityHeaderEntries.map(([header, value]) => (
              <article className="healthItem" key={header}>
                <div>
                  <strong>{header}</strong>
                  <span>{value}</span>
                </div>
              </article>
            ))}
          </div>
          <div className="policyGrid">
            {(securityHeadersContract?.policy_checks ?? [
              "Every response includes X-Content-Type-Options=nosniff.",
              "Every response includes X-Frame-Options=DENY.",
              "Every response includes Referrer-Policy=no-referrer.",
            ]).map((check) => (
              <span key={check}>{check}</span>
            ))}
          </div>
        </section>

        <section className="panel" aria-label="Trace ID propagation contract">
          <header className="panelHeader">
            <h2>Trace ID Contract</h2>
            <button type="button" onClick={() => void loadTraceIdContract()}>
              Refresh Contract
            </button>
          </header>
          <div className="healthSummary">
            <div>
              <span>Contract</span>
              <strong>{traceIdContract?.contract_version ?? "trace-id-propagation-v1"}</strong>
            </div>
            <div>
              <span>Request Header</span>
              <strong>{traceIdContract?.request_header ?? "x-trace-id"}</strong>
            </div>
            <div>
              <span>Response Header</span>
              <strong>{traceIdContract?.response_header ?? "x-trace-id"}</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{traceIdEvidenceRefs.ui_visible}</strong>
            </div>
          </div>
          <p className="muted evidenceLine">
            Evidence: {traceIdEvidenceRefs.contract_visible} / {traceIdEvidenceRefs.header_roundtrip} /{" "}
            {traceIdEvidenceRefs.generated_trace_visible} / {traceIdEvidenceRefs.ui_visible}
          </p>
          <div className="policyGrid">
            {(traceIdContract?.policy_checks ?? [
              "If x-trace-id is supplied, the same value is returned in the response header.",
              "If no trace id is supplied, the API generates one with prefix trace-.",
              "Every response includes X-Superbrain-Trace-Contract.",
            ]).map((check) => (
              <span key={check}>{check}</span>
            ))}
          </div>
        </section>

        <section className="panel" aria-label="Cache control contract">
          <header className="panelHeader">
            <h2>Cache Control Contract</h2>
            <button type="button" onClick={() => void loadCacheControlContract()}>
              Refresh Contract
            </button>
          </header>
          <div className="healthSummary">
            <div>
              <span>Contract</span>
              <strong>{cacheControlContract?.contract_version ?? "cache-control-no-store-v1"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{cacheControlContract?.mode ?? "api_response_no_store_cache_control"}</strong>
            </div>
            <div>
              <span>Endpoint</span>
              <strong>/api/v1/cache/contract</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{cacheControlEvidenceRefs.ui_visible}</strong>
            </div>
          </div>
          <p className="muted evidenceLine">
            Evidence: {cacheControlEvidenceRefs.contract_visible} / {cacheControlEvidenceRefs.headers_enforced} /{" "}
            {cacheControlEvidenceRefs.sensitive_payload_no_store} / {cacheControlEvidenceRefs.ui_visible}
          </p>
          <div className="healthList">
            {cacheControlEntries.map(([header, value]) => (
              <article className="healthItem" key={header}>
                <div>
                  <strong>{header}</strong>
                  <span>{value}</span>
                </div>
              </article>
            ))}
          </div>
          <div className="policyGrid">
            {(cacheControlContract?.policy_checks ?? [
              "Every Agent API response includes Cache-Control no-store.",
              "Every Agent API response includes Pragma no-cache.",
              "Every Agent API response includes Expires 0.",
            ]).map((check) => (
              <span key={check}>{check}</span>
            ))}
          </div>
        </section>

        <section className="panel" aria-label="Request ID correlation contract">
          <header className="panelHeader">
            <h2>Request ID Contract</h2>
            <button type="button" onClick={() => void loadRequestIdContract()}>
              Refresh Contract
            </button>
          </header>
          <div className="healthSummary">
            <div>
              <span>Contract</span>
              <strong>{requestIdContract?.contract_version ?? "request-id-correlation-v1"}</strong>
            </div>
            <div>
              <span>Request Header</span>
              <strong>{requestIdContract?.request_header ?? "x-request-id"}</strong>
            </div>
            <div>
              <span>Endpoint</span>
              <strong>/api/v1/request/contract</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{requestIdEvidenceRefs.ui_visible}</strong>
            </div>
          </div>
          <p className="muted evidenceLine">
            Evidence: {requestIdEvidenceRefs.contract_visible} / {requestIdEvidenceRefs.header_roundtrip} /{" "}
            {requestIdEvidenceRefs.error_envelope_correlation} / {requestIdEvidenceRefs.audit_correlation} /{" "}
            {requestIdEvidenceRefs.audit_feed_visibility} / {requestIdEvidenceRefs.ui_visible}
          </p>
          <div className="policyGrid">
            {(requestIdContract?.policy_checks ?? [
              "If x-request-id is supplied, the same value is returned in the response header.",
              "Structured error envelopes include request_id and trace_id for support/audit correlation.",
              "Audited cost-export actions persist request_id and trace_id in audit_log.details.",
            ]).map((check) => (
              <span key={check}>{check}</span>
            ))}
          </div>
        </section>

        <section className="panel externalGatesPanel" aria-label="Layer Interface Contracts">
          <header className="panelHeader">
            <h2>Layer Interface Contracts</h2>
            <button type="button" onClick={() => void loadLayerInterfaceContract()}>
              Refresh Contract
            </button>
          </header>
          <div className="healthSummary">
            <div>
              <span>Contract</span>
              <strong>{layerInterfaceContract?.contract_version ?? "layer-interface-contracts-v1"}</strong>
            </div>
            <div>
              <span>Coverage</span>
              <strong>{layerInterfaceContract?.coverage ?? "7 runtime layer boundaries"}</strong>
            </div>
            <div>
              <span>Endpoint</span>
              <strong>{layerInterfaceContract?.endpoint ?? "GET /api/v1/layer-interfaces/contract"}</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{layerInterfaceContract?.evidence_ref ?? "layer_interface_contracts_visible"}</strong>
            </div>
          </div>
          <div className="gateList">
            {(layerInterfaceContract?.interfaces ?? []).map((item) => (
              <article className="gateItem gateReady" key={item.id}>
                <div>
                  <strong>{item.id}</strong>
                  <span>{item.status}</span>
                </div>
                <small>
                  {item.method} {item.path}
                </small>
                <p>
                  {item.source_layer} to {item.target_layer} · {item.transport} · {item.evidence_ref}
                </p>
              </article>
            ))}
          </div>
          <div className="policyGrid">
            {(layerInterfaceContract?.policy_checks ?? [
              "Every listed boundary declares method, path, request schema, response schema, status, and evidence_ref.",
              "External or write-capable interfaces remain dry-run or blocked until their gates are configured.",
              "No live provider calls, live MCP writes, or production deploys are claimed by this register.",
            ]).map((check) => (
              <span key={check}>{check}</span>
            ))}
          </div>
        </section>

        <section className="panel externalGatesPanel" aria-label="Task Assignment Queue Contract">
          <header className="panelHeader">
            <h2>Task Assignment Queue Contract</h2>
            <button type="button" onClick={() => void loadTaskAssignmentContract()}>
              Refresh Contract
            </button>
          </header>
          <div className="healthSummary">
            <div>
              <span>Contract</span>
              <strong>{taskAssignmentContract?.contract_version ?? "task-assignment-queue-contract-v1"}</strong>
            </div>
            <div>
              <span>Boundary</span>
              <strong>{taskAssignmentContract?.covered_boundary ?? "L2-L3 Agent API to Agent Pool"}</strong>
            </div>
            <div>
              <span>Queue</span>
              <strong>{taskAssignmentContract?.queue.queue_key ?? "tasks:agent:queue"}</strong>
            </div>
            <div>
              <span>Priority</span>
              <strong>
                {(taskAssignmentContract?.queue.priority_order ?? ["high", "mid", "low"]).join(" -> ")}
              </strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{taskAssignmentContract?.evidence_ref ?? "task_assignment_queue_contract_visible"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Intake</strong>
              <p>
                {taskAssignmentContract
                  ? `${taskAssignmentContract.intake.method} ${taskAssignmentContract.intake.path} via ${taskAssignmentContract.intake.mode}`
                  : "POST /internal/tasks via fail_closed_before_enqueue"}
              </p>
            </article>
            <article className="policyItem">
              <strong>Schema</strong>
              <p>
                {(taskAssignmentContract?.assignment_schema.required ?? [
                  "project_id",
                  "session_id",
                  "agent_type",
                  "task_type",
                  "task_description",
                ]).join(", ")}
              </p>
            </article>
            <article className="policyItem">
              <strong>Backpressure</strong>
              <p>
                {taskAssignmentContract
                  ? `${taskAssignmentContract.backpressure.queue_depth_source}; ${taskAssignmentContract.backpressure.stale_queue_rescue}`
                  : "Redis LLEN tasks:agent:queue; agent-worker finalizes stale queued records."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Priority Routing</strong>
              <p>
                {taskAssignmentContract
                  ? `${taskAssignmentContract.backpressure.priority_consumption}; ${Object.entries(
                      taskAssignmentContract.queue.priority_queues ?? {
                        high: "tasks:agent:queue:high",
                        mid: "tasks:agent:queue",
                        low: "tasks:agent:queue:low",
                      },
                    )
                      .map(([level, queue]) => `${level}:${queue}`)
                      .join(" ")}`
                  : "agent-worker BLPOP consumes high before mid before low."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Visibility</strong>
              <p>
                {(taskAssignmentContract?.queue.visibility_endpoints ?? [
                  "/api/v1/agents/status",
                  "/api/v1/tasks/recent",
                  "/api/v1/metrics",
                ]).join(", ")}
              </p>
            </article>
          </div>
          <p className="muted evidenceLine">
            Evidence:{" "}
            {(taskAssignmentContract?.evidence_refs ?? [
              "task_assignment_queue_contract_visible",
              "task_assignment_completed",
              "worker_status_regression_harness",
              "worker_stale_queued_finalized",
              "task_session_uuid_fail_closed_proof",
            ]).join(" / ")}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="Agent LLM Streaming Contract">
          <header className="panelHeader">
            <h2>Agent LLM Streaming Contract</h2>
            <button type="button" onClick={() => void loadAgentLlmStreamingContract()}>
              Refresh Contract
            </button>
          </header>
          <div className="healthSummary">
            <div>
              <span>Contract</span>
              <strong>{agentLlmStreamingContract?.contract_version ?? "agent-llm-streaming-contract-v1"}</strong>
            </div>
            <div>
              <span>Boundary</span>
              <strong>{agentLlmStreamingContract?.covered_boundary ?? "L3-L4 Agent Pool to LLM Gateway"}</strong>
            </div>
            <div>
              <span>Protocol</span>
              <strong>{agentLlmStreamingContract?.gateway_contract.protocol ?? "openai_compatible_sse"}</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{agentLlmStreamingContract?.evidence_ref ?? "agent_llm_streaming_contract_visible"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Agent Consumer</strong>
              <p>
                {agentLlmStreamingContract
                  ? `${agentLlmStreamingContract.agent_consumer.function} via ${agentLlmStreamingContract.agent_consumer.parser}`
                  : "call_llm_gateway_for_task via parse_llm_gateway_sse_line"}
              </p>
            </article>
            <article className="policyItem">
              <strong>Gateway Route</strong>
              <p>
                {agentLlmStreamingContract
                  ? `${agentLlmStreamingContract.gateway_contract.chat_completion_endpoint} after ${agentLlmStreamingContract.gateway_contract.routing_policy_endpoint}`
                  : "POST /llm/v1/chat/completions after POST /llm/api/v1/routing/policy/evaluate"}
              </p>
            </article>
            <article className="policyItem">
              <strong>Required State</strong>
              <p>
                {(agentLlmStreamingContract?.agent_consumer.required_state_fields ?? [
                  "llm_gateway_calls[].streaming_used",
                  "llm_gateway_calls[].stream_done_seen",
                  "llm_gateway_calls[].live_provider_calls",
                ]).join(", ")}
              </p>
            </article>
            <article className="policyItem">
              <strong>Response</strong>
              <p>
                {Object.entries(
                  agentLlmStreamingContract?.response_schema ?? {
                    "chunk.object": "chat.completion.chunk",
                    "terminal_frame": "data: [DONE]",
                    "live_provider_calls": "false in deterministic local mode",
                  },
                )
                  .map(([key, value]) => `${key}: ${value}`)
                  .join("; ")}
              </p>
            </article>
          </div>
          <p className="muted">
            Streaming frames:{" "}
            {(agentLlmStreamingContract?.gateway_contract.frames ?? [
              "data: {chat.completion.chunk}",
              "data: {chat.completion.chunk finish_reason=stop}",
              "data: [DONE]",
            ]).join(" | ")}
          </p>
          <p className="muted">
            Policy checks:{" "}
            {(agentLlmStreamingContract?.policy_checks ?? [
              "Agents request streaming through the LLM Gateway and never through direct provider URLs.",
              "Routing policy is evaluated before the streaming chat completion request.",
              "The Agent executor records stream_done_seen=true before claiming streaming completion.",
            ]).join(" / ")}
          </p>
          <p className="muted evidenceLine">
            Evidence:{" "}
            {(agentLlmStreamingContract?.evidence_refs ?? [
              "agent_llm_streaming_contract_visible",
              "llm_gateway_streaming_dry_run",
              "llm_routing_policy_primary_allowed",
            ]).join(" / ")}
          </p>
        </section>

        <section className="statusBand" aria-label="Run status">
          <div>
            <span>Status</span>
            <strong>{status}</strong>
          </div>
          <div>
            <span>Session</span>
            <strong>{lastRun?.session_id ?? "none"}</strong>
          </div>
          <div>
            <span>Task</span>
            <strong>{lastRun?.task_id ?? "none"}</strong>
          </div>
          <div>
            <span>Memory</span>
            <strong>{lastRun?.memory_id ?? "none"}</strong>
          </div>
        </section>

        <section className="panel progressPanel" aria-label="Project progress">
          <header className="panelHeader">
            <h2>Project Progress</h2>
            <button
              type="button"
              onClick={() =>
                void Promise.all([loadProjectProgress(), loadProjectProgressIntegrity(), loadProjectProgressCompletion()])
              }
            >
              Refresh
            </button>
          </header>
          <div className="progressHero">
            <div>
              <span>Total Project</span>
              <strong>{projectProgress ? `${projectProgress.overall_percent}%` : "loading"}</strong>
            </div>
            <p>{projectProgress?.truth_policy ?? "Evidence-based progress is loading."}</p>
          </div>
          <div className="progressIntegrity" aria-label="Project progress integrity">
            <div>
              <span>Progress Integrity</span>
              <strong>{projectProgressIntegrity?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>Manifest</span>
              <strong>{projectProgressIntegrity ? `${projectProgressIntegrity.manifest_overall_percent}%` : "loading"}</strong>
            </div>
            <div>
              <span>Computed</span>
              <strong>{projectProgressIntegrity ? `${projectProgressIntegrity.computed_overall_percent}%` : "loading"}</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{projectProgressIntegrity?.evidence_ref ?? "project_progress_integrity_runtime_proof"}</strong>
            </div>
            <p>
              {projectProgressMismatches.length
                ? `Blocked: ${projectProgressMismatches.join(", ")}`
                : projectProgressIntegrity?.contract_version ?? "project-progress-integrity-v1"}
            </p>
          </div>
          <div className="progressIntegrity" aria-label="100 percent completion contract">
            <div>
              <span>100% Contract</span>
              <strong>{projectProgressCompletion?.contract_version ?? "project-progress-100-percent-contract-v1"}</strong>
            </div>
            <div>
              <span>Status</span>
              <strong>{projectProgressCompletion?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>All to 100</span>
              <strong>{projectProgressCompletion?.can_set_all_to_100 ? "allowed" : "blocked"}</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{projectProgressCompletion?.evidence_ref ?? "project_progress_100_percent_gate_contract"}</strong>
            </div>
            <p>
              {projectProgressHardBlockers.length
                ? `Blocked by ${projectProgressHardBlockers.slice(0, 4).join(", ")}`
                : "Completion gate loading."}
            </p>
          </div>
          <div className="progressColumns">
            <section aria-label="Horizontal phase progress">
              <h3>Horizontal Phases</h3>
              <div className="horizontalProgress">
                {horizontalProgressItems.length ? (
                  horizontalProgressItems.map((item) => (
                  <article className="progressRow" key={item.id}>
                    <div>
                      <strong>{item.label}</strong>
                      <span>{item.percent}%</span>
                    </div>
                    <div className="progressTrack" aria-hidden="true">
                      <div className="progressFill" style={{ width: `${item.percent}%` }} />
                    </div>
                    <small title={item.status}>{compactProgressStatus(item.status)}</small>
                  </article>
                  ))
                ) : (
                  <p className="muted">Phase progress loading.</p>
                )}
              </div>
            </section>
            <section aria-label="Vertical architecture progress">
              <h3>Vertical Layers</h3>
              <div className="verticalProgress">
                {verticalProgressItems.length ? (
                  verticalProgressItems.map((item) => (
                  <article className="verticalItem" key={item.id}>
                    <strong>{item.percent}%</strong>
                    <div className="verticalLayerHeader">
                      <span>{item.label}</span>
                    </div>
                    <div className="verticalTrack" aria-hidden="true">
                      <div className="verticalFill" style={{ width: `${item.percent}%` }} />
                    </div>
                    <small title={item.status}>{compactProgressStatus(item.status)}</small>
                  </article>
                  ))
                ) : (
                  <p className="muted">Layer progress loading.</p>
                )}
              </div>
            </section>
          </div>
          <div className="progressFooter">
            <span>{projectProgress?.binding_document ?? "binding document loading"}</span>
            <span>Verified: {projectProgress?.last_verified ?? "loading"}</span>
          </div>
        </section>

        <section className="grid" aria-label="Agent status">
          {agents.map((agent) => (
            <article className="agent" key={agent.type}>
              <span>{agent.type}</span>
              <strong>{agent.status}</strong>
              <small>{agent.role ?? "Runtime profile loading"}</small>
              <small>Model: {agent.primary_model ?? "unknown"}</small>
              <small>
                Limits: {agent.max_execution_seconds ?? 0}s / {agent.max_output_tokens ?? 0} tokens /{" "}
                {agent.max_retries ?? agent.retries} retries
              </small>
              <small>Tools: {agent.allowed_tools?.join(", ") ?? "loading"}</small>
              <small>Human gates: {agent.human_review_required_actions?.join(", ") ?? "loading"}</small>
              <small>{agent.graceful_degradation ?? "Graceful degradation policy loading."}</small>
              <small>{agent.current_task ?? agent.latest_task_type ?? `retries ${agent.retries}`}</small>
              <small>Last task: {agent.latest_task_id ?? "none"}</small>
              <small>Last status: {agent.latest_status ?? "none"}</small>
              {agent.latest_result ? <small>{agent.latest_result}</small> : null}
              {agent.latest_error ? <small className="agentError">{agent.latest_error}</small> : null}
            </article>
          ))}
        </section>

        <section
          className="panel liveAgentPanel"
          aria-label="Live agent steering"
          data-evidence="live_agent_steering_ui_visible"
        >
          <header className="panelHeader">
            <h2>Live Agent Control</h2>
            <button
              type="button"
              onClick={() => void Promise.all([loadLiveAgents(), loadLiveAgentHistory(liveAgentId, projectId)])}
            >
              Refresh
            </button>
          </header>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Contract</strong>
              <p>{liveAgentContract?.contract_version ?? liveAgentStatus?.contract_version ?? "live-agent-steering-v1"}</p>
            </article>
            <article className="policyItem">
              <strong>Runtime</strong>
              <p>{liveAgentStatus?.runtime_source ?? liveAgentContract?.mode ?? "openai_responses_via_llm_gateway"}</p>
            </article>
            <article className="policyItem">
              <strong>Endpoint</strong>
              <p>{liveAgentContract?.steer_endpoint ?? "POST /api/v1/live-agents/steer"}</p>
            </article>
            <article className="policyItem">
              <strong>History</strong>
              <p>{liveAgentContract?.history_endpoint ?? "GET /api/v1/live-agents/history"}</p>
            </article>
            <article className="policyItem">
              <strong>Provider Calls</strong>
              <p>{liveAgentContract?.metadata_policy?.live_provider_calls_allowed ? "enabled" : "disabled"}</p>
            </article>
          </div>
          <form className="liveAgentForm" onSubmit={steerLiveAgent}>
            <label>
              <span>Agent</span>
              <select
                value={liveAgentId}
                onChange={(event) => {
                  const nextAgentId = event.target.value;
                  setLiveAgentId(nextAgentId);
                  void loadLiveAgentHistory(nextAgentId, projectId);
                }}
              >
                {liveAgentProfiles.length ? (
                  liveAgentProfiles.map((agent) => (
                    <option key={agent.agent_id} value={agent.agent_id}>
                      {agent.display_name} / {agent.execution_role}
                    </option>
                  ))
                ) : (
                  <option value="supervisor">Supervisor / planner</option>
                )}
              </select>
            </label>
            <label>
              <span>Message</span>
              <textarea
                value={liveAgentMessage}
                maxLength={10_000}
                onChange={(event) => setLiveAgentMessage(event.target.value)}
              />
              <small>
                {selectedLiveAgent?.agent_id ?? liveAgentId} | session{" "}
                {selectedLiveAgent?.has_session ? selectedLiveAgent.previous_response_id ?? "active" : "new"} |{" "}
                {liveAgentEvidenceRefs.ui_visible} / {liveAgentEvidenceRefs.security_guard}
              </small>
            </label>
            <div className="actions">
              <button type="submit" disabled={liveAgentSendStatus === "sending" || !liveAgentMessage.trim()}>
                Send
              </button>
              <button type="button" onClick={() => void resetLiveAgentSession()} disabled={!liveAgentProfiles.length}>
                Reset
              </button>
            </div>
          </form>
          <div className="liveAgentTranscript" aria-label="Live agent response">
            <strong>{liveAgentResponse?.agent_id ?? selectedLiveAgent?.agent_id ?? liveAgentId}</strong>
            <span>{liveAgentResponse?.status ?? liveAgentSendStatus}</span>
            <small>{liveAgentResponse?.model ?? selectedLiveAgent?.model ?? liveAgentStatus?.default_model ?? "loading"}</small>
            <p>{liveAgentResponse?.text ?? "No live-agent response in this browser session yet."}</p>
            <small>
              Audit: {liveAgentResponse?.audit_persisted ? "persisted" : "pending"} ·{" "}
              {liveAgentResponse?.audit_evidence_ref ?? "live_agent_steering_audit_persisted"}
            </small>
          </div>
          <div
            className="liveAgentHistory"
            aria-label="Live agent message history"
            data-evidence="live_agent_steering_history_visible"
          >
            <div className="historyHeader">
              <strong>Message History</strong>
              <button type="button" onClick={() => void loadLiveAgentHistory(liveAgentId, projectId)}>
                Refresh
              </button>
            </div>
            <small>
              {liveAgentHistory?.history_endpoint ?? "GET /api/v1/live-agents/history"} /{" "}
              {liveAgentHistory?.evidence_ref ?? "live_agent_steering_history_visible"} / {liveAgentHistoryStatus}
            </small>
            <div className="compactList">
              {liveAgentHistory?.events?.length ? (
                liveAgentHistory.events.map((event) => (
                  <article className="modelItem" key={event.id}>
                    <strong>
                      {event.agent_id} / {event.status ?? "unknown"}
                    </strong>
                    <small>
                      {event.created_at ?? "unknown time"} / {event.model ?? "unknown model"} /{" "}
                      {event.live_provider_calls ? "provider-call" : "live_provider_calls=false"}
                    </small>
                    <p>{event.response_preview || "No response preview stored."}</p>
                    <small>Response: {event.response_id ?? "none"}</small>
                    <small>Trace: {event.trace_id ?? "none"}</small>
                    <small>{event.evidence_ref ?? "live_agent_steering_audit_persisted"}</small>
                  </article>
                ))
              ) : (
                <p className="muted">No persisted live-agent history for this agent yet.</p>
              )}
            </div>
          </div>
          <p className="muted evidenceLine">
            Evidence: {liveAgentEvidenceRefs.contract_visible} / {liveAgentEvidenceRefs.ui_visible} /{" "}
            {liveAgentEvidenceRefs.security_guard} / {liveAgentEvidenceRefs.history_visible}
          </p>
        </section>

        <section className="panel taskPanel" aria-label="Autonomous coding team">
          <header className="panelHeader">
            <h2>Autonomous Coding Team</h2>
            <button
              type="button"
              onClick={() => void Promise.all([loadAutonomousTeamStatus(), loadAutonomousDispatchContract()])}
            >
              Refresh
            </button>
          </header>
          <div className="taskSummary">
            <span>Status</span>
            <strong>{autonomousTeam?.status ?? "loading"}</strong>
            <small>
              {(autonomousTeam?.team_mode ?? "logical team mode loading") +
                " | runtime " +
                (autonomousTeam?.runtime_source ?? "loading")}
            </small>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Dispatch</strong>
              <p>{autonomousTeam?.dispatch_id ?? "No dispatch recorded yet."}</p>
            </article>
            <article className="policyItem">
              <strong>Objective</strong>
              <p>{autonomousTeam?.objective ?? "Awaiting first autonomous dispatch."}</p>
            </article>
            <article className="policyItem">
              <strong>Queue</strong>
              <p>
                depth {autonomousTeam?.queue_depth ?? 0} | high {autonomousTeam?.queue_depth_by_priority?.high ?? 0} |
                mid {autonomousTeam?.queue_depth_by_priority?.mid ?? 0} | low{" "}
                {autonomousTeam?.queue_depth_by_priority?.low ?? 0}
              </p>
            </article>
            <article className="policyItem">
              <strong>Runtime Contract</strong>
              <p>{autonomousDispatchContract?.runtime_pool_contract_version ?? "Loading runtime pool contract."}</p>
            </article>
            <article className="policyItem">
              <strong>External Adapter</strong>
              <p>
                {autonomousTeam?.external_runtime?.provider ?? "none"} |{" "}
                {autonomousTeam?.external_runtime?.status ?? "disabled"}
              </p>
            </article>
          </div>
          <div className="modelList compactList">
            {autonomousTeam?.members?.length ? (
              autonomousTeam.members.map((member) => {
                const allowedTools = stringList(member.allowed_tools);
                const plannedCapabilities = stringList(member.planned_capabilities);
                const writeScope = stringList(member.write_scope);
                return (
                  <article className="modelItem" key={member.logical_role}>
                    <strong>
                      {member.logical_role} -&gt; {member.execution_agent_type}
                    </strong>
                    <small>
                      {member.latest_status ?? member.status} | priority {member.priority ?? "n/a"} | queue{" "}
                      {member.priority_level ?? "n/a"}
                    </small>
                    <small>Task: {member.task_type ?? "none"}</small>
                    <small>ID: {member.latest_task_id ?? member.task_id ?? "none"}</small>
                    <small>Tools: {allowedTools.length ? allowedTools.join(", ") : "none"}</small>
                    <small>
                      Capabilities: {plannedCapabilities.length ? plannedCapabilities.join(", ") : "none"}
                    </small>
                    <small>Write scope: {writeScope.length ? writeScope.join(", ") : "read-only"}</small>
                    <small>Trace: {member.trace_id ?? "none"}</small>
                    <small>Request: {member.request_id ?? "none"}</small>
                    {member.latest_result ? <small>{member.latest_result}</small> : null}
                    {member.latest_error ? <small className="agentError">{member.latest_error}</small> : null}
                  </article>
                );
              })
            ) : (
              <p className="muted">Autonomous team status not loaded yet.</p>
            )}
          </div>
          <small>
            Contract: {autonomousTeam?.contract_version ?? "loading"} / dispatch{" "}
            {autonomousTeam?.dispatch_contract_version ?? autonomousDispatchContract?.contract_version ?? "loading"}
          </small>
        </section>

        <section className="panel taskPanel" aria-label="Autonomous master plan">
          <header className="panelHeader">
            <h2>Autonomous Master Plan</h2>
            <button
              type="button"
              onClick={() => void Promise.all([loadAutonomousMasterPlan(), loadAutonomousMasterPlanContract()])}
            >
              Refresh
            </button>
          </header>
          <div className="taskSummary">
            <span>Status</span>
            <strong>{autonomousMasterPlan?.status ?? "loading"}</strong>
            <small>
              {(autonomousMasterPlan?.source_document ?? "master plan source loading") +
                " | runtime " +
                (autonomousMasterPlan?.runtime_source ?? "loading")}
            </small>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Overall</strong>
              <p>{autonomousMasterPlan?.overall_percent ?? 0}%</p>
            </article>
            <article className="policyItem">
              <strong>Integrity</strong>
              <p>{autonomousMasterPlan?.integrity_status ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Binding Document</strong>
              <p>{autonomousMasterPlan?.binding_document ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Contract</strong>
              <p>{autonomousMasterPlanContract?.contract_version ?? autonomousMasterPlan?.contract_version ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>External Adapter</strong>
              <p>
                {autonomousMasterPlan?.external_runtime_adapter?.provider ?? "none"} |{" "}
                {autonomousMasterPlan?.external_runtime_adapter?.status ?? "disabled"}
              </p>
            </article>
          </div>
          <div className="modelList compactList">
            <article className="modelItem">
              <strong>Next Concrete Steps</strong>
              {autonomousMasterPlan?.next_concrete_steps?.length ? (
                autonomousMasterPlan.next_concrete_steps.map((step) => <small key={step}>{step}</small>)
              ) : (
                <small>Next steps loading.</small>
              )}
            </article>
            <article className="modelItem">
              <strong>Hard Constraints</strong>
              {autonomousMasterPlan?.hard_constraints?.length ? (
                autonomousMasterPlan.hard_constraints.map((constraint) => <small key={constraint}>{constraint}</small>)
              ) : (
                <small>Constraints loading.</small>
              )}
            </article>
            <article className="modelItem">
              <strong>Running Containers</strong>
              {autonomousMasterPlan?.running_containers?.length ? (
                autonomousMasterPlan.running_containers.map((container) => <small key={container}>{container}</small>)
              ) : (
                <small>Container state loading.</small>
              )}
            </article>
            <article className="modelItem">
              <strong>Roles</strong>
              <small>{autonomousMasterPlan?.logical_roles?.join(", ") ?? "loading"}</small>
              <small>{autonomousMasterPlan?.dispatch_endpoints?.join(" | ") ?? "dispatch endpoints loading"}</small>
            </article>
          </div>
        </section>

        <section className="panel taskPanel" aria-label="Persisted agent roster">
          <header className="panelHeader">
            <h2>Persisted Agent Roster</h2>
            <button
              type="button"
              onClick={() => void Promise.all([loadAutonomousAgentRoster(), loadAutonomousAgentRosterContract()])}
            >
              Refresh
            </button>
          </header>
          <div className="taskSummary">
            <span>Status</span>
            <strong>{autonomousAgentRoster?.status ?? "loading"}</strong>
            <small>
              {(autonomousAgentRoster?.source_document ?? "roster source loading") +
                " | runtime " +
                (autonomousAgentRoster?.runtime_source ?? "loading")}
            </small>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Role Count</strong>
              <p>{autonomousAgentRoster?.role_count ?? 0}</p>
            </article>
            <article className="policyItem">
              <strong>Live Slots</strong>
              <p>{autonomousAgentRoster?.operating_core?.default_live_mode?.live_slots?.join(", ") ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Parked Slot</strong>
              <p>{autonomousAgentRoster?.operating_core?.default_live_mode?.parked_slot ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Contract</strong>
              <p>{autonomousAgentRosterContract?.contract_version ?? autonomousAgentRoster?.contract_version ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Bindings</strong>
              <p>
                LangGraph {autonomousAgentRoster?.runtime_bindings?.langgraph?.status ?? "loading"} | CrewAI{" "}
                {autonomousAgentRoster?.runtime_bindings?.crewai?.status ?? "loading"} | Prometheus{" "}
                {autonomousAgentRoster?.runtime_bindings?.prometheus?.status ?? "loading"}
              </p>
            </article>
          </div>
          <div className="modelList compactList">
            <article className="modelItem">
              <strong>Validated Startable</strong>
              {(autonomousAgentRoster?.launcher_status?.validated_startable?.length
                ? autonomousAgentRoster.launcher_status.validated_startable
                : ["loading"]).map((item) => (
                <small key={item}>{item}</small>
              ))}
            </article>
            <article className="modelItem">
              <strong>Runtime Bindings</strong>
              <small>
                LangGraph: {autonomousAgentRoster?.runtime_bindings?.langgraph?.transport ?? "loading"} /{" "}
                {autonomousAgentRoster?.runtime_bindings?.langgraph?.checkpointing ?? "loading"}
              </small>
              <small>
                Prometheus: {autonomousAgentRoster?.runtime_bindings?.prometheus?.endpoint ?? "loading"}
              </small>
              <small>
                External Adapter: {autonomousAgentRoster?.runtime_bindings?.external_adapter?.provider ?? "none"} |{" "}
                {autonomousAgentRoster?.runtime_bindings?.external_adapter?.status ?? "disabled"}
              </small>
              {autonomousAgentRoster?.runtime_bindings?.external_adapter?.agents?.length ? (
                <small>
                  External Agents: {autonomousAgentRoster.runtime_bindings.external_adapter.agents.join(", ")}
                </small>
              ) : null}
            </article>
            <article className="modelItem">
              <strong>Startup Protocol</strong>
              {autonomousAgentRoster?.startup_protocol?.length ? (
                autonomousAgentRoster.startup_protocol.map((step) => <small key={step}>{step}</small>)
              ) : (
                <small>Startup protocol loading.</small>
              )}
            </article>
            <article className="modelItem">
              <strong>Persisted Roles</strong>
              {autonomousAgentRoster?.roles?.length ? (
                autonomousAgentRoster.roles.slice(0, 8).map((role) => (
                  <small key={role.id}>
                    {role.id}: {role.status ?? "unknown"}
                    {role.metadata?.blocker ? ` | ${role.metadata.blocker}` : ""}
                  </small>
                ))
              ) : (
                <small>Role roster loading.</small>
              )}
            </article>
          </div>
        </section>

        <section className="panel taskPanel" aria-label="Task queue">
          <header className="panelHeader">
            <h2>Task Queue</h2>
            <button type="button" onClick={() => void loadRecentTasks()}>
              Refresh
            </button>
          </header>
          <div className="taskSummary">
            <span>Queue depth</span>
            <strong>{taskQueueDepth}</strong>
            <small>Done Validation: implemented, tested, integrated, reported, logged</small>
          </div>
          <div className="taskList">
            {recentTasks.length ? (
              recentTasks.map((task) => (
                <article className="taskItem" key={task.task_id}>
                  <div>
                    <strong>{task.agent_type}</strong>
                    <span className={`taskState task-${task.status}`}>{task.status}</span>
                  </div>
                  <small>{task.task_type}</small>
                  <small>{task.task_id}</small>
                  <small>
                    Retries: {task.retry_count} / {task.max_retries}
                  </small>
                  <p>{task.task_description}</p>
                  <section className="doneValidation" aria-label="Done validation">
                    <strong>Done Validation</strong>
                    <div className="doneBadges">
                      {doneValidationKeys.map((key) => (
                        <span
                          className={`doneBadge ${task.done_validation?.[key] ? "doneBadge-pass" : "doneBadge-pending"}`}
                          key={key}
                        >
                          {key}: {task.done_validation?.[key] ? "pass" : "pending"}
                        </span>
                      ))}
                    </div>
                    <small>Envelope: {task.result_envelope ? "attached" : "pending"}</small>
                  </section>
                  {task.result ? <small>{task.result}</small> : null}
                  {task.error ? <small className="agentError">{task.error}</small> : null}
                </article>
              ))
            ) : (
              <p className="muted">No task records yet.</p>
            )}
          </div>
        </section>

        <section className="panel taskPolicyPanel" aria-label="Task policy gate">
          <header className="panelHeader">
            <h2>Task Policy Gate</h2>
            <button type="button" onClick={() => void loadTaskPolicy()}>
              Refresh
            </button>
          </header>
          <div className="policySummary">
            <div>
              <span>Policy</span>
              <strong>{taskPolicy?.policy_version ?? "loading"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{taskPolicy?.mode ?? "loading"}</strong>
            </div>
            <div>
              <span>Blocked actions</span>
              <strong>{taskPolicy ? stringList(taskPolicy.required_blocked_actions).length : "loading"}</strong>
            </div>
            <div>
              <span>Allowed tools</span>
              <strong>{taskPolicy ? stringList(taskPolicy.allowed_tools).length : "loading"}</strong>
            </div>
            <div>
              <span>Profile gates</span>
              <strong>{taskPolicy?.profile_gates?.length ?? "loading"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Required Blocks</strong>
              <p>
                {taskPolicy
                  ? stringList(taskPolicy.required_blocked_actions).join(", ") || "none"
                  : "Loading policy blocks."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Allowed Tools</strong>
              <p>
                {taskPolicy ? stringList(taskPolicy.allowed_tools).join(", ") || "none" : "Loading tool allowlist."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Write Scope Rule</strong>
              <p>
                {taskPolicy
                  ? `${taskPolicy.write_scope_required_for?.agent_type ?? "write-scoped"} tasks using ${stringList(taskPolicy.write_scope_required_for?.tools).join(
                      ", ",
                    ) || "write tools"} require explicit write_scope.`
                  : "Loading write-scope rule."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Human Gate</strong>
              <p>{taskPolicy?.devops_human_gate ?? "Loading human-review gate."}</p>
            </article>
            <article className="policyItem">
              <strong>Profile Contract</strong>
              <p>{taskPolicy?.profile_contract_version ?? "Loading profile-gated runtime contract."}</p>
            </article>
          </div>
          {taskPolicy?.profile_gates?.length ? (
            <div className="modelList compactList">
              {taskPolicy.profile_gates.map((gate) => (
                <article key={gate.agent_type} className="modelItem">
                  <strong>{gate.agent_type}</strong>
                  <small>
                    {gate.max_retries} retries | {gate.max_execution_seconds}s max
                  </small>
                  <small>Tools: {stringList(gate.allowed_tools).join(", ") || "none"}</small>
                  <small>Human gates: {stringList(gate.human_review_required_actions).join(", ") || "none"}</small>
                </article>
              ))}
            </div>
          ) : null}
        </section>

        <section className="panel escalationPanel" aria-label="Escalations">
          <header className="panelHeader">
            <h2>Escalations</h2>
            <button type="button" onClick={() => void loadEscalations()}>
              Refresh
            </button>
          </header>
          <div className="escalationList">
            {escalations.length ? (
              escalations.map((event) => (
                <article className="escalationItem" key={event.id}>
                  <div>
                    <strong>{String(event.details.agent_type ?? event.event_type)}</strong>
                    <span className={`severity severity-${event.severity}`}>{event.severity}</span>
                  </div>
                  <small>{event.created_at ?? "no timestamp"}</small>
                  <small>Task: {String(event.details.task_id ?? "none")}</small>
                  <small>
                    Retries: {String(event.details.retry_count ?? "0")} / {String(event.details.max_retries ?? "0")}
                  </small>
                  <small>Trace: {String(event.trace_id ?? event.details.trace_id ?? event.details.run_id ?? "none")}</small>
                  <small>Evidence: {escalationEvidence(event)}</small>
                  <p>{escalationDetail(event)}</p>
                </article>
              ))
            ) : (
              <p className="muted">No escalations yet.</p>
            )}
          </div>
        </section>

        <section className="panel modelPanel" aria-label="Model matrix">
          <header className="panelHeader">
            <h2>Model Matrix</h2>
            <button type="button" onClick={() => void loadModelCapabilities()}>
              Refresh
            </button>
          </header>
          <div className="modelSummary">
            <span>Memory context cap</span>
            <strong>{modelCapabilities ? `${modelCapabilities.memory_injection_budget_percent_max}%` : "loading"}</strong>
          </div>
          <div className="modelSummary">
            <span>Agent profiles</span>
            <strong>{modelCapabilities?.agent_profiles?.length ?? 0} runtime contracts</strong>
          </div>
          <div className="modelList">
            {modelCapabilities?.routes?.length ? (
              modelCapabilities.routes.map((route) => {
                const fallbacks = stringList(route.fallbacks);
                return (
                  <article className="modelItem" key={route.agent_type}>
                    <div>
                      <strong>{route.agent_type}</strong>
                      <span>{route.cost_tier}</span>
                    </div>
                    <p>{route.primary}</p>
                    <small>Fallbacks: {fallbacks.length ? fallbacks.join(" -> ") : "none"}</small>
                    <small>Max output: {route.max_output_tokens}</small>
                    <small>Memory budget: {route.memory_injection_budget_percent}%</small>
                    <small>{route.supports_streaming ? "Streaming ready" : "No streaming"}</small>
                    <small>{route.configured_only ? "Configured only" : "Live verified"}</small>
                  </article>
                );
              })
            ) : (
              <p className="muted">Model routes loading.</p>
            )}
          </div>
        </section>

        <section className="panel modelPanel" aria-label="LLM gateway">
          <header className="panelHeader">
            <h2>LLM Gateway</h2>
            <button type="button" onClick={() => void loadLlmGateway()}>
              Refresh
            </button>
          </header>
          <div className="modelSummary">
            <span>{llmGateway?.service ?? "llm-gateway"}</span>
            <strong>{llmGateway?.status ?? "loading"}</strong>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Mode</strong>
              <p>{llmGateway?.mode ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Provider Calls</strong>
              <p>{llmGateway?.live_provider_calls ? "live provider calls active" : "live_provider_calls=false"}</p>
            </article>
            <article className="policyItem">
              <strong>Runtime Guard</strong>
              <p>{llmGateway?.runtime_guard_parity?.status ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Guard Version</strong>
              <p>{llmGateway?.runtime_guard_parity?.contract_version ?? "llm-runtime-guard-parity-v1"}</p>
            </article>
            <article className="policyItem">
              <strong>HF Router Contract</strong>
              <p>{llmGateway?.hf_router?.available ? "HF token configured" : "router token absent"}</p>
            </article>
            <article className="policyItem">
              <strong>Routing Resolver</strong>
              <p>{llmGateway?.routing_resolver ? "deterministic route selected" : "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Routing Policy</strong>
              <p>{llmGateway?.routing_policy_contract?.contract_version ?? "llm-routing-policy-v1"}</p>
            </article>
            <article className="policyItem">
              <strong>Policy Decisions</strong>
              <p>{llmGateway?.routing_policy_contract?.decisions?.join(", ") ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Selected Model</strong>
              <p>{llmGateway?.routing_resolution?.selected_model ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Selected Provider</strong>
              <p>{llmGateway?.routing_resolution?.selected_provider ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Route Reason</strong>
              <p>{llmGateway?.routing_resolution?.reason ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Provider Health</strong>
              <p>{llmGateway?.routing_resolution?.provider_health?.status ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Streaming Contract</strong>
              <p>{llmGateway?.streaming_contract?.protocol ?? llmGateway?.streaming_protocol ?? "loading"}</p>
            </article>
            <article className="policyItem">
              <strong>Models</strong>
              <p>{llmGateway ? `${llmGateway.models_configured} configured routes` : "loading"}</p>
            </article>
          </div>
          <p className="muted">
            Fallback chain: {llmGateway?.routing_resolution?.fallback_chain?.join(" -> ") ?? "loading"}
          </p>
          <p className="muted">
            Provider chain: {llmGateway?.routing_resolution?.provider_chain?.join(" -> ") ?? "loading"}
          </p>
          <p className="muted">
            Streaming frames: {llmGateway?.streaming_contract?.frames?.join(" | ") ?? "loading"}
          </p>
          <p className="muted">
            Runtime guard parity: {llmGateway?.runtime_guard_parity?.endpoint ?? "GET /llm/api/v1/runtime/guard-parity"} /{" "}
            {llmGateway?.runtime_guard_parity?.evidence_ref ?? "llm_runtime_guard_parity_visible"} /{" "}
            {(llmGateway?.runtime_guard_parity?.guard_matrix ?? [])
              .map((guard) => `${guard.guard}:${guard.status}`)
              .join(" | ") || "loading"}
          </p>
          <p className="muted">
            Policy evidence:{" "}
            {llmGateway?.routing_policy_contract?.evidence_refs?.contract_visible ??
              "llm_routing_policy_contract_visible"}{" "}
            /{" "}
            {llmGateway?.routing_policy_contract?.evidence_refs?.direct_provider_blocked ??
              "llm_routing_policy_direct_provider_blocked"}{" "}
            /{" "}
            {llmGateway?.routing_policy_contract?.evidence_refs?.fallback_limit_blocked ??
              "llm_routing_policy_fallback_limit_blocked"}{" "}
            /{" "}
            {llmGateway?.routing_policy_contract?.evidence_refs?.retry_limit_blocked ??
              "llm_routing_policy_retry_limit_blocked"}{" "}
            /{" "}
            {llmGateway?.routing_policy_contract?.evidence_refs?.sensitive_cache_blocked ??
              "llm_routing_policy_sensitive_cache_blocked"}
          </p>
          <div className="modelList">
            {llmGateway?.provider_snapshot?.providers?.length ? (
              llmGateway.provider_snapshot.providers.map((provider) => {
                const providerModels = provider.configured_models ?? provider.models ?? provider.visible_models_sample ?? [];
                const backoffSeconds = provider.backoff_seconds ?? [];
                return (
                  <article className="modelItem" key={provider.provider}>
                    <div>
                      <strong>{provider.provider}</strong>
                      <span>{provider.status}</span>
                    </div>
                    <small>Models: {providerModels.length ? providerModels.join(", ") : "not advertised"}</small>
                    <small>Visible via router: {provider.model_count_visible ?? "unknown"}</small>
                    <small>Backoff: {backoffSeconds.length ? `${backoffSeconds.join("s -> ")}s` : "not required"}</small>
                    <small>Reset: {provider.reset_after_seconds ?? "not required"}</small>
                    <small>{provider.non_claim ?? "Provider health is loaded from the current gateway snapshot."}</small>
                  </article>
                );
              })
            ) : (
              <p className="muted">Provider health snapshot loading.</p>
            )}
          </div>
          <p className="muted">{llmGateway?.non_claims?.[0] ?? "No live LLM provider proof is claimed."}</p>
        </section>

        <section className="panel graphPanel" aria-label="LangGraph progress">
          <header className="panelHeader">
            <h2>LangGraph Progress</h2>
            <button type="button" onClick={() => void startPhase2RuntimeGraph()} disabled={graphStatus === "streaming"}>
              Start Phase 2 Runtime
            </button>
            <button type="button" onClick={() => void runLangGraphProgress()} disabled={graphStatus === "streaming"}>
              Stream
            </button>
          </header>
          <div className="graphSummary">
            <div>
              <span>Status</span>
              <strong>{graphStatus}</strong>
            </div>
            <div>
              <span>Events</span>
              <strong>{graphEvents.length}</strong>
            </div>
            <div>
              <span>Latest node</span>
              <strong>{latestGraphEvent?.node_name ?? latestGraphEvent?.node ?? "none"}</strong>
            </div>
            <div>
              <span>Checkpointing</span>
              <strong>{graphEvents.find((item) => item.checkpointing)?.checkpointing ?? "pending"}</strong>
            </div>
            <div>
              <span>Phase 2 Runtime</span>
              <strong>{String(phase2RuntimeStart?.status ?? phase2RuntimeContract?.contract_version ?? "not-started")}</strong>
            </div>
            <div>
              <span>Runtime Thread</span>
              <strong>{String(phase2RuntimeStart?.thread_id ?? phase2RuntimeState?.session_id ?? "none")}</strong>
            </div>
            <div>
              <span>Runtime Evidence</span>
              <strong>{phase2RuntimeEvidenceRefs.includes("phase2_runtime_graph_started") ? "phase2_runtime_graph_started" : "pending"}</strong>
            </div>
            <div>
              <span>Runtime Gates</span>
              <strong>{String(phase2RuntimeStart?.live_provider_calls ?? false) === "false" ? "live gates closed" : "check"}</strong>
            </div>
            <div>
              <span>Runtime Runs</span>
              <strong>{phase2RuntimeRuns.length}</strong>
            </div>
            <div>
              <span>Latest Runtime Status</span>
              <strong>{String(latestPhase2RuntimeRun?.status ?? "none")}</strong>
            </div>
            <div>
              <span>Role Summaries</span>
              <strong>{String(latestPhase2RuntimeRun?.role_summary_count ?? 0)}</strong>
            </div>
            <div>
              <span>SSE Contract</span>
              <strong>
                {String(
                  (phase2RuntimeContract?.sse_event_contract as Record<string, unknown> | undefined)?.contract_version ??
                    latestGraphEvent?.contract_version ??
                    "phase2-sse-event-contract-v1",
                )}
              </strong>
            </div>
            <div>
              <span>SSE Events</span>
              <strong>
                {(
                  ((phase2RuntimeContract?.sse_event_contract as Record<string, unknown> | undefined)
                    ?.required_event_types as string[] | undefined) ??
                  latestGraphEvent?.required_event_types ??
                  ["heartbeat", "agent_status", "error", "done"]
                ).join(", ")}
              </strong>
            </div>
          </div>
          <p className="muted">
            Phase 2 Runtime Contract: {String(phase2RuntimeContract?.contract_version ?? "phase2-runtime-v1 loading")} via{" "}
            {String(phase2RuntimeContract?.start_endpoint ?? "POST /api/v1/phase2/runtime/start")} and{" "}
            {String(phase2RuntimeContract?.runs_endpoint ?? "GET /api/v1/phase2/runtime/runs")} with{" "}
            phase2_runtime_run_status_visible
          </p>
          <p className="muted">
            SSE Event Contract:{" "}
            {String(
              (phase2RuntimeContract?.sse_event_contract as Record<string, unknown> | undefined)?.evidence_ref ??
                latestGraphEvent?.evidence_ref ??
                "phase2_sse_event_contract_proof",
            )}{" "}
            via {String(phase2RuntimeContract?.stream_endpoint ?? "POST /api/v1/orchestrator/dry-run/stream")}
          </p>
          <div className="graphList compactList">
            {phase2RuntimeRuns.length ? (
              phase2RuntimeRuns.slice(0, 3).map((run) => (
                <article className="graphItem" key={String(run.thread_id ?? run.run_id)}>
                  <div>
                    <strong>{String(run.status ?? "unknown")}</strong>
                    <span>{String(run.thread_id ?? "no-thread")}</span>
                  </div>
                  <small>{String(run.aggregation_evidence_ref ?? "pending-aggregation")}</small>
                  <small>Roles: {String(run.role_summary_count ?? 0)}</small>
                </article>
              ))
            ) : (
              <p className="muted">No Phase 2 runtime run status yet.</p>
            )}
          </div>
          <div className="graphList">
            {graphEvents.length ? (
              graphEvents.map((item, index) => (
                <article className="graphItem" key={`${item.event}-${index}`}>
                  <div>
                    <strong>{item.node_name ?? item.node ?? item.event}</strong>
                    <span>{item.event}</span>
                  </div>
                  <small>{item.status ?? "updated"}</small>
                  <small>Thread: {item.thread_id ?? "none"}</small>
                </article>
              ))
            ) : (
              <p className="muted">No LangGraph stream yet.</p>
            )}
          </div>
        </section>

        <section className="panel agentActivityPanel" aria-label="Agent activity">
          <header className="panelHeader">
            <h2>Agent Activity</h2>
            <button
              type="button"
              onClick={() => void Promise.all([loadAgentActivityContract(), loadAgentActivityEvents(), loadAuditEvents()])}
            >
              Refresh
            </button>
          </header>
          <div className="policySummary">
            <div>
              <span>Contract</span>
              <strong>{agentActivityContract?.contract_version ?? "agent-activity-trace-v1"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{agentActivityContract?.mode ?? "audit_log_backed_trace_view"}</strong>
            </div>
            <div>
              <span>Langfuse</span>
              <strong>{agentActivityLangfuse?.public_url_configured ? "configured" : "auth proxy required"}</strong>
            </div>
            <div>
              <span>Sources</span>
              <strong>{agentActivityContract ? agentActivitySourceEndpoints.length : "loading"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Trace Deep-Link</strong>
              <p>{agentActivityLangfuse?.deep_link_template ?? "/observability/langfuse/trace/{trace_id}"}</p>
              <small>Evidence: agent_activity_trace_link_template / langfuse_auth_proxy_required</small>
            </article>
            <article className="policyItem">
              <strong>Source Endpoints</strong>
              <p>{agentActivitySourceEndpoints.length ? agentActivitySourceEndpoints.join(" / ") : "GET /api/v1/audit/recent?limit=50"}</p>
            </article>
            <article className="policyItem">
              <strong>Filters</strong>
              <p>{agentActivityFilters.length ? agentActivityFilters.join(", ") : "agent_type, event_type, severity, time_range, trace_id"}</p>
            </article>
            <article className="policyItem">
              <strong>Evidence</strong>
              <p>{Object.values(agentActivityEvidenceRefs).join(" / ")}</p>
            </article>
            <article className="policyItem perRoleSummaryContract">
              <strong>Per-role Summaries</strong>
              <p>per_role_results, role_summary_count, partial_failure, partial_failure_reasons</p>
              <small>Evidence: agent_activity_per_role_results_visible</small>
            </article>
          </div>
          <div className="gateList">
            {(agentActivityContract?.policy_checks ?? [
              "trace_id_visible",
              "langfuse_access_requires_auth_proxy",
              "audit_log_is_source_of_truth",
              "no_public_langfuse_without_auth",
              "per_role_results_visible",
            ]).map((check) => (
              <article className="gateItem gateReady" key={check}>
                <div>
                  <strong>Activity Check</strong>
                  <span>enforced</span>
                </div>
                <p>{check}</p>
              </article>
            ))}
          </div>
          <div className="activityFilterBar" aria-label="Agent activity filters">
            <label>
              <span>Severity</span>
              <select value={activitySeverityFilter} onChange={(event) => setActivitySeverityFilter(event.target.value)}>
                <option value="">all</option>
                <option value="info">info</option>
                <option value="warning">warning</option>
                <option value="critical">critical</option>
              </select>
            </label>
            <label>
              <span>Event</span>
              <input
                value={activityEventTypeFilter}
                onChange={(event) => setActivityEventTypeFilter(event.target.value)}
                placeholder="task_policy_blocked"
              />
            </label>
            <label>
              <span>Agent</span>
              <input
                value={activityAgentFilter}
                onChange={(event) => setActivityAgentFilter(event.target.value)}
                placeholder="planner"
              />
            </label>
            <label>
              <span>Trace</span>
              <input
                value={activityTraceFilter}
                onChange={(event) => setActivityTraceFilter(event.target.value)}
                placeholder="trace id"
              />
            </label>
            <button type="button" onClick={() => void loadAgentActivityEvents()}>
              Apply
            </button>
          </div>
          <div className="auditList">
            {agentActivityEvents.length ? (
              agentActivityEvents.map((event) => (
                <article className="auditItem activityItem" key={`activity-${event.id}`}>
                  <div>
                    <strong>{event.event_type}</strong>
                    <span className={`severity severity-${event.severity}`}>{event.severity}</span>
                  </div>
                  <small>Agent: {event.agent_type}</small>
                  <small>Trace: {event.trace_id}</small>
                  <small>Langfuse: {event.langfuse_trace_url}</small>
                  <small>Session: {event.session_id ?? "none"}</small>
                  {(event.per_role_results?.length ?? 0) > 0 ? (
                    <div className="perRoleSummary">
                      <strong>Per-role Summaries</strong>
                      <small>
                        role_summary_count={event.role_summary_count ?? event.per_role_results?.length ?? 0} ·
                        partial_failure={String(event.partial_failure ?? false)} ·{" "}
                        {event.aggregation_evidence_ref ?? "agent_result_aggregation_complete"}
                      </small>
                      <div className="perRoleGrid">
                        {event.per_role_results?.map((roleResult) => (
                          <article className="perRoleItem" key={`${event.id}-${roleResult.role}`}>
                            <strong>{roleResult.role}</strong>
                            <span>{roleResult.status}</span>
                            <small>Summary: {roleResult.summary ?? "No summary provided."}</small>
                            <small>MCP: {roleResult.mcp_status ?? "unknown"}</small>
                            <small>{roleResult.mcp_evidence_ref ?? "mcp_evidence_pending"}</small>
                          </article>
                        ))}
                      </div>
                      {(event.partial_failure_reasons?.length ?? 0) > 0 ? (
                        <small>Reasons: {event.partial_failure_reasons?.join(", ")}</small>
                      ) : null}
                    </div>
                  ) : null}
                </article>
              ))
            ) : (
              <p className="muted">No agent activity matches the active filters.</p>
            )}
          </div>
          <p className="infraNote">
            {agentActivityNonClaims.length
              ? agentActivityNonClaims.join(" ")
              : "This contract does not claim public unauthenticated Langfuse access."}
          </p>
        </section>

        <section className="panel rotationPanel" aria-label="Rotation events">
          <header className="panelHeader">
            <h2>Rotation Events</h2>
            <button type="button" onClick={() => void loadRotationEvents()}>
              Refresh
            </button>
          </header>
          <div className="rotationList">
            {rotationEvents.length ? (
              rotationEvents.map((event) => (
                <article className="rotationItem" key={event.id}>
                  <div>
                    <strong>{event.details.agent ?? "agent"}</strong>
                    <span className={`severity severity-${event.severity}`}>{event.details.reason ?? event.severity}</span>
                  </div>
                  <p>
                    {event.details.from_provider ?? "unknown"} to {event.details.to_provider ?? "unknown"}
                  </p>
                  <small>
                    Models: {event.details.from_model ?? "n/a"} to {event.details.to_model ?? "n/a"}
                  </small>
                  <small>
                    Fallback #{event.details.fallback_index ?? 1}; policy:{" "}
                    {event.details.routing_policy_decision ?? "allow_fallback"}
                  </small>
                  <small>
                    Cost: {event.details.cost_metadata?.estimated_cost_cents ?? 0} cents; live providers:{" "}
                    {event.details.live_provider_calls ? "true" : "false"}
                  </small>
                  <small>Evidence: {event.details.evidence_ref ?? "provider_fallback_structured_event"}</small>
                  <small>{event.created_at ?? "no timestamp"}</small>
                  <small>Session: {event.session_id ?? "none"}</small>
                  <small>Trace: {event.details.trace_id ?? "none"}</small>
                </article>
              ))
            ) : (
              <p className="muted">No provider rotations yet.</p>
            )}
          </div>
        </section>

        <section className="panel healthPanel" aria-label="System health">
          <header className="panelHeader">
            <h2>System Health</h2>
            <button type="button" onClick={() => void loadHealth()}>
              Refresh
            </button>
          </header>
          <div className="healthSummary">
            <div>
              <span>Overall</span>
              <strong>{health?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>API</span>
              <strong>{health?.service ?? "loading"}</strong>
            </div>
            <div>
              <span>Tables</span>
              <strong>{health?.services?.postgres?.required_tables ?? "loading"}</strong>
            </div>
            <div>
              <span>Budget Gate</span>
              <strong>{health?.budget?.allow_new_calls === false ? "blocked" : "open"}</strong>
            </div>
          </div>
          <div className="healthList">
            {health ? (
              Object.entries(health.services).map(([name, service]) => (
                <article className="healthItem" key={name}>
                  <div>
                    <strong>{name}</strong>
                    <span className={`healthState health-${service.status}`}>{service.status}</span>
                  </div>
                  {service.database ? <small>Database: {service.database}</small> : null}
                  {service.extensions?.length ? <small>Extensions: {service.extensions.join(", ")}</small> : null}
                  {service.service ? <small>Service: {service.service}</small> : null}
                  {service.error ? <small className="agentError">{service.error}</small> : null}
                </article>
              ))
            ) : (
              <p className="muted">Health loading.</p>
            )}
          </div>
        </section>

        <section className="panel historyPanel" aria-label="Recent runs">
          <header className="panelHeader">
            <h2>Recent Runs</h2>
            <div className="headerActions">
              <button
                type="button"
                disabled={!recentSessions.length}
                onClick={() => recentSessions[0] && void openSessionHistory(recentSessions[0].session_id)}
              >
                Open Latest
              </button>
              <button type="button" onClick={() => void loadRecentSessions()}>
                Refresh
              </button>
            </div>
          </header>
          <div className="historyList">
            {recentSessions.length ? (
              recentSessions.map((session) => (
                <article className="historyItem" key={session.session_id}>
                  <div>
                    <strong>{session.project_id}</strong>
                    <small>{session.started_at ?? "no timestamp"}</small>
                  </div>
                  <p>{session.prompt ?? "No prompt stored."}</p>
                  <small>Task: {session.latest_task_id ?? "none"}</small>
                  <small>{session.assistant_result ?? "No worker result yet."}</small>
                  <div className="historyActions">
                    <small>Session: {session.session_id}</small>
                    <button type="button" onClick={() => void openSessionHistory(session.session_id)}>
                      Open
                    </button>
                  </div>
                </article>
              ))
            ) : (
              <p className="muted">No recent runs yet.</p>
            )}
          </div>
          <div className="historyDetail" aria-label="Opened run history">
            <div className="historyDetailHeader">
              <div>
                <span>Opened Run</span>
                <strong>{selectedSessionHistory?.session.session_id ?? "none"}</strong>
              </div>
              <span>{sessionHistoryStatus}</span>
            </div>
            {selectedSessionHistory ? (
              <>
                <div className="historyStateGrid">
                  <div>
                    <span>Project</span>
                    <strong>{selectedSessionHistory.session.project_id}</strong>
                  </div>
                  <div>
                    <span>Progress</span>
                    <strong>{selectedSessionHistory.project_progress.overall_percent}%</strong>
                  </div>
                  <div>
                    <span>Integrity</span>
                    <strong>{selectedSessionHistory.project_progress_integrity.status}</strong>
                  </div>
                  <div>
                    <span>Evidence</span>
                    <strong>{selectedSessionHistory.evidence_ref}</strong>
                  </div>
                </div>
                <div className="historyTranscript">
                  <strong>Transcript</strong>
                  {selectedSessionHistory.messages.length ? (
                    selectedSessionHistory.messages.map((message) => (
                      <article className="historyMessage" key={message.id}>
                        <div>
                          <span>{message.role}</span>
                          <small>{message.created_at ?? "no timestamp"}</small>
                        </div>
                        <p>{message.content ?? "No message content stored."}</p>
                      </article>
                    ))
                  ) : (
                    <p className="muted">No chat messages stored for this run; task and audit state are shown below.</p>
                  )}
                </div>
                <div className="historyStateGrid">
                  <div>
                    <span>Tasks</span>
                    <strong>{selectedSessionHistory.tasks.length}</strong>
                  </div>
                  <div>
                    <span>Audit Events</span>
                    <strong>{selectedSessionHistory.audit_events.length}</strong>
                  </div>
                  <div>
                    <span>Last Verified</span>
                    <strong>{selectedSessionHistory.project_progress.last_verified ?? "unknown"}</strong>
                  </div>
                  <div>
                    <span>Manifest</span>
                    <strong>{selectedSessionHistory.project_progress_integrity.evidence_ref}</strong>
                  </div>
                </div>
                <div className="historyMiniList">
                  {selectedSessionHistory.tasks.slice(0, 4).map((task) => (
                    <article key={task.task_id}>
                      <strong>{task.agent_type}: {task.status}</strong>
                      <small>{task.task_description}</small>
                    </article>
                  ))}
                  {selectedSessionHistory.audit_events.slice(0, 4).map((event) => (
                    <article key={event.id}>
                      <strong>{event.event_type}</strong>
                      <small>{event.created_at ?? "no timestamp"} | {event.severity}</small>
                    </article>
                  ))}
                </div>
              </>
            ) : (
              <p className="muted">Open a recent run to view its transcript, task state, audit trail, and current project progress.</p>
            )}
          </div>
        </section>

        <section className="panel auditPanel" aria-label="Audit log">
          <header className="panelHeader">
            <h2>Audit</h2>
            <button type="button" onClick={() => void loadAuditEvents()}>
              Refresh
            </button>
          </header>
          <p className="muted">
            Audit correlation: request_id / trace_id / request_id_audit_feed_visible
          </p>
          <div className="auditList">
            {auditEvents.length ? (
              auditEvents.map((event) => (
                <article className="auditItem" key={event.id}>
                  <div>
                    <strong>{event.event_type}</strong>
                    <span className={`severity severity-${event.severity}`}>{event.severity}</span>
                  </div>
                  <small>{event.created_at ?? "no timestamp"}</small>
                  <small>Session: {event.session_id ?? "none"}</small>
                  <small>Request ID: {event.request_id ?? String(event.details.request_id ?? "none")}</small>
                  <small>Trace ID: {event.trace_id ?? String(event.details.trace_id ?? "none")}</small>
                  <small>
                    Evidence: {event.audit_feed_evidence_ref ?? event.correlation_evidence_ref ?? String(event.details.correlation_evidence_ref ?? "none")}
                  </small>
                  <pre>{JSON.stringify(event.details, null, 2)}</pre>
                </article>
              ))
            ) : (
              <article className="auditItem auditItemEmpty">
                <div>
                  <strong>No audit events yet.</strong>
                  <span className="severity severity-info">info</span>
                </div>
                <small>Request ID: none</small>
                <small>Trace ID: none</small>
                <small>Evidence: request_id_audit_feed_visible</small>
              </article>
            )}
          </div>
        </section>

        <section className="panel mcpAuditPanel" aria-label="MCP audit">
          <header className="panelHeader">
            <h2>MCP Audit</h2>
            <button type="button" onClick={() => void loadMcpAuditEvents()}>
              Refresh
            </button>
          </header>
          <div className="mcpAuditList">
            {mcpAuditEvents.length ? (
              mcpAuditEvents.map((event) => (
                <article className="mcpAuditItem" key={event.id}>
                  <div>
                    <strong>{String(event.details.toolset ?? "tool")}</strong>
                    <span className={`severity severity-${event.severity}`}>{String(event.details.status ?? event.severity)}</span>
                  </div>
                  <small>{String(event.details.capability ?? "unknown capability")}</small>
                  <small>Request: {String(event.details.tool_request_id ?? "none")}</small>
                  <small>Error: {String(event.details.error_class ?? "none")}</small>
                  <p>{String(event.details.sanitized_summary ?? "No summary.")}</p>
                </article>
              ))
            ) : (
              <p className="muted">No MCP audit records yet.</p>
            )}
          </div>
        </section>

        <section className="panel memoryConsolidationPanel" aria-label="Memory consolidation">
          <header className="panelHeader">
            <h2>Memory Consolidation</h2>
            <button type="button" onClick={() => void loadMemoryConsolidationEvents()}>
              Refresh
            </button>
          </header>
          <div className="auditList">
            {memoryConsolidationEvents.length ? (
              memoryConsolidationEvents.map((event) => (
                <article className="auditItem" key={event.id}>
                  <div>
                    <strong>{event.event_type.replace("memory_", "")}</strong>
                    <span className={`severity severity-${event.severity}`}>{event.severity}</span>
                  </div>
                  <small>{event.created_at ?? "no timestamp"}</small>
                  <small>Idempotency: {String(event.details.idempotency_key ?? "none")}</small>
                  <small>Reason: {String(event.details.reason ?? "consolidated")}</small>
                  <p>{String(event.details.redis_key ?? "no redis key")}</p>
                </article>
              ))
            ) : (
              <p className="muted">No memory consolidation records yet.</p>
            )}
          </div>
        </section>

        <section className="panel costPanel" aria-label="Cost monitor">
          <header className="panelHeader">
            <h2>Cost Monitor</h2>
            <button type="button" onClick={() => void Promise.all([loadBudget(), loadCosts(), loadCostExportContract()])}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Spent</span>
              <strong>{costs ? cents(costs.total_cost_cents) : "loading"}</strong>
            </div>
            <div>
              <span>Limit</span>
              <strong>{costs ? cents(costs.budget_limit_cents) : "loading"}</strong>
            </div>
            <div>
              <span>Usage</span>
              <strong>{costs ? `${costs.budget_spent_percentage}%` : "loading"}</strong>
            </div>
            <div>
              <span>Gate</span>
              <strong>{costs?.allow_new_calls === false ? "blocked" : "open"}</strong>
            </div>
            <div>
              <span>Export</span>
              <strong>{costExportContract?.supported_formats.join(", ") ?? "loading"}</strong>
            </div>
            <div>
              <span>Group by</span>
              <strong>{costExportContract?.supported_group_by.join(" / ") ?? "loading"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>CSV Export</strong>
              <p>{costExportContract?.endpoint ?? "GET /api/v1/costs/export?format=csv&group_by=agent"}</p>
              <small>
                Contract endpoint: /api/v1/costs/export/contract · default file{" "}
                {costExportContract?.filename_pattern ?? "superbrain-costs-{group_by}.csv"}
              </small>
            </article>
            <article className="policyItem">
              <strong>Columns</strong>
              <p>{costExportContract?.columns.join(", ") ?? "Loading CSV column contract."}</p>
            </article>
            <article className="policyItem">
              <strong>Evidence</strong>
              <p>
                {costExportContract
                  ? Object.values(costExportContract.evidence_refs).join(" / ")
                  : "Loading cost export evidence refs."}
              </p>
              <small>
                Default evidence refs: cost_export_contract_visible / cost_export_csv_generated /
                cost_export_audit_persisted
              </small>
            </article>
            <article className="policyItem">
              <strong>Download Path</strong>
              <p>/api/v1/costs/export?format=csv&amp;group_by=agent</p>
            </article>
          </div>
          <div className="gateList">
            {costExportContract?.policy_checks?.length ? (
              costExportContract.policy_checks.map((check) => (
                <article className="gateItem gateReady" key={check}>
                  <div>
                    <strong>Export Check</strong>
                    <span>enforced</span>
                  </div>
                  <p>{check}</p>
                </article>
              ))
            ) : (
              <p className="muted">Cost export checks loading.</p>
            )}
          </div>
          <p className="infraNote">
            {costExportContract?.non_claims.join(" ") ??
              "This local CSV export is not a provider invoice or production reconciliation."}
          </p>
          <div className="costList">
            {costs?.breakdown?.length ? (
              costs.breakdown.map((item) => (
                <article className="costItem" key={`${item.agent_type}-${item.provider_name}-${item.model_name}`}>
                  <div>
                    <strong>{item.agent_type ?? "unknown"}</strong>
                    <span>{cents(item.cost_cents)}</span>
                  </div>
                  <small>
                    {item.provider_name} / {item.model_name}
                  </small>
                </article>
              ))
            ) : (
              <p className="muted">No LLM cost records yet.</p>
            )}
          </div>
        </section>

        <section className="panel infraBudgetPanel" aria-label="Rate limit guard">
          <header className="panelHeader">
            <h2>Rate Limit Guard</h2>
            <button type="button" onClick={() => void Promise.all([loadRateLimitContract(), loadRateLimitStatus()])}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{rateLimitContract?.contract_version ?? "loading"}</strong>
            </div>
            <div>
              <span>Status</span>
              <strong>{rateLimitStatus?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>Remaining</span>
              <strong>
                {rateLimitStatus ? `${rateLimitStatus.remaining} / ${rateLimitStatus.limit}` : "loading"}
              </strong>
            </div>
            <div>
              <span>Window</span>
              <strong>{rateLimitStatus ? `${rateLimitStatus.window_seconds}s` : "loading"}</strong>
            </div>
            <div>
              <span>Failure</span>
              <strong>{rateLimitContract ? `HTTP ${rateLimitContract.failure_status}` : "loading"}</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{rateLimitStatus?.evidence_ref ?? "rate_limit_status_visible"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Protected Endpoint</strong>
              <p>{rateLimitContract?.protected_endpoints.join(", ") ?? "POST /api/v1/prompt"}</p>
            </article>
            <article className="policyItem">
              <strong>Status Endpoint</strong>
              <p>{rateLimitContract?.status_endpoint ?? "GET /api/v1/rate-limit/status?project_id={id}"}</p>
            </article>
            <article className="policyItem">
              <strong>Redis Scope</strong>
              <p>{rateLimitContract?.redis_key_pattern ?? "rate_limit:prompt:{project_id}:{window}"}</p>
            </article>
            <article className="policyItem">
              <strong>Overflow Evidence</strong>
              <p>{rateLimitContract?.evidence_refs.overflow_blocked ?? "rate_limit_429_enforced"}</p>
              <small>
                Default evidence refs: rate_limit_contract_visible / rate_limit_status_visible /
                rate_limit_429_enforced
              </small>
            </article>
          </div>
          <div className="gateList">
            {rateLimitContract?.policy_checks?.length ? (
              rateLimitContract.policy_checks.map((check) => (
                <article className="gateItem gateReady" key={check}>
                  <div>
                    <strong>Rate Check</strong>
                    <span>enforced</span>
                  </div>
                  <p>{check}</p>
                </article>
              ))
            ) : (
              <p className="muted">Rate-limit checks loading.</p>
            )}
          </div>
        </section>

        <section className="panel infraBudgetPanel" aria-label="Session limit guard">
          <header className="panelHeader">
            <h2>Session Limit Guard</h2>
            <button
              type="button"
              onClick={() => void Promise.all([loadSessionLimitContract(), loadSessionLimitStatus()])}
            >
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{sessionLimitContract?.contract_version ?? "loading"}</strong>
            </div>
            <div>
              <span>Status</span>
              <strong>{sessionLimitStatus?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>Remaining</span>
              <strong>
                {sessionLimitStatus ? `${sessionLimitStatus.remaining} / ${sessionLimitStatus.limit}` : "loading"}
              </strong>
            </div>
            <div>
              <span>TTL</span>
              <strong>{sessionLimitStatus ? `${sessionLimitStatus.ttl_seconds}s` : "loading"}</strong>
            </div>
            <div>
              <span>Failure</span>
              <strong>{sessionLimitContract ? `HTTP ${sessionLimitContract.failure_status}` : "loading"}</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{sessionLimitStatus?.evidence_ref ?? "session_limit_status_visible"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Protected Endpoint</strong>
              <p>{sessionLimitContract?.protected_endpoints.join(", ") ?? "POST /api/v1/prompt"}</p>
            </article>
            <article className="policyItem">
              <strong>Status Endpoint</strong>
              <p>{sessionLimitContract?.status_endpoint ?? "GET /api/v1/session-limits/status?session_id={id}"}</p>
            </article>
            <article className="policyItem">
              <strong>Redis Scope</strong>
              <p>{sessionLimitContract?.redis_key_pattern ?? "session:{session_id}:llm_calls"}</p>
            </article>
            <article className="policyItem">
              <strong>Overflow Evidence</strong>
              <p>{sessionLimitContract?.evidence_refs.overflow_blocked ?? "session_limit_429_enforced"}</p>
              <small>
                Default evidence refs: session_limit_contract_visible / session_limit_status_visible /
                session_limit_429_enforced
              </small>
            </article>
          </div>
          <div className="gateList">
            {sessionLimitContract?.policy_checks?.length ? (
              sessionLimitContract.policy_checks.map((check) => (
                <article className="gateItem gateReady" key={check}>
                  <div>
                    <strong>Session Check</strong>
                    <span>enforced</span>
                  </div>
                  <p>{check}</p>
                </article>
              ))
            ) : (
              <p className="muted">Session-limit checks loading.</p>
            )}
          </div>
        </section>

        <section className="panel infraBudgetPanel" aria-label="Infrastructure budget">
          <header className="panelHeader">
            <h2>Infra Budget</h2>
            <button type="button" onClick={() => void loadInfraBudget()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Projected</span>
              <strong>{infraBudget ? cents(infraBudget.projected_cost_cents) : "loading"}</strong>
            </div>
            <div>
              <span>Hard limit</span>
              <strong>{infraBudget ? cents(infraBudget.budget_limit_cents) : "loading"}</strong>
            </div>
            <div>
              <span>Usage</span>
              <strong>{infraBudget ? `${infraBudget.budget_spent_percentage}%` : "loading"}</strong>
            </div>
            <div>
              <span>Gate</span>
              <strong>{infraBudget?.allow_new_infra === false ? "blocked" : "open"}</strong>
            </div>
          </div>
          <div className="costList">
            {infraBudget?.items?.length ? (
              infraBudget.items.map((item) => (
                <article className="costItem" key={item.name}>
                  <div>
                    <strong>{item.name}</strong>
                    <span>{cents(item.monthly_cost_cents)}</span>
                  </div>
                  <small>{item.source}</small>
                </article>
              ))
            ) : (
              <p className="muted">Infrastructure projection loading.</p>
            )}
          </div>
          <p className="infraNote">
            Source: {infraBudget?.source ?? "loading"}; live verified: {infraBudget?.live_verified ? "yes" : "no"}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="Cloud provider inventory">
          <header className="panelHeader">
            <h2>Cloud Inventory</h2>
            <button type="button" onClick={() => void loadClouds()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{clouds?.contract_version ?? "cloud-provider-inventory-v1"}</strong>
            </div>
            <div>
              <span>Status</span>
              <strong>{clouds?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>Configured</span>
              <strong>{clouds ? `${clouds.configured_count}/${clouds.total_count}` : "loading"}</strong>
            </div>
            <div>
              <span>Live proofs</span>
              <strong>{clouds ? `${clouds.live_verified_count}/${clouds.total_count}` : "loading"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Endpoint</strong>
              <p>{clouds?.endpoint ?? "GET /api/v1/clouds"}</p>
              <small>No secret values are returned by the cloud inventory endpoint.</small>
            </article>
            <article className="policyItem">
              <strong>Evidence</strong>
              <p>{clouds?.evidence_ref ?? "cloud_provider_inventory_visible"}</p>
              <small>7 Layer Map uses the existing architecture-layer ids.</small>
            </article>
          </div>
          <div className="gateList">
            {clouds?.providers?.length ? (
              clouds.providers.map((provider) => (
                <article
                  className={provider.configured ? "gateItem gateReady" : "gateItem gateMissing"}
                  key={provider.id}
                >
                  <div>
                    <strong>{provider.label}</strong>
                    <span>{provider.live_verified ? "live" : provider.status}</span>
                  </div>
                  <small>
                    {provider.role} Layers: {provider.layers.join(", ")}
                  </small>
                  <p>
                    Env:{" "}
                    {provider.env_status
                      .map((item) => `${item.key}:${item.configured ? "set" : "missing"}`)
                      .join(" | ")}
                  </p>
                  {typeof provider.monthly_cost_cents === "number" ? (
                    <p>Monthly cost: {cents(provider.monthly_cost_cents)}</p>
                  ) : null}
                  {provider.resources?.slice(0, 4).map((resource, index) => (
                    <p key={`${provider.id}-resource-${index}`}>
                      {(Object.entries(resource)
                        .filter(([, value]) => value !== null && value !== undefined && value !== "")
                        .slice(0, 6)
                        .map(([key, value]) => `${key}: ${String(value)}`)
                        .join(" · ")) || "resource pending"}
                    </p>
                  ))}
                  {provider.error ? <p>{provider.error}</p> : null}
                </article>
              ))
            ) : (
              <p className="muted">Cloud inventory loading.</p>
            )}
          </div>
          <div className="policyGrid">
            {(clouds?.seven_layer_mapping ?? []).map((layer) => (
              <article className="policyItem" key={layer.layer_id}>
                <strong>
                  {layer.layer_id} · {layer.label}
                </strong>
                <p>{layer.providers.map((providerId) => cloudProviderLabels.get(providerId) ?? providerId).join(", ")}</p>
                <small>{layer.evidence_ref}</small>
              </article>
            ))}
          </div>
        </section>

        <section className="panel externalGatesPanel" aria-label="Cloud seven layer readiness">
          <header className="panelHeader">
            <h2>Cloud 7-Layer Readiness</h2>
            <button type="button" onClick={() => void loadCloudLayers()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{cloudLayers?.contract_version ?? "cloud-layer-readiness-v1"}</strong>
            </div>
            <div>
              <span>Status</span>
              <strong>{cloudLayers?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>Live layers</span>
              <strong>
                {cloudLayers
                  ? `${cloudLayers.ready_layer_count}/${cloudLayers.total_layer_count}`
                  : "loading"}
              </strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{cloudLayers?.evidence_ref ?? "cloud_layer_readiness_visible"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Endpoint</strong>
              <p>{cloudLayers?.endpoint ?? "GET /api/v1/clouds/layers"}</p>
              <small>{cloudLayers?.provider_inventory_endpoint ?? "GET /api/v1/clouds"}</small>
            </article>
            <article className="policyItem">
              <strong>Gate Model</strong>
              <p>{cloudLayers?.provider_inventory_evidence_ref ?? "cloud_provider_inventory_visible"}</p>
              <small>Missing provider env gates stay explicit blockers.</small>
            </article>
          </div>
          <div className="gateList">
            {cloudLayers?.layers?.length ? (
              cloudLayers.layers.map((layer) => (
                <article
                  className={layer.status === "live_verified" ? "gateItem gateReady" : "gateItem gateMissing"}
                  key={layer.layer_id}
                >
                  <div>
                    <strong>
                      {layer.layer_id} · {layer.label}
                    </strong>
                    <span>{layer.status}</span>
                  </div>
                  <small>
                    Required:{" "}
                    {layer.required_providers
                      .map((providerId) => cloudProviderLabels.get(providerId) ?? providerId)
                      .join(", ")}
                  </small>
                  <p>
                    Configured: {layer.configured_providers.length ? layer.configured_providers.join(", ") : "none"} ·
                    Live: {layer.live_verified_providers.length ? layer.live_verified_providers.join(", ") : "none"}
                  </p>
                  <p>
                    Blockers: {layer.blockers.length ? layer.blockers.join(" | ") : "none"}
                  </p>
                  <p>{layer.next_safe_action}</p>
                </article>
              ))
            ) : (
              <p className="muted">Cloud layer readiness loading.</p>
            )}
          </div>
        </section>

        <section className="panel externalGatesPanel" aria-label="Cloud render offload contract">
          <header className="panelHeader">
            <h2>Cloud Render Offload</h2>
            <button type="button" onClick={() => void loadCloudRenderOffload()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{cloudRenderOffload?.contract_version ?? "cloud-render-offload-v1"}</strong>
            </div>
            <div>
              <span>Status</span>
              <strong>{cloudRenderOffload?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>Local Render</span>
              <strong>{cloudRenderOffload?.localhost_heavy_render_allowed ? "allowed" : "blocked"}</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{cloudRenderOffload?.evidence_ref ?? "cloud_render_offload_contract_visible"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Endpoint</strong>
              <p>{cloudRenderOffload?.endpoint ?? "GET /api/v1/clouds/render-offload/contract"}</p>
              <small>{cloudRenderOffload?.localhost_role ?? "dev_control_plane_only"}</small>
            </article>
            <article className="policyItem">
              <strong>Home PC Protection</strong>
              <p>{cloudRenderOffload?.home_pc_protection ? "heavy graphics stay cloud-only" : "loading"}</p>
              <small>Localhost remains a lightweight control plane.</small>
            </article>
          </div>
          <div className="gateList">
            {cloudRenderOffload?.workloads?.length ? (
              cloudRenderOffload.workloads.map((workload) => (
                <article
                  className={workload.local_allowed ? "gateItem gateReady" : "gateItem gateMissing"}
                  key={workload.id}
                >
                  <div>
                    <strong>{workload.label}</strong>
                    <span>{workload.local_allowed ? "local-ok" : "cloud-only"}</span>
                  </div>
                  <small>{workload.required_runtime}</small>
                  <p>{workload.blocker ?? "control plane only"}</p>
                </article>
              ))
            ) : (
              <p className="muted">Cloud render offload loading.</p>
            )}
          </div>
          <div className="policyGrid">
            {(cloudRenderOffload?.cloud_gates ?? []).map((gate) => (
              <article className="policyItem" key={gate.id}>
                <strong>{gate.id}</strong>
                <p>
                  {gate.required_env}: {gate.configured ? "configured" : "missing"}
                </p>
                <small>{gate.evidence_ref}</small>
              </article>
            ))}
          </div>
          <p className="muted">
            Blockers: {cloudRenderOffload?.blockers?.length ? cloudRenderOffload.blockers.join(" | ") : "loading"}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="External gates">
          <header className="panelHeader">
            <h2>External Gates</h2>
            <button type="button" onClick={() => void loadExternalGates()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{externalGates?.contract_version ?? "external-gates-state-v1"}</strong>
            </div>
            <div>
              <span>Status</span>
              <strong>{externalGates?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>Configured</span>
              <strong>
                {externalGates
                  ? `${externalGates.configured_count}/${externalGates.total_count}`
                  : "loading"}
              </strong>
            </div>
            <div>
              <span>Local work</span>
              <strong>{externalGates?.local_execution_allowed === false ? "blocked" : "open"}</strong>
            </div>
          </div>
          <p className="infraNote">
            {externalGates?.evidence_ref ?? "external_gates_state_visible"} via{" "}
            {externalGates?.endpoint ?? "GET /api/v1/external-gates"}
          </p>
          <div className="gateList">
            {externalGates?.gates?.length ? (
              externalGates.gates.map((gate) => {
                const requiredEnv = stringList(gate.required_env);
                return (
                  <article className={gate.configured ? "gateItem gateReady" : "gateItem gateMissing"} key={gate.id}>
                    <div>
                      <strong>{gate.label}</strong>
                      <span>{gate.configured ? "configured" : "missing"}</span>
                    </div>
                    <small>{gate.required_for}</small>
                    <p>
                      {gate.id} -&gt; {gate.preflight_gate_id}
                    </p>
                    <p>{requiredEnv.length ? requiredEnv.join(", ") : "No env required"}</p>
                    <p>{gate.evidence_ref}</p>
                    <p>{gate.fallback}</p>
                  </article>
                );
              })
            ) : (
              <p className="muted">External gate status loading.</p>
            )}
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Phase 5 - Release Readiness</strong>
              <p>
                Release blockers:{" "}
                {stringList(externalGates?.blocked_release_gates).length
                  ? stringList(externalGates?.blocked_release_gates).join(" | ")
                  : "loading"}
              </p>
              <small>
                Deployment preflight link:{" "}
                {externalGates?.deployment_preflight_endpoint ?? "GET /api/v1/clouds/deployment-preflight/contract"}
              </small>
            </article>
          </div>
        </section>

        <section className="panel externalGatesPanel" aria-label="External Gate Mirror">
          <header className="panelHeader">
            <h2>External Gate Mirror</h2>
            <button type="button" onClick={() => void loadExternalGateMirror()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{externalGateMirror?.contract_version ?? "external-gate-mirror-v1"}</strong>
            </div>
            <div>
              <span>Status</span>
              <strong>{externalGateMirror?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>Hosted claim</span>
              <strong>{externalGateMirror?.hosted_staging_claim_allowed ? "allowed" : "blocked"}</strong>
            </div>
            <div>
              <span>Branch protection</span>
              <strong>{externalGateMirror?.branch_protection_claim_allowed ? "allowed" : "blocked"}</strong>
            </div>
            <div>
              <span>Production</span>
              <strong>{externalGateMirror?.production_deploy_claim_allowed ? "allowed" : "blocked"}</strong>
            </div>
          </div>
          <p className="infraNote">
            {externalGateMirror?.evidence_ref ?? "external_gate_mirror_proof"} via{" "}
            {externalGateMirror?.endpoint ?? "GET /api/v1/external-gates/mirror"}
          </p>
          <div className="gateList">
            {externalGateMirror?.phase2_contracts_mirrored?.length ? (
              externalGateMirror.phase2_contracts_mirrored.map((contract) => (
                <article className="gateItem gateReady" key={`${contract.name}-${contract.endpoint}`}>
                  <div>
                    <strong>{contract.name}</strong>
                    <span>{contract.contract_version}</span>
                  </div>
                  <small>{contract.endpoint}</small>
                  <p>{contract.evidence_ref}</p>
                </article>
              ))
            ) : (
              <p className="muted">External gate mirror loading.</p>
            )}
          </div>
          <p className="muted">
            {externalGateMirror?.mirrored_workflow ?? ".github/workflows/hosted-staging-proof.yml"} mirrors{" "}
            {externalGateMirror?.verifier ?? "scripts/verify-hosted-staging.ps1"}
          </p>
          <p className="muted">
            {externalGateMirror?.branch_protection_evidence_ref ?? "branch_protection_verify_contract"} via{" "}
            {externalGateMirror?.branch_protection_workflow ?? ".github/workflows/branch-protection.yml"} and{" "}
            {externalGateMirror?.branch_protection_verifier ??
              "scripts/apply_github_branch_protection.py --verify-only"}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="Cloud Deployment Preflight">
          <header className="panelHeader">
            <h2>Cloud Deployment Preflight</h2>
            <button type="button" onClick={() => void loadCloudDeploymentPreflight()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{cloudDeploymentPreflight?.contract_version ?? "cloud-deployment-preflight-v1"}</strong>
            </div>
            <div>
              <span>Status</span>
              <strong>{cloudDeploymentPreflight?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>Preflight</span>
              <strong>{cloudDeploymentPreflight?.preflight_ready ? "ready" : "blocked"}</strong>
            </div>
            <div>
              <span>Cloud deploy claim</span>
              <strong>{cloudDeploymentPreflight?.cloud_deploy_claim_allowed ? "allowed" : "blocked"}</strong>
            </div>
            <div>
              <span>Production</span>
              <strong>{cloudDeploymentPreflight?.production_deploy_claim_allowed ? "allowed" : "blocked"}</strong>
            </div>
          </div>
          <p className="infraNote">
            {cloudDeploymentPreflight?.evidence_ref ?? "cloud_deployment_preflight_visible"} via{" "}
            {cloudDeploymentPreflight?.endpoint ?? "GET /api/v1/clouds/deployment-preflight/contract"}
          </p>
          <div className="gateList">
            {cloudDeploymentPreflight?.gates?.length ? (
              cloudDeploymentPreflight.gates.map((gate) => (
                <article className={gate.configured ? "gateItem gateReady" : "gateItem gateMissing"} key={gate.id}>
                  <div>
                    <strong>{gate.label}</strong>
                    <span>{gate.configured ? "configured" : "blocked"}</span>
                  </div>
                  <small>{gate.required_artifact}</small>
                  <p>
                    {gate.required_env.length ? gate.required_env.join(", ") : "no env key"} · {gate.verifier}
                  </p>
                  <p>{gate.next_action}</p>
                </article>
              ))
            ) : (
              <p className="muted">Cloud deployment preflight loading.</p>
            )}
          </div>
          <p className="muted">
            Sequence:{" "}
            {cloudDeploymentPreflight?.required_sequence?.length
              ? cloudDeploymentPreflight.required_sequence.join(" -> ")
              : "publish_ghcr_images -> start_hetzner_pull_based_stack -> configure_vercel_backend_origins -> run_hosted_staging_verifier"}
          </p>
          <p className="muted">Hosted origins gate: hosted_backend_origins</p>
          <p className="muted">
            Blockers:{" "}
            {cloudDeploymentPreflight?.missing_or_blocked_gates?.length
              ? cloudDeploymentPreflight.missing_or_blocked_gates.join(" | ")
              : "loading"}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="Auth Contract">
          <header className="panelHeader">
            <h2>Auth Contract</h2>
            <button type="button" onClick={() => void loadAuthContract()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{authContract?.contract_version ?? "loading"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{authContract?.mode ?? "loading"}</strong>
            </div>
            <div>
              <span>GitHub OAuth</span>
              <strong>{authContract?.live_github_oauth_call ? "live" : "dry-run"}</strong>
            </div>
            <div>
              <span>Refresh rotation</span>
              <strong>{authContract?.refresh_token.rotation_required ? "required" : "loading"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>JWT</strong>
              <p>
                {authContract
                  ? `${authContract.jwt.algorithm}, access TTL ${Math.round(authContract.jwt.access_token_ttl_seconds / 60)} minutes`
                  : "Loading JWT contract."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Cookies</strong>
              <p>
                {authContract
                  ? `HttpOnly=${authContract.cookie_flags.HttpOnly}, Secure=${authContract.cookie_flags.Secure}, SameSite=${authContract.cookie_flags.SameSite}`
                  : "Loading cookie flags."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Refresh Store</strong>
              <p>
                {authContract
                  ? `${authContract.refresh_token.blacklist_store}: ${authContract.refresh_token.blacklist_key_pattern}`
                  : "Loading refresh-token blacklist contract."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Evidence</strong>
              <p>
                {authContract
                  ? Object.values(authContract.evidence_refs).join(" / ")
                  : "Loading auth evidence refs."}
              </p>
              <small>
                Default evidence refs: auth_contract_visible / auth_refresh_rotated /
                auth_refresh_reuse_blocked / auth_logout_revoked
              </small>
            </article>
          </div>
          <div className="gateList">
            {authContract?.policy_checks?.length ? (
              authContract.policy_checks.map((check) => (
                <article className="gateItem gateReady" key={check}>
                  <div>
                    <strong>Policy Check</strong>
                    <span>enforced</span>
                  </div>
                  <p>{check}</p>
                </article>
              ))
            ) : (
              <p className="muted">Auth policy checks loading.</p>
            )}
          </div>
          <p className="infraNote">
            {authContract?.non_claims.join(" ") ??
              "No live GitHub OAuth exchange is claimed without credentials."}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="Memory Purge Contract">
          <header className="panelHeader">
            <h2>Memory Purge Contract</h2>
            <button type="button" onClick={() => void loadMemoryPurgeContract()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{memoryPurgeContract?.contract_version ?? "loading"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{memoryPurgeContract?.mode ?? "loading"}</strong>
            </div>
            <div>
              <span>Confirmation</span>
              <strong>{memoryPurgeContract?.requires_confirmation ? "confirm=true" : "loading"}</strong>
            </div>
            <div>
              <span>Audit retention</span>
              <strong>
                {memoryPurgeContract ? `${memoryPurgeContract.audit.retention_days} days` : "loading"}
              </strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Endpoint</strong>
              <p>{memoryPurgeContract?.endpoint ?? "DELETE /api/v1/memory"}</p>
              <small>Contract endpoint: /api/v1/memory/purge/contract</small>
            </article>
            <article className="policyItem">
              <strong>Job Status</strong>
              <p>{memoryPurgeContract?.job_status_endpoint ?? "GET /api/v1/memory/purge/jobs/{job_id}"}</p>
              <small>Evidence: memory_purge_job_status_visible</small>
            </article>
            <article className="policyItem">
              <strong>Scope</strong>
              <p>
                {memoryPurgeContract?.purge_scope.join(" / ") ??
                  "Loading scoped Redis, memory, message, and session purge scope."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Evidence</strong>
              <p>
                {memoryPurgeContract
                  ? Object.values(memoryPurgeContract.evidence_refs).join(" / ")
                  : "Loading memory purge evidence refs."}
              </p>
              <small>
                Default evidence refs: memory_purge_contract_visible /
                memory_purge_completed / memory_purge_confirmation_required
              </small>
            </article>
            <article className="policyItem">
              <strong>Audit</strong>
              <p>
                {memoryPurgeContract
                  ? `${memoryPurgeContract.audit.event_type}, stored_after_purge=${memoryPurgeContract.audit.stored_after_purge}`
                  : "Loading purge audit contract."}
              </p>
            </article>
          </div>
          <div className="gateList">
            {memoryPurgeContract?.policy_checks?.length ? (
              memoryPurgeContract.policy_checks.map((check) => (
                <article className="gateItem gateReady" key={check}>
                  <div>
                    <strong>Policy Check</strong>
                    <span>enforced</span>
                  </div>
                  <p>{check}</p>
                </article>
              ))
            ) : (
              <p className="muted">Memory purge policy checks loading.</p>
            )}
          </div>
          <p className="infraNote">
            {memoryPurgeContract?.non_claims.join(" ") ??
              "No Langfuse trace purge or provider-side purge is claimed before live wiring."}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="DevOps workflow dispatch">
          <header className="panelHeader">
            <h2>DevOps Workflow Dispatch</h2>
            <button type="button" onClick={() => void loadWorkflowDispatch()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{workflowDispatch?.contract_version ?? "loading"}</strong>
            </div>
            <div>
              <span>Status</span>
              <strong>{workflowDispatch?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>GitHub call</span>
              <strong>{workflowDispatch?.live_github_call ? "live" : "dry-run"}</strong>
            </div>
            <div>
              <span>Human gate</span>
              <strong>{workflowDispatch?.human_gate.approved ? "approved" : "required"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>GitHub API</strong>
              <p>
                {workflowDispatch
                  ? `${workflowDispatch.github_api.method} ${workflowDispatch.github_api.endpoint}`
                  : "Loading workflow dispatch contract."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Payload</strong>
              <p>
                {workflowDispatch
                  ? `${workflowDispatch.payload.ref} / ${workflowDispatch.payload.inputs.environment} / ${workflowDispatch.payload.inputs.action}`
                  : "Loading dispatch payload."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Required Permission</strong>
              <p>
                {workflowDispatch
                  ? `${workflowDispatch.github_api.required_token_env} with ${workflowDispatch.github_api.required_permission}`
                  : "Loading permission contract."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Non-Claims</strong>
              <p>{workflowDispatch?.non_claims.join(" ") ?? "No dispatch claim is loaded yet."}</p>
            </article>
          </div>
        </section>

        <section className="panel externalGatesPanel" aria-label="GitHub Branch PR Contract">
          <header className="panelHeader">
            <h2>GitHub Branch/PR Contract</h2>
            <button type="button" onClick={() => void loadGithubBranchPrContract()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{githubBranchPrContract?.contract_version ?? "loading"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{githubBranchPrContract?.mode ?? "loading"}</strong>
            </div>
            <div>
              <span>GitHub call</span>
              <strong>{githubBranchPrContract?.live_github_call ? "live" : "dry-run"}</strong>
            </div>
            <div>
              <span>Allowed branch</span>
              <strong>{githubBranchPrContract?.allowed_branch_pattern ?? "loading"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Capability</strong>
              <p>
                {githubBranchPrContract
                  ? `${githubBranchPrContract.toolset}.${githubBranchPrContract.capability}`
                  : "Loading GitHub branch plan contract."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Draft PR Payload</strong>
              <p>
                {githubBranchPrContract
                  ? `${githubBranchPrContract.generated_payloads.pull_request_payload.head} -> ${githubBranchPrContract.generated_payloads.pull_request_payload.base}`
                  : "Loading pull request payload."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Evidence</strong>
              <p>
                {githubBranchPrContract
                  ? `${githubBranchPrContract.evidence_refs.accepted} / ${githubBranchPrContract.evidence_refs.blocked}`
                  : "Loading evidence refs."}
              </p>
              <small>Default evidence refs: github_branch_pr_plan / github_branch_pr_policy</small>
            </article>
            <article className="policyItem">
              <strong>Forbidden</strong>
              <p>{githubBranchPrContract?.forbidden_capabilities.join(", ") ?? "Loading forbidden capabilities."}</p>
            </article>
          </div>
          <div className="gateList">
            {githubBranchPrContract?.policy_checks?.length ? (
              githubBranchPrContract.policy_checks.map((check) => (
                <article className="gateItem gateReady" key={check}>
                  <div>
                    <strong>Policy Check</strong>
                    <span>enforced</span>
                  </div>
                  <p>{check}</p>
                </article>
              ))
            ) : (
              <p className="muted">GitHub branch policy checks loading.</p>
            )}
          </div>
          <p className="infraNote">
            {githubBranchPrContract?.non_claims.join(" ") ??
              "No GitHub branch or pull request mutation is claimed."}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="PostgreSQL Readonly Query Contract">
          <header className="panelHeader">
            <h2>PostgreSQL Readonly Query Contract</h2>
            <button type="button" onClick={() => void loadPostgresqlReadonlyContract()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{postgresqlReadonlyContract?.contract_version ?? "loading"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{postgresqlReadonlyContract?.mode ?? "loading"}</strong>
            </div>
            <div>
              <span>Database call</span>
              <strong>{postgresqlReadonlyContract?.live_database_call ? "live" : "dry-run"}</strong>
            </div>
            <div>
              <span>Scope</span>
              <strong>{postgresqlReadonlyContract?.allowed_scope ?? "loading"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Capability</strong>
              <p>
                {postgresqlReadonlyContract
                  ? `${postgresqlReadonlyContract.toolset}.${postgresqlReadonlyContract.capability}`
                  : "Loading PostgreSQL readonly query contract."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Allowed SQL</strong>
              <p>{postgresqlReadonlyContract?.allowed_sql.join(", ") ?? "Loading allowed SQL rules."}</p>
            </article>
            <article className="policyItem">
              <strong>Evidence</strong>
              <p>
                {postgresqlReadonlyContract
                  ? `${postgresqlReadonlyContract.evidence_refs.accepted} / ${postgresqlReadonlyContract.evidence_refs.blocked}`
                  : "Loading evidence refs."}
              </p>
              <small>Default evidence refs: postgresql_readonly_query_plan / postgresql_write_policy</small>
            </article>
            <article className="policyItem">
              <strong>Forbidden SQL</strong>
              <p>{postgresqlReadonlyContract?.forbidden_sql.join(", ") ?? "Loading forbidden SQL tokens."}</p>
            </article>
          </div>
          <div className="gateList">
            {postgresqlReadonlyContract?.policy_checks?.length ? (
              postgresqlReadonlyContract.policy_checks.map((check) => (
                <article className="gateItem gateReady" key={check}>
                  <div>
                    <strong>Policy Check</strong>
                    <span>enforced</span>
                  </div>
                  <p>{check}</p>
                </article>
              ))
            ) : (
              <p className="muted">PostgreSQL readonly policy checks loading.</p>
            )}
          </div>
          <p className="infraNote">
            {postgresqlReadonlyContract?.non_claims.join(" ") ??
              "No PostgreSQL query or database mutation is claimed."}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="Filesystem Workspace Scope Contract">
          <header className="panelHeader">
            <h2>Filesystem Workspace Scope Contract</h2>
            <button type="button" onClick={() => void loadFilesystemWorkspaceContract()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{filesystemWorkspaceContract?.contract_version ?? "loading"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{filesystemWorkspaceContract?.mode ?? "loading"}</strong>
            </div>
            <div>
              <span>Filesystem call</span>
              <strong>{filesystemWorkspaceContract?.live_filesystem_call ? "live" : "dry-run"}</strong>
            </div>
            <div>
              <span>Workspace root</span>
              <strong>{filesystemWorkspaceContract?.workspace_root ?? "loading"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Capability</strong>
              <p>
                {filesystemWorkspaceContract
                  ? `${filesystemWorkspaceContract.toolset}.${filesystemWorkspaceContract.capability}`
                  : "Loading filesystem workspace scope contract."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Allowed Operations</strong>
              <p>{filesystemWorkspaceContract?.allowed_operations.join(", ") ?? "Loading allowed operations."}</p>
            </article>
            <article className="policyItem">
              <strong>Evidence</strong>
              <p>
                {filesystemWorkspaceContract
                  ? `${filesystemWorkspaceContract.evidence_refs.accepted} / ${filesystemWorkspaceContract.evidence_refs.blocked}`
                  : "Loading evidence refs."}
              </p>
              <small>Default evidence refs: filesystem_workspace_access_plan / filesystem_scope_policy</small>
            </article>
            <article className="policyItem">
              <strong>Forbidden Operations</strong>
              <p>{filesystemWorkspaceContract?.forbidden_operations.join(", ") ?? "Loading forbidden operations."}</p>
            </article>
          </div>
          <div className="gateList">
            {filesystemWorkspaceContract?.policy_checks?.length ? (
              filesystemWorkspaceContract.policy_checks.map((check) => (
                <article className="gateItem gateReady" key={check}>
                  <div>
                    <strong>Policy Check</strong>
                    <span>enforced</span>
                  </div>
                  <p>{check}</p>
                </article>
              ))
            ) : (
              <p className="muted">Filesystem workspace policy checks loading.</p>
            )}
          </div>
          <p className="infraNote">
            {filesystemWorkspaceContract?.non_claims.join(" ") ??
              "No host filesystem access outside /tmp/agent-workspace is claimed."}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="Playwright Browser Proof Contract">
          <header className="panelHeader">
            <h2>Playwright Browser Proof Contract</h2>
            <button type="button" onClick={() => void loadPlaywrightBrowserProofContract()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{playwrightBrowserProofContract?.contract_version ?? "loading"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{playwrightBrowserProofContract?.mode ?? "loading"}</strong>
            </div>
            <div>
              <span>Browser call</span>
              <strong>{playwrightBrowserProofContract?.live_browser_call ? "live" : "dry-run"}</strong>
            </div>
            <div>
              <span>Timeout cap</span>
              <strong>
                {playwrightBrowserProofContract ? `${playwrightBrowserProofContract.timeout_ms_cap}ms` : "loading"}
              </strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Capability</strong>
              <p>
                {playwrightBrowserProofContract
                  ? `${playwrightBrowserProofContract.toolset}.${playwrightBrowserProofContract.capability}`
                  : "Loading Playwright browser proof contract."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Allowed Targets</strong>
              <p>{playwrightBrowserProofContract?.allowed_targets.join(", ") ?? "Loading allowed targets."}</p>
            </article>
            <article className="policyItem">
              <strong>Evidence</strong>
              <p>
                {playwrightBrowserProofContract
                  ? `${playwrightBrowserProofContract.evidence_refs.accepted} / ${playwrightBrowserProofContract.evidence_refs.blocked}`
                  : "Loading evidence refs."}
              </p>
              <small>Default evidence refs: playwright_browser_proof_plan / playwright_browser_policy</small>
            </article>
            <article className="policyItem">
              <strong>Forbidden Targets</strong>
              <p>{playwrightBrowserProofContract?.forbidden_targets.join(", ") ?? "Loading forbidden targets."}</p>
            </article>
          </div>
          <div className="gateList">
            {playwrightBrowserProofContract?.policy_checks?.length ? (
              playwrightBrowserProofContract.policy_checks.map((check) => (
                <article className="gateItem gateReady" key={check}>
                  <div>
                    <strong>Policy Check</strong>
                    <span>enforced</span>
                  </div>
                  <p>{check}</p>
                </article>
              ))
            ) : (
              <p className="muted">Playwright browser proof policy checks loading.</p>
            )}
          </div>
          <p className="infraNote">
            {playwrightBrowserProofContract?.non_claims.join(" ") ??
              "No browser session or screenshot capture is claimed."}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="E2B Sandbox Lifecycle Contract">
          <header className="panelHeader">
            <h2>E2B Sandbox Lifecycle Contract</h2>
            <button type="button" onClick={() => void loadE2bSandboxLifecycleContract()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{e2bSandboxLifecycleContract?.contract_version ?? "loading"}</strong>
            </div>
            <div>
              <span>Mode</span>
              <strong>{e2bSandboxLifecycleContract?.mode ?? "loading"}</strong>
            </div>
            <div>
              <span>E2B call</span>
              <strong>{e2bSandboxLifecycleContract?.live_e2b_call ? "live" : "dry-run"}</strong>
            </div>
            <div>
              <span>Finally close</span>
              <strong>{e2bSandboxLifecycleContract?.close_required ? "required" : "loading"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Capability</strong>
              <p>
                {e2bSandboxLifecycleContract
                  ? `${e2bSandboxLifecycleContract.toolset}.${e2bSandboxLifecycleContract.capability}`
                  : "Loading E2B sandbox lifecycle contract."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Allowed Actions</strong>
              <p>{e2bSandboxLifecycleContract?.allowed_actions.join(", ") ?? "Loading allowed actions."}</p>
            </article>
            <article className="policyItem">
              <strong>Evidence</strong>
              <p>
                {e2bSandboxLifecycleContract
                  ? `${e2bSandboxLifecycleContract.evidence_refs.accepted} / ${e2bSandboxLifecycleContract.evidence_refs.blocked} / ${e2bSandboxLifecycleContract.evidence_refs.degraded}`
                  : "Loading evidence refs."}
              </p>
              <small>Default evidence refs: e2b_sandbox_lifecycle_plan / e2b_sandbox_policy</small>
            </article>
            <article className="policyItem">
              <strong>Timeout</strong>
              <p>
                {e2bSandboxLifecycleContract
                  ? `${Math.round(e2bSandboxLifecycleContract.max_session_timeout_ms / 60000)} minutes`
                  : "Loading timeout cap."}
              </p>
            </article>
          </div>
          <div className="gateList">
            {e2bSandboxLifecycleContract?.policy_checks?.length ? (
              e2bSandboxLifecycleContract.policy_checks.map((check) => (
                <article className="gateItem gateReady" key={check}>
                  <div>
                    <strong>Policy Check</strong>
                    <span>enforced</span>
                  </div>
                  <p>{check}</p>
                </article>
              ))
            ) : (
              <p className="muted">E2B sandbox lifecycle policy checks loading.</p>
            )}
          </div>
          <p className="infraNote">
            {e2bSandboxLifecycleContract?.non_claims.join(" ") ??
              "No E2B sandbox creation or code execution is claimed."}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="MCP Version Pinning Contract">
          <header className="panelHeader">
            <h2>MCP Version Pinning Contract</h2>
            <button type="button" onClick={() => void loadMcpVersionPinningContract()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>{mcpVersionPinningContract?.contract_version ?? "mcp-version-pinning-v1"}</strong>
            </div>
            <div>
              <span>Gateway</span>
              <strong>{mcpGateway?.app_version ?? "0.1.0"}</strong>
            </div>
            <div>
              <span>Pin Policy</span>
              <strong>{mcpGateway?.dependency_pin_policy ?? "exact_version_required"}</strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>{mcpVersionPinningContract?.evidence_ref ?? "mcp_version_pinning_contract_visible"}</strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Dependencies</strong>
              <p>
                {mcpPinnedDependencies.map((dependency) => dependency.pin).join(", ")}
              </p>
            </article>
            <article className="policyItem">
              <strong>Tool Contracts</strong>
              <p>
                {mcpPinnedToolContracts.map((contract) => contract.contract_version).join(", ")}
              </p>
            </article>
            <article className="policyItem">
              <strong>Request Contract</strong>
              <p>
                {Object.entries(mcpRequestContract)
                  .map(([key, value]) => `${key}: ${String(value)}`)
                  .join("; ")}
              </p>
            </article>
            <article className="policyItem">
              <strong>Non-Claims</strong>
              <p>
                {mcpNonClaims.length
                  ? mcpNonClaims.join(" ")
                  : "No live MCP write, external MCP server version, or production deployment is claimed."}
              </p>
            </article>
          </div>
          <div className="gateList">
            {(mcpDriftPolicy.length ? mcpDriftPolicy : [
              "Every runtime dependency in services/mcp-gateway/requirements.txt must use exact == pinning.",
              "Every exposed MCP tool contract must publish a stable contract_version.",
              "Adding or changing a tool capability requires updating this endpoint, docs, UI, and verifiers in the same change.",
            ]).map((check) => (
              <article className="gateItem gateReady" key={check}>
                <div>
                  <strong>Drift Check</strong>
                  <span>enforced</span>
                </div>
                <p>{check}</p>
              </article>
            ))}
          </div>
          <p className="infraNote evidenceLine">
            Evidence:{" "}
            {(mcpEvidenceRefs.length ? mcpEvidenceRefs : [
              "mcp_version_pinning_contract_visible",
              "mcp_safe_envelope",
              "mcp_scope_guard",
              "mcp_timeout_guard",
              "mcp_tool_session_bound_audit",
            ]).join(" / ")}
          </p>
        </section>

        <section className="panel externalGatesPanel" aria-label="Memory Embedding Consistency Contract">
          <header className="panelHeader">
            <h2>Memory Embedding Consistency Contract</h2>
            <button type="button" onClick={() => void loadMemoryEmbeddingConsistencyContract()}>
              Refresh
            </button>
          </header>
          <div className="costSummary">
            <div>
              <span>Contract</span>
              <strong>
                {memoryEmbeddingConsistencyContract?.contract_version ?? "memory-embedding-consistency-v1"}
              </strong>
            </div>
            <div>
              <span>Status</span>
              <strong>{memoryEmbeddingConsistencyContract?.status ?? "loading"}</strong>
            </div>
            <div>
              <span>Model</span>
              <strong>
                {memoryCurrentEmbedding?.model_version ?? "text-embedding-3-small"}
              </strong>
            </div>
            <div>
              <span>Evidence</span>
              <strong>
                {memoryEmbeddingConsistencyContract?.evidence_ref ??
                  "memory_embedding_consistency_contract_visible"}
              </strong>
            </div>
          </div>
          <div className="policyGrid">
            <article className="policyItem">
              <strong>Schema</strong>
              <p>
                {Object.entries(memoryExpectedColumns)
                  .map(([key, value]) => `${key}: ${value}`)
                  .join("; ")}
              </p>
            </article>
            <article className="policyItem">
              <strong>Search Mode</strong>
              <p>
                {memoryEmbeddingConsistencyContract
                  ? `${memoryCurrentEmbedding?.search_mode ?? "lexical_fallback"}; vector search enabled: ${String(memoryReadPolicy?.vector_search_enabled ?? false)}`
                  : "lexical_fallback; vector search enabled: false"}
              </p>
            </article>
            <article className="policyItem">
              <strong>Re-Embedding</strong>
              <p>
                {memoryReembeddingPolicy?.stale_row_policy ??
                  "Rows with non-current embedding_model_version are excluded from future vector search."}
              </p>
            </article>
            <article className="policyItem">
              <strong>Non-Claims</strong>
              <p>
                {memoryNonClaims.length
                  ? memoryNonClaims.join(" ")
                  : "No live embedding provider call or production vector-search readiness is claimed."}
              </p>
            </article>
          </div>
          <div className="gateList">
            {(memoryRequiredSteps.length ? memoryRequiredSteps : [
              "record old and new embedding_model_version",
              "queue bounded re-embedding job per project",
              "publish audit evidence before raising memory-layer progress",
            ]).map((check) => (
              <article className="gateItem gateReady" key={check}>
                <div>
                  <strong>Re-Embedding Step</strong>
                  <span>required</span>
                </div>
                <p>{check}</p>
              </article>
            ))}
          </div>
          <p className="infraNote evidenceLine">
            Evidence:{" "}
            {(memoryEvidenceRefs.length ? memoryEvidenceRefs : [
              "memory_embedding_consistency_contract_visible",
              "embedding_model_version_persisted",
              "embedding_vector_dimension_guard",
              "reembedding_strategy_fail_closed",
            ]).join(" / ")}
          </p>
        </section>

        <section className="split">
          <section className="panel" aria-label="Stream events">
            <header className="panelHeader">
              <h2>Stream</h2>
            </header>
            <pre>{events.length ? events.join("\n\n") : "No stream events yet."}</pre>
          </section>

          <section className="panel" aria-label="Memory search">
            <header className="panelHeader">
              <h2>Memory</h2>
              <button type="button" onClick={() => void runMemorySearch()}>
                Search
              </button>
            </header>
            <input value={search} onChange={(event) => setSearch(event.target.value)} />
            <p className="infraNote">
              Single-entry delete uses DELETE /api/v1/memory/{"{memory_id}"} with project_id scope, confirm=true,
              soft-delete status, and audit evidence memory_entry_delete_completed.
            </p>
            <p className="muted">{memoryDeleteStatus}</p>
            <div className="memoryList">
              {memoryResults.length ? (
                memoryResults.map((item) => (
                  <article className="memoryItem" key={item.id}>
                    <div className="memoryItemHeader">
                      <strong>{Math.round(item.relevance_score * 100)}%</strong>
                      <button type="button" className="dangerButton" onClick={() => void deleteMemoryEntry(item.id)}>
                        Delete
                      </button>
                    </div>
                    <p>{item.content}</p>
                    <small>{item.id}</small>
                    <small>Evidence: memory_entry_delete_completed / memory_entry_delete_confirmation_required</small>
                  </article>
                ))
              ) : (
                <p className="muted">No memory result.</p>
              )}
            </div>
          </section>
        </section>
      </section>
    </main>
  );
}
