param(
  [string]$VercelProjectJsonPath = "apps\frontend\.vercel\project.json",
  [string]$FrontendPackageJsonPath = "apps\frontend\package.json",
  [string]$ExpectedRepositorySlug = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
  [string]$OutputPath = ".phase1-artifacts\vercel-project-git-readiness-20260513.json",
  [switch]$RequireBranchUpstream,
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function New-Check(
  [string]$Id,
  [string]$Status,
  [bool]$Blocking,
  [string]$Expected,
  [string]$Actual,
  [string]$RequiredFix
) {
  return [pscustomobject]@{
    id = $Id
    status = $Status
    blocking = $Blocking
    expected = $Expected
    actual = $Actual
    required_fix = $RequiredFix
  }
}

function Invoke-ProcessProbe([string]$CommandName, [string[]]$Arguments) {
  $command = Get-Command $CommandName -ErrorAction SilentlyContinue
  if (-not $command) {
    return [pscustomobject]@{
      available = $false
      exit_code = 127
      output = "$CommandName command is not available"
    }
  }

  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $command.Source @Arguments 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } catch {
    $output = $_.Exception.Message
    $exitCode = 1
  } finally {
    $ErrorActionPreference = $previousPreference
  }

  return [pscustomobject]@{
    available = $true
    exit_code = $exitCode
    output = ($output | Out-String).Trim()
  }
}

function Normalize-FullPath([string]$Path) {
  return ([System.IO.Path]::GetFullPath($Path)).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-RepoRelativePath([string]$RepoRoot, [string]$Path) {
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return Normalize-FullPath $Path
  }

  return Normalize-FullPath (Join-Path $RepoRoot $Path)
}

function Test-PathInsideRepo([string]$RepoRoot, [string]$Path) {
  $root = Normalize-FullPath $RepoRoot
  $candidate = Resolve-RepoRelativePath -RepoRoot $root -Path $Path
  return $candidate.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

function Read-JsonFile([string]$Path) {
  try {
    return [pscustomobject]@{
      ok = $true
      value = (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop)
      error = ""
    }
  } catch {
    return [pscustomobject]@{
      ok = $false
      value = $null
      error = $_.Exception.Message
    }
  }
}

function Get-JsonPropertyValue([object]$Json, [string]$Name) {
  if ($null -eq $Json -or @($Json.PSObject.Properties.Name) -notcontains $Name) {
    return ""
  }

  return [string]$Json.$Name
}

function ConvertTo-RemoteInfo([string]$Url) {
  $trimmed = $Url.Trim()
  $hostName = ""
  $path = ""
  $credentialed = $false

  if ($trimmed -match '^https://') {
    try {
      $uri = [System.Uri]$trimmed
      $hostName = $uri.Host
      $path = $uri.AbsolutePath.TrimStart("/")
      $credentialed = -not [string]::IsNullOrWhiteSpace($uri.UserInfo)
    } catch {
      $hostName = ""
      $path = ""
      $credentialed = ($trimmed -match '@')
    }
  } elseif ($trimmed -match '^ssh://git@([^/]+)/(.+)$') {
    $hostName = $Matches[1]
    $path = $Matches[2]
  } elseif ($trimmed -match '^git@([^:]+):(.+)$') {
    $hostName = $Matches[1]
    $path = $Matches[2]
  }

  if ($path.EndsWith(".git", [System.StringComparison]::OrdinalIgnoreCase)) {
    $path = $path.Substring(0, $path.Length - 4)
  }

  $parts = @($path -split "/" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $owner = if ($parts.Count -ge 2) { $parts[0] } else { "" }
  $repo = if ($parts.Count -ge 2) { $parts[1] } else { "" }

  return [pscustomobject]@{
    host = $hostName
    owner = $owner
    repo = $repo
    slug = if ($owner -and $repo) { "$owner/$repo" } else { "" }
    credentialed = $credentialed
    parseable = (-not [string]::IsNullOrWhiteSpace($hostName) -and -not [string]::IsNullOrWhiteSpace($owner) -and -not [string]::IsNullOrWhiteSpace($repo))
  }
}

function Add-Check([System.Collections.Generic.List[object]]$Checks, [object]$Check) {
  $Checks.Add($Check) | Out-Null
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  $checks = [System.Collections.Generic.List[object]]::new()
  $repoRootFull = Normalize-FullPath $repoRoot

  $gitAvailable = [bool](Get-Command git -ErrorAction SilentlyContinue)
  Add-Check $checks (New-Check "git_cli_available" $(if ($gitAvailable) { "ready" } else { "blocked" }) $true "git command available" "available=$gitAvailable" "Install Git and ensure it is on PATH.")

  $gitRoot = ""
  if ($gitAvailable) {
    $gitRootProbe = Invoke-ProcessProbe "git" @("rev-parse", "--show-toplevel")
    if ($gitRootProbe.exit_code -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRootProbe.output)) {
      $gitRoot = Normalize-FullPath $gitRootProbe.output
    }
    Add-Check $checks (New-Check "git_repo_root" $(if ($gitRoot -eq $repoRootFull) { "ready" } else { "blocked" }) $true "script runs from repository root" "git_root=$gitRoot" "Run the verifier from the repository checkout.")
  }

  $projectPathInsideRepo = Test-PathInsideRepo -RepoRoot $repoRootFull -Path $VercelProjectJsonPath
  Add-Check $checks (New-Check "vercel_project_json_path_scoped" $(if ($projectPathInsideRepo) { "ready" } else { "blocked" }) $true "project json path stays inside repo" "path_inside_repo=$projectPathInsideRepo" "Use a repo-relative Vercel project JSON path.")

  $projectJsonFullPath = Resolve-RepoRelativePath -RepoRoot $repoRootFull -Path $VercelProjectJsonPath
  $projectJsonPresent = $projectPathInsideRepo -and (Test-Path -LiteralPath $projectJsonFullPath)
  Add-Check $checks (New-Check "vercel_project_json_present" $(if ($projectJsonPresent) { "ready" } else { "blocked" }) $true "apps/frontend/.vercel/project.json exists" "present=$projectJsonPresent" "Relink the frontend directory with Vercel, without committing secrets.")

  $projectJson = $null
  $projectJsonParseable = $false
  if ($projectJsonPresent) {
    $projectJsonProbe = Read-JsonFile -Path $projectJsonFullPath
    $projectJson = $projectJsonProbe.value
    $projectJsonParseable = $projectJsonProbe.ok
    Add-Check $checks (New-Check "vercel_project_json_parseable" $(if ($projectJsonParseable) { "ready" } else { "blocked" }) $true "valid JSON" $(if ($projectJsonParseable) { "parseable=true" } else { "parseable=false; error=$($projectJsonProbe.error)" }) "Regenerate the Vercel project link file with the Vercel CLI.")
  } else {
    Add-Check $checks (New-Check "vercel_project_json_parseable" "blocked" $true "valid JSON" "parseable=false" "Restore the Vercel project link file first.")
  }

  $projectId = Get-JsonPropertyValue -Json $projectJson -Name "projectId"
  $orgId = Get-JsonPropertyValue -Json $projectJson -Name "orgId"
  $projectName = Get-JsonPropertyValue -Json $projectJson -Name "projectName"
  $projectIdShapeOk = $projectId -match '^prj_[A-Za-z0-9]+$'
  $orgIdShapeOk = $orgId -match '^(team|user)_[A-Za-z0-9]+$'
  $projectNamePresent = -not [string]::IsNullOrWhiteSpace($projectName)

  Add-Check $checks (New-Check "vercel_project_id_shape" $(if ($projectIdShapeOk) { "ready" } else { "blocked" }) $true "projectId uses prj_ identifier shape" "project_id_present=$(-not [string]::IsNullOrWhiteSpace($projectId)); shape_valid=$projectIdShapeOk" "Relink to a valid Vercel project.")
  Add-Check $checks (New-Check "vercel_org_id_shape" $(if ($orgIdShapeOk) { "ready" } else { "blocked" }) $true "orgId uses team_ or user_ identifier shape" "org_id_present=$(-not [string]::IsNullOrWhiteSpace($orgId)); shape_valid=$orgIdShapeOk" "Relink to the intended Vercel team or user scope.")
  Add-Check $checks (New-Check "vercel_project_name_present" $(if ($projectNamePresent) { "ready" } else { "blocked" }) $true "projectName is present" "project_name_present=$projectNamePresent" "Relink the project so projectName is recorded.")

  $secretLikeProjectKeys = @()
  if ($projectJsonParseable) {
    $secretLikeProjectKeys = @($projectJson.PSObject.Properties.Name | Where-Object { $_ -match '(?i)(token|secret|password|credential|private|auth|key)' })
  }
  Add-Check $checks (New-Check "vercel_project_json_no_secret_keys" $(if ($secretLikeProjectKeys.Count -eq 0) { "ready" } else { "blocked" }) $true "no secret-like keys in project.json" "secret_like_key_count=$($secretLikeProjectKeys.Count)" "Remove secret-like values from project.json and rotate anything that may have leaked.")

  if ($gitAvailable) {
    $trackedProbe = Invoke-ProcessProbe "git" @("ls-files", "--error-unmatch", "--", $VercelProjectJsonPath)
    $projectJsonTracked = ($trackedProbe.exit_code -eq 0)
    Add-Check $checks (New-Check "vercel_project_json_untracked" $(if (-not $projectJsonTracked) { "ready" } else { "blocked" }) $true ".vercel project link is not tracked" "tracked=$projectJsonTracked" "Remove apps/frontend/.vercel from Git tracking and keep it ignored.")

    $ignoredProbe = Invoke-ProcessProbe "git" @("check-ignore", "-q", "--", $VercelProjectJsonPath)
    $projectJsonIgnored = ($ignoredProbe.exit_code -eq 0)
    Add-Check $checks (New-Check "vercel_project_json_ignored" $(if ($projectJsonIgnored) { "ready" } else { "blocked" }) $true ".vercel project link is ignored" "ignored=$projectJsonIgnored" "Add .vercel to apps/frontend/.gitignore.")
  }

  $frontendPathInsideRepo = Test-PathInsideRepo -RepoRoot $repoRootFull -Path $FrontendPackageJsonPath
  $frontendPackagePath = Resolve-RepoRelativePath -RepoRoot $repoRootFull -Path $FrontendPackageJsonPath
  $frontendPackagePresent = $frontendPathInsideRepo -and (Test-Path -LiteralPath $frontendPackagePath)
  Add-Check $checks (New-Check "frontend_package_json_present" $(if ($frontendPackagePresent) { "ready" } else { "blocked" }) $true "frontend package.json exists" "present=$frontendPackagePresent" "Restore apps/frontend/package.json.")

  $frontendPackage = $null
  if ($frontendPackagePresent) {
    $frontendPackageProbe = Read-JsonFile -Path $frontendPackagePath
    $frontendPackage = $frontendPackageProbe.value
    Add-Check $checks (New-Check "frontend_package_json_parseable" $(if ($frontendPackageProbe.ok) { "ready" } else { "blocked" }) $true "valid frontend package JSON" $(if ($frontendPackageProbe.ok) { "parseable=true" } else { "parseable=false; error=$($frontendPackageProbe.error)" }) "Fix apps/frontend/package.json syntax.")
  } else {
    Add-Check $checks (New-Check "frontend_package_json_parseable" "blocked" $true "valid frontend package JSON" "parseable=false" "Restore apps/frontend/package.json first.")
  }

  $buildScript = Get-JsonPropertyValue -Json $frontendPackage.scripts -Name "build"
  $nextDependency = Get-JsonPropertyValue -Json $frontendPackage.dependencies -Name "next"
  $buildScriptPresent = -not [string]::IsNullOrWhiteSpace($buildScript)
  $nextDependencyPresent = -not [string]::IsNullOrWhiteSpace($nextDependency)
  Add-Check $checks (New-Check "frontend_build_script_present" $(if ($buildScriptPresent) { "ready" } else { "blocked" }) $true "frontend build script exists" "build_script_present=$buildScriptPresent" "Add a production build script for Vercel.")
  Add-Check $checks (New-Check "frontend_next_dependency_present" $(if ($nextDependencyPresent) { "ready" } else { "blocked" }) $true "Next.js dependency exists" "next_dependency_present=$nextDependencyPresent" "Add Next.js as a frontend dependency.")

  $remoteUrl = ""
  $remoteInfo = [pscustomobject]@{ parseable = $false; host = ""; slug = ""; owner = ""; repo = "" }
  if ($gitAvailable) {
    $remoteProbe = Invoke-ProcessProbe "git" @("config", "--get", "remote.origin.url")
    if ($remoteProbe.exit_code -eq 0) {
      $remoteUrl = $remoteProbe.output
      $remoteInfo = ConvertTo-RemoteInfo -Url $remoteUrl
    }
    Add-Check $checks (New-Check "git_origin_remote_present" $(if (-not [string]::IsNullOrWhiteSpace($remoteUrl)) { "ready" } else { "blocked" }) $true "remote.origin.url is configured" "present=$(-not [string]::IsNullOrWhiteSpace($remoteUrl))" "Configure the canonical GitHub origin remote.")
    Add-Check $checks (New-Check "git_origin_remote_no_userinfo" $(if (-not $remoteInfo.credentialed) { "ready" } else { "blocked" }) $true "origin remote does not embed credentials" "credentialed=$($remoteInfo.credentialed)" "Remove credentials from remote.origin.url and rotate any exposed token.")
    Add-Check $checks (New-Check "git_origin_remote_parseable" $(if ($remoteInfo.parseable) { "ready" } else { "blocked" }) $true "origin remote is parseable" "parseable=$($remoteInfo.parseable); host=$($remoteInfo.host)" "Use an HTTPS or SSH GitHub remote URL.")

    $githubHostOk = $remoteInfo.host -eq "github.com"
    Add-Check $checks (New-Check "git_origin_remote_host" $(if ($githubHostOk) { "ready" } else { "blocked" }) $true "origin host is github.com" "host=$($remoteInfo.host)" "Point origin to the canonical GitHub repository.")

    $slugOk = if ([string]::IsNullOrWhiteSpace($ExpectedRepositorySlug)) { $remoteInfo.parseable } else { $remoteInfo.slug -eq $ExpectedRepositorySlug }
    Add-Check $checks (New-Check "git_origin_remote_slug" $(if ($slugOk) { "ready" } else { "blocked" }) $true "origin slug matches expected repository" "slug=$($remoteInfo.slug)" "Set origin to the canonical repository slug.")

    $branchProbe = Invoke-ProcessProbe "git" @("branch", "--show-current")
    $currentBranch = if ($branchProbe.exit_code -eq 0) { $branchProbe.output } else { "" }
    $branchPresent = -not [string]::IsNullOrWhiteSpace($currentBranch)
    Add-Check $checks (New-Check "git_current_branch_present" $(if ($branchPresent) { "ready" } else { "blocked" }) $true "checkout is on a named branch" "branch_present=$branchPresent" "Checkout a named branch before using Git-backed Vercel workflows.")

    $upstreamProbe = Invoke-ProcessProbe "git" @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
    $upstream = if ($upstreamProbe.exit_code -eq 0) { $upstreamProbe.output } else { "" }
    $upstreamPresent = -not [string]::IsNullOrWhiteSpace($upstream)
    $upstreamStatus = if ($upstreamPresent) { "ready" } elseif ($RequireBranchUpstream) { "blocked" } else { "warning" }
    Add-Check $checks (New-Check "git_upstream_present" $upstreamStatus ([bool]$RequireBranchUpstream) "current branch has upstream" "upstream_present=$upstreamPresent" "Set the current branch upstream to origin before push/deploy operations.")

    $upstreamOriginOk = $upstream.StartsWith("origin/", [System.StringComparison]::Ordinal)
    $upstreamOriginStatus = if ($upstreamOriginOk) { "ready" } elseif ($RequireBranchUpstream) { "blocked" } else { "warning" }
    Add-Check $checks (New-Check "git_upstream_uses_origin" $upstreamOriginStatus ([bool]$RequireBranchUpstream) "upstream uses origin remote" "upstream=$upstream" "Track the branch from origin before push/deploy operations.")

    $branchRemoteProbe = Invoke-ProcessProbe "git" @("config", "--get", "branch.$currentBranch.remote")
    $branchRemote = if ($branchRemoteProbe.exit_code -eq 0) { $branchRemoteProbe.output } else { "" }
    $branchRemoteStatus = if ($branchRemote -eq "origin") { "ready" } elseif ($RequireBranchUpstream) { "blocked" } else { "warning" }
    Add-Check $checks (New-Check "git_branch_remote_origin" $branchRemoteStatus ([bool]$RequireBranchUpstream) "branch remote is origin" "branch_remote=$branchRemote" "Set branch remote to origin before push/deploy operations.")

    $fetchProbe = Invoke-ProcessProbe "git" @("config", "--get-all", "remote.origin.fetch")
    $fetchRefspec = if ($fetchProbe.exit_code -eq 0) { $fetchProbe.output } else { "" }
    $fetchRefspecOk = $fetchRefspec.Contains("refs/heads/*:refs/remotes/origin/*")
    Add-Check $checks (New-Check "git_origin_fetch_refspec" $(if ($fetchRefspecOk) { "ready" } else { "blocked" }) $true "origin fetches branch refs" "fetch_refspec_ok=$fetchRefspecOk" "Restore the standard origin fetch refspec.")
  }

  $blockingFailures = @($checks | Where-Object { $_.blocking -and $_.status -ne "ready" })
  $warnings = @($checks | Where-Object { $_.status -eq "warning" })
  $ready = ($blockingFailures.Count -eq 0)
  $classification = if ($ready) {
    "project_link_git_config_ready"
  } elseif (-not $projectJsonPresent) {
    "missing_vercel_project_link"
  } elseif (-not $projectIdShapeOk -or -not $orgIdShapeOk) {
    "invalid_vercel_project_link"
  } elseif ($remoteInfo.parseable -and $remoteInfo.host -ne "github.com") {
    "git_remote_not_github"
  } elseif ($remoteInfo.credentialed) {
    "git_remote_contains_credentials"
  } elseif ($remoteInfo.parseable -and -not [string]::IsNullOrWhiteSpace($ExpectedRepositorySlug) -and $remoteInfo.slug -ne $ExpectedRepositorySlug) {
    "git_remote_slug_mismatch"
  } else {
    "project_link_git_config_blocked"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = if ($ready) { "ready" } else { "blocked" }
    ready = $ready
    classification = $classification
    blocking_failure_count = $blockingFailures.Count
    blocking_failures = @($blockingFailures | ForEach-Object { $_.id })
    warning_count = $warnings.Count
    warnings = @($warnings | ForEach-Object { $_.id })
    vercel_project_git_ready = $ready
    project_json = [ordered]@{
      path = $VercelProjectJsonPath
      present = $projectJsonPresent
      parseable = $projectJsonParseable
      project_id_present = -not [string]::IsNullOrWhiteSpace($projectId)
      org_id_present = -not [string]::IsNullOrWhiteSpace($orgId)
      project_name_present = $projectNamePresent
      secret_like_key_count = $secretLikeProjectKeys.Count
    }
    git = [ordered]@{
      command_available = $gitAvailable
      root = $gitRoot
      origin_host = $remoteInfo.host
      origin_slug = $remoteInfo.slug
      expected_slug = $ExpectedRepositorySlug
      upstream = $upstream
      branch_upstream_required = [bool]$RequireBranchUpstream
    }
    frontend = [ordered]@{
      package_json_path = $FrontendPackageJsonPath
      package_json_present = $frontendPackagePresent
      build_script_present = $buildScriptPresent
      next_dependency_present = $nextDependencyPresent
    }
    checks = @($checks)
    policy = [ordered]@{
      mutates_repository = $false
      reads_secret_files = $false
      reads_env_values = $false
      calls_vercel_api = $false
      calls_git_network = $false
      may_deploy = $false
      may_release = $false
    }
    leak_prevention = [ordered]@{
      file_contents_included = $false
      secret_values_included = $false
      tokens_included = $false
      env_values_included = $false
      project_id_value_included = $false
      org_id_value_included = $false
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputParent = Split-Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
      New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  }

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 8
  } else {
    Write-Host "[vercel-project-git-readiness] status=$($summary.status)"
    Write-Host "[vercel-project-git-readiness] classification=$($summary.classification)"
    Write-Host "[vercel-project-git-readiness] vercel_project_git_ready=$($summary.vercel_project_git_ready)"
    Write-Host "[vercel-project-git-readiness] blocking_failure_count=$($summary.blocking_failure_count)"
    if ($blockingFailures.Count -gt 0) {
      Write-Host "[vercel-project-git-readiness] blocking_failures=$($summary.blocking_failures -join ',')"
    }
  }

  if (-not $ready -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}
