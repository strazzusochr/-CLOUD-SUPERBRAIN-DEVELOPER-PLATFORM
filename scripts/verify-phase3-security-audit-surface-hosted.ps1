param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase3 security audit surface verification failed: $Label did not contain '$Expected'. Value: $text"
  }
}

function Assert-NotContains($Label, $Value, $Unexpected) {
  $text = ($Value | Out-String)
  if ($text.Contains($Unexpected)) {
    throw "Phase3 security audit surface verification failed: $Label contained '$Unexpected'. Value: $text"
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase3 security audit surface verification failed: $Label"
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
  $payloadFile = Join-Path $env:TEMP ("phase3-security-audit-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("phase3-security-audit-" + [Guid]::NewGuid().ToString("N") + ".py")
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
  throw "Phase3 security audit surface proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase3-security-audit-surface] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend security audit panel" $frontendHtml "Security Audit Surface"
Assert-Contains "frontend contract version" $frontendHtml "security-audit-surface-v1"
Assert-Contains "frontend surface evidence" $frontendHtml "security_audit_surface_visible"
Assert-Contains "frontend event evidence" $frontendHtml "security_audit_event_visible"
Assert-Contains "frontend endpoint" $frontendHtml "GET /api/v1/security/events"

$contract = Invoke-Text "$BaseUrl/api/v1/security/events/contract"
Assert-Contains "contract version" $contract '"contract_version":"security-audit-surface-v1"'
Assert-Contains "contract endpoint" $contract "GET /api/v1/security/events"
Assert-Contains "contract source table" $contract "audit_log"
Assert-Contains "contract csp source" $contract "POST /api/v1/security/csp/report"
Assert-Contains "contract mcp source" $contract "POST /mcp/api/v1/tools/execute"
Assert-Contains "contract llm source" $contract "POST /llm/v1/chat/completions"
Assert-Contains "contract csp event type" $contract "security_csp_violation_reported"
Assert-Contains "contract auth event type" $contract "auth_refresh_rotated"
Assert-Contains "contract mcp event type" $contract "mcp_tool_executed"
Assert-Contains "contract llm event type" $contract "llm_gateway_request"
Assert-Contains "contract read only" $contract '"read_only":true'
Assert-Contains "contract surface evidence" $contract "security_audit_surface_visible"
Assert-Contains "contract event evidence" $contract "security_audit_event_visible"
Assert-Contains "contract mcp evidence" $contract "mcp_denied_tool_audit_correlation"

$suffix = [Guid]::NewGuid().ToString("N")
$cspRequestId = "security-audit-csp-$suffix"
$cspTraceId = "trace-security-audit-csp-$suffix"
$redactionSecret = "phase3-security-audit-proof-token-$suffix"
$cspBody = @{
  request_id = $cspRequestId
  trace_id = $cspTraceId
  user_agent = "phase3-security-audit-verifier"
  report = @{
    "document-uri" = "$BaseUrl/"
    "blocked-uri" = "https://blocked.example.invalid/security-audit-surface.js"
    "violated-directive" = "script-src"
    "effective-directive" = "script-src"
    "original-policy" = "default-src self; api_key=$redactionSecret"
  }
} | ConvertTo-Json -Compress -Depth 8
$cspResult = Invoke-JsonApi "$BaseUrl/api/v1/security/csp/report" "POST" $cspBody
Assert-True "csp accepted" ($cspResult.status -eq "accepted")
Assert-True "csp audit persisted" ($cspResult.audit_persisted -eq $true)
Assert-True "csp audit evidence" ($cspResult.audit_evidence_ref -eq "csp_report_audit_persisted")

$llmTraceId = "trace-security-audit-llm-$suffix"
$llmBody = @{
  model = "deepseek-ai/DeepSeek-V4-Flash:fastest"
  messages = @(@{ role = "user"; content = "phase3 security audit surface proof" })
  stream = $false
  metadata = @{
    trace_id = $llmTraceId
    agent_type = "tester"
  }
} | ConvertTo-Json -Compress -Depth 8
$llmResult = Invoke-JsonApi "$BaseUrl/llm/v1/chat/completions" "POST" $llmBody
Assert-True "llm dry-run audit persisted" ($llmResult.audit_persisted -eq $true)
Assert-True "llm dry-run no live calls" ($llmResult.live_provider_calls -eq $false)

$mcpTraceId = "trace-security-audit-mcp-$suffix"
$mcpRequestId = "security-audit-mcp-$suffix"
$toolRequestId = "security-audit-tool-$suffix"
$mcpBody = @{
  tool_request_id = $toolRequestId
  run_id = "security-audit-run-$suffix"
  session_id = [Guid]::NewGuid().ToString()
  trace_id = $mcpTraceId
  request_id = $mcpRequestId
  agent_role = "devops"
  toolset = "github"
  capability = "delete_branch"
  intent_summary = "Verifier proves denied MCP capability appears in the read-only security audit surface."
  input_ref = (@{ branch = "main"; token_hint = "redaction-proof-value" } | ConvertTo-Json -Compress)
  allowed_scope = "feature/security-audit-surface"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = $toolRequestId
  audit_tags = @("phase3", "security-audit-surface")
  redaction_required = $true
  expected_output_type = "blocked_tool_result"
} | ConvertTo-Json -Depth 8 -Compress
$mcpResult = Invoke-JsonApi "$BaseUrl/mcp/api/v1/tools/execute" "POST" $mcpBody
Assert-True "mcp blocked" ($mcpResult.status -eq "blocked")
Assert-True "mcp audit persisted" ($mcpResult.audit_persisted -eq $true)

Start-Sleep -Milliseconds 700

$feed = Invoke-Text "$BaseUrl/api/v1/security/events?limit=50"
Assert-Contains "feed contract" $feed '"contract_version":"security-audit-surface-v1"'
Assert-Contains "feed read only" $feed '"read_only":true'
Assert-Contains "feed surface evidence" $feed "security_audit_surface_visible"
Assert-Contains "feed event evidence" $feed "security_audit_event_visible"
Assert-Contains "feed csp request" $feed $cspRequestId
Assert-Contains "feed csp trace" $feed $cspTraceId
Assert-Contains "feed csp category" $feed "browser_security_policy"
Assert-Contains "feed csp audit evidence" $feed "csp_report_audit_persisted"
Assert-Contains "feed llm trace" $feed $llmTraceId
Assert-Contains "feed llm category" $feed "llm_gateway_guard"
Assert-Contains "feed llm dry-run" $feed '"live_provider_calls":false'
Assert-Contains "feed mcp request" $feed $mcpRequestId
Assert-Contains "feed mcp category" $feed "mcp_guard"
Assert-Contains "feed mcp deny evidence" $feed "mcp_denied_tool_audit_correlation"
Assert-NotContains "feed redaction secret absent" $feed $redactionSecret
Assert-Contains "feed redaction mask visible" $feed "***MASKED_SECRET***"

$filtered = Invoke-Text "$BaseUrl/api/v1/security/events?event_type=security_csp_violation_reported&limit=50"
Assert-Contains "filtered csp request visible" $filtered $cspRequestId
Assert-Contains "filtered csp event type" $filtered "security_csp_violation_reported"
Assert-NotContains "filtered excludes llm trace" $filtered $llmTraceId

Write-Host "status=verified"
Write-Host "contract_version=security-audit-surface-v1"
Write-Host "evidence_ref=security_audit_surface_visible"
