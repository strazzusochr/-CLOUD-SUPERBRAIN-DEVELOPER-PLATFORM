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
  $probeBlockMatch = [regex]::Match($raw, '(?s)\$hostedProbes\s*=\s*@\((.*?)\)\s*\}')
  if (-not $probeBlockMatch.Success) {
    throw "External gate verifier preflight failed: hosted probe block is missing"
  }

  $requiredIds = [regex]::Matches($requiredBlockMatch.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
  $definedHostedProbeIds = [regex]::Matches($probeBlockMatch.Groups[1].Value, 'New-Probe\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
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

