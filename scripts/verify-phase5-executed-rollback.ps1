param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$ExpectedSha = "ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5",
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

$artifactPath = ".phase1-artifacts\phase5-executed-rollback-prod-candidate-20260505-rc1.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing executed rollback artifact: $artifactPath"
}
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  "Status: verified",
  "Candidate release id: $ReleaseId",
  "Previous good release id: ${ReleaseId}@${ExpectedSha}",
  "Executed rollback selector: IMAGE_TAG=$ExpectedSha",
  "Restored candidate selector: IMAGE_TAG=staging",
  "Executed rollback completed: yes",
  "Candidate selector restored to staging: yes",
  "Hosted progress after restore remained manifest-backed: overall=$expectedOverall, phase5=$expectedPhase5",
  "Hosted integrity after restore remained verified: yes",
  "This is an executed rollback proof on hosted staging."
)) {
  Assert-Contains "executed rollback artifact" $artifact $required
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate executed rollback linked" $candidate 'Historical executed rollback reference: `.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md`'

$selector = (& ssh -i $KeyPath -o StrictHostKeyChecking=no "${RemoteUser}@${RemoteHost}" "cd $RemoteAppDir && grep '^IMAGE_TAG=' .env") | Out-String
if ($LASTEXITCODE -ne 0) {
  throw "Verification failed: unable to read remote IMAGE_TAG selector."
}
Assert-Contains "remote restored selector" $selector "IMAGE_TAG=staging"

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "progress phase5" $progress """percent"": $expectedPhase5"

$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "integrity" $integrity '"status": "verified"'
Assert-Contains "integrity phase5" $integrity """phase_5"": $expectedPhase5"

Write-Host "[phase5-executed-rollback] verified"
