param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

if (-not $BaseUrl) {
  throw "BaseUrl is required"
}
$BaseUrl = $BaseUrl.TrimEnd("/")
if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
  throw "Reference design browser proof refuses localhost unless -AllowLocalhost is set"
}

$npx = Get-Command npx -ErrorAction SilentlyContinue
if (-not $npx) {
  throw "npx is required for Playwright browser verification"
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$playwrightModule = Join-Path $repoRoot "apps\frontend\node_modules\playwright"
if (-not (Test-Path $playwrightModule)) {
  throw "Missing Playwright module. Run npm install --prefix apps/frontend first."
}

$nodeScript = Join-Path $PSScriptRoot "verify-reference-design-browser.cjs"
if (-not (Test-Path $nodeScript)) {
  throw "Missing reference design browser verifier"
}

$args = @($nodeScript, "--base-url", $BaseUrl)
if ($AllowLocalhost) {
  $args += "--allow-localhost"
}

Write-Host "[reference-design-browser] base url: $BaseUrl"
node @args
if ($LASTEXITCODE -ne 0) {
  throw "Reference design browser proof failed"
}
