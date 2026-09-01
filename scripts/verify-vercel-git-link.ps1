param(
  [string]$EnvFilePath = (Join-Path $HOME ".codex\secrets\cloud-superbrain.local.env"),
  [string]$VercelProjectJsonPath = "apps\frontend\.vercel\project.json",
  [string]$ExpectedOrg = "strazzusochr",
  [string]$ExpectedRepo = "-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM",
  [string]$ExpectedProductionBranch = "chore/repo-bootstrap",
  [string]$ExpectedRootDirectory = "apps/frontend",
  [string]$OutputPath = ".phase1-artifacts\vercel-git-link-20260513.json",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Set-ProcessEnvIfMissing([string]$Name, [string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Value)) {
    return $false
  }

  $current = [Environment]::GetEnvironmentVariable($Name, "Process")
  if (-not [string]::IsNullOrWhiteSpace($current)) {
    return $false
  }

  [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
  return $true
}

function Invoke-NodeJson([string]$Script) {
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) {
    return [pscustomobject]@{
      status = "blocked"
      classification = "node_unavailable"
      http_status = 0
      checks = @{}
      error = "node command is not available"
    }
  }

  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("vercel-git-link-{0}.js" -f ([guid]::NewGuid().ToString("N")))
  try {
    Set-Content -LiteralPath $tmp -Value $Script -Encoding UTF8
    $raw = & $node.Source $tmp 2>&1 | Out-String
    try {
      return ($raw | ConvertFrom-Json)
    } catch {
      $trimmed = $raw.Trim()
      return [pscustomobject]@{
        status = "blocked"
        classification = "node_probe_non_json"
        http_status = 0
        checks = @{}
        output_excerpt = $trimmed.Substring(0, [Math]::Min(400, $trimmed.Length))
      }
    }
  } finally {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
}

function Write-Report([object]$Report, [string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return
  }

  $parent = Split-Path $Path -Parent
  if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  $Report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  $importLocalEnv = Join-Path $PSScriptRoot "import-local-env.ps1"
  if (Test-Path -LiteralPath $importLocalEnv) {
    & $importLocalEnv -EnvFilePath $EnvFilePath -Quiet
  }

  $projectJsonPresent = Test-Path -LiteralPath $VercelProjectJsonPath
  $projectJson = $null
  if ($projectJsonPresent) {
    $projectJson = Get-Content -LiteralPath $VercelProjectJsonPath -Raw | ConvertFrom-Json
    if ($projectJson.projectId) {
      Set-ProcessEnvIfMissing -Name "VERCEL_PROJECT_ID" -Value ([string]$projectJson.projectId) | Out-Null
    }
    if ($projectJson.orgId) {
      Set-ProcessEnvIfMissing -Name "VERCEL_TEAM_ID" -Value ([string]$projectJson.orgId) | Out-Null
      Set-ProcessEnvIfMissing -Name "VERCEL_ORG_ID" -Value ([string]$projectJson.orgId) | Out-Null
    }
  }

  $tokenPresent = -not [string]::IsNullOrWhiteSpace($env:VERCEL_TOKEN)
  $projectId = [string]$env:VERCEL_PROJECT_ID
  $teamId = if (-not [string]::IsNullOrWhiteSpace($env:VERCEL_TEAM_ID)) { [string]$env:VERCEL_TEAM_ID } else { [string]$env:VERCEL_ORG_ID }

  $nodeScript = @"
const token = process.env.VERCEL_TOKEN || "";
const project = process.env.VERCEL_PROJECT_ID || "";
const team = process.env.VERCEL_TEAM_ID || process.env.VERCEL_ORG_ID || "";
const expected = {
  org: "$ExpectedOrg",
  repo: "$ExpectedRepo",
  productionBranch: "$ExpectedProductionBranch",
  rootDirectory: "$ExpectedRootDirectory"
};

function query(params) {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value) search.set(key, value);
  }
  const rendered = search.toString();
  return rendered ? "?" + rendered : "";
}

function result(status, classification, extra) {
  console.log(JSON.stringify(Object.assign({
    status,
    classification,
    http_status: 0,
    checks: {}
  }, extra || {})));
}

(async () => {
  if (!token) return result("blocked", "missing_vercel_token");
  if (!project) return result("blocked", "missing_vercel_project_id");

  try {
    const response = await fetch(
      "https://api.vercel.com/v9/projects/" + encodeURIComponent(project) + query({ teamId: team }),
      { headers: { Authorization: "Bearer " + token } }
    );
    let body = {};
    try {
      body = await response.json();
    } catch {}

    const link = body && body.link ? body.link : {};
    const observed = {
      id: body && body.id || null,
      name: body && body.name || null,
      framework: body && body.framework || null,
      rootDirectory: body && body.rootDirectory || null,
      linkType: link.type || null,
      linkOrg: link.org || null,
      linkRepo: link.repo || null,
      linkProductionBranch: link.productionBranch || null,
      autoAssignCustomDomains: body && body.autoAssignCustomDomains,
      autoExposeSystemEnvs: body && body.autoExposeSystemEnvs
    };

    const checks = {
      project_readable: response.ok,
      project_id_matches: response.ok && observed.id === project,
      framework_nextjs: response.ok && observed.framework === "nextjs",
      root_directory_matches: response.ok && observed.rootDirectory === expected.rootDirectory,
      link_type_github: response.ok && observed.linkType === "github",
      link_org_matches: response.ok && observed.linkOrg === expected.org,
      link_repo_matches: response.ok && observed.linkRepo === expected.repo,
      production_branch_matches: response.ok && observed.linkProductionBranch === expected.productionBranch
    };

    const ready = Object.values(checks).every(Boolean);
    let classification = ready ? "vercel_git_link_ready" : "vercel_git_link_mismatch";
    if (!response.ok) {
      const errorCode = body && body.error ? body.error.code || "api_error" : "api_error";
      classification = response.status === 401
        ? "token_invalid_or_expired"
        : response.status === 403
          ? "token_forbidden_for_project_or_team"
          : errorCode;
    }

    return result(ready ? "ready" : "blocked", classification, {
      http_status: response.status,
      checks,
      observed,
      error_code: body && body.error ? body.error.code || null : null
    });
  } catch (error) {
    return result("blocked", "vercel_api_unreachable", {
      error: error.message
    });
  }
})();
"@

  $probe = Invoke-NodeJson -Script $nodeScript
  $status = if ($probe.status -eq "ready") { "ready" } else { "blocked" }
  $report = [pscustomobject]@{
    script = "verify-vercel-git-link.ps1"
    status = $status
    classification = [string]$probe.classification
    safe_for_git_auto_deploy = ($status -eq "ready")
    token_present = $tokenPresent
    project_json_present = $projectJsonPresent
    project_id_present = (-not [string]::IsNullOrWhiteSpace($projectId))
    team_id_present = (-not [string]::IsNullOrWhiteSpace($teamId))
    expected = [pscustomobject]@{
      org = $ExpectedOrg
      repo = $ExpectedRepo
      production_branch = $ExpectedProductionBranch
      root_directory = $ExpectedRootDirectory
    }
    observed = $probe.observed
    checks = $probe.checks
    http_status = $probe.http_status
    error_code = $probe.error_code
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
  }

  Write-Report -Report $report -Path $OutputPath

  if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 12
  } else {
    Write-Host "[vercel-git-link] status=$($report.status)"
    Write-Host "[vercel-git-link] classification=$($report.classification)"
    Write-Host "[vercel-git-link] safe_for_git_auto_deploy=$($report.safe_for_git_auto_deploy)"
    Write-Host "[vercel-git-link] http_status=$($report.http_status)"
    if ($report.observed) {
      Write-Host "[vercel-git-link] root_directory=$($report.observed.rootDirectory)"
      Write-Host "[vercel-git-link] git=$($report.observed.linkType)/$($report.observed.linkOrg)/$($report.observed.linkRepo)@$($report.observed.linkProductionBranch)"
    }
  }

  if ($status -eq "ready" -or $ReportOnly) {
    exit 0
  }
  exit 1
} catch {
  $report = [pscustomobject]@{
    script = "verify-vercel-git-link.ps1"
    status = "blocked"
    classification = "script_exception"
    safe_for_git_auto_deploy = $false
    error = $_.Exception.Message
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Report -Report $report -Path $OutputPath
  if ($JsonOnly) {
    $report | ConvertTo-Json -Depth 8
  } else {
    Write-Host "[vercel-git-link] status=blocked"
    Write-Host "[vercel-git-link] classification=script_exception"
    Write-Host "[vercel-git-link] error=$($_.Exception.Message)"
  }
  if ($ReportOnly) {
    exit 0
  }
  exit 1
} finally {
  Pop-Location
}
