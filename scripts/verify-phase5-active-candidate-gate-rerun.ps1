param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

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

function Assert-True($Label, $Value) {
  if (-not [bool]$Value) {
    throw "Verification failed: $Label expected true."
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
  Assert-Equal "active release id" $activeReleaseId "prod-candidate-2026-05-11-rc1"
  Assert-False "production rollout claimed" $config.production_rollout_claimed

  $candidatePath = "docs\release-artifacts\$activeReleaseId.md"
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw "Missing active release candidate artifact: $candidatePath"
  }
  $candidate = Get-Content -LiteralPath $candidatePath -Raw
  Assert-Contains "candidate proof field" $candidate "active_candidate_gate_rerun_proof: ``docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-candidate-gate-rerun.md``"
  Assert-Contains "candidate proof evidence" $candidate "Active candidate gate rerun proof: ``docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-candidate-gate-rerun.md``"

  if ($candidate -notmatch '(?m)^source_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Verification failed: active candidate missing source_commit_sha."
  }
  $sourceSha = $Matches[1]
  if ($candidate -notmatch '(?m)^immutable_image_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Verification failed: active candidate missing immutable_image_commit_sha."
  }
  $immutableSha = $Matches[1]

  $artifactPath = "docs\release-artifacts\$activeReleaseId-active-candidate-gate-rerun.md"
  if (-not (Test-Path -LiteralPath $artifactPath)) {
    throw "Missing active candidate gate rerun artifact: $artifactPath"
  }
  $artifact = Get-Content -LiteralPath $artifactPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$activeReleaseId``",
    "base_url: ``$BaseUrl``",
    "active_release_id: ``$activeReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "production_rollout_claimed: ``false``",
    "bundle_status: ``passed``",
    "bundle_gate_count: ``3``",
    "current_release_candidate_status: ``verified``",
    "vercel_git_link_status: ``ready``",
    "vercel_project_git_readiness_status: ``ready``",
    "policy_mutates_production: ``false``",
    "policy_deploys_production: ``false``",
    "policy_claims_rollout: ``false``",
    "policy_includes_secrets: ``false``",
    "scripts\verify-active-release-candidate-bundle.ps1 -ReportOnly -JsonOnly -BaseUrl $BaseUrl",
    "scripts\verify-current-release-candidate.ps1 -BaseUrl $BaseUrl",
    "This rerun does not claim a production rollout.",
    "This rerun does not include secret values."
  )) {
    Assert-Contains "active candidate gate rerun artifact" $artifact $required
  }

  $global:LASTEXITCODE = 0
  $bundleRaw = & "scripts\verify-active-release-candidate-bundle.ps1" -ReportOnly -JsonOnly -BaseUrl $BaseUrl 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: active release candidate bundle exited with code $LASTEXITCODE."
  }
  try {
    $bundle = $bundleRaw | ConvertFrom-Json
  } catch {
    throw "Verification failed: active release candidate bundle did not return JSON."
  }
  Assert-Equal "bundle status" $bundle.status "passed"
  Assert-True "bundle passed" $bundle.passed
  Assert-Equal "bundle active release" $bundle.active_release_id $activeReleaseId
  Assert-Equal "bundle source sha" $bundle.source_commit_sha $sourceSha
  Assert-Equal "bundle immutable sha" $bundle.immutable_image_commit_sha $immutableSha
  Assert-Equal "bundle gate count" ([int]$bundle.gate_count) 3
  Assert-False "bundle mutates production" $bundle.policy.mutates_production
  Assert-False "bundle deploys production" $bundle.policy.deploys_production
  Assert-False "bundle claims rollout" $bundle.policy.claims_rollout
  Assert-False "bundle includes secrets" $bundle.policy.includes_secrets

  $gateIds = @($bundle.gates | ForEach-Object { [string]$_.id })
  foreach ($requiredGate in @("current-release-candidate", "vercel-project-git-readiness", "vercel-git-link")) {
    if ($gateIds -notcontains $requiredGate) {
      throw "Verification failed: bundle missing gate '$requiredGate'."
    }
  }

  & "scripts\verify-current-release-candidate.ps1" -ReleaseId $activeReleaseId -BaseUrl $BaseUrl
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: current release candidate verifier exited with code $LASTEXITCODE."
  }

  Write-Host "[phase5-active-candidate-gate-rerun] verified"
} finally {
  Pop-Location
}
