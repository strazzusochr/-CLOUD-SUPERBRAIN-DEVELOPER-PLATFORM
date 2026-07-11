param(
  [Parameter(Mandatory = $true)][string]$BaseUrl,
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\goal-d4\batch2"
)

$ErrorActionPreference = "Stop"
$uri = [Uri]$BaseUrl
if ($uri.Host -in @("localhost", "127.0.0.1", "::1") -and -not $AllowLocalhost) {
  throw "Localhost requires -AllowLocalhost and is DEV-ONLY evidence."
}
$repoRoot = (Get-Location).Path
$outPath = Join-Path $repoRoot $OutDir
New-Item -ItemType Directory -Force $outPath | Out-Null
$paths = @(
  "/api/v1/agent-activity/recent",
  "/api/v1/audit/mcp",
  "/api/v1/escalations/recent",
  "/api/v1/memory/consolidation/recent",
  "/api/v1/memory/embedding-consistency/contract",
  "/api/v1/rotation/events",
  "/api/v1/organism/events",
  "/api/v1/organism/replay",
  "/api/v1/artifacts"
)

# Secret/redaction rules are per surface, not global:
# - Truly secret-bearing JSON keys and leaked token values are forbidden everywhere.
# - The organism surfaces are additionally bound to the redaction contract
#   (no session_id / user_id / details / prompt — see PROJECT_STATE organism rules).
# - agent-activity/audit surfaces legitimately carry session_id/trace_id per
#   agent-activity-trace-v1, so those keys are NOT failures there.
$globalForbiddenKeys = '"(authorization|cookie|set-cookie|password|api_key|client_secret|private_key)"\s*:'
$tokenLeakValues = '(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|Bearer\s+[A-Za-z0-9._-]{16,}|FlyV1\s+[A-Za-z0-9+/=_-]{16,})'
$redactedForbiddenKeys = '"(session_id|user_id|details|prompt)"\s*:'
$redactionContractPaths = @("/api/v1/organism/events", "/api/v1/organism/replay")

function Invoke-Probe([string]$Path) {
  $response = Invoke-WebRequest -UseBasicParsing -Uri "$($BaseUrl.TrimEnd('/'))$Path" -Headers @{ Accept = "application/json" } -TimeoutSec 20
  $source = $response.Headers["x-superbrain-source"]
  $payload = $response.Content | ConvertFrom-Json
  $violations = @()
  if ($response.Content -match $globalForbiddenKeys) { $violations += "secret_key:$($Matches[1])" }
  if ($response.Content -match $tokenLeakValues) { $violations += "token_value_leak" }
  if ($redactionContractPaths -contains $Path -and $response.Content -match $redactedForbiddenKeys) {
    $violations += "redaction_contract:$($Matches[1])"
  }
  [pscustomobject]@{
    path = $Path
    http_status = [int]$response.StatusCode
    source = $source
    source_kind = if ($null -ne $payload.PSObject.Properties["source_kind"]) { [string]$payload.source_kind } else { $null }
    live_backend = if ($null -ne $payload.PSObject.Properties["live_backend"]) { $payload.live_backend } else { $null }
    secret_fields_present = ($violations.Count -gt 0)
    secret_violations = $violations
  }
}

$results = @($paths | ForEach-Object { Invoke-Probe $_ })
$embedding = $results | Where-Object { $_.path -eq "/api/v1/memory/embedding-consistency/contract" } | Select-Object -First 1
$artifactAlias = $results | Where-Object { $_.path -eq "/api/v1/artifacts" } | Select-Object -First 1
$failures = @($results | Where-Object { $_.http_status -ne 200 -or $_.secret_fields_present })
$report = [ordered]@{
  contract_version = "goal-d4-class-b-probe-v1"
  base_url = $BaseUrl
  scope = if ($uri.Host -in @("localhost", "127.0.0.1", "::1")) { "DEV-ONLY" } else { "HTTPS_HOSTED" }
  results = $results
  pass_count = @($results | Where-Object { $_.http_status -eq 200 -and -not $_.secret_fields_present }).Count
  fail_count = $failures.Count
  non_claims = @("GET-only probe.", "No memory write/roundtrip was attempted.", "No live LLM call.", "No live MCP write.", "No secret output.")
}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outPath "class-b-probe-$($uri.Host).json") -Encoding utf8
Write-Host "[goal-d4-class-b] scope=$($report.scope) pass=$($report.pass_count) fail=$($report.fail_count)"
if ($report.fail_count -gt 0) { exit 1 }
