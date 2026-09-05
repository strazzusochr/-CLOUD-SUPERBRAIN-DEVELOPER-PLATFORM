param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$RequireT3ProviderSet,
  [string]$OutputPath = "",
  [int]$TimeoutSec = 30
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
$requiredT3Providers = @("cloudflare_edge", "github_actions", "ghcr_registry", "grafana_cloud")

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) {
    throw "Cloud provider live-read verification failed: $Label"
  }
}

try {
  $uri = [System.Uri]$BaseUrl
} catch {
  throw "Cloud provider live-read verification failed: BaseUrl is invalid"
}

$isLocalhost = $uri.Host -in @("localhost", "127.0.0.1", "::1")
if ($isLocalhost -and -not $AllowLocalhost) {
  throw "Cloud provider live-read verification failed: localhost requires -AllowLocalhost"
}
if (-not $isLocalhost -and $uri.Scheme -ne "https") {
  throw "Cloud provider live-read verification failed: hosted BaseUrl must use HTTPS"
}

$base = $BaseUrl.TrimEnd("/")
$inventory = Invoke-RestMethod -Method Get -Uri "$base/api/v1/clouds" -TimeoutSec $TimeoutSec
$layers = Invoke-RestMethod -Method Get -Uri "$base/api/v1/clouds/layers" -TimeoutSec $TimeoutSec

Assert-True "inventory contract version" ($inventory.contract_version -eq "cloud-provider-inventory-v1")
Assert-True "layer contract version" ($layers.contract_version -eq "cloud-layer-readiness-v1")
Assert-True "inventory live count is bounded" ([int]$inventory.live_verified_count -ge 0 -and [int]$inventory.live_verified_count -le [int]$inventory.total_count)

$providerSummary = @(
  $inventory.providers | ForEach-Object {
    [ordered]@{
      id = [string]$_.id
      status = [string]$_.status
      configured = [bool]$_.configured
      live_verified = [bool]$_.live_verified
      resource_sources = @($_.resources | ForEach-Object { [string]$_.source } | Sort-Object -Unique)
    }
  }
)
$layerSummary = @(
  $layers.layers | ForEach-Object {
    [ordered]@{
      layer_id = [string]$_.layer_id
      status = [string]$_.status
      live_verified_providers = @($_.live_verified_providers | ForEach-Object { [string]$_ })
    }
  }
)

if ($RequireT3ProviderSet) {
  Assert-True "live_verified_count must be greater than zero" ([int]$inventory.live_verified_count -gt 0)
  foreach ($providerId in $requiredT3Providers) {
    $matches = @($inventory.providers | Where-Object { $_.id -eq $providerId })
    Assert-True "$providerId exists exactly once" ($matches.Count -eq 1)
    Assert-True "$providerId is live verified" ([bool]$matches[0].live_verified)
  }
  Assert-True "at least one layer is beyond action_required" (@($layers.layers | Where-Object { $_.status -ne "action_required" }).Count -gt 0)
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
  $OutputPath = Join-Path $repoRoot ".phase1-artifacts\cloud-provider-live-read-$stamp.json"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath = Join-Path $repoRoot $OutputPath
}

$artifact = [ordered]@{
  contract_version = "cloud-provider-live-read-proof-v1"
  status = "verified"
  checked_at = (Get-Date).ToUniversalTime().ToString("o")
  evidence_scope = if ($isLocalhost) { "DEV-ONLY" } else { "hosted-read-only" }
  base_origin = $uri.GetLeftPart([System.UriPartial]::Authority)
  t3_provider_set_required = [bool]$RequireT3ProviderSet
  inventory = [ordered]@{
    status = [string]$inventory.status
    configured_count = [int]$inventory.configured_count
    live_verified_count = [int]$inventory.live_verified_count
    total_count = [int]$inventory.total_count
    providers = $providerSummary
  }
  layer_readiness = [ordered]@{
    status = [string]$layers.status
    ready_layer_count = [int]$layers.ready_layer_count
    partial_layer_count = [int]$layers.partial_layer_count
    total_layer_count = @($layers.layers).Count
    layers = $layerSummary
  }
  assertions = @(
    "provider inventory contract parsed",
    "layer readiness contract parsed",
    $(if ($RequireT3ProviderSet) { "T3 Cloudflare, GitHub, GHCR, and Grafana reads are live verified" } else { "live provider reads remain optional in token-free runtime mode" })
  )
  non_claims = @(
    "No cloud mutation was performed.",
    "No token value or provider response body is stored.",
    $(if ($isLocalhost) { "DEV-ONLY; hosted proof still blocked." } else { "This read-only proof is not a production deployment approval." })
  )
}

$json = $artifact | ConvertTo-Json -Depth 9
foreach ($key in @("CLOUDFLARE_API_TOKEN", "GITHUB_TOKEN", "GHCR_TOKEN", "GRAFANA_CLOUD_API_KEY")) {
  $secret = [Environment]::GetEnvironmentVariable($key, "Process")
  if (-not [string]::IsNullOrWhiteSpace($secret) -and $json.Contains($secret)) {
    throw "Cloud provider live-read verification failed: artifact contains secret material for $key"
  }
}

$parent = Split-Path $OutputPath -Parent
if ($parent) {
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
$json | Set-Content -LiteralPath $OutputPath -Encoding UTF8

$relativeArtifact = if ($OutputPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  $OutputPath.Substring($repoRoot.Length).TrimStart("\", "/")
} else {
  $OutputPath
}
Write-Host "[cloud-provider-live-read] status=verified"
Write-Host "[cloud-provider-live-read] evidence_scope=$($artifact.evidence_scope)"
Write-Host "[cloud-provider-live-read] live_verified_count=$($inventory.live_verified_count)/$($inventory.total_count)"
Write-Host "[cloud-provider-live-read] ready_layer_count=$($layers.ready_layer_count)/$(@($layers.layers).Count)"
Write-Host "[cloud-provider-live-read] artifact=$relativeArtifact"
