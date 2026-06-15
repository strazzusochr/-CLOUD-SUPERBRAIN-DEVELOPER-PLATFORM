param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Platform UI status boundary verification failed: $label"
  }
}

function Assert-NotContains($label, $value, $forbidden) {
  $text = ($value | Out-String)
  if ($text.Contains($forbidden)) {
    throw "Platform UI status boundary verification failed: $label contains forbidden '$forbidden'."
  }
}

function Invoke-Text($url) {
  $lastError = $null
  for ($attempt = 1; $attempt -le 4; $attempt++) {
    try {
      $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 90 -UseBasicParsing
      if ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 300) {
        return [string]$response.Content
      }
      $lastError = "HTTP $($response.StatusCode)"
    } catch {
      $lastError = $_.Exception.Message
    }
    Start-Sleep -Seconds ([Math]::Min(10, 2 * $attempt))
  }
  throw "Platform UI status boundary verification failed: GET $url did not become stable: $lastError"
}

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Platform UI status boundary proof refuses localhost unless -AllowLocalhost is set"
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$productSurfacePaths = @(
  "apps\frontend\app\home\page.tsx",
  "apps\frontend\app\workbench\page.tsx",
  "apps\frontend\app\games\page.tsx",
  "apps\frontend\app\apps\page.tsx",
  "apps\frontend\app\media\page.tsx",
  "apps\frontend\app\docs-output\page.tsx",
  "apps\frontend\components\shell\AppShell.tsx"
)
$productRoutes = @("/home", "/workbench", "/games", "/apps", "/media", "/docs-output")

foreach ($relativePath in $productSurfacePaths) {
  $path = Join-Path $repoRoot $relativePath
  Assert-True "product surface exists $relativePath" (Test-Path -LiteralPath $path)
}

$forbiddenSourceMarkers = @(
  "fetchProgress",
  "fetchMasterPlan",
  "fetchCompletionGate",
  "MANIFEST",
  "/api/v1/project/progress",
  "overall_percent",
  "progress_source",
  "Project Progress",
  "Projektstand",
  "Completion-Gate",
  "Workspace-Surfaces",
  "Gate-Matrix",
  "Recovery-Historie",
  "external-gate-audit",
  "external-gate-summary",
  "go-live-readiness",
  "GET /api/v1/project/progress"
)

foreach ($relativePath in $productSurfacePaths) {
  $source = Get-Content -LiteralPath (Join-Path $repoRoot $relativePath) -Raw
  foreach ($forbidden in $forbiddenSourceMarkers) {
    Assert-NotContains "$relativePath source boundary" $source $forbidden
  }
}

$agentApiLibPath = Join-Path $repoRoot "apps\frontend\lib\agentApi.ts"
$platformLibPath = Join-Path $repoRoot "apps\frontend\lib\platform.ts"
Assert-True "agent api lib exists" (Test-Path -LiteralPath $agentApiLibPath)
Assert-True "platform lib exists" (Test-Path -LiteralPath $platformLibPath)
$agentApiLib = Get-Content -LiteralPath $agentApiLibPath -Raw
$platformLib = Get-Content -LiteralPath $platformLibPath -Raw

foreach ($required in @("fetchProgress", "fetchMasterPlan", "fetchCompletionGate", "/api/v1/project/progress")) {
  Assert-True "project status helper remains isolated in agentApi lib: $required" $agentApiLib.Contains($required)
}
foreach ($allowed in @("MANIFEST", "Project Progress", "/api/v1/project/progress")) {
  Assert-True "project status manifest remains isolated in platform lib: $allowed" $platformLib.Contains($allowed)
}

Write-Host "[platform-ui-boundary] runtime product surfaces"
$forbiddenRuntimeMarkers = @(
  "Project Progress",
  "Projektstand",
  "Completion-Gate",
  "Workspace-Surfaces",
  "Gate-Matrix",
  "Recovery-Historie",
  "external-gate-audit",
  "external-gate-summary",
  "go-live-readiness"
)

foreach ($route in $productRoutes) {
  $html = Invoke-Text "$BaseUrl$route"
  foreach ($forbidden in $forbiddenRuntimeMarkers) {
    Assert-NotContains "$route runtime boundary" $html $forbidden
  }
  Assert-NotContains "$route stale singular model route" $html "/api/v1/model-capabilities"
  Assert-True "$route app shell visible" ($html.Contains("Cloud Superbrain") -or $html.Contains("Superbrain"))
}

$wiringSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\lib\workspaceWiring.ts") -Raw
$verticalSource = Get-Content -LiteralPath (Join-Path $repoRoot "apps\frontend\lib\workspaceVerticalStack.ts") -Raw
foreach ($allowedDataPlaneRef in @("/api/v1/project/progress/integrity", "/api/v1/external-gates")) {
  Assert-True "workspace wiring may keep non-rendering data ref $allowedDataPlaneRef" $wiringSource.Contains($allowedDataPlaneRef)
}
foreach ($forbidden in @("fetchProgress", "fetchMasterPlan", "fetchCompletionGate", "MANIFEST")) {
  Assert-NotContains "workspace wiring non-rendering boundary" $wiringSource $forbidden
  Assert-NotContains "workspace vertical stack non-rendering boundary" $verticalSource $forbidden
}

Write-Host "[platform-ui-boundary] product_surfaces=$($productSurfacePaths.Count) routes=$($productRoutes.Count)"
Write-Host "[platform-ui-boundary] checks completed"
