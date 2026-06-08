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
  if (-not $text.Contains($expected)) { throw "Verification failed: $label did not contain '$expected'." }
}

function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) { throw "Verification failed: $label expected '$expected' but got '$actual'." }
}

function Get-JsonPy($code) {
  $content = $code | py -3 -
  return ($content | ConvertFrom-Json)
}
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase4 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_4" }).percent)
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifactPath = "docs\release-artifacts\$ReleaseId-smoke-recheck.md"
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "overall_percent: ``$expectedOverall``",
  "phase_4_percent: ``$expectedPhase4``",
  "phase_5_percent: ``$expectedPhase5``",
  'Root title marker: `Cloud Superbrain`',
  "Current progress carried in smoke recheck: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'Candidate decision remained `no-release`'
)) { Assert-Contains "smoke recheck artifact" $artifact $required }

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate smoke recheck proof linked" $candidate 'smoke_recheck_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-recheck.md`'
Assert-Contains "candidate evidence smoke recheck proof linked" $candidate 'Smoke recheck proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-recheck.md`'

$title = @"
import re, ssl, urllib.request
ctx = ssl.create_default_context()
html = urllib.request.urlopen(r'''$BaseUrl/''', context=ctx, timeout=20).read().decode('utf-8','replace')
m = re.search(r'<title>(.*?)</title>', html, re.I | re.S)
print(m.group(1).strip() if m else '')
"@ | py -3 -
Assert-Contains "hosted root title" $title "Cloud Superbrain"

foreach ($url in @(
  "$BaseUrl/",
  "$BaseUrl/api/v1/health",
  "$BaseUrl/mcp/api/v1/health",
  "$BaseUrl/llm/api/v1/health"
)) {
  $status = @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r'''$url''', context=ctx, timeout=20) as r:
    print(r.status)
"@ | py -3 -
  Assert-Contains "hosted status $url" $status "200"
}

$progress = Get-JsonPy @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r'''$BaseUrl/api/v1/project/progress''', context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
$phase4 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$phase5 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1
Assert-Equal "hosted overall percent" $progress.overall_percent $expectedOverall
Assert-Equal "hosted phase4 percent" $phase4.percent $expectedPhase4
Assert-Equal "hosted phase5 percent" $phase5.percent $expectedPhase5

$integrity = Get-JsonPy @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r'''$BaseUrl/api/v1/project/progress/integrity''', context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Equal "hosted integrity status" $integrity.status "verified"

$mirror = Get-JsonPy @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r'''$BaseUrl/api/v1/external-gates/mirror''', context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Equal "external gate mirror status" $mirror.status "verified"

$gates = Get-JsonPy @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r'''$BaseUrl/api/v1/external-gates''', context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Equal "external gates status" $gates.status "verified"

$completion = Get-JsonPy @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r'''$BaseUrl/api/v1/project/progress/completion''', context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
if ($completion.can_set_all_to_100 -ne $false) { throw "Verification failed: completion gate must remain fail-closed." }

$preflightContract = Get-JsonPy @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r'''$BaseUrl/api/v1/clouds/deployment-preflight/contract''', context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Equal "deployment preflight contract version" $preflightContract.contract_version "cloud-deployment-preflight-surface-v1"

$preflight = Get-JsonPy @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r'''$BaseUrl/api/v1/clouds/deployment-preflight''', context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Equal "deployment preflight status" $preflight.status "verified"

Write-Host "[phase5-smoke-recheck] verified"
