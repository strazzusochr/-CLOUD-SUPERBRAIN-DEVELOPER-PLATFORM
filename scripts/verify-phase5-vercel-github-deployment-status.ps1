param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [string]$VercelFrontendUrl = "https://frontend-seven-psi-78.vercel.app",
  [string]$ExpectedRepositorySlug = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
  [string]$ExpectedBranch = "codex/live-agent-steering-ui-20260513",
  [string]$ExpectedVercelTargetPrefix = "https://vercel.com/strazzusochrs-projects/frontend/",
  [string]$CommitSha = "",
  [switch]$AllowLocalhost,
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Assert-Equal($Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) {
    throw "Phase5 Vercel GitHub deployment status verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 Vercel GitHub deployment status verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 Vercel GitHub deployment status verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 Vercel GitHub deployment status verification failed: $Label missing '$Expected'."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 Vercel GitHub deployment status verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 Vercel GitHub deployment status verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Invoke-ProcessProbe([string]$CommandName, [string[]]$Arguments) {
  $command = Get-Command $CommandName -ErrorAction SilentlyContinue
  if (-not $command) {
    throw "$CommandName command is not available."
  }

  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $command.Source @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousPreference
  }

  if ($exitCode -ne 0) {
    $excerpt = $output.Trim()
    if ($excerpt.Length -gt 800) {
      $excerpt = $excerpt.Substring(0, 800)
    }
    throw "$CommandName command failed with exit code $exitCode. Output: $excerpt"
  }

  return $output.Trim()
}

function Invoke-JsonProcess([string]$CommandName, [string[]]$Arguments) {
  $output = Invoke-ProcessProbe -CommandName $CommandName -Arguments $Arguments
  try {
    return ($output | ConvertFrom-Json -ErrorAction Stop)
  } catch {
    throw "$CommandName command did not return parseable JSON."
  }
}

function Invoke-StatusWebRequest([string]$Url) {
  $response = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $Url -TimeoutSec 60
  return [pscustomobject]@{
    status_code = [int]$response.StatusCode
    content = [string]$response.Content
    content_length = ([string]$response.Content).Length
  }
}

function Select-VercelGitLinkSummary($Probe) {
  $domainVerified = $false
  foreach ($domain in @($Probe.observed.domains)) {
    if ([string]$domain.name -eq "frontend-seven-psi-78.vercel.app" -and [bool]$domain.verified) {
      $domainVerified = $true
    }
  }

  return [ordered]@{
    status = [string]$Probe.status
    classification = [string]$Probe.classification
    safe_for_git_auto_deploy = [bool]$Probe.safe_for_git_auto_deploy
    http_status = [int]$Probe.http_status
    framework_nextjs = [bool]$Probe.checks.framework_nextjs
    root_directory_matches = [bool]$Probe.checks.root_directory_matches
    link_type_github = [bool]$Probe.checks.link_type_github
    link_org_matches = [bool]$Probe.checks.link_org_matches
    link_repo_matches = [bool]$Probe.checks.link_repo_matches
    production_branch_matches = [bool]$Probe.checks.production_branch_matches
    domain_verified = $domainVerified
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$tempOutputPaths = @()
Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "BaseUrl is required."
  }
  $BaseUrl = $BaseUrl.TrimEnd("/")
  $VercelFrontendUrl = $VercelFrontendUrl.TrimEnd("/")
  if ((-not $AllowLocalhost) -and ($BaseUrl -notmatch "^https://")) {
    throw "Phase5 Vercel GitHub deployment status requires HTTPS unless -AllowLocalhost is set."
  }

  $configPath = "docs\release-artifacts\current-release-candidate.json"
  Assert-True "current release candidate config exists" (Test-Path -LiteralPath $configPath)
  $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  $activeReleaseId = [string]$config.active_release_id
  if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
    $ReleaseId = $activeReleaseId
  }
  Assert-Equal "release id" $ReleaseId $activeReleaseId
  Assert-False "production rollout claimed" $config.production_rollout_claimed

  $candidatePath = "docs\release-artifacts\$ReleaseId.md"
  Assert-True "active release candidate artifact exists" (Test-Path -LiteralPath $candidatePath)
  $candidate = Get-Content -LiteralPath $candidatePath -Raw
  Assert-Contains "candidate id" $candidate "release_id: ``$ReleaseId``"
  Assert-Contains "candidate environment" $candidate "environment: ``production-candidate``"
  Assert-Contains "candidate image build branch" $candidate "image_build_branch: ``$ExpectedBranch``"
  Assert-Contains "candidate non-claim" $candidate "This artifact does not claim a production rollout."
  Assert-Contains "candidate Vercel proof link" $candidate "vercel_github_deployment_status_proof: ``docs/release-artifacts/$ReleaseId-vercel-github-deployment-status-20260514.md``"
  Assert-NotSecretBearing "candidate artifact" $candidate

  $proofPath = "docs\release-artifacts\$ReleaseId-vercel-github-deployment-status-20260514.md"
  Assert-True "Vercel GitHub deployment proof exists" (Test-Path -LiteralPath $proofPath)
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "production_rollout_claimed: ``false``",
    "github_status_context: ``Vercel``",
    "github_status_state: ``success``",
    "vercel_frontend_url: ``$VercelFrontendUrl/``",
    "hosted_staging_url: ``$BaseUrl/``",
    "This proof does not claim a production rollout.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "Vercel proof artifact" $proof $required
  }
  Assert-NotSecretBearing "Vercel proof artifact" $proof

  $currentBranch = Invoke-ProcessProbe "git" @("branch", "--show-current")
  Assert-Equal "current branch" $currentBranch $ExpectedBranch

  if ([string]::IsNullOrWhiteSpace($CommitSha)) {
    $CommitSha = Invoke-ProcessProbe "git" @("rev-parse", "HEAD")
  }
  Assert-Sha "commit sha" $CommitSha

  $gitStatus = Invoke-ProcessProbe "git" @("status", "--short")
  $worktreeHasChanges = -not [string]::IsNullOrWhiteSpace($gitStatus)

  $projectReadinessOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("phase5-vercel-project-readiness-{0}.json" -f ([guid]::NewGuid().ToString("N")))
  $tempOutputPaths += $projectReadinessOutputPath
  $projectReadiness = Invoke-JsonProcess "powershell" @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "scripts\verify-vercel-project-git-readiness.ps1",
    "-RequireBranchUpstream",
    "-ReportOnly",
    "-JsonOnly",
    "-OutputPath",
    $projectReadinessOutputPath
  )
  Assert-Equal "Vercel project git readiness status" ([string]$projectReadiness.status) "ready"
  Assert-True "Vercel project git readiness boolean" ([bool]$projectReadiness.ready)
  Assert-Equal "Vercel project git readiness blocking failures" ([int]$projectReadiness.blocking_failure_count) 0

  $gitLinkOutputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("phase5-vercel-git-link-{0}.json" -f ([guid]::NewGuid().ToString("N")))
  $tempOutputPaths += $gitLinkOutputPath
  $gitLinkRaw = Invoke-JsonProcess "powershell" @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "scripts\verify-vercel-git-link.ps1",
    "-ReportOnly",
    "-JsonOnly",
    "-OutputPath",
    $gitLinkOutputPath
  )
  $gitLink = Select-VercelGitLinkSummary $gitLinkRaw
  Assert-Equal "Vercel Git link status" ([string]$gitLink.status) "ready"
  Assert-Equal "Vercel Git link classification" ([string]$gitLink.classification) "vercel_git_link_ready"
  Assert-True "Vercel Git link auto deploy safe" ([bool]$gitLink.safe_for_git_auto_deploy)
  Assert-True "Vercel frontend domain verified" ([bool]$gitLink.domain_verified)

  $combinedStatus = Invoke-JsonProcess "gh" @(
    "api",
    "repos/$ExpectedRepositorySlug/commits/$CommitSha/status"
  )
  Assert-Equal "combined GitHub status" ([string]$combinedStatus.state) "success"
  $vercelStatuses = @($combinedStatus.statuses | Where-Object {
    $_.context -eq "Vercel" -and
    $_.state -eq "success" -and
    ([string]$_.target_url).StartsWith($ExpectedVercelTargetPrefix, [System.StringComparison]::Ordinal)
  })
  Assert-True "successful Vercel status context present" ($vercelStatuses.Count -ge 1)
  $vercelStatus = $vercelStatuses | Select-Object -First 1

  $frontendResponse = Invoke-StatusWebRequest "$VercelFrontendUrl/"
  Assert-Equal "Vercel frontend HTTP status" $frontendResponse.status_code 200
  Assert-Contains "Vercel frontend title" $frontendResponse.content "<title>Cloud Superbrain</title>"
  Assert-NotSecretBearing "Vercel frontend content" $frontendResponse.content

  $hostedResponse = Invoke-StatusWebRequest "$BaseUrl/"
  Assert-Equal "hosted staging HTTP status" $hostedResponse.status_code 200
  Assert-Contains "hosted staging content" $hostedResponse.content "Cloud Superbrain"
  Assert-NotSecretBearing "hosted staging content" $hostedResponse.content

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    branch = $currentBranch
    commit_sha = $CommitSha
    worktree_has_changes = $worktreeHasChanges
    github_combined_status = [string]$combinedStatus.state
    github_status_context = "Vercel"
    github_status_state = [string]$vercelStatus.state
    github_status_target_url = [string]$vercelStatus.target_url
    vercel_frontend_url = "$VercelFrontendUrl/"
    vercel_frontend_status_code = $frontendResponse.status_code
    hosted_staging_url = "$BaseUrl/"
    hosted_staging_status_code = $hostedResponse.status_code
    vercel_project_git_readiness = [ordered]@{
      status = [string]$projectReadiness.status
      classification = [string]$projectReadiness.classification
      blocking_failure_count = [int]$projectReadiness.blocking_failure_count
    }
    vercel_git_link = $gitLink
    production_rollout_claimed = $false
    policy = [ordered]@{
      mutates_production = $false
      deploys_production = $false
      claims_rollout = $false
      reads_secret_values = $false
      includes_secrets = $false
      live_provider_calls_claimed = $false
      live_mcp_writes_claimed = $false
    }
  }
  Assert-NotSecretBearing "summary" ($summary | ConvertTo-Json -Depth 8 -Compress)

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 8
  } else {
    Write-Host "[phase5-vercel-github-deployment-status] verified"
    Write-Host "[phase5-vercel-github-deployment-status] release_id=$ReleaseId"
    Write-Host "[phase5-vercel-github-deployment-status] github_status_context=Vercel"
    Write-Host "[phase5-vercel-github-deployment-status] vercel_frontend_status_code=$($frontendResponse.status_code)"
  }
} catch {
  if ($ReportOnly) {
    $summary = [ordered]@{
      status = "failed"
      passed = $false
      release_id = $ReleaseId
      error = $_.Exception.Message
      production_rollout_claimed = $false
    }
    if ($JsonOnly) {
      $summary | ConvertTo-Json -Depth 4
    } else {
      Write-Host "[phase5-vercel-github-deployment-status] failed"
      Write-Host "[phase5-vercel-github-deployment-status] error=$($_.Exception.Message)"
    }
    exit 0
  }
  throw
} finally {
  foreach ($path in $tempOutputPaths) {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
  }
  Pop-Location
}
