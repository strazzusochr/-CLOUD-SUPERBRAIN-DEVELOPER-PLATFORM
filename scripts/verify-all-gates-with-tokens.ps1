param(
  [string]$EnvFilePath = (Join-Path $HOME ".codex\secrets\cloud-superbrain.local.env"),
  [string]$HostedBaseUrl = $env:STAGING_BASE_URL,
  [string]$LocalBaseUrl = "http://localhost:8081",
  [string]$Repository = $(if ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM" }),
  [string]$Branch = $(if ($env:BRANCH_NAME) { $env:BRANCH_NAME } else { "" }),
  [string]$ArtifactDirectory = ".phase1-artifacts",
  [switch]$RequireAllClosed,
  [switch]$OverwriteEnv
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$importScript = Join-Path $PSScriptRoot "import-local-env.ps1"
if (-not (Test-Path -LiteralPath $importScript)) {
  throw "Missing env import helper: $importScript"
}

& $importScript -EnvFilePath $EnvFilePath -Quiet -Overwrite:$OverwriteEnv

function Normalize-BaseUrl([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return ""
  }
  return $Value.Trim().TrimEnd("/")
}

function Set-ProcessEnvIfMissing([string]$Name, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Value)) {
    return
  }
  $existing = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($existing)) {
    [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
  }
}

if ([string]::IsNullOrWhiteSpace($HostedBaseUrl)) {
  $HostedBaseUrl = $env:STAGING_BASE_URL
}

$normalizedHostedBaseUrl = Normalize-BaseUrl $HostedBaseUrl
if (-not [string]::IsNullOrWhiteSpace($normalizedHostedBaseUrl)) {
  Set-ProcessEnvIfMissing "STAGING_BASE_URL" $normalizedHostedBaseUrl
  Set-ProcessEnvIfMissing "AGENT_API_BASE_URL" $normalizedHostedBaseUrl
  Set-ProcessEnvIfMissing "MCP_GATEWAY_BASE_URL" "$normalizedHostedBaseUrl/mcp"
  Set-ProcessEnvIfMissing "LLM_GATEWAY_BASE_URL" "$normalizedHostedBaseUrl/llm"
}

$hardRequired = @(
  "STAGING_BASE_URL",
  "AGENT_API_BASE_URL",
  "MCP_GATEWAY_BASE_URL",
  "LLM_GATEWAY_BASE_URL"
)

$missing = @()
foreach ($name in $hardRequired) {
  $value = [Environment]::GetEnvironmentVariable($name, "Process")
  if ([string]::IsNullOrWhiteSpace($value)) {
    $missing += $name
  }
}

if ([string]::IsNullOrWhiteSpace($env:BRANCH_PROTECTION_TOKEN) -and -not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
  $env:BRANCH_PROTECTION_TOKEN = $env:GITHUB_TOKEN
}

if ([string]::IsNullOrWhiteSpace($env:HETZNER_API_TOKEN) -and -not [string]::IsNullOrWhiteSpace($env:HCLOUD_TOKEN)) {
  $env:HETZNER_API_TOKEN = $env:HCLOUD_TOKEN
}

if ($missing.Count -gt 0) {
  throw "Required environment variable(s) missing for external gate verification: $($missing -join ', ')"
}

$externalArgs = [ordered]@{
  HostedBaseUrl = $HostedBaseUrl
  LocalBaseUrl = $LocalBaseUrl
  Repository = $Repository
  ArtifactDirectory = $ArtifactDirectory
}
if (-not [string]::IsNullOrWhiteSpace($Branch)) {
  $externalArgs["Branch"] = $Branch
}
if ($RequireAllClosed) {
  $externalArgs["RequireAllClosed"] = $true
}

Write-Host "[verify-all-gates-with-tokens] running external gate verification with private env bootstrap"
Write-Host "[verify-all-gates-with-tokens] optional identity tokens are evaluated by verify-external-gates.ps1, not pre-required here"

Push-Location $repoRoot
try {
  & (Join-Path $PSScriptRoot "verify-external-gates.ps1") @externalArgs
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
} finally {
  Pop-Location
}
