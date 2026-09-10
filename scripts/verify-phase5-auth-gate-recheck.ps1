param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" }),
  [switch]$AllowLocalhost,
  [switch]$StaticOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Phase 5 auth gate recheck failed: $Label" }
  Write-Host "[phase5-auth-gate-recheck] $Label"
}

function Assert-Contains([string]$Label, [string]$Value, [string]$Expected) {
  Assert-True "$Label contains '$Expected'" $Value.Contains($Expected)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $artifactPath = "docs\release-artifacts\$ReleaseId-auth-gate-recheck.md"
  Assert-True "historical artifact exists" (Test-Path -LiteralPath $artifactPath)
  $artifact = Get-Content -LiteralPath $artifactPath -Raw
  foreach ($required in @(
    'Status: `security-invalidated`',
    'disposition: `superseded`',
    'superseded_by: `phase3-auth-credential-issuance-fail-closed-v1`',
    "release_id: ``$ReleaseId``",
    'overall_percent: `70`',
    'phase_4_percent: `100`',
    'phase_5_percent: `67`',
    '`overall=70`',
    '`phase_4=100`',
    '`phase_5=63`',
    'This is not current Phase-3 or Phase-5 evidence.',
    'This does not claim the replacement verifier or full suite is green.'
  )) {
    Assert-Contains "historical artifact" $artifact $required
  }
  Assert-Contains "historical insecure callback preserved as invalid provenance" $artifact 'issued dry-run auth tokens on the hosted candidate'
  Assert-Contains "historical arbitrary callback explicitly invalidated" $artifact 'arbitrary callback input'

  $candidatePath = "docs\release-artifacts\$ReleaseId.md"
  Assert-True "historical candidate exists" (Test-Path -LiteralPath $candidatePath)
  $candidate = Get-Content -LiteralPath $candidatePath -Raw
  Assert-Contains "candidate superseded auth reference" $candidate 'auth_gate_recheck_superseded_reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-auth-gate-recheck.md`'
  Assert-Contains "candidate evidence superseded auth reference" $candidate 'Superseded auth gate historical reference: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-auth-gate-recheck.md`'

  $manifest = Get-Content -LiteralPath "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
  $phase3 = $manifest.horizontal.items | Where-Object { $_.id -eq "phase_3" } | Select-Object -First 1
  Assert-True "Phase 3 remains 44" ([int]$phase3.percent -eq 44)
  foreach ($marker in @(
    "auth_credential_issuance_fail_closed",
    "oauth_state_one_time_enforced",
    "refresh_token_registry_enforced"
  )) {
    Assert-True "current manifest marker $marker" ([string]$phase3.status).Contains($marker)
  }
  foreach ($supersededMarker in @(
    "local_auth_lifecycle_browser_proof",
    "hosted_auth_lifecycle_staging_proof"
  )) {
    Assert-True "superseded manifest marker absent: $supersededMarker" (-not ([string]$phase3.status).Contains($supersededMarker))
  }

  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-phase3-auth-fail-closed.ps1 -StaticOnly
  Assert-True "current fail-closed static proof" ($LASTEXITCODE -eq 0)

  if ($StaticOnly -or [string]::IsNullOrWhiteSpace($BaseUrl)) {
    Write-Host "[phase5-auth-gate-recheck] status=verified_static_supersession hosted_current_auth=blocked_missing_stateful_staging"
    exit 0
  }

  $base = $BaseUrl.TrimEnd("/")
  $isLocal = $base -match '^https?://(localhost|127\.0\.0\.1|\[::1\])(?::\d+)?$'
  if ($isLocal -and -not $AllowLocalhost) {
    throw "Local auth proof requires -AllowLocalhost and remains DEV-ONLY."
  }
  if (-not $isLocal -and $base -notmatch '^https://') {
    throw "Hosted auth contract verification requires a non-local HTTPS URL."
  }

  $arguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\verify-phase3-auth-fail-closed.ps1",
    "-BaseUrl", $base
  )
  if ($isLocal) { $arguments += "-AllowLocalhost" }
  powershell @arguments
  Assert-True "current fail-closed boundary proof" ($LASTEXITCODE -eq 0)
  $classification = if ($isLocal) { "verified_dev_only" } else { "verified_current_https_contract_readonly" }
  Write-Host "[phase5-auth-gate-recheck] status=$classification historical_rc1=superseded hosted_stateful_auth_verified=false progress_credit=false"
} finally {
  Pop-Location
}
