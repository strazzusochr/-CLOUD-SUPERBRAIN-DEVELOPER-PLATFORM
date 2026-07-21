param(
  [string]$WorkerUrl = "https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev",
  [string]$OutDir = ".codex\runs\CURRENT\master-goal\t3\agent-pool-hosted-readonly"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Hosted Agent Pool read-only verification failed: $Label" }
  Write-Host "[agent-pool-hosted-readonly] $Label"
}

function Invoke-Json([string]$Uri) {
  return Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec 30
}

function Assert-FalseClaims([string]$Label, $Payload) {
  foreach ($field in @("live_provider_calls", "direct_provider_calls", "live_mcp_writes", "production_deploy", "secret_output")) {
    Assert-True "$Label $field=false" ($Payload.$field -is [bool] -and -not [bool]$Payload.$field)
  }
}

$baseUrl = $WorkerUrl.Trim().TrimEnd("/")
Assert-True "HTTPS boundary" ($baseUrl -match "^https://")

Write-Host "[agent-pool-hosted-readonly] health and contract"
$health = Invoke-Json "$baseUrl/api/v1/health"
Assert-True "health status healthy" ([string]$health.status -eq "healthy")
Assert-True "Cloudflare D1 provider" ([string]$health.provider -eq "cloudflare-d1")
Assert-True "D1 read verified" ([bool]$health.d1_read_verified)
Assert-True "hosted persistence visible" ([bool]$health.persisted)
Assert-True "free-tier policy" ([bool]$health.free_tier_policy)
Assert-True "writes remain authenticated" ([bool]$health.auth_required_for_writes)
Assert-FalseClaims "health" $health

$contract = Invoke-Json "$baseUrl/api/v1/phase2/runtime/contract"
Assert-True "contract version" ([string]$contract.contract_version -eq "cloudflare-d1-langgraph-runtime-v1")
Assert-True "deterministic hosted mode" ([string]$contract.mode -eq "deterministic_hosted_free_runtime")
Assert-True "LangGraph engine" ([string]$contract.engine -eq "langgraph-js")
Assert-True "StateGraph invocation" ([string]$contract.graph_api -eq "StateGraph.compile.invoke")
Assert-True "D1 checkpointing" ([string]$contract.checkpointing -eq "cloudflare-d1")
Assert-True "D1 memory store" ([string]$contract.memory_store -eq "cloudflare-d1")
Assert-True "write auth required" ([bool]$contract.write_auth_required)
Assert-True "contract persisted" ([bool]$contract.persisted)
Assert-FalseClaims "contract" $contract

$expectedRoles = @("planner", "coder", "tester", "devops")
$expectedRoleKey = (($expectedRoles | Sort-Object) -join ",")
$contractRoles = @($contract.graph_nodes | ForEach-Object { [string]$_ })
$contractRoleKey = (($contractRoles | Sort-Object) -join ",")
Assert-True "contract exposes exactly four roles" ($contractRoleKey -eq $expectedRoleKey)

Write-Host "[agent-pool-hosted-readonly] persisted run discovery"
$runs = Invoke-Json "$baseUrl/api/v1/phase2/runtime/runs?limit=20"
Assert-True "run list verified" ([string]$runs.status -eq "verified")
Assert-True "run list D1-backed" ([string]$runs.source -eq "cloudflare-d1" -and [bool]$runs.persisted)
Assert-FalseClaims "run list" $runs

$candidate = @($runs.runs | Where-Object {
  [string]$_.status -eq "completed" -and
  [string]$_.current_node -eq "complete" -and
  [string]$_.checkpointing -eq "cloudflare-d1" -and
  [bool]$_.persisted
} | Sort-Object updated_at -Descending | Select-Object -First 1)
Assert-True "completed persisted run exists" ($candidate.Count -eq 1)
$runSummary = $candidate[0]
$summaryRoles = @($runSummary.role_results | Where-Object { [string]$_.status -eq "completed" } | ForEach-Object { [string]$_.role })
$summaryRoleKey = (($summaryRoles | Sort-Object) -join ",")
Assert-True "run summary exposes four completed roles" ($summaryRoleKey -eq $expectedRoleKey)
Assert-FalseClaims "run summary" $runSummary

Write-Host "[agent-pool-hosted-readonly] persisted run readback"
$run = Invoke-Json "$baseUrl/api/v1/phase2/runtime/runs/$($runSummary.run_id)"
Assert-True "run id stable" ([string]$run.run_id -eq [string]$runSummary.run_id)
Assert-True "run terminal state" ([string]$run.status -eq "completed" -and [string]$run.current_node -eq "complete")
Assert-True "run D1 checkpoint readback" ([string]$run.checkpointing -eq "cloudflare-d1" -and [bool]$run.persisted)
Assert-True "prompt represented only by SHA-256" ([string]$run.prompt_sha256 -match "^[0-9a-f]{64}$")
Assert-True "run evidence reference" ([string]$run.evidence_ref -eq "cloudflare_d1_langgraph_roundtrip")
Assert-FalseClaims "run readback" $run

$tasks = @($run.tasks)
Assert-True "exactly four persisted tasks" ($tasks.Count -eq 4)
$taskRoles = @($tasks | Where-Object { [string]$_.status -eq "completed" } | ForEach-Object { [string]$_.agent_role })
$taskRoleKey = (($taskRoles | Sort-Object) -join ",")
Assert-True "persisted task roles match contract" ($taskRoleKey -eq $expectedRoleKey)
foreach ($role in $expectedRoles) {
  $task = @($tasks | Where-Object { [string]$_.agent_role -eq $role })
  Assert-True "$role task unique and completed" ($task.Count -eq 1 -and [string]$task[0].status -eq "completed")
  Assert-True "$role task evidence persisted" ([string]$task[0].output_json -match "cloudflare_d1_${role}_task_persisted")
}

if (-not (Test-Path -LiteralPath $OutDir)) {
  New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$reportPath = Join-Path $OutDir "report-$stamp.json"
$report = [ordered]@{
  contract_version = "hosted-agent-pool-readonly-v1"
  status = "verified"
  evidence_ref = "hosted_cloudflare_d1_four_role_agent_pool_readback_proof"
  transport = "https_read_only"
  provider = "cloudflare_workers_d1"
  worker_url = $baseUrl
  run_id = [string]$run.run_id
  thread_id = [string]$run.thread_id
  prompt_sha256 = [string]$run.prompt_sha256
  roles = $expectedRoles
  task_count = $tasks.Count
  checkpointing = [string]$run.checkpointing
  persisted = $true
  paid_provider = $false
  token_used = $false
  provider_write = $false
  live_provider_calls = $false
  direct_provider_calls = $false
  live_mcp_writes = $false
  production_deploy = $false
  secret_output = $false
  verified_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  non_claims = @(
    "This read-only proof revalidates an existing hosted deterministic four-role run; it does not create a new run.",
    "It does not prove Redis worker-pool scaling, priority-queue parity, live LLM calls, live MCP writes, release promotion, or production readiness.",
    "No authentication token, provider mutation, or paid provider is used."
  )
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8
Write-Host "[agent-pool-hosted-readonly] report=$reportPath"
Write-Host "[agent-pool-hosted-readonly] checks completed"
