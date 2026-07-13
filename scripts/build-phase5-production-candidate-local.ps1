param(
  [string]$SourceSha = "",
  [string]$ReleaseId = "prod-candidate-2026-07-13-local-rc1",
  [string]$OutputDir = ".codex\runs\CURRENT\master-goal\phase5\production-candidate-local"
)

$ErrorActionPreference = "Stop"

function Assert-SafeName([string]$Label, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]+$') {
    throw "$Label contains unsupported characters: $Value"
  }
}

function Invoke-Native([string]$Label, [string]$FilePath, [string[]]$Arguments, [string]$LogPath = "") {
  $previousErrorActionPreference = $ErrorActionPreference
  $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
  $ErrorActionPreference = "Continue"
  $PSNativeCommandUseErrorActionPreference = $false
  try {
    if ($LogPath) {
      & $FilePath @Arguments 2>&1 | Tee-Object -FilePath $LogPath
    } else {
      & $FilePath @Arguments 2>&1
    }
    $exitCode = $LASTEXITCODE
  } finally {
    $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
    $ErrorActionPreference = $previousErrorActionPreference
  }
  if ($exitCode -ne 0) {
    throw "$Label failed with exit code $exitCode."
  }
}

function Get-ContainerSha256([string]$Image, [string]$Path) {
  $value = (& docker run --rm --entrypoint sha256sum $Image $Path 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $value -notmatch '^([0-9a-f]{64})\s+') {
    throw "Could not hash $Path in $Image. Value: $value"
  }
  return $Matches[1]
}

Assert-SafeName "ReleaseId" $ReleaseId
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($SourceSha)) {
    $candidateConfig = Get-Content "docs\release-artifacts\current-release-candidate.json" -Raw | ConvertFrom-Json
    if ([string]$candidateConfig.active_release_id -ne $ReleaseId) {
      throw "Active release id does not match requested release id."
    }
    $candidateText = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
    if ($candidateText -notmatch '(?m)^source_commit_sha:\s*`([0-9a-f]{40})`\s*$') {
      throw "Active candidate does not contain a valid source_commit_sha."
    }
    $SourceSha = $Matches[1]
  }
  $resolvedSourceSha = (git rev-parse "$SourceSha^{commit}" 2>$null | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $resolvedSourceSha -notmatch '^[0-9a-f]{40}$') {
    throw "SourceSha is not a local commit: $SourceSha"
  }

  $outputPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDir))
  New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
  $logsPath = Join-Path $outputPath "build-logs"
  New-Item -ItemType Directory -Force -Path $logsPath | Out-Null

  $tempRoot = [System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetTempPath()) "cloud-superbrain-phase5"))
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  $workPath = [System.IO.Path]::GetFullPath((Join-Path $tempRoot ([Guid]::NewGuid().ToString("N"))))
  if (-not $workPath.StartsWith($tempRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing unsafe candidate work path: $workPath"
  }
  New-Item -ItemType Directory -Force -Path $workPath | Out-Null

  try {
    $archivePath = Join-Path $workPath "source.tar"
    $sourcePath = Join-Path $workPath "source"
    New-Item -ItemType Directory -Force -Path $sourcePath | Out-Null
    Invoke-Native "git archive" "git" @("archive", "--format=tar", "--output=$archivePath", $resolvedSourceSha)
    Invoke-Native "git archive extraction" "tar.exe" @("-xf", $archivePath, "-C", $sourcePath)
    $archiveSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()

    $serviceDefinitions = @(
      [ordered]@{ id = "frontend"; dockerfile = "apps/frontend/Dockerfile"; context = "apps/frontend"; target = "runner"; source_file = "apps/frontend/package.json"; embedded_file = "/app/package.json" },
      [ordered]@{ id = "agent-api"; dockerfile = "services/agent-api/Dockerfile"; context = "."; target = ""; source_file = "services/agent-api/app/main.py"; embedded_file = "/app/app/main.py" },
      [ordered]@{ id = "agent-worker"; dockerfile = "services/agent-worker/Dockerfile"; context = "."; target = ""; source_file = "services/agent-worker/app/worker.py"; embedded_file = "/app/app/worker.py" },
      [ordered]@{ id = "memory-worker"; dockerfile = "services/memory-worker/Dockerfile"; context = "."; target = ""; source_file = "services/memory-worker/app/worker.py"; embedded_file = "/app/app/worker.py" },
      [ordered]@{ id = "mcp-gateway"; dockerfile = "services/mcp-gateway/Dockerfile"; context = "."; target = ""; source_file = "services/mcp-gateway/app/main.py"; embedded_file = "/app/app/main.py" },
      [ordered]@{ id = "llm-gateway"; dockerfile = "services/llm-gateway/Dockerfile"; context = "."; target = ""; source_file = "services/llm-gateway/app/main.py"; embedded_file = "/app/app/main.py" }
    )

    $images = @()
    foreach ($service in $serviceDefinitions) {
      $imageTag = "cloud-superbrain-production-candidate/$($service.id):$resolvedSourceSha"
      $dockerfilePath = Join-Path $sourcePath $service.dockerfile
      $contextPath = Join-Path $sourcePath $service.context
      $buildArgs = @(
        "build",
        "--file", $dockerfilePath,
        "--tag", $imageTag,
        "--label", "org.opencontainers.image.revision=$resolvedSourceSha",
        "--label", "org.opencontainers.image.source=https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
        "--label", "org.opencontainers.image.version=$ReleaseId",
        "--label", "org.opencontainers.image.ref.name=$ReleaseId"
      )
      if ($service.target) {
        $buildArgs += @("--target", $service.target)
      }
      $buildArgs += $contextPath
      Write-Host "[phase5-candidate-local] building $($service.id) from committed archive $resolvedSourceSha"
      Invoke-Native "docker build $($service.id)" "docker" $buildArgs (Join-Path $logsPath "$($service.id).log")

      $inspect = @(& docker image inspect $imageTag | ConvertFrom-Json)[0]
      if ($LASTEXITCODE -ne 0 -or $null -eq $inspect) {
        throw "docker inspect failed for $imageTag"
      }
      $revision = [string]$inspect.Config.Labels.'org.opencontainers.image.revision'
      $version = [string]$inspect.Config.Labels.'org.opencontainers.image.version'
      if ($revision -ne $resolvedSourceSha -or $version -ne $ReleaseId) {
        throw "OCI label mismatch for $imageTag"
      }

      $sourceFilePath = Join-Path $sourcePath $service.source_file
      $sourceFileSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFilePath).Hash.ToLowerInvariant()
      $embeddedFileSha256 = Get-ContainerSha256 -Image $imageTag -Path $service.embedded_file
      if ($sourceFileSha256 -ne $embeddedFileSha256) {
        throw "Embedded source hash mismatch for $($service.id)"
      }

      $frontendBuildId = ""
      if ($service.id -eq "frontend") {
        $frontendBuildId = (& docker run --rm --entrypoint cat $imageTag /app/.next/BUILD_ID 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($frontendBuildId)) {
          throw "Frontend production image does not contain a Next.js BUILD_ID."
        }
      }

      $images += [ordered]@{
        service = $service.id
        image_tag = $imageTag
        image_id = [string]$inspect.Id
        image_size_bytes = [int64]$inspect.Size
        dockerfile = $service.dockerfile
        dockerfile_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $dockerfilePath).Hash.ToLowerInvariant()
        source_file = $service.source_file
        embedded_file = $service.embedded_file
        source_file_sha256 = $sourceFileSha256
        embedded_file_sha256 = $embeddedFileSha256
        oci_revision = $revision
        oci_source = [string]$inspect.Config.Labels.'org.opencontainers.image.source'
        oci_version = $version
        frontend_build_id = $frontendBuildId
      }
    }

    $report = [ordered]@{
      contract_version = "phase5-production-candidate-local-v1"
      evidence_ref = "phase5_local_production_candidate_verified"
      status = "verified"
      generated_at = (Get-Date).ToUniversalTime().ToString("o")
      release_id = $ReleaseId
      source_commit_sha = $resolvedSourceSha
      source_boundary = "committed_git_archive_only"
      git_archive_sha256 = $archiveSha256
      service_count = $images.Count
      images = $images
      rollback_target = "7be0ac03de2a5f435d98629de3d310253c00e3f3"
      phase5_progress_before_proof = 67
      phase5_progress_after_proof = 68
      registry_publish = $false
      hosted_staging_parity = $false
      production_deploy = $false
      release_promotion = $false
      owner_review_approved = $false
      secret_output = $false
      non_claims = @(
        "Local image IDs are Docker-engine-local content addresses and are not GHCR digests.",
        "The planned immutable GHCR tag set is unpublished.",
        "DEV-ONLY; hosted proof still blocked.",
        "No production deployment or release promotion was performed."
      )
    }
    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputPath "candidate-images.json") -Encoding utf8

    $markdown = @"
# Phase 5 Local Production Candidate Proof

- Status: verified
- Release: ``$ReleaseId``
- Source commit: ``$resolvedSourceSha``
- Source boundary: committed Git archive only
- Git archive SHA256: ``$archiveSha256``
- Service images: $($images.Count)
- Phase 5: 67 -> 68
- Registry publish: false
- Hosted staging parity: false
- Production deploy: false
- Release promotion: false
- Owner review approved: false

DEV-ONLY; hosted proof still blocked. Local Docker image IDs are not GHCR digests.
"@
    Set-Content -LiteralPath (Join-Path $outputPath "candidate-images.md") -Value $markdown -Encoding utf8
    Write-Host "[phase5-candidate-local] report=$(Join-Path $outputPath 'candidate-images.json')"
    Write-Host "[phase5-candidate-local] status=verified service_count=$($images.Count)"
  } finally {
    if (Test-Path -LiteralPath $workPath) {
      $resolvedCleanup = [System.IO.Path]::GetFullPath($workPath)
      if (-not $resolvedCleanup.StartsWith($tempRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing unsafe recursive cleanup path: $resolvedCleanup"
      }
      Remove-Item -LiteralPath $resolvedCleanup -Recurse -Force
    }
  }
} finally {
  Pop-Location
}
