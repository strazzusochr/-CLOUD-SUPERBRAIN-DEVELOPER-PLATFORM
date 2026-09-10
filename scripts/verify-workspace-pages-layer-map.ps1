$ErrorActionPreference = "Stop"

function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) {
    throw "Verification failed: $label expected '$expected', got '$actual'."
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label missing '$expected'."
  }
}

function Assert-NotContains($label, $value, $forbidden) {
  $text = ($value | Out-String)
  if ($text.Contains($forbidden)) {
    throw "Verification failed: $label contains forbidden marker '$forbidden'."
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$navPath = Join-Path $repoRoot "apps\frontend\lib\nav.tsx"
$wiringPath = Join-Path $repoRoot "apps\frontend\lib\workspaceWiring.ts"
$workspaceWiringRoutePath = Join-Path $repoRoot "apps\frontend\app\api\v1\workspace\wiring\route.ts"
$organismContractRoutePath = Join-Path $repoRoot "apps\frontend\app\api\v1\organism\contract\route.ts"
$organismTopologyRoutePath = Join-Path $repoRoot "apps\frontend\app\api\v1\organism\topology\route.ts"
$agentApiPath = Join-Path $repoRoot "services\agent-api\app\main.py"
$appRoot = Join-Path $repoRoot "apps\frontend\app"
$systemArchitecturePath = Join-Path $repoRoot "docs\system-architecture.md"

if (-not (Test-Path -LiteralPath $navPath)) {
  throw "Missing navigation registry: $navPath"
}
if (-not (Test-Path -LiteralPath $systemArchitecturePath)) {
  throw "Missing architecture source: $systemArchitecturePath"
}
foreach ($requiredPath in @($wiringPath, $workspaceWiringRoutePath, $organismContractRoutePath, $organismTopologyRoutePath, $agentApiPath)) {
  if (-not (Test-Path -LiteralPath $requiredPath)) {
    throw "Missing workspace wiring dependency: $requiredPath"
  }
}

$nav = Get-Content -LiteralPath $navPath -Raw
$wiring = Get-Content -LiteralPath $wiringPath -Raw
$workspaceWiringRoute = Get-Content -LiteralPath $workspaceWiringRoutePath -Raw
$organismContractRoute = Get-Content -LiteralPath $organismContractRoutePath -Raw
$organismTopologyRoute = Get-Content -LiteralPath $organismTopologyRoutePath -Raw
$agentApi = Get-Content -LiteralPath $agentApiPath -Raw
$architecture = Get-Content -LiteralPath $systemArchitecturePath -Raw

$expectedPages = @(
  @{ id = "home"; no = 1; route = "/home"; layer = "FE" },
  @{ id = "login"; no = 2; route = "/login"; layer = "FE" },
  @{ id = "workbench"; no = 3; route = "/workbench"; layer = "FE" },
  @{ id = "organism"; no = 4; route = "/organism"; layer = "FE" },
  @{ id = "organism-replay"; no = 5; route = "/organism/replay"; layer = "OBS" },
  @{ id = "organism-map"; no = 6; route = "/organism/map"; layer = "FE" },
  @{ id = "agents"; no = 7; route = "/agents"; layer = "AP" },
  @{ id = "files"; no = 8; route = "/files"; layer = "MEM" },
  @{ id = "files-local"; no = 9; route = "/files/local"; layer = "MEM" },
  @{ id = "tools"; no = 10; route = "/tools"; layer = "MCP" },
  @{ id = "marketplace"; no = 11; route = "/marketplace"; layer = "LLM" },
  @{ id = "observe"; no = 12; route = "/observe"; layer = "OBS" },
  @{ id = "games"; no = 13; route = "/games"; layer = "AP" },
  @{ id = "apps"; no = 14; route = "/apps"; layer = "AP" },
  @{ id = "media"; no = 15; route = "/media"; layer = "LLM" },
  @{ id = "docs-output"; no = 16; route = "/docs-output"; layer = "MEM" },
  @{ id = "evidence"; no = 17; route = "/evidence"; layer = "OBS" },
  @{ id = "diagnostics"; no = 18; route = "/diagnostics"; layer = "OBS" },
  @{ id = "design-system"; no = 19; route = "/design-system"; layer = "FE" },
  @{ id = "stack"; no = 20; route = "/technology"; layer = "ORC" },
  @{ id = "settings"; no = 21; route = "/settings"; layer = "MCP" },
  @{ id = "open-source"; no = 22; route = "/open-source"; layer = "FE" }
)

$layerMap = @{
  FE = "1 Frontend"
  ORC = "2 Orchestration"
  AP = "3 Agent Pool"
  LLM = "4 LLM Gateway"
  MCP = "5 Tool MCP"
  MEM = "6 Memory"
  OBS = "7 Observability"
}

foreach ($entry in $layerMap.GetEnumerator()) {
  Assert-Contains "system architecture layer $($entry.Key)" $architecture $entry.Value
}

$matches = [regex]::Matches(
  $nav,
  '\{\s*id:\s*"(?<id>[^"]+)",\s*no:\s*(?<no>\d+),\s*label:\s*"(?<label>[^"]+)",\s*route:\s*"(?<route>[^"]+)",\s*icon:\s*"(?<icon>[^"]+)",\s*layer:\s*"(?<layer>[^"]+)"\s*\}'
)

Assert-Equal "workspace page count" $matches.Count 22

$seenRoutes = New-Object "System.Collections.Generic.HashSet[string]"
$seenNumbers = New-Object "System.Collections.Generic.HashSet[int]"
$seenIds = New-Object "System.Collections.Generic.HashSet[string]"

for ($i = 0; $i -lt $expectedPages.Count; $i++) {
  $match = $matches[$i]
  $expected = $expectedPages[$i]
  $actualNo = [int]$match.Groups["no"].Value
  $actualRoute = $match.Groups["route"].Value
  $actualLayer = $match.Groups["layer"].Value

  Assert-Equal "workspace page order $($i + 1) no" $actualNo $expected.no
  Assert-Equal "workspace page order $($i + 1) id" $match.Groups["id"].Value $expected.id
  Assert-Equal "workspace page order $($i + 1) route" $actualRoute $expected.route
  Assert-Equal "workspace page order $($i + 1) layer" $actualLayer $expected.layer

  if (-not $seenRoutes.Add($actualRoute)) {
    throw "Verification failed: duplicate route '$actualRoute'."
  }
  if (-not $seenNumbers.Add($actualNo)) {
    throw "Verification failed: duplicate page number '$actualNo'."
  }
  if (-not $seenIds.Add($match.Groups["id"].Value)) {
    throw "Verification failed: duplicate page id '$($match.Groups["id"].Value)'."
  }
  if (-not $layerMap.ContainsKey($actualLayer)) {
    throw "Verification failed: unknown layer code '$actualLayer'."
  }
}

$wiringMatches = [regex]::Matches($wiring, 'pageId:\s*"(?<id>[^"]+)"')
Assert-Equal "workspace wiring count" $wiringMatches.Count 22

$allowedRegions = @("prefrontal", "thalamus", "hippocampus", "amygdala", "basal", "cerebellum", "motor", "sensory", "autonomic", "callosum")
$allowedHubs = @("workbench", "agents", "tools", "models", "marketplace", "observe", "memory", "cloud")
$seenWiringIds = New-Object "System.Collections.Generic.HashSet[string]"
foreach ($page in $expectedPages) {
  if (-not $seenWiringIds.Add($page.id)) {
    throw "Verification failed: duplicate expected wiring id '$($page.id)'."
  }
  $blockMatch = [regex]::Match($wiring, '(?s)\{\s*pageId:\s*"' + [regex]::Escape($page.id) + '".*?secretOutput:\s*false,\s*\}')
  if (-not $blockMatch.Success) {
    throw "Verification failed: workspace wiring missing complete block for '$($page.id)'."
  }
  $block = $blockMatch.Value
  $regionMatch = [regex]::Match($block, 'brainRegion:\s*"(?<region>[^"]+)"')
  $hubMatch = [regex]::Match($block, 'hub:\s*"(?<hub>[^"]+)"')
  if (-not $regionMatch.Success -or -not ($allowedRegions -contains $regionMatch.Groups["region"].Value)) {
    throw "Verification failed: workspace wiring '$($page.id)' has invalid brain region."
  }
  if (-not $hubMatch.Success -or -not ($allowedHubs -contains $hubMatch.Groups["hub"].Value)) {
    throw "Verification failed: workspace wiring '$($page.id)' has invalid hub."
  }
  Assert-Contains "workspace wiring data sources $($page.id)" $block "dataSources:"
  Assert-Contains "workspace wiring verifier refs $($page.id)" $block "verifierRefs:"
  Assert-Contains "workspace wiring live false $($page.id)" $block "live: false"
  Assert-Contains "workspace wiring writes false $($page.id)" $block "writes: false"
  Assert-Contains "workspace wiring secret output false $($page.id)" $block "secretOutput: false"
}

Assert-Contains "workspace wiring contract version" $wiring 'workspace-surface-wiring-v1'
Assert-Contains "workspace wiring evidence ref" $wiring 'workspace_surface_wiring_visible'
Assert-Contains "workspace wiring endpoint" $workspaceWiringRoute 'endpoint: "/api/v1/workspace/wiring"'
Assert-Contains "workspace wiring page count" $workspaceWiringRoute "page_count: surfaces.length"
Assert-Contains "organism contract workspace pages" $organismContractRoute "workspace_pages"
Assert-Contains "organism contract workspace related endpoint" $organismContractRoute '"/api/v1/workspace/wiring"'
Assert-Contains "organism topology page region edges" $organismTopologyRoute "page_to_brain_region"
Assert-Contains "organism topology page hub edges" $organismTopologyRoute "page_to_capability_hub"
Assert-Contains "organism topology page data edges" $organismTopologyRoute "page_to_data_source"
Assert-Contains "organism topology page verifier edges" $organismTopologyRoute "page_to_verifier"
Assert-Contains "agent-api workspace wiring contract version" $agentApi "WORKSPACE_WIRING_CONTRACT_VERSION"
Assert-Contains "agent-api workspace wiring endpoint" $agentApi '@app.get("/api/v1/workspace/wiring")'
Assert-Contains "agent-api organism workspace page count" $agentApi "workspace_page_count"
Assert-Contains "agent-api topology page region edges" $agentApi "page_to_brain_region"
Assert-Contains "agent-api topology page data edges" $agentApi "page_to_data_source"
Assert-Contains "agent-api topology page verifier edges" $agentApi "page_to_verifier"
Assert-Contains "agent-api stack page id" $agentApi '(20, "stack", "/technology", "Technologie-Stack", "ORC")'

foreach ($page in $expectedPages) {
  $relative = ($page.route.TrimStart("/") -replace "/", "\") + "\page.tsx"
  $pagePath = Join-Path $appRoot $relative
  if (-not (Test-Path -LiteralPath $pagePath)) {
    throw "Verification failed: workspace route '$($page.route)' missing page file '$relative'."
  }
}

foreach ($legacyRoute in @("/about/stack", "/about/open-source", "/design-system/responsive")) {
  Assert-NotContains "workspace page registry" $nav "route: `"$legacyRoute`""
}

foreach ($supplementalRoute in @("/", "/organism/live", "/responsive")) {
  if ($supplementalRoute -eq "/") {
    $relative = "page.tsx"
  } else {
    $relative = ($supplementalRoute.TrimStart("/") -replace "/", "\") + "\page.tsx"
  }
  $pagePath = Join-Path $appRoot $relative
  if (-not (Test-Path -LiteralPath $pagePath)) {
    throw "Verification failed: supplemental route '$supplementalRoute' missing page file '$relative'."
  }
  Assert-NotContains "workspace page registry supplemental route" $nav "route: `"$supplementalRoute`""
}

Write-Host "[workspace-pages-layer-map] canonical 22 page registry verified"
