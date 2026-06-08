param(
  [string]$BaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" })
)

$ErrorActionPreference = "Stop"

function Assert-HostedBaseUrlConfigured {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "Hosted verifier requires -BaseUrl or env:STAGING_BASE_URL (HTTPS, non-localhost)."
  }
  if ($BaseUrl -notmatch '^https://') {
    throw "Hosted verifier requires an HTTPS BaseUrl."
  }
  if ($BaseUrl -match 'localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|host\.docker\.internal') {
    throw "Hosted verifier refuses localhost and loopback BaseUrl values."
  }
}
Assert-HostedBaseUrlConfigured


function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted cost-export-contract verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted cost-export-contract verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Invoke-WebResponse($url, $timeoutSeconds = 30) {
  $python = @'
import json, ssl, sys, urllib.error, urllib.request
context = ssl._create_unverified_context() if sys.argv[1].startswith("https://") else None
try:
    with urllib.request.urlopen(sys.argv[1], timeout=int(sys.argv[2]), context=context) as response:
        result = {
            "status_code": response.getcode(),
            "content": response.read().decode("utf-8", errors="replace"),
            "headers": dict(response.headers.items()),
        }
except urllib.error.HTTPError as error:
    result = {
        "status_code": error.code,
        "content": error.read().decode("utf-8", errors="replace"),
        "headers": dict(error.headers.items()),
    }
print(json.dumps(result))
'@
  $raw = $python | py -3 - $url $timeoutSeconds
  $parsed = $raw | ConvertFrom-Json
  return [pscustomobject]@{
    StatusCode = [int]$parsed.status_code
    Content = [string]$parsed.content
    Headers = $parsed.headers
  }
}

function Invoke-JsonApi($url) {
  $response = Invoke-WebResponse -url $url
  if ([int]$response.StatusCode -ge 400) {
    throw "Phase4 hosted cost-export-contract verification failed: GET $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted cost-export-contract proof requires HTTPS" }

$contract = Invoke-JsonApi "$BaseUrl/api/v1/costs/export/contract"
Assert-True "contract version" ($contract.contract_version -eq "cost-monitor-export-v1")
Assert-True "contract endpoint parity" ($contract.endpoint -eq "GET /api/v1/costs/export?format=csv&group_by=agent|model|session")
Assert-True "csv format supported" (@($contract.supported_formats) -contains "csv")

$traceId = "hosted-cost-export-" + [Guid]::NewGuid().ToString("N")
$requestId = "req-" + [Guid]::NewGuid().ToString("N")
$exportResponse = Invoke-WebResponse "$BaseUrl/api/v1/costs/export?format=csv&group_by=agent&trace_id=$traceId&request_id=$requestId"

Assert-True "csv export status" ($exportResponse.StatusCode -eq 200)
Assert-True "csv content type" ($exportResponse.Headers."Content-Type" -eq "text/csv; charset=utf-8")
Assert-True "contract header" ($exportResponse.Headers."X-Contract-Version" -eq "cost-monitor-export-v1")
Assert-True "evidence header" ($exportResponse.Headers."X-Evidence-Ref" -eq "cost_export_csv_generated")
Assert-True "trace header" ($exportResponse.Headers."X-Trace-Id" -eq $traceId)
Assert-True "request header" ($exportResponse.Headers."X-Request-Id" -eq $requestId)
Assert-Contains "filename" $exportResponse.Headers."Content-Disposition" 'superbrain-costs-agent.csv'
Assert-Contains "csv header row" $exportResponse.Content 'group_by,agent_type,model_name,provider_name,session_id,input_tokens,output_tokens,cost_cents,from_cache,row_count'

$audit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=80"
$auditRecord = @($audit.events) | Where-Object {
  $_.event_type -eq "cost_export_generated" -and $_.request_id -eq $requestId
} | Select-Object -First 1
Assert-True "audit record visible" ($null -ne $auditRecord)
Assert-True "trace parity" ($auditRecord.trace_id -eq $traceId)
Assert-True "audit feed evidence" ($auditRecord.audit_feed_evidence_ref -eq "request_id_audit_feed_visible")
Assert-True "group by parity" ($auditRecord.details.group_by -eq "agent")
Assert-True "audit evidence ref parity" ($auditRecord.details.evidence_ref -eq "cost_export_audit_persisted")
Assert-True "contract version parity" ($auditRecord.details.contract_version -eq "cost-monitor-export-v1")

Write-Host "[phase4-cost-export-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-cost-export-contract-runtime] result=verified"
