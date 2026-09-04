param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$ReadOnly,
  [string]$OutDir = ".codex\runs\CURRENT\phase3\csp-report-contract"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase3 CSP report verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-NotContains($label, $value, $forbidden) {
  $text = ($value | Out-String)
  if ($text.Contains($forbidden)) {
    throw "Phase3 CSP report verification failed: $label contained forbidden '$forbidden'."
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase3 CSP report verification failed: $label"
  }
}

function Invoke-WebResponse(
  [string]$Url,
  [string]$Method = "GET",
  [string]$Body = "",
  [hashtable]$Headers = $null,
  [string]$ContentType = "",
  [int]$TimeoutSeconds = 30
) {
  $payload = [ordered]@{
    url = $Url
    method = $Method
    timeout_seconds = $TimeoutSeconds
    headers = $Headers
  }
  if ($Body) {
    $payload.body_b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Body))
  }
  if ($ContentType) {
    $payload.content_type = $ContentType
  }
  $payloadFile = Join-Path $env:TEMP ("phase3-csp-report-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("phase3-csp-report-" + [Guid]::NewGuid().ToString("N") + ".py")
  try {
    Set-Content -LiteralPath $payloadFile -Value ($payload | ConvertTo-Json -Compress -Depth 6) -NoNewline -Encoding utf8
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

headers = payload.get("headers") or {}
if payload.get("content_type"):
    headers["Content-Type"] = payload["content_type"]

request = urllib.request.Request(payload["url"], data=data, headers=headers, method=payload.get("method", "GET"))
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeout_seconds", 30)) as response:
        body = response.read().decode("utf-8", errors="replace")
        print(json.dumps({"status_code": response.getcode(), "body": body, "headers": dict(response.headers.items())}))
except urllib.error.HTTPError as exc:
    print(json.dumps({"status_code": exc.code, "body": exc.read().decode("utf-8", errors="replace"), "headers": dict(exc.headers.items())}))
'@
    Set-Content -LiteralPath $pythonFile -Value $pythonScript -NoNewline -Encoding utf8
    $raw = py -3 $pythonFile $payloadFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw $raw.Trim()
    }
    return ($raw | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
    if (Test-Path -LiteralPath $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
  }
}

function Invoke-Text($url) {
  return (Invoke-WebResponse -Url $url -Method "GET").body
}

function Invoke-HeadersText($url) {
  $response = Invoke-WebResponse -Url $url -Method "GET"
  $lines = @()
  foreach ($header in $response.headers.PSObject.Properties) {
    $value = $header.Value
    if ($value -is [System.Array]) {
      $value = $value -join ", "
    }
    $lines += ("{0}: {1}" -f $header.Name.ToLowerInvariant(), $value)
  }
  return ($lines -join "`n")
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$isLocalProof = $BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]"
if ((-not $AllowLocalhost) -and $isLocalProof) {
  throw "Phase3 CSP report proof refuses localhost unless -AllowLocalhost is set"
}
if ((-not $ReadOnly) -and (-not $isLocalProof)) {
  throw "Phase3 CSP report write proof is DEV-ONLY; use -ReadOnly for non-local targets"
}
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactDir = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

Write-Host "[phase3-csp-report] base url: $BaseUrl"
Write-Host "[phase3-csp-report] contract and UI"

$frontendHtml = Invoke-Text "$BaseUrl/diagnostics"
Assert-Contains "diagnostics csp report option" $frontendHtml "CSP Report Contract"
Assert-Contains "diagnostics csp report endpoint" $frontendHtml "/api/v1/security/csp/contract"

$securityHeadersContract = Invoke-Text "$BaseUrl/api/v1/security/headers/contract"
Assert-Contains "security headers contract version" $securityHeadersContract '"contract_version":"security-headers-v1"'
Assert-Contains "security csp report contract version" $securityHeadersContract "csp-report-contract-v1"
Assert-Contains "security csp report evidence" $securityHeadersContract "csp_report_contract_visible"

$headers = Invoke-HeadersText "$BaseUrl/api/v1/health"
Assert-Contains "csp header present" $headers "content-security-policy:"
Assert-Contains "csp report-uri present" $headers "report-uri /api/v1/security/csp/report"
Assert-Contains "security contract header" $headers "x-superbrain-security-contract: security-headers-v1"

$contract = Invoke-Text "$BaseUrl/api/v1/security/csp/contract"
Assert-Contains "csp contract version" $contract '"contract_version":"csp-report-contract-v1"'
Assert-Contains "csp contract endpoint" $contract "POST /api/v1/security/csp/report"
Assert-Contains "csp contract evidence" $contract "csp_report_contract_visible"
Assert-Contains "csp contract audit evidence" $contract "csp_report_audit_persisted"
Assert-Contains "csp contract body limit" $contract '"max_body_bytes":16384'
Assert-Contains "csp report content type" $contract "application/csp-report"
Assert-Contains "csp report json content type" $contract "application/json"
Assert-Contains "csp no raw persistence" $contract '"raw_report_persisted":false'
Assert-Contains "csp no user agent persistence" $contract '"user_agent_persisted":false'
Assert-Contains "csp no credential persistence" $contract '"cookies_or_credentials_persisted":false'
Assert-Contains "csp query redaction" $contract '"uri_query_and_fragment_persisted":false'

if ($ReadOnly) {
  Write-Host "status=verified_read_only"
  Write-Host "contract_version=csp-report-contract-v1"
  Write-Host "evidence_ref=csp_report_contract_visible"
  exit 0
}

Write-Host "[phase3-csp-report] local audit and redaction proof"
$proofId = [Guid]::NewGuid().ToString("N")
$requestId = "csp-report-proof-$proofId"
$privateMarker = "must-not-persist-$proofId"
$body = @{
  "csp-report" = @{
    "document-uri" = "$BaseUrl/diagnostics?probe=$privateMarker#fragment"
    "blocked-uri" = "https://blocked.example.invalid/script.js?probe=$privateMarker#fragment"
    "violated-directive" = "script-src-elem"
    "effective-directive" = "script-src-elem"
    "source-file" = "$BaseUrl/app.js?probe=$privateMarker"
    "line-number" = 1
    "column-number" = 1
    "status-code" = 200
    "user-agent" = $privateMarker
    "unknown-field" = $privateMarker
  }
  request_id = $requestId
  trace_id = "csp-trace-proof-$proofId"
} | ConvertTo-Json -Compress -Depth 5

$report = Invoke-WebResponse -Url "$BaseUrl/api/v1/security/csp/report" -Method "POST" -Body $body -ContentType "application/csp-report"
Assert-True "csp report accepted" ([int]$report.status_code -eq 200)
Assert-Contains "csp report status" $report.body '"status":"accepted"'
Assert-Contains "csp report contract version" $report.body '"contract_version":"csp-report-contract-v1"'
Assert-Contains "csp report audit persisted" $report.body '"audit_persisted":true'
Assert-Contains "csp report no external forwarding" $report.body '"live_external_report_forwarding":false'
Assert-Contains "csp report no secret output" $report.body '"secret_output":false'

$audit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=100"
Assert-Contains "csp audit event visible" $audit "security_csp_violation_reported"
Assert-Contains "csp audit request id visible" $audit $requestId
Assert-Contains "csp audit evidence visible" $audit "csp_report_audit_persisted"
Assert-Contains "csp audit sanitized document uri" $audit "$BaseUrl/diagnostics"
Assert-Contains "csp audit sanitized blocked uri" $audit "https://blocked.example.invalid/script.js"
Assert-NotContains "csp audit query, fragment, and unknown field redacted" $audit $privateMarker

Write-Host "[phase3-csp-report] negative paths"
$oversizedBody = @{
  "csp-report" = @{
    "blocked-uri" = "https://blocked.example.invalid/oversized.js"
    padding = ("x" * 17000)
  }
} | ConvertTo-Json -Compress -Depth 5
$oversized = Invoke-WebResponse -Url "$BaseUrl/api/v1/security/csp/report" -Method "POST" -Body $oversizedBody -ContentType "application/csp-report"
Assert-True "oversized csp report rejected with 413" ([int]$oversized.status_code -eq 413)
Assert-Contains "oversized csp report error" $oversized.body "csp_report_too_large"

$invalidShape = Invoke-WebResponse -Url "$BaseUrl/api/v1/security/csp/report" -Method "POST" -Body '{"report-not-supported":{"blocked-uri":"inline"}}' -ContentType "application/json"
Assert-True "invalid csp report shape rejected with 422" ([int]$invalidShape.status_code -eq 422)
Assert-Contains "invalid csp report shape error" $invalidShape.body "missing_csp_report"

$unsupportedType = Invoke-WebResponse -Url "$BaseUrl/api/v1/security/csp/report" -Method "POST" -Body '{"csp-report":{"blocked-uri":"inline"}}' -ContentType "text/plain"
Assert-True "unsupported csp report content type rejected with 415" ([int]$unsupportedType.status_code -eq 415)
Assert-Contains "unsupported csp report content type error" $unsupportedType.body "unsupported_csp_report_content_type"

Write-Host "[phase3-csp-report] Chromium click proof"
$oldCspBase = $env:PHASE3_CSP_BASE_URL
$oldCspDir = $env:PHASE3_CSP_ARTIFACT_DIR
$oldPhase6Base = $env:PHASE6_BASE_URL
try {
  $env:PHASE3_CSP_BASE_URL = $BaseUrl
  $env:PHASE3_CSP_ARTIFACT_DIR = $artifactDir
  $env:PHASE6_BASE_URL = $BaseUrl
  Push-Location (Join-Path $repoRoot "apps\frontend")
  try {
    npx playwright test e2e/phase3-csp-report.spec.ts --workers=1 --reporter=line
    if ($LASTEXITCODE -ne 0) { throw "Playwright CSP report proof failed" }
  } finally { Pop-Location }
} finally {
  $env:PHASE3_CSP_BASE_URL = $oldCspBase
  $env:PHASE3_CSP_ARTIFACT_DIR = $oldCspDir
  $env:PHASE6_BASE_URL = $oldPhase6Base
}
$screenshotPath = Join-Path $artifactDir "diagnostics-csp-report-contract.png"
Assert-True "CSP browser screenshot exists" (Test-Path $screenshotPath)
$screenshotBytes = (Get-Item $screenshotPath).Length
Assert-True "CSP browser screenshot nonblank" ($screenshotBytes -gt 25000)

$reportPayload = [ordered]@{
  contract_version = "csp-report-contract-v1"
  status = "verified"
  scope = "DEV-ONLY"
  accepted_status = [int]$report.status_code
  oversized_status = [int]$oversized.status_code
  invalid_shape_status = [int]$invalidShape.status_code
  unsupported_type_status = [int]$unsupportedType.status_code
  audit_persisted = $true
  query_and_fragment_redacted = $true
  raw_report_persisted = $false
  provider_write = $false
  production_deploy = $false
  screenshot = @{ path = "diagnostics-csp-report-contract.png"; bytes = $screenshotBytes }
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
}
$reportPayload | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $artifactDir "report.json") -Encoding utf8

Write-Host "status=verified"
Write-Host "contract_version=csp-report-contract-v1"
Write-Host "evidence_ref=csp_report_contract_visible"
Write-Host "audit_evidence_ref=csp_report_audit_persisted"
Write-Host "proof_scope=DEV-ONLY"
Write-Host "screenshot_bytes=$screenshotBytes"
