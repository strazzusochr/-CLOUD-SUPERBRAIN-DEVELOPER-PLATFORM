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


function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Phase3 hosted fallback/activity verification failed: $label did not contain '$expected'. Value: $text"
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
  throw "Phase3 hosted fallback/activity proof requires HTTPS"
}

Write-Host "[phase3-hosted-fallback-activity] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend fallback panel" $frontendHtml "System Unavailable Fallback"
Assert-Contains "frontend fallback evidence" $frontendHtml "system_unavailable_ui_state"
Assert-Contains "frontend agent activity panel" $frontendHtml "Agent Activity"
Assert-Contains "frontend agent activity filtered evidence" $frontendHtml "agent_activity_filtered_feed_visible"
Assert-Contains "frontend agent activity filter controls" $frontendHtml "activityFilterBar"

$systemFallbackContract = Invoke-Text "$BaseUrl/api/v1/system/fallback/contract"
Assert-Contains "system fallback version" $systemFallbackContract '"contract_version":"system-unavailable-fallback-v1"'
Assert-Contains "system fallback ui state" $systemFallbackContract '"ui_state":"System Unavailable"'
Assert-Contains "system fallback evidence" $systemFallbackContract "system_unavailable_ui_state"
Assert-Contains "system fallback no fake healthy claim" $systemFallbackContract "no_fake_healthy_claim"

$agentActivityContract = Invoke-Text "$BaseUrl/api/v1/agent-activity/contract"
Assert-Contains "agent activity contract version" $agentActivityContract '"contract_version":"agent-activity-trace-v1"'
Assert-Contains "agent activity filtered feed source" $agentActivityContract "GET /api/v1/agent-activity/recent?limit=50"
Assert-Contains "agent activity audit source" $agentActivityContract "GET /api/v1/audit/recent?limit=50"
Assert-Contains "agent activity langfuse guard" $agentActivityContract "no_public_langfuse_without_auth"
Assert-Contains "agent activity filtered evidence" $agentActivityContract "agent_activity_filtered_feed_visible"

$agentActivityFeed = Invoke-Text "$BaseUrl/api/v1/agent-activity/recent?limit=5&severity=info"
Assert-Contains "agent activity feed contract" $agentActivityFeed '"contract_version":"agent-activity-trace-v1"'
Assert-Contains "agent activity feed mode" $agentActivityFeed '"mode":"audit_log_backed_filtered_feed"'
Assert-Contains "agent activity feed severity" $agentActivityFeed '"severity":"info"'
Assert-Contains "agent activity feed evidence" $agentActivityFeed "agent_activity_filtered_feed_visible"

Write-Host "[phase3-hosted-fallback-activity] checks completed"
