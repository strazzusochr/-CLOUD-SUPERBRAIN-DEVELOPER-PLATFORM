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
$ownerUncoveredCellIds = @($below | ForEach-Object { [string]$_.id })
try {
  if (Test-Path $ownerInputPath) {
    $ownerInput = Get-Content $ownerInputPath -Raw | ConvertFrom-Json
    $allCellIds = @($cells | ForEach-Object { [string]$_.id })
    $belowCellIds = @($below | ForEach-Object { [string]$_.id })
    $actions = @($ownerInput.actions)
    $autonomousOpenItems = @($ownerInput.autonomous_open_items | ForEach-Object { [string]$_ })
    $autonomousOpenItemsOk = ($autonomousOpenItems.Count -eq 0)
    $autonomousOpenItemsDetail = if ($autonomousOpenItemsOk) {
      "none; local Cloudflare-native adapter and truth candidate are verified"
    } else {
      "open: " + ($autonomousOpenItems -join ", ")
    }
    $invalidActions = @(
      $actions | Where-Object {
        [string]$_.id -notmatch '^O\d+$' -or
        [string]$_.status -ne 'owner_required' -or
        [string]::IsNullOrWhiteSpace([string]$_.required_owner_action) -or
        @($_.affected_cells).Count -eq 0 -or
        @($_.verifier_after).Count -eq 0
      }
    )
    $coveredIds = @(
      $actions |
        ForEach-Object { @($_.affected_cells) } |
        ForEach-Object { [string]$_ } |
        Sort-Object -Unique
    )
    $unknownIds = @($coveredIds | Where-Object { $_ -notin $allCellIds })
    $ownerBlockedCellIds = @($belowCellIds | Where-Object { $_ -in $coveredIds })
    $ownerUncoveredCellIds = @($belowCellIds | Where-Object { $_ -notin $coveredIds })
    $expectedActionCells = @{
      O1 = @("phase_3")
      O2 = @("phase_5", "phase_6")
      O3 = @("layer_5", "phase_5")
      O4 = @("layer_3", "layer_5", "phase_6")
      O5 = @("layer_6")
      O6 = @("layer_4")
    }
    $actionIds = @($actions | ForEach-Object { [string]$_.id } | Sort-Object)
    $actionMapOk = (($actionIds -join ",") -eq (($expectedActionCells.Keys | Sort-Object) -join ","))
    foreach ($action in $actions) {
      $actionId = [string]$action.id
      $actualAffected = @($action.affected_cells | ForEach-Object { [string]$_ } | Sort-Object)
      $expectedAffected = @($expectedActionCells[$actionId] | Sort-Object)
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
      "cloudflare_native_zero_card_hosted_runtime",
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
      [bool]$cloudflareTargetGate.local_candidate_verified -eq $true -and
      [bool]$cloudflareTargetGate.zero_card_verified -eq $false -and
      [bool]$cloudflareTargetGate.r2_enabled -eq $false -and
      [bool]$cloudflareTargetGate.live_verified -eq $false -and
      [bool]$cloudflareTargetGate.paid_provider -eq $false
    )
    $externalGateStateOk = (
      [string]$externalState.status -eq "blocked" -and
      [bool]$externalState.production_deploy_claim_allowed -eq $false -and
      @($externalState.missing_or_failed_gates) -contains "fly_live_budget_check" -and
      [string]$ownerInput.external_gate_truth.active_target_gate -eq "cloudflare_native_zero_card_hosted_runtime" -and
      @($ownerInput.external_gate_truth.missing_or_failed_gates) -contains "cloudflare_native_zero_card_hosted_runtime" -and
      [string]$ownerInput.external_gate_truth.legacy_fly_path_status -eq "superseded_historical" -and
      [bool]$ownerInput.external_gate_truth.production_deploy_claim_allowed -eq $false -and
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
    $llmResponseVerifier = Get-Content (Join-Path $repoRoot "scripts\verify-llm-responses-contract.ps1") -Raw
    $llmDryRunLockOk = (
      $llmResponseVerifier.Contains('Assert-True "contract live provider calls false"') -and
      $llmResponseVerifier.Contains('Assert-True "response live provider calls false"') -and
      $llmResponseVerifier.Contains('Assert-True "hosted response no live provider"')
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
      $llmDryRunLockOk -and
      $sourceMatches
    )
    $ownerMatrixDetail = if ($ownerMatrixOk) {
      "covered below-100 cells: " + ($ownerBlockedCellIds -join ", ")
    } else {
      "invalid_actions=$($invalidActions.Count) autonomous_open=$($autonomousOpenItems.Count) unknown_cells=$($unknownIds -join ',') uncovered_cells=$($ownerUncoveredCellIds -join ',') action_map=$actionMapOk unknown_gates=$($unknownGateIds -join ',') closed_gates=$closedGateStateOk external_gate=$externalGateStateOk cloudflare_target=$cloudflareTargetGateOk o2_zero_card=$o2ZeroCardOk llm_dry_run_lock=$llmDryRunLockOk source_matches=$sourceMatches"
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
  owner_blocked_cells = $ownerBlockedCellIds
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
