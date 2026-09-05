param(
  [ValidateRange(1024, 65535)]
  [int]$Port = 8791,
  [string]$SeedReportPath = ".codex\runs\CURRENT\master-goal\t2\hosted-build-preview\report.json",
  [string]$EvidencePath = ".codex\runs\CURRENT\master-goal\t3\cloudflare-d1-local\report.json"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$workerRoot = Join-Path $repoRoot "services\cloudflare-stateful-runtime"
$tempRoot = Join-Path $repoRoot ".codex\tmp\cloudflare-stateful-runtime-local"
$stdoutPath = Join-Path $tempRoot "wrangler.stdout.log"
$stderrPath = Join-Path $tempRoot "wrangler.stderr.log"
$baseUrl = "http://127.0.0.1:$Port"
$authToken = "local-proof-" + [Guid]::NewGuid().ToString("N")
$guardedEnvironment = @{}
foreach ($name in @(
  "AGENT_API_AUTH_TOKEN",
  "CF_ACCOUNT_ID",
  "CF_API_KEY",
  "CF_API_TOKEN",
  "CF_EMAIL",
  "CLOUDFLARE_API_TOKEN",
  "CLOUDFLARE_API_KEY",
  "CLOUDFLARE_EMAIL",
  "CLOUDFLARE_ACCOUNT_ID",
  "CLOUDFLARE_AUTH_TOKEN",
  "CLOUDFLARE_ZONE_ID",
  "R2_ACCESS_KEY_ID",
  "R2_SECRET_ACCESS_KEY",
  "WRANGLER_API_TOKEN",
  "WRANGLER_SEND_METRICS"
)) {
  $guardedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}
$workerProcess = $null

function Stop-LocalWorker {
  param([System.Diagnostics.Process]$StartedProcess)

  if ($null -eq $StartedProcess) { return }
  $processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
  $rootIds = [Collections.Generic.HashSet[int]]::new()
  [void]$rootIds.Add($StartedProcess.Id)

  $stopIds = [Collections.Generic.HashSet[int]]::new()
  $queue = [Collections.Generic.Queue[int]]::new()
  foreach ($rootId in $rootIds) { $queue.Enqueue($rootId) }
  while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()
    if (-not $stopIds.Add($current)) { continue }
    foreach ($child in @($processes | Where-Object { [int]$_.ParentProcessId -eq $current })) {
      $queue.Enqueue([int]$child.ProcessId)
    }
  }
  foreach ($processId in @($stopIds) | Sort-Object -Descending) {
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
  }
}

try {
  if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
    throw "Port $Port is already in use; refusing to stop an unrelated process"
  }

  foreach ($name in @(
    "CF_ACCOUNT_ID",
    "CF_API_KEY",
    "CF_API_TOKEN",
    "CF_EMAIL",
    "CLOUDFLARE_API_TOKEN",
    "CLOUDFLARE_API_KEY",
    "CLOUDFLARE_EMAIL",
    "CLOUDFLARE_ACCOUNT_ID",
    "CLOUDFLARE_AUTH_TOKEN",
    "CLOUDFLARE_ZONE_ID",
    "R2_ACCESS_KEY_ID",
    "R2_SECRET_ACCESS_KEY",
    "WRANGLER_API_TOKEN"
  )) {
    [Environment]::SetEnvironmentVariable($name, $null, "Process")
  }
  $env:WRANGLER_SEND_METRICS = "false"
  $env:AGENT_API_AUTH_TOKEN = $authToken

  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
  Push-Location $workerRoot
  try {
    & npm.cmd run db:migrate:local
    if ($LASTEXITCODE -ne 0) { throw "Local D1 migration failed with exit code $LASTEXITCODE" }
  } finally {
    Pop-Location
  }

  $node = (Get-Command node.exe -ErrorAction Stop).Source
  $wrangler = Join-Path $workerRoot "node_modules\wrangler\bin\wrangler.js"
  if (-not (Test-Path -LiteralPath $wrangler)) { throw "Pinned Wrangler entrypoint not found: $wrangler" }
  $arguments = @(
    $wrangler, "dev", "--local", "--env", "preview",
    "--persist-to", ".wrangler/state", "--port", [string]$Port,
    "--var", "AGENT_API_AUTH_TOKEN:$authToken",
    "--log-level", "error", "--show-interactive-dev-session", "false"
  )
  $workerProcess = Start-Process -FilePath $node -ArgumentList $arguments -WorkingDirectory $workerRoot -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru

  $healthy = $false
  for ($attempt = 0; $attempt -lt 60; $attempt++) {
    if ($workerProcess.HasExited) {
      $details = ((Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue)).Trim()
      throw "Local Worker exited before health was ready. $details"
    }
    try {
      $health = Invoke-RestMethod -UseBasicParsing -Uri "$baseUrl/api/v1/health" -TimeoutSec 2
      if ($health.status -eq "healthy" -and $health.d1_read_verified -eq $true) {
        $healthy = $true
        break
      }
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }
  if (-not $healthy) { throw "Local Worker health did not become ready at $baseUrl" }

  & (Join-Path $PSScriptRoot "verify-cloudflare-stateful-runtime.ps1") -BaseUrl $baseUrl -AllowLocalhost -SeedReportPath $SeedReportPath -EvidencePath $EvidencePath

  $workerLogs = [string]((Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue))
  if ($workerLogs.Contains($authToken)) {
    throw "Local Worker logs exposed the synthetic write-auth value"
  }
  foreach ($value in @($guardedEnvironment.Values | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) -and ([string]$_).Length -ge 12 })) {
    if ($workerLogs.Contains([string]$value)) {
      throw "Local Worker logs exposed a guarded management credential"
    }
  }

  Write-Host "[cloudflare-stateful-runtime-local] status=verified transport=DEV-ONLY provider_calls=0"
} finally {
  try {
    Stop-LocalWorker -StartedProcess $workerProcess
    if ($null -ne $workerProcess) { $workerProcess.Dispose() }
  } finally {
    foreach ($name in $guardedEnvironment.Keys) {
      [Environment]::SetEnvironmentVariable($name, $guardedEnvironment[$name], "Process")
    }
  }
}

exit 0
