param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$ExpectedSha = "ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5",
  [long]$WorkflowRunId = 25392582005,
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Get-Json($command) {
  $raw = Invoke-Expression $command
  return ($raw | Out-String)
}

function Invoke-DockerManifestInspect($ref, [switch]$Verbose) {
  $attempts = 3
  $lastOutput = ""
  for ($attempt = 1; $attempt -le $attempts; $attempt++) {
    $global:LASTEXITCODE = 0
    if ($Verbose) {
      $lastOutput = docker manifest inspect --verbose $ref 2>&1 | Out-String
    } else {
      $lastOutput = docker manifest inspect $ref 2>&1 | Out-String
    }
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($lastOutput)) {
      return $lastOutput
    }
    if ($attempt -lt $attempts) {
      Write-Warning "GHCR manifest inspect retry $attempt/$attempts for $ref"
      Start-Sleep -Seconds (5 * $attempt)
    }
  }
  throw "Verification failed: GHCR manifest inspect failed for $ref after $attempts attempts. Last output: $lastOutput"
}

Write-Host "[phase5-rollback] artifact"
$artifactPath = ".phase1-artifacts\phase5-rollback-drill-prod-candidate-20260505-rc1.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing rollback drill artifact: $artifactPath"
}
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  "Status: ``verified``",
  "Candidate: ``$ReleaseId``",
  "Workflow run id: ``$WorkflowRunId``",
  "Source commit sha: ``$ExpectedSha``",
  "Current hosted selector: ``IMAGE_TAG=staging``",
  "Rollback selector: ``IMAGE_TAG=$ExpectedSha``",
  "This is a documented rollback drill, not an executed rollback."
)) {
  Assert-Contains "rollback drill artifact" $artifact $required
}

Write-Host "[phase5-rollback] github workflow run"
$run = @"
import json, urllib.request
url = 'https://api.github.com/repos/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/$WorkflowRunId'
req = urllib.request.Request(url, headers={'User-Agent': 'Codex'})
with urllib.request.urlopen(req, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@ | py -3 -
Assert-Contains "workflow run" $run '"conclusion": "success"'
Assert-Contains "workflow run" $run '"status": "completed"'
Assert-Contains "workflow run" $run ('"head_sha": "' + $ExpectedSha + '"')

Write-Host "[phase5-rollback] immutable ghcr tags"
$images = @("agent-api", "mcp-gateway", "frontend", "llm-gateway", "agent-worker", "memory-worker")
foreach ($name in $images) {
  $ref = "ghcr.io/strazzusochr/cloud-superbrain-developer-platform/${name}:$ExpectedSha"
  Invoke-DockerManifestInspect $ref | Out-Null
}

Write-Host "[phase5-rollback] hosted endpoints"
foreach ($url in @(
  "$BaseUrl/",
  "$BaseUrl/api/v1/health",
  "$BaseUrl/mcp/api/v1/health",
  "$BaseUrl/llm/api/v1/health"
)) {
  $status = @"
import ssl, sys, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(sys.argv[1], context=ctx, timeout=20) as response:
    print(response.status)
"@ | py -3 - $url
  Assert-Contains "hosted status $url" $status "200"
}

Write-Host "[phase5-rollback] rollback drill verified"
