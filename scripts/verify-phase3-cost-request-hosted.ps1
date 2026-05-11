param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase3 hosted cost/request verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Invoke-JsonApi(
  [string]$Url,
  [string]$Method = "GET",
  [string]$Body = "",
  [hashtable]$Headers = $null,
  [string]$ContentType = "application/json",
  [int]$TimeoutSeconds = 15
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
  $payloadJson = $payload | ConvertTo-Json -Compress -Depth 6
  $payloadFile = Join-Path $env:TEMP ("phase3-hosted-cost-request-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("phase3-hosted-cost-request-" + [Guid]::NewGuid().ToString("N") + ".py")
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

headers = payload.get("headers") or {}
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
        body = response.read().decode("utf-8", errors="replace")
        result = {
            "status_code": response.getcode(),
            "body": body,
            "headers": dict(response.headers.items()),
        }
except urllib.error.HTTPError as exc:
    result = {
        "status_code": exc.code,
        "body": exc.read().decode("utf-8", errors="replace"),
        "headers": dict(exc.headers.items()),
    }
print(json.dumps(result))
'@
    Set-Content -LiteralPath $pythonFile -Value $pythonScript -NoNewline -Encoding utf8
    $raw = py -3 $pythonFile $payloadFile 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      throw $raw.Trim()
    }
    $parsed = $raw | ConvertFrom-Json
    return [pscustomobject]@{
      StatusCode = [int]$parsed.status_code
      Body = [string]$parsed.body
      Headers = $parsed.headers
    }
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
    if (Test-Path $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
  }
}

function Invoke-Text($url) {
  return (Invoke-JsonApi -Url $url -Method "GET" -ContentType "").Body
}

function Invoke-HeadersText($url, [hashtable]$headers = $null) {
  $response = Invoke-JsonApi -Url $url -Method "GET" -Headers $headers -ContentType ""
  $lines = @()
  foreach ($header in $response.Headers.PSObject.Properties) {
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
if ($BaseUrl -notmatch "^https://") {
  throw "Phase3 hosted cost/request proof requires HTTPS"
}

Write-Host "[phase3-hosted-cost-request] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend cost monitor panel" $frontendHtml "Cost Monitor"
Assert-Contains "frontend cost export marker" $frontendHtml "CSV Export"
Assert-Contains "frontend trace id panel" $frontendHtml "Trace ID Contract"
Assert-Contains "frontend request id panel" $frontendHtml "Request ID Contract"
Assert-Contains "frontend request audit marker" $frontendHtml "request_id_audit_feed_visible"

$costs = Invoke-Text "$BaseUrl/api/v1/costs"
Assert-Contains "costs budget limit" $costs '"budget_limit_cents":20000'
Assert-Contains "costs breakdown" $costs '"breakdown"'

$costExportContract = Invoke-Text "$BaseUrl/api/v1/costs/export/contract"
Assert-Contains "cost export contract version" $costExportContract '"contract_version":"cost-monitor-export-v1"'
Assert-Contains "cost export csv support" $costExportContract '"supported_formats":["csv"]'
Assert-Contains "cost export grouping" $costExportContract "agent"
Assert-Contains "cost export evidence" $costExportContract "cost_export_csv_generated"

$traceProbeId = "hosted-trace-proof-" + [Guid]::NewGuid().ToString("N")
$traceContract = Invoke-Text "$BaseUrl/api/v1/trace/contract"
Assert-Contains "trace contract version" $traceContract '"contract_version":"trace-id-propagation-v1"'
Assert-Contains "trace roundtrip evidence" $traceContract "trace_id_header_roundtrip"
$traceHeaders = Invoke-HeadersText -url "$BaseUrl/api/v1/health" -headers @{ "x-trace-id" = $traceProbeId }
Assert-Contains "trace response header roundtrip" $traceHeaders "x-trace-id: $traceProbeId"
Assert-Contains "trace contract marker" $traceHeaders "x-superbrain-trace-contract: trace-id-propagation-v1"

$requestProbeId = "hosted-request-proof-" + [Guid]::NewGuid().ToString("N")
$requestContract = Invoke-Text "$BaseUrl/api/v1/request/contract"
Assert-Contains "request id contract version" $requestContract '"contract_version":"request-id-correlation-v1"'
Assert-Contains "request id roundtrip evidence" $requestContract "request_id_header_roundtrip"
Assert-Contains "request id audit evidence" $requestContract "request_id_audit_correlation"
$requestHeaders = Invoke-HeadersText -url "$BaseUrl/api/v1/health" -headers @{ "x-request-id" = $requestProbeId }
Assert-Contains "request id response header roundtrip" $requestHeaders "x-request-id: $requestProbeId"
Assert-Contains "request contract marker" $requestHeaders "x-superbrain-request-contract: request-id-correlation-v1"

$costExportTraceId = "hosted-cost-export-proof-" + [Guid]::NewGuid().ToString("N")
$costExportRequestId = "hosted-cost-export-request-proof-" + [Guid]::NewGuid().ToString("N")
$costExportCsv = Invoke-Text "$BaseUrl/api/v1/costs/export?format=csv&group_by=agent&trace_id=$costExportTraceId&request_id=$costExportRequestId"
Assert-Contains "cost export csv header" $costExportCsv "group_by,agent_type,model_name,provider_name,session_id,input_tokens,output_tokens,cost_cents,from_cache,row_count"

$costExportAudit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=80"
Assert-Contains "cost export audit event" $costExportAudit "cost_export_generated"
Assert-Contains "cost export audit trace id" $costExportAudit $costExportTraceId
Assert-Contains "cost export audit request id" $costExportAudit $costExportRequestId
Assert-Contains "request audit feed evidence" $costExportAudit "request_id_audit_feed_visible"
Assert-Contains "request id top-level field" $costExportAudit ('"request_id":"{0}"' -f $costExportRequestId)

Write-Host "[phase3-hosted-cost-request] checks completed"
