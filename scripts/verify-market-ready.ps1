<#
  verify-market-ready.ps1 - AGGREGATE FINISH-LINE (eine Wahrheit fuer "100% marktreif").
  Druckt am Ende genau eine Zeile: "MARKET_READY: true" oder "MARKET_READY: false".
  true NUR wenn: alle Pflicht-Verifier exit 0 UND Manifest jede horizontale+vertikale Zelle == 100
  UND Gate-Audit status=verified & production_deploy_claim_allowed=true UND kein OPEN im PROOF_LEDGER.
  Kann NICHT gefaked werden: liest echte Verifier-Exitcodes und die echten Truth-Dateien.

  Beispiele:
    npm run verify:market-ready                 # voller Lauf (Docker-Stack up erwartet)
    powershell -File scripts\verify-market-ready.ps1 -StaticOnly           # validiert READY/OWNER_BLOCKED ohne Runtime
    powershell -File scripts\verify-market-ready.ps1 -IncludeExternalGates # + owner-gated Gate-Audit
    powershell -File scripts\verify-market-ready.ps1 -IncludeExternalGates -RequireReady
#>
param(
  [switch]$StaticOnly,            # ueberspringt Docker/Runtime-Verifier
  [switch]$IncludeExternalGates,  # faehrt zusaetzlich verify:external-gates (braucht Owner-Inputs)
  [switch]$RequireReady,          # exit 0 ausschliesslich fuer MARKET_READY:true
  [string]$OutDir = ".codex\runs\CURRENT\master-goal\market-ready"
)

$ErrorActionPreference = "Continue"   # Orchestrator darf nicht crashen; wir sammeln Fehler
$repoRoot   = Split-Path -Parent $PSScriptRoot
$artifactDir = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
$results = New-Object System.Collections.Generic.List[object]

function Add-Result(
  [string]$name,
  [bool]$ok,
  [string]$detail,
  [bool]$required = $true,
  [bool]$ownerGated = $false,
  [ValidateSet("integrity", "readiness")][string]$failureClass = "integrity"
) {
  $results.Add([pscustomobject]@{
    step = $name
    ok = $ok
    required = $required
    owner_gated = $ownerGated
    failure_class = $failureClass
    detail = $detail
  })
  $tag = if ($ok) { "PASS" } elseif (-not $required) { "SKIP" } else { "FAIL" }
  Write-Host ("[market-ready] {0,-34} {1}  {2}" -f $name, $tag, $detail)
}

function Invoke-Npm(
  [string]$name,
  [string]$script,
  [bool]$required = $true,
  [bool]$ownerGated = $false
) {
  Write-Host "[market-ready] running: npm run $script"
  & npm run $script 2>&1 | ForEach-Object { Write-Host "    $_" }
  $code = $LASTEXITCODE; if ($null -eq $code) { $code = 127 }
  Add-Result $name ($code -eq 0) "exit=$code" $required $ownerGated
}

function Resolve-RepoScopedFile([string]$RelativePath) {
  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
    return $null
  }
  try {
    $repoPrefix = [IO.Path]::GetFullPath($repoRoot).TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    $resolved = [IO.Path]::GetFullPath((Join-Path $repoRoot $RelativePath))
    if (-not $resolved.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
      return $null
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
      return $null
    }
    return $resolved
  } catch {
    return $null
  }
}

function Get-FileSha256([string]$Path) {
  $stream = [IO.File]::OpenRead($Path)
  try {
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
      return (($sha256.ComputeHash($stream) | ForEach-Object { $_.ToString("X2") }) -join "")
    } finally {
      $sha256.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
}

function Test-JsonInteger([object]$Value) {
  return ($Value -is [byte] -or $Value -is [sbyte] -or
    $Value -is [int16] -or $Value -is [uint16] -or
    $Value -is [int32] -or $Value -is [uint32] -or
    $Value -is [int64] -or $Value -is [uint64])
}

function Test-JsonBool([object]$Value, [bool]$Expected) {
  return ($Value -is [bool] -and $Value -eq $Expected)
}

function Test-IsBooleanPropertyName([string]$Name) {
  if ($Name -in @(
    "market_ready", "static_only", "paid_provider", "secret_output", "dev_only", "DEV_ONLY",
    "r2_enabled", "mocks_used", "route_interception_used", "direct_provider_calls",
    "live_provider_calls", "production_deploy",
    "production_release_claimed", "production_rollout_claimed", "cloud_mutation",
    "payment_required", "paid_fallback_allowed", "lexical_evidence_reused",
    "arbitrary_paths_allowed", "main_write", "force_push", "value_recorded"
  )) { return $true }
  return ($Name -match '(^is_|^has_|_verified$|_claim_allowed$|_required$|_enabled$|_claimed$|_performed$|_used$|_configured$|_complete$|_persisted$|_granted$|_approved$|_unchanged$|_ready$)')
}

function Find-InvalidBooleanFields([object]$Value, [string]$Path = "root") {
  $invalid = @()
  if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) { return $invalid }
  if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [pscustomobject]) {
    $index = 0
    foreach ($item in $Value) {
      $invalid += @(Find-InvalidBooleanFields $item "$Path[$index]")
      $index++
    }
    return $invalid
  }
  foreach ($property in $Value.PSObject.Properties) {
    $propertyPath = "$Path.$($property.Name)"
    if ((Test-IsBooleanPropertyName $property.Name) -and $property.Value -isnot [bool]) {
      $invalid += $propertyPath
    }
    $invalid += @(Find-InvalidBooleanFields $property.Value $propertyPath)
  }
  return $invalid
}

function Test-TrackedCleanRepoFile([string]$RelativePath) {
  $resolved = Resolve-RepoScopedFile $RelativePath
  if (-not $resolved) { return $false }
  $normalized = $RelativePath.Replace('\', '/')
  & git.exe -C $repoRoot ls-files --error-unmatch -- $normalized 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { return $false }
  & git.exe -C $repoRoot diff --quiet HEAD -- $normalized
  return ($LASTEXITCODE -eq 0)
}

function Get-ReadyGateEvidenceValidation(
  [object]$Gate,
  [string]$GateId,
  [string]$ExpectedCandidateSha
) {
  $failures = New-Object System.Collections.Generic.List[string]
  if ($null -eq $Gate) {
    $failures.Add("missing_gate")
    return [pscustomobject]@{ ok = $false; detail = ($failures -join ","); evidence_path = "" }
  }
  if (-not (Test-JsonBool $Gate.owner_granted $true)) { $failures.Add("owner_granted") }
  if (-not (Test-JsonBool $Gate.live_verified $true)) { $failures.Add("live_verified") }
  if (-not (Test-JsonBool $Gate.paid_provider $false)) { $failures.Add("paid_provider") }
  if ([string]::IsNullOrWhiteSpace([string]$Gate.owner_grant_ref)) { $failures.Add("owner_grant_ref") }
  if ([string]::IsNullOrWhiteSpace([string]$Gate.provider)) { $failures.Add("provider") }
  if ([string]::IsNullOrWhiteSpace([string]$Gate.verifier)) { $failures.Add("verifier") }

  $verifiedAt = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse([string]$Gate.verified_at_utc, [ref]$verifiedAt)) {
    $failures.Add("verified_at_utc")
  }

  $relativeEvidence = [string]$Gate.evidence_artifact
  $evidencePath = Resolve-RepoScopedFile $relativeEvidence
  if (-not $evidencePath) {
    $failures.Add("evidence_artifact")
    return [pscustomobject]@{ ok = $false; detail = ($failures -join ","); evidence_path = $relativeEvidence }
  }
  if (-not (Test-TrackedCleanRepoFile $relativeEvidence)) { $failures.Add("evidence_not_tracked_clean") }
  $actualEvidenceSha = Get-FileSha256 $evidencePath
  if ([string]$Gate.evidence_sha256 -notmatch '^[A-Fa-f0-9]{64}$' -or
      -not $actualEvidenceSha.Equals([string]$Gate.evidence_sha256, [StringComparison]::OrdinalIgnoreCase)) {
    $failures.Add("evidence_sha256")
  }

  try {
    $evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
  } catch {
    $failures.Add("evidence_json")
    return [pscustomobject]@{ ok = $false; detail = ($failures -join ","); evidence_path = $relativeEvidence }
  }
  if ([string]::IsNullOrWhiteSpace([string]$evidence.contract_version)) { $failures.Add("contract_version") }
  $evidenceVerified = ([string]$evidence.status -eq "verified" -or [string]$evidence.result -eq "verified")
  if (-not $evidenceVerified) { $failures.Add("evidence_status") }
  if ($GateId -ne "phase6_scale_runtime") {
    $secretProperty = $evidence.PSObject.Properties["secret_output"]
    if ($null -eq $secretProperty -or -not (Test-JsonBool $secretProperty.Value $false)) { $failures.Add("secret_output") }
  }

  switch ($GateId) {
    "production_auth_identity" {
      if ([string]$evidence.contract_version -ne "production-auth-identity-proof-v1") { $failures.Add("auth_contract") }
      foreach ($field in @(
        "hosted_https", "real_browser", "oauth_start_verified", "callback_verified",
        "session_readback_verified", "refresh_verified", "logout_verified",
        "audit_readback_verified", "refresh_revoked_verified", "cookies_cleared_verified",
        "rollback_verified"
      )) {
        $property = $evidence.PSObject.Properties[$field]
        if ($null -eq $property -or -not (Test-JsonBool $property.Value $true)) { $failures.Add("auth_$field") }
      }
      if (-not (Test-JsonBool $evidence.dev_only $false)) { $failures.Add("auth_dev_only") }
      if ([string]$evidence.source_binding.source_commit_sha -ne $ExpectedCandidateSha) { $failures.Add("auth_candidate") }
      if ([string]::IsNullOrWhiteSpace([string]$evidence.source_binding.deployment_id)) { $failures.Add("auth_deployment_id") }
    }
    "docker_registry_publish" {
      if ([string]$evidence.contract_version -ne "ghcr-release-manifest-v1") { $failures.Add("ghcr_contract") }
      if ([string]$evidence.candidate_sha -ne $ExpectedCandidateSha) { $failures.Add("ghcr_candidate") }
      if ([string]$evidence.registry -ne "ghcr.io") { $failures.Add("ghcr_registry") }
      if ([int]$evidence.service_count -ne 6 -or [int]$evidence.unique_top_digest_count -ne 6 -or @($evidence.images).Count -ne 6) {
        $failures.Add("ghcr_six_services")
      }
      if (@($evidence.required_platforms).Count -ne 2 -or
          @($evidence.required_platforms) -notcontains "linux/amd64" -or
          @($evidence.required_platforms) -notcontains "linux/arm64") {
        $failures.Add("ghcr_platforms")
      }
      foreach ($field in @("inspection_read_only", "selected_tag_is_exact_candidate_sha", "publication_complete")) {
        $property = $evidence.PSObject.Properties[$field]
        if ($null -eq $property -or -not (Test-JsonBool $property.Value $true)) { $failures.Add("ghcr_$field") }
      }
      if (-not (Test-JsonBool $evidence.mutable_tag_fallback_used $false) -or
          -not (Test-JsonBool $evidence.registry_delete_performed $false)) {
        $failures.Add("ghcr_mutation_boundary")
      }
      if ([string]$evidence.workflow.candidate_sha -ne $ExpectedCandidateSha -or
          [string]::IsNullOrWhiteSpace([string]$evidence.workflow.run_url)) {
        $failures.Add("ghcr_workflow_binding")
      }
    }
    "phase6_scale_runtime" {
      if ([string]$evidence.contract_version -ne "phase6-scale-evidence-v2") { $failures.Add("phase6_contract") }
      if ([string]$evidence.source_binding.repository_head_sha -ne $ExpectedCandidateSha) { $failures.Add("phase6_candidate") }
      if (-not (Test-JsonBool $evidence.source_binding.owner_granted $true) -or
          [string]$evidence.source_binding.owner_grant_ref -ne [string]$Gate.owner_grant_ref) {
        $failures.Add("phase6_owner_binding")
      }
      if (-not (Test-JsonBool $evidence.source_binding.health_json_source_binding_verified $true) -or
          -not (Test-JsonBool $evidence.request_budget.exact_plan_executed $true) -or
          -not (Test-JsonBool $evidence.request_budget.cap_respected $true) -or
          -not (Test-JsonBool $evidence.cleanup.complete $true) -or
          -not (Test-JsonBool $evidence.aggregate.criterion_met $true) -or
          @($evidence.aggregate.failures).Count -ne 0) {
        $failures.Add("phase6_readback_cleanup")
      }
      if (-not (Test-JsonBool $evidence.auth.value_recorded $false) -or
          -not (Test-JsonBool $evidence.gate_promotion_performed $false) -or
          [int]$evidence.percentage_credit_awarded -ne 0) {
        $failures.Add("phase6_non_claim")
      }
    }
    default { $failures.Add("unsupported_gate") }
  }
  return [pscustomobject]@{
    ok = ($failures.Count -eq 0)
    detail = if ($failures.Count -eq 0) { "tracked_clean_source_bound_evidence" } else { $failures -join "," }
    evidence_path = $relativeEvidence
  }
}

Write-Host "=== MARKET-READY AGGREGATE GATE ==="

# --- 1) Statische Wahrheit (immer) ---
Write-Host "[market-ready] running: manifest integrity"
& py -3 (Join-Path $repoRoot "scripts\verify_project_progress_manifest.py") 2>&1 | ForEach-Object { Write-Host "    $_" }
$manifestOk = ($LASTEXITCODE -eq 0)
Add-Result "manifest-integrity" $manifestOk "verify_project_progress_manifest.py"

# Manifest-Zellen: exakt 7 horizontal + 7 vertikal, eindeutige IDs und 0..100.
$allHundred = $false
$overallHundred = $false
$manifestShapeOk = $false
$cellDetail = "unreadable"
$below = @()
$progressCells = @()
try {
  $m = Get-Content (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
  $horizontalCells = @($m.horizontal.items)
  $verticalCells = @($m.vertical.items)
  $progressCells = @($horizontalCells + $verticalCells)
  $uniqueCellIds = @($progressCells | ForEach-Object { [string]$_.id } | Sort-Object -Unique)
  $invalidPercentCells = @($progressCells | Where-Object {
    -not (Test-JsonInteger $_.percent) -or [long]$_.percent -lt 0 -or [long]$_.percent -gt 100
  })
  $manifestShapeOk = (
    $horizontalCells.Count -eq 7 -and
    $verticalCells.Count -eq 7 -and
    $progressCells.Count -eq 14 -and
    $uniqueCellIds.Count -eq 14 -and
    $invalidPercentCells.Count -eq 0 -and
    (Test-JsonInteger $m.overall_percent) -and
    [long]$m.overall_percent -ge 0 -and [long]$m.overall_percent -le 100
  )
  $below = @($progressCells | Where-Object { [long]$_.percent -lt 100 })
  $allHundred = ($manifestShapeOk -and @($progressCells | Where-Object { [long]$_.percent -ne 100 }).Count -eq 0)
  $overallHundred = ($manifestShapeOk -and [long]$m.overall_percent -eq 100)
  if ($allHundred -and $overallHundred) { $cellDetail = "all 14 cells and overall = 100" }
  else { $cellDetail = "below 100: " + (($below | ForEach-Object { "$($_.id)=$($_.percent)" }) -join ", ") }
} catch { $cellDetail = "parse error: $($_.Exception.Message)" }
Add-Result "manifest-shape" $manifestShapeOk "horizontal=7 vertical=7 cells=$($progressCells.Count) unique_ids=$($uniqueCellIds.Count) overall=$($m.overall_percent)"

# Immutable candidate identity is required in both states. OWNER_BLOCKED may point
# at an older, still-valid candidate; READY additionally requires the full runtime
# verifier chain to prove that no candidate-relevant source drift remains.
$activeReleaseId = $null
$candidateSha = $null
$candidateStateOk = $false
$candidateStateDetail = "unreadable candidate truth"
$phase5Credit = $null
$currentCandidate = $null
$candidateReadiness = $null
try {
  $phase5CreditPath = "docs/runtime-state/phase5-credit-itemization.json"
  $currentCandidatePath = "docs/release-artifacts/current-release-candidate.json"
  $phase5Credit = Get-Content (Join-Path $repoRoot $phase5CreditPath) -Raw | ConvertFrom-Json
  $currentCandidate = Get-Content (Join-Path $repoRoot $currentCandidatePath) -Raw | ConvertFrom-Json
  $activeReleaseId = [string]$phase5Credit.active_release_id
  $candidateSha = [string]$phase5Credit.active_source_commit_sha
  if ($activeReleaseId -notmatch '^[a-z0-9][a-z0-9._-]{0,127}$') { throw "invalid active release id" }
  if ($candidateSha -notmatch '^[0-9a-f]{40}$') { throw "invalid candidate sha" }
  $candidateReadinessRelativePath = "docs/release-artifacts/$activeReleaseId-readiness.json"
  $candidateReadinessPath = Resolve-RepoScopedFile $candidateReadinessRelativePath
  if (-not $candidateReadinessPath) { throw "missing candidate readiness artifact" }
  $candidateReadiness = Get-Content -LiteralPath $candidateReadinessPath -Raw | ConvertFrom-Json
  & git.exe -C $repoRoot cat-file -e "$candidateSha^{commit}" 2>$null
  $candidateCommitExists = ($LASTEXITCODE -eq 0)
  & git.exe -C $repoRoot merge-base --is-ancestor $candidateSha HEAD
  $candidateIsAncestor = ($LASTEXITCODE -eq 0)
  $candidateStateOk = (
    [string]$currentCandidate.active_release_id -eq $activeReleaseId -and
    [string]$candidateReadiness.release_id -eq $activeReleaseId -and
    [string]$candidateReadiness.source_commit_sha -eq $candidateSha -and
    $candidateCommitExists -and
    $candidateIsAncestor -and
    (Test-TrackedCleanRepoFile $phase5CreditPath) -and
    (Test-TrackedCleanRepoFile $currentCandidatePath) -and
    (Test-TrackedCleanRepoFile $candidateReadinessRelativePath)
  )
  $candidateStateDetail = "release=$activeReleaseId candidate=$candidateSha exists=$candidateCommitExists ancestor=$candidateIsAncestor tracked_clean=$candidateStateOk"
} catch {
  $activeReleaseId = $null
  $candidateSha = $null
  $candidateStateDetail = "candidate parse error: $($_.Exception.Message)"
}
Add-Result "candidate-binding" $candidateStateOk $candidateStateDetail

# The owner-input manifest makes the below-100 classification executable. It never raises
# percentages; it only proves that every current gap has an explicit Owner action and verifier.
$ownerInputPath = Join-Path $repoRoot "docs\runtime-state\owner-input-manifest.json"
$ownerMatrixOk = $false
$ownerMatrixDetail = "missing: docs/runtime-state/owner-input-manifest.json"
$autonomousOpenItemsOk = $false
$autonomousOpenItemsDetail = "owner-input manifest unreadable"
$ownerBlockedCellIds = @()
$resolvedCellIds = @()
$ownerUncoveredCellIds = @($below | ForEach-Object { [string]$_.id })
$hostedAcceptanceOk = $false
$ownerInput = $null
$capabilityState = $null
$externalState = $null
$externalAudit = $null
$o2ZeroCardOk = $false
$o4StateOk = $false
$o5ResolvedOk = $false
$o6ResolvedOk = $false
$truthMode = "invalid"
$readyGateChecks = @()
$readyTruthFilesClean = $false
$externalReadyOk = $false
try {
  if (Test-Path $ownerInputPath) {
    $ownerInput = Get-Content $ownerInputPath -Raw | ConvertFrom-Json
    $allCellIds = @($progressCells | ForEach-Object { [string]$_.id })
    $belowCellIds = @($below | ForEach-Object { [string]$_.id })
    $actions = @($ownerInput.actions)
    $ownerActions = @($actions | Where-Object { [string]$_.status -eq "owner_required" })
    $resolvedActions = @($actions | Where-Object { [string]$_.status -eq "resolved_verified" })
    $o4Action = @($actions | Where-Object { [string]$_.id -eq "O4" }) | Select-Object -First 1
    $o4IsResolved = ($null -ne $o4Action -and [string]$o4Action.status -eq "resolved_verified")
    $autonomousOpenItems = @($ownerInput.autonomous_open_items | ForEach-Object { [string]$_ })
    $autonomousOpenItemsOk = ($autonomousOpenItems.Count -eq 0)
    $autonomousOpenItemsDetail = if ($autonomousOpenItemsOk) {
      "none; source-bound Cloudflare O2Core plus hosted product and 22-page acceptance are verified"
    } else {
      "open: " + ($autonomousOpenItems -join ", ")
    }
    $invalidActions = @(
      $actions | Where-Object {
        [string]$_.id -notmatch '^O\d+$' -or
        [string]$_.status -notin @('owner_required', 'resolved_verified') -or
        [string]::IsNullOrWhiteSpace([string]$_.required_owner_action) -or
        @($_.affected_cells).Count -eq 0 -or
        @($_.verifier_after).Count -eq 0
      }
    )
    $ownerCoveredIds = @(
      $ownerActions |
        ForEach-Object { @($_.affected_cells) } |
        ForEach-Object { [string]$_ } |
        Sort-Object -Unique
    )
    $resolvedCoveredIds = @(
      $resolvedActions |
        ForEach-Object { @($_.affected_cells) } |
        ForEach-Object { [string]$_ } |
        Sort-Object -Unique
    )
    $coveredIds = @(
      $actions |
        ForEach-Object { @($_.affected_cells) } |
        ForEach-Object { [string]$_ } |
        Sort-Object -Unique
    )
    $unknownIds = @($coveredIds | Where-Object { $_ -notin $allCellIds })
    $ownerBlockedCellIds = @($belowCellIds | Where-Object { $_ -in $ownerCoveredIds })
    $resolvedCellIds = @($belowCellIds | Where-Object { $_ -in $resolvedCoveredIds })
    $ownerUncoveredCellIds = @($belowCellIds | Where-Object { $_ -notin $coveredIds })
    $expectedOwnerActionCells = @{
      O1 = @("phase_3")
      O2 = @("phase_5", "phase_6")
      O3 = @("layer_5", "phase_5")
    }
    $expectedResolvedActionCells = @{
      O5 = @("layer_6")
      O6 = @("layer_4")
    }
    if ($o4IsResolved) {
      $expectedResolvedActionCells.O4 = @("layer_3", "layer_5", "phase_6")
    } else {
      $expectedOwnerActionCells.O4 = @("layer_3", "layer_5", "phase_6")
    }
    $ownerActionIds = @($ownerActions | ForEach-Object { [string]$_.id } | Sort-Object)
    $resolvedActionIds = @($resolvedActions | ForEach-Object { [string]$_.id } | Sort-Object)
    $actionMapOk = (
      ($ownerActionIds -join ",") -eq (($expectedOwnerActionCells.Keys | Sort-Object) -join ",") -and
      ($resolvedActionIds -join ",") -eq (($expectedResolvedActionCells.Keys | Sort-Object) -join ",")
    )
    foreach ($action in $ownerActions) {
      $actionId = [string]$action.id
      $actualAffected = @($action.affected_cells | ForEach-Object { [string]$_ } | Sort-Object)
      $expectedAffected = @($expectedOwnerActionCells[$actionId] | Sort-Object)
      if (($actualAffected -join ",") -ne ($expectedAffected -join ",")) {
        $actionMapOk = $false
      }
    }
    foreach ($action in $resolvedActions) {
      $actionId = [string]$action.id
      $actualAffected = @($action.affected_cells | ForEach-Object { [string]$_ } | Sort-Object)
      $expectedAffected = @($expectedResolvedActionCells[$actionId] | Sort-Object)
      if (($actualAffected -join ",") -ne ($expectedAffected -join ",")) {
        $actionMapOk = $false
      }
    }

    $capabilityState = Get-Content (Join-Path $repoRoot "docs\runtime-state\capability-gates.json") -Raw | ConvertFrom-Json
    $externalState = Get-Content (Join-Path $repoRoot "docs\runtime-state\external-gate-summary.json") -Raw | ConvertFrom-Json
    $capabilityGateIds = @($capabilityState.gates.PSObject.Properties.Name)
    $externalGateIds = @($externalState.gate_ids)
    $knownGateIds = @($capabilityGateIds + $externalGateIds | Sort-Object -Unique)
    $referencedGateIds = @(
      $actions |
        ForEach-Object { @($_.gate_ids) } |
        ForEach-Object { [string]$_ } |
        Sort-Object -Unique
    )
    $unknownGateIds = @($referencedGateIds | Where-Object { $_ -notin $knownGateIds })
    $closedGateStateOk = $true
    $expectedClosedGateIds = @(
      "production_auth_identity",
      "docker_registry_publish",
      "phase6_scale_runtime"
    )
    if (-not $o4IsResolved) {
      $expectedClosedGateIds += @("live_mcp_writes", "live_agent_tool_writes")
    }
    foreach ($gateId in $expectedClosedGateIds) {
      $gateProperty = $capabilityState.gates.PSObject.Properties[$gateId]
      if ($null -eq $gateProperty -or [bool]$gateProperty.Value.live_verified) {
        $closedGateStateOk = $false
      }
    }
    $cloudflareTargetGate = $capabilityState.gates.cloudflare_native_zero_card_hosted_runtime
    $cloudflareTargetGateOk = (
      $null -ne $cloudflareTargetGate -and
      [bool]$cloudflareTargetGate.owner_granted -eq $true -and
      [bool]$cloudflareTargetGate.local_candidate_verified -eq $true -and
      [bool]$cloudflareTargetGate.zero_card_verified -eq $true -and
      [bool]$cloudflareTargetGate.hosted_source_parity_verified -eq $true -and
      [bool]$cloudflareTargetGate.hosted_stateful_roundtrip_verified -eq $true -and
      [bool]$cloudflareTargetGate.r2_enabled -eq $false -and
      [bool]$cloudflareTargetGate.live_verified -eq $true -and
      [bool]$cloudflareTargetGate.paid_provider -eq $false -and
      [string]$cloudflareTargetGate.evidence_sha256 -match '^[A-F0-9]{64}$'
    )
    $externalAuditPath = Join-Path $repoRoot ([string]$externalState.source_artifact)
    $externalAudit = if (Test-Path -LiteralPath $externalAuditPath -PathType Leaf) {
      Get-Content -LiteralPath $externalAuditPath -Raw | ConvertFrom-Json
    } else {
      $null
    }
    $cloudflareScopeReadinessPath = Join-Path $repoRoot ".codex\runs\CURRENT\p5\cloudflare-scope-readiness\report.json"
    $cloudflareScopeReadiness = if (Test-Path -LiteralPath $cloudflareScopeReadinessPath -PathType Leaf) {
      Get-Content -LiteralPath $cloudflareScopeReadinessPath -Raw | ConvertFrom-Json
    } else {
      $null
    }
    $cloudflareScopeReadinessOk = (
      $null -ne $cloudflareScopeReadiness -and
      [string]$cloudflareScopeReadiness.contract_version -eq "cloudflare-owner-scope-readiness-v1" -and
      [string]$cloudflareScopeReadiness.status -eq "scope_blocked" -and
      [string]$cloudflareScopeReadiness.execution_scope -eq "read_only" -and
      [bool]$cloudflareScopeReadiness.credentials.secret_output -eq $false -and
      @($cloudflareScopeReadiness.checks).Count -eq 6 -and
      @($cloudflareScopeReadiness.checks | Where-Object {
        [string]$_.method -ne "GET" -or
        [int]$_.http_status -notin @(401, 403) -or
        @($_.error_codes) -notcontains 10000
      }).Count -eq 0 -and
      [bool]$cloudflareScopeReadiness.assertions.only_get_requests_used -eq $true -and
      [bool]$cloudflareScopeReadiness.assertions.cloud_mutation -eq $false -and
      [bool]$cloudflareScopeReadiness.assertions.resource_inventory_verified -eq $false -and
      [bool]$cloudflareScopeReadiness.assertions.o2_prime_scope_ready -eq $false
    )
    $externalAuditOk = (
      $null -ne $externalAudit -and
      [string]$externalAudit.contract_version -eq "external-gate-audit-v2" -and
      [string]$externalAudit.status -eq [string]$externalState.status -and
      [string]$externalAudit.active_target_gate -eq "cloudflare_native_zero_card_hosted_runtime" -and
      [string]$externalAudit.generated_at_utc -eq [string]$externalState.generated_at_utc -and
      [bool]$externalAudit.production_deploy_claim_allowed -eq [bool]$externalState.production_deploy_claim_allowed -and
      [bool]$externalAudit.cloudflare_native_zero_card_hosted_runtime_claim_allowed -eq $true -and
      (@($externalAudit.missing_or_failed_gates) -join ",") -eq (@($externalState.missing_or_failed_gates) -join ",") -and
      @($externalAudit.source_evidence_refs) -contains ".codex/runs/CURRENT/p5/cloudflare-scope-readiness/report.json" -and
      [string]$externalAudit.legacy_provenance.status -eq "historical_only" -and
      [string]$externalAudit.legacy_provenance.retired_gate_id -eq "fly_live_budget_check" -and
      $cloudflareScopeReadinessOk
    )
    $externalGateStateOk = (
      [string]$externalState.contract_version -eq "external-gate-summary-v2" -and
      [string]$externalState.source_contract_version -eq "external-gate-audit-v2" -and
      [string]$externalState.status -eq "blocked" -and
      [bool]$externalState.production_deploy_claim_allowed -eq $false -and
      [string]$externalState.active_target_gate -eq "cloudflare_native_zero_card_hosted_runtime" -and
      @($externalState.missing_or_failed_gates).Count -eq 1 -and
      @($externalState.missing_or_failed_gates) -notcontains "github_branch_protection_current_verify" -and
      [bool]$externalState.branch_protection_claim_allowed -eq $true -and
      @($externalState.missing_or_failed_gates) -contains "ghcr_image_digest_verify" -and
      [bool]$externalState.cloudflare_native_zero_card_hosted_runtime_claim_allowed -eq $true -and
      [string]$externalState.legacy_provenance.status -eq "historical_only" -and
      [string]$externalState.legacy_provenance.retired_gate_id -eq "fly_live_budget_check" -and
      [string]$ownerInput.external_gate_truth.active_target_gate -eq "cloudflare_native_zero_card_hosted_runtime" -and
      @($ownerInput.external_gate_truth.missing_or_failed_gates).Count -eq 1 -and
      @($ownerInput.external_gate_truth.missing_or_failed_gates) -notcontains "github_branch_protection_current_verify" -and
      @($ownerInput.external_gate_truth.missing_or_failed_gates) -contains "ghcr_image_digest_verify" -and
      [string]$ownerInput.external_gate_truth.legacy_fly_path_status -eq "superseded_historical" -and
      [bool]$ownerInput.external_gate_truth.production_deploy_claim_allowed -eq $false -and
      $externalAuditOk -and
      $cloudflareTargetGateOk
    )
    $o2 = @($actions | Where-Object { [string]$_.id -eq "O2" }) | Select-Object -First 1
    $o2ZeroCardOk = (
      $null -ne $o2 -and
      [string]$o2.display_id -eq "O2'" -and
      [bool]$o2.payment_required -eq $false -and
      [bool]$o2.zero_card_required -eq $true -and
      [bool]$o2.paid_fallback_allowed -eq $false -and
      @($o2.gate_ids) -contains "cloudflare_native_zero_card_hosted_runtime" -and
      @($o2.gate_ids) -contains "phase6_scale_runtime" -and
      @($o2.gate_ids) -notcontains "fly_live_budget_check"
    )

    $hostedTruth = $ownerInput.hosted_acceptance_truth
    $hostedStateRelativePath = [string]$hostedTruth.state_artifact
    $productAcceptanceRelativePath = [string]$hostedTruth.product_acceptance_report
    $workspaceAcceptanceRelativePath = [string]$hostedTruth.workspace_22_page_report
    $hostedStatePath = Resolve-RepoScopedFile $hostedStateRelativePath
    $productAcceptancePath = Resolve-RepoScopedFile $productAcceptanceRelativePath
    $workspaceAcceptancePath = Resolve-RepoScopedFile $workspaceAcceptanceRelativePath
    $hostedState = if ($hostedStatePath) {
      Get-Content -LiteralPath $hostedStatePath -Raw | ConvertFrom-Json
    } else {
      $null
    }
    $productAcceptance = if ($productAcceptancePath) {
      Get-Content -LiteralPath $productAcceptancePath -Raw | ConvertFrom-Json
    } else {
      $null
    }
    $workspaceAcceptance = if ($workspaceAcceptancePath) {
      Get-Content -LiteralPath $workspaceAcceptancePath -Raw | ConvertFrom-Json
    } else {
      $null
    }
    $productAcceptanceSha256 = if ($productAcceptancePath) {
      Get-FileSha256 $productAcceptancePath
    } else {
      ""
    }
    $workspaceAcceptanceSha256 = if ($workspaceAcceptancePath) {
      Get-FileSha256 $workspaceAcceptancePath
    } else {
      ""
    }
    $hostedAcceptanceOk = (
      $null -ne $hostedTruth -and
      [string]$hostedTruth.status -eq "verified" -and
      [bool]$hostedTruth.product_acceptance_hosted_proof -eq $true -and
      [bool]$hostedTruth.workspace_22_page_hosted_proof -eq $true -and
      $null -ne $hostedState -and
      [string]$hostedState.contract_version -eq "cloudflare-native-hosted-current-v1" -and
      [string]$hostedState.status -eq "verified" -and
      [bool]$hostedState.dev_only -eq $false -and
      [bool]$hostedState.hosted_proof -eq $true -and
      [bool]$hostedState.product_acceptance_hosted_proof -eq $true -and
      [bool]$hostedState.workspace_22_page_hosted_proof -eq $true -and
      [bool]$hostedState.r2_enabled -eq $false -and
      [bool]$hostedState.paid_provider -eq $false -and
      [bool]$hostedState.production_deploy -eq $false -and
      [bool]$hostedState.production_release_claimed -eq $false -and
      [bool]$hostedState.secret_output -eq $false -and
      [string]$hostedState.product_acceptance_evidence_artifact -eq $productAcceptanceRelativePath -and
      [string]$hostedState.product_acceptance_evidence_sha256 -eq $productAcceptanceSha256 -and
      [string]$hostedState.workspace_22_page_evidence_artifact -eq $workspaceAcceptanceRelativePath -and
      [string]$hostedState.workspace_22_page_evidence_sha256 -eq $workspaceAcceptanceSha256 -and
      [string]$hostedTruth.product_acceptance_report_sha256 -eq $productAcceptanceSha256 -and
      [string]$hostedTruth.workspace_22_page_report_sha256 -eq $workspaceAcceptanceSha256 -and
      $null -ne $productAcceptance -and
      [string]$productAcceptance.contract_version -eq "product-acceptance-3d-game-v1" -and
      [string]$productAcceptance.status -eq "verified" -and
      [bool]$productAcceptance.dev_only -eq $false -and
      [bool]$productAcceptance.hosted_proof -eq $true -and
      [string]$productAcceptance.proof_scope -eq "hosted_https" -and
      [string]$productAcceptance.base_url -eq [string]$hostedState.product_acceptance_base_url -and
      [string]$productAcceptance.source_binding.source_commit_sha -eq [string]$hostedState.product_acceptance_source_commit_sha -and
      [string]$productAcceptance.source_binding.source_archive_sha256 -eq [string]$hostedState.product_acceptance_source_archive_sha256 -and
      [string]$productAcceptance.source_binding.deployment_id -eq [string]$hostedState.product_acceptance_deployment_id -and
      [bool]$productAcceptance.build.live_provider_calls -eq $true -and
      [string]$productAcceptance.build.gateway_mode -eq "cloudflare_workers_ai_live" -and
      [string]$productAcceptance.build.gateway_provider -eq "cloudflare-workers-ai" -and
      [bool]$productAcceptance.build.direct_provider_calls -eq $false -and
      [bool]$productAcceptance.build.live_mcp_writes -eq $false -and
      [bool]$productAcceptance.build.audit_persisted -eq $true -and
      [bool]$productAcceptance.build.persisted -eq $true -and
      [bool]$productAcceptance.mocks_used -eq $false -and
      [bool]$productAcceptance.route_interception_used -eq $false -and
      [int]$productAcceptance.console_error_count -eq 0 -and
      [int]$productAcceptance.page_error_count -eq 0 -and
      [bool]$productAcceptance.secret_output -eq $false -and
      $null -ne $workspaceAcceptance -and
      [string]$workspaceAcceptance.contract_version -eq "22-page-action-acceptance-v2" -and
      [string]$workspaceAcceptance.status -eq "verified" -and
      [bool]$workspaceAcceptance.dev_only -eq $false -and
      [bool]$workspaceAcceptance.hosted_proof -eq $true -and
      [string]$workspaceAcceptance.proof_scope -eq "hosted_https" -and
      [string]$workspaceAcceptance.base_url -eq [string]$hostedState.workspace_22_page_base_url -and
      [string]$workspaceAcceptance.source_binding.source_commit_sha -eq [string]$hostedState.workspace_22_page_source_commit_sha -and
      [string]$workspaceAcceptance.source_binding.source_archive_sha256 -eq [string]$hostedState.workspace_22_page_source_archive_sha256 -and
      [string]$workspaceAcceptance.source_binding.deployment_id -eq [string]$hostedState.workspace_22_page_deployment_id -and
      [string]$workspaceAcceptance.source_binding.product_acceptance_report_path -eq $productAcceptanceRelativePath -and
      [string]$workspaceAcceptance.source_binding.product_acceptance_report_sha256 -eq $productAcceptanceSha256.ToLowerInvariant() -and
      [int]$workspaceAcceptance.registered_route_count -eq 22 -and
      [int]$workspaceAcceptance.visited_route_count -eq 22 -and
      [bool]$workspaceAcceptance.route_registry_parity -eq $true -and
      [int]$workspaceAcceptance.audited_enabled_family_count -eq [int]$workspaceAcceptance.registered_enabled_family_count -and
      [int]$workspaceAcceptance.effect_verified_family_count -eq [int]$workspaceAcceptance.registered_enabled_family_count -and
      [int]$workspaceAcceptance.audited_enabled_member_action_count -eq [int]$workspaceAcceptance.registered_enabled_member_action_count -and
      [int]$workspaceAcceptance.dead_action_count -eq 0 -and
      [int]$workspaceAcceptance.unregistered_page_local_action_count -eq 0 -and
      [int]$workspaceAcceptance.click_only_passes -eq 0 -and
      [int]$workspaceAcceptance.non_direct_pass_count -eq 0 -and
      [int]$workspaceAcceptance.provider_request_count -eq 2 -and
      [int]$workspaceAcceptance.allowed_build_request_count -eq 2 -and
      [int]$workspaceAcceptance.live_provider_response_count -eq 2 -and
      [int]$workspaceAcceptance.unexpected_provider_request_count -eq 0 -and
      [int]$workspaceAcceptance.console_error_count -eq 0 -and
      [int]$workspaceAcceptance.page_error_count -eq 0 -and
      [bool]$workspaceAcceptance.mocks_used -eq $false -and
      [bool]$workspaceAcceptance.route_interception_used -eq $false -and
      [bool]$workspaceAcceptance.secret_output -eq $false
    )

    $agentWriteGate = $capabilityState.gates.live_agent_tool_writes
    $mcpWriteGate = $capabilityState.gates.live_mcp_writes
    $o4StateOk = $false
    if (-not $o4IsResolved) {
      $o4StateOk = (
        $null -ne $o4Action -and
        [string]$o4Action.status -eq "owner_required" -and
        [string]$o4Action.owner_scope_decision.decision -eq "approved_as_proposed" -and
        [bool]$o4Action.owner_scope_decision.gate_state_unchanged -eq $true -and
        [bool]$agentWriteGate.owner_granted -eq $false -and
        [bool]$agentWriteGate.live_verified -eq $false -and
        [bool]$mcpWriteGate.owner_granted -eq $false -and
        [bool]$mcpWriteGate.live_verified -eq $false
      )
    } else {
      $o4EvidenceRelativePath = [string]$agentWriteGate.evidence_artifact
      $o4EvidencePath = Resolve-RepoScopedFile $o4EvidenceRelativePath
      $o4EvidenceSha256 = if ($o4EvidencePath) { Get-FileSha256 $o4EvidencePath } else { "" }
      $o4Evidence = if ($o4EvidencePath) {
        Get-Content -LiteralPath $o4EvidencePath -Raw | ConvertFrom-Json
      } else {
        $null
      }
      $o4RuntimeRelativePath = if ($o4Evidence) { [string]$o4Evidence.runtime_report } else { "" }
      $o4BrowserRelativePath = if ($o4Evidence) { [string]$o4Evidence.browser_report } else { "" }
      $o4RuntimePath = Resolve-RepoScopedFile $o4RuntimeRelativePath
      $o4BrowserPath = Resolve-RepoScopedFile $o4BrowserRelativePath
      $o4RuntimeSha256 = if ($o4RuntimePath) { Get-FileSha256 $o4RuntimePath } else { "" }
      $o4BrowserSha256 = if ($o4BrowserPath) { Get-FileSha256 $o4BrowserPath } else { "" }
      $o4Runtime = if ($o4RuntimePath) {
        Get-Content -LiteralPath $o4RuntimePath -Raw | ConvertFrom-Json
      } else {
        $null
      }
      $o4Browser = if ($o4BrowserPath) {
        Get-Content -LiteralPath $o4BrowserPath -Raw | ConvertFrom-Json
      } else {
        $null
      }
      $agentPoolProgress = @($m.vertical.items | Where-Object { [string]$_.id -eq "layer_3" }) | Select-Object -First 1
      $o4StateOk = (
        $null -ne $o4Action -and
        [string]$o4Action.status -eq "resolved_verified" -and
        [int]$o4Action.percentage_credit -eq 31 -and
        [int]$o4Action.percentage_credit_breakdown.layer_3 -eq 31 -and
        [int]$o4Action.percentage_credit_breakdown.layer_5 -eq 0 -and
        [int]$o4Action.percentage_credit_breakdown.phase_6 -eq 0 -and
        @($o4Action.evidence_refs) -contains "docs/runtime-state/capability-gates.json#live_agent_tool_writes" -and
        @($o4Action.evidence_refs) -contains "docs/runtime-state/capability-gates.json#live_mcp_writes" -and
        @($o4Action.evidence_refs) -contains $o4EvidenceRelativePath -and
        $null -ne $agentWriteGate -and
        $null -ne $mcpWriteGate -and
        [bool]$agentWriteGate.owner_granted -eq $true -and
        [bool]$agentWriteGate.live_verified -eq $true -and
        [bool]$mcpWriteGate.owner_granted -eq $true -and
        [bool]$mcpWriteGate.live_verified -eq $true -and
        [string]$agentWriteGate.evidence_artifact -eq [string]$mcpWriteGate.evidence_artifact -and
        [string]$agentWriteGate.evidence_sha256 -eq $o4EvidenceSha256 -and
        [string]$mcpWriteGate.evidence_sha256 -eq $o4EvidenceSha256 -and
        [string]$agentWriteGate.provider -eq "local_mcp_gateway_filesystem" -and
        [string]$mcpWriteGate.provider -eq "local_mcp_gateway_filesystem" -and
        [bool]$agentWriteGate.paid_provider -eq $false -and
        [bool]$mcpWriteGate.paid_provider -eq $false -and
        [string]$agentWriteGate.verifier -eq "scripts/verify-o4-live-writes.ps1" -and
        [string]$mcpWriteGate.verifier -eq "scripts/verify-o4-live-writes.ps1" -and
        [bool]$agentWriteGate.runtime_verified -eq $true -and
        [bool]$agentWriteGate.browser_verified -eq $true -and
        [bool]$agentWriteGate.branch_protection_verified -eq $true -and
        [bool]$agentWriteGate.audit_fail_closed_verified -eq $true -and
        [bool]$mcpWriteGate.runtime_verified -eq $true -and
        [bool]$mcpWriteGate.browser_verified -eq $true -and
        [bool]$mcpWriteGate.branch_protection_verified -eq $true -and
        [bool]$mcpWriteGate.audit_fail_closed_verified -eq $true -and
        $null -ne $o4Evidence -and
        [string]$o4Evidence.contract_version -eq "o4-live-agent-mcp-write-proof-v1" -and
        [string]$o4Evidence.status -eq "verified" -and
        [string]$o4Evidence.provider -eq "local_mcp_gateway_filesystem" -and
        [bool]$o4Evidence.paid_provider -eq $false -and
        [bool]$o4Evidence.live_agent_tool_writes -eq $true -and
        [bool]$o4Evidence.live_mcp_writes -eq $true -and
        [bool]$o4Evidence.runtime_verified -eq $true -and
        [bool]$o4Evidence.browser_verified -eq $true -and
        [bool]$o4Evidence.proof_worktree_clean_verified -eq $true -and
        [bool]$o4Evidence.audit_failure_rollback_verified -eq $true -and
        [bool]$o4Evidence.arbitrary_paths_allowed -eq $false -and
        [bool]$o4Evidence.main_write -eq $false -and
        [bool]$o4Evidence.force_push -eq $false -and
        [bool]$o4Evidence.production_deploy -eq $false -and
        [bool]$o4Evidence.secret_output -eq $false -and
        [bool]$o4Evidence.DEV_ONLY -eq $true -and
        [string]$o4Evidence.runtime_report_sha256 -eq $o4RuntimeSha256 -and
        [string]$o4Evidence.browser_report_sha256 -eq $o4BrowserSha256 -and
        $null -ne $o4Runtime -and
        [string]$o4Runtime.contract_version -eq "o4-live-write-runtime-proof-v1" -and
        [string]$o4Runtime.status -eq "verified" -and
        [bool]$o4Runtime.audit_failure_rollback_verified -eq $true -and
        [bool]$o4Runtime.proof_worktree_clean_verified -eq $true -and
        [bool]$o4Runtime.secret_output -eq $false -and
        $null -ne $o4Browser -and
        [string]$o4Browser.contract_version -eq "o4-live-write-browser-proof-v1" -and
        [string]$o4Browser.status -eq "verified" -and
        [bool]$o4Browser.real_browser -eq $true -and
        [bool]$o4Browser.proof_worktree_clean_verified -eq $true -and
        [bool]$o4Browser.secret_output -eq $false -and
        [string]$o4Evidence.runtime_report_source_commit -eq [string]$o4Runtime.source_commit -and
        [string]$o4Evidence.browser_report_source_commit -eq [string]$o4Browser.source_commit -and
        [bool]$o4Evidence.runtime_source_parity_verified -eq $true -and
        [bool]$o4Evidence.browser_source_parity_verified -eq $true -and
        $null -ne $agentPoolProgress -and
        [int]$agentPoolProgress.percent -eq 100 -and
        [string]$agentPoolProgress.status -match "bounded_live_agent_mcp_write_audit_verified"
      )
    }

    $o5 = @($resolvedActions | Where-Object { [string]$_.id -eq "O5" }) | Select-Object -First 1
    $vectorGate = $capabilityState.gates.live_vector_memory_search
    $vectorEvidencePath = Resolve-RepoScopedFile ([string]$vectorGate.evidence_artifact)
    $vectorEvidenceSha256 = if ($vectorEvidencePath) {
      Get-FileSha256 $vectorEvidencePath
    } else {
      ""
    }
    $vectorEvidence = if ($vectorEvidencePath) {
      Get-Content -LiteralPath $vectorEvidencePath -Raw | ConvertFrom-Json
    } else {
      $null
    }
    $memoryProgress = @($m.vertical.items | Where-Object { [string]$_.id -eq "layer_6" }) | Select-Object -First 1
    $o5ResolvedOk = (
      $null -ne $o5 -and
      [string]$o5.status -eq "resolved_verified" -and
      [int]$o5.percentage_credit -eq 10 -and
      @($o5.evidence_refs) -contains "docs/runtime-state/capability-gates.json#live_vector_memory_search" -and
      @($o5.evidence_refs) -contains [string]$vectorGate.evidence_artifact -and
      $null -ne $vectorGate -and
      [bool]$vectorGate.owner_granted -eq $true -and
      [bool]$vectorGate.owner_scope_approved -eq $true -and
      [bool]$vectorGate.architecture_approved -eq $true -and
      [bool]$vectorGate.hosted_semantic_search_verified -eq $true -and
      [bool]$vectorGate.live_verified -eq $true -and
      [string]$vectorGate.provider -eq "cloudflare_vectorize" -and
      [bool]$vectorGate.paid_provider -eq $false -and
      [string]$vectorGate.verifier -eq "scripts/verify-live-vector-memory-search.ps1" -and
      [string]$vectorGate.evidence_sha256 -eq $vectorEvidenceSha256 -and
      $null -ne $vectorEvidence -and
      [string]$vectorEvidence.contract_version -eq "live-vector-memory-search-proof-v1" -and
      [string]$vectorEvidence.status -eq "verified" -and
      [bool]$vectorEvidence.live_verified -eq $true -and
      [bool]$vectorEvidence.hosted_semantic_search_verified -eq $true -and
      [bool]$vectorEvidence.lexical_evidence_reused -eq $false -and
      [bool]$vectorEvidence.paid_provider -eq $false -and
      [bool]$vectorEvidence.secret_output -eq $false -and
      @($vectorEvidence.blockers).Count -eq 0 -and
      [int]$vectorEvidence.percentage_credit -eq 0 -and
      $null -ne $memoryProgress -and
      [int]$memoryProgress.percent -eq 100 -and
      [string]$memoryProgress.status -match "hosted_semantic_vector_search_cloudflare_vectorize_roundtrip_verified"
    )

    $o6 = @($resolvedActions | Where-Object { [string]$_.id -eq "O6" }) | Select-Object -First 1
    $llmGate = $capabilityState.gates.live_llm_provider_calls
    $o6ResolvedOk = (
      $null -ne $o6 -and
      [string]$o6.status -eq "resolved_verified" -and
      [int]$o6.percentage_credit -eq 0 -and
      @($o6.evidence_refs) -contains $hostedStateRelativePath -and
      @($o6.evidence_refs) -contains $productAcceptanceRelativePath -and
      $null -ne $llmGate -and
      [bool]$llmGate.owner_granted -eq $true -and
      [bool]$llmGate.live_verified -eq $true -and
      [string]$llmGate.provider -eq "cloudflare_workers_ai" -and
      [bool]$llmGate.paid_provider -eq $false -and
      $hostedAcceptanceOk
    )
    $sourceMatches = (
      [int]$ownerInput.canonical_overall_percent -eq [int]$m.overall_percent -and
      [bool]$ownerInput.market_ready -eq $false
    )
    $ownerMatrixOk = (
      [string]$ownerInput.contract_version -eq "owner-input-manifest-v2" -and
      [string]$ownerInput.status -eq "owner_blocked_autonomous_complete" -and
      $autonomousOpenItemsOk -and
      $invalidActions.Count -eq 0 -and
      $unknownIds.Count -eq 0 -and
      $ownerUncoveredCellIds.Count -eq 0 -and
      $actionMapOk -and
      $unknownGateIds.Count -eq 0 -and
      $closedGateStateOk -and
      $externalGateStateOk -and
      $o2ZeroCardOk -and
      $hostedAcceptanceOk -and
      $o4StateOk -and
      $o5ResolvedOk -and
      $o6ResolvedOk -and
      $sourceMatches
    )
    $ownerMatrixDetail = if ($ownerMatrixOk) {
      "owner-required below-100 cells: " + ($ownerBlockedCellIds -join ", ") + "; resolved-no-credit cells: " + ($resolvedCellIds -join ", ")
    } else {
      "invalid_actions=$($invalidActions.Count) autonomous_open=$($autonomousOpenItems.Count) unknown_cells=$($unknownIds -join ',') uncovered_cells=$($ownerUncoveredCellIds -join ',') action_map=$actionMapOk unknown_gates=$($unknownGateIds -join ',') closed_gates=$closedGateStateOk external_gate=$externalGateStateOk external_audit=$externalAuditOk cloudflare_scope=$cloudflareScopeReadinessOk cloudflare_target=$cloudflareTargetGateOk o2_zero_card=$o2ZeroCardOk hosted_acceptance=$hostedAcceptanceOk o4_state=$o4StateOk o5_resolved=$o5ResolvedOk o6_resolved=$o6ResolvedOk source_matches=$sourceMatches"
    }
  }
} catch {
  $ownerMatrixDetail = "parse error: $($_.Exception.Message)"
}

if ($null -ne $ownerInput -and
    [string]$ownerInput.contract_version -eq "owner-input-manifest-v2" -and
    [string]$ownerInput.status -eq "owner_blocked_autonomous_complete" -and
    [bool]$ownerInput.market_ready -eq $false -and
    -not $allHundred) {
  $truthMode = "owner_blocked"
}

if ($null -ne $ownerInput -and
    [string]$ownerInput.contract_version -eq "owner-input-manifest-v2" -and
    [string]$ownerInput.status -eq "market_ready_verified" -and
    [bool]$ownerInput.market_ready -eq $true -and
    $allHundred) {
  $truthMode = "ready"
  $expectedReadyActionCells = @{
    O1 = @("phase_3")
    O2 = @("phase_5", "phase_6")
    O3 = @("layer_5", "phase_5")
    O4 = @("layer_3", "layer_5", "phase_6")
    O5 = @("layer_6")
    O6 = @("layer_4")
  }
  $readyActionIds = @($actions | ForEach-Object { [string]$_.id } | Sort-Object)
  $readyActionMapOk = (
    $actions.Count -eq 6 -and
    ($readyActionIds -join ",") -eq (($expectedReadyActionCells.Keys | Sort-Object) -join ",") -and
    @($actions | Where-Object {
      [string]$_.status -ne "resolved_verified" -or
      @($_.evidence_refs).Count -eq 0 -or
      @($_.verifier_after).Count -eq 0 -or
      [string]::IsNullOrWhiteSpace([string]$_.required_owner_action)
    }).Count -eq 0
  )
  foreach ($action in $actions) {
    $actionId = [string]$action.id
    $actualAffected = @($action.affected_cells | ForEach-Object { [string]$_ } | Sort-Object)
    $expectedAffected = @($expectedReadyActionCells[$actionId] | Sort-Object)
    if (($actualAffected -join ",") -ne ($expectedAffected -join ",")) { $readyActionMapOk = $false }
  }

  $phase5ReadyOk = (
    $null -ne $phase5Credit -and
    [int]$phase5Credit.current_score.total_item_count -eq 19 -and
    [int]$phase5Credit.current_score.verified_item_count -eq 19 -and
    [int]$phase5Credit.current_score.blocked_item_count -eq 0 -and
    @($phase5Credit.current_score.blocked_item_ids).Count -eq 0 -and
    [int]$phase5Credit.current_score.computed_percent -eq 100 -and
    @($phase5Credit.items).Count -eq 19 -and
    @($phase5Credit.items | Where-Object {
      [string]$_.status -ne "verified" -or [bool]$_.credit_awarded -ne $true
    }).Count -eq 0
  )

  $externalAuditReadyOk = (
    $null -ne $externalAudit -and
    [string]$externalAudit.contract_version -eq "external-gate-audit-v2" -and
    [string]$externalAudit.status -eq "verified" -and
    [bool]$externalAudit.production_deploy_claim_allowed -eq $true -and
    @($externalAudit.missing_or_failed_gates).Count -eq 0 -and
    [bool]$externalAudit.cloudflare_native_zero_card_hosted_runtime_claim_allowed -eq $true -and
    [string]$externalAudit.legacy_provenance.status -eq "historical_only" -and
    [string]$externalAudit.legacy_provenance.retired_gate_id -eq "fly_live_budget_check"
  )
  $externalReadyOk = (
    $null -ne $externalState -and
    [string]$externalState.contract_version -eq "external-gate-summary-v2" -and
    [string]$externalState.source_contract_version -eq "external-gate-audit-v2" -and
    [string]$externalState.status -eq "verified" -and
    [bool]$externalState.production_deploy_claim_allowed -eq $true -and
    [bool]$externalState.branch_protection_claim_allowed -eq $true -and
    [bool]$externalState.ghcr_image_digest_claim_allowed -eq $true -and
    [bool]$externalState.cloudflare_native_zero_card_hosted_runtime_claim_allowed -eq $true -and
    @($externalState.missing_or_failed_gates).Count -eq 0 -and
    [string]$ownerInput.external_gate_truth.status -eq "verified" -and
    [bool]$ownerInput.external_gate_truth.production_deploy_claim_allowed -eq $true -and
    @($ownerInput.external_gate_truth.missing_or_failed_gates).Count -eq 0 -and
    $externalAuditReadyOk
  )

  $readyGateChecks = @(
    Get-ReadyGateEvidenceValidation $capabilityState.gates.production_auth_identity "production_auth_identity" $candidateSha
    Get-ReadyGateEvidenceValidation $capabilityState.gates.docker_registry_publish "docker_registry_publish" $candidateSha
    Get-ReadyGateEvidenceValidation $capabilityState.gates.phase6_scale_runtime "phase6_scale_runtime" $candidateSha
  )
  $readyGatesOk = (@($readyGateChecks | Where-Object { -not $_.ok }).Count -eq 0)

  $readyHostedCandidateOk = (
    [string]$hostedState.source_commit_sha -eq $candidateSha -and
    [string]$hostedState.product_acceptance_source_commit_sha -eq $candidateSha -and
    [string]$hostedState.workspace_22_page_source_commit_sha -eq $candidateSha -and
    [string]$productAcceptance.source_binding.source_commit_sha -eq $candidateSha -and
    [string]$workspaceAcceptance.source_binding.source_commit_sha -eq $candidateSha
  )

  $readyTruthPaths = @(
    "docs/project-progress.manifest.json",
    "docs/runtime-state/owner-input-manifest.json",
    "docs/runtime-state/capability-gates.json",
    "docs/runtime-state/external-gate-summary.json",
    ([string]$externalState.source_artifact).Replace('\', '/'),
    "docs/runtime-state/phase5-credit-itemization.json",
    "docs/release-artifacts/current-release-candidate.json",
    $candidateReadinessRelativePath,
    $hostedStateRelativePath,
    $productAcceptanceRelativePath,
    $workspaceAcceptanceRelativePath,
    ".codex/runs/CURRENT/master-goal/PROOF_LEDGER.md"
  ) + @($readyGateChecks | ForEach-Object { [string]$_.evidence_path }) + @(
    $actions |
      ForEach-Object { @($_.evidence_refs) } |
      ForEach-Object { ([string]$_ -split '#', 2)[0] }
  )
  $dirtyReadyTruthPaths = @(
    $readyTruthPaths |
      Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
      Sort-Object -Unique |
      Where-Object { -not (Test-TrackedCleanRepoFile ([string]$_)) }
  )
  $readyTruthFilesClean = ($dirtyReadyTruthPaths.Count -eq 0)
  $readyTrackedWorktreeState = @(& git.exe -C $repoRoot status --porcelain=v1 --untracked-files=no)
  $readyTrackedWorktreeClean = ($LASTEXITCODE -eq 0 -and $readyTrackedWorktreeState.Count -eq 0)

  $readySourceMatches = (
    [int]$m.overall_percent -eq 100 -and
    $progressCells.Count -eq 14 -and
    [int]$ownerInput.canonical_overall_percent -eq 100 -and
    @($ownerInput.autonomous_open_items).Count -eq 0
  )
  $ownerMatrixOk = (
    $candidateStateOk -and
    $readySourceMatches -and
    $readyActionMapOk -and
    $invalidActions.Count -eq 0 -and
    $unknownIds.Count -eq 0 -and
    $ownerUncoveredCellIds.Count -eq 0 -and
    $unknownGateIds.Count -eq 0 -and
    $phase5ReadyOk -and
    $externalReadyOk -and
    $readyHostedCandidateOk -and
    $cloudflareTargetGateOk -and
    $o2ZeroCardOk -and
    $hostedAcceptanceOk -and
    $o4StateOk -and
    $o5ResolvedOk -and
    $o6ResolvedOk -and
    $readyGatesOk -and
    $readyTruthFilesClean -and
    $readyTrackedWorktreeClean
  )
  $ownerMatrixDetail = if ($ownerMatrixOk) {
    "ready truth: 14/14 cells=100, O1-O6 resolved, three final capability gates source-bound, external/hosted evidence verified"
  } else {
    $gateFailureDetail = @($readyGateChecks | Where-Object { -not $_.ok } | ForEach-Object { $_.detail }) -join ";"
    "ready invalid: source=$readySourceMatches actions=$readyActionMapOk phase5=$phase5ReadyOk external=$externalReadyOk hosted=$hostedAcceptanceOk hosted_candidate=$readyHostedCandidateOk o4=$o4StateOk o5=$o5ResolvedOk o6=$o6ResolvedOk gates=$readyGatesOk gate_detail=$gateFailureDetail tracked_clean=$readyTruthFilesClean worktree_clean=$readyTrackedWorktreeClean dirty=$($dirtyReadyTruthPaths -join ',')"
  }
}
$invalidBooleanFields = @()
foreach ($truthObject in @(
  [pscustomobject]@{ name = "owner"; value = $ownerInput },
  [pscustomobject]@{ name = "capability"; value = $capabilityState },
  [pscustomobject]@{ name = "external"; value = $externalState },
  [pscustomobject]@{ name = "external_audit"; value = $externalAudit },
  [pscustomobject]@{ name = "hosted"; value = $hostedState },
  [pscustomobject]@{ name = "product"; value = $productAcceptance },
  [pscustomobject]@{ name = "workspace"; value = $workspaceAcceptance },
  [pscustomobject]@{ name = "o4"; value = $o4Evidence },
  [pscustomobject]@{ name = "o4_runtime"; value = $o4Runtime },
  [pscustomobject]@{ name = "o4_browser"; value = $o4Browser },
  [pscustomobject]@{ name = "vector"; value = $vectorEvidence }
)) {
  if ($null -ne $truthObject.value) {
    $invalidBooleanFields += @(Find-InvalidBooleanFields $truthObject.value $truthObject.name)
  }
}
$truthTypesOk = ($invalidBooleanFields.Count -eq 0)
Add-Result "truth-boolean-types" $truthTypesOk $(if ($truthTypesOk) { "strict JSON booleans" } else { "invalid: " + ($invalidBooleanFields -join ',') })
Add-Result "owner-input-matrix" $ownerMatrixOk $ownerMatrixDetail
Add-Result "autonomous-open-items" $autonomousOpenItemsOk $autonomousOpenItemsDetail
Add-Result "manifest-all-100" ($allHundred -and $overallHundred) $cellDetail $true (-not $allHundred -and $ownerMatrixOk) "readiness"

# PROOF_LEDGER: der jeweils neueste append-only Status pro Item darf nicht OPEN sein.
$ledgerPath = Join-Path $repoRoot ".codex\runs\CURRENT\master-goal\PROOF_LEDGER.md"
$ledgerOk = $false; $ledgerDetail = "missing"
$ledgerOwnerGated = $false
$ledgerIntegrityOk = $false
$ledgerIntegrityDetail = "missing"
if (Test-Path $ledgerPath) {
  $latestStatus = @{}
  $ledgerDataRows = 0
  $ledgerMalformedRows = 0
  foreach ($line in Get-Content $ledgerPath) {
    if ($line -notmatch '^\|') { continue }
    $ledgerCells = @($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($ledgerCells.Count -gt 0 -and ($ledgerCells[0] -eq 'item' -or $ledgerCells[0] -match '^-+$' -or $ledgerCells[-1] -eq 'status')) { continue }
    $ledgerDataRows++
    if ($ledgerCells.Count -ne 8 -or [string]::IsNullOrWhiteSpace([string]$ledgerCells[0])) {
      $ledgerMalformedRows++
      continue
    }
    $status = $ledgerCells[7]
    if ($status -notin @('PASS', 'OPEN', 'REVOKED')) {
      $ledgerMalformedRows++
      continue
    }
    $latestStatus[$ledgerCells[0]] = $status
  }
  $ledgerIntegrityOk = ($ledgerDataRows -gt 0 -and $ledgerMalformedRows -eq 0 -and $latestStatus.Count -gt 0)
  $ledgerIntegrityDetail = "rows=$ledgerDataRows malformed=$ledgerMalformedRows latest_items=$($latestStatus.Count)"
  $openItems = @($latestStatus.GetEnumerator() | Where-Object { $_.Value -eq 'OPEN' } | ForEach-Object { $_.Key })
  $autonomousOpenItems = @($openItems | Where-Object { $_ -notmatch '^B\d+-|owner[-_ ]gated|owner[-_ ]gate' })
  $ledgerOwnerGated = ($openItems.Count -gt 0 -and $autonomousOpenItems.Count -eq 0)
  $ledgerOk = ($ledgerIntegrityOk -and $openItems.Count -eq 0)
  $ledgerDetail = if (-not $ledgerIntegrityOk) {
    "ledger integrity failed"
  } elseif ($ledgerOk) {
    "no latest OPEN status"
  } else {
    "latest OPEN: " + ($openItems -join ', ')
  }
}
Add-Result "proof-ledger-integrity" $ledgerIntegrityOk $ledgerIntegrityDetail
$ledgerFailureClass = if ($ledgerOk -or $ledgerOwnerGated) { "readiness" } else { "integrity" }
Add-Result "proof-ledger-clean" $ledgerOk $ledgerDetail $true $ledgerOwnerGated $ledgerFailureClass

# Every artifact used to classify the current truth must survive a clean clone. Local ignored
# run files are not evidence until their exact bytes are explicitly versioned and remain clean.
$canonicalEvidencePaths = @(
  "docs/runtime-state/cloudflare-native-hosted-current.json",
  ".codex/runs/CURRENT/p5/cloudflare-scope-readiness/report.json",
  ".codex/runs/CURRENT/master-goal/PROOF_LEDGER.md",
  [string]$productAcceptanceRelativePath,
  [string]$workspaceAcceptanceRelativePath
)
if ($null -ne $capabilityState) {
  foreach ($gateProperty in $capabilityState.gates.PSObject.Properties) {
    $gate = $gateProperty.Value
    if (Test-JsonBool $gate.live_verified $true) {
      $canonicalEvidencePaths += [string]$gate.evidence_artifact
      if ($null -ne $gate.PSObject.Properties["local_evidence_artifact"]) {
        $canonicalEvidencePaths += [string]$gate.local_evidence_artifact
      }
    }
  }
}
foreach ($action in @($resolvedActions)) {
  foreach ($evidenceRef in @($action.evidence_refs)) {
    $canonicalEvidencePaths += ([string]$evidenceRef -split '#', 2)[0]
  }
}
$canonicalEvidencePaths = @(
  $canonicalEvidencePaths |
    ForEach-Object { ([string]$_).Trim().Replace('\', '/') } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object -Unique
)
$nonPortableEvidencePaths = @(
  $canonicalEvidencePaths |
    Where-Object { -not (Test-TrackedCleanRepoFile $_) }
)
$canonicalEvidencePortable = ($canonicalEvidencePaths.Count -gt 0 -and $nonPortableEvidencePaths.Count -eq 0)
$canonicalEvidenceDetail = if ($canonicalEvidencePortable) {
  "tracked_clean=$($canonicalEvidencePaths.Count)"
} else {
  "missing_or_dirty=" + ($nonPortableEvidencePaths -join ',')
}
Add-Result "canonical-evidence-portability" $canonicalEvidencePortable $canonicalEvidenceDetail

# Lint-Warnungen (marktreif = 0). Advisory-Zaehler, geht in die Pflicht ein.
$lintOk = $false; $lintDetail = "not run"
try {
  Push-Location (Join-Path $repoRoot "apps\frontend")
  $lintOut = (& npm run lint 2>&1 | Out-String)
  $lintExit = $LASTEXITCODE
  if ($null -eq $lintExit) { $lintExit = 127 }
  Pop-Location
  $warnCount = ([regex]::Matches($lintOut, "(?im)\bwarning\b")).Count
  $lintOk = ($lintExit -eq 0 -and $warnCount -eq 0)
  $lintDetail = "exit=$lintExit warnings~=$warnCount (marktreif verlangt 0)"
} catch { $lintDetail = "error: $($_.Exception.Message)" }
Add-Result "lint-zero-warnings" $lintOk $lintDetail

# --- 2) Runtime/Browser-Verifier (nur ohne -StaticOnly, Docker-Stack up) ---
if (-not $StaticOnly) {
  Invoke-Npm "verify(phase1+gitleaks)" "verify"
  Invoke-Npm "verify:runtime"          "verify:runtime"
  Write-Host "[market-ready] running: scripts\start-dev-live.ps1"
  & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "scripts\start-dev-live.ps1") 2>&1 |
    ForEach-Object { Write-Host "    $_" }
  $devLiveCode = $LASTEXITCODE; if ($null -eq $devLiveCode) { $devLiveCode = 127 }
  Add-Result "dev-live-rehydrate" ($devLiveCode -eq 0) "exit=$devLiveCode"
  if ($devLiveCode -eq 0) {
    Invoke-Npm "verify:browser" "verify:browser"
  } else {
    Add-Result "verify:browser" $false "skipped: DEV-LIVE rehydration failed"
  }
  Invoke-Npm "verify:csrf"             "verify:csrf"
  Invoke-Npm "verify:responsive"       "verify:responsive"
  Invoke-Npm "frontend-hosted-current" "verify:frontend-hosted-current"
  Invoke-Npm "backend-hosted-current"  "verify:backend-hosted-current"
  Invoke-Npm "verify:phase6-frontend"  "verify:phase6-frontend"
  Invoke-Npm "build(full-pages)"       "build"
  Invoke-Npm "current-release-candidate" "verify:current-release-candidate"
  if ($IncludeExternalGates) {
    Invoke-Npm "verify:release-candidate(stateful)" "verify:release-candidate" $true $true
  } else {
    Add-Result `
      "verify:release-candidate(stateful)" `
      $false `
      "SKIPPED: requires owner-gated stateful hosted runtime; use -IncludeExternalGates" `
      $true `
      $true `
      "readiness"
  }
} else {
  Add-Result "runtime-verifiers" $false "SKIPPED via -StaticOnly (kein MARKET_READY moeglich)" $true $false "readiness"
}

# --- 3) External Gates (owner-gated) ---
$gateStatus = "unknown"; $gateProd = $false
try {
  $g = Get-Content (Join-Path $repoRoot "docs\runtime-state\external-gate-summary.json") -Raw | ConvertFrom-Json
  $gateStatus = "$($g.status)"; $gateProd = (Test-JsonBool $g.production_deploy_claim_allowed $true)
} catch {}
if ($IncludeExternalGates) {
  Invoke-Npm "verify:external-gates" "verify:external-gates"
  try {
    $g = Get-Content (Join-Path $repoRoot "docs\runtime-state\external-gate-summary.json") -Raw | ConvertFrom-Json
    $gateStatus = "$($g.status)"; $gateProd = (Test-JsonBool $g.production_deploy_claim_allowed $true)
  } catch {}
}
$gatesOk = ($gateStatus -eq "verified" -and $gateProd)
Add-Result "external-gates-verified" $gatesOk "status=$gateStatus production_deploy_claim_allowed=$gateProd" $true $true "readiness"

# --- 4) Urteil ---
$readyContractOk = (
  $truthMode -eq "ready" -and
  $ownerMatrixOk -and
  $manifestShapeOk -and
  $allHundred -and
  $overallHundred -and
  $candidateStateOk -and
  $hostedAcceptanceOk -and
  $externalReadyOk -and
  $readyTruthFilesClean -and
  $readyTrackedWorktreeClean -and
  -not $StaticOnly -and
  $IncludeExternalGates -and
  $gatesOk
)
Add-Result `
  "ready-evidence-candidate-source-bound" `
  $readyContractOk `
  "truth_mode=$truthMode static_only=$([bool]$StaticOnly) external=$([bool]$IncludeExternalGates) candidate=$candidateStateOk tracked_evidence=$readyTruthFilesClean tracked_worktree=$readyTrackedWorktreeClean" `
  $true `
  ($truthMode -eq "owner_blocked" -and $ownerMatrixOk) `
  "readiness"

$requiredFails = @($results | Where-Object { $_.required -and -not $_.ok })
$integrityFails = @($requiredFails | Where-Object { [string]$_.failure_class -eq "integrity" })
$truthValid = (
  $integrityFails.Count -eq 0 -and
  $manifestShapeOk -and
  $candidateStateOk -and
  $ownerMatrixOk -and
  $truthMode -in @("owner_blocked", "ready")
)
$marketReady = ($truthValid -and $truthMode -eq "ready" -and $requiredFails.Count -eq 0 -and $readyContractOk)
$validOwnerBlocked = ($truthValid -and $truthMode -eq "owner_blocked" -and -not $marketReady)
$aggregateState = if ($marketReady) {
  "READY"
} elseif ($validOwnerBlocked) {
  "OWNER_BLOCKED"
} else {
  "INVALID"
}
$exitCode = if ($aggregateState -eq "INVALID") {
  2
} elseif ($RequireReady -and -not $marketReady) {
  1
} else {
  0
}

Write-Host ""
Write-Host "=== MATRIX ==="
$results | ForEach-Object {
  $s = if ($_.ok) { "PASS" } elseif (-not $_.required) { "SKIP" } else { "FAIL" }
  Write-Host ("  {0,-34} {1}" -f $_.step, $s)
}
Write-Host ""
if ($aggregateState -ne "READY") {
  $ownerBlocked = @($requiredFails | Where-Object { $_.owner_gated -or $_.step -eq "external-gates-verified" })
  $auditSkipped = @(
    $requiredFails | Where-Object {
      $StaticOnly -and $_.step -eq "runtime-verifiers" -and $_.detail -match '^SKIPPED via -StaticOnly'
    }
  )
  $autonomousOpen = @($integrityFails)
  if ($ownerBlocked.Count -gt 0) {
    Write-Host "OWNER-BLOCKED (Spur B - siehe docs/runtime-state/owner-input-manifest.json):"
    $ownerBlocked | ForEach-Object { Write-Host "  - $($_.step): $($_.detail)" }
  }
  if ($auditSkipped.Count -gt 0) {
    Write-Host "AUDIT-MODUS (kein Implementierungsdefizit):"
    $auditSkipped | ForEach-Object { Write-Host "  - $($_.step): $($_.detail)" }
  }
  Write-Host "INTEGRITAET/AUTONOM OFFEN:"
  if ($autonomousOpen.Count -eq 0) {
    Write-Host "  - keine"
  } else {
    $autonomousOpen | ForEach-Object { Write-Host "  - $($_.step): $($_.detail)" }
  }
}

$report = [pscustomobject]@{
  contract_version = "market-ready-aggregate-v2"
  generated_at     = (Get-Date).ToUniversalTime().ToString("o")
  aggregate_state  = $aggregateState
  truth_valid      = $truthValid
  valid_owner_blocked = $validOwnerBlocked
  require_ready    = [bool]$RequireReady
  exit_code        = $exitCode
  active_release_id = $activeReleaseId
  candidate_sha    = $candidateSha
  candidate_source_bound = $candidateStateOk
  static_only      = [bool]$StaticOnly
  included_external_gates = [bool]$IncludeExternalGates
  manifest_all_100 = $allHundred
  manifest_overall_100 = $overallHundred
  manifest_cell_count = $progressCells.Count
  manifest_overall_percent = if ($null -ne $m) { $m.overall_percent } else { $null }
  manifest_cells   = $cellDetail
  owner_input_manifest = "docs/runtime-state/owner-input-manifest.json"
  owner_input_matrix_verified = $ownerMatrixOk
  autonomous_open_items_verified = $autonomousOpenItemsOk
  hosted_acceptance_verified = $hostedAcceptanceOk
  owner_blocked_cells = $ownerBlockedCellIds
  resolved_no_credit_cells = $resolvedCellIds
  owner_uncovered_cells = $ownerUncoveredCellIds
  gates_status     = $gateStatus
  production_deploy_claim_allowed = $gateProd
  ready_evidence_tracked_clean = $readyTruthFilesClean
  ready_tracked_worktree_clean = $readyTrackedWorktreeClean
  integrity_failure_count = $integrityFails.Count
  steps            = $results
  market_ready     = $marketReady
}
$report | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $artifactDir "report.json") -Encoding utf8

Write-Host ""
Write-Host ("AGGREGATE_STATE: {0}" -f $aggregateState)
Write-Host ("MARKET_READY: {0}" -f ($marketReady.ToString().ToLowerInvariant()))
exit $exitCode
