param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

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

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-smoke-proof.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing executed smoke proof artifact: $artifactPath"
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase4 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_4" }).percent)
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "base_url: ``$BaseUrl``",
  "## Executed Sequence",
  "## Results",
  "Root title marker: ``Cloud Superbrain``",
  "Project Progress: ``overall=$expectedOverall``, ``phase4=$expectedPhase4``, ``phase5=$expectedPhase5``",
  "Candidate Verifier: ``passed``",
  "Rollback Drill Verifier: ``passed``",
  "This is not a production rollout proof."
)) {
  Assert-Contains "executed smoke artifact" $artifact $required
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path $candidatePath)) {
  throw "Missing release artifact: $candidatePath"
}
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate smoke evidence linked" $candidate "Executed smoke proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md``"

$htmlCheck = Invoke-PythonJsonCheck @"
import re, ssl, urllib.request
ctx = ssl.create_default_context()
html = urllib.request.urlopen(r"$BaseUrl/", context=ctx, timeout=20).read().decode("utf-8", "replace")
title = re.search(r"<title>(.*?)</title>", html, re.I | re.S)
print(title.group(1).strip() if title else "")
"@
Assert-Contains "hosted root title" $htmlCheck "Cloud Superbrain"

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

$integrityJson = Invoke-PythonJsonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress/integrity", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "hosted integrity" $integrityJson '"status": "verified"'
Assert-Contains "hosted integrity phase4" $integrityJson """phase_4"": $expectedPhase4"
Assert-Contains "hosted integrity phase5" $integrityJson """phase_5"": $expectedPhase5"

$externalGates = Invoke-PythonJsonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/external-gates", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "hosted external gates" $externalGates '"status": "verified"'

$externalMirror = Invoke-PythonJsonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/external-gates/mirror", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "hosted external gate mirror" $externalMirror '"status": "verified"'

$preflight = Invoke-PythonJsonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/clouds/deployment-preflight", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "hosted deployment preflight" $preflight '"status": "verified"'

$completion = Invoke-PythonJsonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress/completion", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "hosted completion contract" $completion '"can_set_all_to_100": false'

Write-Host "[phase5-executed-smoke] verified"
