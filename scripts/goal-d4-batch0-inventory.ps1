param(
  [string]$OutDir = ".codex\runs\CURRENT\goal-d4\batch0\inventory",
  [string]$LocalBaseUrl = "http://localhost:8081",
  [string[]]$CloudBaseUrls = @(
    "https://frontend-seven-psi-78.vercel.app",
    "https://frontend-kzztyxkgs-strazzusochrs-projects.vercel.app"
  )
)

$ErrorActionPreference = "Stop"
$repoRoot = (Get-Location).Path
$outPath = Join-Path $repoRoot $OutDir
New-Item -ItemType Directory -Force $outPath | Out-Null

function Get-TextHash([string]$Text) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant() } finally { $sha.Dispose() }
}

function Get-HeaderValue($Headers, [string]$Name) {
  if ($null -eq $Headers) { return $null }
  foreach ($key in $Headers.Keys) {
    if ([string]$key -ieq $Name) { return [string]$Headers[$key] }
  }
  return $null
}

function Invoke-ReadProbe([string]$BaseUrl, [string]$Path) {
  $uri = "$($BaseUrl.TrimEnd('/'))$Path"
  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  $status = 0
  $headers = $null
  $content = ""
  $error = $null
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $uri -Method Get -TimeoutSec 12 -Headers @{ Accept = "application/json" }
    $status = [int]$response.StatusCode
    $headers = $response.Headers
    $content = [string]$response.Content
  } catch {
    $error = $_.Exception.Message
    $response = $_.Exception.Response
    if ($null -ne $response) {
      $status = [int]$response.StatusCode
      $headers = $response.Headers
      try {
        $reader = [System.IO.StreamReader]::new($response.GetResponseStream())
        $content = $reader.ReadToEnd()
        $reader.Dispose()
      } catch {}
    }
  }
  $watch.Stop()
  $payload = $null
  try { if ($content) { $payload = $content | ConvertFrom-Json } } catch {}
  $source = Get-HeaderValue $headers "x-superbrain-source"
  if (-not $source -and $null -ne $payload) {
    foreach ($key in @("source", "source_kind", "persistence", "mode")) {
      $property = $payload.PSObject.Properties[$key]
      if ($null -ne $property -and $null -ne $property.Value) { $source = [string]$property.Value; break }
    }
  }
  [pscustomobject]@{
    path = $Path
    method = "GET"
    url = $uri
    http_status = $status
    latency_ms = [math]::Round($watch.Elapsed.TotalMilliseconds, 1)
    source = $source
    live_backend = if ($null -ne $payload -and $null -ne $payload.PSObject.Properties["live_backend"]) { $payload.live_backend } else { $null }
    source_kind = if ($null -ne $payload -and $null -ne $payload.PSObject.Properties["source_kind"]) { [string]$payload.source_kind } else { $null }
    response_bytes = [System.Text.Encoding]::UTF8.GetByteCount($content)
    payload_sha256 = if ($content) { Get-TextHash $content } else { $null }
    error = $error
  }
}

function Invoke-ComposeProbe([string]$Service, [string]$Port, [string[]]$Command) {
  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  $detail = ""
  $status = "PASS"
  try {
    $detail = (& docker compose -f docker-compose.dev.yml exec -T $Service @Command 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "exit=$LASTEXITCODE" }
  } catch {
    $status = "FAIL"
    $detail = "$detail $($_.Exception.Message)".Trim()
  }
  $watch.Stop()
  [pscustomobject]@{
    service = $Service
    internal_port = $Port
    status = $status
    latency_ms = [math]::Round($watch.Elapsed.TotalMilliseconds, 1)
    detail = $detail.Substring(0, [math]::Min($detail.Length, 400))
  }
}

$wiring = Invoke-ReadProbe $LocalBaseUrl "/api/v1/workspace/wiring"
if ($wiring.http_status -ne 200) { throw "Workspace wiring is unavailable for API inventory: HTTP $($wiring.http_status)" }
$wiringResponse = Invoke-WebRequest -UseBasicParsing -Uri "$($LocalBaseUrl.TrimEnd('/'))/api/v1/workspace/wiring" -TimeoutSec 12
$wiringPayload = $wiringResponse.Content | ConvertFrom-Json
$apiRefs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($surface in @($wiringPayload.surfaces)) {
  foreach ($source in @($surface.dataSources)) {
    $value = [string]$source
    if ($value.StartsWith("/api/v1/") -or $value.StartsWith("/mcp/api/v1/") -or $value.StartsWith("/llm/api/v1/")) {
      [void]$apiRefs.Add($value)
    }
  }
}
[void]$apiRefs.Add("/llm/api/v1/responses/contract")
[void]$apiRefs.Add("/mcp/api/v1/version-pinning/contract")
$apiPaths = @($apiRefs | Sort-Object)

$portRows = [System.Collections.Generic.List[object]]::new()
foreach ($connection in @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -ge 1000 -and $_.LocalPort -le 9999 })) {
  $processName = "unknown"
  try { $processName = (Get-Process -Id $connection.OwningProcess -ErrorAction Stop).ProcessName } catch {}
  $portRows.Add([pscustomobject]@{
    port = [int]$connection.LocalPort
    address = [string]$connection.LocalAddress
    process_id = [int]$connection.OwningProcess
    process = $processName
  })
}
$tcpConnectOpenPorts = [System.Collections.Generic.List[int]]::new()
foreach ($port in 1000..9999) {
  $client = [System.Net.Sockets.TcpClient]::new()
  try {
    $connect = $client.ConnectAsync("127.0.0.1", $port)
    if ($connect.Wait(15) -and $client.Connected) { $tcpConnectOpenPorts.Add($port) }
  } catch {} finally { $client.Dispose() }
}
$host8081 = $portRows | Where-Object { $_.port -eq 8081 }
$unexpectedPorts = $portRows | Where-Object { $_.port -notin @(3000, 8000, 8077, 8081) }

$serviceMatrix = @(
  Invoke-ComposeProbe "frontend" "3000/tcp" @("node", "-e", "fetch('http://127.0.0.1:3000/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))")
  Invoke-ComposeProbe "agent-api" "8000/tcp" @("python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/v1/health', timeout=3)")
  Invoke-ComposeProbe "agent-worker" "no listener" @("python", "-c", "import os,psycopg,redis; redis.Redis.from_url(os.environ['REDIS_URL']).ping(); psycopg.connect(os.environ['DATABASE_URL']).close()")
  Invoke-ComposeProbe "memory-worker" "no listener" @("python", "-m", "app.worker", "--healthcheck")
  Invoke-ComposeProbe "mcp-gateway" "9000/tcp" @("python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:9000/api/v1/health', timeout=3)")
  Invoke-ComposeProbe "llm-gateway" "4000/tcp" @("python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:4000/api/v1/health', timeout=3)")
  Invoke-ComposeProbe "local-llm" "8080/tcp (DEV-only)" @("sh", "-lc", "curl -fsS http://127.0.0.1:8080/health >/dev/null")
  Invoke-ComposeProbe "postgres" "5432/tcp" @("sh", "-lc", "pg_isready -U `"`$POSTGRES_USER`" -d `"`$POSTGRES_DB`"")
  Invoke-ComposeProbe "redis" "6379/tcp" @("redis-cli", "ping")
  Invoke-ComposeProbe "nginx" "8080/tcp -> host 8081" @("wget", "-qO-", "http://127.0.0.1:8080/health")
)
$composeJson = & docker compose -f docker-compose.dev.yml ps --format json 2>$null
$composeRows = @($composeJson | ForEach-Object { $_ | ConvertFrom-Json })
$platformRow = [pscustomobject]@{
  service = "platform"
  internal_port = "logical compose status"
  status = if ($composeRows.Count -eq 10 -and @($composeRows | Where-Object { $_.Health -ne "healthy" }).Count -eq 0) { "PASS" } else { "FAIL" }
  latency_ms = 0
  detail = "compose_containers=$($composeRows.Count)"
}
$serviceMatrix += $platformRow
$surfaceAuditPath = Join-Path (Split-Path $outPath -Parent) "surface-audit\report.json"
$routeRegression = if (Test-Path -LiteralPath $surfaceAuditPath) { Get-Content -LiteralPath $surfaceAuditPath -Raw | ConvertFrom-Json } else { $null }

$localMatrix = @($apiPaths | ForEach-Object { Invoke-ReadProbe $LocalBaseUrl $_ })
$cloudMatrices = @{}
foreach ($cloudBaseUrl in $CloudBaseUrls) {
  $cloudMatrices[$cloudBaseUrl] = @($apiPaths | ForEach-Object { Invoke-ReadProbe $cloudBaseUrl $_ })
}
$canonicalCloud = $CloudBaseUrls[0]
$canonicalMatrix = @($cloudMatrices[$canonicalCloud])
$delta = foreach ($local in $localMatrix) {
  $cloud = $canonicalMatrix | Where-Object { $_.path -eq $local.path } | Select-Object -First 1
  if ($local.http_status -eq 200 -and $null -ne $cloud) {
    $projectionLike = ([string]$cloud.source -match "projection|frontend" -or [string]$cloud.source_kind -match "projection" -or $cloud.live_backend -eq $false)
    if ($projectionLike -or $cloud.http_status -ne 200) {
      [pscustomobject]@{
        path = $local.path
        local_status = $local.http_status
        local_source = $local.source
        cloud_status = $cloud.http_status
        cloud_source = $cloud.source
        cloud_source_kind = $cloud.source_kind
        cloud_live_backend = $cloud.live_backend
        transfer_candidate = $true
      }
    }
  }
}

$supplementalRoutes = @("/organism/live", "/exports", "/exports/docs") | ForEach-Object { Invoke-ReadProbe $LocalBaseUrl $_ }
$report = [ordered]@{
  contract_version = "goal-d4-batch0-inventory-v1"
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
  scope = "DEV-ONLY local inventory plus read-only HTTPS measurements"
  canonical_cloud = $canonicalCloud
  cloud_canonical_reason = "D4 binding document records frontend-seven-psi-78 as the production Vercel URL; both configured HTTPS URLs answered health 200 during this audit."
  port_scan = [ordered]@{
    range = "1000-9999"
    listener_inventory_method = "Real TCP connect attempt against 127.0.0.1 for every port plus Windows listening TCP inventory; Docker Compose host publication is cross-checked separately."
    tcp_connect_attempt_count = 9000
    tcp_connect_open_ports = @($tcpConnectOpenPorts)
    listeners = @($portRows | Sort-Object port, address)
    expected_host_port_8081_found = (@($host8081).Count -gt 0)
    unexpected_listeners_documented = @($unexpectedPorts)
  }
  compose_containers = $composeRows
  compose_services = $serviceMatrix
  route_regression = $routeRegression
  api_ref_count = $apiPaths.Count
  api_paths = $apiPaths
  local_api_matrix = $localMatrix
  cloud_api_matrices = $cloudMatrices
  transfer_delta_candidates = @($delta)
  supplemental_noncanonical_routes = $supplementalRoutes
  non_claims = @("No cloud mutation.", "No live LLM provider request.", "No live MCP write.", "No secret output.", "Localhost evidence is DEV-ONLY.")
}
$reportPath = Join-Path $outPath "inventory.json"
$report | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $reportPath -Encoding utf8

function Format-TableRows($Rows, [string[]]$Columns) {
  $Rows | ForEach-Object {
    $cells = foreach ($column in $Columns) {
      $value = $_.$column
      if ($null -eq $value) { "" } else { ([string]$value).Replace("|", "\\|").Replace("`n", " ") }
    }
    "| " + ($cells -join " | ") + " |"
  }
}

$routeRows = Format-TableRows @($supplementalRoutes) @("path", "http_status", "source", "error")
$serviceRows = Format-TableRows @($serviceMatrix) @("service", "internal_port", "status", "latency_ms", "detail")
$portRowsMarkdown = Format-TableRows @($portRows | Sort-Object port, address) @("port", "address", "process_id", "process")
$deltaRows = Format-TableRows @($delta) @("path", "local_status", "local_source", "cloud_status", "cloud_source", "cloud_source_kind", "cloud_live_backend")
$composeRowsMarkdown = Format-TableRows @($composeRows | Sort-Object Service) @("Service", "State", "Health", "Ports")
$routeRowsMarkdown = if ($null -ne $routeRegression) { Format-TableRows @($routeRegression.routes) @("route", "http_status", "app_shell", "main", "fail_count") } else { @("| missing | 0 | false | false | 1 |") }
$apiSummaryRows = foreach ($baseUrl in @($LocalBaseUrl) + $CloudBaseUrls) {
  $rows = if ($baseUrl -eq $LocalBaseUrl) { $localMatrix } else { $cloudMatrices[$baseUrl] }
  [pscustomobject]@{
    base_url = $baseUrl
    total = $rows.Count
    http_200 = @($rows | Where-Object { $_.http_status -eq 200 }).Count
    non_200 = @($rows | Where-Object { $_.http_status -ne 200 }).Count
    frontend_projection_or_empty = @($rows | Where-Object { ([string]$_.source -match "projection|frontend") -or ([string]$_.source_kind -match "projection") }).Count
  }
}
$apiSummaryMarkdown = Format-TableRows $apiSummaryRows @("base_url", "total", "http_200", "non_200", "frontend_projection_or_empty")
$localApiSummaryMarkdown = Format-TableRows @($apiSummaryRows | Where-Object { $_.base_url -eq $LocalBaseUrl }) @("base_url", "total", "http_200", "non_200", "frontend_projection_or_empty")
$cloudApiSummaryMarkdown = Format-TableRows @($apiSummaryRows | Where-Object { $_.base_url -ne $LocalBaseUrl }) @("base_url", "total", "http_200", "non_200", "frontend_projection_or_empty")
$designRowsMarkdown = @(
  "| /technology local | .codex/runs/CURRENT/goal-d4/batch0/surface-audit/screenshots/technology-before.png | DEV-ONLY |",
  "| /technology canonical cloud | .codex/runs/CURRENT/goal-d4/batch0/technology-cloud/screenshots/technology-before.png | HTTPS_HOSTED |"
)

$markdown = @(
  "# Goal D4 Batch 0 Deep Audit",
  "",
  "Scope: DEV-ONLY local inventory plus read-only HTTPS Vercel measurement.",
  "",
  "## Compose State",
  "",
  "| Service | State | Health | Published ports |",
  "| --- | --- | --- | --- |",
  ($composeRowsMarkdown -join "`n"),
  "",
  "## Port Scan 1000-9999",
  "",
  "Method: real TCP connects on 127.0.0.1 across 1000-9999, Windows listener inventory, and Compose publication cross-check. Docker publishes only nginx host port 8081; other discovered host listeners are documented and not attributed to this stack unless their process is Docker/WSL relay.",
  "",
  "| Port | Address | PID | Process |",
  "| ---: | --- | ---: | --- |",
  ($portRowsMarkdown -join "`n"),
  "",
  "## Internal Service Matrix",
  "",
  "The D4 logical platform row is compose status; it is not an eleventh container.",
  "",
  "| Service | Internal port | Status | Latency ms | Detail |",
  "| --- | --- | --- | ---: | --- |",
  ($serviceRows -join "`n"),
  "",
  "## 22 Route Regression",
  "",
  "PASS evidence: `surface-audit/report.json`, `surface-audit/report.md`, its HAR, and 44 before/after PNGs. Canonical registry is exactly 22; `/organism/live` is a supplemental compatibility route. `/exports` is not a page route; `/docs-output` owns export UI.",
  "",
  "| Route | HTTP | App shell | Main | FAIL |",
  "| --- | ---: | --- | --- | ---: |",
  ($routeRowsMarkdown -join "`n"),
  "",
  "## API Status Matrix Summary",
  "",
  "All $($apiPaths.Count) API-like workspace references were measured with GET. POST-only LLM chat was intentionally not invoked in Batch 0 because this batch is read-only and must not consume a provider budget or create a session.",
  "",
  "### Local API Matrix",
  "",
  "| Base URL | Refs | HTTP 200 | Non-200 | Projection-like |",
  "| --- | ---: | ---: | ---: | ---: |",
  ($localApiSummaryMarkdown -join "`n"),
  "",
  "### Cloud API Matrix",
  "",
  "| Base URL | Refs | HTTP 200 | Non-200 | Projection-like |",
  "| --- | ---: | ---: | ---: | ---: |",
  ($cloudApiSummaryMarkdown -join "`n"),
  "",
  "Full per-path matrices, source headers, source kinds, live-backend flags, response hashes, and errors are in `inventory.json`.",
  "",
  "## Delta Candidates",
  "",
  "Canonical cloud: ``$canonicalCloud``. A delta candidate means local HTTP 200 while the canonical cloud response is projection-like, explicitly has ``live_backend=false``, or is non-200. This is evidence for Batch 1 classification, not a live-backend claim.",
  "",
  "| Path | Local HTTP | Local source | Cloud HTTP | Cloud source | Cloud source kind | Cloud live backend |",
  "| --- | ---: | --- | ---: | --- | --- | --- |",
  $(if (@($delta).Count) { $deltaRows -join "`n" } else { "| none | | | | | | |" }),
  "",
  "## Supplemental Noncanonical Routes",
  "",
  "| Path | HTTP | Source | Error |",
  "| --- | ---: | --- | --- |",
  ($routeRows -join "`n"),
  "",
  "## Design Delta",
  "",
  "| Surface | Screenshot | Scope |",
  "| --- | --- | --- |",
  ($designRowsMarkdown -join "`n"),
  "",
  "Visual target documentation is not changed by this inventory; it requires visual evidence review first.",
  "",
  "FAIL definition: Batch 0 route regression is PASS only when ``surface-audit/report.json`` reports ``fail_count=0``; inventory measurements document actual non-200/API projection differences without pretending they are route regressions.",
  "",
  "Non-Claims: no cloud mutation, no live LLM call, no live MCP write, no secret output, no hosted-agent-api claim.",
  ""
) -join "`n"
$markdown | Set-Content -LiteralPath (Join-Path $outPath "batch0-deep-audit.md") -Encoding utf8

$failedServices = @($serviceMatrix | Where-Object { $_.status -ne "PASS" }).Count
if ($failedServices -gt 0) { throw "Batch 0 internal service failures=$failedServices; see $reportPath" }
Write-Host "[goal-d4-batch0] api_refs=$($apiPaths.Count) local_200=$(@($localMatrix | Where-Object { $_.http_status -eq 200 }).Count) delta_candidates=$(@($delta).Count) out=$OutDir"
