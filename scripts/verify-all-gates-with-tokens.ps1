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
$externalGateScript = Join-Path $PSScriptRoot "verify-external-gates.ps1"
if (-not (Test-Path -LiteralPath $importScript)) {
  throw "Missing env import helper: $importScript"
}
if (-not (Test-Path -LiteralPath $externalGateScript)) {
  throw "Missing external gate verifier: $externalGateScript"
}

& $importScript -EnvFilePath $EnvFilePath -Quiet -Overwrite:$OverwriteEnv

function Assert-ExternalGateVerifierPreflight([string]$ScriptPath) {
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    $ScriptPath,
    [ref]$null,
    [ref]$parseErrors
  ) | Out-Null
  if ($parseErrors -and $parseErrors.Count -gt 0) {
    $messages = @($parseErrors | ForEach-Object { $_.Message }) -join "; "
    throw "External gate verifier has parse errors: $messages"
  }

  $raw = Get-Content -Path $ScriptPath -Raw
  if (-not $raw.Contains('$global:LASTEXITCODE = 0')) {
    throw "External gate verifier preflight failed: successful exit code reset is missing"
  }

  $requiredBlockMatch = [regex]::Match($raw, '(?s)\$hostedApiRequiredIds\s*=\s*@\((.*?)\)')
  if (-not $requiredBlockMatch.Success) {
    throw "External gate verifier preflight failed: hosted API required id block is missing"
  }
  $requiredIds = [regex]::Matches($requiredBlockMatch.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
  $definedHostedProbeIds = [regex]::Matches($raw, '(?:Invoke-HttpProbe|New-Probe)\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
  $missingHostedProbeIds = @($requiredIds | Where-Object { $definedHostedProbeIds -notcontains $_ })
  if ($missingHostedProbeIds.Count -gt 0) {
    throw "External gate verifier preflight failed: missing hosted probe definitions for $($missingHostedProbeIds -join ', ')"
  }
}

function Normalize-BaseUrl([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return ""
  }
  return $Value.Trim().TrimEnd("/")
}

function Set-ProcessEnvValue([string]$Name, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Value)) {
    return
  }
  [Environment]::SetEnvironmentVariable($Name, $Value.Trim().TrimEnd("/"), "Process")
}

function Set-ProcessEnvIfMissing([string]$Name, [string]$Value) {
  $existing = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($existing)) {
    Set-ProcessEnvValue $Name $Value
  }
}

$flyOriginAppDefaults = @{
  FLY_APP_AGENT_API = "cloud-superbrain-agent-api"
  FLY_APP_MCP_GATEWAY = "cloud-superbrain-mcp-gateway"
  FLY_APP_LLM_GATEWAY = "cloud-superbrain-llm-gateway"
}

function Get-FlyAppNameOrDefault([string]$FlyAppEnvName) {
  $flyApp = [Environment]::GetEnvironmentVariable($FlyAppEnvName, "Process")
  if (-not [string]::IsNullOrWhiteSpace($flyApp)) {
    return $flyApp
  }

  if ($flyOriginAppDefaults.ContainsKey($FlyAppEnvName)) {
    return $flyOriginAppDefaults[$FlyAppEnvName]
  }

  return ""
}

function Convert-FlyAppNameToBaseUrl([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return ""
  }

  $trimmed = $Value.Trim().TrimEnd("/")
  if ($trimmed.Contains("<") -or $trimmed.Contains(">") -or $trimmed.Contains('${')) {
    return ""
  }

  if ($trimmed -match '^https://[A-Za-z0-9.-]+(\.fly\.dev)?$') {
    return $trimmed
  }

  if ($trimmed -match '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$') {
    return "https://$trimmed.fly.dev"
  }

  return ""
}

function Test-PlaceholderValue([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $true
  }

  $trimmed = $Value.Trim()
  return ($trimmed.Contains("<") -or $trimmed.Contains(">") -or $trimmed.Contains('${'))
}

function Test-HostedRewriteFallbackValue([string]$EnvName, [string]$Value, [string]$HostedBaseUrlValue) {
  $normalizedValue = Normalize-BaseUrl $Value
  $normalizedHosted = Normalize-BaseUrl $HostedBaseUrlValue
  if ([string]::IsNullOrWhiteSpace($normalizedValue) -or [string]::IsNullOrWhiteSpace($normalizedHosted)) {
    return $false
  }

  $hostedFallbacks = switch ($EnvName) {
    "AGENT_API_BASE_URL" { @($normalizedHosted) }
    "MCP_GATEWAY_BASE_URL" { @("$normalizedHosted/mcp") }
    "LLM_GATEWAY_BASE_URL" { @("$normalizedHosted/llm") }
    default { @() }
  }

  return @($hostedFallbacks | Where-Object {
    $normalizedValue.Equals($_, [System.StringComparison]::OrdinalIgnoreCase)
  }).Count -gt 0
}

function Resolve-OriginEnv([string]$EnvName, [string]$FlyAppEnvName, [string]$HostedFallbackUrl) {
  $existing = Normalize-BaseUrl ([Environment]::GetEnvironmentVariable($EnvName, "Process"))
  if (
    -not (Test-PlaceholderValue $existing) -and
    -not (Test-HostedRewriteFallbackValue $EnvName $existing $normalizedHostedBaseUrl)
  ) {
    Set-ProcessEnvValue $EnvName $existing
    return
  }

  $derivedUrl = Convert-FlyAppNameToBaseUrl (Get-FlyAppNameOrDefault $FlyAppEnvName)
  if (-not [string]::IsNullOrWhiteSpace($derivedUrl)) {
    Set-ProcessEnvValue $EnvName $derivedUrl
    return
  }

  if (-not [string]::IsNullOrWhiteSpace($existing) -and -not (Test-PlaceholderValue $existing)) {
    Set-ProcessEnvValue $EnvName $existing
    return
  }

  if ($HostedFallbackUrl -match '^https://') {
    Set-ProcessEnvIfMissing $EnvName $HostedFallbackUrl
  }
}

if ([string]::IsNullOrWhiteSpace($HostedBaseUrl)) {
  $HostedBaseUrl = $env:STAGING_BASE_URL
}

$normalizedHostedBaseUrl = Normalize-BaseUrl $HostedBaseUrl
if (-not [string]::IsNullOrWhiteSpace($normalizedHostedBaseUrl)) {
  Set-ProcessEnvIfMissing "STAGING_BASE_URL" $normalizedHostedBaseUrl
}

Resolve-OriginEnv "AGENT_API_BASE_URL" "FLY_APP_AGENT_API" $normalizedHostedBaseUrl
Resolve-OriginEnv "MCP_GATEWAY_BASE_URL" "FLY_APP_MCP_GATEWAY" "$normalizedHostedBaseUrl/mcp"
Resolve-OriginEnv "LLM_GATEWAY_BASE_URL" "FLY_APP_LLM_GATEWAY" "$normalizedHostedBaseUrl/llm"

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
Write-Host "[verify-all-gates-with-tokens] preflight-checking verify-external-gates.ps1"
Assert-ExternalGateVerifierPreflight $externalGateScript

Push-Location $repoRoot
try {
  & $externalGateScript @externalArgs
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
} finally {
  Pop-Location
}

