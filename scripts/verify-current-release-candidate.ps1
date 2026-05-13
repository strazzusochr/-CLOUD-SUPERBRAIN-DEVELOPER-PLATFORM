param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [string]$CandidateSha = ""
)

$ErrorActionPreference = "Stop"

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

function Assert-True($label, $value) {
  if (-not [bool]$value) {
    throw "Verification failed: $label expected true."
  }
}

function Assert-Sha($label, $value) {
  if ([string]::IsNullOrWhiteSpace($value) -or $value -notmatch '^[0-9a-f]{40}$') {
    throw "Verification failed: $label is not a lowercase 40-character SHA."
  }
}

function Assert-PublicHttpsUrl($label, $value) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Verification failed: $label is empty."
  }
  try {
    $uri = [System.Uri]$value
  } catch {
    throw "Verification failed: $label is not a valid URL."
  }
  if ($uri.Scheme -ne "https") {
    throw "Verification failed: $label must use https."
  }
  $urlHost = $uri.Host.ToLowerInvariant()
  if (
    $urlHost -eq "localhost" -or
    $urlHost.EndsWith(".local") -or
    $urlHost -match '^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)'
  ) {
    throw "Verification failed: $label must be a public hosted URL, not $urlHost."
  }
}

function Get-Json($url) {
@"
import json, urllib.request
with urllib.request.urlopen(r"$url", timeout=30) as response:
    print(json.dumps(json.load(response)))
"@ | py -3 -
}

function Get-Text($url) {
@"
import urllib.request
with urllib.request.urlopen(r"$url", timeout=30) as response:
    print(response.read(200000).decode("utf-8", "replace"))
"@ | py -3 -
}

function Get-Status($url) {
@"
import urllib.request
with urllib.request.urlopen(r"$url", timeout=30) as response:
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
Assert-PublicHttpsUrl "BaseUrl" $BaseUrl
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

if ($artifact -notmatch '(?m)^source_branch:\s*`([^`]+)`\s*$') {
  throw "Verification failed: active release artifact missing source_branch."
}
$sourceBranch = $Matches[1]
if ([string]::IsNullOrWhiteSpace($sourceBranch)) {
  throw "Verification failed: active release source_branch is empty."
}

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

if ($artifact -notmatch '(?m)^-\s+Vercel frontend:\s*`([^`]+)`\s*$') {
  throw "Verification failed: active release artifact missing Vercel frontend cloud surface."
}
$vercelFrontendUrl = $Matches[1]
Assert-PublicHttpsUrl "Vercel frontend URL" $vercelFrontendUrl
$vercelFrontendHost = ([System.Uri]$vercelFrontendUrl).Host
$vercelStatus = Get-Status $vercelFrontendUrl
Assert-Contains "Vercel frontend status" $vercelStatus "200"
$vercelHtml = Get-Text $vercelFrontendUrl
Assert-Contains "Vercel frontend HTML" $vercelHtml "Cloud Superbrain"

$vercelGitLinkRaw = & "scripts\verify-vercel-git-link.ps1" -ReportOnly -JsonOnly -OutputPath "" 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
  throw "Verification failed: Vercel Git link verifier exited with code $LASTEXITCODE."
}
try {
  $vercelGitLink = $vercelGitLinkRaw | ConvertFrom-Json
} catch {
  throw "Verification failed: Vercel Git link verifier did not return JSON."
}
Assert-Equal "Vercel Git link status" $vercelGitLink.status "ready"
Assert-Equal "Vercel Git link classification" $vercelGitLink.classification "vercel_git_link_ready"
Assert-True "Vercel Git auto deploy safety" $vercelGitLink.safe_for_git_auto_deploy
Assert-Equal "Vercel Git link HTTP status" ([int]$vercelGitLink.http_status) 200
Assert-Equal "Vercel root directory" $vercelGitLink.observed.rootDirectory "apps/frontend"
Assert-Equal "Vercel link type" $vercelGitLink.observed.linkType "github"
Assert-Equal "Vercel link org" $vercelGitLink.observed.linkOrg "strazzusochr"
Assert-Equal "Vercel link repo" $vercelGitLink.observed.linkRepo "-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM"
Assert-Equal "Vercel production branch" $vercelGitLink.observed.linkProductionBranch $sourceBranch
$matchingVerifiedDomain = @($vercelGitLink.observed.domains | Where-Object {
  [string]$_.name -eq $vercelFrontendHost -and [bool]$_.verified
} | Select-Object -First 1)
Assert-True "Vercel frontend domain bound to verified project domain" ($null -ne $matchingVerifiedDomain)
foreach ($checkName in @(
  "project_readable",
  "project_id_matches",
  "framework_nextjs",
  "root_directory_matches",
  "link_type_github",
  "link_org_matches",
  "link_repo_matches",
  "production_branch_matches"
)) {
  Assert-True "Vercel Git link check $checkName" $vercelGitLink.checks.$checkName
}

& "scripts\verify-current-immutable-staging-parity.ps1" -ReleaseId $ReleaseId -CandidateSha $CandidateSha -BaseUrl $BaseUrl
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
