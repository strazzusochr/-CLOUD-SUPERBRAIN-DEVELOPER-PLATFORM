param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) { throw "Verification failed: $label did not contain '$expected'." }
}

function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) { throw "Verification failed: $label expected '$expected' but got '$actual'." }
}

function Get-Json($uri) {
  $python = @"
import urllib.request
with urllib.request.urlopen(r'''$uri''', timeout=30) as response:
    print(response.read().decode("utf-8"))
"@
  $content = $python | py -3 -
  return ($content | ConvertFrom-Json)
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
  throw "Verification failed: GHCR immutable manifest inspect failed for $ref after $attempts attempts. Last output: $lastOutput"
}

$artifactPath = "docs\release-artifacts\$ReleaseId-provenance-review.md"
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  "overall_percent: ``$expectedOverall``",
  "phase_5_percent: ``$expectedPhase5``",
  'Provenance classification: `candidate_provenance_review`',
  "Current progress carried in review: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'Immutable candidate SHA remains bound to the candidate artifact: `yes`',
  'Staging parity remains explicitly blocked: `yes`'
)) { Assert-Contains "provenance review artifact" $artifact $required }

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate provenance proof linked" $candidate 'provenance_review_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provenance-review.md`'
Assert-Contains "candidate evidence provenance proof linked" $candidate 'Provenance review proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provenance-review.md`'
Assert-Contains "candidate staging parity proof linked" $candidate 'staging_tag_parity_blocked_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`'
Assert-Contains "candidate staging parity evidence linked" $candidate 'Staging tag parity blocked proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`'
Assert-Contains "candidate workflow url" $candidate 'workflow_run_url: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25392582005`'
Assert-Contains "candidate source sha" $candidate 'source_commit_sha: `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`'

$images = @("agent-api", "mcp-gateway", "frontend", "llm-gateway", "agent-worker", "memory-worker")
foreach ($name in $images) {
  $ref = "ghcr.io/strazzusochr/cloud-superbrain-developer-platform/${name}:ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5"
  Invoke-DockerManifestInspect $ref | Out-Null
}

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion"
$gates = Get-Json "$BaseUrl/api/v1/external-gates"

$phase4 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$phase5 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1

Assert-Equal "hosted overall percent" $progress.overall_percent $expectedOverall
Assert-Equal "hosted phase4 percent" $phase4.percent 100
Assert-Equal "hosted phase5 percent" $phase5.percent $expectedPhase5
Assert-Equal "hosted integrity status" $integrity.status "verified"
Assert-Equal "external gates status" $gates.status "verified"
if ($completion.can_set_all_to_100 -ne $false) { throw "Verification failed: completion gate must remain fail-closed." }

Write-Host "[phase5-provenance-review] verified"
