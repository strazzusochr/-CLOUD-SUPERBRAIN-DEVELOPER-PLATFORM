param(
    [string]$Namespace = "ghcr.io/strazzusochr/cloud-superbrain-developer-platform",
    [string]$Tag = "staging",
    [string]$Platforms = "linux/arm64",
    [string]$Builder = ""
)

if ([string]::IsNullOrWhiteSpace($Tag) -or $Tag.Length -gt 128 -or $Tag -notmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$') {
    throw "Invalid Docker tag: $Tag"
}

& (Join-Path $PSScriptRoot "require-docker-readiness.ps1") -GateName "image build and push"

$Services = @(
    @{ name = "agent-api"; path = "services/agent-api" },
    @{ name = "agent-worker"; path = "services/agent-worker" },
    @{ name = "memory-worker"; path = "services/memory-worker" },
    @{ name = "llm-gateway"; path = "services/llm-gateway" },
    @{ name = "mcp-gateway"; path = "services/mcp-gateway" },
    @{ name = "frontend"; path = "apps/frontend" }
)

foreach ($service in $Services) {
    $name = $service.name
    $path = $service.path
    $image = "${Namespace}/${name}:${Tag}"
    $buildArgs = @("buildx", "build", "--platform", $Platforms, "-t", $image, "--push")
    if (-not [string]::IsNullOrWhiteSpace($Builder)) {
        $buildArgs += @("--builder", $Builder)
    }
    $buildArgs += @($path)

    Write-Host "--- Building and Pushing $name ---"
    docker @buildArgs
    if ($LASTEXITCODE -ne 0) {
        throw "docker buildx build failed for $name"
    }
}
