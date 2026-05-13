param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [string]$OutputPath = "",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Assert-Equal($Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) {
    throw "Verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Verification failed: $Label expected false."
  }
}

function Assert-True($Label, $Value) {
  if (-not [bool]$Value) {
    throw "Verification failed: $Label expected true."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Invoke-Gate([string]$Id, [string]$ScriptPath, [hashtable]$Arguments) {
  if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Missing gate script for $Id`: $ScriptPath"
  }

  $startedAt = Get-Date
  $global:LASTEXITCODE = 0
  & $ScriptPath @Arguments
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw "Gate failed: $Id exited with code $exitCode."
  }

  return [pscustomobject]@{
    id = $Id
    script = $ScriptPath
    status = "passed"
    started_at = $startedAt.ToUniversalTime().ToString("o")
    completed_at = (Get-Date).ToUniversalTime().ToString("o")
  }
}

function Invoke-JsonGate([string]$Id, [string]$ScriptPath, [hashtable]$Arguments) {
  if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Missing gate script for $Id`: $ScriptPath"
  }

  $startedAt = Get-Date
  $global:LASTEXITCODE = 0
  $raw = & $ScriptPath @Arguments 2>&1 | Out-String
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw "Gate failed: $Id exited with code $exitCode."
  }

  try {
    $report = $raw | ConvertFrom-Json
  } catch {
    throw "Gate failed: $Id did not return JSON."
  }

  return [pscustomobject]@{
    id = $Id
    script = $ScriptPath
    status = "passed"
    started_at = $startedAt.ToUniversalTime().ToString("o")
    completed_at = (Get-Date).ToUniversalTime().ToString("o")
    report = $report
  }
}

function Read-JsonFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing JSON file: $Path"
  }

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  $configPath = "docs\release-artifacts\current-release-candidate.json"
  $config = Read-JsonFile $configPath
  $activeReleaseId = [string]$config.active_release_id
  if ([string]::IsNullOrWhiteSpace($activeReleaseId)) {
    throw "Verification failed: active release id missing from $configPath."
  }

  if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
    $ReleaseId = $activeReleaseId
  }
  Assert-Equal "release id" $ReleaseId $activeReleaseId
  Assert-False "production rollout claimed" $config.production_rollout_claimed

  $candidatePath = "docs\release-artifacts\$ReleaseId.md"
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw "Missing active release candidate artifact: $candidatePath"
  }

  $candidate = Get-Content -LiteralPath $candidatePath -Raw
  if ($candidate -notmatch '(?m)^source_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Verification failed: active release artifact missing source_commit_sha."
  }
  $sourceSha = $Matches[1]
  Assert-Sha "source commit sha" $sourceSha

  if ($candidate -notmatch '(?m)^immutable_image_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Verification failed: active release artifact missing immutable_image_commit_sha."
  }
  $immutableSha = $Matches[1]
  Assert-Sha "immutable image commit sha" $immutableSha

  $gates = [System.Collections.Generic.List[object]]::new()
  $gates.Add((Invoke-Gate "current-release-candidate" "scripts\verify-current-release-candidate.ps1" @{
    ReleaseId = $ReleaseId
    CandidateSha = $immutableSha
    BaseUrl = $BaseUrl
  })) | Out-Null
  $vercelProjectGate = Invoke-JsonGate "vercel-project-git-readiness" "scripts\verify-vercel-project-git-readiness.ps1" @{
    RequireBranchUpstream = $true
    ReportOnly = $true
    JsonOnly = $true
    OutputPath = ""
  }
  $gates.Add($vercelProjectGate) | Out-Null
  $vercelProjectReadiness = $vercelProjectGate.report
  Assert-Equal "Vercel project git readiness status" $vercelProjectReadiness.status "ready"
  Assert-True "Vercel project git ready" $vercelProjectReadiness.ready
  Assert-Equal "Vercel project git blocking failures" ([int]$vercelProjectReadiness.blocking_failure_count) 0

  $vercelGitGate = Invoke-JsonGate "vercel-git-link" "scripts\verify-vercel-git-link.ps1" @{
    ReportOnly = $true
    JsonOnly = $true
    OutputPath = ""
  }
  $gates.Add($vercelGitGate) | Out-Null
  $vercelGitLink = $vercelGitGate.report
  Assert-Equal "Vercel git link status" $vercelGitLink.status "ready"
  Assert-True "Vercel git safe auto deploy" $vercelGitLink.safe_for_git_auto_deploy

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = "passed"
    passed = $true
    active_release_id = $ReleaseId
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    base_url = $BaseUrl
    gate_count = $gates.Count
    gates = @($gates)
    policy = [ordered]@{
      mutates_production = $false
      deploys_production = $false
      claims_rollout = $false
      includes_secrets = $false
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputParent = Split-Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
      New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  }

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 8
  } else {
    Write-Host "[active-release-candidate-bundle] verified"
    Write-Host "[active-release-candidate-bundle] release_id=$ReleaseId"
    Write-Host "[active-release-candidate-bundle] gate_count=$($gates.Count)"
  }
} catch {
  if ($ReportOnly) {
    throw
  }
  throw
} finally {
  Pop-Location
}
