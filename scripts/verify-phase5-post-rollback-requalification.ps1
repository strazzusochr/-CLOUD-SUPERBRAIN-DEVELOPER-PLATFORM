param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$KeyPath = "C:\Users\immer\.ssh\oracle_key",
  [string]$RemoteUser = "root",
  [string]$RemoteHost = "188.34.191.140",
  [string]$RemoteAppDir = "/app",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

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

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-post-rollback-requalification.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing post-rollback requalification artifact: $artifactPath"
}
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  "Status: ``verified``",
  "Candidate: ``$ReleaseId``",
  "Executed rollback proof: ``.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md``",
  "Hosted selector after requalification: ``IMAGE_TAG=staging``",
  "Hosted root status: ``200``",
  "Hosted Agent API status: ``200``",
  "Hosted MCP status: ``200``",
  "Hosted LLM status: ``200``",
  "Hosted progress remained manifest-backed: ``yes``",
  "Hosted integrity remained verified: ``yes``",
  "Production rollout claim introduced: ``no``"
)) {
  Assert-Contains "post-rollback requalification artifact" $artifact $required
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate requalification linked" $candidate "Historical post-rollback requalification reference: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification.md``"

$selector = (& ssh -i $KeyPath -o StrictHostKeyChecking=no "${RemoteUser}@${RemoteHost}" "cd $RemoteAppDir && grep '^IMAGE_TAG=' .env") | Out-String
if ($LASTEXITCODE -ne 0) {
  throw "Verification failed: unable to read remote IMAGE_TAG selector."
}
Assert-Contains "remote selector" $selector "IMAGE_TAG=staging"

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

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

$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
Assert-Contains "completion contract" $completion '"can_set_all_to_100": false'

$externalGates = Get-Json "$BaseUrl/api/v1/external-gates"
Assert-Contains "external gates" $externalGates '"status": "verified"'

Write-Host "[phase5-post-rollback-requalification] verified"
