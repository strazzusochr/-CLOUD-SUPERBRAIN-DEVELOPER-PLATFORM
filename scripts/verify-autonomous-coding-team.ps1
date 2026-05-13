param(
  [string]$BaseUrl = "http://localhost:8081"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Autonomous coding team verification failed: $label"
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
Assert-True "dispatch assignment dispatch_id contract" (@($dispatchContract.required_assignment_fields) -contains "dispatch_id")
Assert-True "dispatch assignment provenance contract" (@($dispatchContract.required_assignment_fields) -contains "provenance_evidence_ref")

$homepage = Invoke-WebResponse -url "$BaseUrl/" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "homepage returns 200" ($homepage.StatusCode -eq 200)
Assert-True "homepage autonomous coding team marker" ($homepage.Content.Contains("Autonomous Coding Team"))

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
  Assert-True "assignment dispatch id parity for $($assignment.logical_role)" ([string]$assignment.dispatch_id -eq [string]$dispatch.dispatch_id)
  Assert-True "assignment task id for $($assignment.logical_role)" (-not [string]::IsNullOrWhiteSpace([string]$assignment.task_id))
  Assert-True "assignment priority queue for $($assignment.logical_role)" (-not [string]::IsNullOrWhiteSpace([string]$assignment.priority_queue))
  Assert-True "assignment evidence ref for $($assignment.logical_role)" ($assignment.evidence_ref -eq "autonomous_team_dispatch_visible")
  Assert-True "assignment provenance ref for $($assignment.logical_role)" ($assignment.provenance_evidence_ref -eq "autonomous_team_dispatch_task_provenance")
}

$teamStatus = Invoke-JsonApi -url "$BaseUrl/api/v1/team/status?dispatch_id=$($dispatch.dispatch_id)" -method "GET" -contentType $null -timeoutSeconds 20
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
Assert-True "coder dispatch id visible" ([string]$coderMember.dispatch_id -eq [string]$dispatch.dispatch_id)
Assert-True "coder provenance visible" ($coderMember.provenance_evidence_ref -eq "autonomous_team_dispatch_task_provenance")

foreach ($assignment in @($dispatch.assignments)) {
  $taskState = Invoke-JsonApi -url "$BaseUrl/api/v1/internal/tasks/$($assignment.task_id)" -method "GET" -contentType $null -timeoutSeconds 20
  Assert-True "task status visible for $($assignment.logical_role)" (@("queued", "running", "completed", "failed", "escalated", "abandoned_after_queue_drain") -contains [string]$taskState.task.status)
  Assert-True "task trace parity for $($assignment.logical_role)" ([string]$taskState.task.trace_id -eq $traceId)
  Assert-True "task dispatch parity for $($assignment.logical_role)" ([string]$taskState.task.dispatch_id -eq [string]$dispatch.dispatch_id)
  Assert-True "task logical role parity for $($assignment.logical_role)" ([string]$taskState.task.logical_role -eq [string]$assignment.logical_role)
  Assert-True "task provenance parity for $($assignment.logical_role)" ([string]$taskState.task.provenance_evidence_ref -eq "autonomous_team_dispatch_task_provenance")
}

$recentTasks = Invoke-JsonApi -url "$BaseUrl/api/v1/tasks/recent?limit=20" -method "GET" -contentType $null -timeoutSeconds 20
$recentForSession = @($recentTasks.tasks) | Where-Object { $_.session_id -eq $dispatch.session_id }
Assert-True "recent task visibility for dispatched session" (@($recentForSession).Count -ge 5)
foreach ($assignment in @($dispatch.assignments)) {
  $recentTask = @($recentForSession) | Where-Object { $_.task_id -eq $assignment.task_id } | Select-Object -First 1
  Assert-True "recent task present for $($assignment.logical_role)" ($null -ne $recentTask)
  Assert-True "recent task dispatch parity for $($assignment.logical_role)" ([string]$recentTask.dispatch_id -eq [string]$dispatch.dispatch_id)
  Assert-True "recent task logical role parity for $($assignment.logical_role)" ([string]$recentTask.logical_role -eq [string]$assignment.logical_role)
  Assert-True "recent task provenance parity for $($assignment.logical_role)" ([string]$recentTask.provenance_evidence_ref -eq "autonomous_team_dispatch_task_provenance")
}

Write-Host "[autonomous-coding-team] base_url=$BaseUrl"
Write-Host "[autonomous-coding-team] dispatch_id=$($dispatch.dispatch_id)"
Write-Host "[autonomous-coding-team] result=verified"
