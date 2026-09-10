param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase3 CSP report verification failed: $label did not contain '$expected'. Value: $text"
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
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
    if (Test-Path $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
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
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Phase3 CSP report proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase3-csp-report] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend csp report panel" $frontendHtml "CSP Report Contract"
Assert-Contains "frontend csp report evidence" $frontendHtml "csp_report_contract_visible"

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

$requestId = "csp-report-proof-" + [Guid]::NewGuid().ToString("N")
$body = @{
  "csp-report" = @{
    "document-uri" = "$BaseUrl/"
    "blocked-uri" = "https://blocked.example.invalid/script.js"
    "violated-directive" = "script-src-elem"
    "effective-directive" = "script-src-elem"
    "source-file" = "$BaseUrl/app.js"
    "line-number" = 1
    "column-number" = 1
    "status-code" = 200
  }
  request_id = $requestId
  trace_id = "csp-trace-proof"
} | ConvertTo-Json -Compress -Depth 5

$report = Invoke-WebResponse -Url "$BaseUrl/api/v1/security/csp/report" -Method "POST" -Body $body -ContentType "application/json"
Assert-True "csp report accepted" ([int]$report.status_code -eq 200)
Assert-Contains "csp report status" $report.body '"status":"accepted"'
Assert-Contains "csp report contract version" $report.body '"contract_version":"csp-report-contract-v1"'
Assert-Contains "csp report audit persisted" $report.body '"audit_persisted":true'
Assert-Contains "csp report no external forwarding" $report.body '"live_external_report_forwarding":false'

$audit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=20"
Assert-Contains "csp audit event visible" $audit "security_csp_violation_reported"
Assert-Contains "csp audit request id visible" $audit $requestId
Assert-Contains "csp audit evidence visible" $audit "csp_report_audit_persisted"

Write-Host "status=verified"
Write-Host "contract_version=csp-report-contract-v1"
Write-Host "evidence_ref=csp_report_contract_visible"
