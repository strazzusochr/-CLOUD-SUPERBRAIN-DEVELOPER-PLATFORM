param(
  [string]$BaseUrl = "http://localhost:8081"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Autonomous coding team verification failed: $label"
  }
}

function Get-HtmlElementsByTestId($html, $testId) {
  $pattern = '(?is)<[^>]*\bdata-testid\s*=\s*["'']' + [Regex]::Escape([string]$testId) + '["''][^>]*>'
  return @([Regex]::Matches([string]$html, $pattern) | ForEach-Object { $_.Value })
}

function Get-HtmlElementByTestId($html, $testId) {
  $elements = @(Get-HtmlElementsByTestId -html $html -testId $testId)
  Assert-True "agents page element $testId visible exactly once" ($elements.Count -eq 1)
  return $elements[0]
}

function Test-HtmlAttribute($element, $name, $expected) {
  $pattern = '(?is)\b' + [Regex]::Escape([string]$name) + '\s*=\s*["'']' + [Regex]::Escape([string]$expected) + '["'']'
  return [Regex]::IsMatch([string]$element, $pattern)
}

function Assert-HtmlAttribute($label, $element, $name, $expected) {
  Assert-True $label (Test-HtmlAttribute -element $element -name $name -expected $expected)
}

function Assert-HtmlAttributePresent($label, $element, $name) {
  $pattern = '(?is)\b' + [Regex]::Escape([string]$name) + '\s*=\s*["''][^"'']+["'']'
  Assert-True $label ([Regex]::IsMatch([string]$element, $pattern))
}

function Assert-DevOnlyUiBoundaries($html) {
  foreach ($required in @(
    "DEV-ONLY; hosted proof still blocked",
    "live_provider_calls=false",
    "live_mcp_writes=false",
    "production_deploy=false",
    "secret_output=false"
  )) {
    Assert-True "agents page boundary $required visible" ([string]$html).Contains($required)
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
  $payloadFile = Join-Path $env:TEMP ("autonomous-coding-team-" + [Guid]::NewGuid().ToString("N") + ".json")
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
    throw "Autonomous coding team verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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
$isLocalhost = $BaseUrl -match "^https?://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])(?::|/|$)"
Assert-True "dispatch proof is restricted to DEV-ONLY localhost" $isLocalhost

$teamContract = Invoke-JsonApi -url "$BaseUrl/api/v1/team/status/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "team contract version" ($teamContract.contract_version -eq "autonomous-coding-team-v1")
Assert-True "team mode" ($teamContract.mode -eq "logical_five_role_overlay_on_runtime_pool")
Assert-True "team contract roles" (@($teamContract.required_logical_roles) -join "," -eq "supervisor,planner,explorer,coder,tester")
Assert-True "team dispatch endpoint" ($teamContract.dispatch_endpoint -eq "POST /api/v1/task/dispatch")
Assert-True "team runtime endpoint" ($teamContract.runtime_endpoint -eq "GET /api/v1/team/status")

$dispatchContract = Invoke-JsonApi -url "$BaseUrl/api/v1/task/dispatch/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "dispatch contract version" ($dispatchContract.contract_version -eq "autonomous-task-dispatch-v1")
Assert-True "dispatch runtime endpoint" ($dispatchContract.runtime_endpoint -eq "POST /api/v1/task/dispatch")
Assert-True "dispatch status endpoint" ($dispatchContract.status_endpoint -eq "GET /api/v1/team/status")
Assert-True "dispatch roles" (@($dispatchContract.required_logical_roles) -join "," -eq "supervisor,planner,explorer,coder,tester")
Assert-True "supervisor maps to planner" ($dispatchContract.logical_to_execution_map.supervisor -eq "planner")
Assert-True "coder maps to coder" ($dispatchContract.logical_to_execution_map.coder -eq "coder")
Assert-True "tester maps to tester" ($dispatchContract.logical_to_execution_map.tester -eq "tester")

$projectId = "autonomous-team-" + [Guid]::NewGuid().ToString("N")
$sessionId = [Guid]::NewGuid().ToString()
$traceId = "autonomous-trace-" + [Guid]::NewGuid().ToString("N")
$dispatchBody = @{
  project_id = $projectId
  objective = "Implement autonomous coding team runtime surface and verify queue visibility"
  session_id = $sessionId
  trace_id = $traceId
  write_scope = @("services/agent-api/**", "apps/frontend/**", "scripts/**")
  acceptance_criteria = @("result_envelope", "done_validation", "audit_log", "runtime_visibility")
  constraints = @("maintain legacy 4-role contracts", "no production deploy")
} | ConvertTo-Json -Compress

$dispatch = Invoke-JsonApi -url "$BaseUrl/api/v1/task/dispatch" -method "POST" -body $dispatchBody -contentType "application/json" -timeoutSeconds 25
Assert-True "dispatch id returned" (-not [string]::IsNullOrWhiteSpace([string]$dispatch.dispatch_id))
Assert-True "dispatch session id returned" (-not [string]::IsNullOrWhiteSpace([string]$dispatch.session_id))
Assert-True "dispatch status queued or active" (@("queued", "active", "completed", "attention") -contains [string]$dispatch.status)
Assert-True "dispatch assignment count" (@($dispatch.assignments).Count -eq 5)
Assert-True "dispatch team mode" ($dispatch.team_mode -eq "logical_five_role_overlay_on_runtime_pool")
Assert-True "dispatch runtime source" ($dispatch.runtime_source -eq "internal_queue")
Assert-True "dispatch runtime pool contract version" ($dispatch.runtime_pool_contract_version -eq "task-assignment-queue-contract-v1")

$assignmentRoles = @($dispatch.assignments | ForEach-Object { [string]$_.logical_role })
foreach ($role in @("supervisor", "planner", "explorer", "coder", "tester")) {
  Assert-True "dispatch role $role present" ($assignmentRoles -contains $role)
}

foreach ($assignment in @($dispatch.assignments)) {
  Assert-True "assignment task id for $($assignment.logical_role)" (-not [string]::IsNullOrWhiteSpace([string]$assignment.task_id))
  Assert-True "assignment priority queue for $($assignment.logical_role)" (-not [string]::IsNullOrWhiteSpace([string]$assignment.priority_queue))
  Assert-True "assignment evidence ref for $($assignment.logical_role)" ($assignment.evidence_ref -eq "autonomous_team_dispatch_visible")
}

$escapedDispatchId = [Uri]::EscapeDataString([string]$dispatch.dispatch_id)
$teamStatus = Invoke-JsonApi -url "$BaseUrl/api/v1/team/status?dispatch_id=$escapedDispatchId" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "team status dispatch id parity" ($teamStatus.dispatch_id -eq $dispatch.dispatch_id)
Assert-True "team status mode" ($teamStatus.team_mode -eq "logical_five_role_overlay_on_runtime_pool")
Assert-True "team status runtime source visible" (-not [string]::IsNullOrWhiteSpace([string]$teamStatus.runtime_source))
Assert-True "team status runtime pool contract version" ($teamStatus.runtime_pool_contract_version -eq "task-assignment-queue-contract-v1")
Assert-True "team status member count" (@($teamStatus.members).Count -eq 5)
Assert-True "team status queue depth visible" ($null -ne $teamStatus.queue_depth)
Assert-True "team status high queue visible" ($null -ne $teamStatus.queue_depth_by_priority.high)
Assert-True "team status mid queue visible" ($null -ne $teamStatus.queue_depth_by_priority.mid)
Assert-True "team status low queue visible" ($null -ne $teamStatus.queue_depth_by_priority.low)

$memberRoles = @($teamStatus.members | ForEach-Object { [string]$_.logical_role })
foreach ($role in @("supervisor", "planner", "explorer", "coder", "tester")) {
  Assert-True "team member $role present" ($memberRoles -contains $role)
}

$coderMember = @($teamStatus.members) | Where-Object { $_.logical_role -eq "coder" } | Select-Object -First 1
$supervisorMember = @($teamStatus.members) | Where-Object { $_.logical_role -eq "supervisor" } | Select-Object -First 1
Assert-True "coder execution type" ($coderMember.execution_agent_type -eq "coder")
Assert-True "supervisor execution type" ($supervisorMember.execution_agent_type -eq "planner")
Assert-True "coder write scope visible" (@($coderMember.write_scope).Count -ge 1)

$agentsPage = Invoke-WebResponse -url "$BaseUrl/agents?dispatch_id=$escapedDispatchId" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "agents page returns 200 after dispatch" ($agentsPage.StatusCode -eq 200)
$codingTeamElement = Get-HtmlElementByTestId -html $agentsPage.Content -testId "autonomous-coding-team"
Assert-HtmlAttribute "agents page coding-team contract parity" $codingTeamElement "data-contract-version" $teamStatus.contract_version
Assert-HtmlAttributePresent "agents page coding-team status visible" $codingTeamElement "data-status"
Assert-HtmlAttribute "agents page coding-team mode parity" $codingTeamElement "data-team-mode" $teamStatus.team_mode
Assert-HtmlAttribute "agents page coding-team dispatch parity" $codingTeamElement "data-dispatch-id" $dispatch.dispatch_id
Assert-HtmlAttribute "agents page coding-team member-count parity" $codingTeamElement "data-member-count" ([string](@($teamStatus.members).Count))
Assert-HtmlAttribute "agents page coding-team runtime-source parity" $codingTeamElement "data-runtime-source" $teamStatus.runtime_source

$memberElements = @(Get-HtmlElementsByTestId -html $agentsPage.Content -testId "autonomous-coding-team-member")
Assert-True "agents page renders exactly five coding-team members" ($memberElements.Count -eq 5)
foreach ($member in @($teamStatus.members)) {
  $matchingMembers = @($memberElements | Where-Object {
    (Test-HtmlAttribute -element $_ -name "data-logical-role" -expected $member.logical_role) -and
    (Test-HtmlAttribute -element $_ -name "data-execution-agent-type" -expected $member.execution_agent_type)
  })
  Assert-True "agents page member parity for $($member.logical_role)" ($matchingMembers.Count -eq 1)
  Assert-HtmlAttributePresent "agents page member status visible for $($member.logical_role)" $matchingMembers[0] "data-status"
}
Assert-DevOnlyUiBoundaries $agentsPage.Content

foreach ($assignment in @($dispatch.assignments)) {
  $taskState = Invoke-JsonApi -url "$BaseUrl/api/v1/internal/tasks/$($assignment.task_id)" -method "GET" -contentType $null -timeoutSeconds 20
  Assert-True "task status visible for $($assignment.logical_role)" (@("queued", "running", "completed", "failed", "escalated", "abandoned_after_queue_drain") -contains [string]$taskState.task.status)
  Assert-True "task trace parity for $($assignment.logical_role)" ([string]$taskState.task.trace_id -eq $traceId)
}

$recentTasks = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=20" -method "GET" -contentType $null -timeoutSeconds 20
$recentForSession = @($recentTasks.tasks) | Where-Object { $_.session_id -eq $dispatch.session_id }
Assert-True "recent task visibility for dispatched session" (@($recentForSession).Count -ge 1)

Write-Host "[autonomous-coding-team] base_url=$BaseUrl"
Write-Host "[autonomous-coding-team] dispatch_id=$($dispatch.dispatch_id)"
Write-Host "[autonomous-coding-team] member_count=$(@($teamStatus.members).Count)"
Write-Host "[autonomous-coding-team] evidence_scope=DEV-ONLY"
Write-Host "[autonomous-coding-team] hosted_proof=false"
Write-Host "[autonomous-coding-team] production_deploy=false"
Write-Host "[autonomous-coding-team] result=verified"
