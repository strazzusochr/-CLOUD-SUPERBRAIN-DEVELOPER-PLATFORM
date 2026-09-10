param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 gateway correlation snapshot verification failed: $Label"
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $Text = ($Value | Out-String)
  if (-not $Text.Contains($Expected)) {
    throw "Phase3 gateway correlation snapshot verification failed: $Label did not contain '$Expected'. Value: $Text"
  }
}

function Invoke-JsonApi($Url, $Method = "GET", $Body = $null, $Headers = @{}, $TimeoutSeconds = 30) {
  $requestHeaders = @{ "Accept" = "application/json" }
  foreach ($key in $Headers.Keys) {
    $requestHeaders[$key] = $Headers[$key]
  }
  if ($null -ne $Body) {
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $requestHeaders -ContentType "application/json" -Body $Body -TimeoutSec $TimeoutSeconds
  }
  return Invoke-RestMethod -Method $Method -Uri $Url -Headers $requestHeaders -TimeoutSec $TimeoutSeconds
}

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  throw "BaseUrl is required"
}
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://" -and -not $AllowLocalhost) {
  throw "Phase3 gateway correlation snapshot proof requires HTTPS unless -AllowLocalhost is set"
}

Write-Host "[phase3-gateway-correlation-snapshot] base_url=$BaseUrl"

$frontendHtml = (Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/" -TimeoutSec 60).Content
Assert-Contains "frontend panel" $frontendHtml "Gateway Correlation Snapshot"
Assert-Contains "frontend contract marker" $frontendHtml "gateway-correlation-snapshot-v1"
Assert-Contains "frontend evidence marker" $frontendHtml "gateway_correlation_snapshot_visible"
Assert-Contains "frontend redaction marker" $frontendHtml "gateway_correlation_redaction_enforced"
Assert-Contains "frontend no live write marker" $frontendHtml "gateway_correlation_no_live_write_guard"

$contract = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/contract"
Assert-True "contract version" ($contract.contract_version -eq "gateway-correlation-snapshot-v1")
Assert-True "contract endpoint" ($contract.endpoint -eq "GET /api/v1/security/gateway-correlation/snapshot")
Assert-True "contract read-only" ($contract.read_only -eq $true)
Assert-True "contract no live provider" ($contract.live_provider_calls_claimed -eq $false)
Assert-True "contract no live mcp" ($contract.live_mcp_writes_claimed -eq $false)
Assert-True "contract has task source" (@($contract.source_event_types) -contains "task_completed")
Assert-True "contract has llm source" (@($contract.source_event_types) -contains "llm_gateway_request")
Assert-True "contract has mcp source" (@($contract.source_event_types) -contains "mcp_tool_executed")
Assert-True "contract evidence" ($contract.evidence_ref -eq "gateway_correlation_snapshot_visible")
Assert-True "contract redaction evidence" ($contract.redaction_evidence_ref -eq "gateway_correlation_redaction_enforced")
Assert-True "contract no live write evidence" ($contract.no_live_write_evidence_ref -eq "gateway_correlation_no_live_write_guard")

$sessionId = [guid]::NewGuid().ToString()
$traceId = "gateway-correlation-" + [guid]::NewGuid().ToString("N")
$requestId = "req-gateway-correlation-" + [guid]::NewGuid().ToString("N")
$toolRequestId = "gateway-correlation-tool-" + [guid]::NewGuid().ToString("N")
$runId = "gateway-correlation-run-" + [guid]::NewGuid().ToString("N")
$secretProbe = "sk-proj-gatewaycorrelation" + [guid]::NewGuid().ToString("N")
$headers = @{
  "x-trace-id" = $traceId
  "x-request-id" = $requestId
}

$taskBody = @{
  project_id = "superbrain"
  session_id = $sessionId
  agent_type = "tester"
  task_type = "gateway_correlation_probe"
  task_description = "Verifier proves read-only agent LLM MCP correlation snapshot without live provider calls or live MCP writes."
  trace_id = $traceId
  priority = 6
  max_retries = 1
  allowed_tools = @("memory_read", "filesystem_mcp", "mcp_gateway")
  write_scope = @()
  blocked_actions = @("force_push", "live_provider_call", "prod_deploy", "production_db_write", "push_main", "secret_change")
  acceptance_criteria = @("result_envelope", "done_validation", "audit_log", "gateway_correlation_snapshot_visible")
  human_review_required = $true
} | ConvertTo-Json -Depth 8 -Compress

$taskCreate = Invoke-JsonApi "$BaseUrl/api/v1/internal/tasks" "POST" $taskBody $headers
$taskId = $taskCreate.task.task_id
Assert-True "task id returned" (-not [string]::IsNullOrWhiteSpace($taskId))

$taskStatus = $null
for ($attempt = 0; $attempt -lt 30; $attempt++) {
  Start-Sleep -Seconds 1
  $taskStatus = Invoke-JsonApi "$BaseUrl/api/v1/internal/tasks/$taskId" "GET" $null $headers
  if ($taskStatus.task.status -eq "completed") {
    break
  }
}
Assert-True "agent task completed" ($taskStatus.task.status -eq "completed")
Assert-True "agent task trace persisted" ($taskStatus.task.trace_id -eq $traceId)

$llmBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  messages = @(@{ role = "user"; content = "phase3 gateway correlation proof $secretProbe" })
  stream = $false
  metadata = @{
    trace_id = $traceId
    request_id = $requestId
    session_id = $sessionId
    agent_type = "tester"
  }
} | ConvertTo-Json -Compress -Depth 8
$llmSeed = Invoke-JsonApi "$BaseUrl/llm/v1/chat/completions" "POST" $llmBody $headers
$llmText = $llmSeed | ConvertTo-Json -Depth 20 -Compress
Assert-Contains "llm dry-run no live call" $llmText '"live_provider_calls":false'
Assert-Contains "llm audit persisted" $llmText '"audit_persisted":true'
Assert-Contains "llm deterministic provider" $llmText '"provider_name":"deterministic-dry-run"'

$mcpBody = @{
  tool_request_id = $toolRequestId
  run_id = $runId
  session_id = $sessionId
  trace_id = $traceId
  request_id = $requestId
  agent_role = "devops"
  toolset = "github"
  capability = "delete_branch"
  intent_summary = "Verifier proves gateway correlation snapshot denied MCP evidence without live write."
  input_ref = (@{ branch = "main"; token_hint = "redaction-proof-value" } | ConvertTo-Json -Compress)
  allowed_scope = "feature/gateway-correlation-proof"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = $toolRequestId
  audit_tags = @("phase3", "gateway-correlation", "mcp-deny")
  redaction_required = $true
  expected_output_type = "blocked_tool_result"
} | ConvertTo-Json -Depth 8 -Compress
$mcpSeed = Invoke-JsonApi "$BaseUrl/mcp/api/v1/tools/execute" "POST" $mcpBody $headers
Assert-True "mcp result blocked" ($mcpSeed.status -eq "blocked")
Assert-True "mcp result no raw input leak" (-not (($mcpSeed | ConvertTo-Json -Depth 20 -Compress).Contains("redaction-proof-value")))

$snapshot = $null
$matchedGroup = $null
for ($attempt = 0; $attempt -lt 20; $attempt++) {
  Start-Sleep -Milliseconds 500
  $snapshot = Invoke-JsonApi "$BaseUrl/api/v1/security/gateway-correlation/snapshot?limit=80"
  $matchedGroup = @($snapshot.groups) | Where-Object {
    $_.trace_id -eq $traceId -and
    $_.has_agent_task -eq $true -and
    $_.has_llm_audit -eq $true -and
    $_.has_mcp_audit -eq $true
  } | Select-Object -First 1
  if ($null -ne $matchedGroup) {
    break
  }
}

Assert-True "snapshot contract version" ($snapshot.contract_version -eq "gateway-correlation-snapshot-v1")
Assert-True "snapshot mode" ($snapshot.mode -eq "read_only_agent_llm_mcp_correlation_snapshot")
Assert-True "snapshot read-only" ($snapshot.read_only -eq $true)
Assert-True "snapshot no live provider claim" ($snapshot.live_provider_calls_claimed -eq $false)
Assert-True "snapshot no live mcp claim" ($snapshot.live_mcp_writes_claimed -eq $false)
Assert-True "snapshot prompt bodies absent" ($snapshot.prompt_bodies_returned -eq $false)
Assert-True "snapshot input refs absent" ($snapshot.tool_input_refs_returned -eq $false)
Assert-True "snapshot credentials absent" ($snapshot.provider_credentials_returned -eq $false)
Assert-True "snapshot forbidden hits clear" ([int]$snapshot.forbidden_pattern_hits -eq 0)
Assert-True "snapshot redaction clear" ($snapshot.redaction_status -eq "clear")
Assert-True "snapshot full correlation count" ([int]$snapshot.full_correlation_count -ge 1)
Assert-True "snapshot matched group" ($null -ne $matchedGroup)
Assert-True "snapshot matched state" ($matchedGroup.correlation_state -eq "agent_llm_mcp_correlated")
Assert-True "snapshot matched no live provider" ([int]$matchedGroup.live_provider_call_count -eq 0)
Assert-True "snapshot matched no live mcp" ([int]$matchedGroup.live_mcp_write_count -eq 0)
Assert-True "snapshot matched task event" (@($matchedGroup.event_types) -contains "task_completed")
Assert-True "snapshot matched llm event" (@($matchedGroup.event_types) -contains "llm_gateway_request")
Assert-True "snapshot matched mcp event" (@($matchedGroup.event_types) -contains "mcp_tool_executed")

$snapshotText = $snapshot | ConvertTo-Json -Depth 30 -Compress
Assert-True "snapshot no secret probe leak" (-not $snapshotText.Contains($secretProbe))
Assert-True "snapshot no mcp input leak" (-not $snapshotText.Contains("redaction-proof-value"))
Assert-True "snapshot no prompt body marker" (-not $snapshotText.Contains("prompt_body"))

Write-Host "status=verified"
Write-Host "contract_version=gateway-correlation-snapshot-v1"
Write-Host "evidence_ref=gateway_correlation_snapshot_visible"
Write-Host "redaction_evidence_ref=gateway_correlation_redaction_enforced"
Write-Host "no_live_write_evidence_ref=gateway_correlation_no_live_write_guard"
