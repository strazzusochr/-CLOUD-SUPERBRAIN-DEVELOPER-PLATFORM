param(
  [switch]$Apply,
  [switch]$OwnerGate,
  [string]$StagingBaseUrl = $env:STAGING_BASE_URL,
  [string]$AgentApiBaseUrl = $env:AGENT_API_BASE_URL,
  [string]$McpGatewayBaseUrl = $env:MCP_GATEWAY_BASE_URL,
  [string]$LlmGatewayBaseUrl = $env:LLM_GATEWAY_BASE_URL,
  [string]$AgentApiFlyApp = $env:FLY_APP_AGENT_API,
  [string]$McpGatewayFlyApp = $env:FLY_APP_MCP_GATEWAY,
  [string]$LlmGatewayFlyApp = $env:FLY_APP_LLM_GATEWAY,
  [string]$ArtifactPath = ""
)

$ErrorActionPreference = "Stop"

function Convert-FlyAppNameToBaseUrl([string]$AppName) {
  if ([string]::IsNullOrWhiteSpace($AppName)) {
    throw "Fly app name must not be empty"
  }
  return "https://$AppName.fly.dev"
}

function Test-RetiredHostedBaseUrl([string]$Url) {
  if ([string]::IsNullOrWhiteSpace($Url)) {
    return $false
  }
  try {
    $uri = [System.Uri]$Url
  } catch {
    return $false
  }
  $uriHost = $uri.Host.ToLowerInvariant()
  return $uriHost.EndsWith(".sslip.io")
}

function Assert-CloudHttpsUrl([string]$Label, [string]$Url, [bool]$AllowExample) {
  if ([string]::IsNullOrWhiteSpace($Url)) {
    throw "$Label is required"
  }

  try {
    $uri = [System.Uri]$Url
  } catch {
    throw "$Label must be an absolute HTTPS URL"
  }

  if ($uri.Scheme -ne "https") {
    throw "$Label must use HTTPS"
  }

  $uriHost = $uri.Host.ToLowerInvariant()
  if ($uriHost -in @("localhost", "127.0.0.1", "0.0.0.0", "::1")) {
    throw "$Label must not use localhost"
  }
  if ($uriHost.EndsWith(".local") -or $uriHost.EndsWith(".internal")) {
    throw "$Label must not use a local/internal host"
  }
  if (Test-RetiredHostedBaseUrl $Url) {
    throw "$Label must not use retired sslip.io staging"
  }

  $parsedIp = $null
  if ([System.Net.IPAddress]::TryParse($uriHost, [ref]$parsedIp)) {
    throw "$Label must use a cloud DNS hostname, not a raw IP"
  }

  if ((-not $AllowExample) -and ($uriHost.EndsWith(".example.invalid") -or $uriHost -eq "example.invalid")) {
    throw "$Label must not use example.invalid in Apply mode"
  }

  return $uri.AbsoluteUri.TrimEnd("/")
}

function Test-EnvPresent([string]$Name) {
  $value = [Environment]::GetEnvironmentVariable($Name)
  return -not [string]::IsNullOrWhiteSpace($value)
}

if ([string]::IsNullOrWhiteSpace($AgentApiFlyApp)) { $AgentApiFlyApp = "cloud-superbrain-agent-api" }
if ([string]::IsNullOrWhiteSpace($McpGatewayFlyApp)) { $McpGatewayFlyApp = "cloud-superbrain-mcp-gateway" }
if ([string]::IsNullOrWhiteSpace($LlmGatewayFlyApp)) { $LlmGatewayFlyApp = "cloud-superbrain-llm-gateway" }

if ([string]::IsNullOrWhiteSpace($AgentApiBaseUrl)) { $AgentApiBaseUrl = Convert-FlyAppNameToBaseUrl $AgentApiFlyApp }
if ([string]::IsNullOrWhiteSpace($McpGatewayBaseUrl)) { $McpGatewayBaseUrl = Convert-FlyAppNameToBaseUrl $McpGatewayFlyApp }
if ([string]::IsNullOrWhiteSpace($LlmGatewayBaseUrl)) { $LlmGatewayBaseUrl = Convert-FlyAppNameToBaseUrl $LlmGatewayFlyApp }

$allowExample = -not $Apply
$validated = [ordered]@{
  STAGING_BASE_URL = if ([string]::IsNullOrWhiteSpace($StagingBaseUrl)) { $null } else { Assert-CloudHttpsUrl "STAGING_BASE_URL" $StagingBaseUrl $allowExample }
  AGENT_API_BASE_URL = Assert-CloudHttpsUrl "AGENT_API_BASE_URL" $AgentApiBaseUrl $allowExample
  MCP_GATEWAY_BASE_URL = Assert-CloudHttpsUrl "MCP_GATEWAY_BASE_URL" $McpGatewayBaseUrl $allowExample
  LLM_GATEWAY_BASE_URL = Assert-CloudHttpsUrl "LLM_GATEWAY_BASE_URL" $LlmGatewayBaseUrl $allowExample
}

$tokenPresence = [ordered]@{
  VERCEL_TOKEN = Test-EnvPresent "VERCEL_TOKEN"
  FLY_API_TOKEN = Test-EnvPresent "FLY_API_TOKEN"
  GHCR_TOKEN = Test-EnvPresent "GHCR_TOKEN"
  BRANCH_PROTECTION_TOKEN = Test-EnvPresent "BRANCH_PROTECTION_TOKEN"
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
if ([string]::IsNullOrWhiteSpace($ArtifactPath)) {
  $ArtifactPath = ".phase1-artifacts\owner-cloud-gate-activation-plan-$timestamp.json"
}

$plan = [ordered]@{
  contract = "owner-cloud-gate-activation-plan-v1"
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  mode = if ($Apply) { "apply_requested" } else { "PlanOnly" }
  owner_gate_required = $true
  owner_gate_supplied = [bool]($Apply -and $OwnerGate)
  apply_allowed = $false
  cloud_mutation_default = "disabled"
  mutation_execute_policy = "manual-owner-shell-after-review"
  secret_policy = "presence-only; never print token values"
  required_origins = $validated
  fly_apps = [ordered]@{
    agent_api = $AgentApiFlyApp
    mcp_gateway = $McpGatewayFlyApp
    llm_gateway = $LlmGatewayFlyApp
  }
  token_presence = $tokenPresence
  owner_actions = @(
    [ordered]@{
      step = "fly_origins"
      gate = "Owner deploy gate"
      target = "Fly.io apps for L2/L4/L5 origins"
      commands = @(
        "fly deploy -c fly.agent-api.toml --remote-only",
        "fly deploy -c fly.mcp-gateway.toml --remote-only",
        "fly deploy -c fly.llm-gateway.toml --remote-only"
      )
    },
    [ordered]@{
      step = "vercel_preview_env"
      gate = "Owner env gate"
      target = "Vercel preview/staging environment"
      env_names = @("STAGING_REWRITES_ENABLED", "AGENT_API_BASE_URL", "MCP_GATEWAY_BASE_URL", "LLM_GATEWAY_BASE_URL")
      values = [ordered]@{
        STAGING_REWRITES_ENABLED = "1"
        AGENT_API_BASE_URL = $validated.AGENT_API_BASE_URL
        MCP_GATEWAY_BASE_URL = $validated.MCP_GATEWAY_BASE_URL
        LLM_GATEWAY_BASE_URL = $validated.LLM_GATEWAY_BASE_URL
      }
    },
    [ordered]@{
      step = "hosted_verification"
      gate = "Hosted staging proof"
      target = "Vercel HTTPS STAGING_BASE_URL"
      commands = @(
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <STAGING_BASE_URL>",
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-external-gates.ps1"
      )
    }
  )
  non_claims = @(
    "no production deployment",
    "no registry push",
    "no live provider call",
    "no live MCP write",
    "no secret output",
    "no gate closure without hosted verifier artifact"
  )
}

$artifactDir = Split-Path -Parent $ArtifactPath
if (-not [string]::IsNullOrWhiteSpace($artifactDir)) {
  New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
}
$plan | ConvertTo-Json -Depth 8 | Set-Content -Path $ArtifactPath -Encoding UTF8

Write-Host "[owner-cloud-gate] artifact=$ArtifactPath"
Write-Host "[owner-cloud-gate] mode=$($plan.mode)"
Write-Host "[owner-cloud-gate] apply_allowed=$($plan.apply_allowed)"
Write-Host "[owner-cloud-gate] secret_policy=$($plan.secret_policy)"
Write-Host "[owner-cloud-gate] next=owner must approve cloud mutation, then rerun hosted verifiers"

if ($Apply -and -not $OwnerGate) {
  throw "-Apply requires -OwnerGate. Default PlanOnly performs no cloud mutation."
}

if ($Apply -and $OwnerGate) {
  throw "Apply mode is fail-closed in Codex: use the emitted plan for explicit owner-approved cloud commands, then verify with hosted artifacts."
}
