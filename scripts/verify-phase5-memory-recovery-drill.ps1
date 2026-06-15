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

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-memory-recovery-drill.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing memory recovery drill artifact: $artifactPath"
}
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "memory_scope: ``project-scoped recovery decision``",
  "## Evidence Capture",
  "## Decision Path",
  "Recovery classification: ``candidate_memory_recovery``",
  "Automatic restore executed: ``no``",
  "Release action if memory integrity regresses: ``keep candidate stopped / no-release``",
  "docs/runbooks/memory-recovery.md",
  "docs/runbooks/incident-response.md",
  "docs/runbooks/rollback-deploy.md",
  "This is not an executed restore."
)) {
  Assert-Contains "memory recovery drill artifact" $artifact $required
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
$candidate = Get-Content $candidatePath -Raw
Assert-Contains "candidate memory recovery linked" $candidate "Memory recovery drill proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md``"

$apiHealth = Invoke-Python @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/health", context=ctx, timeout=20) as r:
    print(r.status)
"@
Assert-Contains "api health" $apiHealth "200"

$progress = Invoke-Python @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "progress phase5" $progress """percent"": $expectedPhase5"

$integrity = Invoke-Python @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress/integrity", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "integrity" $integrity '"status": "verified"'
Assert-Contains "integrity phase5" $integrity """phase_5"": $expectedPhase5"

$embeddingContract = Invoke-Python @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/memory/embedding-consistency/contract", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "embedding consistency contract" $embeddingContract '"contract_version": "memory-embedding-consistency-v1"'
Assert-Contains "embedding consistency status" $embeddingContract '"status": "verified"'

$purgeContract = Invoke-Python @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/memory/purge/contract", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "purge contract version" $purgeContract '"contract_version": "memory-dsgvo-purge-v1"'
Assert-Contains "purge contract job endpoint" $purgeContract '"job_status_endpoint": "GET /api/v1/memory/purge/jobs/{job_id}"'

$projectId = "phase5-memory-recovery-" + [Guid]::NewGuid().ToString("N")
$purgeRequest = Invoke-Python @"
import json, ssl, urllib.request, urllib.parse
ctx = ssl.create_default_context()
url = r"$BaseUrl/api/v1/memory?project_id=" + urllib.parse.quote(r"$projectId") + "&confirm=true&reason=phase5_memory_recovery_drill&trace_id=phase5-memory-recovery"
req = urllib.request.Request(url, method="DELETE")
with urllib.request.urlopen(req, context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "purge request evidence" $purgeRequest '"evidence_ref": "memory_purge_completed"'

$purgeJob = Invoke-Python @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
payload = json.loads(r'''$($purgeRequest.Replace("'", "''"))''')
job_id = payload["job_id"]
with urllib.request.urlopen(r"$BaseUrl/api/v1/memory/purge/jobs/" + job_id, context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "purge job status" $purgeJob '"evidence_ref": "memory_purge_job_status_visible"'

$consolidationFeed = Invoke-Python @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/memory/consolidation/recent?limit=5", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "consolidation feed" $consolidationFeed '"events"'

$audit = Invoke-Python @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/audit/recent?limit=5", context=ctx, timeout=20) as r:
    print(r.status)
    print(json.dumps(json.load(r)))
"@
Assert-Contains "audit status" $audit "200"
Assert-Contains "audit body" $audit '"events"'

Write-Host "[phase5-memory-recovery-drill] verified"
