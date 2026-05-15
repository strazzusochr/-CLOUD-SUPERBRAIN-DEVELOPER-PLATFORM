param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Assert-Equal($Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) {
    throw "Phase5 active verifier sweep bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active verifier sweep bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active verifier sweep bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active verifier sweep bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active verifier sweep bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active verifier sweep bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active verifier sweep bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Invoke-JsonApi([string]$Url) {
  return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" } -TimeoutSec 90
}

function Invoke-RepoScript([string]$Label, [string]$Path, [string[]]$ScriptArgs) {
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @ScriptArgs 2>&1
  $text = ($output | Out-String)
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed: $text"
  }
  Assert-NotSecretBearing $Label $text
  return ,$text
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "BaseUrl is required."
  }
  $BaseUrl = $BaseUrl.TrimEnd("/")
  if ($BaseUrl -notmatch "^https://") {
    throw "Phase5 active verifier sweep bundle requires a public HTTPS BaseUrl."
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
  Assert-Contains "candidate environment" $candidate "environment: ``production-candidate``"
  Assert-Contains "candidate non-claim" $candidate "This artifact does not claim a production rollout."
  Assert-Contains "candidate verifier sweep proof" $candidate "active_verifier_sweep_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-verifier-sweep-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-verifier-sweep-bundle-20260515.md"
  Assert-True "active verifier sweep proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "base_url: ``$BaseUrl``",
    "production_rollout_claimed: ``false``",
    "verifier_gate_count: ``20``",
    "changed_horizontal: ``Phase 2 88->89; Phase 5 84->88``",
    "changed_vertical: ``Agent Pool 75->76; LLM Gateway 65->67; MCP Gateway 67->68; Memory 73->74``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active verifier sweep proof artifact" $proof $required
  }
  Assert-NotSecretBearing "active verifier sweep proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 82
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  $phase2 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_2" }) | Select-Object -First 1
  Assert-Equal "progress phase2" ([int]$phase2.percent) 89
  Assert-Contains "phase2 agent success correlation status" $phase2.status "active_agent_success_correlation_runtime_verified"
  Assert-Equal "progress phase5" ([int]$phase5.percent) 88
  Assert-Contains "phase5 status" $phase5.status "active_verifier_sweep_bundle_verified"
  Assert-Contains "phase5 agent success correlation status" $phase5.status "active_agent_success_correlation_bundle_verified"
  Assert-Contains "phase5 memory status" $phase5.status "active_memory_operations_bundle_verified"
  Assert-Contains "phase5 memory success correlation status" $phase5.status "active_memory_success_correlation_bundle_verified"
  Assert-Contains "phase5 agent operations status" $phase5.status "active_agent_operations_bundle_verified"
  Assert-Contains "phase5 LLM operations status" $phase5.status "active_llm_operations_bundle_verified"
  Assert-Contains "phase5 LLM success correlation status" $phase5.status "active_llm_success_correlation_bundle_verified"
  Assert-Contains "phase5 LLM guard correlation status" $phase5.status "active_llm_guard_correlation_bundle_verified"
  Assert-Contains "phase5 MCP operations status" $phase5.status "active_mcp_operations_bundle_verified"
  Assert-Contains "phase5 MCP success correlation status" $phase5.status "active_mcp_success_correlation_bundle_verified"
  Assert-Contains "phase5 MCP guard correlation status" $phase5.status "active_mcp_guard_correlation_bundle_verified"
  $agentPool = @($progress.vertical.items | Where-Object { $_.id -eq "layer_3" }) | Select-Object -First 1
  Assert-Equal "progress agent pool" ([int]$agentPool.percent) 76
  Assert-Contains "agent pool status" $agentPool.status "active_agent_operations_runtime_verified"
  Assert-Contains "agent pool success correlation status" $agentPool.status "active_agent_success_correlation_runtime_verified"
  $llmGateway = @($progress.vertical.items | Where-Object { $_.id -eq "layer_4" }) | Select-Object -First 1
  Assert-Equal "progress LLM Gateway" ([int]$llmGateway.percent) 67
  Assert-Contains "LLM Gateway status" $llmGateway.status "active_llm_operations_runtime_verified"
  Assert-Contains "LLM Gateway success correlation status" $llmGateway.status "active_llm_success_correlation_runtime_verified"
  Assert-Contains "LLM Gateway guard correlation status" $llmGateway.status "active_llm_guard_correlation_runtime_verified"
  $mcpGateway = @($progress.vertical.items | Where-Object { $_.id -eq "layer_5" }) | Select-Object -First 1
  Assert-Equal "progress MCP Gateway" ([int]$mcpGateway.percent) 68
  Assert-Contains "MCP Gateway status" $mcpGateway.status "active_mcp_operations_runtime_verified"
  Assert-Contains "MCP Gateway success correlation status" $mcpGateway.status "active_mcp_success_correlation_runtime_verified"
  Assert-Contains "MCP Gateway guard correlation status" $mcpGateway.status "active_mcp_guard_correlation_runtime_verified"
  $memory = @($progress.vertical.items | Where-Object { $_.id -eq "layer_6" }) | Select-Object -First 1
  Assert-Equal "progress memory" ([int]$memory.percent) 74
  Assert-Contains "memory status" $memory.status "active_memory_operations_runtime_verified"
  Assert-Contains "memory success correlation status" $memory.status "active_memory_success_correlation_runtime_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $currentReleaseOutput = Invoke-RepoScript "current-release-candidate" "scripts\verify-current-release-candidate.ps1" @("-BaseUrl", $BaseUrl, "-ReleaseId", $ReleaseId)
  Assert-Contains "current-release-candidate output" $currentReleaseOutput "[current-release-candidate] verified"

  $activeBundleOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\verify-active-release-candidate-bundle.ps1" -BaseUrl $BaseUrl -ReportOnly -JsonOnly 2>&1
  $activeBundleText = ($activeBundleOutput | Out-String)
  if ($LASTEXITCODE -ne 0) {
    throw "active-release-candidate-bundle failed: $activeBundleText"
  }
  Assert-NotSecretBearing "active-release-candidate-bundle" $activeBundleText
  Assert-Contains "active bundle status" $activeBundleText '"status":  "passed"'
  Assert-Contains "active bundle passed" $activeBundleText '"passed":  true'
  Assert-Contains "active bundle production rollout" $activeBundleText '"production_rollout_claimed":  false'
  Assert-Contains "active bundle gate count" $activeBundleText '"gate_count":  3'

  $hostedSmokeOutput = Invoke-RepoScript "hosted-staging-smoke" "scripts\verify-hosted-staging-smoke.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "hosted smoke output" $hostedSmokeOutput "[hosted-smoke] checks completed"

  $gatewayPolicyOutput = Invoke-RepoScript "phase3-active-gateway-policy-bundle" "scripts\verify-phase3-active-gateway-policy-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "gateway policy output" $gatewayPolicyOutput "[phase3-active-gateway-policy-bundle] verified"

  $runtimeGuardOutput = Invoke-RepoScript "phase5-active-runtime-guard-matrix-bundle" "scripts\verify-phase5-active-runtime-guard-matrix-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "runtime guard output" $runtimeGuardOutput "[phase5-active-runtime-guard-matrix-bundle] verified"

  $gatewayExecutionOutput = Invoke-RepoScript "phase5-active-gateway-execution-bundle" "scripts\verify-phase5-active-gateway-execution-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "gateway execution output" $gatewayExecutionOutput "[phase5-active-gateway-execution-bundle] verified"

  $memoryOperationsOutput = Invoke-RepoScript "phase5-active-memory-operations-bundle" "scripts\verify-phase5-active-memory-operations-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "memory operations output" $memoryOperationsOutput "[phase5-active-memory-operations-bundle] verified"

  $memorySuccessCorrelationOutput = Invoke-RepoScript "phase5-active-memory-success-correlation-bundle" "scripts\verify-phase5-active-memory-success-correlation-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "memory success correlation output" $memorySuccessCorrelationOutput "[phase5-active-memory-success-correlation-bundle] verified"

  $agentOperationsOutput = Invoke-RepoScript "phase5-active-agent-operations-bundle" "scripts\verify-phase5-active-agent-operations-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "agent operations output" $agentOperationsOutput "[phase5-active-agent-operations-bundle] verified"

  $agentSuccessCorrelationOutput = Invoke-RepoScript "phase5-active-agent-success-correlation-bundle" "scripts\verify-phase5-active-agent-success-correlation-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "agent success correlation output" $agentSuccessCorrelationOutput "[phase5-active-agent-success-correlation-bundle] verified"

  $llmOperationsOutput = Invoke-RepoScript "phase5-active-llm-operations-bundle" "scripts\verify-phase5-active-llm-operations-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "LLM operations output" $llmOperationsOutput "[phase5-active-llm-operations-bundle] verified"

  $llmSuccessCorrelationOutput = Invoke-RepoScript "phase5-active-llm-success-correlation-bundle" "scripts\verify-phase5-active-llm-success-correlation-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "LLM success correlation output" $llmSuccessCorrelationOutput "[phase5-active-llm-success-correlation-bundle] verified"

  $llmGuardCorrelationOutput = Invoke-RepoScript "phase5-active-llm-guard-correlation-bundle" "scripts\verify-phase5-active-llm-guard-correlation-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "LLM guard correlation output" $llmGuardCorrelationOutput "[phase5-active-llm-guard-correlation-bundle] verified"

  $mcpOperationsOutput = Invoke-RepoScript "phase5-active-mcp-operations-bundle" "scripts\verify-phase5-active-mcp-operations-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "MCP operations output" $mcpOperationsOutput "[phase5-active-mcp-operations-bundle] verified"

  $mcpSuccessCorrelationOutput = Invoke-RepoScript "phase5-active-mcp-success-correlation-bundle" "scripts\verify-phase5-active-mcp-success-correlation-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "MCP success correlation output" $mcpSuccessCorrelationOutput "[phase5-active-mcp-success-correlation-bundle] verified"

  $mcpGuardCorrelationOutput = Invoke-RepoScript "phase5-active-mcp-guard-correlation-bundle" "scripts\verify-phase5-active-mcp-guard-correlation-bundle.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "MCP guard correlation output" $mcpGuardCorrelationOutput "[phase5-active-mcp-guard-correlation-bundle] verified"

  $llmCatalogOutput = Invoke-RepoScript "phase4-llm-model-catalog" "scripts\verify-phase4-llm-model-catalog.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "llm catalog output" $llmCatalogOutput "status=verified"

  $mcpCatalogOutput = Invoke-RepoScript "phase4-mcp-capability-catalog" "scripts\verify-phase4-mcp-capability-catalog.ps1" @("-BaseUrl", $BaseUrl)
  Assert-Contains "mcp catalog output" $mcpCatalogOutput "status=verified"

  $securityOutput = Invoke-RepoScript "security" "scripts\verify-security.ps1" @()
  Assert-Contains "security output" $securityOutput "[verify-security] verified"

  $artifactSafetyOutput = Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @()
  Assert-Contains "artifact safety output" $artifactSafetyOutput "[evidence-artifact-safety] status=safe"

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    verifier_gate_count = 20
    changed_horizontal = "Phase 2 88->89; Phase 5 84->88"
    changed_vertical = "Agent Pool 75->76; LLM Gateway 65->67; MCP Gateway 67->68; Memory 73->74"
    gates = @(
      "current-release-candidate",
      "active-release-candidate-bundle",
      "hosted-staging-smoke",
      "phase3-active-gateway-policy-bundle",
      "phase5-active-runtime-guard-matrix-bundle",
      "phase5-active-gateway-execution-bundle",
      "phase5-active-memory-operations-bundle",
      "phase5-active-memory-success-correlation-bundle",
      "phase5-active-agent-operations-bundle",
      "phase5-active-agent-success-correlation-bundle",
      "phase5-active-llm-operations-bundle",
      "phase5-active-llm-success-correlation-bundle",
      "phase5-active-llm-guard-correlation-bundle",
      "phase5-active-mcp-operations-bundle",
      "phase5-active-mcp-success-correlation-bundle",
      "phase5-active-mcp-guard-correlation-bundle",
      "phase4-llm-model-catalog",
      "phase4-mcp-capability-catalog",
      "security",
      "evidence-artifact-safety"
    )
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
    Write-Host "[phase5-active-verifier-sweep-bundle] verified"
    Write-Host "[phase5-active-verifier-sweep-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-verifier-sweep-bundle] verifier_gate_count=$($summary.verifier_gate_count)"
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
      Write-Host "[phase5-active-verifier-sweep-bundle] failed"
      Write-Host "[phase5-active-verifier-sweep-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}
