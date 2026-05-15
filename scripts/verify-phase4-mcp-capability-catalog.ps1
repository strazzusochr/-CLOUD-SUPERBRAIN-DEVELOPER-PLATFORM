param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "MCP capability catalog verification failed: $label"
  }
}

function Invoke-Text($url) {
  $python = @'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=30) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  return ($python | py -3 - $url)
}

function Invoke-JsonApi($url) {
  return (Invoke-Text $url | ConvertFrom-Json)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "MCP capability catalog proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase4-mcp-capability-catalog] base url: $BaseUrl"

$frontendHtml = Invoke-Text "$BaseUrl/"
Assert-True "frontend exposes mcp capability catalog panel" ($frontendHtml.Contains("MCP Capability Catalog"))
Assert-True "frontend exposes mcp capability catalog contract version" ($frontendHtml.Contains("mcp-capability-catalog-v1"))
Assert-True "frontend exposes mcp capability catalog evidence" ($frontendHtml.Contains("mcp_capability_catalog_visible"))
Assert-True "frontend exposes mcp capability catalog endpoint" ($frontendHtml.Contains("GET /mcp/api/v1/capabilities/catalog"))
Assert-True "frontend exposes no live writes marker" ($frontendHtml.Contains("live_mcp_writes=false"))

$health = Invoke-JsonApi "$BaseUrl/mcp/api/v1/health"
Assert-True "health catalog contract version" ($health.capability_catalog_contract_version -eq "mcp-capability-catalog-v1")
Assert-True "health catalog endpoint" ($health.capability_catalog_endpoint -eq "GET /mcp/api/v1/capabilities/catalog")
Assert-True "health catalog evidence" ($health.capability_catalog_evidence_ref -eq "mcp_capability_catalog_visible")
Assert-True "health no live writes" ($health.live_mcp_writes -eq $false)

$catalog = Invoke-JsonApi "$BaseUrl/mcp/api/v1/capabilities/catalog"
Assert-True "catalog contract version" ($catalog.contract_version -eq "mcp-capability-catalog-v1")
Assert-True "catalog status" ($catalog.status -eq "verified")
Assert-True "catalog mode" ($catalog.mode -eq "deterministic_mcp_capability_catalog")
Assert-True "catalog endpoint" ($catalog.endpoint -eq "GET /mcp/api/v1/capabilities/catalog")
Assert-True "catalog evidence" ($catalog.evidence_ref -eq "mcp_capability_catalog_visible")
Assert-True "catalog no live writes" ($catalog.live_mcp_writes -eq $false)
Assert-True "catalog no live mutations" ($catalog.live_mutations -eq $false)
Assert-True "catalog no external mcp server calls" ($catalog.external_mcp_server_calls -eq $false)
Assert-True "catalog toolset count" ([int]$catalog.toolset_count -ge 6)
Assert-True "catalog capability count" ([int]$catalog.capability_count -ge 6)

$toolsets = @($catalog.toolsets)
$toolsetNames = @($toolsets | ForEach-Object { [string]$_.toolset })
foreach ($required in @("github", "postgresql", "filesystem", "playwright", "e2b", "puppeteer")) {
  Assert-True "catalog toolset $required" ($toolsetNames -contains $required)
}

foreach ($toolset in $toolsets) {
  Assert-True "toolset $($toolset.toolset) no live writes" ($toolset.live_mcp_writes -eq $false)
  Assert-True "toolset $($toolset.toolset) no live mutation" ($toolset.live_mutation -eq $false)
  Assert-True "toolset $($toolset.toolset) requires audit" ($toolset.requires_audit -eq $true)
  Assert-True "toolset $($toolset.toolset) requires timeout" ($toolset.requires_timeout -eq $true)
  Assert-True "toolset $($toolset.toolset) unsupported capability guard" ($toolset.unsupported_capability_guard -eq "mcp_unsupported_capability_guard")
}

$github = $toolsets | Where-Object { $_.toolset -eq "github" } | Select-Object -First 1
Assert-True "github allowed branch pr plan" (@($github.supported_capabilities) -contains "plan_branch_pr")
Assert-True "github blocks delete branch" (@($github.blocked_capability_examples) -contains "delete_branch")
Assert-True "github contract version" ($github.contract_version -eq "github-branch-pr-plan-v1")

$e2b = $toolsets | Where-Object { $_.toolset -eq "e2b" } | Select-Object -First 1
Assert-True "e2b allowed lifecycle plan" (@($e2b.supported_capabilities) -contains "plan_sandbox_lifecycle")
Assert-True "e2b allowed timeout simulation" (@($e2b.supported_capabilities) -contains "simulate_timeout")
Assert-True "e2b blocks raw create sandbox" (@($e2b.blocked_capability_examples) -contains "create_sandbox")

$puppeteer = $toolsets | Where-Object { $_.toolset -eq "puppeteer" } | Select-Object -First 1
Assert-True "puppeteer no allowed capabilities" (@($puppeteer.supported_capabilities).Count -eq 0)
Assert-True "puppeteer blocks launch browser" (@($puppeteer.blocked_capability_examples) -contains "launch_browser")
Assert-True "puppeteer has no live contract" ($null -eq $puppeteer.contract_version)

Assert-True "guard unsupported toolset" ($catalog.guards.unsupported_toolset -eq "mcp_unsupported_toolset_guard")
Assert-True "guard unsupported capability" ($catalog.guards.unsupported_capability -eq "mcp_unsupported_capability_guard")
Assert-True "guard scope" ($catalog.guards.scope_guard -eq "mcp_scope_guard")
Assert-True "guard timeout" ($catalog.guards.timeout_guard -eq "mcp_timeout_guard")
Assert-True "guard redaction" ($catalog.guards.secret_redaction -eq "mcp_secret_redaction_guard")
Assert-True "guard denied audit correlation" ($catalog.guards.denied_audit_correlation -eq "mcp_denied_tool_audit_correlation")
Assert-True "catalog non claims" (@($catalog.non_claims).Count -ge 3)

$versionContract = Invoke-JsonApi "$BaseUrl/mcp/api/v1/version-pinning/contract"
Assert-True "version pinning carries catalog evidence" (@($versionContract.evidence_refs) -contains "mcp_capability_catalog_visible")
Assert-True "version pinning pinned contract count" (@($versionContract.pinned_tool_contracts).Count -ge 5)

Write-Host "status=verified"
Write-Host "contract_version=$($catalog.contract_version)"
Write-Host "evidence_ref=$($catalog.evidence_ref)"
Write-Host "toolset_count=$($catalog.toolset_count)"
Write-Host "capability_count=$($catalog.capability_count)"
