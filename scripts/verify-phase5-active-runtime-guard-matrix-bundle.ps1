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
    throw "Phase5 active runtime guard matrix bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active runtime guard matrix bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active runtime guard matrix bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active runtime guard matrix bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active runtime guard matrix bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active runtime guard matrix bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active runtime guard matrix bundle verification failed: $Label is not a valid release candidate id."
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
  if ((-not $AllowLocalhost) -and ($BaseUrl -notmatch "^https://")) {
    throw "Phase5 active runtime guard matrix bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate runtime guard bundle proof" $candidate "active_runtime_guard_matrix_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-runtime-guard-matrix-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-runtime-guard-matrix-bundle-20260515.md"
  Assert-True "active runtime guard matrix proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "production_rollout_claimed: ``false``",
    "runtime_guard_gate_count: ``6``",
    "changed_horizontal: ``none``",
    "changed_vertical: ``none``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active runtime guard matrix proof artifact" $proof $required
  }
  if ($AllowLocalhost) {
    Assert-Contains "active runtime guard matrix proof local command" $proof "scripts\verify-phase5-active-runtime-guard-matrix-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost"
    Assert-Contains "active runtime guard matrix proof local base" $proof "local_control_plane_url: ``$BaseUrl``"
  } else {
    Assert-Contains "active runtime guard matrix proof base url" $proof "base_url: ``$BaseUrl``"
  }
  Assert-NotSecretBearing "active runtime guard matrix proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 81
  $phase3 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_3" }) | Select-Object -First 1
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase3" ([int]$phase3.percent) 95
  Assert-Equal "progress phase5" ([int]$phase5.percent) 86

  $agentPool = @($progress.vertical.items | Where-Object { $_.id -eq "layer_3" }) | Select-Object -First 1
  $llmLayer = @($progress.vertical.items | Where-Object { $_.id -eq "layer_4" }) | Select-Object -First 1
  $mcpLayer = @($progress.vertical.items | Where-Object { $_.id -eq "layer_5" }) | Select-Object -First 1
  Assert-Equal "agent pool percent" ([int]$agentPool.percent) 76
  Assert-Equal "llm gateway percent" ([int]$llmLayer.percent) 66
  Assert-Equal "mcp gateway percent" ([int]$mcpLayer.percent) 67
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $steeringArgs = @("-BaseUrl", $BaseUrl)
  if ($AllowLocalhost) { $steeringArgs += "-AllowLocalhost" }
  $steeringOutput = Invoke-RepoScript "phase3-live-agent-steering" "scripts\verify-phase3-live-agent-steering.ps1" $steeringArgs
  Assert-Contains "phase3-live-agent-steering output" $steeringOutput "[phase3-live-agent] ok"

  $historyArgs = @("-BaseUrl", $BaseUrl)
  if ($AllowLocalhost) { $historyArgs += "-AllowLocalhost" }
  $historyOutput = Invoke-RepoScript "phase3-live-agent-history" "scripts\verify-phase3-live-agent-history.ps1" $historyArgs
  Assert-Contains "phase3-live-agent-history output" $historyOutput "[phase3-live-agent-history] ok"

  $llmGuardArgs = @("-BaseUrl", $BaseUrl)
  if ($AllowLocalhost) { $llmGuardArgs += "-AllowLocalhost" }
  $llmGuardOutput = Invoke-RepoScript "phase4-llm-live-provider-guard" "scripts\verify-phase4-llm-live-provider-guard.ps1" $llmGuardArgs
  Assert-Contains "phase4-llm-live-provider-guard output" $llmGuardOutput "[phase4-llm-live-provider-guard] ok"

  $mcpGuardArgs = @("-BaseUrl", $BaseUrl)
  if ($AllowLocalhost) { $mcpGuardArgs += "-AllowLocalhost" }
  $mcpGuardOutput = Invoke-RepoScript "phase4-mcp-security-guard" "scripts\verify-phase4-mcp-security-guard.ps1" $mcpGuardArgs
  Assert-Contains "phase4-mcp-security-guard output" $mcpGuardOutput "[phase4-mcp-security-guard] ok"

  $browserArgs = @("-BaseUrl", $BaseUrl)
  if ($AllowLocalhost) { $browserArgs += "-AllowLocalhost" }
  $browserOutput = Invoke-RepoScript "browser-contract" "scripts\verify-browser-contract.ps1" $browserArgs
  Assert-Contains "browser-contract output" $browserOutput "[browser-contract] checks completed"

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
    runtime_guard_gate_count = 6
    changed_horizontal = "none"
    changed_vertical = "none"
    gates = @(
      "phase3-live-agent-steering",
      "phase3-live-agent-history",
      "phase4-llm-live-provider-guard",
      "phase4-mcp-security-guard",
      "browser-contract",
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
    Write-Host "[phase5-active-runtime-guard-matrix-bundle] verified"
    Write-Host "[phase5-active-runtime-guard-matrix-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-runtime-guard-matrix-bundle] runtime_guard_gate_count=$($summary.runtime_guard_gate_count)"
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
      Write-Host "[phase5-active-runtime-guard-matrix-bundle] failed"
      Write-Host "[phase5-active-runtime-guard-matrix-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}
