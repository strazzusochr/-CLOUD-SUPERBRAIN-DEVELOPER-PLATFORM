param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" }),
  [string]$CandidateSha = ""
)

$ErrorActionPreference = "Stop"

function Assert-HostedBaseUrlConfigured {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "Hosted verifier requires -BaseUrl or env:STAGING_BASE_URL (HTTPS, non-localhost)."
  }
  if ($BaseUrl -notmatch '^https://') {
    throw "Hosted verifier requires an HTTPS BaseUrl."
  }
  if ($BaseUrl -match 'localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|host\.docker\.internal') {
    throw "Hosted verifier refuses localhost and loopback BaseUrl values."
  }
}
Assert-HostedBaseUrlConfigured


function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) {
    throw "Verification failed: $label expected '$expected' but got '$actual'."
  }
}

function Assert-False($label, $value) {
  if ([bool]$value) {
    throw "Verification failed: $label expected false."
  }
}

function Assert-Sha($label, $value) {
  if ([string]::IsNullOrWhiteSpace($value) -or $value -notmatch '^[0-9a-f]{40}$') {
    throw "Verification failed: $label is not a lowercase 40-character SHA."
  }
}

function Get-Json($url) {
@"
import json, ssl, urllib.request
ctx = ssl._create_unverified_context()
with urllib.request.urlopen(r"$url", timeout=30, context=ctx) as response:
    print(json.dumps(json.load(response)))
"@ | py -3 -
}

function Get-Status($url) {
@"
import ssl, urllib.request
ctx = ssl._create_unverified_context()
with urllib.request.urlopen(r"$url", timeout=30, context=ctx) as response:
    print(response.status)
"@ | py -3 -
}

function Assert-GitCommitExists($sha) {
  git cat-file -e "$sha^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: git commit does not exist locally: $sha"
  }
}

$configPath = "docs\release-artifacts\current-release-candidate.json"
if (-not (Test-Path $configPath)) {
  throw "Missing current release candidate config: $configPath"
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$activeReleaseId = [string]$config.active_release_id
if ([string]::IsNullOrWhiteSpace($activeReleaseId)) {
  throw "Verification failed: active_release_id is missing from $configPath."
}

if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
  $ReleaseId = $activeReleaseId
} else {
  Assert-Equal "requested release id" $ReleaseId $activeReleaseId
}
Assert-False "production rollout claimed flag" $config.production_rollout_claimed

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path $candidatePath)) {
  throw "Missing active release candidate artifact: $candidatePath"
}

$artifact = Get-Content $candidatePath -Raw
Assert-Contains "release artifact id" $artifact "release_id: ``$ReleaseId``"
Assert-Contains "release artifact environment" $artifact "environment: ``production-candidate``"
Assert-Contains "release artifact non-claim" $artifact "This artifact does not claim a production rollout."
Assert-Contains "release artifact rollout gate" $artifact "Production deployment still requires the release-candidate gate bundle and a separate rollout proof."

if ($artifact -notmatch '(?m)^source_commit_sha:\s*`([^`]+)`\s*$') {
  throw "Verification failed: active release artifact missing source_commit_sha."
}
$sourceSha = $Matches[1]
Assert-Sha "source_commit_sha" $sourceSha
Assert-GitCommitExists $sourceSha

if ($artifact -notmatch '(?m)^immutable_image_commit_sha:\s*`([^`]+)`\s*$') {
  throw "Verification failed: active release artifact missing immutable_image_commit_sha."
}
$immutableSha = $Matches[1]
Assert-Sha "immutable_image_commit_sha" $immutableSha
Assert-GitCommitExists $immutableSha

if ([string]::IsNullOrWhiteSpace($CandidateSha)) {
  $CandidateSha = $immutableSha
} else {
  Assert-Equal "candidate sha" $CandidateSha $immutableSha
}

Assert-Contains "release artifact immutable tag set" $artifact "immutable_tag_set: ``ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:$CandidateSha``"

git merge-base --is-ancestor $sourceSha HEAD
if ($LASTEXITCODE -ne 0) {
  throw "Verification failed: active release source is not an ancestor of current HEAD."
}

$rolloutArtifacts = @(Get-ChildItem "docs\release-artifacts" -Filter "prod-release-*.md" -File -ErrorAction SilentlyContinue)
if ($rolloutArtifacts.Count -gt 0) {
  throw "Verification failed: production rollout artifacts already exist under docs\release-artifacts."
}

& "scripts\manual\verify-phase5-staging-immutable-parity.ps1" -ReleaseId $ReleaseId -CandidateSha $CandidateSha -BaseUrl $BaseUrl
if ($LASTEXITCODE -ne 0) {
  throw "Verification failed: immutable staging parity readiness verifier failed."
}

foreach ($url in @(
  "$BaseUrl/",
  "$BaseUrl/api/v1/health",
  "$BaseUrl/mcp/api/v1/health",
  "$BaseUrl/llm/api/v1/health",
  "$BaseUrl/api/v1/project/progress/integrity"
)) {
  $status = Get-Status $url
  Assert-Contains "hosted status $url" $status "200"
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$progress = Get-Json "$BaseUrl/api/v1/project/progress" | ConvertFrom-Json
Assert-Equal "hosted overall progress" ([int]$progress.overall_percent) ([int]$manifest.overall_percent)

$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity" | ConvertFrom-Json
Assert-Equal "hosted integrity status" $integrity.status "verified"

$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion" | ConvertFrom-Json
Assert-False "hosted completion can_set_all_to_100" $completion.can_set_all_to_100

$externalGates = Get-Json "$BaseUrl/api/v1/external-gates" | ConvertFrom-Json
Assert-Equal "hosted external gates status" $externalGates.status "verified"

Write-Host "[current-release-candidate] verified"
