param(
  [Parameter(Mandatory = $true)][string]$BaseUrl,
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\master-goal\phase2\class-cd"
)

$ErrorActionPreference = "Stop"
$uri = [Uri]$BaseUrl
$isLocal = $uri.Host -in @("localhost", "127.0.0.1", "::1")
if ($isLocal -and -not $AllowLocalhost) {
  throw "Localhost requires -AllowLocalhost and remains DEV-ONLY evidence."
}
if (-not $isLocal -and $uri.Scheme -ne "https") {
  throw "Hosted Class-C proof requires HTTPS."
}

$base = $BaseUrl.TrimEnd("/")
$classC = @(
  @{ path = "/api/v1/agents/status"; collection = "agents" },
  @{ path = "/api/v1/live-agents/status"; collection = "agents" },
  @{ path = "/api/v1/phase2/runtime/runs"; collection = "runs" },
  @{ path = "/api/v1/task/dispatches/recent"; collection = "items" },
  @{ path = "/api/v1/tasks/recent"; collection = "tasks" }
)

$results = @()
foreach ($surface in $classC) {
  $response = Invoke-WebRequest -UseBasicParsing -Uri "$base$($surface.path)" -TimeoutSec 30 -Headers @{ Accept = "application/json" }
  $payload = $response.Content | ConvertFrom-Json
  $source = (@($response.Headers["x-superbrain-source"]) -join ",")
  $collection = @($payload.($surface.collection))
  $passed = (
    [int]$response.StatusCode -eq 200 -and
    $source -eq "frontend-projection" -and
    $payload.live_backend -eq $false -and
    [string]$payload.status -eq "degraded" -and
    [string]$payload.reason -eq "stateful_runtime_not_configured" -and
    [string]$payload.owner_precondition -match "Fly.*Neon/Upstash" -and
    $collection.Count -eq 0
  )
  $results += [pscustomobject]@{
    path = $surface.path
    http_status = [int]$response.StatusCode
    source = $source
    live_backend = $payload.live_backend
    status = $payload.status
    reason = $payload.reason
    collection = $surface.collection
    collection_count = $collection.Count
    passed = $passed
  }
}

$startBody = @{ project_id = "class-c-proof"; prompt = "must stay blocked" } | ConvertTo-Json -Compress
try {
  $startResponse = Invoke-WebRequest -UseBasicParsing -Method POST -Uri "$base/api/v1/phase2/runtime/start" -ContentType "application/json" -Body $startBody -TimeoutSec 30
  $startStatus = [int]$startResponse.StatusCode
  $startPayload = $startResponse.Content | ConvertFrom-Json
} catch {
  $startStatus = [int]$_.Exception.Response.StatusCode
  $errorBody = [string]$_.ErrorDetails.Message
  if (-not $errorBody -and $null -ne $_.Exception.Response) {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    try { $errorBody = $reader.ReadToEnd() } finally { $reader.Dispose() }
  }
  if (-not $errorBody) { throw "Phase-2 start guard returned HTTP $startStatus without a JSON body." }
  $startPayload = $errorBody | ConvertFrom-Json
}
$startPassed = (
  $startStatus -eq 503 -and
  $startPayload.live_backend -eq $false -and
  [string]$startPayload.status -eq "blocked" -and
  [string]$startPayload.reason -eq "stateful_runtime_not_configured" -and
  $null -eq $startPayload.run
)

$matrixPath = ".codex\runs\CURRENT\goal-d4\batch1\transfer-matrix.json"
$matrix = Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json
$classD = @($matrix.entries | Where-Object { $_.class -eq "D" })
$classDPassed = $classD.Count -eq 4 -and @($classD | Where-Object { $null -ne $_.cloud_http }).Count -eq 0

$outPath = Join-Path (Get-Location) $OutDir
New-Item -ItemType Directory -Force -Path $outPath | Out-Null
$report = [ordered]@{
  contract_version = "goal-d4-class-cd-boundary-proof-v1"
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
  base_url = $BaseUrl
  scope = if ($isLocal) { "DEV-ONLY" } else { "HTTPS_HOSTED" }
  class_c = $results
  class_c_start_guard = [ordered]@{
    path = "/api/v1/phase2/runtime/start"
    http_status = $startStatus
    status = $startPayload.status
    reason = $startPayload.reason
    passed = $startPassed
  }
  class_d = $classD
  class_d_passed = $classDPassed
  fail_count = @($results | Where-Object { -not $_.passed }).Count + [int](-not $startPassed) + [int](-not $classDPassed)
  non_claims = @(
    "No hosted LangGraph, Redis, PostgreSQL, worker, or queue runtime is claimed.",
    "No Class-C mutation is executed.",
    "Class-D surfaces remain DEV-only and are not emulated in Vercel."
  )
}
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $outPath "class-cd-boundary.json") -Encoding utf8
Write-Host "[goal-d4-class-cd] class_c=$($results.Count) class_d=$($classD.Count) fail=$($report.fail_count)"
if ($report.fail_count -gt 0) { exit 1 }
