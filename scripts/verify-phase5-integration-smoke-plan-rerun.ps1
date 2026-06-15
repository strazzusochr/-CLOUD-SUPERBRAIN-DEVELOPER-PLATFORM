param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" })
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

function Invoke-PythonJsonCheck($code) {
@"
$code
"@ | py -3 -
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase4 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_4" }).percent)
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifactPath = "docs\release-artifacts\$ReleaseId-integration-smoke-plan-rerun.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing integration smoke plan rerun artifact: $artifactPath"
}

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "base_url: ``$BaseUrl``",
  "overall_percent: ``$expectedOverall``",
  "phase_4_percent: ``$expectedPhase4``",
  "phase_5_percent: ``$expectedPhase5``",
  'current_selector: `IMAGE_TAG=staging`',
  'rollback_selector: `IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`',
  "## Executed Sequence",
  "GET /api/v1/project/progress/completion",
  "GET /api/v1/external-gates/mirror",
  "GET /api/v1/clouds/deployment-preflight",
  'powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1',
  'powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1',
  "candidate decision remained ``no-release``",
  "This is not a production rollout proof."
)) {
  Assert-Contains "integration smoke plan rerun artifact" $artifact $required
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path $candidatePath)) {
  throw "Missing release artifact: $candidatePath"
}
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate integration smoke rerun linked" $candidate "integration_smoke_plan_rerun_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-smoke-plan-rerun.md``"
Assert-Contains "candidate integration smoke rerun evidence linked" $candidate "Active integration smoke plan proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-smoke-plan-rerun.md``"

$rootTitle = Invoke-PythonJsonCheck @"
import re, ssl, urllib.request
ctx = ssl.create_default_context()
html = urllib.request.urlopen(r"$BaseUrl/", context=ctx, timeout=20).read().decode("utf-8", "replace")
title = re.search(r"<title>(.*?)</title>", html, re.I | re.S)
print(title.group(1).strip() if title else "")
"@
Assert-Contains "hosted root title" $rootTitle "Cloud Superbrain"

foreach ($url in @(
  "$BaseUrl/",
  "$BaseUrl/api/v1/health",
  "$BaseUrl/mcp/api/v1/health",
  "$BaseUrl/llm/api/v1/health"
)) {
  $status = Invoke-PythonJsonCheck @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(r.status)
"@
  Assert-Contains "hosted status $url" $status "200"
}

$progressJson = Invoke-PythonJsonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "hosted progress overall" $progressJson """overall_percent"": $expectedOverall"
Assert-Contains "hosted progress phase4" $progressJson """id"": ""phase_4"""
Assert-Contains "hosted progress phase5" $progressJson """id"": ""phase_5"""
Assert-Contains "hosted progress phase5 percent" $progressJson """percent"": $expectedPhase5"

$integrityJson = Invoke-PythonJsonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress/integrity", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "hosted integrity" $integrityJson '"status": "verified"'

$completionJson = Invoke-PythonJsonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress/completion", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "hosted completion" $completionJson '"can_set_all_to_100": false'

$externalGatesJson = Invoke-PythonJsonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/external-gates", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "hosted external gates" $externalGatesJson '"status": "verified"'

$externalMirrorJson = Invoke-PythonJsonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/external-gates/mirror", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "hosted external gates mirror" $externalMirrorJson '"status": "verified"'

$preflightJson = Invoke-PythonJsonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/clouds/deployment-preflight", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "hosted deployment preflight" $preflightJson '"status": "verified"'

Write-Host "[phase5-integration-smoke-plan-rerun] verified"
