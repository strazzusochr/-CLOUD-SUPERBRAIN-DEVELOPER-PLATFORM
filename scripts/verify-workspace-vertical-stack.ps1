param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Workspace vertical stack verification failed: $label"
  }
}

function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) {
    throw "Workspace vertical stack verification failed: $label expected '$expected', got '$actual'."
  }
}

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Workspace vertical stack verification failed: $label missing '$expected'."
  }
}

function Invoke-Json($url) {
  return Invoke-RestMethod -Uri $url -Method GET -TimeoutSec 60
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Workspace vertical stack proof refuses localhost unless -AllowLocalhost is set"
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$verticalSourcePath = Join-Path $repoRoot "apps\frontend\lib\workspaceVerticalStack.ts"
$verticalRoutePath = Join-Path $repoRoot "apps\frontend\app\api\v1\workspace\vertical-stack\route.ts"
$agentApiPath = Join-Path $repoRoot "services\agent-api\app\main.py"

foreach ($requiredPath in @($verticalSourcePath, $verticalRoutePath, $agentApiPath)) {
  Assert-True "required file exists $requiredPath" (Test-Path -LiteralPath $requiredPath)
}

$verticalSource = Get-Content -LiteralPath $verticalSourcePath -Raw
$verticalRoute = Get-Content -LiteralPath $verticalRoutePath -Raw
$agentApi = Get-Content -LiteralPath $agentApiPath -Raw

foreach ($required in @(
  "workspace-vertical-stack-v1",
  "workspace_vertical_stack_visible",
  "ui",
  "api",
  "data",
  "verification",
  "deploy",
  "safety",
  "Budget UI remains hidden",
  "Localhost evidence remains DEV-ONLY"
)) {
  Assert-Contains "frontend vertical source" $verticalSource $required
}
Assert-Contains "frontend vertical route" $verticalRoute "workspaceVerticalStackContract"
Assert-Contains "agent api vertical contract version" $agentApi "WORKSPACE_VERTICAL_STACK_CONTRACT_VERSION"
Assert-Contains "agent api vertical evidence ref" $agentApi "WORKSPACE_VERTICAL_STACK_EVIDENCE_REF"
Assert-Contains "agent api vertical route" $agentApi '@app.get("/api/v1/workspace/vertical-stack")'
Assert-Contains "agent api go-live guarded endpoint" $agentApi "GET /api/v1/workspace/vertical-stack"
Assert-Contains "agent api organism related endpoint" $agentApi "/api/v1/workspace/vertical-stack"

Write-Host "[workspace-vertical-stack] runtime contract"
$vertical = Invoke-Json "$BaseUrl/api/v1/workspace/vertical-stack"
$wiring = Invoke-Json "$BaseUrl/api/v1/workspace/wiring"

Assert-Equal "vertical contract version" $vertical.contract_version "workspace-vertical-stack-v1"
Assert-Equal "vertical endpoint" $vertical.endpoint "/api/v1/workspace/vertical-stack"
Assert-Equal "vertical evidence" $vertical.evidence_ref "workspace_vertical_stack_visible"
Assert-Equal "vertical page count" ([int]$vertical.page_count) 22
Assert-Equal "vertical expected page count" ([int]$vertical.expected_page_count) 22
Assert-Equal "vertical layers required" ([int]$vertical.layers_required) 7
Assert-Equal "wiring contract version" $wiring.contract_version "workspace-surface-wiring-v1"
Assert-Equal "wiring page count" ([int]$wiring.page_count) 22

$stageKeys = @($vertical.required_stage_keys | ForEach-Object { [string]$_ })
foreach ($stage in @("ui", "api", "data", "verification", "deploy", "safety")) {
  Assert-True "required stage key $stage" ($stageKeys -contains $stage)
}

$stackItems = @($vertical.stacks)
$wiringItems = @($wiring.surfaces)
Assert-Equal "stack item count" $stackItems.Count 22
Assert-Equal "wiring item count" $wiringItems.Count 22

$wiringByPageId = @{}
foreach ($surface in $wiringItems) {
  $wiringByPageId[[string]$surface.pageId] = $surface
}

$json = $vertical | ConvertTo-Json -Depth 24
foreach ($forbidden in @("Hetzner", "GitKraken", "Oracle", '"directProviderCalls":true', '"secretOutput":true', '"writes":true', '"productionDeployClaimAllowed":true')) {
  Assert-True "forbidden vertical marker absent $forbidden" (-not $json.Contains($forbidden))
}

$seenPageIds = New-Object "System.Collections.Generic.HashSet[string]"
$seenRoutes = New-Object "System.Collections.Generic.HashSet[string]"
foreach ($stack in $stackItems) {
  $pageId = [string]$stack.pageId
  Assert-True "unique stack page id $pageId" $seenPageIds.Add($pageId)
  Assert-True "wiring exists for $pageId" $wiringByPageId.ContainsKey($pageId)
  $surface = $wiringByPageId[$pageId]

  Assert-Equal "$pageId no" ([int]$stack.no) ([int]$surface.no)
  Assert-Equal "$pageId route" ([string]$stack.route) ([string]$surface.route)
  Assert-Equal "$pageId layer" ([string]$stack.layer) ([string]$surface.layer)
  Assert-Equal "$pageId brain region" ([string]$stack.brainRegion) ([string]$surface.brainRegion)
  Assert-Equal "$pageId hub" ([string]$stack.hub) ([string]$surface.hub)
  Assert-True "unique route $($stack.route)" $seenRoutes.Add([string]$stack.route)

  Assert-Equal "$pageId ui route" ([string]$stack.ui.route) ([string]$stack.route)
  Assert-True "$pageId shell required" ($stack.ui.shellRequired -eq $true)
  Assert-True "$pageId active rail required" ($stack.ui.activeRailRequired -eq $true)
  Assert-True "$pageId component path" ([string]$stack.ui.componentPath).StartsWith("apps/frontend/app/")
  Assert-True "$pageId component page file" ([string]$stack.ui.componentPath).EndsWith("/page.tsx")
  $componentPath = Join-Path $repoRoot (([string]$stack.ui.componentPath) -replace "/", "\")
  Assert-True "$pageId component file exists" (Test-Path -LiteralPath $componentPath)

  Assert-True "$pageId gateway bound" ($stack.api.gatewayBound -eq $true)
  Assert-True "$pageId no direct provider calls" ($stack.api.directProviderCalls -eq $false)
  Assert-True "$pageId data sources present" (@($stack.data.sources).Count -gt 0)
  Assert-True "$pageId no default writes" ($stack.data.writesAllowedByDefault -eq $false)
  Assert-True "$pageId no secret output data" ($stack.data.secretOutputAllowed -eq $false)

  $verificationRefs = @($stack.verification.refs | ForEach-Object { [string]$_ })
  Assert-True "$pageId vertical verifier ref" ($verificationRefs -contains "scripts/verify-workspace-vertical-stack.ps1")
  Assert-True "$pageId browser verifier ref" ($verificationRefs -contains "scripts/verify-workspace-pages-browser.ps1")
  Assert-True "$pageId browser proof required" ($stack.verification.browserProofRequired -eq $true)
  Assert-True "$pageId phase1 guard required" ($stack.verification.phase1GuardRequired -eq $true)
  Assert-True "$pageId hosted proof required for release" ($stack.verification.hostedProofRequiredForRelease -eq $true)

  Assert-Equal "$pageId frontend target" ([string]$stack.deploy.frontendTarget) "vercel"
  Assert-True "$pageId fly agent target" (@($stack.deploy.backendTargets) -contains "fly-agent-api")
  Assert-True "$pageId fly mcp target" (@($stack.deploy.backendTargets) -contains "fly-mcp-gateway")
  Assert-True "$pageId fly llm target" (@($stack.deploy.backendTargets) -contains "fly-llm-gateway")
  Assert-Equal "$pageId registry" ([string]$stack.deploy.registry) "ghcr"
  Assert-Equal "$pageId hosted proof blocked" ([string]$stack.deploy.hostedProofStatus) "blocked_external_gates"

  Assert-True "$pageId safety live false" ($stack.safety.live -eq $false)
  Assert-True "$pageId safety writes false" ($stack.safety.writes -eq $false)
  Assert-True "$pageId safety secret output false" ($stack.safety.secretOutput -eq $false)
  Assert-True "$pageId no production claim" ($stack.safety.productionDeployClaimAllowed -eq $false)
  Assert-True "$pageId local proof only" ($stack.safety.localProofOnly -eq $true)
  Assert-True "$pageId event kinds present" (@($stack.eventKinds).Count -gt 0)
}

Write-Host "[workspace-vertical-stack] checks completed"
