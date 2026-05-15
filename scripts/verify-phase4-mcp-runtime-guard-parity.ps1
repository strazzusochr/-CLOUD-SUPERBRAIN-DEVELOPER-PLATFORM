param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "MCP runtime guard parity verification failed: $label"
  }
}

function Invoke-Text($url) {
  $scriptPath = [System.IO.Path]::GetTempFileName() + ".py"
  $python = @'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=30) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  try {
    Set-Content -LiteralPath $scriptPath -Value $python -Encoding UTF8
    $output = & py -3 $scriptPath $url
    if ($LASTEXITCODE -ne 0) {
      throw "HTTP request failed for $url"
    }
    return $output
  } finally {
    Remove-Item -LiteralPath $scriptPath -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-JsonApi($url) {
  return (Invoke-Text $url | ConvertFrom-Json)
}

function Assert-NoSecretLeak($label, $value) {
  $text = ($value | ConvertTo-Json -Depth 100)
  $forbidden = @(
    'sk-[A-Za-z0-9_-]{20,}',
    'ghp_[A-Za-z0-9_]{20,}',
    'xox[baprs]-[A-Za-z0-9-]{20,}',
    'AKIA[0-9A-Z]{16}',
    'BEGIN (RSA|OPENSSH|PRIVATE) KEY',
    'OPENAI_API_KEY\s*[:=]\s*["''][^"'']+'
  )
  foreach ($pattern in $forbidden) {
    Assert-True "$label has no forbidden secret pattern $pattern" (-not ($text -match $pattern))
  }
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "MCP runtime guard parity proof refuses localhost unless -AllowLocalhost is set"
}

Write-Host "[phase4-mcp-runtime-guard-parity] base url: $BaseUrl"

$parity = Invoke-JsonApi "$BaseUrl/api/v1/agents/mcp-runtime-guard-parity"
Assert-NoSecretLeak "parity payload" $parity
$directGateway = Invoke-JsonApi "$BaseUrl/mcp/api/v1/runtime/guard-parity"
$directVersion = Invoke-JsonApi "$BaseUrl/mcp/api/v1/version-pinning/contract"
$directCatalog = Invoke-JsonApi "$BaseUrl/mcp/api/v1/capabilities/catalog"
Assert-NoSecretLeak "direct gateway payload" $directGateway
Assert-NoSecretLeak "direct version payload" $directVersion
Assert-NoSecretLeak "direct catalog payload" $directCatalog

Assert-True "contract version" ($parity.contract_version -eq "mcp-runtime-guard-parity-v1")
Assert-True "status verified" ($parity.status -eq "verified")
Assert-True "mode" ($parity.mode -eq "agent_api_to_mcp_gateway_runtime_guard_parity")
Assert-True "endpoint" ($parity.endpoint -eq "GET /api/v1/agents/mcp-runtime-guard-parity")
Assert-True "evidence" ($parity.evidence_ref -eq "mcp_runtime_guard_parity_visible")
Assert-True "no live writes" ($parity.live_mcp_writes -eq $false)
Assert-True "no live mutations" ($parity.live_mutations -eq $false)
Assert-True "no external mcp calls" ($parity.external_mcp_server_calls -eq $false)
Assert-True "no model downloads" ($parity.model_downloads -eq $false)
Assert-True "snapshots redacted" ($parity.snapshots_redacted -eq $true)
Assert-True "snapshot redaction policy" ($parity.snapshot_redaction_policy -eq "app.security.redact_json")
Assert-True "gateway endpoint" ($parity.gateway_endpoint -eq "GET /mcp/api/v1/runtime/guard-parity")
Assert-True "no gateway error" ($null -eq $parity.gateway_error)

$requiredEvidence = @(
  "mcp_runtime_guard_parity_visible",
  "mcp_version_pinning_contract_visible",
  "mcp_capability_catalog_visible",
  "mcp_secret_redaction_guard",
  "mcp_unsupported_toolset_guard",
  "mcp_unsupported_capability_guard",
  "mcp_denied_tool_audit_correlation"
)
foreach ($evidence in $requiredEvidence) {
  Assert-True "evidence ref $evidence" (@($parity.evidence_refs) -contains $evidence)
}

$gateway = $parity.gateway_snapshot
Assert-True "gateway snapshot exists" ($null -ne $gateway)
Assert-True "gateway snapshot contract" ($gateway.contract_version -eq "mcp-runtime-guard-parity-v1")
Assert-True "gateway snapshot status" ($gateway.status -eq "verified")
Assert-True "gateway snapshot mode" ($gateway.mode -eq "deterministic_mcp_runtime_guard_parity")
Assert-True "gateway snapshot endpoint" ($gateway.endpoint -eq "GET /mcp/api/v1/runtime/guard-parity")
Assert-True "gateway snapshot evidence" ($gateway.evidence_ref -eq "mcp_runtime_guard_parity_visible")
Assert-True "gateway snapshot no live writes" ($gateway.live_mcp_writes -eq $false)
Assert-True "gateway snapshot no live mutations" ($gateway.live_mutations -eq $false)
Assert-True "gateway snapshot no external mcp calls" ($gateway.external_mcp_server_calls -eq $false)
Assert-True "gateway snapshot no model downloads" ($gateway.model_downloads -eq $false)
Assert-True "gateway deep compare contract" ($gateway.contract_version -eq $directGateway.contract_version)
Assert-True "gateway deep compare evidence" ($gateway.evidence_ref -eq $directGateway.evidence_ref)
Assert-True "gateway deep compare guard count" (@($gateway.guard_matrix).Count -eq @($directGateway.guard_matrix).Count)
foreach ($evidence in $requiredEvidence) {
  Assert-True "gateway snapshot carries $evidence" (@($gateway.evidence_refs) -contains $evidence)
}

foreach ($guard in @($gateway.guard_matrix)) {
  Assert-True "gateway guard $($guard.guard) status" ($guard.status -eq "enforced")
  Assert-True "gateway guard $($guard.guard) fail closed" ($guard.fail_closed -eq $true)
  Assert-True "gateway guard $($guard.guard) evidence" ([string]$guard.evidence_ref -match "^mcp_")
}

$version = $gateway.version_pinning_contract
Assert-True "version snapshot contract" ($version.contract_version -eq "mcp-version-pinning-v1")
Assert-True "version snapshot endpoint" ($version.endpoint -eq "GET /mcp/api/v1/version-pinning/contract")
Assert-True "version snapshot evidence ref" ($version.evidence_ref -eq "mcp_version_pinning_contract_visible")
Assert-True "version snapshot no live writes" ($version.live_mcp_writes -eq $false)
Assert-True "version snapshot no live mutations" ($version.live_mutations -eq $false)
Assert-True "version snapshot no external mcp calls" ($version.external_mcp_server_calls -eq $false)
Assert-True "version deep compare contract" ($version.contract_version -eq $directVersion.contract_version)
Assert-True "version deep compare evidence" ($version.evidence_ref -eq $directVersion.evidence_ref)

$catalog = $gateway.capability_catalog_contract
Assert-True "catalog contract" ($catalog.contract_version -eq "mcp-capability-catalog-v1")
Assert-True "catalog endpoint" ($catalog.endpoint -eq "GET /mcp/api/v1/capabilities/catalog")
Assert-True "catalog evidence ref" ($catalog.evidence_ref -eq "mcp_capability_catalog_visible")
Assert-True "catalog no live writes" ($catalog.live_mcp_writes -eq $false)
Assert-True "catalog no live mutations" ($catalog.live_mutations -eq $false)
Assert-True "catalog no external mcp calls" ($catalog.external_mcp_server_calls -eq $false)
Assert-True "catalog toolset count" ([int]$catalog.toolset_count -ge 6)
Assert-True "catalog capability count" ([int]$catalog.capability_count -ge 6)
Assert-True "catalog deep compare contract" ($catalog.contract_version -eq $directCatalog.contract_version)
Assert-True "catalog deep compare evidence" ($catalog.evidence_ref -eq $directCatalog.evidence_ref)
Assert-True "catalog deep compare toolset count" ([int]$catalog.toolset_count -eq [int]$directCatalog.toolset_count)
Assert-True "catalog deep compare capability count" ([int]$catalog.capability_count -eq [int]$directCatalog.capability_count)

foreach ($field in @("mcp_gateway_calls[].tool_request_id", "mcp_gateway_calls[].session_id", "mcp_gateway_calls[].trace_id", "mcp_gateway_calls[].request_id", "mcp_gateway_calls[].guard_evidence_ref", "mcp_gateway_calls[].live_mcp_writes_proven_false")) {
  Assert-True "required agent executor field $field" (@($parity.required_agent_executor_fields) -contains $field)
  Assert-True "gateway agent executor field $field" (@($gateway.agent_executor_contract.required_state_fields) -contains $field)
}
Assert-True "gateway non claims" (@($gateway.non_claims).Count -ge 3)

foreach ($contract in @("mcp-runtime-guard-parity-v1", "mcp-version-pinning-v1", "mcp-capability-catalog-v1")) {
  Assert-True "required gateway contract $contract" (@($parity.required_gateway_contracts) -contains $contract)
}
foreach ($guard in @("unsupported_toolset", "unsupported_capability", "scope_guard", "timeout_guard", "secret_redaction", "denied_audit_correlation")) {
  Assert-True "required gateway guard $guard" (@($parity.required_gateway_guards) -contains $guard)
}

Write-Host "status=verified"
Write-Host "contract_version=$($parity.contract_version)"
Write-Host "evidence_ref=$($parity.evidence_ref)"
Write-Host "toolset_count=$($catalog.toolset_count)"
Write-Host "capability_count=$($catalog.capability_count)"
