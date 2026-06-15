param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
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

Write-Host "[organism-topology] runtime topology"
$base = Normalize-BaseUrl $BaseUrl
Assert-BaseUrlAllowed $base ([bool]$AllowLocalhost)

foreach ($path in @(
  "apps\frontend\app\api\v1\organism\topology\route.ts",
  "apps\frontend\app\api\v1\organism\contract\route.ts",
  "apps\frontend\lib\platform.ts",
  "apps\frontend\components\organism\regionMap.ts",
  "services\agent-api\app\main.py"
)) {
  Assert-True "required source exists $path" (Test-Path $path)
}

$frontendTopologySource = Get-Content -Path "apps\frontend\app\api\v1\organism\topology\route.ts" -Raw
$frontendContractSource = Get-Content -Path "apps\frontend\app\api\v1\organism\contract\route.ts" -Raw
$platformSource = Get-Content -Path "apps\frontend\lib\platform.ts" -Raw
$regionSource = Get-Content -Path "apps\frontend\components\organism\regionMap.ts" -Raw
$agentApiSource = Get-Content -Path "services\agent-api\app\main.py" -Raw

foreach ($required in @(
  "organism-topology-v1",
  "agent_to_tool",
  "agent_to_model",
  "page_to_data_source",
  "page_to_verifier",
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
  "PROVIDERS",
  "LAYERS",
  "Vercel",
  "Fly.io",
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
  "{ id: `"P4`", pct: 99 }"
)) {
  Assert-Contains "platform source" $platformSource $required
}

foreach ($required in @(
  "def organism_topology_payload",
  "organism-topology-v1",
  '"kind": "agent_to_tool"',
  '"kind": "page_to_verifier"',
  '"kind": "layer_to_provider"',
  '@app.get("/api/v1/organism/topology")'
)) {
  Assert-Contains "agent api topology source" $agentApiSource $required
}

$topology = Invoke-Json "$base/api/v1/organism/topology"
$contract = Invoke-Json "$base/api/v1/organism/contract"
$wiring = Invoke-Json "$base/api/v1/workspace/wiring"
$vertical = Invoke-Json "$base/api/v1/workspace/vertical-stack"

Assert-True "topology contract version" ($topology.contract_version -eq "organism-topology-v1")
Assert-True "organism contract version" ($contract.contract_version -eq "organism-surface-v1")
Assert-True "workspace wiring version" ($wiring.contract_version -eq "workspace-surface-wiring-v1")
Assert-True "workspace vertical version" ($vertical.contract_version -eq "workspace-vertical-stack-v1")
Assert-True "topology live false" ($topology.live -eq $false)
Assert-True "topology source kind contract" ($topology.source_kind -eq "contract")

$nodes = @($topology.nodes)
$edges = @($topology.edges)
Assert-True "topology has nodes" ($nodes.Count -gt 0)
Assert-True "topology has edges" ($edges.Count -gt 0)

$nodeIds = New-Object "System.Collections.Generic.HashSet[string]"
foreach ($node in $nodes) {
  $id = [string]$node.id
  Assert-True "node id present" (-not [string]::IsNullOrWhiteSpace($id))
  Assert-True "node id unique $id" ($nodeIds.Add($id))
  Assert-True "node secret output false $id" ($node.secret_output -eq $false)
  Assert-True "node writes false $id" ($node.writes -eq $false)
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
  "provider:ghcr_registry",
  "provider:grafana_cloud",
  "page:workbench",
  "page:organism",
  "page:open-source"
)) {
  Assert-True "required node $requiredId" ($nodeIds.Contains($requiredId))
}

$edgeKinds = New-Object "System.Collections.Generic.HashSet[string]"
foreach ($edge in $edges) {
  $from = [string]$edge.from
  $to = [string]$edge.to
  $kind = [string]$edge.kind
  Assert-True "edge from exists $from" ($nodeIds.Contains($from))
  Assert-True "edge to exists $to" ($nodeIds.Contains($to))
  Assert-True "edge kind present" (-not [string]::IsNullOrWhiteSpace($kind))
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
  "layer_to_provider",
  "gate_to_security_region"
)) {
  Assert-True "required edge kind $requiredKind" ($edgeKinds.Contains($requiredKind))
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
