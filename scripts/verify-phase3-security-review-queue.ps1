param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase3 security review queue verification failed: $Label did not contain '$Expected'. Value: $text"
  }
}

function Assert-NotContains($Label, $Value, $Unexpected) {
  $text = ($Value | Out-String)
  if ($text.Contains($Unexpected)) {
    throw "Phase3 security review queue verification failed: $Label contained '$Unexpected'. Value: $text"
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 security review queue verification failed: $Label"
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
  $payloadFile = Join-Path $env:TEMP ("phase3-security-review-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("phase3-security-review-" + [Guid]::NewGuid().ToString("N") + ".py")
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
  throw "Phase3 security review queue proof refuses localhost unless -AllowLocalhost is set"
}
$baseUri = [System.Uri]$BaseUrl
$isLocalhost = $baseUri.Host -in @("localhost", "127.0.0.1", "::1")
if ((-not $isLocalhost) -and $baseUri.Host -ne "188-34-191-140.sslip.io") {
  throw "Phase3 security review queue mutation probe is allowed only on hosted staging 188-34-191-140.sslip.io"
}

Write-Host "[phase3-security-review-queue] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend security review panel" $frontendHtml "Security Review Queue"
Assert-Contains "frontend contract version" $frontendHtml "security-review-queue-v1"
Assert-Contains "frontend queue evidence" $frontendHtml "security_review_queue_visible"
Assert-Contains "frontend item evidence" $frontendHtml "security_review_item_visible"
Assert-Contains "frontend redaction evidence" $frontendHtml "security_review_redaction_enforced"
Assert-Contains "frontend mutation evidence" $frontendHtml "security_review_mutation_blocked"
Assert-Contains "frontend endpoint" $frontendHtml "GET /api/v1/security/review-queue"

$contract = Invoke-Text "$BaseUrl/api/v1/security/review-queue/contract"
Assert-Contains "contract version" $contract '"contract_version":"security-review-queue-v1"'
Assert-Contains "contract endpoint" $contract "GET /api/v1/security/review-queue"
Assert-Contains "contract source table" $contract "audit_log"
Assert-Contains "contract source surface" $contract "GET /api/v1/security/events"
Assert-Contains "contract read only" $contract '"read_only":true'
Assert-Contains "contract queue evidence" $contract "security_review_queue_visible"
Assert-Contains "contract item evidence" $contract "security_review_item_visible"
Assert-Contains "contract redaction evidence" $contract "security_review_redaction_enforced"
Assert-Contains "contract mutation evidence" $contract "security_review_mutation_blocked"
Assert-Contains "contract filter evidence" $contract "security_review_filter_state_visible"
Assert-Contains "contract decision history evidence" $contract "security_review_decision_history_visible"
Assert-Contains "contract evidence snapshot" $contract "security_review_evidence_snapshot_visible"
Assert-Contains "contract forbidden token" $contract "authorization_header"
Assert-Contains "contract forbidden cookie" $contract "cookie"
Assert-Contains "contract no live provider" $contract "No live provider calls"

$suffix = [Guid]::NewGuid().ToString("N")
$redactionSecret = "phase3-security-review-token-$suffix"
$cspRequestId = "security-review-csp-$suffix"
$cspTraceId = "trace-security-review-csp-$suffix"
$cspBody = @{
  request_id = $cspRequestId
  trace_id = $cspTraceId
  user_agent = "phase3-security-review-verifier"
  report = @{
    "document-uri" = "$BaseUrl/"
    "blocked-uri" = "https://blocked.example.invalid/security-review-queue.js"
    "violated-directive" = "script-src"
    "effective-directive" = "script-src"
    "original-policy" = "default-src self; authorization=$redactionSecret"
  }
} | ConvertTo-Json -Compress -Depth 8
$cspResult = Invoke-JsonApi "$BaseUrl/api/v1/security/csp/report" "POST" $cspBody
Assert-True "csp accepted" ($cspResult.status -eq "accepted")
Assert-True "csp audit persisted" ($cspResult.audit_persisted -eq $true)

Start-Sleep -Milliseconds 700

$queue = Invoke-Text "$BaseUrl/api/v1/security/review-queue?limit=50"
Assert-Contains "queue contract" $queue '"contract_version":"security-review-queue-v1"'
Assert-Contains "queue read only" $queue '"read_only":true'
Assert-Contains "queue evidence" $queue "security_review_queue_visible"
Assert-Contains "queue item evidence" $queue "security_review_item_visible"
Assert-Contains "queue redaction evidence" $queue "security_review_redaction_enforced"
Assert-Contains "queue filter evidence" $queue "security_review_filter_state_visible"
Assert-Contains "queue decision history evidence" $queue "security_review_decision_history_visible"
Assert-Contains "queue evidence snapshot" $queue "security_review_evidence_snapshot_visible"
Assert-Contains "queue risk badge" $queue "risk_badge"
Assert-Contains "queue decision history" $queue "decision_history"
Assert-Contains "queue csp request" $queue $cspRequestId
Assert-Contains "queue csp trace" $queue $cspTraceId
Assert-Contains "queue detail keys only" $queue "detail_keys"
Assert-NotContains "queue raw secret absent" $queue $redactionSecret
Assert-NotContains "queue token absent" $queue "sk-proj-"
Assert-NotContains "queue private key absent" $queue "BEGIN PRIVATE KEY"
Assert-NotContains "queue cookie absent" $queue "Set-Cookie"
Assert-Contains "queue masked marker visible" $queue "***MASKED_SECRET***"

$needsReview = Invoke-Text "$BaseUrl/api/v1/security/review-queue?status=needs_review&limit=50"
Assert-Contains "needs review status" $needsReview "needs_review"
Assert-Contains "needs review request" $needsReview $cspRequestId
Assert-Contains "needs review filter evidence" $needsReview "security_review_filter_state_visible"

$snapshot = Invoke-Text "$BaseUrl/api/v1/security/review-queue/snapshot?status=needs_review&limit=50"
Assert-Contains "snapshot mode" $snapshot "read_only_security_review_evidence_snapshot"
Assert-Contains "snapshot endpoint" $snapshot "GET /api/v1/security/review-queue/snapshot"
Assert-Contains "snapshot filter evidence" $snapshot "security_review_filter_state_visible"
Assert-Contains "snapshot decision history" $snapshot "security_review_decision_history_visible"
Assert-Contains "snapshot evidence ref" $snapshot "security_review_evidence_snapshot_visible"
Assert-Contains "snapshot risk badges" $snapshot "risk_badges"
Assert-Contains "snapshot latest decisions" $snapshot "latest_decisions"
Assert-Contains "snapshot csp request" $snapshot $cspRequestId
Assert-NotContains "snapshot raw secret absent" $snapshot $redactionSecret

$blocked = Invoke-WebResponse -Url "$BaseUrl/api/v1/security/review-queue" -Method "POST" -Body (@{ status = "approved" } | ConvertTo-Json -Compress)
Assert-True "mutation blocked status" ([int]$blocked.status_code -eq 403)
Assert-Contains "mutation block evidence" $blocked.body "security_review_mutation_blocked"
Assert-Contains "mutation read only" $blocked.body "security_review_queue_is_read_only"

Write-Host "status=verified"
Write-Host "contract_version=security-review-queue-v1"
Write-Host "evidence_ref=security_review_queue_visible"
