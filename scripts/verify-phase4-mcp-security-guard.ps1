param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "MCP security guard verification failed: $label"
  }
}

function Invoke-RawHttp($Url, $Method = "GET", $Body = $null) {
  $payload = [ordered]@{
    url = $Url
    method = $Method
  }
  if ($null -ne $Body) {
    $payload.body_b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes([string]$Body))
  }
  $payloadFile = Join-Path $env:TEMP ("mcp-guard-http-" + [Guid]::NewGuid().ToString("N") + ".json")
  $pythonFile = Join-Path $env:TEMP ("mcp-guard-http-" + [Guid]::NewGuid().ToString("N") + ".py")
  try {
    Set-Content -LiteralPath $payloadFile -Value ($payload | ConvertTo-Json -Compress -Depth 5) -NoNewline -Encoding utf8
    $pythonScript = @'
import base64
import json
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8-sig") as handle:
    payload = json.load(handle)

data = None
headers = {}
if payload.get("body_b64"):
    data = base64.b64decode(payload["body_b64"])
    headers["Content-Type"] = "application/json"

request = urllib.request.Request(payload["url"], data=data, headers=headers, method=payload.get("method", "GET"))
try:
    with urllib.request.urlopen(request, timeout=60) as response:
        content = response.read().decode("utf-8", errors="replace")
        print(json.dumps({"StatusCode": response.status, "Content": content}))
except urllib.error.HTTPError as exc:
    content = exc.read().decode("utf-8", errors="replace")
    print(json.dumps({"StatusCode": exc.code, "Content": content}))
'@
    Set-Content -LiteralPath $pythonFile -Value $pythonScript -NoNewline -Encoding utf8
    $output = py -3 $pythonFile $payloadFile
    if ($LASTEXITCODE -ne 0) {
      throw ($output | Out-String)
    }
    return ($output | ConvertFrom-Json)
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
    if (Test-Path $pythonFile) { Remove-Item -LiteralPath $pythonFile -Force }
  }
}

function Invoke-JsonApi($url, $method = "GET", $body = $null) {
  $response = Invoke-RawHttp -Url $url -Method $method -Body $body
  if ([int]$response.StatusCode -ge 400) {
    throw "$method $url returned HTTP $($response.StatusCode): $($response.Content)"
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "MCP security guard proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase4-mcp-security-guard] base url: $BaseUrl"

$versionContract = Invoke-JsonApi "$BaseUrl/mcp/api/v1/version-pinning/contract"
Assert-True "unsupported puppeteer listed" (@($versionContract.request_contract.unsupported_toolsets_blocked) -contains "puppeteer")
Assert-True "unsupported toolset evidence listed" (@($versionContract.evidence_refs) -contains "mcp_unsupported_toolset_guard")
Assert-True "unsupported capability evidence listed" (@($versionContract.evidence_refs) -contains "mcp_unsupported_capability_guard")
Assert-True "unsupported capability guard mode" ($versionContract.capability_guard.mode -eq "fail_closed_unknown_capability")
Assert-True "github supported capability visible" (@($versionContract.capability_guard.supported_capabilities.github) -contains "plan_branch_pr")
Assert-True "redaction evidence listed" (@($versionContract.evidence_refs) -contains "mcp_secret_redaction_guard")

$githubContract = Invoke-JsonApi "$BaseUrl/mcp/api/v1/github/branch-pr/contract"
Assert-True "github redaction evidence" ($githubContract.evidence_refs.redaction -eq "mcp_secret_redaction_guard")

$puppeteerBody = @{
  tool_request_id = "phase4-puppeteer-block"
  run_id = "phase4-proof"
  agent_role = "tester"
  toolset = "puppeteer"
  capability = "launch_browser"
  intent_summary = "prove unsupported puppeteer is blocked"
  input_ref = "{}"
  allowed_scope = "browser-proof-localhost"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "phase4-puppeteer-block"
  audit_tags = @("phase4", "mcp", "puppeteer-block")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress

$puppeteer = Invoke-JsonApi "$BaseUrl/mcp/api/v1/tools/execute" "POST" $puppeteerBody
Assert-True "puppeteer blocked status" ($puppeteer.status -eq "blocked")
Assert-True "puppeteer blocked error" ($puppeteer.error_class -eq "unsupported_toolset")
Assert-True "puppeteer blocked evidence" ($puppeteer.evidence_ref -eq "mcp_unsupported_toolset_guard")

$unsupportedCapabilityBody = @{
  tool_request_id = "phase4-github-delete-branch-block"
  run_id = "phase4-proof"
  agent_role = "devops"
  toolset = "github"
  capability = "delete_branch"
  intent_summary = "prove unsupported github delete branch is blocked"
  input_ref = "{}"
  allowed_scope = "feature/agent-delete-proof"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "phase4-github-delete-branch-block"
  audit_tags = @("phase4", "mcp", "unsupported-capability")
  redaction_required = $true
  expected_output_type = "tool_result"
} | ConvertTo-Json -Compress

$unsupportedCapability = Invoke-JsonApi "$BaseUrl/mcp/api/v1/tools/execute" "POST" $unsupportedCapabilityBody
Assert-True "unsupported capability blocked status" ($unsupportedCapability.status -eq "blocked")
Assert-True "unsupported capability blocked error" ($unsupportedCapability.error_class -eq "unsupported_capability")
Assert-True "unsupported capability blocked evidence" ($unsupportedCapability.evidence_ref -eq "mcp_unsupported_capability_guard")
Assert-True "unsupported capability audit" ($unsupportedCapability.audit_persisted -eq $true)

$secretBodyText = "Contains ghp_abcdefghijklmnopqrstuvwxyz123456 and token=supersecretvalue12345 and sk-testsecretvalue12345"
$githubInput = @{
  branch = "feature/agent-redaction-proof"
  title = "Redaction proof"
  base = "main"
  body = $secretBodyText
} | ConvertTo-Json -Compress
$githubBody = @{
  tool_request_id = "phase4-github-redaction"
  run_id = "phase4-proof"
  agent_role = "devops"
  toolset = "github"
  capability = "plan_branch_pr"
  intent_summary = "prove branch pr body redaction"
  input_ref = $githubInput
  allowed_scope = "feature/agent-redaction-proof"
  timeout_ms = 1000
  retry_budget = 0
  idempotency_key = "phase4-github-redaction"
  audit_tags = @("phase4", "mcp", "redaction")
  redaction_required = $true
  expected_output_type = "github_plan"
} | ConvertTo-Json -Compress

$github = Invoke-JsonApi "$BaseUrl/mcp/api/v1/tools/execute" "POST" $githubBody
Assert-True "github plan success" ($github.status -eq "success")
Assert-True "github redaction applied" ($github.github_plan.redaction.applied -eq $true)
Assert-True "github redaction evidence" ($github.github_plan.redaction.evidence_ref -eq "mcp_secret_redaction_guard")
$body = [string]$github.github_plan.pull_request_payload.body
Assert-True "github body no ghp token" (-not $body.Contains("ghp_abcdefghijklmnopqrstuvwxyz123456"))
Assert-True "github body no token value" (-not $body.Contains("supersecretvalue12345"))
Assert-True "github body no sk token" (-not $body.Contains("sk-testsecretvalue12345"))
Assert-True "github body contains redaction marker" ($body.Contains("[REDACTED_") -or $body.Contains("[REDACTED_SECRET]"))

Write-Host "[phase4-mcp-security-guard] ok"
