param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$ReadOnly,
  [string]$OutDir = ".codex\runs\CURRENT\phase3\csrf-origin-guard"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) { if (-not $condition) { throw "Phase3 CSRF verification failed: $label" } }
function Assert-Contains($label, $value, $expected) { $text=($value|Out-String); if(-not $text.Contains($expected)){throw "Phase3 CSRF verification failed: $label missing '$expected'"} }
function Assert-NotContains($label, $value, $forbidden) { $text=($value|Out-String); if($text.Contains($forbidden)){throw "Phase3 CSRF verification failed: $label contained '$forbidden'"} }
function Invoke-Text($url) { return (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30).Content }

function Invoke-CurlProbe([string[]]$Headers) {
  $bodyFile = Join-Path $env:TEMP ("csrf-body-" + [guid]::NewGuid().ToString("N") + ".txt")
  $headerFile = Join-Path $env:TEMP ("csrf-headers-" + [guid]::NewGuid().ToString("N") + ".txt")
  try {
    $arguments = @("-sS", "-o", $bodyFile, "-D", $headerFile, "-w", "%{http_code}", "-X", "POST")
    foreach ($header in $Headers) { $arguments += @("-H", $header) }
    $arguments += "$BaseUrl/api/v1/security/csrf/probe"
    $previous = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    try { $status = (& curl.exe @arguments 2>&1 | Out-String).Trim() } finally { $ErrorActionPreference = $previous }
    if ($LASTEXITCODE -ne 0) { throw "curl probe failed: $status" }
    return [pscustomobject]@{ status=[int]$status; body=(Get-Content $bodyFile -Raw); headers=(Get-Content $headerFile -Raw) }
  } finally {
    if(Test-Path $bodyFile){Remove-Item -LiteralPath $bodyFile -Force}
    if(Test-Path $headerFile){Remove-Item -LiteralPath $headerFile -Force}
  }
}

$BaseUrl=$BaseUrl.TrimEnd("/")
$isLocalhost=$BaseUrl -match "^http://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(:|/|$)"
if($isLocalhost -and -not $AllowLocalhost){throw "Localhost verification requires -AllowLocalhost and remains DEV-ONLY"}
if((-not $isLocalhost) -and -not $ReadOnly){throw "Remote CSRF proof is read-only unless a separate hosted write gate is approved"}
$repoRoot=Split-Path -Parent $PSScriptRoot
$artifactDir=if([IO.Path]::IsPathRooted($OutDir)){$OutDir}else{Join-Path $repoRoot $OutDir}
New-Item -ItemType Directory -Path $artifactDir -Force|Out-Null

Write-Host "[phase3-csrf] contract and visible surface"
$contract=Invoke-Text "$BaseUrl/api/v1/security/csrf/contract"
foreach($required in @('"contract_version":"csrf-origin-guard-v1"','"evidence_ref":"csrf_origin_guard_visible"','"audit_evidence_ref":"csrf_origin_rejection_audited"','"rejection_status_code":403','"phase3_progress_after_proof":42','"cross_site_browser_requests_allowed":false','"null_origin_allowed":false','"raw_origin_persisted":false','"cookie_or_authorization_value_persisted":false')){Assert-Contains "contract" $contract $required}
$html=Invoke-Text "$BaseUrl/diagnostics"
Assert-Contains "diagnostics label" $html "CSRF Origin Guard"
Assert-Contains "diagnostics endpoint" $html "/api/v1/security/csrf/contract"
$apiSource=Get-Content (Join-Path $repoRoot "services\agent-api\app\main.py") -Raw
$nginxSource=Get-Content (Join-Path $repoRoot "infrastructure\nginx\dev.conf") -Raw
$frontendSource=Get-Content (Join-Path $repoRoot "apps\frontend\app\diagnostics\page.tsx") -Raw
$browserSource=Get-Content (Join-Path $repoRoot "apps\frontend\e2e\phase3-csrf-origin.spec.ts") -Raw
$docSource=Get-Content (Join-Path $repoRoot "docs\runtime-contracts\security-csrf-origin-guard.md") -Raw
foreach($required in @("csrf_origin_guard_middleware","persist_csrf_rejection_audit","security_csrf_request_rejected","_normalized_origin")){Assert-Contains "API source" $apiSource $required}
Assert-Contains "Nginx forwarded host" $nginxSource 'proxy_set_header X-Forwarded-Host $http_host;'
foreach($required in @("CSRF Origin Guard","/api/v1/security/csrf/contract")){Assert-Contains "frontend source" $frontendSource $required}
foreach($required in @("same-origin browser POST","PHASE3_CSRF_ARTIFACT_DIR","x-superbrain-csrf-contract")){Assert-Contains "browser source" $browserSource $required}
foreach($required in @("csrf-origin-guard-v1","csrf_origin_rejection_audited","Raw Origin values","DEV-ONLY")){Assert-Contains "contract doc" $docSource $required}
$manifest=Get-Content (Join-Path $repoRoot "docs\project-progress.manifest.json") -Raw|ConvertFrom-Json
$phase3=@($manifest.horizontal.items)|Where-Object id -eq "phase_3"|Select-Object -First 1
Assert-True "manifest phase3 at least 42" ([int]$phase3.percent -ge 42)
Assert-Contains "manifest CSRF marker" $phase3.status "csrf_origin_guard_visible"

if($ReadOnly){Write-Host "[phase3-csrf] status=verified_read_only"; exit 0}

Write-Host "[phase3-csrf] same-origin and non-browser compatibility"
$nonBrowser=Invoke-CurlProbe @()
Assert-True "non-browser accepted" ($nonBrowser.status -eq 200)
Assert-Contains "non-browser body" $nonBrowser.body '"status":"accepted_same_origin_or_non_browser"'
Assert-Contains "non-browser header" $nonBrowser.headers "x-superbrain-csrf-contract: csrf-origin-guard-v1"
$sameOrigin=Invoke-CurlProbe @("Origin: $BaseUrl","Sec-Fetch-Site: same-origin")
Assert-True "same-origin accepted" ($sameOrigin.status -eq 200)
Assert-Contains "same-origin body" $sameOrigin.body '"state_write":false'

Write-Host "[phase3-csrf] fail-closed negative paths"
$attacker="https://csrf-attacker.invalid"
$crossSite=Invoke-CurlProbe @("Origin: $attacker","Sec-Fetch-Site: cross-site")
Assert-True "cross-site rejected" ($crossSite.status -eq 403)
Assert-Contains "cross-site error" $crossSite.body '"error":"csrf_origin_rejected"'
Assert-Contains "cross-site reason" $crossSite.body '"reason":"fetch_metadata_cross_site"'
Assert-Contains "cross-site audited" $crossSite.body '"audit_persisted":true'
$mismatch=Invoke-CurlProbe @("Origin: $attacker","Sec-Fetch-Site: same-site")
Assert-True "origin mismatch rejected" ($mismatch.status -eq 403)
Assert-Contains "origin mismatch reason" $mismatch.body '"reason":"origin_mismatch"'
$nullOrigin=Invoke-CurlProbe @("Origin: null","Sec-Fetch-Site: same-site")
Assert-True "null origin rejected" ($nullOrigin.status -eq 403)
Assert-Contains "null origin reason" $nullOrigin.body '"reason":"invalid_or_null_origin"'
$audit=Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=100"
Assert-Contains "audit event" $audit "security_csrf_request_rejected"
Assert-Contains "audit evidence" $audit "csrf_origin_rejection_audited"
Assert-NotContains "raw attacker origin absent" $audit $attacker

Write-Host "[phase3-csrf] Chromium click and same-origin POST proof"
$oldBase=$env:PHASE3_CSRF_BASE_URL; $oldDir=$env:PHASE3_CSRF_ARTIFACT_DIR; $oldPhase6Base=$env:PHASE6_BASE_URL
try{
  $env:PHASE3_CSRF_BASE_URL=$BaseUrl; $env:PHASE3_CSRF_ARTIFACT_DIR=$artifactDir; $env:PHASE6_BASE_URL=$BaseUrl
  Push-Location (Join-Path $repoRoot "apps\frontend")
  try{npx playwright test e2e/phase3-csrf-origin.spec.ts --workers=1 --reporter=line; if($LASTEXITCODE -ne 0){throw "Playwright CSRF proof failed"}}finally{Pop-Location}
}finally{$env:PHASE3_CSRF_BASE_URL=$oldBase;$env:PHASE3_CSRF_ARTIFACT_DIR=$oldDir;$env:PHASE6_BASE_URL=$oldPhase6Base}
$screenshot=Join-Path $artifactDir "diagnostics-csrf-origin-guard.png"
Assert-True "screenshot exists" (Test-Path $screenshot)
$bytes=(Get-Item $screenshot).Length
Assert-True "screenshot nonblank" ($bytes -gt 25000)
@{contract_version="csrf-origin-guard-v1";status="verified";scope="DEV-ONLY";same_origin_browser_post=200;cross_site=403;origin_mismatch=403;null_origin=403;audit_persisted=$true;raw_origin_persisted=$false;provider_write=$false;production_deploy=$false;screenshot=@{path="diagnostics-csrf-origin-guard.png";bytes=$bytes};generated_at=(Get-Date).ToUniversalTime().ToString("o")}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $artifactDir "report.json") -Encoding utf8
Write-Host "[phase3-csrf] status=verified"
Write-Host "[phase3-csrf] screenshot_bytes=$bytes"
