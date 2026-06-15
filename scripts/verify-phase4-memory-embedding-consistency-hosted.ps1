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
    throw "Phase4 hosted memory-embedding-consistency verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted memory-embedding-consistency verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Invoke-WebResponse($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = $null, $timeoutSeconds = 30) {
  $bodyBase64 = $null
  if ($null -ne $body) {
    $bodyBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$body))
  }
  $payload = [pscustomobject]@{
    url = $url
    method = $method
    bodyBase64 = $bodyBase64
    headers = $headers
    contentType = $contentType
    timeoutSeconds = $timeoutSeconds
  } | ConvertTo-Json -Depth 8 -Compress
  $python = @'
import base64
import json
import ssl
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
body_base64 = payload.get("bodyBase64")
data = None
if body_base64 is not None:
    data = base64.b64decode(body_base64.encode("ascii"))
headers = payload.get("headers") or {}
content_type = payload.get("contentType")
if content_type and "Content-Type" not in headers and "content-type" not in headers:
    headers["Content-Type"] = content_type
request = urllib.request.Request(payload["url"], data=data, headers=headers, method=payload["method"])
context = ssl._create_unverified_context() if payload["url"].startswith("https://") else None
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30), context=context) as response:
        result = {"status_code": response.getcode(), "content": response.read().decode("utf-8", errors="replace")}
except urllib.error.HTTPError as error:
    result = {"status_code": error.code, "content": error.read().decode("utf-8", errors="replace")}
print(json.dumps(result))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-memory-embedding-consistency-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  $parsed = $raw | ConvertFrom-Json
  return [pscustomobject]@{ StatusCode = [int]$parsed.status_code; Content = [string]$parsed.content }
}

function Invoke-JsonApi($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = "application/json", $timeoutSeconds = 30) {
  $response = Invoke-WebResponse -url $url -method $method -body $body -headers $headers -contentType $contentType -timeoutSeconds $timeoutSeconds
  if ([int]$response.StatusCode -ge 400) {
    throw "Phase4 hosted memory-embedding-consistency verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase4 hosted memory-embedding-consistency proof requires HTTPS"
}

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/embedding-consistency/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "memory-embedding-consistency-v1")
Assert-True "status verified" ($contract.status -eq "verified")
Assert-True "schema table parity" ($contract.schema.table -eq "memory_entries")
Assert-True "vector column parity" ($contract.schema.expected_columns.content_embedding -eq "vector(1536)")
Assert-True "actual vector column parity" ($contract.schema.actual_columns.content_embedding -eq "vector(1536)")
Assert-True "embedding model column parity" ($contract.schema.actual_columns.embedding_model_version -eq "character varying(100)")
Assert-True "metadata column parity" ($contract.schema.actual_columns.metadata -eq "jsonb")
Assert-True "status column parity" ($contract.schema.actual_columns.status -eq "character varying(50)")
Assert-True "schema mismatch list empty" (@($contract.schema.mismatches).Count -eq 0)
Assert-True "schema error empty" ([string]::IsNullOrWhiteSpace([string]$contract.schema.error))
Assert-True "search mode lexical fallback" ($contract.current_embedding.search_mode -eq "lexical_fallback")
Assert-True "generation mode disabled" ($contract.current_embedding.generation_mode -eq "disabled_until_live_embedding_gate")
Assert-True "live embedding provider calls false" (-not [bool]$contract.current_embedding.live_embedding_provider_calls)
Assert-True "dimensions parity" ([int]$contract.current_embedding.dimensions -eq 1536)
Assert-True "model version visible" (-not [string]::IsNullOrWhiteSpace([string]$contract.current_embedding.model_version))
Assert-True "filter field parity" ($contract.read_policy.filter_field_when_vector_search_enabled -eq "embedding_model_version")
Assert-True "vector search disabled" (-not [bool]$contract.read_policy.vector_search_enabled)
Assert-True "safe fallback parity" ($contract.read_policy.safe_fallback -eq "lexical_fallback")
Assert-True "persisted column parity" ($contract.write_policy.persisted_column -eq "memory_entries.embedding_model_version")
Assert-True "metadata mirror parity" ($contract.write_policy.metadata_mirror -eq "metadata.embedding_model_version")
Assert-True "stale row policy visible" (-not [string]::IsNullOrWhiteSpace([string]$contract.reembedding_policy.stale_row_policy))
Assert-True "evidence ref visible" (@($contract.evidence_refs) -contains "embedding_model_version_persisted")

$searchContract = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/search/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "search contract version" ($searchContract.contract_version -eq "memory-search-runtime-v1")
Assert-True "search mode parity" ($searchContract.search_mode -eq $contract.current_embedding.search_mode)
Assert-True "embedding dependency parity" ($searchContract.depends_on.embedding_consistency_contract -eq "GET /api/v1/memory/embedding-consistency/contract")

$projectId = "hosted-phase4-memory-embedding-" + [Guid]::NewGuid().ToString("N")
$needle = "phase4 hosted memory embedding consistency " + [Guid]::NewGuid().ToString("N")
$promptBody = @{
  project_id = $projectId
  prompt = $needle
  stream = $false
} | ConvertTo-Json -Compress
$created = Invoke-JsonApi -url "$BaseUrl/api/v1/prompt" -method "POST" -body $promptBody -contentType "application/json" -timeoutSeconds 20
Assert-True "session id returned" (-not [string]::IsNullOrWhiteSpace([string]$created.session_id))

$encodedNeedle = [uri]::EscapeDataString([string]$needle)
$search = Invoke-JsonApi -url "$BaseUrl/api/v1/memory/search?q=$encodedNeedle&project_id=$projectId&limit=5&threshold=0.0" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "runtime search mode parity" ($search.search_mode -eq $contract.current_embedding.search_mode)
$result = @($search.results) | Select-Object -First 1
Assert-True "search result visible" ($null -ne $result)
Assert-Contains "needle found in search result" $result.content $needle
Assert-True "session parity" ($result.session_id -eq $created.session_id)

Write-Host "[phase4-memory-embedding-consistency] base_url=$BaseUrl"
Write-Host "[phase4-memory-embedding-consistency] result=verified"
