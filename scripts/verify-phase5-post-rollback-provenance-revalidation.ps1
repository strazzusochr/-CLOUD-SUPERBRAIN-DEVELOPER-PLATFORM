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

function Invoke-PythonJson($code) {
@"
$code
"@ | py -3 -
}

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing post-rollback provenance revalidation artifact: $artifactPath"
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  'revalidation_scope: `post_rollback_workflow_ghcr_and_runtime_provenance`',
  '## Provenance Scope',
  '## Results',
  "Current progress carried in revalidation: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'Workflow source remained authoritative: `yes`',
  'Immutable tag set remained usable: `yes`',
  'Staging parity block remained visible after rollback restore: `yes`',
  'Production claim: `forbidden`'
)) {
  Assert-Contains "post-rollback provenance artifact" $artifact $required
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate provenance linked" $candidate 'post_rollback_provenance_revalidation_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md`'
Assert-Contains "candidate staging parity linked" $candidate 'staging_tag_parity_blocked_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`'

$workflow = Invoke-PythonJson @"
import json, urllib.request
url = 'https://api.github.com/repos/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005'
req = urllib.request.Request(url, headers={'User-Agent': 'Codex'})
with urllib.request.urlopen(req, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "workflow id" $workflow '"id": 25392582005'
Assert-Contains "workflow status" $workflow '"status": "completed"'
Assert-Contains "workflow conclusion" $workflow '"conclusion": "success"'
Assert-Contains "workflow head sha" $workflow '"head_sha": "ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5"'

$images = @("agent-api", "mcp-gateway", "frontend", "llm-gateway", "agent-worker", "memory-worker")
foreach ($name in $images) {
  $ref = "ghcr.io/strazzusochr/cloud-superbrain-developer-platform/${name}:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5"
  $manifestInspect = docker manifest inspect $ref
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: GHCR manifest inspect failed for $ref"
  }
  Assert-Contains "ghcr manifest $name" $manifestInspect '"architecture": "amd64"'
  Assert-Contains "ghcr manifest $name" $manifestInspect '"architecture": "arm64"'
}

foreach ($url in @(
  "$BaseUrl/",
  "$BaseUrl/api/v1/health",
  "$BaseUrl/mcp/api/v1/health",
  "$BaseUrl/llm/api/v1/health"
)) {
  $status = Invoke-PythonJson @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(r.status)
"@
  Assert-Contains "hosted status $url" $status "200"
}

$progress = Invoke-PythonJson @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$BaseUrl/api/v1/project/progress", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@
Assert-Contains "progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "progress phase5" $progress """percent"": $expectedPhase5"

Write-Host "[phase5-post-rollback-provenance-revalidation] verified"
