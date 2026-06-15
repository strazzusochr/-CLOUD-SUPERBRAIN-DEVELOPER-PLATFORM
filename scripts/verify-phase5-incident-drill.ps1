param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" }),
  [string]$ExpectedRollbackSha = "ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5"
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

function Invoke-PythonJson($code) {
@"
$code
"@ | py -3 -
}

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-incident-drill.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing incident drill artifact: $artifactPath"
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "incident_type: ``runtime_candidate``",
  "## Evidence Capture",
  "## Decision Path",
  "Current progress carried in drill: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  "GET /api/v1/clouds/deployment-preflight",
  "Incident classification: ``runtime``",
  "Release action: ``keep candidate stopped / no-release``",
  "Rollback decision path: ``use immutable GHCR tag set :$ExpectedRollbackSha if hosted health regresses``",
  "Rollback proof dependency: ``.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md``",
  "docs/runbooks/incident-response.md",
  "docs/runbooks/rollback-deploy.md",
  "Hosted progress remained manifest-backed: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  "This is not an executed rollback."
)) {
  Assert-Contains "incident drill artifact" $artifact $required
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate incident drill linked" $candidate "Incident drill proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md``"

$health = Invoke-PythonJson @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/health", context=ctx, timeout=20) as r:
    print(r.status)
"@
Assert-Contains "health" $health "200"

$integrity = Invoke-PythonJson @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress/integrity", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "integrity" $integrity '"status": "verified"'

$progress = Invoke-PythonJson @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "progress phase5" $progress """percent"": $expectedPhase5"

$metrics = Invoke-PythonJson @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/metrics", context=ctx, timeout=20) as r:
    print(r.status)
    print(r.read().decode("utf-8", "replace")[:300])
"@
Assert-Contains "metrics" $metrics "200"
Assert-Contains "metrics proof" $metrics "superbrain_project_progress_percent"

$audit = Invoke-PythonJson @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/audit/recent?limit=5", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "audit feed" $audit '"events"'

$escalations = Invoke-PythonJson @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/escalations/recent?limit=5", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "escalation feed" $escalations '"events"'

$externalGates = Invoke-PythonJson @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/external-gates", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "external gates" $externalGates '"status": "verified"'

$preflight = Invoke-PythonJson @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/clouds/deployment-preflight", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "deployment preflight" $preflight '"status": "verified"'

Write-Host "[phase5-incident-drill] verified"
