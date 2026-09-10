param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase3 security review gate verification failed: $Label did not contain '$Expected'. Value: $text"
  }
}

function Assert-NotContains($Label, $Value, $Unexpected) {
  $text = ($Value | Out-String)
  if ($text.Contains($Unexpected)) {
    throw "Phase3 security review gate verification failed: $Label contained '$Unexpected'. Value: $text"
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 security review gate verification failed: $Label"
  }
}

function Invoke-WebResponse(
  [string]$Url,
  [string]$Method = "GET",
  [string]$Body = "",
  [string]$ContentType = "application/json",
  [int]$TimeoutSeconds = 30
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
  $payloadFile = Join-Path $env:TEMP ("phase3-security-review-gate-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("phase3-security-review-gate-" + [Guid]::NewGuid().ToString("N") + ".py")
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

headers = {}
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

function Invoke-Text($Url) {
  return (Invoke-WebResponse -Url $Url -Method "GET").body
}

function Invoke-JsonApi($Url, $Method = "GET", $Body = $null) {
  $response = Invoke-WebResponse -Url $Url -Method $Method -Body $Body -ContentType "application/json"
  if ([int]$response.status_code -ge 400) {
    throw "HTTP $($response.status_code): $($response.body)"
  }
  return ($response.body | ConvertFrom-Json)
}

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  throw "BaseUrl is required"
}
$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Phase3 security review gate proof refuses localhost unless -AllowLocalhost is set"
}
$baseUri = [System.Uri]$BaseUrl
$isLocalhost = $baseUri.Host -in @("localhost", "127.0.0.1", "::1")
if ((-not $isLocalhost) -and $baseUri.Host -ne "188-34-191-140.sslip.io") {
  throw "Phase3 security review gate mutation probe is allowed only on hosted staging 188-34-191-140.sslip.io"
}

Write-Host "[phase3-security-review-gate] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend gate panel" $frontendHtml "Security Review Gate Summary"
Assert-Contains "frontend gate evidence" $frontendHtml "security_review_gate_summary_visible"
Assert-Contains "frontend non rollout" $frontendHtml "Production"

$contract = Invoke-Text "$BaseUrl/api/v1/security/review-queue/contract"
Assert-Contains "contract version" $contract '"contract_version":"security-review-queue-v1"'
Assert-Contains "contract gate endpoint" $contract "GET /api/v1/security/review-queue/gate"
Assert-Contains "contract gate evidence" $contract "security_review_gate_summary_visible"
Assert-Contains "contract read only" $contract '"read_only":true'
Assert-Contains "contract advisory policy" $contract "cannot approve a production rollout"

$suffix = [Guid]::NewGuid().ToString("N")
$redactionSecret = "phase3-security-review-gate-token-$suffix"
$cspRequestId = "security-review-gate-csp-$suffix"
$cspTraceId = "trace-security-review-gate-csp-$suffix"
$cspBody = @{
  request_id = $cspRequestId
  trace_id = $cspTraceId
  user_agent = "phase3-security-review-gate-verifier"
  report = @{
    "document-uri" = "$BaseUrl/"
    "blocked-uri" = "https://blocked.example.invalid/security-review-gate.js"
    "violated-directive" = "script-src"
    "effective-directive" = "script-src"
    "original-policy" = "default-src self; authorization=$redactionSecret"
  }
} | ConvertTo-Json -Compress -Depth 8
$cspResult = Invoke-JsonApi "$BaseUrl/api/v1/security/csp/report" "POST" $cspBody
Assert-True "csp accepted" ($cspResult.status -eq "accepted")
Assert-True "csp audit persisted" ($cspResult.audit_persisted -eq $true)

Start-Sleep -Milliseconds 700

$gate = Invoke-Text "$BaseUrl/api/v1/security/review-queue/gate?limit=50"
Assert-Contains "gate mode" $gate "read_only_security_review_gate_summary"
Assert-Contains "gate evidence" $gate "security_review_gate_summary_visible"
Assert-Contains "gate queue evidence" $gate "security_review_queue_visible"
Assert-Contains "gate snapshot evidence" $gate "security_review_evidence_snapshot_visible"
Assert-Contains "gate blocked" $gate "blocked_by_open_security_reviews"
Assert-Contains "gate blocker count" $gate "blocker_count"
Assert-Contains "gate promotion false" $gate '"promotion_allowed":false'
Assert-Contains "gate production false" $gate '"production_rollout_claimed":false'
Assert-Contains "gate release authority" $gate "outside_security_review_queue"
Assert-Contains "gate request" $gate $cspRequestId
Assert-Contains "gate trace" $gate $cspTraceId
Assert-Contains "gate blocker badge" $gate "review_required"
Assert-NotContains "gate raw secret absent" $gate $redactionSecret
Assert-NotContains "gate token absent" $gate "sk-proj-"
Assert-NotContains "gate private key absent" $gate "BEGIN PRIVATE KEY"

$blocked = Invoke-WebResponse -Url "$BaseUrl/api/v1/security/review-queue" -Method "POST" -Body (@{ status = "approved" } | ConvertTo-Json -Compress)
Assert-True "mutation blocked status" ([int]$blocked.status_code -eq 403)
Assert-Contains "mutation block evidence" $blocked.body "security_review_mutation_blocked"

Write-Host "status=verified"
Write-Host "contract_version=security-review-queue-v1"
Write-Host "evidence_ref=security_review_gate_summary_visible"
