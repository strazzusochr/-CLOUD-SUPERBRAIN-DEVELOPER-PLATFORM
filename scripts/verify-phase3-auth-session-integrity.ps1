param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$ReadOnly,
  [switch]$SkipBrowser,
  [string]$OutDir = ".codex\runs\CURRENT\phase3\auth-session-integrity"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) { if (-not $condition) { throw "Phase3 auth-session verification failed: $label" } }
function Assert-Contains($label, $value, $expected) { $text=($value|Out-String); if(-not $text.Contains($expected)){throw "Phase3 auth-session verification failed: $label missing '$expected'"} }
function Assert-NotContains($label, $value, $forbidden) { $text=($value|Out-String); if($text.Contains($forbidden)){throw "Phase3 auth-session verification failed: $label contained '$forbidden'"} }
function Invoke-Text($url) { return (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 30).Content }

$BaseUrl=$BaseUrl.TrimEnd("/")
$isLocalhost=$BaseUrl -match "^http://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(:|/|$)"
if($isLocalhost -and -not $AllowLocalhost){throw "Localhost verification requires -AllowLocalhost and remains DEV-ONLY"}
if((-not $isLocalhost) -and -not $ReadOnly){throw "Remote auth-session proof is read-only unless a separate hosted write gate is approved"}
$repoRoot=Split-Path -Parent $PSScriptRoot
$artifactDir=if([IO.Path]::IsPathRooted($OutDir)){$OutDir}else{Join-Path $repoRoot $OutDir}
New-Item -ItemType Directory -Path $artifactDir -Force|Out-Null

Write-Host "[phase3-auth-session] contract and source guards"
$contract=Invoke-Text "$BaseUrl/api/v1/auth/session/contract"
foreach($required in @('"contract_version":"auth-session-integrity-v1"','"evidence_ref":"auth_session_integrity_visible"','"algorithm":"HMAC-SHA256"','"constant_time_signature_check":true','"expiry_enforced":true','"tampered_cookie_rejected":true','"external_provider_write":false','"production_identity_claimed":false')){Assert-Contains "contract" $contract $required}
$helperSource=Get-Content (Join-Path $repoRoot "apps\frontend\lib\authSession.ts") -Raw
$routeSource=Get-Content (Join-Path $repoRoot "apps\frontend\app\api\v1\auth\session\route.ts") -Raw
$browserSource=Get-Content (Join-Path $repoRoot "apps\frontend\e2e\phase3-auth-session-integrity.spec.ts") -Raw
$docSource=Get-Content (Join-Path $repoRoot "docs\runtime-contracts\auth-session-integrity.md") -Raw
foreach($required in @("createHmac","timingSafeEqual","AUTH_SESSION_TTL_SECONDS","verifySignedAuthSession","ephemeral_process")){Assert-Contains "helper source" $helperSource $required}
foreach($required in @(
  "auth-session-integrity",
  "external_provider_write: false",
  "async function clearSessionCookie()",
  'jar.set(AUTH_SESSION_COOKIE, "", {',
  "httpOnly: true",
  "secure: true",
  'sameSite: "strict"',
  'path: "/"',
  "maxAge: 0",
  "expires: new Date(0)"
)){Assert-Contains "route source" $routeSource $required}
Assert-NotContains "route must not use attribute-incomplete cookie deletion" $routeSource "jar.delete(AUTH_SESSION_COOKIE)"
Assert-NotContains "route has no GitHub store" $routeSource "ghStore"
foreach($required in @("tampered cookie","session_invalidated","external_provider_write","login-auth-session-integrity.png")){Assert-Contains "browser source" $browserSource $required}
foreach($required in @("auth-session-integrity-v1","HMAC-SHA256","AUTH_SESSION_SECRET","DEV-ONLY")){Assert-Contains "contract doc" $docSource $required}

Write-Host "[phase3-auth-session] deterministic token unit tests"
Push-Location (Join-Path $repoRoot "apps\frontend")
try { node --test tests/auth-session-integrity.test.mjs; if($LASTEXITCODE -ne 0){throw "auth-session unit tests failed"} } finally { Pop-Location }

if($ReadOnly){Write-Host "[phase3-auth-session] status=verified_read_only";exit 0}

Write-Host "[phase3-auth-session] issue, verify, tamper, and provider rejection"
$httpProbe = node (Join-Path $repoRoot "scripts\verify-auth-session-http.mjs") --base-url $BaseUrl
if($LASTEXITCODE -ne 0){throw "auth-session HTTP probes failed"}
foreach($required in @('"status":"verified"','"valid_cookie_accepted":true','"tampered_cookie_rejected":true','"invalid_cookie_clear_header":true','"unsupported_provider_rejected":true','"logout_cookie_cleared":true','"external_provider_write":false','"token_output":false')){Assert-Contains "HTTP probe" $httpProbe $required}

if(-not $SkipBrowser){
  Write-Host "[phase3-auth-session] Chromium login and tamper proof"
  $oldBase=$env:PHASE3_AUTH_SESSION_BASE_URL;$oldDir=$env:PHASE3_AUTH_SESSION_ARTIFACT_DIR;$oldPhase6Base=$env:PHASE6_BASE_URL
  try{
    $env:PHASE3_AUTH_SESSION_BASE_URL=$BaseUrl;$env:PHASE3_AUTH_SESSION_ARTIFACT_DIR=$artifactDir;$env:PHASE6_BASE_URL=$BaseUrl
    Push-Location (Join-Path $repoRoot "apps\frontend")
    try{npx playwright test e2e/phase3-auth-session-integrity.spec.ts --workers=1 --reporter=line;if($LASTEXITCODE -ne 0){throw "Playwright auth-session proof failed"}}finally{Pop-Location}
  }finally{$env:PHASE3_AUTH_SESSION_BASE_URL=$oldBase;$env:PHASE3_AUTH_SESSION_ARTIFACT_DIR=$oldDir;$env:PHASE6_BASE_URL=$oldPhase6Base}
  $screenshot=Join-Path $artifactDir "login-auth-session-integrity.png"
  Assert-True "screenshot exists" (Test-Path $screenshot)
  $bytes=(Get-Item $screenshot).Length
  Assert-True "screenshot nonblank" ($bytes -gt 25000)
}else{$bytes=0}

$reportName=if($SkipBrowser){"report-runtime.json"}else{"report.json"}
@{contract_version="auth-session-integrity-v1";status="verified";scope="DEV-ONLY";browser_click_verified=(-not $SkipBrowser);valid_cookie_accepted=$true;tampered_cookie_rejected=$true;expiry_unit_verified=$true;unsupported_provider_rejected=$true;external_provider_write=$false;production_identity_claimed=$false;screenshot=@{path="login-auth-session-integrity.png";bytes=$bytes};generated_at=(Get-Date).ToUniversalTime().ToString("o")}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $artifactDir $reportName) -Encoding utf8
Write-Host "[phase3-auth-session] status=verified browser_click_verified=$(-not $SkipBrowser)"
