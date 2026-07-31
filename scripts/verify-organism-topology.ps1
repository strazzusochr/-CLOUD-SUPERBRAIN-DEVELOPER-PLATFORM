param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$StaticOnly
)

$ErrorActionPreference = "Stop"

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
    throw "Localhost topology proof requires -AllowLocalhost and remains DEV-ONLY"
  }
  if (-not $isLocal -and $uri.Scheme -ne "https") {
    throw "Hosted topology proof requires HTTPS"
  }
}

function Invoke-Json([string]$Url) {
  try {
    return Invoke-RestMethod -Method Get -Uri $Url -TimeoutSec 30 -ErrorAction Stop
  } catch {
    throw "Failed to fetch JSON from ${Url}: $($_.Exception.Message)"
  }
}

function Group-NodeKinds($Nodes) {
  $counts = @{}
  foreach ($node in @($Nodes)) {
    $kind = [string]$node.kind
    if (-not $counts.ContainsKey($kind)) {
      $counts[$kind] = 0
    }
    $counts[$kind] += 1
  }
  return $counts
}

function Get-TopologyMirrorProjection([string]$Label, $Payload) {
  Assert-True "$Label payload object" ($null -ne $Payload)
  Assert-True "$Label live strict false" ($Payload.live -is [bool] -and $Payload.live -eq $false)
  Assert-True "$Label nodes array" ($Payload.nodes -is [System.Array])
  Assert-True "$Label edges array" ($Payload.edges -is [System.Array])
  Assert-True "$Label non-claims array" ($Payload.non_claims -is [System.Array])

  $nodes = @($Payload.nodes)
  $nodeIds = @($nodes | ForEach-Object { [string]$_.id })
  Assert-True "$Label node IDs unique" (@($nodeIds | Sort-Object -Unique).Count -eq $nodeIds.Count)

  return [ordered]@{
    contract_version = [string]$Payload.contract_version
    evidence_ref = [string]$Payload.evidence_ref
    endpoint = [string]$Payload.endpoint
    source_kind = [string]$Payload.source_kind
    live = [bool]$Payload.live
    nodes = @(
      $nodes |
        ForEach-Object {
          $displayLabel = if ($null -ne $_.label) {
            [string]$_.label
          } elseif ($null -ne $_.name) {
            [string]$_.name
          } else {
            [string]$_.id
          }
          "$([string]$_.id)`t$([string]$_.kind)`t$([string]$_.writes)`t$([string]$_.secret_output)`t$displayLabel"
        } |
        Sort-Object
    )
    edges = @(
      @($Payload.edges) |
        ForEach-Object { "$([string]$_.from)`t$([string]$_.to)`t$([string]$_.kind)" } |
        Sort-Object
    )
    non_claims = @(@($Payload.non_claims) | ForEach-Object { [string]$_ } | Sort-Object)
  }
}

function Invoke-BackendTopologyJson {
  $previousErrorPreference = $ErrorActionPreference
  $result = $null
  try {
    $ErrorActionPreference = "Continue"
    if (Test-Path ".venv\Scripts\python.exe") {
      $output = & ".venv\Scripts\python.exe" "scripts\emit-organism-topology-backend.py" 2>&1
      if ($LASTEXITCODE -eq 0 -and @($output).Count -gt 0) {
        $result = $output -join "`n"
      }
    }
    if ($null -eq $result -and (Get-Command py -ErrorAction SilentlyContinue)) {
      $output = & py -3.12 "scripts\emit-organism-topology-backend.py" 2>&1
      if ($LASTEXITCODE -eq 0 -and @($output).Count -gt 0) {
        $result = $output -join "`n"
      }
    }
    if ($null -eq $result -and (Get-Command python -ErrorAction SilentlyContinue)) {
      $output = & python "scripts\emit-organism-topology-backend.py" 2>&1
      if ($LASTEXITCODE -eq 0 -and @($output).Count -gt 0) {
        $result = $output -join "`n"
      }
    }
  } finally {
    $ErrorActionPreference = $previousErrorPreference
  }
  if ($null -ne $result) {
    return $result
  }
  throw "Unable to execute the Agent API topology builder with installed project dependencies."
}

Write-Host "[organism-topology] static topology surface"

foreach ($path in @(
  "apps\frontend\app\api\v1\organism\topology\route.ts",
  "apps\frontend\app\api\v1\organism\contract\route.ts",
  "apps\frontend\app\organism\map\page.tsx",
  "apps\frontend\components\organism\OrganismTopologyMap.tsx",
  "apps\frontend\e2e\22-page-actions.spec.ts",
  "apps\frontend\e2e\organism.spec.ts",
  "apps\frontend\lib\actionMatrix.ts",
  "apps\frontend\lib\platform.ts",
  "apps\frontend\lib\workspaceWiring.ts",
  "apps\frontend\components\organism\regionMap.ts",
  "scripts\emit-organism-topology-backend.py",
  "scripts\emit-organism-topology-route.cjs",
  "services\agent-api\app\main.py"
)) {
  Assert-True "required source exists $path" (Test-Path $path)
}

$frontendTopologySource = Get-Content -Path "apps\frontend\app\api\v1\organism\topology\route.ts" -Raw
$frontendContractSource = Get-Content -Path "apps\frontend\app\api\v1\organism\contract\route.ts" -Raw
$organismMapPageSource = Get-Content -Path "apps\frontend\app\organism\map\page.tsx" -Raw
$organismMapComponentSource = Get-Content -Path "apps\frontend\components\organism\OrganismTopologyMap.tsx" -Raw
$actionRunnerSource = Get-Content -Path "apps\frontend\e2e\22-page-actions.spec.ts" -Raw
$organismE2eSource = Get-Content -Path "apps\frontend\e2e\organism.spec.ts" -Raw
$actionMatrixSource = Get-Content -Path "apps\frontend\lib\actionMatrix.ts" -Raw
$platformSource = Get-Content -Path "apps\frontend\lib\platform.ts" -Raw
$regionSource = Get-Content -Path "apps\frontend\components\organism\regionMap.ts" -Raw
$agentApiSource = Get-Content -Path "services\agent-api\app\main.py" -Raw

foreach ($required in @(
  "organism-topology-v1",
  "organism_topology_visible",
  "/api/v1/organism/topology",
  "agent_to_tool",
  "agent_to_model",
  "page_to_data_source",
  "page_to_verifier",
  "directCapabilityEdges",
  'region:${hub.region}',
  "layer_to_provider",
  "gate_to_security_region",
  "secret_output: false",
  "writes: false"
)) {
  Assert-Contains "frontend topology source" $frontendTopologySource $required
}

foreach ($required in @(
  "workspace_page_count",
  "Topology edges must reference existing layer, region, hub, agent, tool, model, skill, provider, and gate nodes.",
  "/api/v1/workspace/vertical-stack"
)) {
  Assert-Contains "frontend organism contract source" $frontendContractSource $required
}

foreach ($required in @(
  "ORGANISM_AGENTS",
  'region: "motor"',
  'region: "basal"',
  'region: "thalamus"',
  "PROVIDERS",
  "LAYERS",
  "Vercel",
  "Cloudflare-native Runtime / Workers AI",
  "Historical read-only provider inventory",
  "GHCR",
  "Grafana Cloud"
)) {
  Assert-Contains "region map source" $regionSource $required
}

foreach ($required in @(
  "AGENTS",
  "MCP_TOOLS",
  "MODELS",
  "SKILLS",
  "CLOSED_GATES",
  "{ id: `"P4`", pct: 100 }"
)) {
  Assert-Contains "platform source" $platformSource $required
}

foreach ($required in @(
  "def organism_topology_payload",
  "organism-topology-v1",
  "organism_topology_visible",
  '"kind": "agent_to_tool"',
  '"kind": "page_to_verifier"',
  'f"region:{h[''region'']}"',
  '"kind": "layer_to_provider"',
  '@app.get("/api/v1/organism/topology")'
)) {
  Assert-Contains "agent api topology source" $agentApiSource $required
}

foreach ($required in @(
  "OrganismTopologyMap",
  "<OrganismTopologyMap"
)) {
  Assert-Contains "organism map page" $organismMapPageSource $required
}
Assert-NotContains "organism map page" $organismMapPageSource "OrganismView"

foreach ($required in @(
  '"use client"',
  "/api/v1/organism/topology",
  "organism-topology-v1",
  "organism_topology_visible",
  "page:organism-map",
  "isTopologyNode",
  "isTopologyEdge",
  "isTopologyPayload",
  "Array.isArray(value.nodes)",
  "Array.isArray(value.edges)",
  "Array.isArray(value.non_claims)",
  "value.writes === false",
  "value.secret_output === false",
  "value.non_claims.every((claim) => isNonEmptyString(claim)",
  "MAX_TOPOLOGY_NODES",
  "MAX_TOPOLOGY_EDGES",
  "MAX_NON_CLAIMS",
  "MAX_TOPOLOGY_RESPONSE_BYTES",
  "MAX_NODE_LABEL_LENGTH",
  "readBoundedJson",
  "response.body?.getReader()",
  "reader.cancel",
  "TextDecoder",
  "normalizeTopologyPayload",
  "topologyRequest === request",
  "topologyRequest = null",
  "retryTopology",
  "organism-topology-retry",
  "nodeIds.size === value.nodes.length",
  "nodeIds.has(edge.from) && nodeIds.has(edge.to)",
  'method: "GET"',
  "organism-topology-map",
  "organism-topology-loading",
  "organism-topology-error",
  "organism-topology-kind-filter",
  "organism-topology-node",
  "organism-topology-adjacent-node",
  "organism-topology-adjacency",
  "data-contract-version",
  "data-evidence-ref",
  "data-endpoint",
  "data-source-kind",
  "data-live",
  "data-read-only",
  "data-node-count",
  "data-edge-count",
  "data-selected-node-id",
  "data-node-kind",
  "data-node-id",
  "data-edge-kind",
  "data-direction",
  "data-incoming-count",
  "data-outgoing-count",
  "aria-pressed"
)) {
  Assert-Contains "organism topology component" $organismMapComponentSource $required
}
Assert-NotContains "organism topology component" $organismMapComponentSource "OrganismView"
Assert-NotContains "organism topology component" $organismMapComponentSource "http://"
Assert-NotContains "organism topology component" $organismMapComponentSource "https://"
Assert-NotContains "organism topology component" $organismMapComponentSource "response.json()"

foreach ($required in @(
  "organism map renders topology counts, filters, selection, and adjacency without the Phase-6 scene",
  "organism map rejects an oversized otherwise-valid topology before rendering",
  "organism map retries after a transient topology failure",
  "organism-topology-v1",
  "organism_topology_visible",
  "page:organism-map",
  "agent:planner",
  "agent:coder",
  "organism-topology-map",
  "organism-topology-kind-filter",
  "organism-topology-node",
  "organism-topology-adjacent-node",
  "organism-topology-adjacency",
  "data-edge-kind",
  "data-direction",
  "600_000",
  'page.locator("canvas")',
  'page.locator(".cortex-wrap")',
  'data-testid^="phase6-"'
)) {
  Assert-Contains "organism topology browser proof" $organismE2eSource $required
}

foreach ($required in @(
  "map-topology-kind-filter",
  "organism-topology-node-list",
  "requireEffectDelta: true"
)) {
  Assert-Contains "organism topology action matrix" $actionMatrixSource $required
}

foreach ($required in @(
  "action.requireEffectDelta",
  "control must produce a concrete effect-target delta"
)) {
  Assert-Contains "organism topology action runner" $actionRunnerSource $required
}

Write-Host "[organism-topology] normalized frontend/backend mirror"
$previousConsoleOutputEncoding = [Console]::OutputEncoding
$previousPipelineOutputEncoding = $OutputEncoding
try {
  $utf8OutputEncoding = [Text.UTF8Encoding]::new($false)
  [Console]::OutputEncoding = $utf8OutputEncoding
  $OutputEncoding = $utf8OutputEncoding
  $frontendTopologyOutput = & node scripts\emit-organism-topology-route.cjs 2>&1
  $frontendTopologyExit = $LASTEXITCODE
} finally {
  [Console]::OutputEncoding = $previousConsoleOutputEncoding
  $OutputEncoding = $previousPipelineOutputEncoding
}
if ($frontendTopologyExit -ne 0) {
  throw "Frontend topology route emitter failed: $($frontendTopologyOutput -join "`n")"
}
$frontendTopologyJson = $frontendTopologyOutput -join "`n"
$backendTopologyJson = Invoke-BackendTopologyJson
$frontendMirror = $frontendTopologyJson | ConvertFrom-Json
$backendMirror = $backendTopologyJson | ConvertFrom-Json
Assert-True "frontend topology source identity" ($frontendMirror.source -eq "static_runtime_contract")
Assert-True "backend topology source identity" ($backendMirror.source -eq "agent-api-static-contract")
Assert-True "frontend topology response byte ceiling" (
  [System.Text.Encoding]::UTF8.GetByteCount($frontendTopologyJson) -le 524288
)
$frontendProjection = Get-TopologyMirrorProjection "frontend topology mirror" $frontendMirror
$backendProjection = Get-TopologyMirrorProjection "backend topology mirror" $backendMirror
$frontendProjectionJson = $frontendProjection | ConvertTo-Json -Depth 6 -Compress
$backendProjectionJson = $backendProjection | ConvertTo-Json -Depth 6 -Compress
$topologyMirrorsMatch = [string]::Equals(
  $frontendProjectionJson,
  $backendProjectionJson,
  [System.StringComparison]::Ordinal
)
if (-not $topologyMirrorsMatch) {
  $scalarDiffs = @(
    foreach ($key in @("contract_version", "evidence_ref", "endpoint", "source_kind", "live")) {
      if ([string]$frontendProjection[$key] -cne [string]$backendProjection[$key]) {
        "${key}:frontend=$($frontendProjection[$key]),backend=$($backendProjection[$key])"
      }
    }
  )
  $nodeDiffs = @(
    Compare-Object @($frontendProjection.nodes) @($backendProjection.nodes) -CaseSensitive |
      Select-Object -First 3 |
      ForEach-Object { "$($_.SideIndicator):$($_.InputObject)" }
  )
  $edgeDiffs = @(
    Compare-Object @($frontendProjection.edges) @($backendProjection.edges) -CaseSensitive |
      Select-Object -First 3 |
      ForEach-Object { "$($_.SideIndicator):$($_.InputObject)" }
  )
  $nonClaimDiffs = @(
    Compare-Object @($frontendProjection.non_claims) @($backendProjection.non_claims) -CaseSensitive |
      Select-Object -First 3 |
      ForEach-Object { "$($_.SideIndicator):$($_.InputObject)" }
  )
  throw (
    "Verification failed: normalized topology mirrors match; " +
    "scalar_diffs=$($scalarDiffs -join '|'); " +
    "node_diffs=$($nodeDiffs -join '|'); " +
    "edge_diffs=$($edgeDiffs -join '|'); " +
    "non_claim_diffs=$($nonClaimDiffs -join '|')"
  )
}
Write-Host "[organism-topology] mirror nodes=$(@($frontendMirror.nodes).Count) edges=$(@($frontendMirror.edges).Count)"

if ($StaticOnly) {
  Write-Host "[organism-topology] static checks completed"
  return
}

Write-Host "[organism-topology] runtime topology"
$base = Normalize-BaseUrl $BaseUrl
Assert-BaseUrlAllowed $base ([bool]$AllowLocalhost)

$topology = Invoke-Json "$base/api/v1/organism/topology"
$contract = Invoke-Json "$base/api/v1/organism/contract"
$wiring = Invoke-Json "$base/api/v1/workspace/wiring"
$vertical = Invoke-Json "$base/api/v1/workspace/vertical-stack"

Assert-True "topology contract version" ($topology.contract_version -eq "organism-topology-v1")
Assert-True "topology evidence ref" ($topology.evidence_ref -eq "organism_topology_visible")
Assert-True "topology endpoint" ($topology.endpoint -eq "/api/v1/organism/topology")
Assert-True "organism contract version" ($contract.contract_version -eq "organism-surface-v1")
Assert-True "workspace wiring version" ($wiring.contract_version -eq "workspace-surface-wiring-v1")
Assert-True "workspace vertical version" ($vertical.contract_version -eq "workspace-vertical-stack-v1")
Assert-True "topology live is strict false" ($topology.live -is [bool] -and $topology.live -eq $false)
Assert-True "topology source kind contract" ($topology.source_kind -eq "contract")

$nodes = @($topology.nodes)
$edges = @($topology.edges)
$nonClaims = @($topology.non_claims)
Assert-True "topology nodes is array" ($topology.nodes -is [System.Array])
Assert-True "topology edges is array" ($topology.edges -is [System.Array])
Assert-True "topology non-claims is array" ($topology.non_claims -is [System.Array])
Assert-True "topology has nodes" ($nodes.Count -gt 0)
Assert-True "topology has edges" ($edges.Count -gt 0)
Assert-True "topology has non-claims" ($nonClaims.Count -gt 0)
Assert-True "topology node count bounded" ($nodes.Count -le 512)
Assert-True "topology edge count bounded" ($edges.Count -le 4096)
Assert-True "topology non-claim count bounded" ($nonClaims.Count -le 32)
$runtimeTopologyJson = $topology | ConvertTo-Json -Depth 12 -Compress
Assert-True "topology serialized byte ceiling" (
  [System.Text.Encoding]::UTF8.GetByteCount($runtimeTopologyJson) -le 524288
)
foreach ($nonClaim in $nonClaims) {
  Assert-True "topology non-claim is a non-empty string" (
    $nonClaim -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$nonClaim)
  )
  Assert-True "topology non-claim length bounded" (([string]$nonClaim).Length -le 500)
}
Assert-True "topology non-claims deny provider writes" (($nonClaims -join " ") -match "no provider write")
Assert-True "topology non-claims deny secret output" (($nonClaims -join " ") -match "no secret")

$nodeIds = New-Object "System.Collections.Generic.HashSet[string]"
foreach ($node in $nodes) {
  $id = [string]$node.id
  Assert-True "node id present" ($node.id -is [string] -and -not [string]::IsNullOrWhiteSpace($id))
  Assert-True "node kind present $id" ($node.kind -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$node.kind))
  Assert-True "node id bounded $id" ($id.Length -le 256)
  Assert-True "node kind bounded $id" (([string]$node.kind).Length -le 64)
  Assert-True "node id unique $id" ($nodeIds.Add($id))
  Assert-True "node secret output strict false $id" ($node.secret_output -is [bool] -and $node.secret_output -eq $false)
  Assert-True "node writes strict false $id" ($node.writes -is [bool] -and $node.writes -eq $false)
}

$counts = Group-NodeKinds $nodes
$expectedCounts = @{
  brain_region = 10
  architecture_layer = 7
  capability_hub = 8
  agent_profile = 4
  mcp_tool = 8
  llm_model = 4
  skill = 10
  cloud_provider = 8
  safety_gate = 8
  workspace_page = 22
}
foreach ($kind in $expectedCounts.Keys) {
  Assert-True "node kind count $kind" ([int]$counts[$kind] -eq [int]$expectedCounts[$kind])
}
Assert-True "workspace data source nodes present" ([int]$counts["workspace_data_source"] -ge 40)
Assert-True "workspace verifier nodes present" ([int]$counts["workspace_verifier"] -ge 8)

foreach ($requiredId in @(
  "region:prefrontal",
  "region:callosum",
  "layer:FE",
  "layer:ORC",
  "layer:AP",
  "layer:LLM",
  "layer:MCP",
  "layer:MEM",
  "layer:OBS",
  "agent:planner",
  "agent:coder",
  "agent:tester",
  "agent:devops",
  "tool:mcp_gateway",
  "model:Qwen/Qwen3-Coder-Next",
  "provider:vercel_frontend",
  "provider:fly_io",
  "provider:cloudflare_edge",
  "provider:ghcr_registry",
  "provider:grafana_cloud",
  "page:workbench",
  "page:organism",
  "page:organism-map",
  "page:open-source"
)) {
  Assert-True "required node $requiredId" ($nodeIds.Contains($requiredId))
}

$edgeKinds = New-Object "System.Collections.Generic.HashSet[string]"
foreach ($edge in $edges) {
  $from = [string]$edge.from
  $to = [string]$edge.to
  $kind = [string]$edge.kind
  Assert-True "edge from is string" ($edge.from -is [string] -and -not [string]::IsNullOrWhiteSpace($from))
  Assert-True "edge to is string" ($edge.to -is [string] -and -not [string]::IsNullOrWhiteSpace($to))
  Assert-True "edge from exists $from" ($nodeIds.Contains($from))
  Assert-True "edge to exists $to" ($nodeIds.Contains($to))
  Assert-True "edge kind present" ($edge.kind -is [string] -and -not [string]::IsNullOrWhiteSpace($kind))
  Assert-True "edge from bounded" ($from.Length -le 256)
  Assert-True "edge to bounded" ($to.Length -le 256)
  Assert-True "edge kind bounded" ($kind.Length -le 128)
  [void]$edgeKinds.Add($kind)
}

foreach ($requiredKind in @(
  "neural_bus",
  "capability_to_region",
  "hub_to_layer",
  "agent_to_hub",
  "agent_to_tool",
  "agent_to_model",
  "tool_to_layer",
  "model_to_gateway_layer",
  "skill_to_tool_hub",
  "page_to_layer",
  "page_to_brain_region",
  "page_to_capability_hub",
  "page_to_data_source",
  "page_to_verifier",
  "page_to_llm_model",
  "page_to_skill",
  "page_to_mcp_tool",
  "page_to_cloud_provider",
  "page_to_agent_profile",
  "page_to_safety_gate",
  "layer_to_provider",
  "gate_to_security_region"
)) {
  Assert-True "required edge kind $requiredKind" ($edgeKinds.Contains($requiredKind))
}

Assert-True "historical Fly has no active layer edge" (@(
  $edges | Where-Object { $_.kind -eq "layer_to_provider" -and $_.to -eq "provider:fly_io" }
).Count -eq 0)
foreach ($layerCode in @("ORC", "AP", "LLM", "MEM", "OBS")) {
  Assert-True "Cloudflare-native provider backs $layerCode" (@(
    $edges | Where-Object {
      $_.kind -eq "layer_to_provider" -and
      $_.from -eq "layer:$layerCode" -and
      $_.to -eq "provider:cloudflare_edge"
    }
  ).Count -eq 1)
}

$pageNodes = @($nodes | Where-Object { $_.kind -eq "workspace_page" })
Assert-True "workspace page count parity" ($pageNodes.Count -eq [int]$wiring.page_count)
Assert-True "vertical stack count parity" ($pageNodes.Count -eq [int]$vertical.page_count)
Assert-True "organism contract page count parity" ($pageNodes.Count -eq [int]$contract.workspace_page_count)

foreach ($page in @($wiring.surfaces)) {
  $pageId = [string]$page.pageId
  Assert-True "page node exists $pageId" ($nodeIds.Contains("page:$pageId"))
  Assert-True "page has layer edge $pageId" (@($edges | Where-Object { $_.from -eq "page:$pageId" -and $_.kind -eq "page_to_layer" }).Count -eq 1)
  Assert-True "page has brain edge $pageId" (@($edges | Where-Object { $_.from -eq "page:$pageId" -and $_.kind -eq "page_to_brain_region" }).Count -eq 1)
  Assert-True "page has hub edge $pageId" (@($edges | Where-Object { $_.from -eq "page:$pageId" -and $_.kind -eq "page_to_capability_hub" }).Count -eq 1)
  Assert-True "page has data edges $pageId" (@($edges | Where-Object { $_.from -eq "page:$pageId" -and $_.kind -eq "page_to_data_source" }).Count -ge 1)
  Assert-True "page has verifier edges $pageId" (@($edges | Where-Object { $_.from -eq "page:$pageId" -and $_.kind -eq "page_to_verifier" }).Count -ge 1)
}

$forbiddenText = ($topology | ConvertTo-Json -Depth 12)
foreach ($forbidden in @("Hetzner", "GitKraken", "Oracle", '"productionDeployClaimAllowed":true', '"secret_output":true', '"writes":true')) {
  if ($forbiddenText.Contains($forbidden)) {
    throw "Topology contains forbidden active marker: $forbidden"
  }
}

Write-Host "[organism-topology] nodes=$($nodes.Count) edges=$($edges.Count)"
Write-Host "[organism-topology] checks completed"
