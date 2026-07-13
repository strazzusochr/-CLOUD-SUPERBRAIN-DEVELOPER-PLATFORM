param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$ReadOnly,
  [string]$OutDir = ".codex\runs\CURRENT\phase3\cross-origin-response-guard"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) { throw "Phase3 cross-origin verification failed: $label" }
}
function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) { throw "Phase3 cross-origin verification failed: $label missing '$expected'" }
}
function Assert-NotContains($label, $value, $forbidden) {
  $text = ($value | Out-String)
  if ($text.Contains($forbidden)) { throw "Phase3 cross-origin verification failed: $label contained '$forbidden'" }
}
function Invoke-Text($url) {
  return (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30).Content
}
function Invoke-HeaderProbe([string]$Path, [string[]]$Headers = @()) {
  $bodyFile = Join-Path $env:TEMP ("cross-origin-body-" + [guid]::NewGuid().ToString("N") + ".txt")
  $headerFile = Join-Path $env:TEMP ("cross-origin-headers-" + [guid]::NewGuid().ToString("N") + ".txt")
  try {
    $arguments = @("-sS", "-o", $bodyFile, "-D", $headerFile, "-w", "%{http_code}")
    foreach ($header in $Headers) { $arguments += @("-H", $header) }
    $arguments += "$BaseUrl$Path"
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { $status = (& curl.exe @arguments 2>&1 | Out-String).Trim() } finally { $ErrorActionPreference = $previous }
    if ($LASTEXITCODE -ne 0) { throw "curl probe failed: $status" }
    return [pscustomobject]@{
      status = [int]$status
      body = (Get-Content $bodyFile -Raw)
      headers = (Get-Content $headerFile -Raw)
    }
  } finally {
    if (Test-Path $bodyFile) { Remove-Item -LiteralPath $bodyFile -Force }
    if (Test-Path $headerFile) { Remove-Item -LiteralPath $headerFile -Force }
  }
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$isLocalhost = $BaseUrl -match "^http://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(:|/|$)"
if ($isLocalhost -and -not $AllowLocalhost) { throw "Localhost verification requires -AllowLocalhost and remains DEV-ONLY" }
if ((-not $isLocalhost) -and -not $ReadOnly) { throw "Remote cross-origin proof is read-only without a hosted write gate" }
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactDir = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

Write-Host "[phase3-cross-origin] contract and source guards"
$contract = Invoke-Text "$BaseUrl/api/v1/security/cross-origin/contract"
foreach ($required in @(
  '"contract_version":"cross-origin-response-guard-v1"',
  '"evidence_ref":"cross_origin_response_guard_visible"',
  '"Cross-Origin-Opener-Policy":"same-origin"',
  '"Cross-Origin-Resource-Policy":"same-origin"',
  '"attacker_origin_reflected":false',
  '"credentials_allowed_cross_origin":false',
  '"phase3_progress_after_proof":43',
  '"provider_write":false',
  '"production_deploy":false'
)) { Assert-Contains "contract" $contract $required }
$html = Invoke-Text "$BaseUrl/diagnostics"
Assert-Contains "diagnostics label" $html "Cross-Origin Response Guard"
Assert-Contains "diagnostics endpoint" $html "/api/v1/security/cross-origin/contract"
$apiSource = Get-Content (Join-Path $repoRoot "services\agent-api\app\main.py") -Raw
$frontendSource = Get-Content (Join-Path $repoRoot "apps\frontend\app\diagnostics\page.tsx") -Raw
$browserSource = Get-Content (Join-Path $repoRoot "apps\frontend\e2e\phase3-cross-origin-response.spec.ts") -Raw
$docSource = Get-Content (Join-Path $repoRoot "docs\runtime-contracts\security-cross-origin-response-guard.md") -Raw
foreach ($required in @("CROSS_ORIGIN_RESPONSE_CONTRACT_VERSION", "cross_origin_response_contract_payload", "Cross-Origin-Resource-Policy")) { Assert-Contains "API source" $apiSource $required }
foreach ($required in @("Cross-Origin Response Guard", "/api/v1/security/cross-origin/contract")) { Assert-Contains "frontend source" $frontendSource $required }
foreach ($required in @("real click", "PHASE3_CROSS_ORIGIN_ARTIFACT_DIR", "cross-origin-opener-policy")) { Assert-Contains "browser source" $browserSource $required }
foreach ($required in @("cross-origin-response-guard-v1", "reflected attacker origins", "DEV-ONLY")) { Assert-Contains "contract doc" $docSource $required }
$manifest = Get-Content (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw | ConvertFrom-Json
$phase3 = @($manifest.horizontal.items) | Where-Object id -eq "phase_3" | Select-Object -First 1
Assert-True "manifest phase3 43" ([int]$phase3.percent -eq 43)
Assert-Contains "manifest cross-origin marker" $phase3.status "cross_origin_response_guard_visible"

if ($ReadOnly) { Write-Host "[phase3-cross-origin] status=verified_read_only"; exit 0 }

Write-Host "[phase3-cross-origin] response and negative-origin probes"
$health = Invoke-HeaderProbe "/api/v1/health"
Assert-True "health status" ($health.status -eq 200)
Assert-Contains "health COOP" $health.headers "cross-origin-opener-policy: same-origin"
Assert-Contains "health CORP" $health.headers "cross-origin-resource-policy: same-origin"
Assert-Contains "health cross-domain" $health.headers "x-permitted-cross-domain-policies: none"
$notFound = Invoke-HeaderProbe "/api/v1/security/cross-origin/not-found"
Assert-True "not-found status" ($notFound.status -eq 404)
Assert-Contains "not-found COOP" $notFound.headers "cross-origin-opener-policy: same-origin"
Assert-Contains "not-found CORP" $notFound.headers "cross-origin-resource-policy: same-origin"
$attackerOrigin = "https://cross-origin-attacker.invalid"
$attacker = Invoke-HeaderProbe "/api/v1/health" @("Origin: $attackerOrigin")
Assert-True "attacker request remains non-mutating" ($attacker.status -eq 200)
Assert-NotContains "attacker origin not reflected" $attacker.headers "access-control-allow-origin:"
Assert-NotContains "attacker credentials not enabled" $attacker.headers "access-control-allow-credentials:"

Write-Host "[phase3-cross-origin] Chromium click proof"
$oldBase = $env:PHASE3_CROSS_ORIGIN_BASE_URL
$oldDir = $env:PHASE3_CROSS_ORIGIN_ARTIFACT_DIR
$oldPhase6Base = $env:PHASE6_BASE_URL
try {
  $env:PHASE3_CROSS_ORIGIN_BASE_URL = $BaseUrl
  $env:PHASE3_CROSS_ORIGIN_ARTIFACT_DIR = $artifactDir
  $env:PHASE6_BASE_URL = $BaseUrl
  Push-Location (Join-Path $repoRoot "apps\frontend")
  try {
    npx playwright test e2e/phase3-cross-origin-response.spec.ts --workers=1 --reporter=line
    if ($LASTEXITCODE -ne 0) { throw "Playwright cross-origin proof failed" }
  } finally { Pop-Location }
} finally {
  $env:PHASE3_CROSS_ORIGIN_BASE_URL = $oldBase
  $env:PHASE3_CROSS_ORIGIN_ARTIFACT_DIR = $oldDir
  $env:PHASE6_BASE_URL = $oldPhase6Base
}
$screenshot = Join-Path $artifactDir "diagnostics-cross-origin-response-guard.png"
Assert-True "screenshot exists" (Test-Path $screenshot)
$bytes = (Get-Item $screenshot).Length
Assert-True "screenshot nonblank" ($bytes -gt 25000)
[ordered]@{
  contract_version = "cross-origin-response-guard-v1"
  status = "verified"
  scope = "DEV-ONLY"
  health_status = $health.status
  error_status = $notFound.status
  attacker_origin_reflected = $false
  credentials_allowed_cross_origin = $false
  provider_write = $false
  production_deploy = $false
  screenshot = @{ path = "diagnostics-cross-origin-response-guard.png"; bytes = $bytes }
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $artifactDir "report.json") -Encoding utf8
Write-Host "[phase3-cross-origin] status=verified"
Write-Host "[phase3-cross-origin] screenshot_bytes=$bytes"
