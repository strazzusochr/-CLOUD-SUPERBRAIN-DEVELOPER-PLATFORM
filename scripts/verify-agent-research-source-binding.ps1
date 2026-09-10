[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-Contains {
  param(
    [string]$Label,
    [string]$Content,
    [string]$Expected
  )
  if (-not $Content.Contains($Expected)) {
    throw "$Label missing required marker: $Expected"
  }
}

function Assert-NotContains {
  param(
    [string]$Label,
    [string]$Content,
    [string]$Forbidden
  )
  if ($Content.Contains($Forbidden)) {
    throw "$Label contains forbidden marker: $Forbidden"
  }
}

Push-Location $repoRoot
try {
  $mainPath = "services\agent-api\app\main.py"
  $llmGatewayPath = "services\llm-gateway\app\main.py"
  $testPath = "services\agent-api\tests\test_agent_research_run.py"
  $frontendPath = "apps\frontend\components\agent-run.tsx"
  $stylesPath = "apps\frontend\app\styles.css"
  $actionMatrixPath = "apps\frontend\lib\actionMatrix.ts"
  $actionSpecPath = "apps\frontend\e2e\22-page-actions.spec.ts"
  $contractPath = "docs\runtime-contracts\agent-research-run.md"
  $projectStatePath = "PROJECT_STATE.md"
  $handoffPath = "AI_HANDOFF.md"
  $verificationPath = "docs\verification-register.md"
  $auditPath = "docs\audit\vision-vs-reality-2026-07-25.md"

  foreach ($path in @(
    $mainPath,
    $llmGatewayPath,
    $testPath,
    $frontendPath,
    $stylesPath,
    $actionMatrixPath,
    $actionSpecPath,
    $contractPath,
    $projectStatePath,
    $handoffPath,
    $verificationPath,
    $auditPath
  )) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "Missing Agent Research source-binding file: $path"
    }
  }

  $mainSource = Get-Content -LiteralPath $mainPath -Raw
  foreach ($required in @(
    'agent-research-run-v3',
    'agent_research_four_role_repo_sources_visible',
    'agent-research-four-role-v1',
    'AGENT_RESEARCH_STEP_ROLES = ("planner", "coder", "tester", "devops")',
    'AGENT_RESEARCH_STEP_OUTPUT_CHARS = 2_000',
    'agent_research_role_binding_payload',
    '"analysis_only": True',
    '"tool_calls": False',
    '"test_execution": False',
    '"deployment_execution": False',
    '"autonomous_software_delivery": False',
    'if profile_id != role',
    'profile.get("agent_id") != role or execution_role != role',
    'AGENT_RESEARCH_GATEWAY_BOOLEAN_FIELDS',
    'type(response_payload.get(field)) is not bool',
    'response_payload.get("contract_version") != LLM_RESPONSES_ADAPTER_CONTRACT_VERSION',
    'response_payload.get("evidence_ref") != LLM_RESPONSES_ADAPTER_EVIDENCE_REF',
    'response_payload.get("trace_id") != trace_id',
    'strict_contract_evidence_trace_and_booleans',
    'llm gateway returned oversized {role} output',
    'agent-research-repo-source-v1',
    'repo_allowlist_lexical',
    '"project-state"',
    '"project-progress"',
    '"agent-roster"',
    'handle.read(AGENT_RESEARCH_SOURCE_MAX_BYTES + 1)',
    '_agent_research_path_is_link',
    'requested_absolute not in allowed_paths[source_id]',
    'resolved.relative_to(resolved_root)',
    '_sanitize_agent_research_source',
    'AGENT_RESEARCH_SOURCE_SENSITIVE_LINE_PATTERN',
    'AGENT_RESEARCH_SOURCE_LONG_HEX_PATTERN',
    'all_allowlisted_sources_must_pass_before_gateway',
    'source_prompt_instructions_trusted',
    '"source_retrieval": True',
    '"source_retrieval_audit_persisted": False',
    '"file_wide_secret_absence_certified": False',
    'raw_document_sha256',
    'sanitized_document_sha256',
    'extract_sha256',
    'hmac.compare_digest(extract_sha256, expected_extract_sha256)',
    'sanitized_sha256={source[''sanitized_document_sha256'']}',
    'if len(context) > AGENT_RESEARCH_SOURCE_CONTEXT_CHARS',
    'fail_closed_without_extract_truncation',
    'arbitrary_path_input',
    'filesystem_writes',
    'bounded_internal_source_exception',
    'three_fixed_baked_project_truth_artifacts',
    'General file browsing must go through MCP scope guard and audit.'
  )) {
    Assert-Contains "Agent API" $mainSource $required
  }
  foreach ($forbidden in @(
    'AGENT_RESEARCH_RUN_CONTRACT_VERSION = "agent-research-run-v1"',
    'AGENT_RESEARCH_RUN_CONTRACT_VERSION = "agent-research-run-v2"',
    '"step_roles": ["planner", "researcher", "writer"]',
    '/api/v1/agent-run/sources/{source_id}',
    'return redact_text("\n\n".join(sections))[:AGENT_RESEARCH_SOURCE_CONTEXT_CHARS]'
  )) {
    Assert-NotContains "Agent API" $mainSource $forbidden
  }

  $llmGatewaySource = Get-Content -LiteralPath $llmGatewayPath -Raw
  Assert-Contains "LLM Gateway Responses adapter" $llmGatewaySource '"secret_output": False'
  Assert-Contains "LLM Gateway Responses adapter" $llmGatewaySource '"local_model_calls": local_call'

  $testSource = Get-Content -LiteralPath $testPath -Raw
  foreach ($required in @(
    'test_four_steps_use_gateway_only_and_match_frontend_shape',
    'test_three_source_context_is_exact_and_hash_bound_in_all_four_gateway_payloads',
    'test_oversized_gateway_output_fails_before_next_role',
    'test_role_profile_drift_stops_before_gateway',
    'test_role_profile_alias_stops_before_gateway',
    'test_gateway_boolean_schema_fails_closed_before_next_role',
    'test_gateway_contract_identity_fails_closed_before_next_role',
    '["planner", "coder", "tester", "devops"]',
    '"llm gateway returned oversized planner output"',
    'test_tampered_extract_hash_stops_before_gateway',
    'test_source_context_overflow_stops_before_gateway',
    'test_source_loading_is_bounded_redacted_and_hash_explicit',
    'test_one_source_outside_fixed_layout_stops_before_gateway',
    'test_required_source_missing_stops_before_gateway',
    'test_parent_link_guard_stops_before_gateway',
    'test_terminal_link_guard_stops_before_gateway',
    'test_oversize_source_reads_only_max_plus_one_and_fails',
    'test_invalid_utf8_source_fails_before_gateway',
    '[REDACTED_LONG_HEX]',
    'raw_sha256={source[''raw_document_sha256'']}',
    'source_read.assert_not_called()',
    'source-secret-value',
    'gateway.assert_not_called()'
  )) {
    Assert-Contains "Agent Research tests" $testSource $required
  }

  $frontendSource = Get-Content -LiteralPath $frontendPath -Raw
  foreach ($required in @(
    'SOURCE_PATHS',
    'STEP_ROLES = ["planner", "coder", "tester", "devops"]',
    'agent-research-run-v3',
    'agent_research_four_role_repo_sources_visible',
    'agent-research-four-role-v1',
    'source_grounded_analysis',
    'candidate.answer === candidate.steps.at(-1)?.content',
    'roleBinding.autonomous_software_delivery === false',
    'typeof candidate.live_provider_calls === "boolean"',
    'typeof candidate.audit_persisted === "boolean"',
    'isNonEmptyString(candidate.trace_id)',
    'isBudget(candidate.budget)',
    'candidate.non_claims.every(isNonEmptyString)',
    'data-audit-persisted={String(run.audit_persisted)}',
    'roles={run.role_binding.gateway_calls} · analysis-only',
    'agent-research-repo-source-v1',
    'repo_allowlist_lexical',
    'source_retrieval_audit_persisted',
    'file_wide_secret_absence_certified',
    'raw_document_sha256',
    'sanitized_document_sha256',
    'extract_sha256',
    'Array.from(source.extract).length <= 900',
    'raw-sha256={s.raw_document_sha256}',
    'sanitized-sha256={s.sanitized_document_sha256}',
    'extract-sha256={s.extract_sha256}',
    'data-testid={`ar-source-detail-${s.source_id}`}',
    'sources={run.source_binding.source_count} · read-only'
  )) {
    Assert-Contains "Agent Research frontend" $frontendSource $required
  }
  Assert-NotContains "Agent Research frontend" $frontendSource 'href={s.url}'

  $stylesSource = Get-Content -LiteralPath $stylesPath -Raw
  foreach ($required in @(
    '.agent-run .ar-planner',
    '.agent-run .ar-coder',
    '.agent-run .ar-tester',
    '.agent-run .ar-devops'
  )) {
    Assert-Contains "Agent Research styles" $stylesSource $required
  }
  Assert-NotContains "Agent Research styles" $stylesSource '.agent-run .ar-researcher'
  Assert-NotContains "Agent Research styles" $stylesSource '.agent-run .ar-writer'

  $actionMatrixSource = Get-Content -LiteralPath $actionMatrixPath -Raw
  Assert-Contains "Action matrix" $actionMatrixSource 'agents-source-detail'
  Assert-Contains "Action matrix" $actionMatrixSource 'exact sanitized extract'
  Assert-Contains "Action matrix" $actionMatrixSource 'four analysis-only roles'
  Assert-NotContains "Action matrix" $actionMatrixSource 'agents-source-link'

  $actionSpecSource = Get-Content -LiteralPath $actionSpecPath -Raw
  Assert-Contains "22-page action spec" $actionSpecSource '"agents-source-detail"'
  Assert-Contains "22-page action spec" $actionSpecSource '"agent-research-run-v3"'
  Assert-Contains "22-page action spec" $actionSpecSource '["planner", "coder", "tester", "devops"]'
  Assert-Contains "22-page action spec" $actionSpecSource '"data-audit-persisted"'
  Assert-Contains "22-page action spec" $actionSpecSource '"data-analysis-only", "true"'
  Assert-NotContains "22-page action spec" $actionSpecSource 'agents-source-link'

  $contractSource = Get-Content -LiteralPath $contractPath -Raw
  foreach ($required in @(
    'agent-research-run-v3',
    'agent_research_four_role_repo_sources_visible',
    'agent-research-four-role-v1',
    'Planner creates',
    'Coder develops',
    'Tester reviews',
    'DevOps synthesizes',
    'analysis_only=true',
    'autonomous_software_delivery=false',
    'aliases are rejected',
    'missing or string-coerced flags fail closed',
    '2,000 Unicode code points',
    'agent-research-repo-source-v1',
    'repo_allowlist_lexical',
    'PROJECT_STATE.md',
    'docs/project-progress.manifest.json',
    'docs/codex-integration/autonomous-agent-roster.json',
    'extracts are never silently truncated after hashing',
    'no source URL or click-through',
    'source_retrieval_audit_persisted=false',
    'file_wide_secret_absence_certified=false',
    'DEV-ONLY; hosted proof still blocked'
  )) {
    Assert-Contains "Agent Research contract document" $contractSource $required
  }
  Assert-NotContains "Agent Research contract document" $contractSource '/api/v1/agent-run/sources/{source_id}'

  foreach ($truthSpec in @(
    [pscustomobject]@{ Path = $projectStatePath; Marker = 'Session-11 P3 Vier-Rollen-Quellenanalyse' },
    [pscustomobject]@{ Path = $handoffPath; Marker = 'Session 11 P3 four-role source analysis' },
    [pscustomobject]@{ Path = $verificationPath; Marker = 'Current Session-11 Agent Research Four-Role Source Analysis' },
    [pscustomobject]@{ Path = $auditPath; Marker = 'agent-research-run-v3' }
  )) {
    $truthSource = Get-Content -LiteralPath $truthSpec.Path -Raw
    Assert-Contains "Truth mirror $($truthSpec.Path)" $truthSource $truthSpec.Marker
  }

  $previousPythonPath = $env:PYTHONPATH
  $previousNoBytecode = $env:PYTHONDONTWRITEBYTECODE
  try {
    $env:PYTHONPATH = (Resolve-Path -LiteralPath "services\agent-api").Path
    $env:PYTHONDONTWRITEBYTECODE = "1"
    @'
from pathlib import Path
import sys
import unittest

source_path = Path("services/agent-api/app/main.py")
compile(source_path.read_text(encoding="utf-8"), str(source_path), "exec")
suite = unittest.defaultTestLoader.discover(
    "services/agent-api/tests",
    pattern="test_agent_research_run.py",
)
count = suite.countTestCases()
result = unittest.TextTestRunner(stream=sys.stdout, verbosity=1).run(suite)
if not result.wasSuccessful():
    raise SystemExit(1)
print(
    f"[agent-research-source] syntax=pass tests={count}/{count} "
    "allowlist=3 roles=4 analysis_only=true read_only=true "
    "external_network=false filesystem_writes=false "
    "source_audit_claim=false"
)
'@ | py -3 -
    if ($LASTEXITCODE -ne 0) {
      throw "Agent Research source-binding unit verification failed"
    }
  } finally {
    $env:PYTHONPATH = $previousPythonPath
    $env:PYTHONDONTWRITEBYTECODE = $previousNoBytecode
  }
} finally {
  Pop-Location
}
