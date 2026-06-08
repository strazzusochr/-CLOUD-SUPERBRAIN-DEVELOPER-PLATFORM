<#
  00-run-full-audit.ps1 — Cloud Superbrain audit pack.

  Orchestrates the existing verifiers + frontend checks and writes an honest
  PASS/WARN/FAIL/BLOCKED report. Never prints secret values; never deploys,
  pushes or performs provider writes.

  Example:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\00-run-full-audit.ps1 `
      -ProjectRoot "." -BaseUrl "http://localhost:3000" `
      -RunRuntime -RuntimeRepeat 5 -RunLint -RunBuild -RunUnit -ProbeMcp
#>
param(
  [string]$ProjectRoot = ".",
  [string]$BaseUrl = "http://localhost:3000",
  [switch]$RunRuntime,
  [int]$RuntimeRepeat = 1,
  [switch]$RunLint,
  [switch]$RunBuild,
  [switch]$RunUnit,
  [switch]$ProbeMcp,
  [string]$AuditOutputRoot = ".audit"
)

$ErrorActionPreference = "Continue"
$root = (Resolve-Path $ProjectRoot).Path
$fe = Join-Path $root "apps\frontend"
$out = Join-Path $root $AuditOutputRoot
New-Item -ItemType Directory -Force -Path $out | Out-Null
$results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$name, [string]$status, [string]$detail) {
  $results.Add([pscustomobject]@{ check = $name; status = $status; detail = $detail })
  Write-Host ("[{0,-7}] {1} — {2}" -f $status, $name, $detail)
}

Write-Host "== Cloud Superbrain audit ==  root=$root"

# 1. Lint
if ($RunLint) {
  Push-Location $fe
  $lint = & npm run lint 2>&1
  Add-Result "lint" ($(if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" })) "eslint exit=$LASTEXITCODE"
  Pop-Location
} else { Add-Result "lint" "BLOCKED" "skipped (-RunLint not set)" }

# 2. Build
if ($RunBuild) {
  Push-Location $fe
  $build = & npm run build 2>&1
  Add-Result "build" ($(if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" })) "next build exit=$LASTEXITCODE"
  Pop-Location
} else { Add-Result "build" "BLOCKED" "skipped (-RunBuild not set)" }

# 3. Unit / e2e (Playwright)
if ($RunUnit) {
  Push-Location $fe
  if (Test-Path (Join-Path $fe "playwright.config.ts")) {
    $e2e = & npx playwright test 2>&1
    Add-Result "e2e" ($(if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" })) "playwright exit=$LASTEXITCODE"
  } else { Add-Result "e2e" "BLOCKED" "no playwright.config.ts" }
  Pop-Location
} else { Add-Result "e2e" "BLOCKED" "skipped (-RunUnit not set)" }

# 4. Runtime route smoke
if ($RunRuntime) {
  $routes = @("/","/home","/login","/workbench","/files","/files/local","/organism",
    "/organism/live","/organism/replay","/organism/map","/agents","/tools","/marketplace",
    "/observe","/evidence","/settings","/diagnostics","/design-system","/responsive",
    "/technology","/open-source","/games","/media","/docs-output","/apps",
    "/api/v1/organism/contract","/api/v1/organism/topology","/api/v1/organism/live-state",
    "/api/v1/organism/events","/api/v1/organism/replay","/api/v1/organism/regions",
    "/api/v1/organism/safety")
  $bad = 0; $ok = 0
  for ($i = 0; $i -lt $RuntimeRepeat; $i++) {
    foreach ($r in $routes) {
      try {
        $resp = Invoke-WebRequest -Uri "$BaseUrl$r" -UseBasicParsing -TimeoutSec 15
        if ($resp.StatusCode -eq 200) { $ok++ } else { $bad++; Write-Host "  non-200 $r => $($resp.StatusCode)" }
      } catch { $bad++; Write-Host "  error $r => $($_.Exception.Message)" }
    }
  }
  Add-Result "route-smoke" ($(if ($bad -eq 0) { "PASS" } else { "FAIL" })) "$ok ok / $bad non-200 over $RuntimeRepeat run(s) against $BaseUrl"
} else { Add-Result "route-smoke" "BLOCKED" "skipped (-RunRuntime not set)" }

# 5. Secret scan (gitleaks)
$gitleaks = Get-Command gitleaks -ErrorAction SilentlyContinue
if ($gitleaks) {
  Push-Location $root
  & gitleaks detect --no-banner --redact 2>&1 | Out-Null
  Add-Result "secret-scan" ($(if ($LASTEXITCODE -eq 0) { "PASS" } else { "FAIL" })) "gitleaks exit=$LASTEXITCODE (redacted)"
  Pop-Location
} else { Add-Result "secret-scan" "BLOCKED" "gitleaks not installed" }

# 6. MCP probe (never prints secret values)
if ($ProbeMcp) {
  $claude = Get-Command claude -ErrorAction SilentlyContinue
  if ($claude) {
    $mcp = & claude mcp list 2>&1
    $count = (@($mcp) | Where-Object { $_ -match "\S" }).Count
    Add-Result "mcp-probe" "PASS" "claude mcp list returned $count line(s)"
  } else { Add-Result "mcp-probe" "BLOCKED" "claude CLI not on PATH" }
} else { Add-Result "mcp-probe" "BLOCKED" "skipped (-ProbeMcp not set)" }

# Write report
$stamp = Get-Date -Format "yyyy-MM-ddTHH-mm-ss"
$json = Join-Path $out "audit-$stamp.json"
$results | ConvertTo-Json -Depth 4 | Set-Content -Path $json -Encoding UTF8

$pass = (@($results | Where-Object status -eq "PASS")).Count
$fail = (@($results | Where-Object status -eq "FAIL")).Count
$blocked = (@($results | Where-Object status -eq "BLOCKED")).Count
$overall = if ($fail -gt 0) { "FAIL" } elseif ($pass -gt 0) { "PASS-WITH-BLOCKED" } else { "BLOCKED" }
Write-Host ""
Write-Host ("== SUMMARY: {0}  (PASS={1} FAIL={2} BLOCKED={3}) ==" -f $overall, $pass, $fail, $blocked)
Write-Host "report: $json"
if ($fail -gt 0) { exit 1 } else { exit 0 }
