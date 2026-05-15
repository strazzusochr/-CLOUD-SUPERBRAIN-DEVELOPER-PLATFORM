param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost,
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Assert-Equal($Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) {
    throw "Phase5 active agent operations bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active agent operations bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active agent operations bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active agent operations bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active agent operations bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active agent operations bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active agent operations bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Invoke-JsonApi([string]$Url) {
  return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" } -TimeoutSec 90
}

function Invoke-RepoScript([string]$Label, [string]$Path, [string[]]$Arguments) {
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1
  $text = ($output | Out-String)
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed: $text"
  }
  Assert-NotSecretBearing $Label $text
  return ,$text
}

function Invoke-AgentRuntimeProbe([string]$BaseUrl) {
  $agents = Invoke-JsonApi "$BaseUrl/api/v1/agents/status"
  Assert-True "queue depth nonnegative" ([int]$agents.queue_depth -ge 0)
  $agentTypes = @($agents.agents | ForEach-Object { [string]$_.type })
  foreach ($role in @("planner", "coder", "tester", "devops")) {
    Assert-True "agent $role visible" ($agentTypes -contains $role)
    $agent = @($agents.agents | Where-Object { [string]$_.type -eq $role }) | Select-Object -First 1
    Assert-Equal "agent $role profile contract" ([string]$agent.profile_contract_version) "agent-profiles-v1"
    Assert-True "agent $role status visible" (-not [string]::IsNullOrWhiteSpace([string]$agent.status))
    Assert-True "agent $role latest status visible" (-not [string]::IsNullOrWhiteSpace([string]$agent.latest_status))
    Assert-True "agent $role blocks live provider" (@($agent.blocked_actions) -contains "live_provider_call")
    Assert-True "agent $role blocks prod deploy" (@($agent.blocked_actions) -contains "prod_deploy")
  }
  Assert-NotSecretBearing "agents status payload" ($agents | ConvertTo-Json -Depth 30 -Compress)

  $contract = Invoke-JsonApi "$BaseUrl/api/v1/tasks/recent/contract"
  Assert-Equal "recent tasks contract version" ([string]$contract.contract_version) "recent-tasks-feed-v1"
  Assert-Equal "recent tasks mode" ([string]$contract.mode) "task_queue_runtime_feed"
  foreach ($field in @("dispatch_id", "logical_role", "provenance_evidence_ref", "result_envelope", "done_validation")) {
    Assert-True "recent tasks top-level field $field" (@($contract.top_level_fields) -contains $field)
  }
  Assert-True "recent tasks dispatch evidence" ($contract.evidence_refs.dispatch_provenance -eq "autonomous_team_dispatch_task_provenance")

  $recent = Invoke-JsonApi "$BaseUrl/api/v1/tasks/recent?limit=20"
  Assert-True "recent tasks payload visible" ($null -ne $recent)
  $tasks = @($recent.tasks)
  Assert-True "recent task rows visible" ($tasks.Count -ge 1)
  $completed = @($tasks | Where-Object { $_.status -eq "completed" }) | Select-Object -First 1
  Assert-True "completed recent task visible" ($null -ne $completed)
  Assert-True "completed recent task result visible" (-not [string]::IsNullOrWhiteSpace([string]$completed.result))
  Assert-NotSecretBearing "recent tasks payload" ($recent | ConvertTo-Json -Depth 30 -Compress)

  return [ordered]@{
    queue_depth = [int]$agents.queue_depth
    agent_count = @($agents.agents).Count
    recent_task_count = $tasks.Count
    latest_task_id = [string]$completed.task_id
  }
}

function Get-BaseUrlArgs([string]$BaseUrl, [bool]$AllowLocalhost) {
  $arguments = @("-BaseUrl", $BaseUrl)
  if ($AllowLocalhost) {
    $arguments += "-AllowLocalhost"
  }
  return ,$arguments
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "BaseUrl is required."
  }
  $BaseUrl = $BaseUrl.TrimEnd("/")
  if ((-not $AllowLocalhost) -and ($BaseUrl -notmatch "^https://")) {
    throw "Phase5 active agent operations bundle requires HTTPS unless -AllowLocalhost is set."
  }

  $configPath = "docs\release-artifacts\current-release-candidate.json"
  Assert-True "current release candidate config exists" (Test-Path -LiteralPath $configPath)
  $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  $activeReleaseId = [string]$config.active_release_id
  if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
    $ReleaseId = $activeReleaseId
  }
  Assert-Equal "release id" $ReleaseId $activeReleaseId
  Assert-ReleaseId "release id" $ReleaseId
  Assert-False "production rollout claimed" $config.production_rollout_claimed

  $candidatePath = "docs\release-artifacts\$ReleaseId.md"
  Assert-True "active release candidate artifact exists" (Test-Path -LiteralPath $candidatePath)
  $candidate = Get-Content -LiteralPath $candidatePath -Raw
  Assert-Contains "candidate id" $candidate "release_id: ``$ReleaseId``"
  Assert-Contains "candidate agent operations proof" $candidate "active_agent_operations_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-agent-operations-bundle-20260515.md``"
  Assert-Contains "candidate non-claim" $candidate "This artifact does not claim a production rollout."
  Assert-NotSecretBearing "candidate artifact" $candidate

  if ($candidate -notmatch '(?m)^source_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Active release artifact is missing source_commit_sha."
  }
  $sourceSha = $Matches[1]
  Assert-Sha "source commit sha" $sourceSha
  if ($candidate -notmatch '(?m)^immutable_image_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Active release artifact is missing immutable_image_commit_sha."
  }
  $immutableSha = $Matches[1]
  Assert-Sha "immutable image commit sha" $immutableSha
  Assert-Contains "candidate hosted selector" $candidate "hosted_selector_observed: ``IMAGE_TAG=$immutableSha``"

  $proofPath = "docs\release-artifacts\$ReleaseId-active-agent-operations-bundle-20260515.md"
  Assert-True "active agent operations proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "base_url: ``https://188-34-191-140.sslip.io``",
    "production_rollout_claimed: ``false``",
    "agent_gate_count: ``8``",
    "changed_horizontal: ``Phase 5 79->80``",
    "changed_vertical: ``Agent Pool 74->75``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active agent operations proof artifact" $proof $required
  }
  Assert-NotSecretBearing "active agent operations proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 81
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 82
  Assert-Contains "phase5 status" $phase5.status "active_agent_operations_bundle_verified"
  $agentPool = @($progress.vertical.items | Where-Object { $_.id -eq "layer_3" }) | Select-Object -First 1
  Assert-Equal "agent pool percent" ([int]$agentPool.percent) 75
  Assert-Contains "agent pool status" $agentPool.status "active_agent_operations_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $gates = [System.Collections.Generic.List[string]]::new()
  $probe = Invoke-AgentRuntimeProbe $BaseUrl
  $gates.Add("agent-status-runtime-probe") | Out-Null
  $gates.Add("recent-tasks-contract") | Out-Null

  $baseUrlArgs = Get-BaseUrlArgs $BaseUrl ([bool]$AllowLocalhost)

  Invoke-RepoScript "autonomous-coding-team" "scripts\verify-autonomous-coding-team.ps1" $baseUrlArgs | Out-Null
  $gates.Add("autonomous-coding-team") | Out-Null
  Invoke-RepoScript "autonomous-roster-master-plan-bundle" "scripts\verify-autonomous-roster-master-plan-bundle.ps1" $baseUrlArgs | Out-Null
  $gates.Add("autonomous-roster-master-plan-bundle") | Out-Null
  Invoke-RepoScript "phase2-runtime-dual-surface" "scripts\verify-phase2-runtime-dual-surface.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase2-runtime-dual-surface") | Out-Null
  Invoke-RepoScript "phase3-live-agent-steering" "scripts\verify-phase3-live-agent-steering.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase3-live-agent-steering") | Out-Null
  Invoke-RepoScript "phase3-live-agent-history" "scripts\verify-phase3-live-agent-history.ps1" $baseUrlArgs | Out-Null
  $gates.Add("phase3-live-agent-history") | Out-Null
  Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @() | Out-Null
  $gates.Add("evidence-artifact-safety") | Out-Null

  Assert-Equal "agent gate count" $gates.Count 8

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    agent_gate_count = $gates.Count
    changed_horizontal = "Phase 5 79->80"
    changed_vertical = "Agent Pool 74->75"
    agent_runtime = $probe
    gates = @($gates)
    policy = [ordered]@{
      mutates_production = $false
      deploys_production = $false
      claims_rollout = $false
      reads_secret_values = $false
      includes_secrets = $false
      live_provider_calls_claimed = $false
      live_mcp_writes_claimed = $false
      local_model_downloads = $false
    }
  }
  Assert-NotSecretBearing "summary" ($summary | ConvertTo-Json -Depth 8 -Compress)

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 8
  } else {
    Write-Host "[phase5-active-agent-operations-bundle] verified"
    Write-Host "[phase5-active-agent-operations-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-agent-operations-bundle] agent_gate_count=$($summary.agent_gate_count)"
  }
} catch {
  if ($ReportOnly) {
    $summary = [ordered]@{
      status = "failed"
      passed = $false
      release_id = $ReleaseId
      base_url = $BaseUrl
      error = $_.Exception.Message
      production_rollout_claimed = $false
    }
    if ($JsonOnly) {
      $summary | ConvertTo-Json -Depth 4
    } else {
      Write-Host "[phase5-active-agent-operations-bundle] failed"
      Write-Host "[phase5-active-agent-operations-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}
