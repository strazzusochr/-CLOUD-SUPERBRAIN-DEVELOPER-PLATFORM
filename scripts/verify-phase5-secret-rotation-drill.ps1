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

function Invoke-Python($code) {
@"
$code
"@ | py -3 -
}

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-secret-rotation-drill.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing secret rotation drill artifact: $artifactPath"
}
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "rotation_scope: ``candidate_runtime_credentials``",
  "## Rotation Sequence",
  "## Decision Path",
  "Rotation classification: ``candidate_secret_rotation``",
  "Repo storage of new secret values: ``forbidden``",
  "Old value handling: ``deactivate or replace in provider system``",
  "docs/runbooks/secret-rotation.md",
  "docs/runbooks/rollback-deploy.md",
  "docs/runbooks/incident-response.md",
  "This does not reveal or store any secret value."
)) {
  Assert-Contains "secret rotation drill artifact" $artifact $required
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate secret rotation linked" $candidate "Secret rotation drill proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md``"

$health = Invoke-Python @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/health", context=ctx, timeout=20) as r:
    print(r.status)
"@
Assert-Contains "health" $health "200"

$progress = Invoke-Python @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "progress phase5" $progress '"label": "Phase 5 - Release Readiness"'
Assert-Contains "progress phase5" $progress """percent"": $expectedPhase5"

$integrity = Invoke-Python @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress/integrity", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "integrity" $integrity '"status": "verified"'
Assert-Contains "integrity phase5" $integrity """phase_5"": $expectedPhase5"

$externalGates = Invoke-Python @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/external-gates", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "external gates" $externalGates '"status": "verified"'

$preflight = Invoke-Python @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/clouds/deployment-preflight", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "deployment preflight" $preflight '"status": "verified"'

Write-Host "[phase5-secret-rotation-drill] verified"
