param(
  [string]$BaseUrl = "http://localhost:8081",
  [string]$ArtifactDir = ".codex\runs\CURRENT\master-goal\phase5\production-candidate-local",
  [switch]$AllowLocalhost,
  [switch]$StaticOnly,
  [switch]$SkipBrowser
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
  Assert-Equal "active release id" $candidateConfig.active_release_id "prod-candidate-2026-07-13-local-rc1"
  Assert-Equal "production rollout claimed" ([bool]$candidateConfig.production_rollout_claimed) $false
  $candidatePath = "docs\release-artifacts\$($candidateConfig.active_release_id).md"
  Assert-True "candidate artifact exists" (Test-Path -LiteralPath $candidatePath)
  $candidate = Get-Content $candidatePath -Raw
  Assert-True "candidate source sha" ($candidate -match '(?m)^source_commit_sha:\s*`([0-9a-f]{40})`\s*$')
  $candidateSourceSha = $Matches[1]
  git cat-file -e "$candidateSourceSha^{commit}" 2>$null
  Assert-True "candidate source commit exists" ($LASTEXITCODE -eq 0)
  git merge-base --is-ancestor $candidateSourceSha HEAD 2>$null
  Assert-True "candidate source is an ancestor of HEAD" ($LASTEXITCODE -eq 0)
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
    Write-Host "[phase5-candidate-local] static checks completed"
    exit 0
  }

  $reportPath = Join-Path $ArtifactDir "candidate-images.json"
  Assert-True "candidate image report exists" (Test-Path -LiteralPath $reportPath)
  $report = Get-Content $reportPath -Raw | ConvertFrom-Json
  Assert-Equal "report contract" $report.contract_version "phase5-production-candidate-local-v1"
  Assert-Equal "report evidence" $report.evidence_ref "phase5_local_production_candidate_verified"
  Assert-Equal "report status" $report.status "verified"
  Assert-Equal "report source" $report.source_commit_sha $candidateSourceSha
  Assert-Equal "report source boundary" $report.source_boundary "committed_git_archive_only"
  Assert-True "archive hash" ([string]$report.git_archive_sha256 -match '^[0-9a-f]{64}$')
  Assert-Equal "service count" ([int]$report.service_count) 6
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

  if (-not $SkipBrowser) {
    $env:PHASE5_CANDIDATE_BASE_URL = $BaseUrl
    $env:PHASE5_CANDIDATE_ARTIFACT_DIR = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $ArtifactDir))
    $env:PHASE6_BASE_URL = $BaseUrl
    npm run test:e2e --prefix apps/frontend -- --project=chromium e2e/phase5-production-candidate.spec.ts
    Assert-True "Playwright candidate proof" ($LASTEXITCODE -eq 0)
  }

  $verification = [ordered]@{
    contract_version = "phase5-production-candidate-local-verification-v1"
    evidence_ref = "phase5_local_production_candidate_verified"
    status = "verified"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    source_commit_sha = $report.source_commit_sha
    service_count = 6
    api_contract_verified = $true
    local_image_identity_verified = $true
    embedded_source_hash_parity_verified = $true
    browser_click_verified = (-not $SkipBrowser)
    registry_publish = $false
    hosted_staging_parity = $false
    production_deploy = $false
    release_promotion = $false
    secret_output = $false
  }
  New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null
  $verification | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $ArtifactDir "verification.json") -Encoding utf8
  Write-Host "[phase5-candidate-local] status=verified service_count=6 browser_click_verified=$(-not $SkipBrowser)"
} finally {
  Pop-Location
}
