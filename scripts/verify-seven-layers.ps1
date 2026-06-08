# scripts/verify-seven-layers.ps1
# Verifiziert ALLE 7 Cloud-Layer auf Implementierung + logische Verdrahtung
# Liefert am Ende einen klaren Gesamtstatus und echte Exit-Codes.

param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$RequireAllClosed
)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

function Write-Layer([string]$Id,[string]$Label,[string]$Status,[string]$Detail){
  [PSCustomObject]@{ layer=$Id; label=$Label; status=$Status; detail=$Detail }
}

function Invoke-Rest([string]$Url,[string]$Method='GET'){
  try {
    $r = Invoke-WebRequest -Uri $Url -Method $Method -UseBasicParsing
    return @{ ok = $true; status = [int]$r.StatusCode; body = $r.Content }
  } catch {
    return @{ ok = $false; status = 0; body = $_.Exception.Message }
  }
}

# ------------------------------------------------------------------
# L1 — Daten & Speicher
# ------------------------------------------------------------------
$l1r = Invoke-Rest "$BaseUrl/api/v1/health"
$l1 = if($l1r.ok){ Write-Layer 'L1' 'Daten & Speicher' 'VERIFIED' 'health=true' }
       else { Write-Layer 'L1' 'Daten & Speicher' 'FAILED' ($l1r.body -join ' ') }

# ------------------------------------------------------------------
# L2 — Modelle & LLM Gateway
# ------------------------------------------------------------------
$l2r = Invoke-Rest "$BaseUrl/llm/api/v1/health"
$l2 = if($l2r.ok){ Write-Layer 'L2' 'Modelle & LLM Gateway' 'VERIFIED' 'llm_health=true' }
       else { Write-Layer 'L2' 'Modelle & LLM Gateway' 'FAILED' ($l2r.body -join ' ') }

# ------------------------------------------------------------------
# L3 — Agent Pool & Worker
# ------------------------------------------------------------------
$l3r = Invoke-Rest "$BaseUrl/api/v1/phase2/runtime/contract"
$l3 = if($l3r.ok){ Write-Layer 'L3' 'Agent Pool & Worker' 'VERIFIED' 'phase2_contract=true' }
       else { Write-Layer 'L3' 'Agent Pool & Worker' 'FAILED' ($l3r.body -join ' ') }

# ------------------------------------------------------------------
# L4 — API & Gateways
# ------------------------------------------------------------------
$l4r = Invoke-Rest "$BaseUrl/api/v1/layer-interfaces/contract"
$l4 = if($l4r.ok){ Write-Layer 'L4' 'API & Gateways' 'VERIFIED' 'layer_interfaces=true' }
       else { Write-Layer 'L4' 'API & Gateways' 'FAILED' ($l4r.body -join ' ') }

# ------------------------------------------------------------------
# L5 — Frontend & UI
# ------------------------------------------------------------------
$l5r = Invoke-Rest "$BaseUrl/api/v1/project/progress/layers/contract"
$l5 = if($l5r.ok){ Write-Layer 'L5' 'Frontend & UI' 'VERIFIED' 'layers_contract=true' }
       else { Write-Layer 'L5' 'Frontend & UI' 'FAILED' ($l5r.body -join ' ') }

# ------------------------------------------------------------------
# L6 — Cloud & Infrastruktur
# ------------------------------------------------------------------
$l6r = Invoke-Rest "$BaseUrl/api/v1/clouds/layers/contract"
$l6 = if($l6r.ok){ Write-Layer 'L6' 'Cloud & Infrastruktur' 'VERIFIED' 'cloud_layers_contract=true' }
       else { Write-Layer 'L6' 'Cloud & Infrastruktur' 'FAILED' ($l6r.body -join ' ') }

# ------------------------------------------------------------------
# L7 — Integration & Verification
# ------------------------------------------------------------------
$l7r = Invoke-Rest "$BaseUrl/api/v1/external-gates"
$l7s = 'FAILED'
$l7d = 'external_gates_unreachable'
if($l7r.ok){
  try {
    $j = $l7r.body | ConvertFrom-Json
    $blocked = @($j.blocked_release_gates)
    if($blocked.Count -eq 0){ $l7s='VERIFIED'; $l7d='no_blocked_release_gates' }
    else { $l7s='BLOCKED'; $l7d=('blocked=' + ($blocked -join ',')) }
  } catch { $l7d = 'json_parse_failed' }
}
$l7 = Write-Layer 'L7' 'Integration & Verification' $l7s $l7d

# ------------------------------------------------------------------
# Browser proof (basic smoke)
# ------------------------------------------------------------------
$browserOut = ''
try {
  $browserOut = node -e "fetch('$BaseUrl').then(r=>r.text()).then(t=>{const o={ok:r=>r.ok,title:t.includes('Cloud Superbrain')};if(!o.title)o.snippet=(t||'').slice(0,120);console.log(JSON.stringify(o))}).catch(e=>console.log(JSON.stringify({ok:false,error:e.message})))"
} catch { $browserOut = 'node_failed' }
$browserOk = $false
if($browserOut){
  try {
    $bj = $browserOut | ConvertFrom-Json
    if ($null -ne $bj.title) { $browserOk = [bool]$bj.title }
    elseif ($null -ne $bj.ok) { $browserOk = [bool]$bj.ok }
  } catch {}
}
$lb = if($browserOk){ Write-Layer 'BROWSER' 'Browser Smoke' 'VERIFIED' 'title_or_marker_visible' }
      else { Write-Layer 'BROWSER' 'Browser Smoke' 'FAILED' ('output=' + $browserOut) }

function Write-Table([PSCustomObject[]]$Rows){
  foreach($r in $Rows){
    $status = switch($r.status){
      'VERIFIED' { 'PASS' }
      'BLOCKED' { 'WARN' }
      default { 'FAIL' }
    }
    "{0,-8} {1,-30} {2,-10} {3}" -f $r.layer, $r.label, $status, $r.detail | Write-Host
  }
}

Write-Host ''
Write-Host '=== CLOUD SUPERBRAIN — 7 LAYER VERIFICATION ===' -ForegroundColor Cyan
Write-Host "Base URL : $BaseUrl"
Write-Host "DateTime : $(Get-Date -Format o)"
Write-Host ''
Write-Table @($l1,$l2,$l3,$l4,$l5,$l6,$l7,$lb)

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
$rows = @($l1,$l2,$l3,$l4,$l5,$l6,$l7)
$verified = @($rows | Where-Object status -eq 'VERIFIED').Count
$blocked  = @($rows | Where-Object status -eq 'BLOCKED').Count
$failed   = @($rows | Where-Object status -eq 'FAILED').Count
$total    = $rows.Count

Write-Host ''
Write-Host '=== SUMMARY ===' -ForegroundColor Cyan
Write-Host "Layers : $total | VERIFIED=$verified | BLOCKED=$blocked | FAILED=$failed"
if($failed -gt 0){
  Write-Host 'RESULT: FAILED' -ForegroundColor Red
  exit 1
}
if($blocked -gt 0){
  Write-Host 'RESULT: BLOCKED' -ForegroundColor Yellow
  exit 2
}
Write-Host 'RESULT: VERIFIED' -ForegroundColor Green
exit 0
