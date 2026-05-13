param(
  [string]$SecretPath = "C:\Users\immer\.codex\secrets\cloud-superbrain.local.env",
  [string]$KnownHetznerTokenPath = "D:\PLATTFORM\HCLOUD_TOKEN.txt",
  [string]$VercelProjectJsonPath = "apps\frontend\.vercel\project.json",
  [string]$OutputPath = "",
  [switch]$RequireOptionalIdentities,
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Read-EnvFile([string]$Path) {
  $values = @{}
  if (-not (Test-Path -LiteralPath $Path)) {
    return $values
  }

  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match "^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$") {
      $name = $Matches[1]
      $value = $Matches[2].Trim()
      if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      $values[$name] = $value
    }
  }

  return $values
}

function Set-ProcessEnvFromMap([hashtable]$Values) {
  foreach ($key in $Values.Keys) {
    [Environment]::SetEnvironmentVariable($key, [string]$Values[$key], "Process")
  }
}

function New-Check(
  [string]$Provider,
  [string[]]$RequiredKeys,
  [string]$CurrentState,
  [string]$VerificationCommand,
  [string]$Result,
  [string]$RequiredFix,
  [string]$Status = "blocked",
  [int]$HttpStatus = 0,
  [bool]$Blocking = $true
) {
  [pscustomobject]@{
    provider = $Provider
    required_keys = $RequiredKeys
    current_state = $CurrentState
    verification_command = $VerificationCommand
    result = $Result
    required_fix = $RequiredFix
    status = $Status
    http_status = $HttpStatus
    blocking = $Blocking
  }
}

function Test-EnvPresent([hashtable]$Values, [string]$Name) {
  return $Values.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace([string]$Values[$Name])
}

function Invoke-NodeJson([string]$Script) {
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (-not $node) {
    return [pscustomobject]@{
      status = "failed"
      error = "node command is not available"
    }
  }

  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("tooling-readiness-{0}.js" -f ([guid]::NewGuid().ToString("N")))
  try {
    Set-Content -LiteralPath $tmp -Value $Script -Encoding UTF8
    $raw = & $node.Source $tmp 2>&1 | Out-String
    try {
      return ($raw | ConvertFrom-Json)
    } catch {
      return [pscustomobject]@{
        status = "failed"
        error = "node probe returned non-json output"
        output_excerpt = $raw.Trim().Substring(0, [Math]::Min(400, $raw.Trim().Length))
      }
    }
  } finally {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-ProcessProbe([scriptblock]$Command) {
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $Command 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } catch {
    $output = $_.Exception.Message
    $exitCode = 1
  } finally {
    $ErrorActionPreference = $previousPreference
  }

  return [pscustomobject]@{
    exit_code = $exitCode
    output = $output
  }
}

function Invoke-DockerReadinessProbe() {
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if (-not $docker) {
    return [pscustomobject]@{
      ready = $false
      exit_code = 127
      server_version = ""
      output_excerpt = "docker command is not available"
    }
  }

  $probe = Invoke-ProcessProbe { docker info --format '{{.ServerVersion}}' }
  $output = ($probe.output | Out-String).Trim()
  $versionMatch = [regex]::Match($output, '^[0-9]+(\.[0-9]+)+', [System.Text.RegularExpressions.RegexOptions]::Multiline)
  return [pscustomobject]@{
    ready = ($probe.exit_code -eq 0 -and $versionMatch.Success)
    exit_code = $probe.exit_code
    server_version = if ($versionMatch.Success) { $versionMatch.Value } else { "" }
    output_excerpt = $output.Substring(0, [Math]::Min(500, $output.Length))
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  $envValues = Read-EnvFile -Path $SecretPath
  Set-ProcessEnvFromMap -Values $envValues

  $projectJson = $null
  if (Test-Path -LiteralPath $VercelProjectJsonPath) {
    $projectJson = Get-Content -LiteralPath $VercelProjectJsonPath -Raw | ConvertFrom-Json
    if (-not (Test-EnvPresent $envValues "VERCEL_PROJECT_ID") -and $projectJson.projectId) {
      [Environment]::SetEnvironmentVariable("VERCEL_PROJECT_ID", [string]$projectJson.projectId, "Process")
    }
    if (-not (Test-EnvPresent $envValues "VERCEL_TEAM_ID") -and $projectJson.orgId) {
      [Environment]::SetEnvironmentVariable("VERCEL_TEAM_ID", [string]$projectJson.orgId, "Process")
    }
  }

  $checks = [System.Collections.Generic.List[object]]::new()

  $cliChecks = [ordered]@{
    node = [bool](Get-Command node -ErrorAction SilentlyContinue)
    npm = [bool](Get-Command npm -ErrorAction SilentlyContinue)
    vercel = [bool](Get-Command vercel -ErrorAction SilentlyContinue)
    wrangler = [bool](Get-Command wrangler -ErrorAction SilentlyContinue)
    hcloud = [bool](Get-Command hcloud -ErrorAction SilentlyContinue)
    git = [bool](Get-Command git -ErrorAction SilentlyContinue)
    git_lfs = $false
    gitkraken_cli_path = [bool](Test-Path -LiteralPath "C:\Users\immer\AppData\Local\GitKrakenCLI\gk.exe")
    gitkraken_cli_on_path = [bool](Get-Command gk -ErrorAction SilentlyContinue)
  }
  $gitLfsProbe = Invoke-ProcessProbe { git lfs version }
  $cliChecks.git_lfs = ($gitLfsProbe.exit_code -eq 0)

  $dockerProbe = Invoke-DockerReadinessProbe
  if ($dockerProbe.ready) {
    $checks.Add((New-Check "docker" @("docker") "Docker engine readiness verified" "docker info --format '{{.ServerVersion}}'" ("server_version={0}" -f $dockerProbe.server_version) "" "ready" 0 $false))
  } else {
    $checks.Add((New-Check "docker" @("docker") "Docker engine is not ready for local docker-dependent gates" "docker info --format '{{.ServerVersion}}'" ("exit_code={0}; [BLOCKED] docker-compose gates; [SKIPPED-REASON: docker-unavailable] docker-dependent verification" -f $dockerProbe.exit_code) "Restore Docker Desktop/WSL2 readiness before running compose, image build, backup, or local runtime gates. Process checks do not prove Docker readiness." "docker_gates_blocked" 0 $false))
  }

  $vercelProbe = Invoke-NodeJson @'
const project = process.env.VERCEL_PROJECT_ID || "";
const team = process.env.VERCEL_TEAM_ID || process.env.VERCEL_ORG_ID || "";
const token = process.env.VERCEL_TOKEN || "";
if (!token || !project) {
  console.log(JSON.stringify({ status: "missing", http_status: 0 }));
  process.exit(0);
}
const url = "https://api.vercel.com/v9/projects/" + encodeURIComponent(project) + (team ? "?teamId=" + encodeURIComponent(team) : "");
fetch(url, { headers: { Authorization: "Bearer " + token } })
  .then(async (response) => {
    let body = {};
    try { body = await response.json(); } catch {}
    console.log(JSON.stringify({
      status: response.ok && body.id === project ? "verified" : "failed",
      http_status: response.status,
      project_id_matches: body.id === project,
      project_name_present: Boolean(body.name),
      error_code: body.error ? body.error.code : null
    }));
  })
  .catch((error) => console.log(JSON.stringify({ status: "failed", http_status: 0, error: error.message })));
'@
  if ($vercelProbe.status -eq "verified") {
    $checks.Add((New-Check "vercel" @("VERCEL_TOKEN", "VERCEL_PROJECT_ID", "VERCEL_TEAM_ID") "project access verified" "GET /v9/projects/<project>?teamId=<team>" "HTTP 200 and project id matched" "" "ready" ([int]$vercelProbe.http_status) $false))
  } else {
    $checks.Add((New-Check "vercel" @("VERCEL_TOKEN", "VERCEL_PROJECT_ID", "VERCEL_TEAM_ID") "token/project/team not fully verified" "GET /v9/projects/<project>?teamId=<team>" ("status={0}; http={1}; error={2}" -f $vercelProbe.status, $vercelProbe.http_status, $vercelProbe.error_code) "Provide a Vercel token that can read the configured project/team, or mark Vercel non-blocking by owner decision." "blocked" ([int]$vercelProbe.http_status) $true))
  }

  $hcloudAvailable = [bool](Get-Command hcloud -ErrorAction SilentlyContinue)
  $secretHetznerOk = $false
  if ($hcloudAvailable -and (Test-EnvPresent $envValues "HETZNER_API_TOKEN")) {
    $oldHcloudToken = $env:HCLOUD_TOKEN
    try {
      $env:HCLOUD_TOKEN = [string]$envValues["HETZNER_API_TOKEN"]
      $secretHetznerProbe = Invoke-ProcessProbe { hcloud server list -o columns=name,status,type,ipv4 }
      $secretHetznerOk = ($secretHetznerProbe.exit_code -eq 0 -and $secretHetznerProbe.output -match "superbrain-staging-fsn1" -and $secretHetznerProbe.output -match "188\.34\.191\.140")
    } finally {
      $env:HCLOUD_TOKEN = $oldHcloudToken
    }
  }

  $knownHetznerOk = $false
  if ($hcloudAvailable -and (Test-Path -LiteralPath $KnownHetznerTokenPath)) {
    $oldHcloudToken = $env:HCLOUD_TOKEN
    try {
      $env:HCLOUD_TOKEN = (Get-Content -LiteralPath $KnownHetznerTokenPath -Raw).Trim()
      $knownHetznerProbe = Invoke-ProcessProbe { hcloud server list -o columns=name,status,type,ipv4 }
      $knownHetznerOk = ($knownHetznerProbe.exit_code -eq 0 -and $knownHetznerProbe.output -match "superbrain-staging-fsn1" -and $knownHetznerProbe.output -match "188\.34\.191\.140")
    } finally {
      $env:HCLOUD_TOKEN = $oldHcloudToken
    }
  }

  if ($secretHetznerOk) {
    $checks.Add((New-Check "hetzner" @("HETZNER_API_TOKEN") "secret-file token verified" "hcloud server list" "staging server visible" "" "ready" 0 $false))
  } elseif ($knownHetznerOk) {
    $checks.Add((New-Check "hetzner" @("HETZNER_API_TOKEN", "HCLOUD_TOKEN") "known token file verified, secret-file token not verified" "hcloud server list" "staging server visible only with known token file" "Replace HETZNER_API_TOKEN in the local secret file or add HCLOUD_TOKEN from the known-good source." "ready_with_fix" 0 $false))
  } else {
    $checks.Add((New-Check "hetzner" @("HETZNER_API_TOKEN") "no verified Hetzner token source" "hcloud server list" "staging server not verified" "Provide a valid Hetzner token for the staging project." "blocked" 0 $true))
  }

  $cloudflareProbe = Invoke-NodeJson @'
const token = process.env.CLOUDFLARE_API_TOKEN || "";
if (!token) {
  console.log(JSON.stringify({ status: "missing", http_status: 0 }));
  process.exit(0);
}
fetch("https://api.cloudflare.com/client/v4/user/tokens/verify", { headers: { Authorization: "Bearer " + token } })
  .then(async (response) => {
    let body = {};
    try { body = await response.json(); } catch {}
    console.log(JSON.stringify({
      status: response.ok && body.success && body.result && body.result.status === "active" ? "verified" : "failed",
      http_status: response.status,
      token_status: body.result ? body.result.status : null,
      success: Boolean(body.success),
      errors: Array.isArray(body.errors) ? body.errors.map((item) => item.code) : []
    }));
  })
  .catch((error) => console.log(JSON.stringify({ status: "failed", http_status: 0, error: error.message })));
'@
  $cloudflareKeysPresent = (Test-EnvPresent $envValues "CLOUDFLARE_ACCOUNT_ID") -and (Test-EnvPresent $envValues "CLOUDFLARE_ZONE_ID") -and (Test-EnvPresent $envValues "CLOUDFLARE_PRODUCTION_DOMAIN")
  if ($cloudflareProbe.status -eq "verified" -and $cloudflareKeysPresent) {
    $checks.Add((New-Check "cloudflare" @("CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_ZONE_ID", "CLOUDFLARE_PRODUCTION_DOMAIN") "token active and required non-secret IDs present" "GET /client/v4/user/tokens/verify" "HTTP 200, token active" "" "ready" ([int]$cloudflareProbe.http_status) $false))
  } else {
    $checks.Add((New-Check "cloudflare" @("CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ACCOUNT_ID", "CLOUDFLARE_ZONE_ID", "CLOUDFLARE_PRODUCTION_DOMAIN") "cloudflare token or required IDs not fully verified" "GET /client/v4/user/tokens/verify" ("status={0}; http={1}; ids_present={2}" -f $cloudflareProbe.status, $cloudflareProbe.http_status, $cloudflareKeysPresent) "Provide active token plus account, zone, and production domain values." "blocked" ([int]$cloudflareProbe.http_status) $true))
  }

  $hfProbe = Invoke-NodeJson @'
const token = process.env.HF_TOKEN || "";
if (!token) {
  console.log(JSON.stringify({ status: "missing", http_status: 0 }));
  process.exit(0);
}
fetch("https://huggingface.co/api/whoami-v2", { headers: { Authorization: "Bearer " + token } })
  .then(async (response) => {
    let body = {};
    try { body = await response.json(); } catch {}
    console.log(JSON.stringify({
      status: response.ok && body.name === "Wrzzzrzr" ? "verified" : "failed",
      http_status: response.status,
      name_matches: body.name === "Wrzzzrzr",
      user_present: Boolean(body.name)
    }));
  })
  .catch((error) => console.log(JSON.stringify({ status: "failed", http_status: 0, error: error.message })));
'@
  if ($hfProbe.status -eq "verified") {
    $checks.Add((New-Check "huggingface" @("HF_TOKEN") "identity verified" "GET /api/whoami-v2" "HTTP 200, expected user matched" "" "ready" ([int]$hfProbe.http_status) $false))
  } else {
    $checks.Add((New-Check "huggingface" @("HF_TOKEN") "identity not verified" "GET /api/whoami-v2" ("status={0}; http={1}" -f $hfProbe.status, $hfProbe.http_status) "Replace HF_TOKEN or mark Hugging Face as optional non-claim." "optional_blocked" ([int]$hfProbe.http_status) ([bool]$RequireOptionalIdentities)))
  }

  $gitLabProbe = Invoke-NodeJson @'
const token = process.env.GITLAB_TOKEN || "";
if (!token) {
  console.log(JSON.stringify({ status: "missing", http_status: 0 }));
  process.exit(0);
}
fetch("https://gitlab.com/api/v4/user", { headers: { "PRIVATE-TOKEN": token } })
  .then(async (response) => {
    let body = {};
    try { body = await response.json(); } catch {}
    console.log(JSON.stringify({
      status: response.ok ? "verified" : "failed",
      http_status: response.status,
      user_present: Boolean(body.username),
      message: body.message || null
    }));
  })
  .catch((error) => console.log(JSON.stringify({ status: "failed", http_status: 0, error: error.message })));
'@
  if ($gitLabProbe.status -eq "verified") {
    $checks.Add((New-Check "gitlab" @("GITLAB_TOKEN") "identity verified" "GET /api/v4/user" "HTTP 200" "" "ready" ([int]$gitLabProbe.http_status) $false))
  } else {
    $checks.Add((New-Check "gitlab" @("GITLAB_TOKEN") "identity not verified" "GET /api/v4/user" ("status={0}; http={1}" -f $gitLabProbe.status, $gitLabProbe.http_status) "Replace GITLAB_TOKEN or mark GitLab as optional non-claim." "optional_blocked" ([int]$gitLabProbe.http_status) ([bool]$RequireOptionalIdentities))
    )
  }

  $gitKrakenTokenPresent = Test-EnvPresent $envValues "GITKRAKEN_API_TOKEN"
  $gitKrakenOrgPresent = Test-EnvPresent $envValues "GITKRAKEN_ORG_ID"
  if ($gitKrakenTokenPresent -and $gitKrakenOrgPresent) {
    $gitKrakenProbe = Invoke-NodeJson @'
const token = process.env.GITKRAKEN_API_TOKEN || "";
const apiBase = (process.env.GITKRAKEN_API_URL || "https://gitkraken.gitclear.com/api/v1").replace(/\/$/, "");
fetch(apiBase + "/api_tokens", { headers: { Authorization: "Bearer " + token } })
  .then(async (response) => {
    let body = {};
    try { body = await response.json(); } catch {}
    console.log(JSON.stringify({
      status: response.ok ? "verified" : "failed",
      http_status: response.status,
      response_em: body.response_em || null
    }));
  })
  .catch((error) => console.log(JSON.stringify({ status: "failed", http_status: 0, error: error.message })));
'@
    if ($gitKrakenProbe.status -eq "verified") {
      $checks.Add((New-Check "gitkraken" @("GITKRAKEN_API_TOKEN", "GITKRAKEN_ORG_ID") "identity token verified" "GET GitKraken api_tokens" "HTTP 2xx" "" "ready" ([int]$gitKrakenProbe.http_status) $false))
    } else {
      $checks.Add((New-Check "gitkraken" @("GITKRAKEN_API_TOKEN", "GITKRAKEN_ORG_ID") "identity token failed verification" "GET GitKraken api_tokens" ("status={0}; http={1}" -f $gitKrakenProbe.status, $gitKrakenProbe.http_status) "Replace GITKRAKEN_API_TOKEN or mark GitKraken as optional non-claim." "optional_blocked" ([int]$gitKrakenProbe.http_status) ([bool]$RequireOptionalIdentities)))
    }
  } else {
    $checks.Add((New-Check "gitkraken" @("GITKRAKEN_API_TOKEN", "GITKRAKEN_ORG_ID") "GITKRAKEN_API_TOKEN missing or org id missing" "Test env presence and optional CLI path" ("token_present={0}; org_present={1}; cli_path_present={2}; cli_on_path={3}" -f $gitKrakenTokenPresent, $gitKrakenOrgPresent, $cliChecks.gitkraken_cli_path, $cliChecks.gitkraken_cli_on_path) "Add GITKRAKEN_API_TOKEN or mark GitKraken as optional non-claim; add GitKrakenCLI path to PATH only if CLI usage is required." "optional_blocked" 0 ([bool]$RequireOptionalIdentities)))
  }

  $ownerDecision = [string]$envValues["OWNER_DECISION"]
  $strategy = [string]$envValues["RELEASE_CANDIDATE_STRATEGY"]
  $liveLlmApproved = [string]$envValues["LIVE_LLM_TEST_CALL_APPROVED"]
  $liveLlmBudget = [string]$envValues["LIVE_LLM_MAX_BUDGET_USD"]
  $ownerOk = @("no-release", "approved") -contains $ownerDecision
  $strategyOk = @("deploy immutable candidate", "rebaseline current staging", "rebaseline current worktree") -contains $strategy
  $liveLlmOk = @("true", "false") -contains $liveLlmApproved
  $budgetOk = $false
  $budgetValue = 0.0
  $budgetOk = [double]::TryParse($liveLlmBudget, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$budgetValue)
  $decisionState = "owner_decision=$ownerDecision; release_candidate_strategy=$strategy; live_llm_test_call_approved=$liveLlmApproved; live_llm_budget_present=$budgetOk"
  if ($ownerOk -and $strategyOk -and $liveLlmOk -and $budgetOk) {
    $checks.Add((New-Check "owner_decisions" @("OWNER_DECISION", "RELEASE_CANDIDATE_STRATEGY", "LIVE_LLM_TEST_CALL_APPROVED", "LIVE_LLM_MAX_BUDGET_USD") "required owner values are explicit" "parse local secret decision keys" $decisionState "" "ready" 0 $false))
  } else {
    $checks.Add((New-Check "owner_decisions" @("OWNER_DECISION", "RELEASE_CANDIDATE_STRATEGY", "LIVE_LLM_TEST_CALL_APPROVED", "LIVE_LLM_MAX_BUDGET_USD") "one or more required owner values are missing or invalid" "parse local secret decision keys" $decisionState "Set OWNER_DECISION, RELEASE_CANDIDATE_STRATEGY, LIVE_LLM_TEST_CALL_APPROVED, and LIVE_LLM_MAX_BUDGET_USD to allowed values." "blocked" 0 $true))
  }

  $blockingFailures = @($checks | Where-Object { $_.blocking -and $_.status -notin @("ready", "ready_with_fix") })
  $optionalFailures = @($checks | Where-Object { -not $_.blocking -and $_.status -eq "optional_blocked" })
  $dockerGateFailures = @($checks | Where-Object { $_.provider -eq "docker" -and $_.status -eq "docker_gates_blocked" })
  $ready = @($checks | Where-Object { $_.status -in @("ready", "ready_with_fix") })
  $overallStatus = if ($blockingFailures.Count -gt 0) {
    "blocked"
  } elseif ($dockerGateFailures.Count -gt 0) {
    "ready_with_docker_gates_blocked"
  } else {
    "ready"
  }
  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    secret_file_present = Test-Path -LiteralPath $SecretPath
    cli = $cliChecks
    overall_status = $overallStatus
    safe_to_continue_codex = ($blockingFailures.Count -eq 0)
    docker_dependent_gates_ready = ($dockerGateFailures.Count -eq 0)
    ready = @($ready.provider)
    blocked = @($blockingFailures.provider)
    docker_blocked = @($dockerGateFailures.provider)
    optional = @($optionalFailures.provider)
    checks = $checks
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
    Write-Host "[tooling-readiness] overall_status=$($summary.overall_status)"
    Write-Host "[tooling-readiness] safe_to_continue_codex=$($summary.safe_to_continue_codex)"
    Write-Host "[tooling-readiness] docker_dependent_gates_ready=$($summary.docker_dependent_gates_ready)"
    Write-Host "[tooling-readiness] ready=$($summary.ready -join ',')"
    Write-Host "[tooling-readiness] blocked=$($summary.blocked -join ',')"
    Write-Host "[tooling-readiness] docker_blocked=$($summary.docker_blocked -join ',')"
    Write-Host "[tooling-readiness] optional=$($summary.optional -join ',')"
    foreach ($check in $checks) {
      Write-Host ("[tooling-readiness] {0}: {1} :: {2}" -f $check.provider, $check.status, $check.result)
      if (-not [string]::IsNullOrWhiteSpace($check.required_fix)) {
        Write-Host ("[tooling-readiness] {0} fix: {1}" -f $check.provider, $check.required_fix)
      }
    }
  }

  if ($blockingFailures.Count -gt 0 -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}
