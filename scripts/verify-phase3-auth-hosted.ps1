param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase3 hosted auth verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase3 hosted auth verification failed: $label"
  }
}

function Invoke-JsonApi(
  [string]$Url,
  [string]$Method = "GET",
  [string]$Body = "",
  [string]$ContentType = "application/json",
  [int]$TimeoutSeconds = 15
) {
  $payload = [ordered]@{
    url = $Url
    method = $Method
    timeout_seconds = $TimeoutSeconds
  }
  if ($Body) {
    $payload.body_b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Body))
  }
  if ($ContentType) {
    $payload.content_type = $ContentType
  }
  $payloadJson = $payload | ConvertTo-Json -Compress -Depth 6
  $payloadFile = Join-Path $env:TEMP ("phase3-hosted-auth-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("phase3-hosted-auth-" + [Guid]::NewGuid().ToString("N") + ".py")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payloadJson -NoNewline -Encoding utf8
    $pythonScript = @'
import base64
import json
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8-sig") as handle:
    payload = json.load(handle)

data = None
if payload.get("body_b64"):
    data = base64.b64decode(payload["body_b64"])

headers = {}
if payload.get("content_type"):
    headers["Content-Type"] = payload["content_type"]

request = urllib.request.Request(
    payload["url"],
    data=data,
    headers=headers,
    method=payload.get("method", "GET"),
)

try:
    with urllib.request.urlopen(request, timeout=payload.get("timeout_seconds", 15)) as response:
        body = response.read().decode("utf-8")
        print(body)
except urllib.error.HTTPError as exc:
    print(exc.read().decode("utf-8"))
    sys.exit(exc.code)
'@
    Set-Content -LiteralPath $pythonFile -Value $pythonScript -NoNewline -Encoding utf8
    $output = py -3 $pythonFile $payloadFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw $output.Trim()
    }
    return $output
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
    if (Test-Path $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
  }
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase3 hosted auth proof requires HTTPS"
}

Write-Host "[phase3-hosted-auth] base url: $BaseUrl"

$frontendHtml = Invoke-JsonApi -Url "$BaseUrl/"
Assert-Contains "frontend auth panel" $frontendHtml "Auth Contract"
Assert-Contains "frontend fallback panel" $frontendHtml "System Unavailable Fallback"

$authContract = Invoke-JsonApi -Url "$BaseUrl/api/v1/auth/contract"
Assert-Contains "auth contract version" $authContract '"contract_version":"auth-github-jwt-refresh-v1"'
Assert-Contains "auth contract no live oauth" $authContract '"live_github_oauth_call":false'
Assert-Contains "auth contract access ttl" $authContract '"access_token_ttl_seconds":900'
Assert-Contains "auth contract refresh ttl" $authContract '"ttl_seconds":604800'
Assert-Contains "auth contract rotation" $authContract '"rotation_required":true'
Assert-Contains "auth contract redis blacklist" $authContract '"blacklist_store":"redis"'
Assert-Contains "auth contract same site" $authContract '"SameSite":"Strict"'

$authGithub = Invoke-JsonApi -Url "$BaseUrl/api/v1/auth/github"
Assert-Contains "auth github contract version" $authGithub '"contract_version":"auth-github-jwt-refresh-v1"'
Assert-Contains "auth github no live oauth" $authGithub '"live_github_oauth_call":false'
Assert-Contains "auth github authorize url" $authGithub "github.com/login/oauth/authorize"

$authCallback = Invoke-JsonApi -Url "$BaseUrl/api/v1/auth/callback?code=hosted-auth-code&state=hosted-auth-state" -Method "GET" -ContentType ""
Assert-Contains "auth callback authenticated" $authCallback '"status":"authenticated"'
Assert-Contains "auth callback no live oauth" $authCallback '"live_github_oauth_call":false'
Assert-Contains "auth callback same site strict" $authCallback '"SameSite":"Strict"'

$authRefreshToken = "hosted-refresh-token-" + [Guid]::NewGuid().ToString("N")
$authRefreshBody = @{ refresh_token = $authRefreshToken; trace_id = "hosted-auth-refresh-rotated" } | ConvertTo-Json -Compress
$authRefresh = Invoke-JsonApi -Url "$BaseUrl/api/v1/auth/refresh" -Method "POST" -Body $authRefreshBody -ContentType "application/json"
Assert-Contains "auth refresh rotated" $authRefresh '"status":"rotated"'
Assert-Contains "auth refresh rotated flag" $authRefresh '"refresh_token_rotated":true'
Assert-Contains "auth refresh blacklist flag" $authRefresh '"old_refresh_token_blacklisted":true'

$authReuseOutput = ""
$authReuseFailed = $false
try {
  $authReuseOutput = Invoke-JsonApi -Url "$BaseUrl/api/v1/auth/refresh" -Method "POST" -Body $authRefreshBody -ContentType "application/json"
} catch {
  $authReuseFailed = $true
  $authReuseOutput = $_.Exception.Message
}
Assert-True "auth refresh reuse blocked with non-2xx" $authReuseFailed
Assert-Contains "auth refresh reuse blocked" $authReuseOutput "refresh_token_invalid"

$authLogoutBody = @{ refresh_token = ("hosted-logout-token-" + [Guid]::NewGuid().ToString("N")); trace_id = "hosted-auth-logout-revoked" } | ConvertTo-Json -Compress
$authLogout = Invoke-JsonApi -Url "$BaseUrl/api/v1/auth/logout" -Method "POST" -Body $authLogoutBody -ContentType "application/json"
Assert-Contains "auth logout status" $authLogout '"status":"logged_out"'
Assert-Contains "auth logout revoked" $authLogout '"refresh_token_revoked":true'

$authAudit = Invoke-JsonApi -Url "$BaseUrl/api/v1/audit/recent?limit=60"
Assert-Contains "auth audit refresh rotated" $authAudit "auth_refresh_rotated"
Assert-Contains "auth audit refresh reuse blocked" $authAudit "auth_refresh_reuse_blocked"
Assert-Contains "auth audit logout revoked" $authAudit "auth_logout_revoked"

$systemFallbackContract = Invoke-JsonApi -Url "$BaseUrl/api/v1/system/fallback/contract"
Assert-Contains "system fallback version" $systemFallbackContract '"contract_version":"system-unavailable-fallback-v1"'
Assert-Contains "system fallback ui state" $systemFallbackContract '"ui_state":"System Unavailable"'
Assert-Contains "system fallback no fake healthy policy" $systemFallbackContract "no_fake_healthy_claim"

Write-Host "[phase3-hosted-auth] checks completed"
