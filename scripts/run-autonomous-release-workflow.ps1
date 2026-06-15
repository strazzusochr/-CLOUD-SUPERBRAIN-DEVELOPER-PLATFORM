param(
  [string]$HostedBaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "" }),
  [switch]$Push,
  [switch]$PlanOnly,
  [switch]$AllowNonCandidateHead,
  [switch]$FailFast,
  [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

function Test-HostedBaseUrl([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $false
  }

  if ($Value -notmatch '^https://') {
    return $false
  }

  if ($Value -match 'localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|host\.docker\.internal') {
    return $false
  }

  return $true
}

function Get-TimestampToken {
  return (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
}

function New-StepResult([string]$Id, [string]$Description, [string]$Command) {
  return [ordered]@{
    id = $Id
    description = $Description
    command = $Command
    status = "pending"
    optional = $false
    message = ""
  }
}

function Complete-Step(
  $Step,
  [string]$Status,
  [string]$Message,
  [bool]$Optional = $false
) {
  $Step.status = $Status
  $Step.message = $Message
  $Step.optional = $Optional
}

function Invoke-ExternalStep(
  [System.Collections.Generic.List[object]]$Steps,
  [string]$Id,
  [string]$Description,
  [string]$CommandText,
  [scriptblock]$Action,
  [switch]$Optional
) {
  $step = New-StepResult -Id $Id -Description $Description -Command $CommandText
  $Steps.Add($step)

  if ($PlanOnly) {
    Complete-Step -Step $step -Status "planned" -Message "PlanOnly"
    return $true
  }

  try {
    & $Action
    Complete-Step -Step $step -Status "passed" -Message "ok" -Optional $Optional.IsPresent
    return $true
  } catch {
    Complete-Step -Step $step -Status "failed" -Message $_.Exception.Message -Optional $Optional.IsPresent
    if (-not $Optional.IsPresent -or $FailFast.IsPresent) {
      throw
    }
    return $false
  }
}

function Invoke-PowerShellFile([string]$Path, [string[]]$Arguments = @()) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Path exited with code $LASTEXITCODE"
  }
}

function Invoke-NativeCommand([scriptblock]$Action, [string]$Label) {
  & $Action
  if ($LASTEXITCODE -ne 0) {
    throw "$Label exited with code $LASTEXITCODE"
  }
}

function Get-BoundarySummary {
  $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\verify-worktree-release-boundary.ps1" -JsonOnly -ReportOnly
  if ($LASTEXITCODE -ne 0) {
    throw "verify-worktree-release-boundary.ps1 failed while collecting summary"
  }
  return ($raw | Out-String | ConvertFrom-Json)
}

function Get-CurrentBranch {
  return ((git branch --show-current) | Out-String).Trim()
}

$artifactDirectory = ".phase1-artifacts"
New-Item -ItemType Directory -Force -Path $artifactDirectory | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $artifactDirectory ("autonomous-release-workflow-{0}.json" -f (Get-TimestampToken))
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  $steps = [System.Collections.Generic.List[object]]::new()
  $currentBranch = Get-CurrentBranch
  $headSha = ((git rev-parse HEAD) | Out-String).Trim()
  $hostedEligible = Test-HostedBaseUrl -Value $HostedBaseUrl
  $boundarySummary = $null
  $pushPerformed = $false

  Invoke-ExternalStep -Steps $steps `
    -Id "project-progress-manifest" `
    -Description "Canonical progress manifest validation" `
    -CommandText "py -3 scripts\verify_project_progress_manifest.py" `
    -Action { Invoke-NativeCommand -Label "verify_project_progress_manifest.py" -Action { py -3 scripts\verify_project_progress_manifest.py } } | Out-Null

  Invoke-ExternalStep -Steps $steps `
    -Id "release-boundary-summary" `
    -Description "Worktree release-boundary snapshot" `
    -CommandText "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-worktree-release-boundary.ps1 -JsonOnly -ReportOnly" `
    -Action {
      $boundarySummary = Get-BoundarySummary
      if (-not [bool]$boundarySummary.release_boundary_clear) {
        $blockers = @($boundarySummary.blockers)
        $hardBlockers = @(
          "worktree_is_dirty",
          "unstaged_changes_present",
          "untracked_files_present"
        )
        $hasHardBlocker = ($blockers | Where-Object { $hardBlockers -contains $_ }).Count -gt 0
        if ($hasHardBlocker) {
          throw ("release boundary blocked: {0}" -f ($blockers -join ","))
        }

        if (-not $AllowNonCandidateHead.IsPresent) {
          throw ("release boundary blocked: {0}" -f ($blockers -join ","))
        }
      }
    } | Out-Null

  $boundarySuitesOptional = $AllowNonCandidateHead.IsPresent
  Invoke-ExternalStep -Steps $steps `
    -Id "release-boundary-suite" `
    -Description "Full release-boundary verifier suite" `
    -CommandText "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite release-boundary -FailFast" `
    -Optional:($boundarySuitesOptional) `
    -Action { Invoke-PowerShellFile -Path "scripts\verify.ps1" -Arguments @("-Suite", "release-boundary", "-FailFast") } | Out-Null

  Invoke-ExternalStep -Steps $steps `
    -Id "release-boundary-regression" `
    -Description "Release-boundary regression suite" `
    -CommandText "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite release-boundary-regression -FailFast" `
    -Optional:($boundarySuitesOptional) `
    -Action { Invoke-PowerShellFile -Path "scripts\verify.ps1" -Arguments @("-Suite", "release-boundary-regression", "-FailFast") } | Out-Null

  Invoke-ExternalStep -Steps $steps `
    -Id "frontend-build" `
    -Description "Frontend build proof" `
    -CommandText "npm run build" `
    -Action { Invoke-NativeCommand -Label "npm run build" -Action { npm run build } } | Out-Null

  $runFrontendE2e = (($env:RUN_FRONTEND_E2E | Out-String).Trim() -eq "1")
  if ($runFrontendE2e) {
    Invoke-ExternalStep -Steps $steps `
      -Id "frontend-e2e" `
      -Description "Browser E2E (human-flow) proof" `
      -CommandText "npm run test:e2e --prefix apps/frontend" `
      -Action { Invoke-NativeCommand -Label "npm run test:e2e --prefix apps/frontend" -Action { npm run test:e2e --prefix apps/frontend } } | Out-Null
  } else {
    Invoke-ExternalStep -Steps $steps `
      -Id "frontend-e2e" `
      -Description "Browser E2E (human-flow) proof" `
      -CommandText "Skipped because env:RUN_FRONTEND_E2E is not set to 1" `
      -Optional `
      -Action { throw "Skipped because RUN_FRONTEND_E2E is not set to 1." } | Out-Null
  }

  Invoke-ExternalStep -Steps $steps `
    -Id "phase1-verify" `
    -Description "Repo-wide phase1 verifier" `
    -CommandText "npm run verify" `
    -Action { Invoke-NativeCommand -Label "npm run verify" -Action { npm run verify } } | Out-Null

  Invoke-ExternalStep -Steps $steps `
    -Id "runtime-verify" `
    -Description "Runtime verifier" `
    -CommandText "npm run verify:runtime" `
    -Action { Invoke-NativeCommand -Label "npm run verify:runtime" -Action { npm run verify:runtime } } | Out-Null

  Invoke-ExternalStep -Steps $steps `
    -Id "browser-verify" `
    -Description "Browser contract verifier" `
    -CommandText "npm run verify:browser" `
    -Action { Invoke-NativeCommand -Label "npm run verify:browser" -Action { npm run verify:browser } } | Out-Null

  Invoke-ExternalStep -Steps $steps `
    -Id "external-gates" `
    -Description "External gates baseline verifier" `
    -CommandText "npm run verify:external-gates" `
    -Action { Invoke-NativeCommand -Label "npm run verify:external-gates" -Action { npm run verify:external-gates } } | Out-Null

  if ($hostedEligible) {
    Invoke-ExternalStep -Steps $steps `
      -Id "release-candidate-hosted" `
      -Description "Hosted release-candidate verifier bundle" `
      -CommandText ("powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1 -Suite release-candidate -FailFast -BaseUrl {0}" -f $HostedBaseUrl) `
      -Action { Invoke-PowerShellFile -Path "scripts\verify.ps1" -Arguments @("-Suite", "release-candidate", "-FailFast", "-BaseUrl", $HostedBaseUrl) } | Out-Null
  } else {
    Invoke-ExternalStep -Steps $steps `
      -Id "release-candidate-hosted" `
      -Description "Hosted release-candidate verifier bundle" `
      -CommandText "Skipped because no HTTPS non-localhost HostedBaseUrl is configured" `
      -Optional `
      -Action { throw "Skipped because HostedBaseUrl is missing, non-HTTPS, or localhost." } | Out-Null
  }

  if ($Push.IsPresent) {
    Invoke-ExternalStep -Steps $steps `
      -Id "git-push" `
      -Description "Push current branch after full green workflow" `
      -CommandText "git push" `
      -Action {
        if ($currentBranch -in @("main", "master")) {
          throw "Refusing to push directly from protected branch '$currentBranch'."
        }
        Invoke-NativeCommand -Label "git push" -Action { git push }
        $pushPerformed = $true
      } | Out-Null
  } else {
    Invoke-ExternalStep -Steps $steps `
      -Id "git-push" `
      -Description "Push current branch after full green workflow" `
      -CommandText "Skipped because -Push was not requested" `
      -Optional `
      -Action { throw "Skipped because -Push was not requested." } | Out-Null
  }

  $summary = [ordered]@{
    contract_version = "autonomous-release-workflow-v1"
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    repo_root = $repoRoot
    branch = $currentBranch
    head_sha = $headSha
    hosted_base_url = $HostedBaseUrl
    hosted_release_checks_enabled = $hostedEligible
    push_requested = $Push.IsPresent
    push_performed = $pushPerformed
    plan_only = $PlanOnly.IsPresent
    allow_non_candidate_head = $AllowNonCandidateHead.IsPresent
    release_boundary_clear = if ($null -ne $boundarySummary) { [bool]$boundarySummary.release_boundary_clear } else { $false }
    release_boundary_blockers = if ($null -ne $boundarySummary -and $null -ne $boundarySummary.blockers) { @($boundarySummary.blockers) } else { @() }
    steps = @($steps)
    status = "passed"
    non_claims = @(
      "No production deployment is performed by this workflow.",
      "Hosted release proof remains blocked without a real HTTPS staging URL and reachable backend origins.",
      "A push is performed only when every required step passes and -Push is explicitly requested."
    )
  }

  $summary | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8
  Write-Host ("[autonomous-release-workflow] status=passed artifact={0}" -f $OutputPath)
} catch {
  $failedMessage = $_.Exception.Message
  $summary = [ordered]@{
    contract_version = "autonomous-release-workflow-v1"
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    repo_root = $repoRoot
    branch = $currentBranch
    head_sha = $headSha
    hosted_base_url = $HostedBaseUrl
    hosted_release_checks_enabled = $hostedEligible
    push_requested = $Push.IsPresent
    push_performed = $false
    plan_only = $PlanOnly.IsPresent
    allow_non_candidate_head = $AllowNonCandidateHead.IsPresent
    release_boundary_clear = if ($null -ne $boundarySummary) { [bool]$boundarySummary.release_boundary_clear } else { $false }
    release_boundary_blockers = if ($null -ne $boundarySummary -and $null -ne $boundarySummary.blockers) { @($boundarySummary.blockers) } else { @() }
    steps = @($steps)
    status = "failed"
    failure = $failedMessage
    non_claims = @(
      "No production deployment is performed by this workflow.",
      "No push should be treated as valid release evidence when any required step fails.",
      "Hosted proof is not claimed unless the hosted release-candidate step passes against a real HTTPS staging URL."
    )
  }

  $summary | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8
  Write-Error ("[autonomous-release-workflow] failed: {0}" -f $failedMessage)
  Write-Host ("[autonomous-release-workflow] artifact={0}" -f $OutputPath)
  exit 1
} finally {
  Pop-Location
}
