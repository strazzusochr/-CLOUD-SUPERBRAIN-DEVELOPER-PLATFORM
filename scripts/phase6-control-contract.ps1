# Shared by the P6 executor, evidence reader and offline integration tests.
# No IO, networking, gate writes, or caller-supplied production policy.
function ConvertFrom-Phase6Json([string]$Json, [int]$Depth = 30) {
  $options = @{ Depth = $Depth; ErrorAction = 'Stop' }
  if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $options.DateKind = 'String' }
  return ($Json | ConvertFrom-Json @options)
}

function Get-Phase6AuditedDeltaHash {
  # Exact S3 -> reviewed control path set, including this complete P6 fix.
  # This is NOT a wildcard approval for additional code or evidence changes.
  return '973e4271145d46e0dd93925dd6d9a65b2c3ab8554b01f33ae9af362d617b4b42'
}

function Get-Phase6AllowedControlPaths([string]$ReleaseId, [string]$HostedEvidencePath, [string]$DeploymentEvidencePath) {
  if ($ReleaseId -cnotmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-local-rc[1-9][0-9]*$') {
    throw 'Phase6 active release identity is invalid.'
  }
  return @(
    '.gitattributes', '.github/workflows/phase6-scale-runtime.yml', 'PROJECT_STATE.md',
    'apps/frontend/lib/endpoint-snapshot.json', 'apps/frontend/lib/platform.ts',
    'docs/project-progress.manifest.json', 'docs/runtime-state/phase6-scale-criterion.json',
    'docs/runtime-state/cloudflare-native-hosted-current.json', 'docs/runtime-state/phase6-scale-hosted-current.json',
    'docs/runtime-state/capability-gates.json', 'docs/runtime-state/external-gate-summary.json',
    'docs/runtime-state/phase5-credit-itemization.json', 'docs/runtime-state/project-progress-delta-ledger.json',
    'docs/runtime-state/source-qualification-control.json', 'docs/release-artifacts/current-release-candidate.json',
    "docs/release-artifacts/$ReleaseId-readiness.json", "docs/release-artifacts/$ReleaseId.md",
    $HostedEvidencePath.Replace('\', '/'), $DeploymentEvidencePath.Replace('\', '/'),
    ($DeploymentEvidencePath.Replace('\', '/') + '.sha256'),
    'scripts/score_layer5_registry_release_credit.py', 'scripts/tests/test_new_progress_credit_scorers.py',
    'scripts/tests/test_verify_phase5_credit_itemization.py', 'scripts/tests/test_verify_project_progress_manifest.py',
    'scripts/verify_phase5_credit_itemization.py',
    'scripts/phase6-control-contract.ps1', 'scripts/verify-phase6-contract-chain-static.ps1',
    'scripts/verify-phase6-scale-runtime.ps1', 'scripts/verify-phase6-scale-runtime-static.ps1',
    'scripts/verify-phase6-scale-evidence.ps1', 'scripts/verify-phase6-scale-evidence-static.ps1',
    'scripts/collect-phase6-scale-execution-readback.ps1',
    'scripts/write-phase6-scale-deployment-preflight.ps1', 'scripts/write-phase6-scale-deployment-preflight-static.ps1'
  )
}

function Assert-Phase6ControlDelta {
  param(
    [string[]]$Paths, [string[]]$SafePaths, [string]$ReleaseId,
    [string]$HostedEvidencePath, [string]$DeploymentEvidencePath,
    [bool]$RequireAuditedFingerprint = $true
  )
  [string[]]$ordered = @($Paths)
  [string[]]$safe = @($SafePaths)
  if ($ordered.Count -eq 0) { throw 'Phase6 source/control delta is empty.' }
  foreach ($path in @($ordered) + @($safe)) {
    if ($path -cnotmatch '^[A-Za-z0-9_./-]+$' -or $path.StartsWith('/') -or
        $path -match '(^|/)\.\.?(/|$)|//') { throw 'Phase6 source/control delta contains a noncanonical path.' }
  }
  [Array]::Sort($ordered, [StringComparer]::Ordinal)
  [Array]::Sort($safe, [StringComparer]::Ordinal)
  if (@($ordered | Select-Object -Unique).Count -ne $ordered.Count -or
      $ordered.Count -ne $safe.Count -or ($ordered -join "`n") -cne ($safe -join "`n")) {
    throw 'Phase6 source/control delta contains a duplicate, delete, rename, or type change.'
  }
  $allowed = @(Get-Phase6AllowedControlPaths $ReleaseId $HostedEvidencePath $DeploymentEvidencePath)
  $prefix = "docs/release-artifacts/$ReleaseId-evidence/"
  $unexpected = @($ordered | Where-Object { $allowed -cnotcontains $_ -and -not $_.StartsWith($prefix, [StringComparison]::Ordinal) })
  if ($unexpected.Count -ne 0) { throw "Phase6 source/control delta contains non-control paths: $($unexpected -join ',')" }
  if ($RequireAuditedFingerprint) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = (($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($ordered -join "`n"))) | ForEach-Object { $_.ToString('x2') }) -join '') }
    finally { $sha.Dispose() }
    if ($hash -cne (Get-Phase6AuditedDeltaHash)) { throw 'Phase6 source/control delta differs from the audited path-set fingerprint.' }
  }
  return $ordered
}
