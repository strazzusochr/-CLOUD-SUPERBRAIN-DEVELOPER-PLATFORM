param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [string]$CandidateSha = "",
  [string]$KeyPath = "",
  [string]$OutputPath = "",
  [switch]$RequireVerified,
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"
$startedAt = Get-Date

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Verification failed: $Label did not contain '$Expected'."
  }
}

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

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Verification failed: $Label is not a valid release candidate id."
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  $configPath = "docs\release-artifacts\current-release-candidate.json"
  if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Missing current release candidate config: $configPath"
  }

  $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  $activeReleaseId = [string]$config.active_release_id
  if ([string]::IsNullOrWhiteSpace($activeReleaseId)) {
    throw "Verification failed: active_release_id is missing from $configPath."
  }

  if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
    $ReleaseId = $activeReleaseId
  }
  Assert-Equal "release id" $ReleaseId $activeReleaseId
  Assert-ReleaseId "release id" $ReleaseId
  Assert-False "production rollout claimed" $config.production_rollout_claimed

  $candidatePath = "docs\release-artifacts\$ReleaseId.md"
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw "Missing active release candidate artifact: $candidatePath"
  }

  $candidate = Get-Content -LiteralPath $candidatePath -Raw
  Assert-Contains "release artifact id" $candidate "release_id: ``$ReleaseId``"
  Assert-Contains "release artifact environment" $candidate "environment: ``production-candidate``"
  Assert-Contains "release artifact non-claim" $candidate "This artifact does not claim a production rollout."

  if ($candidate -notmatch '(?m)^immutable_image_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Verification failed: active release artifact missing immutable_image_commit_sha."
  }
  $immutableSha = $Matches[1]
  Assert-Sha "immutable image commit sha" $immutableSha

  if ([string]::IsNullOrWhiteSpace($CandidateSha)) {
    $CandidateSha = $immutableSha
  }
  Assert-Equal "candidate sha" $CandidateSha $immutableSha

  Assert-Contains "immutable tag set" $candidate "immutable_tag_set: ``ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:$CandidateSha``"
  $parityVerified = $candidate.Contains("immutable_staging_parity_status: ``verified``") -and $candidate.Contains("hosted_selector_observed: ``IMAGE_TAG=$CandidateSha``")
  $parityBlocked = $candidate.Contains("immutable_staging_parity_status: ``blocked_after_frontend_source_build``") -and $candidate.Contains("hosted_selector_observed: ``IMAGE_TAG=staging``")
  if ($RequireVerified -and -not $parityVerified) {
    throw "Verification failed: active release candidate is not currently deployed as the immutable staging selector."
  }
  if (-not $RequireVerified -and -not ($parityVerified -or $parityBlocked)) {
    throw "Verification failed: active release artifact must either verify immutable staging parity or explicitly block it with current selector truth."
  }

  $manualArgs = @{
    ReleaseId = $ReleaseId
    CandidateSha = $CandidateSha
    BaseUrl = $BaseUrl
  }
  if ($RequireVerified) {
    if ([string]::IsNullOrWhiteSpace($KeyPath)) {
      $KeyPath = [Environment]::GetEnvironmentVariable("STAGING_SSH_KEY_PATH")
    }
    if ([string]::IsNullOrWhiteSpace($KeyPath)) {
      throw "RequireVerified needs -KeyPath or STAGING_SSH_KEY_PATH."
    }
    $manualArgs.RequireVerified = $true
    $manualArgs.KeyPath = $KeyPath
  }

  & "scripts\manual\verify-phase5-staging-immutable-parity.ps1" @manualArgs *>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: manual immutable staging parity verifier failed."
  }

  $report = [pscustomobject]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    candidate_sha = $CandidateSha
    require_verified = [bool]$RequireVerified
    report_only = [bool]$ReportOnly
    started_at = $startedAt.ToUniversalTime().ToString("o")
    completed_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  }

  if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 6
  } elseif ($RequireVerified) {
    Write-Host "[current-immutable-staging-parity] verified"
  } elseif ($parityBlocked) {
    Write-Host "[current-immutable-staging-parity] blocked"
  } else {
    Write-Host "[current-immutable-staging-parity] ready"
  }
} finally {
  Pop-Location
}
