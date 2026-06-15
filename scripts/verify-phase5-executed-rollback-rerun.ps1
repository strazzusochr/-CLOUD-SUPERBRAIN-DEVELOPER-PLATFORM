param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$ExpectedSha = "ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5",
  [string]$KeyPath = $env:STAGING_SSH_KEY_PATH,
  [string]$RemoteUser = "root",
  [string]$RemoteHost = $env:STAGING_SSH_HOST,
  [string]$RemoteAppDir = "/app",
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" }),
  [string]$ExpectedLiveSelector = ""
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

function Get-Json($url) {
  @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@ | py -3 -
}

function Resolve-ExpectedLiveSelector($explicitSelector) {
  if (-not [string]::IsNullOrWhiteSpace($explicitSelector)) {
    return $explicitSelector
  }

  $currentCandidatePath = "docs\release-artifacts\prod-candidate-2026-05-11-rc1.md"
  if (Test-Path $currentCandidatePath) {
    $currentCandidate = Get-Content $currentCandidatePath -Raw
    if ($currentCandidate -match 'hosted_selector_observed:\s*`([^`]+)`') {
      return $Matches[1]
    }
  }

  return "IMAGE_TAG=staging"
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)
$expectedLiveSelector = Resolve-ExpectedLiveSelector $ExpectedLiveSelector

$artifactPath = ".phase1-artifacts\phase5-executed-rollback-rerun-20260507.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing executed rollback rerun artifact: $artifactPath"
}
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  "Status: ``verified``",
  "Candidate: ``$ReleaseId``",
  "Current progress reference: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  "Integrity status: ``verified``",
  "Executed rollback selector: ``IMAGE_TAG=$ExpectedSha``",
  "Restored candidate selector: ``IMAGE_TAG=staging``",
  "Owner decision: ``no-release``"
)) {
  Assert-Contains "executed rollback rerun artifact" $artifact $required
}

$baseArtifact = Get-Content ".phase1-artifacts\phase5-executed-rollback-prod-candidate-20260505-rc1.md" -Raw
Assert-Contains "executed rollback base artifact" $baseArtifact "Executed rollback selector: IMAGE_TAG=$ExpectedSha"
Assert-Contains "executed rollback base artifact" $baseArtifact "Restored candidate selector: IMAGE_TAG=staging"

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate rerun linked" $candidate "executed_rollback_rerun_proof: ``.phase1-artifacts/phase5-executed-rollback-rerun-20260507.md``"

$selector = (& ssh -i $KeyPath -o StrictHostKeyChecking=no "${RemoteUser}@${RemoteHost}" "cd $RemoteAppDir && grep '^IMAGE_TAG=' .env") | Out-String
if ($LASTEXITCODE -ne 0) {
  throw "Verification failed: unable to read remote IMAGE_TAG selector."
}
Assert-Contains "remote selector" $selector $expectedLiveSelector

foreach ($url in @(
  "$BaseUrl/",
  "$BaseUrl/api/v1/health",
  "$BaseUrl/mcp/api/v1/health",
  "$BaseUrl/llm/api/v1/health"
)) {
  $status = @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(r.status)
"@ | py -3 -
  Assert-Contains "hosted status $url" $status "200"
}

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "progress phase5" $progress """percent"": $expectedPhase5"

$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "integrity status" $integrity '"status": "verified"'

Write-Host "[phase5-executed-rollback-rerun] verified"
