param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) {
    throw "Verification failed: $label expected '$expected' but got '$actual'."
  }
}

function Assert-False($label, $value) {
  if ([bool]$value) {
    throw "Verification failed: $label expected false."
  }
}

function Assert-Sha($label, $value) {
  if ([string]::IsNullOrWhiteSpace($value) -or $value -notmatch '^[0-9a-f]{40}$') {
    throw "Verification failed: $label is not a lowercase 40-character SHA."
  }
}

function Invoke-Gate([string]$Id, [string]$ScriptPath, [hashtable]$Arguments) {
  if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Missing gate script for $Id`: $ScriptPath"
  }

  $global:LASTEXITCODE = 0
  & $ScriptPath @Arguments *>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: gate '$Id' exited with code $LASTEXITCODE."
  }

  return [pscustomobject]@{
    id = $Id
    script = $ScriptPath
    status = "passed"
  }
}

function Invoke-ProcessGate([string]$Id, [string]$CommandName, [string[]]$Arguments) {
  $command = Get-Command $CommandName -ErrorAction SilentlyContinue
  if (-not $command) {
    throw "Missing command for $Id`: $CommandName"
  }

  $global:LASTEXITCODE = 0
  & $command.Source @Arguments *>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Verification failed: gate '$Id' exited with code $LASTEXITCODE."
  }

  return [pscustomobject]@{
    id = $Id
    script = $CommandName
    status = "passed"
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

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)

if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
  $config = Get-Content "docs\release-artifacts\current-release-candidate.json" -Raw | ConvertFrom-Json
  $ReleaseId = [string]$config.active_release_id
  Assert-False "production rollout claimed" $config.production_rollout_claimed
}

if ($ReleaseId -ne "prod-candidate-2026-05-05-rc1") {
  $candidatePath = "docs\release-artifacts\$ReleaseId.md"
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw "Missing active release candidate artifact: $candidatePath"
  }
  $candidate = Get-Content -LiteralPath $candidatePath -Raw
  foreach ($required in @(
    "release_id: ``$ReleaseId``",
    "environment: ``production-candidate``",
    "This artifact does not claim a production rollout.",
    "active_full_suite_rebaseline_proof: ``docs/release-artifacts/$ReleaseId-active-full-suite-rebaseline-20260515.md``"
  )) {
    Assert-Contains "active candidate artifact" $candidate $required
  }

  if ($candidate -notmatch '(?m)^source_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Verification failed: active candidate artifact missing source_commit_sha."
  }
  $sourceSha = $Matches[1]
  Assert-Sha "source commit sha" $sourceSha
  if ($candidate -notmatch '(?m)^immutable_image_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Verification failed: active candidate artifact missing immutable_image_commit_sha."
  }
  $immutableSha = $Matches[1]
  Assert-Sha "immutable image commit sha" $immutableSha

  $proofPath = "docs\release-artifacts\$ReleaseId-active-full-suite-rebaseline-20260515.md"
  if (-not (Test-Path -LiteralPath $proofPath)) {
    throw "Missing active full-suite rebaseline proof: $proofPath"
  }
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "production_rollout_claimed: ``false``",
    "active_gate_count: ``10``",
    "phase5_suite_plan_status: ``passed``",
    "changed_horizontal: ``Phase 2 88->89; Phase 5 84->88``",
    "changed_vertical: ``Agent Pool 75->76; LLM Gateway 65->67; MCP Gateway 67->68; Memory 73->74``",
    "This proof does not claim a production rollout.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "active full-suite proof" $proof $required
  }

  $gates = [System.Collections.Generic.List[object]]::new()
  $gates.Add((Invoke-ProcessGate "project-progress-manifest" "py" @("-3", "scripts\verify_project_progress_manifest.py"))) | Out-Null
  $gates.Add((Invoke-Gate "phase5-suite-active-candidate-plan" "scripts\verify-phase5-suite-active-candidate-plan.ps1" @{})) | Out-Null
  $gates.Add((Invoke-Gate "current-release-candidate" "scripts\verify-current-release-candidate.ps1" @{
    ReleaseId = $ReleaseId
    BaseUrl = $BaseUrl
  })) | Out-Null
  $gates.Add((Invoke-Gate "active-release-candidate-bundle" "scripts\verify-active-release-candidate-bundle.ps1" @{
    ReleaseId = $ReleaseId
    BaseUrl = $BaseUrl
    ReportOnly = $true
    JsonOnly = $true
  })) | Out-Null
  $gates.Add((Invoke-Gate "hosted-staging-smoke" "scripts\verify-hosted-staging-smoke.ps1" @{
    BaseUrl = $BaseUrl
  })) | Out-Null
  $gates.Add((Invoke-Gate "active-runtime-evidence-bundle" "scripts\verify-phase5-active-runtime-evidence-bundle.ps1" @{
    ReleaseId = $ReleaseId
    BaseUrl = $BaseUrl
  })) | Out-Null
  $gates.Add((Invoke-Gate "active-security-evidence-bundle" "scripts\verify-phase5-active-security-evidence-bundle.ps1" @{
    ReleaseId = $ReleaseId
    BaseUrl = $BaseUrl
  })) | Out-Null
  $gates.Add((Invoke-Gate "active-verifier-sweep-bundle" "scripts\verify-phase5-active-verifier-sweep-bundle.ps1" @{
    ReleaseId = $ReleaseId
    BaseUrl = $BaseUrl
  })) | Out-Null
  $gates.Add((Invoke-Gate "vercel-github-deployment-status" "scripts\verify-phase5-vercel-github-deployment-status.ps1" @{
    ReleaseId = $ReleaseId
    BaseUrl = $BaseUrl
  })) | Out-Null
  $gates.Add((Invoke-Gate "evidence-artifact-safety" "scripts\verify-evidence-artifact-safety.ps1" @{})) | Out-Null
  Assert-Equal "active gate count" $gates.Count 10

  $progress = Get-Json "$BaseUrl/api/v1/project/progress" | ConvertFrom-Json
  Assert-Equal "hosted progress overall" ([int]$progress.overall_percent) $expectedOverall
  $progressPhase5 = @($progress.horizontal.items | Where-Object { $_.id -eq "phase_5" }) | Select-Object -First 1
  Assert-Equal "hosted progress phase5" ([int]$progressPhase5.percent) $expectedPhase5
  Assert-Contains "phase5 active full-suite status" $progressPhase5.status "active_full_suite_rebaseline_verified"

  $integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity" | ConvertFrom-Json
  Assert-Equal "hosted integrity status" $integrity.status "verified"
  Assert-Equal "hosted integrity manifest overall" ([int]$integrity.manifest_overall_percent) $expectedOverall
  Assert-Equal "hosted integrity computed overall" ([int]$integrity.computed_overall_percent) $expectedOverall

  Write-Host "[phase5-full-verifier-sweep] active rebaseline verified"
  Write-Host "[phase5-full-verifier-sweep] release_id=$ReleaseId"
  Write-Host "[phase5-full-verifier-sweep] active_gate_count=$($gates.Count)"
  return
}

$artifactPath = ".phase1-artifacts\phase5-full-verifier-sweep-20260507.md"
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "Candidate: ``$ReleaseId``",
  "Current progress reference: ``overall=$expectedOverall``, ``phase5=$expectedPhase5``",
  'full `verify-phase5*.ps1` sweep: `passed`',
  '`verify-phase1.ps1`: `passed`',
  '`gitleaks`: `no leaks found`'
)) {
  Assert-Contains "full verifier sweep artifact" $artifact $required
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate full sweep field" $candidate 'full_verifier_sweep_proof: `.phase1-artifacts/phase5-full-verifier-sweep-20260507.md`'
Assert-Contains "candidate full sweep evidence bullet" $candidate 'Full verifier sweep proof: `.phase1-artifacts/phase5-full-verifier-sweep-20260507.md`'
Assert-Contains "candidate staging parity blocker field" $candidate 'staging_tag_parity_blocked_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`'
Assert-Contains "candidate staging parity blocker evidence bullet" $candidate 'Staging tag parity blocked proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`'
Assert-Contains "candidate repo parity blocker field" $candidate 'repo_worktree_parity_blocked_proof: `.phase1-artifacts/phase5-repo-worktree-parity-blocked-20260507.md`'
Assert-Contains "candidate repo parity blocker evidence bullet" $candidate 'Repo worktree parity blocked proof: `.phase1-artifacts/phase5-repo-worktree-parity-blocked-20260507.md`'

$phase5Scripts = Get-ChildItem "scripts\verify-phase5*.ps1"
if ($phase5Scripts.Count -lt 10) {
  throw "Verification failed: expected a full phase5 verifier set."
}

$progress = Get-Json "$BaseUrl/api/v1/project/progress"
Assert-Contains "hosted progress overall" $progress """overall_percent"": $expectedOverall"
Assert-Contains "hosted progress phase5" $progress """percent"": $expectedPhase5"
$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity"
Assert-Contains "integrity" $integrity '"status": "verified"'

Write-Host "[phase5-full-verifier-sweep] verified"
