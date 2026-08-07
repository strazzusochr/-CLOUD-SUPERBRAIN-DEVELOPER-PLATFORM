param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost,
  [switch]$StaticOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Filesystem project-progress verification failed: $Label" }
}

function Assert-Contains([string]$Label, [string]$Text, [string]$Needle) {
  Assert-True $Label ($Text.Contains($Needle))
}

function Read-Source([string]$RelativePath) {
  $path = Join-Path $repoRoot $RelativePath
  Assert-True "$RelativePath exists" (Test-Path -LiteralPath $path -PathType Leaf)
  return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

$mcp = Read-Source "services\mcp-gateway\app\main.py"
$agent = Read-Source "services\agent-api\app\main.py"
$dockerfile = Read-Source "services\mcp-gateway\Dockerfile"
$compose = Read-Source "docker-compose.dev.yml"
$devNginx = Read-Source "infrastructure\nginx\dev.conf"
$cloudNginx = Read-Source "infrastructure\nginx\cloud.conf"
$vercelMcp = Read-Source "api\mcp.py"
$ui = Read-Source "apps\frontend\components\goal-b-actions.tsx"
$defaults = Read-Source "apps\frontend\lib\endpointDefaults.ts"
$contractDoc = Read-Source "docs\runtime-contracts\mcp-filesystem-project-progress-contract.md"

foreach ($required in @(
  "filesystem-project-progress-read-v1",
  "filesystem_project_progress_read_verified",
  "def filesystem_project_progress_contract",
  "def execute_filesystem_project_progress_read",
  "/internal/v1/filesystem/project-progress",
  "FILESYSTEM_PROJECT_PROGRESS_PATH",
  "65_536",
  "read_phase:authorized",
  "read_phase:completed",
  "filesystem_read_performed",
  "caller_path_allowed",
  "direct_provider_calls",
  "progress_source",
  "os.open",
  "O_NOFOLLOW"
)) { Assert-Contains "MCP source marker $required" $mcp $required }

foreach ($required in @(
  "filesystem_project_progress",
  "canonical-project-progress",
  "filesystem-project-progress-read-v1",
  "/internal/v1/filesystem/project-progress",
  "mcp_audit_readback_verified",
  "timeout=3.0"
)) { Assert-Contains "Agent source marker $required" $agent $required }

Assert-Contains "manifest copied into MCP image" $dockerfile "docs/project-progress.manifest.json"
Assert-Contains "manifest fixed image path" $dockerfile "/app/readonly/project-progress.manifest.json"
Assert-Contains "manifest made read-only" $dockerfile "chmod 0444"
Assert-Contains "MCP exact DEV mode" $compose 'SUPERBRAIN_RUNTIME_MODE: "dev-only"'
foreach ($source in @($devNginx, $cloudNginx)) {
  Assert-Contains "public internal MCP path blocked" $source "location ^~ /mcp/internal/"
  Assert-Contains "public service-token header stripped" $source 'proxy_set_header X-Superbrain-Agent-Token "";'
}
foreach ($required in @('request.url.path.startswith("/mcp/internal/")', 'status_code=404')) {
  Assert-Contains "Vercel ASGI internal MCP path guard" $vercelMcp $required
}
Assert-Contains "local UI adapter option" $ui 'value="filesystem_project_progress"'
Assert-Contains "local UI canonical query" $ui "canonical-project-progress"
Assert-Contains "version pinning includes adapter" $mcp "filesystem-project-progress-read-v1"
Assert-Contains "frontend default includes adapter pin" $defaults "filesystem-project-progress-read-v1"
foreach ($required in @(
  "filesystem-project-progress-read-v1",
  "canonical-project-progress",
  "65536",
  "O_NOFOLLOW",
  "audit_before_read",
  "audit_after_read",
  "DEV-ONLY; hosted proof still blocked",
  'MCP Gateway remains `56%`',
  'Overall remains `89%`'
)) { Assert-Contains "runtime contract documentation $required" $contractDoc $required }

if ($StaticOnly) {
  Write-Host "[filesystem-project-progress] status=verified_static DEV-ONLY hosted=false"
  exit 0
}

$uri = [Uri]$BaseUrl
$isLocal = $uri.Scheme -eq "http" -and $uri.Host -in @("localhost", "127.0.0.1", "::1")
Assert-True "runtime proof is DEV-ONLY localhost" ($isLocal -and $AllowLocalhost)
$base = $BaseUrl.TrimEnd("/")

$contract = Invoke-RestMethod -Method Get -Uri "$base/mcp/api/v1/filesystem/project-progress/contract" -TimeoutSec 15
Assert-True "contract version" ([string]$contract.contract_version -eq "filesystem-project-progress-read-v1")
Assert-True "contract caller path false" ([bool]$contract.caller_path_allowed -eq $false)
Assert-True "contract max bytes" ([int]$contract.max_source_bytes -eq 65536)
Assert-True "contract no writes" ([bool]$contract.live_mcp_writes -eq $false)
Assert-True "contract no direct provider calls" ([bool]$contract.direct_provider_calls -eq $false)
Assert-True "contract no secrets" ([bool]$contract.secret_output -eq $false)

$internalStatus = curl.exe -sS --max-time 15 --output NUL --write-out "%{http_code}" "$base/mcp/internal/v1/filesystem/project-progress"
Assert-True "public internal endpoint is hidden" ([int]$internalStatus -eq 404)

$body = @{ project_id = "goal-b-local"; tool_id = "filesystem_project_progress"; query = "canonical-project-progress" } | ConvertTo-Json -Compress
$result = Invoke-RestMethod -Method Post -Uri "$base/api/v1/tools/read-only/execute" -ContentType "application/json" -Body $body -TimeoutSec 30
Assert-True "execution success" ([string]$result.status -eq "success")
Assert-True "tool id" ([string]$result.tool_id -eq "filesystem_project_progress")
Assert-True "filesystem read performed" ([bool]$result.filesystem_read_performed)
Assert-True "MCP audits read back" ([bool]$result.mcp_audit_readback_verified)
Assert-True "agent audit persisted" ([bool]$result.audit_persisted)
Assert-True "overall bounded" ([int]$result.result.overall_percent -ge 0 -and [int]$result.result.overall_percent -le 100)
Assert-True "seven phases" (@($result.result.horizontal).Count -eq 7)
Assert-True "seven layers" (@($result.result.vertical).Count -eq 7)
Assert-True "phase projection allowlist" ((@($result.result.horizontal[0].PSObject.Properties.Name | Sort-Object) -join ",") -eq "id,percent")
Assert-True "layer projection allowlist" ((@($result.result.vertical[0].PSObject.Properties.Name | Sort-Object) -join ",") -eq "id,percent")
Assert-True "source hash" ([string]$result.result.source_sha256 -match '^[a-f0-9]{64}$')
foreach ($field in @("live_mcp_writes", "live_provider_calls", "direct_provider_calls", "production_deploy", "secret_output")) {
  Assert-True "$field false" ([bool]$result.$field -eq $false)
}

$badBody = @{ project_id = "goal-b-local"; tool_id = "filesystem_project_progress"; query = "../PROJECT_STATE.md" } | ConvertTo-Json -Compress
$tempStem = "superbrain-filesystem-project-progress-" + [Guid]::NewGuid().ToString("N")
$badRequestPath = Join-Path ([IO.Path]::GetTempPath()) ($tempStem + "-request.json")
$badResponsePath = Join-Path ([IO.Path]::GetTempPath()) ($tempStem + "-response.json")
try {
  [IO.File]::WriteAllText($badRequestPath, $badBody, [Text.UTF8Encoding]::new($false))
  $badStatus = curl.exe -sS --max-time 15 -H "Content-Type: application/json" --data-binary "@$badRequestPath" --output $badResponsePath --write-out "%{http_code}" "$base/api/v1/tools/read-only/execute"
  $badResponse = [IO.File]::ReadAllText($badResponsePath)
} finally {
  Remove-Item -LiteralPath $badRequestPath, $badResponsePath -Force -ErrorAction SilentlyContinue
}
Assert-True "caller path rejected" ([int]$badStatus -eq 422)
Assert-Contains "caller path rejection body" $badResponse "canonical-project-progress"

Write-Host "[filesystem-project-progress] status=verified runtime_read=true audit_before_after=true secret_output=false DEV-ONLY hosted=false"
