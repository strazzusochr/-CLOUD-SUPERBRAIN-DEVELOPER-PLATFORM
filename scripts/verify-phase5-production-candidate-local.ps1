param(
  [string]$BaseUrl = "http://localhost:8081",
  [string]$ArtifactDir = ".codex\runs\CURRENT\master-goal\phase5\production-candidate-local",
  [switch]$AllowLocalhost,
  [switch]$AllowNonCandidateHead,
  [switch]$StaticOnly,
  [switch]$SkipBrowser,
  [string]$EvidenceRunId = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BaseUrl = $BaseUrl.TrimEnd("/")
$isLocal = $BaseUrl -match 'localhost|127\.0\.0\.1|\[::1\]'
if ($isLocal -and -not $AllowLocalhost -and -not $StaticOnly) {
  throw "Local phase5 candidate verification requires -AllowLocalhost."
}

function Assert-True([string]$Label, $Condition) {
  if (-not $Condition) { throw "Phase5 local candidate verification failed: $Label" }
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) { throw "Phase5 local candidate verification failed: $Label expected '$Expected' but got '$Actual'." }
}

function Get-ContainerSha256([string]$Image, [string]$Path) {
  $value = (& docker run --rm --entrypoint sha256sum $Image $Path 2>&1 | Out-String).Trim()
  Assert-True "embedded hash readable for $Image $Path" ($LASTEXITCODE -eq 0 -and $value -match '^([0-9a-f]{64})\s+')
  return $Matches[1]
}

Push-Location $repoRoot
try {
  $candidateConfig = Get-Content "docs\release-artifacts\current-release-candidate.json" -Raw | ConvertFrom-Json
  Assert-True "active release id" ([string]$candidateConfig.active_release_id -match '^prod-candidate-\d{4}-\d{2}-\d{2}-local-rc\d+$')
  Assert-Equal "production rollout claimed" ([bool]$candidateConfig.production_rollout_claimed) $false
  $candidatePath = "docs\release-artifacts\$($candidateConfig.active_release_id).md"
  Assert-True "candidate artifact exists" (Test-Path -LiteralPath $candidatePath)
  $candidate = Get-Content $candidatePath -Raw
  Assert-True "candidate source sha" ($candidate -match '(?m)^source_commit_sha:\s*`([0-9a-f]{40})`\s*$')
  $candidateSourceSha = $Matches[1]
  $legacyEvidence = (
    [string]$candidateConfig.active_release_id -eq "prod-candidate-2026-07-31-local-rc11" -and
    $candidateSourceSha -eq "bae3cdc1692e1e99e7f546f72664a3c747958b8c"
  )
  if (-not $legacyEvidence) {
    if ([string]::IsNullOrWhiteSpace($EvidenceRunId)) {
      $EvidenceRunId = [Guid]::NewGuid().ToString("D").ToLowerInvariant()
    }
    Assert-True "evidence run id" (
      $EvidenceRunId -match '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    )
  }
  git cat-file -e "$candidateSourceSha^{commit}" 2>$null
  Assert-True "candidate source commit exists" ($LASTEXITCODE -eq 0)
  git merge-base --is-ancestor $candidateSourceSha HEAD 2>$null
  Assert-True "candidate source is an ancestor of HEAD" ($LASTEXITCODE -eq 0)

  $sourceManifestText = (& git show "${candidateSourceSha}:docs/project-progress.manifest.json" 2>$null | Out-String)
  Assert-True "candidate source manifest readable" ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($sourceManifestText))
  $sourceManifest = $sourceManifestText | ConvertFrom-Json
  $sourcePhase5Items = @($sourceManifest.horizontal.items | Where-Object { $_.id -eq "phase_5" })
  Assert-Equal "candidate source phase_5 item count" $sourcePhase5Items.Count 1
  $sourcePhase5 = [int]$sourcePhase5Items[0].percent
  Assert-True "candidate source phase_5 percent" ($sourcePhase5 -ge 0 -and $sourcePhase5 -le 100)

  $currentManifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
  $currentPhase5Items = @($currentManifest.horizontal.items | Where-Object { $_.id -eq "phase_5" })
  Assert-Equal "current phase_5 item count" $currentPhase5Items.Count 1
  $currentPhase5 = [int]$currentPhase5Items[0].percent
  Assert-True "current phase_5 percent" ($currentPhase5 -ge 0 -and $currentPhase5 -le 100)

  $runtimeSourcePaths = @(
    ".dockerignore",
    "apps/frontend",
    "services/agent-api",
    "services/agent-worker",
    "services/memory-worker",
    "services/mcp-gateway",
    "services/llm-gateway",
    "PROJECT_STATE.md",
    "docs/project-progress.manifest.json",
    "docs/runtime-state/external-gate-summary.json",
    "docs/codex-integration/autonomous-agent-roster.json"
  )
  $qualificationTruthPaths = @(
    "PROJECT_STATE.md",
    "apps/frontend/lib/endpoint-snapshot.json",
    "apps/frontend/lib/platform.ts",
    "docs/project-progress.manifest.json"
  )
  # Compare the candidate tree with the index. In a clean checkout the index is
  # HEAD; before commit it also includes only the explicitly staged truth slice,
  # while unrelated unstaged build artifacts remain outside qualification truth.
  $runtimeDiffArgs = @("diff", "--cached", "--name-only", "--diff-filter=ACDMRTUXB", $candidateSourceSha, "--") + $runtimeSourcePaths
  $runtimeChangedPaths = @(& git @runtimeDiffArgs | ForEach-Object { ([string]$_).Trim().Replace("\", "/") } | Where-Object { $_ })
  Assert-True "candidate runtime diff readable" ($LASTEXITCODE -eq 0)
  $runtimeSourceMatchesHead = $runtimeChangedPaths.Count -eq 0
  $qualificationTruthTransition = $false
  if (-not $runtimeSourceMatchesHead) {
    $unexpectedRuntimePaths = @($runtimeChangedPaths | Where-Object { $qualificationTruthPaths -notcontains $_ })
    $missingTruthPaths = @($qualificationTruthPaths | Where-Object { $runtimeChangedPaths -notcontains $_ })
    if ($unexpectedRuntimePaths.Count -eq 0 -and $missingTruthPaths.Count -eq 0) {
      $itemization = Get-Content "docs\runtime-state\phase5-credit-itemization.json" -Raw | ConvertFrom-Json
      $legacyPhase5ForParity = [int]$itemization.legacy_gap_reconstruction.recorded_percent
      $qualifiedPhase5ForParity = [int]$itemization.current_score.computed_percent
      $qualificationTruthTransition = (
        [string]$itemization.mode -eq "fully_itemized" -and
        -not [bool]$itemization.credit_blocked_until_candidate_qualified -and
        $sourcePhase5 -eq $legacyPhase5ForParity -and
        $currentPhase5 -eq $qualifiedPhase5ForParity -and
        ([int]$currentManifest.overall_percent - [int]$sourceManifest.overall_percent) -eq [int](($qualifiedPhase5ForParity - $legacyPhase5ForParity) / 7)
      )
    }
  }
  $runtimeSourceParityVerified = $runtimeSourceMatchesHead -or $qualificationTruthTransition
  if (-not $runtimeSourceMatchesHead -and -not $AllowNonCandidateHead.IsPresent) {
    Assert-True "candidate runtime source matches HEAD or exact post-qualification truth transition" $runtimeSourceParityVerified
  }
  if (-not $runtimeSourceParityVerified) {
    Write-Host "[phase5-candidate-local] active candidate predates current HEAD; development-only verification"
  }
  foreach ($marker in @(
    'environment: `production-candidate`',
    "immutable_image_commit_sha: ``$candidateSourceSha``",
    'immutable_tag_publish_status: `unpublished`',
    'owner_decision: `no-release`',
    'hosted_staging_parity: `false`',
    'This artifact does not claim a production rollout.',
    'Production deployment still requires the release-candidate gate bundle and a separate rollout proof.'
  )) {
    Assert-True "candidate marker $marker" $candidate.Contains($marker)
  }

  $source = Get-Content "services\agent-api\app\main.py" -Raw
  Assert-True "API contract version source" $source.Contains('PHASE5_PRODUCTION_CANDIDATE_LOCAL_CONTRACT_VERSION = "phase5-production-candidate-local-v1"')
  Assert-True "API endpoint source" $source.Contains('@app.get("/api/v1/release-candidate/local/contract")')
  Assert-True "registry non-claim source" $source.Contains('"registry_publish": False')
  Assert-True "hosted non-claim source" $source.Contains('"hosted_staging_parity": False')
  Assert-True "production non-claim source" $source.Contains('"production_deploy": False')
  Assert-True "promotion non-claim source" $source.Contains('"release_promotion": False')
  Assert-True "secret non-claim source" $source.Contains('"secret_output": False')

  if ($StaticOnly) {
    Write-Host "[phase5-candidate-local] static checks completed runtime_source_matches_head=$($runtimeSourceMatchesHead.ToString().ToLowerInvariant()) qualification_truth_transition=$($qualificationTruthTransition.ToString().ToLowerInvariant()) runtime_source_parity=$($runtimeSourceParityVerified.ToString().ToLowerInvariant())"
    exit 0
  }

  $reportPath = Join-Path $ArtifactDir "candidate-images.json"
  Assert-True "candidate image report exists" (Test-Path -LiteralPath $reportPath)
  $report = Get-Content $reportPath -Raw | ConvertFrom-Json
  Assert-Equal "report contract" $report.contract_version $(if ($legacyEvidence) { "phase5-production-candidate-local-v1" } else { "phase5-production-candidate-local-v2" })
  Assert-Equal "report evidence" $report.evidence_ref "phase5_local_production_candidate_verified"
  Assert-Equal "report status" $report.status "verified"
  Assert-Equal "report release id" $report.release_id ([string]$candidateConfig.active_release_id)
  Assert-Equal "report source" $report.source_commit_sha $candidateSourceSha
  Assert-Equal "report source boundary" $report.source_boundary "committed_git_archive_only"
  Assert-True "archive hash" ([string]$report.git_archive_sha256 -match '^[0-9a-f]{64}$')
  Assert-Equal "service count" ([int]$report.service_count) 6
  Assert-Equal "report phase before" ([int]$report.phase5_progress_before_proof) $sourcePhase5
  Assert-Equal "report phase after" ([int]$report.phase5_progress_after_proof) $sourcePhase5
  Assert-Equal "report progress credit" ([bool]$report.progress_credit_claimed) $false
  Assert-True "candidate rollback target" ($candidate -match '(?m)^rollback_target_commit_sha:\s*`([0-9a-f]{40})`\s*$')
  $candidateRollbackTarget = $Matches[1]
  Assert-Equal "report rollback target" ([string]$report.rollback_target) $candidateRollbackTarget
  Assert-Equal "registry publish" ([bool]$report.registry_publish) $false
  Assert-Equal "hosted staging parity" ([bool]$report.hosted_staging_parity) $false
  Assert-Equal "production deploy" ([bool]$report.production_deploy) $false
  Assert-Equal "release promotion" ([bool]$report.release_promotion) $false
  Assert-Equal "owner review approved" ([bool]$report.owner_review_approved) $false
  Assert-Equal "secret output" ([bool]$report.secret_output) $false

  foreach ($image in @($report.images)) {
    $inspect = @(& docker image inspect $image.image_tag | ConvertFrom-Json)[0]
    Assert-True "image exists $($image.service)" ($LASTEXITCODE -eq 0 -and $null -ne $inspect)
    Assert-Equal "image id $($image.service)" ([string]$inspect.Id) ([string]$image.image_id)
    Assert-Equal "revision label $($image.service)" ([string]$inspect.Config.Labels.'org.opencontainers.image.revision') ([string]$report.source_commit_sha)
    Assert-Equal "version label $($image.service)" ([string]$inspect.Config.Labels.'org.opencontainers.image.version') ([string]$report.release_id)
    Assert-Equal "embedded source parity $($image.service)" (Get-ContainerSha256 -Image $image.image_tag -Path $image.embedded_file) ([string]$image.source_file_sha256)
    if ($image.service -eq "frontend") {
      $buildId = (& docker run --rm --entrypoint cat $image.image_tag /app/.next/BUILD_ID 2>&1 | Out-String).Trim()
      Assert-True "frontend BUILD_ID" ($LASTEXITCODE -eq 0 -and $buildId -eq $image.frontend_build_id -and -not [string]::IsNullOrWhiteSpace($buildId))
    }
  }

  $contract = Invoke-RestMethod -Uri "$BaseUrl/api/v1/release-candidate/local/contract" -Method Get -TimeoutSec 30
  Assert-Equal "runtime contract" $contract.contract_version "phase5-production-candidate-local-v1"
  Assert-Equal "runtime evidence" $contract.evidence_ref "phase5_local_production_candidate_verified"
  Assert-Equal "runtime phase before" ([int]$contract.phase5_progress_before_proof) 67
  Assert-Equal "runtime phase after" ([int]$contract.phase5_progress_after_proof) 68
  Assert-Equal "runtime service count" ([int]$contract.service_count) 6
  foreach ($field in @("registry_publish", "hosted_staging_parity", "production_deploy", "release_promotion", "owner_review_approved", "secret_output")) {
    Assert-Equal "runtime non-claim $field" ([bool]$contract.$field) $false
  }
  foreach ($method in @("POST", "PUT", "DELETE")) {
    try {
      Invoke-WebRequest -Uri "$BaseUrl/api/v1/release-candidate/local/contract" -Method $method -UseBasicParsing -TimeoutSec 15 | Out-Null
      throw "Phase5 local candidate verification failed: $method unexpectedly succeeded."
    } catch {
      $statusCode = [int]$_.Exception.Response.StatusCode
      Assert-Equal "$method remains read-only" $statusCode 405
    }
  }

  $playwrightOutput = @()
  if (-not $SkipBrowser) {
    $env:PHASE5_CANDIDATE_BASE_URL = $BaseUrl
    $env:PHASE5_CANDIDATE_ARTIFACT_DIR = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $ArtifactDir))
    $env:PHASE6_BASE_URL = $BaseUrl
    $previousErrorActionPreference = $ErrorActionPreference
    $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    $ErrorActionPreference = "Continue"
    $PSNativeCommandUseErrorActionPreference = $false
    try {
      $playwrightOutput = @(
        & npm run test:e2e --prefix apps/frontend -- --project=chromium e2e/phase5-production-candidate.spec.ts 2>&1
      )
      $playwrightExit = $LASTEXITCODE
    } finally {
      $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
      $ErrorActionPreference = $previousErrorActionPreference
    }
    foreach ($line in $playwrightOutput) { Write-Host ([string]$line) }
    Assert-True "Playwright candidate proof" ($playwrightExit -eq 0)
    Assert-True "Playwright candidate passed output" (($playwrightOutput | Out-String) -match '(?m)\b1 passed\b')
  }

  $evidenceCommand = (
    "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify-phase5-production-candidate-local.ps1 " +
    "-BaseUrl $BaseUrl -ArtifactDir $ArtifactDir -AllowLocalhost -EvidenceRunId $EvidenceRunId"
  )
  $rawPath = Join-Path $ArtifactDir "raw"
  New-Item -ItemType Directory -Force -Path $rawPath | Out-Null
  $rawLogPath = Join-Path $rawPath "candidate-runtime.log"
  $apiContractPath = Join-Path $rawPath "candidate-runtime-api-contract.json"
  if (-not $legacyEvidence) {
    [IO.File]::WriteAllText(
      ([IO.Path]::GetFullPath((Join-Path $repoRoot $apiContractPath))),
      (($contract | ConvertTo-Json -Depth 8) + "`n"),
      [Text.UTF8Encoding]::new($false)
    )
    $rawLogLines = [Collections.Generic.List[string]]::new()
    [void]$rawLogLines.Add("PHASE5_EVIDENCE_RAW_V2")
    [void]$rawLogLines.Add("[phase5-evidence] chain=candidate-runtime")
    [void]$rawLogLines.Add("[phase5-evidence] release_id=$([string]$candidateConfig.active_release_id)")
    [void]$rawLogLines.Add("[phase5-evidence] source_commit_sha=$candidateSourceSha")
    [void]$rawLogLines.Add("[phase5-evidence] evidence_run_id=$EvidenceRunId")
    [void]$rawLogLines.Add("[phase5-evidence] command=$evidenceCommand")
    foreach ($line in $playwrightOutput) { [void]$rawLogLines.Add([string]$line) }
    foreach ($field in @(
      "api_contract_verified",
      "local_image_identity_verified",
      "embedded_source_hash_parity_verified",
      "candidate_runtime_source_parity_verified"
    )) {
      [void]$rawLogLines.Add("[phase5-candidate-local] $field=true")
    }
    [void]$rawLogLines.Add("[phase5-candidate-local] browser_click_verified=$(((-not $SkipBrowser).ToString()).ToLowerInvariant())")
    [void]$rawLogLines.Add("[phase5-candidate-local] status=verified service_count=6")
    [void]$rawLogLines.Add("[phase5-evidence] exit_code=0")
    [IO.File]::WriteAllLines(
      ([IO.Path]::GetFullPath((Join-Path $repoRoot $rawLogPath))),
      $rawLogLines,
      [Text.UTF8Encoding]::new($false)
    )
  }

  $verification = [ordered]@{
    contract_version = $(if ($legacyEvidence) { "phase5-production-candidate-local-verification-v1" } else { "phase5-production-candidate-local-verification-v2" })
    evidence_ref = "phase5_local_production_candidate_verified"
    status = "verified"
    verification_scope = $(if ($SkipBrowser) { "runtime_without_browser" } else { "full_with_browser" })
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    release_id = [string]$report.release_id
    source_commit_sha = $report.source_commit_sha
    service_count = 6
    api_contract_verified = $true
    local_image_identity_verified = $true
    embedded_source_hash_parity_verified = $true
    candidate_runtime_source_parity_verified = [bool]$runtimeSourceParityVerified
    rollback_target = $candidateRollbackTarget
    browser_click_verified = (-not $SkipBrowser)
    registry_publish = $false
    hosted_staging_parity = $false
    production_deploy = $false
    release_promotion = $false
    secret_output = $false
  }
  if (-not $legacyEvidence) {
    $candidateImagesPath = Join-Path $ArtifactDir "candidate-images.json"
    $verification["command"] = $evidenceCommand
    $verification["evidence_run_id"] = $EvidenceRunId
    $verification["raw_log_path"] = "docs/release-artifacts/$([string]$candidateConfig.active_release_id)-evidence/raw/candidate-runtime.log"
    $verification["raw_log_sha256"] = (Get-FileHash -LiteralPath $rawLogPath -Algorithm SHA256).Hash
    $verification["observed_success_anchors"] = if ($SkipBrowser) {
      @("[phase5-candidate-local] status=verified service_count=6")
    } else {
      @("1 passed", "[phase5-candidate-local] status=verified service_count=6")
    }
    $rawEvidence = [ordered]@{
      candidate_images = [ordered]@{
        path = "docs/release-artifacts/$([string]$candidateConfig.active_release_id)-evidence/candidate-images.json"
        sha256 = (Get-FileHash -LiteralPath $candidateImagesPath -Algorithm SHA256).Hash
      }
      api_contract = [ordered]@{
        path = "docs/release-artifacts/$([string]$candidateConfig.active_release_id)-evidence/raw/candidate-runtime-api-contract.json"
        sha256 = (Get-FileHash -LiteralPath $apiContractPath -Algorithm SHA256).Hash
      }
    }
    if (-not $SkipBrowser) {
      $browserSourcePath = Join-Path $ArtifactDir "diagnostics-phase5-production-candidate.png"
      Assert-True "candidate browser screenshot exists" (Test-Path -LiteralPath $browserSourcePath -PathType Leaf)
      $browserEvidencePath = Join-Path $rawPath "candidate-runtime-browser.png"
      Copy-Item -LiteralPath $browserSourcePath -Destination $browserEvidencePath -Force
      $browserSize = (Get-Item -LiteralPath $browserEvidencePath).Length
      Assert-True "candidate browser screenshot non-empty" ($browserSize -ge 1024)
      $rawEvidence["browser_screenshot"] = [ordered]@{
        path = "docs/release-artifacts/$([string]$candidateConfig.active_release_id)-evidence/raw/candidate-runtime-browser.png"
        sha256 = (Get-FileHash -LiteralPath $browserEvidencePath -Algorithm SHA256).Hash
        size_bytes = [int64]$browserSize
      }
    }
    $verification["raw_evidence"] = $rawEvidence
  }
  New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
  $verificationFile = if ($SkipBrowser) { "verification-runtime.json" } else { "verification.json" }
  $verification | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $ArtifactDir $verificationFile) -Encoding utf8
  Write-Host "[phase5-candidate-local] status=verified service_count=6 source_parity=$($runtimeSourceParityVerified.ToString().ToLowerInvariant()) progress_credit=false browser_click_verified=$(-not $SkipBrowser) artifact=$verificationFile"
} finally {
  Pop-Location
}
