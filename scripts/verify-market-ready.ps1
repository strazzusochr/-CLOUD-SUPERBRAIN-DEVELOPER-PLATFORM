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

function Invoke-Npm([string]$name, [string]$script, [bool]$required = $true) {
  Write-Host "[market-ready] running: npm run $script"
  & npm run $script 2>&1 | ForEach-Object { Write-Host "    $_" }
  $code = $LASTEXITCODE; if ($null -eq $code) { $code = 0 }
  Add-Result $name ($code -eq 0) "exit=$code" $required
}

Write-Host "=== MARKET-READY AGGREGATE GATE ==="

# --- 1) Statische Wahrheit (immer) ---
Write-Host "[market-ready] running: manifest integrity"
& py -3 (Join-Path $repoRoot "scripts\verify_project_progress_manifest.py") 2>&1 | ForEach-Object { Write-Host "    $_" }
$manifestOk = ($LASTEXITCODE -eq 0)
Add-Result "manifest-integrity" $manifestOk "verify_project_progress_manifest.py"

# Manifest-Zellen: jede horizontale + vertikale Zelle muss == 100 sein
$allHundred = $false; $cellDetail = "unreadable"
try {
  $m = Get-Content (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
  $cells = @(); $cells += $m.horizontal.items; $cells += $m.vertical.items
  $below = @($cells | Where-Object { [int]$_.percent -lt 100 })
  $allHundred = ($below.Count -eq 0)
  if ($allHundred) { $cellDetail = "all " + $cells.Count + " cells = 100" }
  else { $cellDetail = "below 100: " + (($below | ForEach-Object { "$($_.id)=$($_.percent)" }) -join ", ") }
} catch { $cellDetail = "parse error: $($_.Exception.Message)" }
Add-Result "manifest-all-100" $allHundred $cellDetail

# PROOF_LEDGER: der jeweils neueste append-only Status pro Item darf nicht OPEN sein.
$ledgerPath = Join-Path $repoRoot ".codex\runs\CURRENT\master-goal\PROOF_LEDGER.md"
$ledgerOk = $false; $ledgerDetail = "missing"
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
  $ledgerOk = ($openItems.Count -eq 0)
  $ledgerDetail = if ($ledgerOk) { "no latest OPEN status" } else { "latest OPEN: " + ($openItems -join ', ') }
}
Add-Result "proof-ledger-clean" $ledgerOk $ledgerDetail

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
  Invoke-Npm "verify:phase6-frontend"  "verify:phase6-frontend"
  Invoke-Npm "build(full-pages)"       "build"
  Invoke-Npm "verify:release-candidate" "verify:release-candidate"
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
  if ($ownerBlocked.Count -gt 0) {
    Write-Host "OWNER-BLOCKED (Spur B - siehe OWNER-INPUT-MANIFEST O1-O5):"
    $ownerBlocked | ForEach-Object { Write-Host "  - $($_.step): $($_.detail)" }
  }
  Write-Host "OFFEN (Spur A - autonom fixbar):"
  @($requiredFails | Where-Object { -not ($_.owner_gated -or $_.step -eq "external-gates-verified") }) |
    ForEach-Object { Write-Host "  - $($_.step): $($_.detail)" }
}

$report = [pscustomobject]@{
  contract_version = "market-ready-aggregate-v1"
  generated_at     = (Get-Date).ToUniversalTime().ToString("o")
  static_only      = [bool]$StaticOnly
  included_external_gates = [bool]$IncludeExternalGates
  manifest_all_100 = $allHundred
  manifest_cells   = $cellDetail
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
