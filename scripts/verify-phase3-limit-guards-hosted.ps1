param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase3 hosted limit-guard verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Invoke-Text($url) {
  $python = @'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=15) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  return ($python | py -3 - $url)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") {
  throw "Phase3 hosted limit-guard proof requires HTTPS"
}

Write-Host "[phase3-hosted-limit-guards] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend rate limit panel" $frontendHtml "Rate Limit Guard"
Assert-Contains "frontend rate limit evidence" $frontendHtml "rate_limit_429_enforced"
Assert-Contains "frontend session limit panel" $frontendHtml "Session Limit Guard"
Assert-Contains "frontend session limit evidence" $frontendHtml "session_limit_429_enforced"

$rateLimitContract = Invoke-Text "$BaseUrl/api/v1/rate-limit/contract"
Assert-Contains "rate limit contract version" $rateLimitContract '"contract_version":"rate-limit-guard-v1"'
Assert-Contains "rate limit protected endpoint" $rateLimitContract "POST /api/v1/prompt"
Assert-Contains "rate limit status endpoint" $rateLimitContract "GET /api/v1/rate-limit/status?project_id={id}"
Assert-Contains "rate limit contract evidence" $rateLimitContract "rate_limit_contract_visible"
Assert-Contains "rate limit 429 evidence" $rateLimitContract "rate_limit_429_enforced"
$rateLimitProjectId = "hosted-rate-limit-" + [Guid]::NewGuid().ToString("N")
$rateLimitStatus = Invoke-Text "$BaseUrl/api/v1/rate-limit/status?project_id=$rateLimitProjectId"
Assert-Contains "rate limit status contract" $rateLimitStatus '"contract_version":"rate-limit-guard-v1"'
Assert-Contains "rate limit status available" $rateLimitStatus '"status":"available"'
Assert-Contains "rate limit status evidence" $rateLimitStatus "rate_limit_status_visible"

$sessionLimitContract = Invoke-Text "$BaseUrl/api/v1/session-limits/contract"
Assert-Contains "session limit contract version" $sessionLimitContract '"contract_version":"session-llm-call-limit-v1"'
Assert-Contains "session limit protected endpoint" $sessionLimitContract "POST /api/v1/prompt"
Assert-Contains "session limit status endpoint" $sessionLimitContract "GET /api/v1/session-limits/status?session_id={id}"
Assert-Contains "session limit contract evidence" $sessionLimitContract "session_limit_contract_visible"
Assert-Contains "session limit status evidence" $sessionLimitContract "session_limit_status_visible"
Assert-Contains "session limit 429 evidence" $sessionLimitContract "session_limit_429_enforced"
$sessionLimitId = "hosted-session-limit-" + [Guid]::NewGuid().ToString("N")
$sessionLimitStatus = Invoke-Text "$BaseUrl/api/v1/session-limits/status?session_id=$sessionLimitId"
Assert-Contains "session limit status contract" $sessionLimitStatus '"contract_version":"session-llm-call-limit-v1"'
Assert-Contains "session limit status available" $sessionLimitStatus '"status":"available"'
Assert-Contains "session limit status evidence" $sessionLimitStatus "session_limit_status_visible"

$metrics = Invoke-Text "$BaseUrl/api/v1/metrics"
Assert-Contains "rate limit capacity metric" $metrics "superbrain_prompt_rate_limit_capacity"
Assert-Contains "rate limit remaining metric" $metrics "superbrain_prompt_rate_limit_remaining"
Assert-Contains "rate limit used metric" $metrics "superbrain_prompt_rate_limit_used"
Assert-Contains "session limit metric" $metrics "superbrain_session_llm_call_limit"
Assert-Contains "session remaining metric" $metrics "superbrain_session_llm_call_remaining"
Assert-Contains "session used metric" $metrics "superbrain_session_llm_call_used"

Write-Host "[phase3-hosted-limit-guards] checks completed"
