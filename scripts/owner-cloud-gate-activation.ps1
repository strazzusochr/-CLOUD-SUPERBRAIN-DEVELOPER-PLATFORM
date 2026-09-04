param(
  [switch]$Apply,
  [switch]$OwnerGate,
  [string]$StagingBaseUrl = $env:STAGING_BASE_URL,
  [string]$CloudflareStatefulBaseUrl = $env:CLOUDFLARE_STATEFUL_BASE_URL,
  [string]$ArtifactPath = ""
)

$ErrorActionPreference = "Stop"

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

$allowExample = -not $Apply
$validated = [ordered]@{
  STAGING_BASE_URL = if ([string]::IsNullOrWhiteSpace($StagingBaseUrl)) { $null } else { Assert-CloudHttpsUrl "STAGING_BASE_URL" $StagingBaseUrl $allowExample }
  CLOUDFLARE_STATEFUL_BASE_URL = if ([string]::IsNullOrWhiteSpace($CloudflareStatefulBaseUrl)) { $null } else { Assert-CloudHttpsUrl "CLOUDFLARE_STATEFUL_BASE_URL" $CloudflareStatefulBaseUrl $allowExample }
}

$tokenPresence = [ordered]@{
  CLOUDFLARE_API_TOKEN = Test-EnvPresent "CLOUDFLARE_API_TOKEN"
  CLOUDFLARE_ACCOUNT_ID = Test-EnvPresent "CLOUDFLARE_ACCOUNT_ID"
  VERCEL_TOKEN = Test-EnvPresent "VERCEL_TOKEN"
  GHCR_TOKEN = Test-EnvPresent "GHCR_TOKEN"
  BRANCH_PROTECTION_TOKEN = Test-EnvPresent "BRANCH_PROTECTION_TOKEN"
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
if ([string]::IsNullOrWhiteSpace($ArtifactPath)) {
  $ArtifactPath = ".phase1-artifacts\owner-cloud-gate-activation-plan-$timestamp.json"
}

$plan = [ordered]@{
  contract = "owner-cloud-gate-activation-plan-v2"
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  mode = if ($Apply) { "apply_requested" } else { "PlanOnly" }
  active_target_gate = "cloudflare_native_zero_card_hosted_runtime"
  owner_gate_required = $true
  owner_gate_supplied = [bool]($Apply -and $OwnerGate)
  apply_allowed = $false
  cloud_mutation_default = "disabled"
  hosted_writes_default = "disabled"
  mutation_execute_policy = "manual-owner-shell-after-review"
  secret_policy = "presence-only; never print token values"
  required_origins = $validated
  required_owner_scope_attestations = [ordered]@{
    workers_scripts_edit = $false
    d1_edit = $false
    durable_objects_edit = $false
    queues_edit = $false
    r2_historical_only = $true
    hosted_write_approval = $false
    zero_card_activation = $false
  }
  token_presence = $tokenPresence
  owner_actions = @(
    [ordered]@{
      step = "cloudflare_scope_review"
      gate = "O2' Owner scope gate"
      target = "Cloudflare Workers, D1, SQLite Durable Objects and Queues"
      required_scopes = @(
        "Workers Scripts:Edit",
        "D1:Edit",
        "Durable Objects:Edit",
        "Queues:Edit"
      )
      artifact_adapter = "D1 bounded UTF-8 text"
      r2_policy = "R2 is historical-only, unbound, and must not be created or activated."
    },
    [ordered]@{
      step = "cloudflare_hosted_runtime"
      gate = "O2' hosted write and deployment gate"
      target = "Cloudflare-native stateful runtime"
      required_env_names = @("CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_API_TOKEN", "CLOUDFLARE_STATEFUL_BASE_URL")
      base_url = $validated.CLOUDFLARE_STATEFUL_BASE_URL
      mutation_policy = "Owner-approved shell only; Codex stays fail-closed."
    },
    [ordered]@{
      step = "hosted_verification"
      gate = "O2' hosted source-parity and stateful-roundtrip proof"
      target = "Cloudflare HTTPS CLOUDFLARE_STATEFUL_BASE_URL and Vercel HTTPS STAGING_BASE_URL"
      commands = @(
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-cloudflare-stateful-runtime.ps1 -BaseUrl <CLOUDFLARE_STATEFUL_BASE_URL> -AllowHostedWrites",
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
    "no gate closure without hosted verifier artifact",
    "no percentage credit from this plan",
    "O6 bounded live LLM is already owner_granted and live_verified; this plan does not make Layer 4 equal 100",
    "retired Fly artifacts are historical_only and do not define the active target"
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
  throw "Apply mode is fail-closed in Codex: Owner scopes, Cloudflare URL, hosted writes, zero-card activation, and deployment must be approved and executed in an owner shell, then verified with hosted artifacts."
}
