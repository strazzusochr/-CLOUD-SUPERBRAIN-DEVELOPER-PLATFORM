<#
  verify-market-ready.ps1 - AGGREGATE FINISH-LINE (eine Wahrheit fuer "100% marktreif").
  Druckt am Ende genau eine Zeile: "MARKET_READY: true" oder "MARKET_READY: false".
  true NUR wenn: alle Pflicht-Verifier exit 0 UND Manifest jede horizontale+vertikale Zelle == 100
  UND Gate-Audit status=verified & production_deploy_claim_allowed=true UND kein OPEN im PROOF_LEDGER.
  Kann NICHT gefaked werden: liest echte Verifier-Exitcodes und die echten Truth-Dateien.

  Beispiele:
    npm run verify:market-ready                 # voller Lauf (Docker-Stack up erwartet)
    powershell -File scripts\verify-market-ready.ps1 -StaticOnly           # nur statische Wahrheit
    powershell -File scripts\verify-market-ready.ps1 -IncludeExternalGates # + owner-gated Gate-Audit
#>
param(
  [switch]$StaticOnly,            # ueberspringt Docker/Runtime-Verifier
  [switch]$IncludeExternalGates,  # faehrt zusaetzlich verify:external-gates (braucht Owner-Inputs)
  [string]$OutDir = ".codex\runs\CURRENT\master-goal\market-ready"
)

$ErrorActionPreference = "Continue"   # Orchestrator darf nicht crashen; wir sammeln Fehler
$repoRoot   = Split-Path -Parent $PSScriptRoot
$artifactDir = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
$results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$name, [bool]$ok, [string]$detail, [bool]$required = $true, [bool]$ownerGated = $false) {
  $results.Add([pscustomobject]@{ step = $name; ok = $ok; required = $required; owner_gated = $ownerGated; detail = $detail })
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
  $code = $LASTEXITCODE; if ($null -eq $code) { $code = 0 }
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

Write-Host "=== MARKET-READY AGGREGATE GATE ==="

# --- 1) Statische Wahrheit (immer) ---
Write-Host "[market-ready] running: manifest integrity"
& py -3 (Join-Path $repoRoot "scripts\verify_project_progress_manifest.py") 2>&1 | ForEach-Object { Write-Host "    $_" }
$manifestOk = ($LASTEXITCODE -eq 0)
Add-Result "manifest-integrity" $manifestOk "verify_project_progress_manifest.py"

# Manifest-Zellen: jede horizontale + vertikale Zelle muss == 100 sein
$allHundred = $false; $cellDetail = "unreadable"; $below = @(); $cells = @()
try {
  $m = Get-Content (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
  $cells += $m.horizontal.items; $cells += $m.vertical.items
  $below = @($cells | Where-Object { [int]$_.percent -lt 100 })
  $allHundred = ($below.Count -eq 0)
  if ($allHundred) { $cellDetail = "all " + $cells.Count + " cells = 100" }
  else { $cellDetail = "below 100: " + (($below | ForEach-Object { "$($_.id)=$($_.percent)" }) -join ", ") }
} catch { $cellDetail = "parse error: $($_.Exception.Message)" }

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
try {
  if (Test-Path $ownerInputPath) {
    $ownerInput = Get-Content $ownerInputPath -Raw | ConvertFrom-Json
    $allCellIds = @($cells | ForEach-Object { [string]$_.id })
    $belowCellIds = @($below | ForEach-Object { [string]$_.id })
    $actions = @($ownerInput.actions)
    $ownerActions = @($actions | Where-Object { [string]$_.status -eq "owner_required" })
    $resolvedActions = @($actions | Where-Object { [string]$_.status -eq "resolved_verified" })
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
      O4 = @("layer_3", "layer_5", "phase_6")
      O5 = @("layer_6")
    }
    $expectedResolvedActionCells = @{
      O6 = @("layer_4")
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
    foreach ($gateId in @(
      "production_auth_identity",
      "docker_registry_publish",
      "phase6_scale_runtime",
      "live_mcp_writes",
      "live_agent_tool_writes",
      "live_vector_memory_search"
    )) {
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
      @($externalState.missing_or_failed_gates).Count -eq 2 -and
      @($externalState.missing_or_failed_gates) -contains "github_branch_protection_current_verify" -and
      @($externalState.missing_or_failed_gates) -contains "ghcr_image_digest_verify" -and
      [bool]$externalState.cloudflare_native_zero_card_hosted_runtime_claim_allowed -eq $true -and
      [string]$externalState.legacy_provenance.status -eq "historical_only" -and
      [string]$externalState.legacy_provenance.retired_gate_id -eq "fly_live_budget_check" -and
      [string]$ownerInput.external_gate_truth.active_target_gate -eq "cloudflare_native_zero_card_hosted_runtime" -and
      @($ownerInput.external_gate_truth.missing_or_failed_gates).Count -eq 2 -and
      @($ownerInput.external_gate_truth.missing_or_failed_gates) -contains "github_branch_protection_current_verify" -and
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
      $o6ResolvedOk -and
      $sourceMatches
    )
    $ownerMatrixDetail = if ($ownerMatrixOk) {
      "owner-required below-100 cells: " + ($ownerBlockedCellIds -join ", ") + "; resolved-no-credit cells: " + ($resolvedCellIds -join ", ")
    } else {
      "invalid_actions=$($invalidActions.Count) autonomous_open=$($autonomousOpenItems.Count) unknown_cells=$($unknownIds -join ',') uncovered_cells=$($ownerUncoveredCellIds -join ',') action_map=$actionMapOk unknown_gates=$($unknownGateIds -join ',') closed_gates=$closedGateStateOk external_gate=$externalGateStateOk external_audit=$externalAuditOk cloudflare_scope=$cloudflareScopeReadinessOk cloudflare_target=$cloudflareTargetGateOk o2_zero_card=$o2ZeroCardOk hosted_acceptance=$hostedAcceptanceOk o6_resolved=$o6ResolvedOk source_matches=$sourceMatches"
    }
  }
} catch {
  $ownerMatrixDetail = "parse error: $($_.Exception.Message)"
}
Add-Result "owner-input-matrix" $ownerMatrixOk $ownerMatrixDetail
Add-Result "autonomous-open-items" $autonomousOpenItemsOk $autonomousOpenItemsDetail
Add-Result "manifest-all-100" $allHundred $cellDetail $true (-not $allHundred -and $ownerMatrixOk)

# PROOF_LEDGER: der jeweils neueste append-only Status pro Item darf nicht OPEN sein.
$ledgerPath = Join-Path $repoRoot ".codex\runs\CURRENT\master-goal\PROOF_LEDGER.md"
$ledgerOk = $false; $ledgerDetail = "missing"
$ledgerOwnerGated = $false
if (Test-Path $ledgerPath) {
  $latestStatus = @{}
  foreach ($line in Get-Content $ledgerPath) {
    if ($line -notmatch '^\|') { continue }
    $cells = @($line.Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -lt 8 -or $cells[0] -eq 'item' -or $cells[0] -match '^-+$') { continue }
    $status = $cells[$cells.Count - 1]
    if ($status -in @('PASS', 'OPEN', 'REVOKED')) { $latestStatus[$cells[0]] = $status }
  }
  $openItems = @($latestStatus.GetEnumerator() | Where-Object { $_.Value -eq 'OPEN' } | ForEach-Object { $_.Key })
  $autonomousOpenItems = @($openItems | Where-Object { $_ -notmatch '^B\d+-|owner[-_ ]gated|owner[-_ ]gate' })
  $ledgerOwnerGated = ($openItems.Count -gt 0 -and $autonomousOpenItems.Count -eq 0)
  $ledgerOk = ($openItems.Count -eq 0)
  $ledgerDetail = if ($ledgerOk) { "no latest OPEN status" } else { "latest OPEN: " + ($openItems -join ', ') }
}
Add-Result "proof-ledger-clean" $ledgerOk $ledgerDetail $true $ledgerOwnerGated

# Lint-Warnungen (marktreif = 0). Advisory-Zaehler, geht in die Pflicht ein.
$lintOk = $false; $lintDetail = "not run"
try {
  Push-Location (Join-Path $repoRoot "apps\frontend")
  $lintOut = (& npm run lint 2>&1 | Out-String)
  $lintExit = $LASTEXITCODE
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
  Invoke-Npm "verify:browser"          "verify:browser"
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
      $true
  }
} else {
  Add-Result "runtime-verifiers" $false "SKIPPED via -StaticOnly (kein MARKET_READY moeglich)" $true
}

# --- 3) External Gates (owner-gated) ---
$gateStatus = "unknown"; $gateProd = $false
try {
  $g = Get-Content (Join-Path $repoRoot "docs\runtime-state\external-gate-summary.json") -Raw | ConvertFrom-Json
  $gateStatus = "$($g.status)"; $gateProd = [bool]$g.production_deploy_claim_allowed
} catch {}
if ($IncludeExternalGates) {
  Invoke-Npm "verify:external-gates" "verify:external-gates"
  try {
    $g = Get-Content (Join-Path $repoRoot "docs\runtime-state\external-gate-summary.json") -Raw | ConvertFrom-Json
    $gateStatus = "$($g.status)"; $gateProd = [bool]$g.production_deploy_claim_allowed
  } catch {}
}
$gatesOk = ($gateStatus -eq "verified" -and $gateProd)
Add-Result "external-gates-verified" $gatesOk "status=$gateStatus production_deploy_claim_allowed=$gateProd" $true $true

# --- 4) Urteil ---
$requiredFails = @($results | Where-Object { $_.required -and -not $_.ok })
$marketReady = ($requiredFails.Count -eq 0)

Write-Host ""
Write-Host "=== MATRIX ==="
$results | ForEach-Object {
  $s = if ($_.ok) { "PASS" } elseif (-not $_.required) { "SKIP" } else { "FAIL" }
  Write-Host ("  {0,-34} {1}" -f $_.step, $s)
}
Write-Host ""
if (-not $marketReady) {
  $ownerBlocked = @($requiredFails | Where-Object { $_.owner_gated -or $_.step -eq "external-gates-verified" })
  $auditSkipped = @(
    $requiredFails | Where-Object {
      $StaticOnly -and $_.step -eq "runtime-verifiers" -and $_.detail -match '^SKIPPED via -StaticOnly'
    }
  )
  $autonomousOpen = @(
    $requiredFails | Where-Object {
      -not ($_.owner_gated -or $_.step -eq "external-gates-verified") -and
      $_.step -notin @($auditSkipped | ForEach-Object { $_.step })
    }
  )
  if ($ownerBlocked.Count -gt 0) {
    Write-Host "OWNER-BLOCKED (Spur B - siehe docs/runtime-state/owner-input-manifest.json):"
    $ownerBlocked | ForEach-Object { Write-Host "  - $($_.step): $($_.detail)" }
  }
  if ($auditSkipped.Count -gt 0) {
    Write-Host "AUDIT-MODUS (kein Implementierungsdefizit):"
    $auditSkipped | ForEach-Object { Write-Host "  - $($_.step): $($_.detail)" }
  }
  Write-Host "OFFEN (Spur A - autonom fixbar):"
  if ($autonomousOpen.Count -eq 0) {
    Write-Host "  - keine"
  } else {
    $autonomousOpen | ForEach-Object { Write-Host "  - $($_.step): $($_.detail)" }
  }
}

$report = [pscustomobject]@{
  contract_version = "market-ready-aggregate-v1"
  generated_at     = (Get-Date).ToUniversalTime().ToString("o")
  static_only      = [bool]$StaticOnly
  included_external_gates = [bool]$IncludeExternalGates
  manifest_all_100 = $allHundred
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
  steps            = $results
  market_ready     = $marketReady
}
$report | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $artifactDir "report.json") -Encoding utf8

Write-Host ""
Write-Host ("MARKET_READY: {0}" -f ($marketReady.ToString().ToLower()))
if (-not $marketReady) { exit 1 }
exit 0
