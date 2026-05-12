param(
  [string]$EnvFilePath = (Join-Path $HOME ".codex\secrets\cloud-superbrain.local.env"),
  [string]$VercelProjectJsonPath = "apps\frontend\.vercel\project.json",
  [string]$OutputPath = "",
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
      status = "failed"
      classification = "node_unavailable"
      probes = @()
      error = "node command is not available"
    }
  }

  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("vercel-access-{0}.js" -f ([guid]::NewGuid().ToString("N")))
  try {
    Set-Content -LiteralPath $tmp -Value $Script -Encoding UTF8
    $raw = & $node.Source $tmp 2>&1 | Out-String
    try {
      return ($raw | ConvertFrom-Json)
    } catch {
      $trimmed = $raw.Trim()
      return [pscustomobject]@{
        status = "failed"
        classification = "node_probe_non_json"
        probes = @()
        output_excerpt = $trimmed.Substring(0, [Math]::Min(400, $trimmed.Length))
      }
    }
  } finally {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
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
  $projectName = if ($projectJson -and $projectJson.projectName) { [string]$projectJson.projectName } else { "" }

  $probe = Invoke-NodeJson @'
const token = process.env.VERCEL_TOKEN || "";
const project = process.env.VERCEL_PROJECT_ID || "";
const team = process.env.VERCEL_TEAM_ID || process.env.VERCEL_ORG_ID || "";
const projectName = process.env.VERCEL_PROJECT_NAME || "";
const base = "https://api.vercel.com";

function query(params) {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value) search.set(key, value);
  }
  const rendered = search.toString();
  return rendered ? "?" + rendered : "";
}

async function request(label, path) {
  if (!token) {
    return {
      label,
      skipped: true,
      ok: false,
      http_status: 0,
      error_code: "missing_token"
    };
  }
  try {
    const response = await fetch(base + path, {
      headers: { Authorization: "Bearer " + token }
    });
    let body = {};
    try {
      body = await response.json();
    } catch {}
    const projects = Array.isArray(body.projects) ? body.projects : [];
    const envs = Array.isArray(body.envs) ? body.envs : [];
    return {
      label,
      ok: response.ok,
      http_status: response.status,
      error_code: body && body.error ? body.error.code || null : null,
      project_id_matches: body && body.id === project,
      project_name_matches: Boolean(projectName && body && body.name === projectName),
      project_name_present: Boolean(body && body.name),
      project_found_in_list: projects.some((item) => item && item.id === project),
      project_name_found_in_list: Boolean(projectName && projects.some((item) => item && item.name === projectName)),
      project_count: projects.length,
      env_count: envs.length
    };
  } catch (error) {
    return {
      label,
      ok: false,
      http_status: 0,
      error_code: "network_error",
      error: error.message
    };
  }
}

(async () => {
  const probes = [];

  if (!token || !project) {
    const classification = !token ? "missing_vercel_token" : "missing_vercel_project_id";
    console.log(JSON.stringify({
      status: "blocked",
      classification,
      probes,
      project_read_verified: false,
      safe_to_deploy_via_vercel: false
    }));
    return;
  }

  probes.push(await request("project_with_team", "/v9/projects/" + encodeURIComponent(project) + query({ teamId: team })));
  probes.push(await request("project_without_team", "/v9/projects/" + encodeURIComponent(project)));
  probes.push(await request("projects_with_team", "/v9/projects" + query({ teamId: team, limit: "100" })));
  probes.push(await request("projects_without_team", "/v9/projects" + query({ limit: "100" })));

  const projectWithTeam = probes.find((item) => item.label === "project_with_team");
  const projectWithoutTeam = probes.find((item) => item.label === "project_without_team");
  const listWithTeam = probes.find((item) => item.label === "projects_with_team");
  const listWithoutTeam = probes.find((item) => item.label === "projects_without_team");
  const projectReadVerified = Boolean((projectWithTeam && projectWithTeam.ok && projectWithTeam.project_id_matches) || (projectWithoutTeam && projectWithoutTeam.ok && projectWithoutTeam.project_id_matches));
  const foundInTeamList = Boolean(listWithTeam && listWithTeam.ok && listWithTeam.project_found_in_list);
  const foundInUserList = Boolean(listWithoutTeam && listWithoutTeam.ok && listWithoutTeam.project_found_in_list);
  const has401 = probes.some((item) => item.http_status === 401);
  const has403 = probes.some((item) => item.http_status === 403);
  const anyProjectListReadable = Boolean((listWithTeam && listWithTeam.ok) || (listWithoutTeam && listWithoutTeam.ok));

  let classification = "blocked_unknown";
  let status = "blocked";
  if (projectWithTeam && projectWithTeam.ok && projectWithTeam.project_id_matches) {
    status = "ready";
    classification = "project_visible_with_configured_team";
  } else if (projectWithoutTeam && projectWithoutTeam.ok && projectWithoutTeam.project_id_matches) {
    status = "blocked";
    classification = "project_visible_without_configured_team_team_scope_mismatch";
  } else if (foundInTeamList || foundInUserList) {
    status = "blocked";
    classification = "project_listed_but_direct_lookup_failed";
  } else if (has401) {
    classification = "token_invalid_or_expired";
  } else if (has403) {
    classification = "token_forbidden_for_project_or_team";
  } else if (anyProjectListReadable) {
    classification = "token_valid_but_project_not_visible";
  } else {
    classification = "vercel_api_unreachable_or_scope_unknown";
  }

  const envProbe = projectReadVerified
    ? await request("project_env_with_team", "/v9/projects/" + encodeURIComponent(project) + "/env" + query({ teamId: team }))
    : null;
  if (envProbe) probes.push(envProbe);

  console.log(JSON.stringify({
    status,
    classification,
    probes,
    project_read_verified: projectReadVerified,
    safe_to_deploy_via_vercel: status === "ready",
    found_in_team_list: foundInTeamList,
    found_in_user_list: foundInUserList
  }));
})();
'@

  $projectProbe = @($probe.probes | Where-Object { $_.label -eq "project_with_team" } | Select-Object -First 1)
  $projectHttpStatus = if ($projectProbe.Count -gt 0 -and $projectProbe[0].http_status) { [int]$projectProbe[0].http_status } else { 0 }
  $status = if ($probe.status -eq "ready") { "ready" } else { "blocked" }
  $blocking = ($status -ne "ready")
  $requiredFix = ""
  if ($blocking) {
    switch ([string]$probe.classification) {
      "missing_vercel_token" { $requiredFix = "Set VERCEL_TOKEN in the private local env file; do not commit it." }
      "missing_vercel_project_id" { $requiredFix = "Set VERCEL_PROJECT_ID or restore apps/frontend/.vercel/project.json." }
      "project_visible_without_configured_team_team_scope_mismatch" { $requiredFix = "Configured project is readable, but not through the configured teamId. Fix VERCEL_TEAM_ID/VERCEL_ORG_ID or relink the project." }
      "token_valid_but_project_not_visible" { $requiredFix = "Use a Vercel token from an account/team that can read the configured project, or relink apps/frontend/.vercel/project.json." }
      "token_invalid_or_expired" { $requiredFix = "Replace VERCEL_TOKEN with a current token." }
      "token_forbidden_for_project_or_team" { $requiredFix = "Grant the token/account access to the configured team/project." }
      default { $requiredFix = "Inspect Vercel account/team/project linkage; no Vercel deployment should run while this verifier is blocked." }
    }
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    env_file_present = Test-Path -LiteralPath $EnvFilePath
    project_json_present = $projectJsonPresent
    project_id_present = -not [string]::IsNullOrWhiteSpace($projectId)
    team_id_present = -not [string]::IsNullOrWhiteSpace($teamId)
    token_present = $tokenPresent
    project_id = $projectId
    team_id = $teamId
    project_name = $projectName
    status = $status
    blocking = $blocking
    classification = [string]$probe.classification
    safe_to_deploy_via_vercel = [bool]$probe.safe_to_deploy_via_vercel
    http_status_project_with_team = $projectHttpStatus
    required_fix = $requiredFix
    probes = @($probe.probes)
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
    Write-Host "[vercel-access] status=$($summary.status)"
    Write-Host "[vercel-access] classification=$($summary.classification)"
    Write-Host "[vercel-access] safe_to_deploy_via_vercel=$($summary.safe_to_deploy_via_vercel)"
    Write-Host "[vercel-access] token_present=$($summary.token_present); project_id_present=$($summary.project_id_present); team_id_present=$($summary.team_id_present)"
    Write-Host "[vercel-access] http_status_project_with_team=$($summary.http_status_project_with_team)"
    if (-not [string]::IsNullOrWhiteSpace($summary.required_fix)) {
      Write-Host "[vercel-access] required_fix=$($summary.required_fix)"
    }
  }

  if ($blocking -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}
