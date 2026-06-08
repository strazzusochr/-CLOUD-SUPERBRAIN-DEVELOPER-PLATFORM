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

function Invoke-PythonCheck($code) {
@"
$code
"@ | py -3 -
}

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-post-rollback-observability-revalidation.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing post-rollback observability revalidation artifact: $artifactPath"
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  'revalidation_scope: `post_rollback_observability_runtime_truth`',
  '## Reviewed Endpoints',
  '## Results',
  "Progress remained: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'Metrics exposed project progress gauge: `superbrain_project_progress_percent`',
  'Candidate decision remained: `no-release`',
  'This is not a live provider claim.'
)) {
  Assert-Contains "post-rollback observability artifact" $artifact $required
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate observability revalidation linked" $candidate 'post_rollback_observability_revalidation_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-observability-revalidation.md`'

$health = Invoke-PythonCheck @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/health", context=ctx, timeout=20) as r:
    print(r.status)
"@
Assert-Contains "health" $health "200"

$progress = Invoke-PythonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "progress phase5" $progress """percent"": $expectedPhase5"

$integrity = Invoke-PythonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress/integrity", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "integrity" $integrity '"status": "verified"'

$metrics = Invoke-PythonCheck @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/metrics", context=ctx, timeout=20) as r:
    print(r.status)
    print(r.read().decode("utf-8", "replace")[:400])
"@
Assert-Contains "metrics status" $metrics "200"
Assert-Contains "metrics gauge" $metrics "superbrain_project_progress_percent"

$audit = Invoke-PythonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/audit/recent?limit=5", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "audit" $audit '"events"'

$escalations = Invoke-PythonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/escalations/recent?limit=5", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "escalations" $escalations '"events"'

$externalGates = Invoke-PythonCheck @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/external-gates", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "external gates" $externalGates '"status": "verified"'

Write-Host "[phase5-post-rollback-observability-revalidation] verified"
