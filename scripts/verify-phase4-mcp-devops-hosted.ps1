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
    throw "Phase4 hosted mcp-devops verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted mcp-devops verification failed: $label"
  }
}

function Invoke-Text($url) {
  $python = @'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=20) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  return ($python | py -3 - $url)
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
request = urllib.request.Request(
    payload["url"],
    data=data,
    headers=headers,
    method=payload["method"],
)
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30)) as response:
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
  $payloadFile = Join-Path $env:TEMP ("phase4-mcp-devops-response-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  $parsed = $raw | ConvertFrom-Json
  return [pscustomobject]@{
    StatusCode = [int]$parsed.status_code
    Content = [string]$parsed.content
    Headers = $parsed.headers
  }
}

function Invoke-JsonApi($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = "application/json", $timeoutSeconds = 30) {
  $response = Invoke-WebResponse -url $url -method $method -body $body -headers $headers -contentType $contentType -timeoutSeconds $timeoutSeconds
  if ([int]$response.StatusCode -ge 400) {
    throw "Phase4 hosted mcp-devops verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
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
  throw "Phase4 hosted mcp-devops proof requires HTTPS"
}

Write-Host "[phase4-hosted-mcp-devops] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-Contains "frontend devops workflow panel" $frontendHtml "DevOps Workflow Dispatch"
Assert-Contains "frontend github branch pr panel" $frontendHtml "GitHub Branch/PR Contract"
Assert-Contains "frontend postgresql readonly panel" $frontendHtml "PostgreSQL Readonly Query Contract"
Assert-Contains "frontend filesystem scope panel" $frontendHtml "Filesystem Workspace Scope Contract"
Assert-Contains "frontend playwright panel" $frontendHtml "Playwright Browser Proof Contract"
Assert-Contains "frontend e2b panel" $frontendHtml "E2B Sandbox Lifecycle Contract"
Assert-Contains "frontend mcp version pinning panel" $frontendHtml "MCP Version Pinning Contract"

$mcpHealth = Invoke-Text "$BaseUrl/mcp/api/v1/health"
Assert-Contains "mcp gateway service" $mcpHealth '"service":"mcp-gateway"'

$githubBranchContract = Invoke-Text "$BaseUrl/mcp/api/v1/github/branch-pr/contract"
Assert-Contains "github branch contract version" $githubBranchContract '"contract_version":"github-branch-pr-plan-v1"'
Assert-Contains "github branch dry mode" $githubBranchContract '"mode":"dry_run_contract_only"'
Assert-Contains "github branch no live github" $githubBranchContract '"live_github_call":false'
Assert-Contains "github branch allowed pattern" $githubBranchContract "feature/agent-*"
Assert-Contains "github branch blocked evidence" $githubBranchContract "github_branch_pr_policy"

$postgresqlReadonlyContract = Invoke-Text "$BaseUrl/mcp/api/v1/postgresql/readonly-query/contract"
Assert-Contains "postgresql contract version" $postgresqlReadonlyContract '"contract_version":"postgresql-readonly-query-v1"'
Assert-Contains "postgresql dry mode" $postgresqlReadonlyContract '"mode":"dry_run_contract_only"'
Assert-Contains "postgresql no live db call" $postgresqlReadonlyContract '"live_database_call":false'
Assert-Contains "postgresql accepted evidence" $postgresqlReadonlyContract "postgresql_readonly_query_plan"
Assert-Contains "postgresql blocked evidence" $postgresqlReadonlyContract "postgresql_write_policy"

$filesystemWorkspaceContract = Invoke-Text "$BaseUrl/mcp/api/v1/filesystem/workspace-scope/contract"
Assert-Contains "filesystem contract version" $filesystemWorkspaceContract '"contract_version":"filesystem-workspace-scope-v1"'
Assert-Contains "filesystem dry mode" $filesystemWorkspaceContract '"mode":"dry_run_contract_only"'
Assert-Contains "filesystem no live filesystem call" $filesystemWorkspaceContract '"live_filesystem_call":false'
Assert-Contains "filesystem accepted evidence" $filesystemWorkspaceContract "filesystem_workspace_access_plan"
Assert-Contains "filesystem blocked evidence" $filesystemWorkspaceContract "filesystem_scope_policy"

$playwrightBrowserContract = Invoke-Text "$BaseUrl/mcp/api/v1/playwright/browser-proof/contract"
Assert-Contains "playwright contract version" $playwrightBrowserContract '"contract_version":"playwright-browser-proof-v1"'
Assert-Contains "playwright no live browser call" $playwrightBrowserContract '"live_browser_call":false'
Assert-Contains "playwright accepted evidence" $playwrightBrowserContract "playwright_browser_proof_plan"
Assert-Contains "playwright blocked evidence" $playwrightBrowserContract "playwright_browser_policy"

$e2bSandboxContract = Invoke-Text "$BaseUrl/mcp/api/v1/e2b/sandbox-lifecycle/contract"
Assert-Contains "e2b contract version" $e2bSandboxContract '"contract_version":"e2b-sandbox-lifecycle-v1"'
Assert-Contains "e2b no live call" $e2bSandboxContract '"live_e2b_call":false'
Assert-Contains "e2b accepted evidence" $e2bSandboxContract "e2b_sandbox_lifecycle_plan"
Assert-Contains "e2b blocked evidence" $e2bSandboxContract "e2b_sandbox_policy"
Assert-Contains "e2b degraded evidence" $e2bSandboxContract "mcp_degraded_missing_e2b_credentials"

$mcpVersionPinningContract = Invoke-Text "$BaseUrl/mcp/api/v1/version-pinning/contract"
Assert-Contains "version pinning contract version" $mcpVersionPinningContract '"contract_version":"mcp-version-pinning-v1"'
Assert-Contains "version pinning evidence" $mcpVersionPinningContract '"evidence_ref":"mcp_version_pinning_contract_visible"'
Assert-Contains "version pinning github contract" $mcpVersionPinningContract "github-branch-pr-plan-v1"
Assert-Contains "version pinning filesystem contract" $mcpVersionPinningContract "filesystem-workspace-scope-v1"
Assert-Contains "version pinning no live write" $mcpVersionPinningContract "No live MCP write"

$mcpTimeoutBody = @{
  tool_request_id = "hosted-timeout-proof"
  run_id = "hosted-proof"
  agent_role = "tester"
  toolset = "e2b"
  capability = "simulate_timeout"
  intent_summary = "prove timeout envelope"
  input_ref = "none"
  allowed_scope = "sandbox:test"
  timeout_ms = 25
  retry_budget = 1
  idempotency_key = "hosted-timeout-proof"
  audit_tags = @("hosted", "timeout")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpTimeout = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpTimeoutBody -contentType "application/json" -timeoutSeconds 15
Assert-True "mcp timeout path status timeout" ($mcpTimeout.status -eq "timeout")
Assert-True "mcp timeout audit persisted" ($mcpTimeout.audit_persisted -eq $true)

$mcpBlockedBody = @{
  tool_request_id = "hosted-main-block-proof"
  run_id = "hosted-proof"
  agent_role = "coder"
  toolset = "github"
  capability = "write_branch"
  intent_summary = "prove main branch block"
  input_ref = "none"
  allowed_scope = "refs/heads/main"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "hosted-main-block-proof"
  audit_tags = @("hosted", "scope")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpBlocked = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpBlockedBody -contentType "application/json" -timeoutSeconds 15
Assert-True "mcp blocked path status blocked" ($mcpBlocked.status -eq "blocked")
Assert-True "mcp blocked error class" ($mcpBlocked.error_class -eq "github_scope_violation")
Assert-True "mcp blocked audit persisted" ($mcpBlocked.audit_persisted -eq $true)

$mcpBranchPlanInput = @{
  branch = "feature/agent-coder-hosted-proof"
  title = "Hosted dry-run PR proof"
  base = "main"
  body = "Hosted verifier proves GitHub Branch/PR dry-run contract without mutation."
} | ConvertTo-Json -Compress
$mcpBranchPlanBody = @{
  tool_request_id = "hosted-github-branch-pr-plan"
  run_id = "hosted-proof"
  agent_role = "coder"
  toolset = "github"
  capability = "plan_branch_pr"
  intent_summary = "prove branch and pull request dry-run plan"
  input_ref = $mcpBranchPlanInput
  allowed_scope = "feature/agent-coder-hosted-proof"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "hosted-github-branch-pr-plan"
  audit_tags = @("hosted", "github", "branch-pr")
  redaction_required = $true
  expected_output_type = "github_plan"
} | ConvertTo-Json -Compress
$mcpBranchPlan = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpBranchPlanBody -contentType "application/json" -timeoutSeconds 15
Assert-True "mcp branch plan success" ($mcpBranchPlan.status -eq "success")
Assert-True "mcp branch plan evidence" ($mcpBranchPlan.evidence_ref -eq "github_branch_pr_plan")
Assert-True "mcp branch plan audit persisted" ($mcpBranchPlan.audit_persisted -eq $true)
Assert-True "mcp branch plan contract version" ($mcpBranchPlan.github_plan.contract_version -eq "github-branch-pr-plan-v1")
Assert-True "mcp branch plan no live github" ($mcpBranchPlan.github_plan.live_github_call -eq $false)
Assert-True "mcp branch allowed branch" ($mcpBranchPlan.github_plan.allowed_branch -eq "feature/agent-coder-hosted-proof")
Assert-True "mcp branch pr head" ($mcpBranchPlan.github_plan.pull_request_payload.head -eq "feature/agent-coder-hosted-proof")
Assert-True "mcp branch pr base" ($mcpBranchPlan.github_plan.pull_request_payload.base -eq "main")
Assert-True "mcp branch pr draft" ($mcpBranchPlan.github_plan.pull_request_payload.draft -eq $true)

$mcpBranchBlockedInput = @{
  branch = "main"
  title = "Forbidden main branch proof"
  base = "main"
  body = "Hosted verifier proves main branch plans are blocked."
} | ConvertTo-Json -Compress
$mcpBranchBlockedBody = @{
  tool_request_id = "hosted-github-branch-pr-block"
  run_id = "hosted-proof"
  agent_role = "coder"
  toolset = "github"
  capability = "plan_branch_pr"
  intent_summary = "prove branch plan policy block"
  input_ref = $mcpBranchBlockedInput
  allowed_scope = "main"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "hosted-github-branch-pr-block"
  audit_tags = @("hosted", "github", "branch-pr-block")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpBranchBlocked = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpBranchBlockedBody -contentType "application/json" -timeoutSeconds 15
Assert-True "mcp branch block status" ($mcpBranchBlocked.status -eq "blocked")
Assert-True "mcp branch block error" ($mcpBranchBlocked.error_class -eq "github_branch_policy_violation")
Assert-True "mcp branch block evidence" ($mcpBranchBlocked.evidence_ref -eq "github_branch_pr_policy")
Assert-True "mcp branch block audit persisted" ($mcpBranchBlocked.audit_persisted -eq $true)

$mcpPostgresqlPlanInput = @{
  sql = "SELECT id, name FROM projects LIMIT 5"
  parameters = @()
} | ConvertTo-Json -Compress
$mcpPostgresqlPlanBody = @{
  tool_request_id = "hosted-postgresql-readonly-plan"
  run_id = "hosted-proof"
  agent_role = "planner"
  toolset = "postgresql"
  capability = "query_readonly"
  intent_summary = "prove postgresql readonly query plan"
  input_ref = $mcpPostgresqlPlanInput
  allowed_scope = "project-context-readonly"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "hosted-postgresql-readonly-plan"
  audit_tags = @("hosted", "postgresql", "readonly")
  redaction_required = $true
  expected_output_type = "postgresql_plan"
} | ConvertTo-Json -Compress
$mcpPostgresqlPlan = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpPostgresqlPlanBody -contentType "application/json" -timeoutSeconds 15
Assert-True "mcp postgresql plan success" ($mcpPostgresqlPlan.status -eq "success")
Assert-True "mcp postgresql evidence" ($mcpPostgresqlPlan.evidence_ref -eq "postgresql_readonly_query_plan")
Assert-True "mcp postgresql audit persisted" ($mcpPostgresqlPlan.audit_persisted -eq $true)
Assert-True "mcp postgresql contract version" ($mcpPostgresqlPlan.postgresql_plan.contract_version -eq "postgresql-readonly-query-v1")
Assert-True "mcp postgresql no live db call" ($mcpPostgresqlPlan.postgresql_plan.live_database_call -eq $false)
Assert-True "mcp postgresql readonly true" ($mcpPostgresqlPlan.postgresql_plan.readonly -eq $true)

$mcpPostgresqlBlockedInput = @{
  sql = "UPDATE projects SET name = 'blocked'"
  parameters = @()
} | ConvertTo-Json -Compress
$mcpPostgresqlBlockedBody = @{
  tool_request_id = "hosted-postgresql-write-block"
  run_id = "hosted-proof"
  agent_role = "planner"
  toolset = "postgresql"
  capability = "query_readonly"
  intent_summary = "prove postgresql write policy block"
  input_ref = $mcpPostgresqlBlockedInput
  allowed_scope = "project-context-readonly"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "hosted-postgresql-write-block"
  audit_tags = @("hosted", "postgresql", "write-block")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpPostgresqlBlocked = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpPostgresqlBlockedBody -contentType "application/json" -timeoutSeconds 15
Assert-True "mcp postgresql blocked status" ($mcpPostgresqlBlocked.status -eq "blocked")
Assert-True "mcp postgresql blocked error" ($mcpPostgresqlBlocked.error_class -eq "postgresql_write_policy_violation")
Assert-True "mcp postgresql blocked evidence" ($mcpPostgresqlBlocked.evidence_ref -eq "postgresql_write_policy")
Assert-True "mcp postgresql blocked audit persisted" ($mcpPostgresqlBlocked.audit_persisted -eq $true)

$mcpFilesystemPlanInput = @{
  operation = "read_file"
  path = "/tmp/agent-workspace/context/task.md"
} | ConvertTo-Json -Compress
$mcpFilesystemPlanBody = @{
  tool_request_id = "hosted-filesystem-workspace-plan"
  run_id = "hosted-proof"
  agent_role = "coder"
  toolset = "filesystem"
  capability = "plan_workspace_access"
  intent_summary = "prove filesystem workspace scope plan"
  input_ref = $mcpFilesystemPlanInput
  allowed_scope = "/tmp/agent-workspace/context"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "hosted-filesystem-workspace-plan"
  audit_tags = @("hosted", "filesystem", "workspace")
  redaction_required = $true
  expected_output_type = "filesystem_plan"
} | ConvertTo-Json -Compress
$mcpFilesystemPlan = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpFilesystemPlanBody -contentType "application/json" -timeoutSeconds 15
Assert-True "mcp filesystem plan success" ($mcpFilesystemPlan.status -eq "success")
Assert-True "mcp filesystem evidence" ($mcpFilesystemPlan.evidence_ref -eq "filesystem_workspace_access_plan")
Assert-True "mcp filesystem audit persisted" ($mcpFilesystemPlan.audit_persisted -eq $true)
Assert-True "mcp filesystem contract version" ($mcpFilesystemPlan.filesystem_plan.contract_version -eq "filesystem-workspace-scope-v1")
Assert-True "mcp filesystem no live fs call" ($mcpFilesystemPlan.filesystem_plan.live_filesystem_call -eq $false)

$mcpFilesystemBlockedInput = @{
  operation = "read_file"
  path = "/etc/passwd"
} | ConvertTo-Json -Compress
$mcpFilesystemBlockedBody = @{
  tool_request_id = "hosted-filesystem-scope-block"
  run_id = "hosted-proof"
  agent_role = "coder"
  toolset = "filesystem"
  capability = "plan_workspace_access"
  intent_summary = "prove filesystem host path block"
  input_ref = $mcpFilesystemBlockedInput
  allowed_scope = "/etc"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "hosted-filesystem-scope-block"
  audit_tags = @("hosted", "filesystem", "scope-block")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpFilesystemBlocked = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpFilesystemBlockedBody -contentType "application/json" -timeoutSeconds 15
Assert-True "mcp filesystem blocked status" ($mcpFilesystemBlocked.status -eq "blocked")
Assert-True "mcp filesystem blocked error" ($mcpFilesystemBlocked.error_class -eq "filesystem_scope_policy_violation")
Assert-True "mcp filesystem blocked evidence" ($mcpFilesystemBlocked.evidence_ref -eq "filesystem_scope_policy")
Assert-True "mcp filesystem blocked audit persisted" ($mcpFilesystemBlocked.audit_persisted -eq $true)

$mcpPlaywrightPlanInput = @{
  action = "take_screenshot"
  target_url = "http://localhost:8081"
} | ConvertTo-Json -Compress
$mcpPlaywrightPlanBody = @{
  tool_request_id = "hosted-playwright-browser-proof-plan"
  run_id = "hosted-proof"
  agent_role = "tester"
  toolset = "playwright"
  capability = "plan_browser_proof"
  intent_summary = "prove playwright browser proof plan"
  input_ref = $mcpPlaywrightPlanInput
  allowed_scope = "browser-proof-localhost"
  timeout_ms = 120000
  retry_budget = 0
  idempotency_key = "hosted-playwright-browser-proof-plan"
  audit_tags = @("hosted", "playwright", "browser-proof")
  redaction_required = $true
  expected_output_type = "playwright_plan"
} | ConvertTo-Json -Compress
$mcpPlaywrightPlan = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpPlaywrightPlanBody -contentType "application/json" -timeoutSeconds 20
Assert-True "mcp playwright plan success" ($mcpPlaywrightPlan.status -eq "success")
Assert-True "mcp playwright evidence" ($mcpPlaywrightPlan.evidence_ref -eq "playwright_browser_proof_plan")
Assert-True "mcp playwright audit persisted" ($mcpPlaywrightPlan.audit_persisted -eq $true)
Assert-True "mcp playwright contract version" ($mcpPlaywrightPlan.playwright_plan.contract_version -eq "playwright-browser-proof-v1")
Assert-True "mcp playwright no live browser" ($mcpPlaywrightPlan.playwright_plan.live_browser_call -eq $false)

$mcpPlaywrightBlockedInput = @{
  action = "navigate_to_url"
  target_url = "file:///etc/passwd"
} | ConvertTo-Json -Compress
$mcpPlaywrightBlockedBody = @{
  tool_request_id = "hosted-playwright-browser-policy-block"
  run_id = "hosted-proof"
  agent_role = "tester"
  toolset = "playwright"
  capability = "plan_browser_proof"
  intent_summary = "prove playwright forbidden target block"
  input_ref = $mcpPlaywrightBlockedInput
  allowed_scope = "browser-proof-localhost"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "hosted-playwright-browser-policy-block"
  audit_tags = @("hosted", "playwright", "policy-block")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpPlaywrightBlocked = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpPlaywrightBlockedBody -contentType "application/json" -timeoutSeconds 15
Assert-True "mcp playwright blocked status" ($mcpPlaywrightBlocked.status -eq "blocked")
Assert-True "mcp playwright blocked error" ($mcpPlaywrightBlocked.error_class -eq "playwright_browser_policy_violation")
Assert-True "mcp playwright blocked evidence" ($mcpPlaywrightBlocked.evidence_ref -eq "playwright_browser_policy")
Assert-True "mcp playwright blocked audit persisted" ($mcpPlaywrightBlocked.audit_persisted -eq $true)

$mcpE2bPlanInput = @{
  action = "execute_code"
  code = "pytest -q"
  close_sandbox_finally = $true
} | ConvertTo-Json -Compress
$mcpE2bPlanBody = @{
  tool_request_id = "hosted-e2b-sandbox-lifecycle-plan"
  run_id = "hosted-proof"
  agent_role = "tester"
  toolset = "e2b"
  capability = "plan_sandbox_lifecycle"
  intent_summary = "prove e2b sandbox lifecycle plan"
  input_ref = $mcpE2bPlanInput
  allowed_scope = "sandbox:test"
  timeout_ms = 1800000
  retry_budget = 0
  idempotency_key = "hosted-e2b-sandbox-lifecycle-plan"
  audit_tags = @("hosted", "e2b", "sandbox-lifecycle")
  redaction_required = $true
  expected_output_type = "e2b_plan"
} | ConvertTo-Json -Compress
$mcpE2bPlan = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpE2bPlanBody -contentType "application/json" -timeoutSeconds 20
Assert-True "mcp e2b plan success" ($mcpE2bPlan.status -eq "success")
Assert-True "mcp e2b evidence" ($mcpE2bPlan.evidence_ref -eq "e2b_sandbox_lifecycle_plan")
Assert-True "mcp e2b audit persisted" ($mcpE2bPlan.audit_persisted -eq $true)
Assert-True "mcp e2b contract version" ($mcpE2bPlan.e2b_plan.contract_version -eq "e2b-sandbox-lifecycle-v1")
Assert-True "mcp e2b no live call" ($mcpE2bPlan.e2b_plan.live_e2b_call -eq $false)
Assert-True "mcp e2b finally close required" ($mcpE2bPlan.e2b_plan.close_sandbox_finally -eq $true)

$mcpE2bBlockedInput = @{
  action = "execute_code"
  code = "pytest -q"
  close_sandbox_finally = $false
} | ConvertTo-Json -Compress
$mcpE2bBlockedBody = @{
  tool_request_id = "hosted-e2b-sandbox-policy-block"
  run_id = "hosted-proof"
  agent_role = "tester"
  toolset = "e2b"
  capability = "plan_sandbox_lifecycle"
  intent_summary = "prove e2b missing finally close block"
  input_ref = $mcpE2bBlockedInput
  allowed_scope = "sandbox:test"
  timeout_ms = 120000
  retry_budget = 0
  idempotency_key = "hosted-e2b-sandbox-policy-block"
  audit_tags = @("hosted", "e2b", "policy-block")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpE2bBlocked = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpE2bBlockedBody -contentType "application/json" -timeoutSeconds 15
Assert-True "mcp e2b blocked status" ($mcpE2bBlocked.status -eq "blocked")
Assert-True "mcp e2b blocked error" ($mcpE2bBlocked.error_class -eq "e2b_sandbox_policy_violation")
Assert-True "mcp e2b blocked evidence" ($mcpE2bBlocked.evidence_ref -eq "e2b_sandbox_policy")
Assert-True "mcp e2b blocked audit persisted" ($mcpE2bBlocked.audit_persisted -eq $true)

$mcpDegradedBody = @{
  tool_request_id = "hosted-e2b-degraded-proof"
  run_id = "hosted-proof"
  agent_role = "tester"
  toolset = "e2b"
  capability = "create_sandbox"
  intent_summary = "prove degraded missing e2b credentials"
  input_ref = "none"
  allowed_scope = "sandbox:test"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "hosted-e2b-degraded-proof"
  audit_tags = @("hosted", "degraded")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress
$mcpDegraded = Invoke-JsonApi -url "$BaseUrl/mcp/api/v1/tools/execute" -method "POST" -body $mcpDegradedBody -contentType "application/json" -timeoutSeconds 15
Assert-True "mcp degraded status" ($mcpDegraded.status -eq "degraded")
Assert-True "mcp degraded error class" ($mcpDegraded.error_class -eq "missing_credentials")
Assert-True "mcp degraded audit persisted" ($mcpDegraded.audit_persisted -eq $true)

$mcpAuditEvents = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=100"
foreach ($needle in @(
  "mcp_tool_executed",
  "hosted-timeout-proof",
  "hosted-main-block-proof",
  "hosted-github-branch-pr-plan",
  "hosted-github-branch-pr-block",
  "hosted-postgresql-readonly-plan",
  "hosted-postgresql-write-block",
  "hosted-filesystem-workspace-plan",
  "hosted-filesystem-scope-block",
  "hosted-playwright-browser-proof-plan",
  "hosted-playwright-browser-policy-block",
  "hosted-e2b-sandbox-lifecycle-plan",
  "hosted-e2b-sandbox-policy-block",
  "hosted-e2b-degraded-proof"
)) {
  Assert-Contains "mcp audit event $needle" $mcpAuditEvents $needle
}

$mcpAuditFeed = Invoke-Text "$BaseUrl/api/v1/audit/mcp?limit=100"
foreach ($needle in @(
  "mcp_tool_executed",
  "hosted-timeout-proof",
  "hosted-main-block-proof",
  "hosted-github-branch-pr-plan",
  "hosted-postgresql-readonly-plan",
  "hosted-filesystem-workspace-plan",
  "hosted-playwright-browser-proof-plan",
  "hosted-e2b-sandbox-lifecycle-plan",
  '"status":"timeout"',
  '"status":"blocked"',
  '"status":"degraded"'
)) {
  Assert-Contains "mcp audit feed $needle" $mcpAuditFeed $needle
}

$workflowPlan = Invoke-Text "$BaseUrl/api/v1/devops/workflow-dispatch/plan"
Assert-Contains "workflow contract version" $workflowPlan '"contract_version":"devops-workflow-dispatch-v1"'
Assert-Contains "workflow dry mode" $workflowPlan '"mode":"dry_run_contract_only"'
Assert-Contains "workflow no live github" $workflowPlan '"live_github_call":false'
Assert-Contains "workflow github endpoint" $workflowPlan "/actions/workflows/main-deploy.yml/dispatches"

$workflowReadyBody = @{
  workflow_id = "main-deploy.yml"
  ref = "main"
  environment = "staging"
  action = "deploy"
  image_tag = "ghcr.io/repo/agent-api:hosted-proof"
  reason = "hosted staging dispatch proof"
  trace_id = "hosted-devops-dispatch-ready"
  human_review_approved = $false
  dry_run = $true
} | ConvertTo-Json -Compress
$workflowReady = Invoke-JsonApi -url "$BaseUrl/api/v1/devops/workflow-dispatch/validate" -method "POST" -body $workflowReadyBody -contentType "application/json" -timeoutSeconds 15
Assert-True "workflow ready status" ($workflowReady.status -eq "ready")
Assert-True "workflow ready no live github" ($workflowReady.live_github_call -eq $false)

$workflowBlockedBody = @{
  workflow_id = "main-deploy.yml"
  ref = "main"
  environment = "production"
  action = "deploy"
  image_tag = "ghcr.io/repo/agent-api:hosted-proof"
  reason = "hosted production block proof"
  trace_id = "hosted-devops-dispatch-blocked"
  human_review_approved = $false
  dry_run = $true
} | ConvertTo-Json -Compress
$workflowBlockedResponse = Invoke-WebResponse -url "$BaseUrl/api/v1/devops/workflow-dispatch/validate" -method "POST" -body $workflowBlockedBody -contentType "application/json" -timeoutSeconds 15
Assert-True "workflow blocked http 403" ([string]$workflowBlockedResponse.StatusCode -eq "403")
$workflowBlockedOut = $workflowBlockedResponse.Content
Assert-Contains "workflow blocked code" $workflowBlockedOut "workflow_dispatch_blocked"
Assert-Contains "workflow blocked human gate" $workflowBlockedOut "production workflow dispatch requires human_review_approved=true"

$workflowAudit = Invoke-Text "$BaseUrl/api/v1/audit/recent?limit=40"
Assert-Contains "workflow audit event" $workflowAudit "devops_workflow_dispatch_contract"
Assert-Contains "workflow audit ready trace" $workflowAudit "hosted-devops-dispatch-ready"
Assert-Contains "workflow audit blocked trace" $workflowAudit "hosted-devops-dispatch-blocked"

Write-Host "[phase4-hosted-mcp-devops] checks completed"
