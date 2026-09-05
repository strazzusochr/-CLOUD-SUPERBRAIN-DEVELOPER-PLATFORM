param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Workspace data source verification failed: $label"
  }
}

function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) {
    throw "Workspace data source verification failed: $label expected '$expected', got '$actual'."
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Workspace data source verification failed: $label missing '$expected'."
  }
}

function Assert-NotContains($label, $value, $forbidden) {
  $text = ($value | Out-String)
  if ($text.Contains($forbidden)) {
    throw "Workspace data source verification failed: $label contains forbidden '$forbidden'."
  }
}

function Invoke-Json($url) {
  return Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 60
}

function Test-AgentApiRoute($source, $route) {
  $routePattern = [regex]::Escape([string]$route)
  $decoratorPattern = '(?m)^\s*@app\.(?:get|post|delete)\(\s*["'']{0}["''](?:\s*,[^\r\n)]*)?\s*\)' -f $routePattern
  return [regex]::IsMatch([string]$source, $decoratorPattern)
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Workspace data source proof refuses localhost unless -AllowLocalhost is set"
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$wiringPath = Join-Path $repoRoot "apps\frontend\lib\workspaceWiring.ts"
$verticalPath = Join-Path $repoRoot "apps\frontend\lib\workspaceVerticalStack.ts"
$agentApiPath = Join-Path $repoRoot "services\agent-api\app\main.py"
$mcpGatewayPath = Join-Path $repoRoot "services\mcp-gateway\app\main.py"
$llmGatewayPath = Join-Path $repoRoot "services\llm-gateway\app\main.py"
$appRoot = Join-Path $repoRoot "apps\frontend\app"
$publicRoot = Join-Path $repoRoot "apps\frontend\public"

foreach ($requiredPath in @($wiringPath, $verticalPath, $agentApiPath, $mcpGatewayPath, $llmGatewayPath)) {
  Assert-True "required file exists $requiredPath" (Test-Path -LiteralPath $requiredPath)
}

$wiringSource = Get-Content -LiteralPath $wiringPath -Raw
$verticalSource = Get-Content -LiteralPath $verticalPath -Raw
$agentApiSource = Get-Content -LiteralPath $agentApiPath -Raw
$mcpGatewaySource = Get-Content -LiteralPath $mcpGatewayPath -Raw
$llmGatewaySource = Get-Content -LiteralPath $llmGatewayPath -Raw

Assert-Contains "workspace wiring model capabilities plural" $wiringSource "/api/v1/models/capabilities"
Assert-Contains "agent api model capabilities plural" $agentApiSource "/api/v1/models/capabilities"
Assert-Contains "agent api local files contract route" $agentApiSource '@app.get("/api/v1/files/local/contract")'
Assert-Contains "agent api local files contract version" $agentApiSource "local-files-readonly-contract-v1"
Assert-Contains "agent api local files no host mount" $agentApiSource "host_filesystem_mounted"
Assert-NotContains "workspace wiring stale singular model route" $wiringSource "/api/v1/model-capabilities"
Assert-NotContains "agent api stale singular model route" $agentApiSource "/api/v1/model-capabilities"

Write-Host "[workspace-data-sources] runtime contracts"
$wiring = Invoke-Json "$BaseUrl/api/v1/workspace/wiring"
$vertical = Invoke-Json "$BaseUrl/api/v1/workspace/vertical-stack"
$topology = Invoke-Json "$BaseUrl/api/v1/organism/topology"
$filesLocal = Invoke-Json "$BaseUrl/api/v1/files/local/contract"
$modelRuntime = Invoke-Json "$BaseUrl/api/v1/models/capabilities"
$modelContract = Invoke-Json "$BaseUrl/api/v1/models/capabilities/contract"

Assert-Equal "wiring contract" $wiring.contract_version "workspace-surface-wiring-v1"
Assert-Equal "wiring page count" ([int]$wiring.page_count) 22
Assert-Equal "vertical contract" $vertical.contract_version "workspace-vertical-stack-v1"
Assert-Equal "vertical page count" ([int]$vertical.page_count) 22
Assert-Equal "topology contract" $topology.contract_version "organism-topology-v1"
Assert-Equal "local files contract" $filesLocal.contract_version "local-files-readonly-contract-v1"
Assert-Equal "local files endpoint" $filesLocal.endpoint "GET /api/v1/files/local/contract"
Assert-True "local files no host filesystem mount" ($filesLocal.host_filesystem_mounted -eq $false)
Assert-True "local files no live filesystem reads" ($filesLocal.live_filesystem_reads -eq $false)
Assert-True "local files writes false" ($filesLocal.writes -eq $false)
Assert-True "local files secret output false" ($filesLocal.secret_output -eq $false)
Assert-Equal "model contract version" $modelContract.contract_version "model-capabilities-contract-v1"
Assert-Equal "model contract runtime endpoint" $modelContract.runtime_endpoint "GET /api/v1/models/capabilities"
Assert-True "model runtime routes present" (@($modelRuntime.routes).Count -ge 5)

$wiringJson = $wiring | ConvertTo-Json -Depth 32
$verticalJson = $vertical | ConvertTo-Json -Depth 32
$topologyJson = $topology | ConvertTo-Json -Depth 32
foreach ($forbidden in @("/api/v1/model-capabilities", "Hetzner", "GitKraken", "Oracle", '"secretOutput":true', '"writes":true', '"secret_output":true', '"writes":true')) {
  Assert-NotContains "wiring runtime forbidden $forbidden" $wiringJson $forbidden
  Assert-NotContains "vertical runtime forbidden $forbidden" $verticalJson $forbidden
  Assert-NotContains "topology runtime forbidden $forbidden" $topologyJson $forbidden
}
Assert-Contains "wiring runtime model capabilities plural" $wiringJson "/api/v1/models/capabilities"
Assert-Contains "vertical runtime model capabilities plural" $verticalJson "/api/v1/models/capabilities"
Assert-Contains "topology runtime model capabilities plural" $topologyJson "/api/v1/models/capabilities"
Assert-Contains "wiring runtime local files contract" $wiringJson "/api/v1/files/local/contract"
Assert-Contains "vertical runtime local files contract" $verticalJson "/api/v1/files/local/contract"
Assert-Contains "topology runtime local files contract" $topologyJson "/api/v1/files/local/contract"

$surfaces = @($wiring.surfaces)
$stacks = @($vertical.stacks)
Assert-Equal "surface count" $surfaces.Count 22
Assert-Equal "stack count" $stacks.Count 22

$stackByPage = @{}
foreach ($stack in $stacks) {
  $stackByPage[[string]$stack.pageId] = $stack
}

$apiRefs = New-Object "System.Collections.Generic.HashSet[string]"
foreach ($surface in $surfaces) {
  $pageId = [string]$surface.pageId
  Assert-True "vertical stack exists for $pageId" $stackByPage.ContainsKey($pageId)
  $stack = $stackByPage[$pageId]
  $surfaceSources = @($surface.dataSources | ForEach-Object { [string]$_ })
  $stackSources = @($stack.data.sources | ForEach-Object { [string]$_ })
  Assert-True "$pageId data sources present" ($surfaceSources.Count -gt 0)
  Assert-Equal "$pageId data source count parity" $stackSources.Count $surfaceSources.Count
  foreach ($source in $surfaceSources) {
    Assert-True "$pageId vertical data source parity $source" ($stackSources -contains $source)
    Assert-True "$pageId no stale singular model route" ($source -ne "/api/v1/model-capabilities")

    if ($source.StartsWith("/api/v1/")) {
      [void]$apiRefs.Add($source)
      Assert-True "$pageId agent api route exists for $source" (Test-AgentApiRoute $agentApiSource $source)
    } elseif ($source.StartsWith("/mcp/api/v1/")) {
      [void]$apiRefs.Add($source)
      $mcpRoute = $source.Substring(4)
      Assert-True "$pageId mcp gateway route exists for $source" (Test-AgentApiRoute $mcpGatewaySource $mcpRoute)
    } elseif ($source.StartsWith("/llm/api/v1/") -or $source.StartsWith("/llm/v1/")) {
      [void]$apiRefs.Add($source)
      $llmRoute = $source.Substring(4)
      Assert-True "$pageId llm gateway route exists for $source" (Test-AgentApiRoute $llmGatewaySource $llmRoute)
    } elseif ($source.StartsWith("/")) {
      if ($source.EndsWith(".glb")) {
        $assetPath = Join-Path $publicRoot ($source.TrimStart("/") -replace "/", "\")
        Assert-True "$pageId public asset exists for $source" (Test-Path -LiteralPath $assetPath)
      } else {
        $componentPath = Join-Path $appRoot (($source.TrimStart("/") -replace "/", "\") + "\page.tsx")
        Assert-True "$pageId route page exists for $source" (Test-Path -LiteralPath $componentPath)
      }
    }
  }
}

Assert-True "api-like data source coverage" ($apiRefs.Count -ge 30)
Assert-True "model capabilities data source covered" ($apiRefs.Contains("/api/v1/models/capabilities"))
Assert-True "local files contract data source covered" ($apiRefs.Contains("/api/v1/files/local/contract"))

Write-Host "[workspace-data-sources] api_refs=$($apiRefs.Count)"
Write-Host "[workspace-data-sources] checks completed"
