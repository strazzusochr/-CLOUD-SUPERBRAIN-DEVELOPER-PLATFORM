$ErrorActionPreference = "Stop"

$checks = @(
  @{
    Dockerfile = "services/agent-api/Dockerfile"
    Sources = @(
      "services/agent-api/requirements.txt",
      "services/agent-api/app",
      "docs/project-progress.manifest.json",
      "docs/runtime-state/external-gate-summary.json",
      "PROJECT_STATE.md",
      "docs/codex-integration/autonomous-agent-roster.json"
    )
  },
  @{
    Dockerfile = "services/mcp-gateway/Dockerfile"
    Sources = @("services/mcp-gateway/requirements.txt", "services/mcp-gateway/app")
  },
  @{
    Dockerfile = "services/llm-gateway/Dockerfile"
    Sources = @("services/llm-gateway/requirements.txt", "services/llm-gateway/app")
  },
  @{
    Dockerfile = "services/agent-worker/Dockerfile"
    Sources = @("services/agent-worker/requirements.txt", "services/agent-worker/app")
  },
  @{
    Dockerfile = "services/memory-worker/Dockerfile"
    Sources = @("services/memory-worker/requirements.txt", "services/memory-worker/app")
  }
)

foreach ($check in $checks) {
  if (-not (Test-Path -LiteralPath $check.Dockerfile)) {
    throw "Missing Dockerfile: $($check.Dockerfile)"
  }

  $dockerfile = Get-Content -LiteralPath $check.Dockerfile -Raw
  foreach ($source in $check.Sources) {
    if (-not (Test-Path -LiteralPath $source)) {
      throw "Fly build source does not exist: $source"
    }
    if (-not $dockerfile.Contains("COPY $source")) {
      throw "$($check.Dockerfile) is not repository-root-build-safe: missing COPY $source"
    }
  }
}

$appConfigs = @(
  @{ Path = "fly.agent-api.toml"; App = "cloud-superbrain-agent-api"; Dockerfile = "services/agent-api/Dockerfile" },
  @{ Path = "fly.agent-worker.toml"; App = "cloud-superbrain-agent-worker"; Dockerfile = "services/agent-worker/Dockerfile" },
  @{ Path = "fly.memory-worker.toml"; App = "cloud-superbrain-memory-worker"; Dockerfile = "services/memory-worker/Dockerfile" },
  @{ Path = "fly.mcp-gateway.toml"; App = "cloud-superbrain-mcp-gateway"; Dockerfile = "services/mcp-gateway/Dockerfile" },
  @{ Path = "fly.llm-gateway.toml"; App = "cloud-superbrain-llm-gateway"; Dockerfile = "services/llm-gateway/Dockerfile" }
)

foreach ($config in $appConfigs) {
  if (-not (Test-Path -LiteralPath $config.Path)) {
    throw "Missing Fly app config: $($config.Path)"
  }
  $raw = Get-Content -LiteralPath $config.Path -Raw
  foreach ($marker in @(
    "app = `"$($config.App)`"",
    "primary_region = `"fra`"",
    "dockerfile = `"$($config.Dockerfile)`"",
    "size = `"shared-cpu-1x`""
  )) {
    if (-not $raw.Contains($marker)) {
      throw "$($config.Path) missing Fly app marker: $marker"
    }
  }
}

$mcpConfig = Get-Content -LiteralPath "fly.mcp-gateway.toml" -Raw
$llmConfig = Get-Content -LiteralPath "fly.llm-gateway.toml" -Raw
$callback = 'AGENT_API_INTERNAL_URL = "http://cloud-superbrain-agent-api.flycast:8000"'
if (-not $mcpConfig.Contains($callback)) {
  throw "fly.mcp-gateway.toml missing private Agent API callback origin"
}
if (-not $llmConfig.Contains($callback)) {
  throw "fly.llm-gateway.toml missing private Agent API callback origin"
}

$rootIgnore = Get-Content -LiteralPath ".dockerignore" -Raw
$frontendIgnore = Get-Content -LiteralPath "apps/frontend/.dockerignore" -Raw
foreach ($marker in @(".env.*", "**/.env.*")) {
  if (-not $rootIgnore.Contains($marker)) {
    throw "Root Docker context does not exclude secret env files: missing $marker"
  }
}
if (-not $frontendIgnore.Contains(".env*")) {
  throw "Frontend Docker context does not exclude .env.local/.env production files"
}

Write-Host "[fly-build-context] repository-root COPY sources verified"
Write-Host "[fly-build-context] five Fly app configs verified"
Write-Host "[fly-build-context] private callback origins verified"
Write-Host "[fly-build-context] secret env files excluded from Docker contexts"
