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
    throw "Phase4 hosted system-fallback-contract verification failed: $label"
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase4 hosted system-fallback-contract verification failed: $label did not contain '$expected'. Value: $text"
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
    throw "Phase4 hosted system-fallback-contract verification failed: GET $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted system-fallback-contract proof requires HTTPS" }

$frontend = Invoke-WebResponse "$BaseUrl/"
$contract = Invoke-JsonApi "$BaseUrl/api/v1/system/fallback/contract"
$health = Invoke-JsonApi "$BaseUrl/api/v1/health"

Assert-True "frontend status ok" ($frontend.StatusCode -eq 200)
Assert-Contains "frontend fallback panel visible" $frontend.Content "System Unavailable Fallback"
Assert-Contains "frontend fallback evidence visible" $frontend.Content "system_unavailable_ui_state"

Assert-True "contract version" ($contract.contract_version -eq "system-unavailable-fallback-v1")
Assert-True "health endpoint parity" ($contract.health_endpoint -eq "GET /api/v1/health")
Assert-True "ui state parity" ($contract.ui_state -eq "System Unavailable")
Assert-True "trigger includes degraded" (@($contract.trigger_conditions) -contains "health.status is degraded or down")
Assert-True "policy includes no fake healthy" (@($contract.policy_checks) -contains "no_fake_healthy_claim")
Assert-True "policy includes failed service visible" (@($contract.policy_checks) -contains "failed_service_visible")
Assert-True "recovery includes retry button" (@($contract.recovery_actions) -contains "keep retry button visible")
Assert-True "evidence unavailable state" ($contract.evidence_refs.unavailable_state -eq "system_unavailable_ui_state")

Assert-True "health runtime healthy" ($health.status -eq "healthy")
Assert-True "health services visible" ($null -ne $health.services)
Assert-True "postgres healthy" ($health.services.postgres.status -eq "healthy")
Assert-True "redis healthy" ($health.services.redis.status -eq "healthy")
Assert-True "agent worker healthy" ($health.services.agent_worker.status -eq "healthy")
Assert-True "memory worker healthy" ($health.services.memory_worker.status -eq "healthy")
Assert-True "mcp gateway healthy" ($health.services.mcp_gateway.status -eq "healthy")
Assert-True "llm gateway healthy" ($health.services.llm_gateway.status -eq "healthy")

Write-Host "[phase4-system-fallback-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-system-fallback-contract-runtime] result=verified"
