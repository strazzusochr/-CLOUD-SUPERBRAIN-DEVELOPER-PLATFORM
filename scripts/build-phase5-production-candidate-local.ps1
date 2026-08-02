param(
  [string]$SourceSha = "",
  [string]$ReleaseId = "prod-candidate-2026-07-20-local-rc2",
  [string]$RollbackTarget = "",
  [string]$OutputDir = ".codex\runs\CURRENT\master-goal\phase5\production-candidate-local",
  [string]$EvidenceRunId = ""
)

$ErrorActionPreference = "Stop"

function Assert-SafeName([string]$Label, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]+$') {
    throw "$Label contains unsupported characters: $Value"
  }
}

function Assert-CommitSha([string]$Label, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "$Label must be a lowercase 40-character commit SHA."
  }
  git cat-file -e "$Value^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "$Label is not a local commit: $Value"
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

function Get-ContainerSha256([string]$Image, [string]$Path, [string]$RawOutputPath = "") {
  $value = (& docker run --rm --entrypoint sha256sum $Image $Path 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $value -notmatch '^([0-9a-f]{64})\s+') {
    throw "Could not hash $Path in $Image. Value: $value"
  }
  if ($RawOutputPath) {
    [IO.File]::WriteAllText($RawOutputPath, "$value`n", [Text.UTF8Encoding]::new($false))
  }
  return $Matches[1]
}

function Get-FileSha256([string]$Path) {
  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
      return ([System.BitConverter]::ToString($sha256.ComputeHash($stream))).Replace("-", "").ToLowerInvariant()
    } finally {
      $sha256.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
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
  $legacyEvidence = (
    $ReleaseId -eq "prod-candidate-2026-07-31-local-rc11" -and
    $resolvedSourceSha -eq "bae3cdc1692e1e99e7f546f72664a3c747958b8c"
  )
  if (-not $legacyEvidence) {
    if ([string]::IsNullOrWhiteSpace($EvidenceRunId)) {
      $EvidenceRunId = [Guid]::NewGuid().ToString("D").ToLowerInvariant()
    }
    if ($EvidenceRunId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') {
      throw "EvidenceRunId must be a lowercase RFC 4122 version-4 UUID."
    }
  }

  if ([string]::IsNullOrWhiteSpace($RollbackTarget)) {
    $activeConfig = Get-Content "docs\release-artifacts\current-release-candidate.json" -Raw | ConvertFrom-Json
    $activeArtifactPath = "docs\release-artifacts\$([string]$activeConfig.active_release_id).md"
    if (-not (Test-Path -LiteralPath $activeArtifactPath)) {
      throw "Cannot derive rollback target; active candidate artifact is missing: $activeArtifactPath"
    }
    $activeArtifact = Get-Content -LiteralPath $activeArtifactPath -Raw
    if ($activeArtifact -notmatch '(?m)^immutable_image_commit_sha:\s*`([0-9a-f]{40})`\s*$') {
      throw "Cannot derive rollback target from active candidate artifact."
    }
    $RollbackTarget = $Matches[1]
  }
  Assert-CommitSha "RollbackTarget" $RollbackTarget
  if ($RollbackTarget -eq $resolvedSourceSha) {
    throw "RollbackTarget must differ from the candidate source commit."
  }

  $outputPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDir))
  New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
  $logsPath = Join-Path $outputPath "build-logs"
  New-Item -ItemType Directory -Force -Path $logsPath | Out-Null
  $rawPath = Join-Path $outputPath "raw"
  $rawImagesPath = Join-Path $rawPath "candidate-images"
  New-Item -ItemType Directory -Force -Path $rawImagesPath | Out-Null

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
    $archiveSha256 = Get-FileSha256 $archivePath

    $sourceManifestPath = Join-Path $sourcePath "docs\project-progress.manifest.json"
    if (-not (Test-Path -LiteralPath $sourceManifestPath)) {
      throw "Candidate source manifest is missing from committed archive: $resolvedSourceSha"
    }
    $sourceManifest = Get-Content -LiteralPath $sourceManifestPath -Raw | ConvertFrom-Json
    $sourcePhase5Items = @($sourceManifest.horizontal.items | Where-Object { $_.id -eq "phase_5" })
    if ($sourcePhase5Items.Count -ne 1) {
      throw "Candidate source manifest must contain exactly one phase_5 item."
    }
    $phase5Percent = [int]$sourcePhase5Items[0].percent
    if ($phase5Percent -lt 0 -or $phase5Percent -gt 100) {
      throw "Candidate source manifest contains an invalid phase_5 percent: $phase5Percent"
    }

    $serviceDefinitions = @(
      [ordered]@{ id = "frontend"; dockerfile = "apps/frontend/Dockerfile"; context = "apps/frontend"; target = "runner"; source_file = "apps/frontend/package.json"; embedded_file = "/app/package.json" },
      [ordered]@{ id = "agent-api"; dockerfile = "services/agent-api/Dockerfile"; context = "."; target = ""; source_file = "services/agent-api/app/main.py"; embedded_file = "/app/app/main.py" },
      [ordered]@{ id = "agent-worker"; dockerfile = "services/agent-worker/Dockerfile"; context = "."; target = ""; source_file = "services/agent-worker/app/worker.py"; embedded_file = "/app/app/worker.py" },
      [ordered]@{ id = "memory-worker"; dockerfile = "services/memory-worker/Dockerfile"; context = "."; target = ""; source_file = "services/memory-worker/app/worker.py"; embedded_file = "/app/app/worker.py" },
      [ordered]@{ id = "mcp-gateway"; dockerfile = "services/mcp-gateway/Dockerfile"; context = "."; target = ""; source_file = "services/mcp-gateway/app/main.py"; embedded_file = "/app/app/main.py" },
      [ordered]@{ id = "llm-gateway"; dockerfile = "services/llm-gateway/Dockerfile"; context = "."; target = ""; source_file = "services/llm-gateway/app/main.py"; embedded_file = "/app/app/main.py" }
    )

    $images = @()
    $rawImages = @()
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

      $inspectRaw = (& docker image inspect $imageTag 2>&1 | Out-String).Trim()
      $inspectExit = $LASTEXITCODE
      if ($inspectExit -ne 0 -or [string]::IsNullOrWhiteSpace($inspectRaw)) {
        throw "docker inspect failed for $imageTag"
      }
      $inspect = @($inspectRaw | ConvertFrom-Json)[0]
      if ($null -eq $inspect) {
        throw "docker inspect returned invalid JSON for $imageTag"
      }
      $inspectRawPath = Join-Path $rawImagesPath "$($service.id)-inspect.json"
      [IO.File]::WriteAllText($inspectRawPath, "$inspectRaw`n", [Text.UTF8Encoding]::new($false))
      $revision = [string]$inspect.Config.Labels.'org.opencontainers.image.revision'
      $version = [string]$inspect.Config.Labels.'org.opencontainers.image.version'
      if ($revision -ne $resolvedSourceSha -or $version -ne $ReleaseId) {
        throw "OCI label mismatch for $imageTag"
      }

      $sourceFilePath = Join-Path $sourcePath $service.source_file
      $sourceFileSha256 = Get-FileSha256 $sourceFilePath
      $embeddedRawPath = Join-Path $rawImagesPath "$($service.id)-embedded-sha256.txt"
      $embeddedFileSha256 = Get-ContainerSha256 -Image $imageTag -Path $service.embedded_file -RawOutputPath $embeddedRawPath
      if ($sourceFileSha256 -ne $embeddedFileSha256) {
        throw "Embedded source hash mismatch for $($service.id)"
      }

      $frontendBuildId = ""
      if ($service.id -eq "frontend") {
        $frontendBuildId = (& docker run --rm --entrypoint cat $imageTag /app/.next/BUILD_ID 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($frontendBuildId)) {
          throw "Frontend production image does not contain a Next.js BUILD_ID."
        }
        [IO.File]::WriteAllText(
          (Join-Path $rawImagesPath "frontend-build-id.txt"),
          "$frontendBuildId`n",
          [Text.UTF8Encoding]::new($false)
        )
      }

      $images += [ordered]@{
        service = $service.id
        image_tag = $imageTag
        image_id = [string]$inspect.Id
        image_size_bytes = [int64]$inspect.Size
        dockerfile = $service.dockerfile
        dockerfile_sha256 = Get-FileSha256 $dockerfilePath
        source_file = $service.source_file
        embedded_file = $service.embedded_file
        source_file_sha256 = $sourceFileSha256
        embedded_file_sha256 = $embeddedFileSha256
        oci_revision = $revision
        oci_source = [string]$inspect.Config.Labels.'org.opencontainers.image.source'
        oci_version = $version
        frontend_build_id = $frontendBuildId
      }
      $rawImage = [ordered]@{
        service = $service.id
        inspect = [ordered]@{
          path = "docs/release-artifacts/$ReleaseId-evidence/raw/candidate-images/$($service.id)-inspect.json"
          sha256 = (Get-FileHash -LiteralPath $inspectRawPath -Algorithm SHA256).Hash
        }
        embedded_hash = [ordered]@{
          path = "docs/release-artifacts/$ReleaseId-evidence/raw/candidate-images/$($service.id)-embedded-sha256.txt"
          sha256 = (Get-FileHash -LiteralPath $embeddedRawPath -Algorithm SHA256).Hash
        }
      }
      if ($service.id -eq "frontend") {
        $frontendBuildIdPath = Join-Path $rawImagesPath "frontend-build-id.txt"
        $rawImage["frontend_build_id"] = [ordered]@{
          path = "docs/release-artifacts/$ReleaseId-evidence/raw/candidate-images/frontend-build-id.txt"
          sha256 = (Get-FileHash -LiteralPath $frontendBuildIdPath -Algorithm SHA256).Hash
        }
      }
      $rawImages += $rawImage
    }

    $evidenceCommand = (
      "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/build-phase5-production-candidate-local.ps1 " +
      "-SourceSha $resolvedSourceSha -ReleaseId $ReleaseId -RollbackTarget $RollbackTarget " +
      "-OutputDir $OutputDir -EvidenceRunId $EvidenceRunId"
    )
    $rawLogPath = Join-Path $rawPath "candidate-images.log"
    if (-not $legacyEvidence) {
      $rawLogLines = @(
        "PHASE5_EVIDENCE_RAW_V2",
        "[phase5-evidence] chain=candidate-images",
        "[phase5-evidence] release_id=$ReleaseId",
        "[phase5-evidence] source_commit_sha=$resolvedSourceSha",
        "[phase5-evidence] evidence_run_id=$EvidenceRunId",
        "[phase5-evidence] command=$evidenceCommand",
        "[phase5-candidate-local] status=verified service_count=$($images.Count)",
        "[phase5-evidence] exit_code=0"
      )
      [IO.File]::WriteAllLines($rawLogPath, $rawLogLines, [Text.UTF8Encoding]::new($false))
    }

    $report = [ordered]@{
      contract_version = $(if ($legacyEvidence) { "phase5-production-candidate-local-v1" } else { "phase5-production-candidate-local-v2" })
      evidence_ref = "phase5_local_production_candidate_verified"
      status = "verified"
      generated_at = (Get-Date).ToUniversalTime().ToString("o")
      release_id = $ReleaseId
      source_commit_sha = $resolvedSourceSha
      source_boundary = "committed_git_archive_only"
      git_archive_sha256 = $archiveSha256
      service_count = $images.Count
      images = $images
      rollback_target = $RollbackTarget
      rollback_target_source = "active_release_candidate"
      phase5_progress_before_proof = $phase5Percent
      phase5_progress_after_proof = $phase5Percent
      progress_credit_claimed = $false
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
    if (-not $legacyEvidence) {
      $report["command"] = $evidenceCommand
      $report["evidence_run_id"] = $EvidenceRunId
      $report["raw_log_path"] = "docs/release-artifacts/$ReleaseId-evidence/raw/candidate-images.log"
      $report["raw_log_sha256"] = (Get-FileHash -LiteralPath $rawLogPath -Algorithm SHA256).Hash
      $report["observed_success_anchors"] = @(
        "[phase5-candidate-local] status=verified service_count=$($images.Count)"
      )
      $report["raw_evidence"] = [ordered]@{ images = $rawImages }
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
- Rollback target: ``$RollbackTarget``
- Phase 5: $phase5Percent -> $phase5Percent (freshness proof; no new credit)
- Progress credit claimed: false
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
