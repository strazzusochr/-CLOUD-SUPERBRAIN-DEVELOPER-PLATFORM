param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$StaticOnly
)

$ErrorActionPreference = "Stop"
$MaxResponseBytes = 1048576

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) {
    throw "Verification failed: $Label"
  }
}

function Assert-Contains([string]$Label, [string]$Text, [string]$Needle) {
  if (-not $Text.Contains($Needle)) {
    throw "Verification failed: $Label missing '$Needle'"
  }
}

function Assert-NotContains([string]$Label, [string]$Text, [string]$Needle) {
  if ($Text.Contains($Needle)) {
    throw "Verification failed: $Label contains forbidden '$Needle'"
  }
}

function Normalize-BaseUrl([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "BaseUrl is required"
  }
  return $Value.Trim().TrimEnd("/")
}

function Assert-BaseUrlAllowed([string]$Url, [bool]$AllowLocal) {
  $uri = [System.Uri]$Url
  $isLocal = $uri.Host -in @("localhost", "127.0.0.1", "::1")
  if ($isLocal -and -not $AllowLocal) {
    throw "Localhost technology runtime proof requires -AllowLocalhost and remains DEV-ONLY"
  }
  if (-not $isLocal -and $uri.Scheme -ne "https") {
    throw "Hosted technology runtime proof requires HTTPS"
  }
}

function Invoke-Contract([string]$Url) {
  try {
    $response = Invoke-WebRequest -Method Get -Uri $Url -TimeoutSec 30 -Headers @{ Accept = "application/json" } -UseBasicParsing
  } catch {
    throw "Failed to fetch technology contract from ${Url}: $($_.Exception.Message)"
  }
  Assert-True "HTTP 200 $Url" ([int]$response.StatusCode -eq 200)
  Assert-True "bounded response $Url" (
    [int64]$response.RawContentLength -gt 0 -and
    [int64]$response.RawContentLength -le $MaxResponseBytes
  )
  $source = [string]$response.Headers["x-superbrain-source"]
  Assert-True "explicit source header $Url" (
    $source -in @("agent-api-boundary", "project-state-projection", "frontend-projection")
  )
  try {
    $payload = $response.Content | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "Invalid JSON from ${Url}: $($_.Exception.Message)"
  }
  return [pscustomobject]@{
    payload = $payload
    source = $source
  }
}

function Assert-StringArray([string]$Label, $Value, [bool]$AllowEmpty = $false) {
  Assert-True "$Label is array" ($Value -is [System.Array])
  if (-not $AllowEmpty) {
    Assert-True "$Label is non-empty" (@($Value).Count -gt 0)
  }
  foreach ($item in @($Value)) {
    Assert-True "$Label contains non-empty strings" (
      $item -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$item)
    )
  }
}

Write-Host "[technology-runtime] static surface"

foreach ($path in @(
  "apps\frontend\app\technology\page.tsx",
  "apps\frontend\components\technology\TechnologyRuntimeView.tsx",
  "apps\frontend\e2e\technology.spec.ts",
  "apps\frontend\lib\actionMatrix.ts",
  "apps\frontend\lib\frontendBoundary.ts",
  "apps\frontend\app\api\v1\[...slug]\route.ts",
  "infrastructure\nginx\dev.conf",
  "infrastructure\nginx\cloud.conf",
  "scripts\verify-browser-contract.ps1",
  "services\agent-api\app\clouds.py",
  "services\agent-api\app\main.py"
)) {
  Assert-True "required source exists $path" (Test-Path -LiteralPath $path)
}

$pageSource = Get-Content -LiteralPath "apps\frontend\app\technology\page.tsx" -Raw
$componentSource = Get-Content -LiteralPath "apps\frontend\components\technology\TechnologyRuntimeView.tsx" -Raw
$browserProofSource = Get-Content -LiteralPath "apps\frontend\e2e\technology.spec.ts" -Raw
$actionMatrixSource = Get-Content -LiteralPath "apps\frontend\lib\actionMatrix.ts" -Raw
$frontendBoundarySource = Get-Content -LiteralPath "apps\frontend\lib\frontendBoundary.ts" -Raw
$catchAllSource = Get-Content -LiteralPath "apps\frontend\app\api\v1\[...slug]\route.ts" -Raw
$nginxDevSource = Get-Content -LiteralPath "infrastructure\nginx\dev.conf" -Raw
$nginxCloudSource = Get-Content -LiteralPath "infrastructure\nginx\cloud.conf" -Raw
$browserContractSource = Get-Content -LiteralPath "scripts\verify-browser-contract.ps1" -Raw
$cloudSource = Get-Content -LiteralPath "services\agent-api\app\clouds.py" -Raw
$agentApiSource = Get-Content -LiteralPath "services\agent-api\app\main.py" -Raw

foreach ($required in @("TechnologyRuntimeView", "<TechnologyRuntimeView")) {
  Assert-Contains "technology page" $pageSource $required
}

foreach ($required in @(
  '"use client"',
  "/api/v1/clouds",
  "/api/v1/clouds/layers",
  "/api/v1/clouds/deployment-preflight",
  "cloud-provider-inventory-v1",
  "cloud_provider_inventory_visible",
  "GET /api/v1/clouds",
  "cloud-layer-readiness-v1",
  "cloud_layer_readiness_visible",
  "GET /api/v1/clouds/layers",
  "cloud-deployment-preflight-v1",
  "cloud_deployment_preflight_visible",
  "GET /api/v1/clouds/deployment-preflight",
  "MAX_RESPONSE_BYTES",
  "EXPECTED_LAYER_IDS",
  "CLOUDFLARE_LAYER_IDS",
  "RESPONSE_SOURCES",
  "isCloudInventory",
  "isCloudLayers",
  "isCloudPreflight",
  "areContractsConsistent",
  "requireVolatileParity",
  "readBoundedJson",
  'response.headers.get("x-superbrain-source")',
  "Promise.all",
  'method: "GET"',
  "technology-runtime-view",
  "technology-runtime-refresh",
  "technology-runtime-error",
  "technology-runtime-retry",
  "technology-provider-filter",
  "technology-layer-select",
  "technology-provider-card",
  "technology-layer-detail",
  "technology-declared-runtime",
  "technology-declared-toolstack",
  "technology-preflight-missing-gate",
  "technology-runtime-source",
  "data-provider-count",
  "data-layer-count",
  "data-visible-provider-count",
  "data-selected-layer-id",
  "data-provider-filter",
  "data-preflight-missing-count",
  "data-current-live-proof",
  "projection_not_current",
  "captured_contract_value=",
  "kein aktueller Beweis",
  "data-live-value-kind",
  "captured_contract",
  "live_verified_current",
  "historical_only",
  "historical_read_verified",
  "cloudflare_edge"
)) {
  Assert-Contains "technology runtime component" $componentSource $required
}
Assert-NotContains "technology runtime component" $componentSource "http://"
Assert-NotContains "technology runtime component" $componentSource "https://"

foreach ($required in @(
  "technology runtime contracts expose working filters layer selection and refresh",
  "technology runtime fails closed on impossible current agent boundary live claims",
  "cloud-provider-inventory-v1",
  "cloud_provider_inventory_visible",
  "cloud-layer-readiness-v1",
  "cloud_layer_readiness_visible",
  "cloud-deployment-preflight-v1",
  "cloud_deployment_preflight_visible",
  "technology-runtime-view",
  "technology-runtime-refresh",
  "technology-runtime-error",
  "technology-runtime-retry",
  "technology-provider-filter",
  "technology-layer-select",
  "technology-provider-card",
  "technology-layer-detail",
  "technology-declared-runtime",
  "contract_declared",
  "technology-declared-toolstack",
  "repo_declared",
  "data-current-live-proof",
  "projection_not_current",
  "captured_contract_value=",
  "kein aktueller Beweis",
  "data-live-value-kind",
  "captured_contract",
  "agent-api-boundary",
  "historical_only",
  "historical_read_verified",
  "cloudflare_edge",
  "Hetzner|GitKraken|Oracle",
  "503",
  "oversize",
  "parity"
)) {
  Assert-Contains "technology browser proof" $browserProofSource $required
}

foreach ($required in @(
  'route: "/technology"',
  "technology-runtime-refresh",
  "technology-provider-filter",
  "technology-layer-select",
  "technology runtime contracts expose working filters layer selection and refresh",
  'zeroRoutes.join("|") !== "/open-source"',
  "only /open-source may have zero page-local action families"
)) {
  Assert-Contains "technology action matrix" $actionMatrixSource $required
}
Assert-NotContains "technology action matrix" $actionMatrixSource 'zeroPageLocalReason: "Static technology inventory'

foreach ($required in @(
  "x-superbrain-source",
  "project-state-projection",
  "frontend-projection"
)) {
  Assert-Contains "same-origin catch-all" $catchAllSource $required
}
foreach ($required in @("x-superbrain-source", "agent-api-boundary")) {
  Assert-Contains "agent-api boundary source" $frontendBoundarySource $required
}
foreach ($nginxSource in @(
  [pscustomobject]@{ Label = "nginx dev api source"; Text = $nginxDevSource },
  [pscustomobject]@{ Label = "nginx cloud api source"; Text = $nginxCloudSource }
)) {
  foreach ($required in @(
    "location /api/",
    'proxy_set_header X-Superbrain-Source "";',
    "proxy_hide_header X-Superbrain-Source;",
    "add_header X-Superbrain-Source agent-api-boundary always;"
  )) {
    Assert-Contains $nginxSource.Label $nginxSource.Text $required
  }
}

foreach ($required in @(
  "verify-technology-runtime-view.ps1",
  "Browser contract verification failed: technology runtime view"
)) {
  Assert-Contains "browser contract technology integration" $browserContractSource $required
}

foreach ($required in @(
  "cloud-provider-inventory-v1",
  "cloud_provider_inventory_visible",
  "cloud-layer-readiness-v1",
  "cloud_layer_readiness_visible",
  "historical_only",
  "cloudflare_edge",
  "total_count",
  "total_layer_count"
)) {
  Assert-Contains "cloud runtime source" $cloudSource $required
}

foreach ($required in @(
  '@app.get("/api/v1/clouds")',
  '@app.get("/api/v1/clouds/layers")',
  '@app.get("/api/v1/clouds/deployment-preflight")'
)) {
  Assert-Contains "agent api technology endpoints" $agentApiSource $required
}

if ($StaticOnly) {
  Write-Host "[technology-runtime] static checks completed"
  return
}

$base = Normalize-BaseUrl $BaseUrl
Assert-BaseUrlAllowed $base ([bool]$AllowLocalhost)
Write-Host "[technology-runtime] runtime contracts"

$inventoryResult = Invoke-Contract "$base/api/v1/clouds"
$layersResult = Invoke-Contract "$base/api/v1/clouds/layers"
$preflightResult = Invoke-Contract "$base/api/v1/clouds/deployment-preflight"
$inventory = $inventoryResult.payload
$readiness = $layersResult.payload
$preflight = $preflightResult.payload
$runtimeSources = @($inventoryResult.source, $layersResult.source, $preflightResult.source)
$currentLiveProof = @($runtimeSources | Where-Object { $_ -ne "agent-api-boundary" }).Count -eq 0
$runtimeText = @($inventory, $readiness, $preflight) | ConvertTo-Json -Depth 100 -Compress
foreach ($forbidden in @("Hetzner", "GitKraken", "Oracle")) {
  Assert-NotContains "technology runtime active payloads" $runtimeText $forbidden
}

Assert-True "inventory contract version" ($inventory.contract_version -eq "cloud-provider-inventory-v1")
Assert-True "inventory evidence" ($inventory.evidence_ref -eq "cloud_provider_inventory_visible")
Assert-True "inventory endpoint" ($inventory.endpoint -eq "GET /api/v1/clouds")
Assert-True "inventory total count" ([int]$inventory.total_count -eq 8)
Assert-True "inventory providers array" ($inventory.providers -is [System.Array])
Assert-True "inventory provider count parity" (@($inventory.providers).Count -eq [int]$inventory.total_count)
Assert-True "inventory layer mapping array" ($inventory.seven_layer_mapping -is [System.Array])
Assert-True "inventory layer mapping count" (@($inventory.seven_layer_mapping).Count -eq 7)
Assert-StringArray "inventory non-claims" $inventory.non_claims

$providerIds = New-Object "System.Collections.Generic.HashSet[string]"
$providersById = @{}
foreach ($provider in @($inventory.providers)) {
  $id = [string]$provider.id
  Assert-True "provider id $id" ($provider.id -is [string] -and -not [string]::IsNullOrWhiteSpace($id))
  Assert-True "provider id unique $id" ($providerIds.Add($id))
  Assert-True "provider configured boolean $id" ($provider.configured -is [bool])
  Assert-True "provider live verified boolean $id" ($provider.live_verified -is [bool])
  Assert-True "provider status $id" ($provider.status -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$provider.status))
  Assert-StringArray "provider layers $id" $provider.layers $true
  Assert-StringArray "provider non-claims $id" $provider.non_claims
  $providersById[$id] = $provider
}
Assert-True "configured count parity" (
  @($inventory.providers | Where-Object { $_.configured -eq $true }).Count -eq [int]$inventory.configured_count
)
Assert-True "live verified count parity" (
  @($inventory.providers | Where-Object { $_.live_verified -eq $true }).Count -eq [int]$inventory.live_verified_count
)

$fly = @($inventory.providers | Where-Object { $_.id -eq "fly_io" })
Assert-True "Fly inventory singleton" ($fly.Count -eq 1)
$allowedFlyStatuses = @("historical_only", "historical_read_verified")
Assert-True "Fly exact historical status set" (
  [string]$fly[0].status -in $allowedFlyStatuses
)
Assert-True "Fly historical nonactive" (
  $fly[0].historical_only -is [bool] -and
  $fly[0].historical_only -eq $true -and
  @($fly[0].layers).Count -eq 0
)

$cloudflare = @($inventory.providers | Where-Object { $_.id -eq "cloudflare_edge" })
Assert-True "Cloudflare inventory singleton" ($cloudflare.Count -eq 1)
$expectedCloudflareLayers = @("layer_2", "layer_3", "layer_4", "layer_6", "layer_7")
Assert-True "Cloudflare active layer mapping" (
  (@($cloudflare[0].layers | Sort-Object) -join "|") -eq (($expectedCloudflareLayers | Sort-Object) -join "|")
)

$mappingById = @{}
foreach ($mapping in @($inventory.seven_layer_mapping)) {
  $layerId = [string]$mapping.layer_id
  Assert-True "mapping layer id $layerId" ($layerId -match "^layer_[1-7]$")
  Assert-True "mapping layer unique $layerId" (-not $mappingById.ContainsKey($layerId))
  Assert-StringArray "mapping providers $layerId" $mapping.providers
  foreach ($providerId in @($mapping.providers)) {
    Assert-True "mapping provider exists $layerId/$providerId" ($providerIds.Contains([string]$providerId))
    Assert-True "Fly absent from active mapping" ([string]$providerId -ne "fly_io")
  }
  $mappingById[$layerId] = $mapping
}
Assert-True "seven mapped layers" ($mappingById.Count -eq 7)

Assert-True "readiness contract version" ($readiness.contract_version -eq "cloud-layer-readiness-v1")
Assert-True "readiness evidence" ($readiness.evidence_ref -eq "cloud_layer_readiness_visible")
Assert-True "readiness endpoint" ($readiness.endpoint -eq "GET /api/v1/clouds/layers")
Assert-True "readiness inventory endpoint" ($readiness.provider_inventory_endpoint -eq "GET /api/v1/clouds")
Assert-True "readiness inventory evidence" ($readiness.provider_inventory_evidence_ref -eq "cloud_provider_inventory_visible")
Assert-True "readiness total count" ([int]$readiness.total_layer_count -eq 7)
Assert-True "readiness layers array" ($readiness.layers -is [System.Array])
Assert-True "readiness layer count parity" (@($readiness.layers).Count -eq [int]$readiness.total_layer_count)
Assert-StringArray "readiness non-claims" $readiness.non_claims

$readinessIds = New-Object "System.Collections.Generic.HashSet[string]"
$derivedReadyCount = 0
$derivedPartialCount = 0
foreach ($layer in @($readiness.layers)) {
  $layerId = [string]$layer.layer_id
  Assert-True "readiness layer id $layerId" ($layerId -match "^layer_[1-7]$")
  Assert-True "readiness layer unique $layerId" ($readinessIds.Add($layerId))
  Assert-True "readiness layer maps $layerId" ($mappingById.ContainsKey($layerId))
  Assert-StringArray "required providers $layerId" $layer.required_providers
  Assert-StringArray "configured providers $layerId" $layer.configured_providers $true
  Assert-StringArray "live providers $layerId" $layer.live_verified_providers $true
  Assert-StringArray "blockers $layerId" $layer.blockers $true
  $requiredProviderSet = New-Object "System.Collections.Generic.HashSet[string]"
  foreach ($providerId in @($layer.required_providers)) {
    [void]$requiredProviderSet.Add([string]$providerId)
  }
  $configuredProviderSet = New-Object "System.Collections.Generic.HashSet[string]"
  foreach ($providerId in @($layer.configured_providers)) {
    Assert-True "configured provider required $layerId/$providerId" (
      $requiredProviderSet.Contains([string]$providerId)
    )
    Assert-True "configured provider unique $layerId/$providerId" (
      $configuredProviderSet.Add([string]$providerId)
    )
  }
  $liveProviderSet = New-Object "System.Collections.Generic.HashSet[string]"
  foreach ($providerId in @($layer.live_verified_providers)) {
    Assert-True "live provider configured $layerId/$providerId" (
      $configuredProviderSet.Contains([string]$providerId)
    )
    Assert-True "live provider unique $layerId/$providerId" (
      $liveProviderSet.Add([string]$providerId)
    )
  }
  Assert-True "provider parity $layerId" (
    (@($layer.required_providers | Sort-Object) -join "|") -eq
    (@($mappingById[$layerId].providers | Sort-Object) -join "|")
  )
  if ($currentLiveProof) {
    $expectedConfigured = @($mappingById[$layerId].providers | Where-Object {
      $providersById[[string]$_].configured -eq $true
    })
    $expectedLive = @($mappingById[$layerId].providers | Where-Object {
      $providersById[[string]$_].live_verified -eq $true
    })
    Assert-True "current configured parity $layerId" (
      (@($layer.configured_providers | Sort-Object) -join "|") -eq
      (@($expectedConfigured | Sort-Object) -join "|")
    )
    Assert-True "current live parity $layerId" (
      (@($layer.live_verified_providers | Sort-Object) -join "|") -eq
      (@($expectedLive | Sort-Object) -join "|")
    )
  }
  $expectedLayerStatus = if (
    @($layer.blockers).Count -eq 0 -and
    @($layer.live_verified_providers).Count -ge @($layer.required_providers).Count
  ) {
    "live_verified"
  } elseif (@($layer.live_verified_providers).Count -gt 0) {
    "partial_live_verified"
  } elseif (@($layer.blockers).Count -gt 0) {
    "action_required"
  } else {
    "metadata_ready"
  }
  Assert-True "derived layer status $layerId" ([string]$layer.status -eq $expectedLayerStatus)
  if ($expectedLayerStatus -eq "live_verified") {
    $derivedReadyCount += 1
  } elseif ($expectedLayerStatus -eq "partial_live_verified") {
    $derivedPartialCount += 1
  }
}
Assert-True "readiness ready count parity" (
  $derivedReadyCount -eq [int]$readiness.ready_layer_count
)
Assert-True "readiness partial count parity" (
  $derivedPartialCount -eq [int]$readiness.partial_layer_count
)
$expectedReadinessStatus = if ($derivedReadyCount -eq @($readiness.layers).Count) {
  "verified"
} elseif ($derivedReadyCount -gt 0 -or $derivedPartialCount -gt 0) {
  "partial"
} else {
  "action_required"
}
Assert-True "derived readiness status" ([string]$readiness.status -eq $expectedReadinessStatus)

Assert-True "preflight contract version" ($preflight.contract_version -eq "cloud-deployment-preflight-v1")
Assert-True "preflight evidence" ($preflight.evidence_ref -eq "cloud_deployment_preflight_visible")
Assert-True "preflight endpoint" ($preflight.endpoint -eq "GET /api/v1/clouds/deployment-preflight")
Assert-True "preflight gates array" ($preflight.gates -is [System.Array])
Assert-True "preflight missing gates array" ($preflight.missing_or_blocked_gates -is [System.Array])
Assert-True "preflight production claim false" (
  $preflight.production_deploy_claim_allowed -is [bool] -and
  $preflight.production_deploy_claim_allowed -eq $false
)
Assert-True "preflight cloud claim false" (
  $preflight.cloud_deploy_claim_allowed -is [bool] -and
  $preflight.cloud_deploy_claim_allowed -eq $false
)
Assert-StringArray "preflight non-claims" $preflight.non_claims

$gateIds = New-Object "System.Collections.Generic.HashSet[string]"
foreach ($gate in @($preflight.gates)) {
  $gateId = [string]$gate.id
  Assert-True "preflight gate id $gateId" ($gate.id -is [string] -and -not [string]::IsNullOrWhiteSpace($gateId))
  Assert-True "preflight gate unique $gateId" ($gateIds.Add($gateId))
  Assert-True "preflight gate configured bool $gateId" ($gate.configured -is [bool])
  Assert-True "preflight gate verified bool $gateId" ($gate.verified -is [bool])
}
foreach ($missingGate in @($preflight.missing_or_blocked_gates)) {
  Assert-True "missing preflight gate exists $missingGate" ($gateIds.Contains([string]$missingGate))
}

Write-Host "[technology-runtime] providers=$($inventory.total_count) layers=$($readiness.total_layer_count) missing_gates=$(@($preflight.missing_or_blocked_gates).Count)"
Write-Host "[technology-runtime] sources=$($inventoryResult.source),$($layersResult.source),$($preflightResult.source)"
Write-Host "[technology-runtime] current_live_proof=$($currentLiveProof.ToString().ToLowerInvariant())"
Write-Host "[technology-runtime] checks completed"
