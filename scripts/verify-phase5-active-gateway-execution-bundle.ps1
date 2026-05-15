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
    throw "Phase5 active gateway execution bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active gateway execution bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active gateway execution bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active gateway execution bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active gateway execution bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active gateway execution bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active gateway execution bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Invoke-JsonApi([string]$Url) {
  return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" } -TimeoutSec 90
}

function Convert-ScriptArguments([hashtable]$Arguments) {
  $items = [System.Collections.Generic.List[string]]::new()
  foreach ($entry in $Arguments.GetEnumerator()) {
    $name = "-$($entry.Key)"
    if ($entry.Value -is [bool] -or $entry.Value -is [switch]) {
      if ([bool]$entry.Value) {
        $items.Add($name) | Out-Null
      }
    } elseif ($null -ne $entry.Value) {
      $items.Add($name) | Out-Null
      $items.Add([string]$entry.Value) | Out-Null
    }
  }
  return @($items)
}

function Invoke-RepoScript([string]$Label, [string]$Path, [hashtable]$Arguments) {
  $argumentList = Convert-ScriptArguments $Arguments
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @argumentList 2>&1
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
    throw "Phase5 active gateway execution bundle requires HTTPS unless -AllowLocalhost is set."
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
  Assert-Contains "candidate gateway execution proof" $candidate "active_gateway_execution_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-gateway-execution-bundle-20260515.md``"
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

  $proofPath = "docs\release-artifacts\$ReleaseId-active-gateway-execution-bundle-20260515.md"
  Assert-True "active gateway execution proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "base_url: ``https://188-34-191-140.sslip.io``",
    "production_rollout_claimed: ``false``",
    "execution_gate_count: ``8``",
    "changed_horizontal: ``Phase 5 77->78``",
    "changed_vertical: ``none``",
    "This proof does not claim a production rollout.",
    "This proof does not claim release promotion.",
    "This proof does not claim live LLM provider calls.",
    "This proof does not claim live MCP writes.",
    "This proof does not claim local model downloads.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active gateway execution proof artifact" $proof $required
  }
  Assert-NotSecretBearing "active gateway execution proof artifact" $proof

  $progress = Invoke-JsonApi "$BaseUrl/api/v1/project/progress"
  Assert-Equal "progress overall" ([int]$progress.overall_percent) 81
  $phase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "progress phase5" ([int]$phase5.percent) 86
  Assert-Contains "phase5 status" $phase5.status "active_gateway_execution_bundle_verified"
  Assert-NotSecretBearing "progress payload" ($progress | ConvertTo-Json -Depth 20 -Compress)

  $gates = [System.Collections.Generic.List[string]]::new()
  $phase2Args = @{ BaseUrl = $BaseUrl }
  if ($AllowLocalhost) { $phase2Args.AllowLocalhost = $true }
  Invoke-RepoScript "phase2-runtime-dual-surface" "scripts\verify-phase2-runtime-dual-surface.ps1" $phase2Args | Out-Null
  $gates.Add("phase2-runtime-dual-surface") | Out-Null

  $gatewaySnapshotArgs = @{ BaseUrl = $BaseUrl }
  $gatewayFullArgs = @{ BaseUrl = $BaseUrl; RequireFullCorrelation = $true }
  if ($AllowLocalhost) {
    $gatewaySnapshotArgs.AllowLocalhost = $true
    $gatewayFullArgs.AllowLocalhost = $true
  }
  Invoke-RepoScript "phase3-gateway-correlation-snapshot" "scripts\verify-phase3-gateway-correlation-snapshot.ps1" $gatewaySnapshotArgs | Out-Null
  $gates.Add("phase3-gateway-correlation-snapshot") | Out-Null
  Invoke-RepoScript "phase3-gateway-correlation-risk-rollup" "scripts\verify-phase3-gateway-correlation-risk-rollup.ps1" $gatewayFullArgs | Out-Null
  $gates.Add("phase3-gateway-correlation-risk-rollup") | Out-Null
  Invoke-RepoScript "phase3-gateway-correlation-timeline" "scripts\verify-phase3-gateway-correlation-timeline.ps1" $gatewayFullArgs | Out-Null
  $gates.Add("phase3-gateway-correlation-timeline") | Out-Null

  if ($AllowLocalhost) {
    Invoke-RepoScript "browser-contract" "scripts\verify-browser-contract.ps1" @{ BaseUrl = $BaseUrl; AllowLocalhost = $true } | Out-Null
    $gates.Add("browser-contract") | Out-Null
  } else {
    Invoke-RepoScript "phase4-agent-llm-streaming-contract-runtime" "scripts\verify-phase4-agent-llm-streaming-contract-runtime-hosted.ps1" @{ BaseUrl = $BaseUrl } | Out-Null
    $gates.Add("phase4-agent-llm-streaming-contract-runtime") | Out-Null
    Invoke-RepoScript "phase4-mcp-devops-hosted" "scripts\verify-phase4-mcp-devops-hosted.ps1" @{ BaseUrl = $BaseUrl } | Out-Null
    $gates.Add("phase4-mcp-devops-hosted") | Out-Null
    Invoke-RepoScript "hosted-staging-smoke" "scripts\verify-hosted-staging-smoke.ps1" @{ BaseUrl = $BaseUrl } | Out-Null
    $gates.Add("hosted-staging-smoke") | Out-Null
  }

  Invoke-RepoScript "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @{} | Out-Null
  $gates.Add("evidence-artifact-safety") | Out-Null
  if ($AllowLocalhost) {
    Assert-Equal "local execution gate count" $gates.Count 6
  } else {
    Assert-Equal "hosted execution gate count" $gates.Count 8
  }

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    execution_gate_count = $gates.Count
    changed_horizontal = "Phase 5 77->78"
    changed_vertical = "none"
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
    Write-Host "[phase5-active-gateway-execution-bundle] verified"
    Write-Host "[phase5-active-gateway-execution-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-gateway-execution-bundle] execution_gate_count=$($summary.execution_gate_count)"
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
      Write-Host "[phase5-active-gateway-execution-bundle] failed"
      Write-Host "[phase5-active-gateway-execution-bundle] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  Pop-Location
}
