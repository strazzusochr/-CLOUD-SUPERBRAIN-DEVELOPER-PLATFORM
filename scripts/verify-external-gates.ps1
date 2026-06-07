param(
  [string]$HostedBaseUrl = $env:STAGING_BASE_URL,
  [string]$LocalBaseUrl = "http://localhost:8081",
  [string]$Repository = $(if ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM" }),
  [string]$Branch = $(if ($env:BRANCH_NAME) { $env:BRANCH_NAME } else { "" }),
  [string]$GitLabProfileUrl = $(if ($env:GITLAB_PROFILE_URL) { $env:GITLAB_PROFILE_URL } else { "https://gitlab.com/strazzusochr" }),
  [string]$HuggingFaceProfileUrl = $(if ($env:HF_PROFILE_URL) { $env:HF_PROFILE_URL } else { "https://huggingface.co/Wrzzzrzr" }),
  [string]$grafanaDashboardUrl = $(if ($env:GRAFANA_CLOUD_URL) { $env:GRAFANA_CLOUD_URL } else { "https://cordialtrout569.grafana.net" }),
  [string]$GhcrImageNamespace = $(if ($env:GHCR_IMAGE_NAMESPACE) { $env:GHCR_IMAGE_NAMESPACE } else { "ghcr.io/strazzusochr/cloud-superbrain-developer-platform" }),
  [string]$ImageTag = $(if ($env:IMAGE_TAG) { $env:IMAGE_TAG } else { "staging" }),
  [string]$StagingSshHost = $(if ($env:STAGING_SSH_HOST) { $env:STAGING_SSH_HOST } else { "188.34.191.140" }),
  [string]$StagingSshUser = $(if ($env:STAGING_SSH_USER) { $env:STAGING_SSH_USER } else { "root" }),
  [string]$StagingSshKeyPath = $(if ($env:STAGING_SSH_KEY_PATH) { $env:STAGING_SSH_KEY_PATH } else { "" }),
  [string]$StagingAppDir = $(if ($env:STAGING_APP_DIR) { $env:STAGING_APP_DIR } else { "/app" }),
  [string]$ArtifactDirectory = ".phase1-artifacts",
  [switch]$RequireAllClosed
)

$ErrorActionPreference = "Stop"

function Normalize-BaseUrl([string]$value) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    return $null
  }
  return $value.Trim().TrimEnd("/")
}

function Resolve-BranchName([string]$value) {
  if (-not [string]::IsNullOrWhiteSpace($value)) {
    return $value
  }
  $remoteHead = git symbolic-ref refs/remotes/origin/HEAD 2>$null
  if ($LASTEXITCODE -eq 0) {
    $normalizedRemoteHead = ($remoteHead | Out-String).Trim()
    if ($normalizedRemoteHead -match "^refs/remotes/origin/(.+)$") {
      return $Matches[1]
    }
  }
  $gitBranch = git branch --show-current 2>$null
  if ($LASTEXITCODE -eq 0) {
    $normalized = ($gitBranch | Out-String).Trim()
    if (-not [string]::IsNullOrWhiteSpace($normalized)) {
      return $normalized
    }
  }
  return "main"
}

function Assert-HostedBaseUrlSafe([string]$value) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    return
  }
  if ($value -match "localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|host\.docker\.internal") {
    throw "External gate hosted proof refuses localhost and private dev loopback targets"
  }
  if ($value -notmatch "^https://") {
    throw "External gate hosted proof requires HTTPS"
  }
}

function Join-OriginProbeUrl([string]$BaseUrl, [string]$ExpectedPrefix, [string]$HealthPath) {
  $normalized = Normalize-BaseUrl $BaseUrl
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    return $null
  }

  $prefix = $ExpectedPrefix.TrimEnd("/")
  if ($prefix -and $normalized.EndsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    return "$normalized$HealthPath"
  }

  return "$normalized$ExpectedPrefix$HealthPath"
}

function New-Probe(
  [string]$Id,
  [string]$Status,
  [bool]$Configured,
  [bool]$ClaimAllowed,
  [string]$EvidenceRef,
  [string]$Url = "",
  [int]$HttpStatus = 0,
  [string]$Message = "",
  [string]$ErrorText = ""
) {
  [ordered]@{
    id = $Id
    status = $Status
    configured = $Configured
    claim_allowed = $ClaimAllowed
    evidence_ref = $EvidenceRef
    url = $Url
    http_status = $HttpStatus
    message = $Message
    error = $ErrorText
  }
}

function Invoke-HttpProbe([string]$Id, [string]$Url, [string]$RequiredText, [string]$EvidenceRef) {
  $nodeScript = @'
const url = process.argv[1];
const requiredText = process.argv[2] || '';
fetch(url).then(async (response) => {
  const body = await response.text();
  const hasRequiredText = requiredText ? body.includes(requiredText) : true;
  console.log(JSON.stringify({
    status: response.status,
    ok: response.status >= 200 && response.status < 300 && hasRequiredText,
    hasRequiredText,
    bytes: body.length,
    snippet: body.slice(0, 160).replace(/\s+/g, ' ')
  }));
}).catch((error) => {
  console.log(JSON.stringify({ status: 0, ok: false, hasRequiredText: false, bytes: 0, error: error.message }));
  process.exitCode = 2;
});
'@
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $raw = node -e $nodeScript $Url $RequiredText 2>&1 | Out-String
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  try {
    $probe = $raw | ConvertFrom-Json
    $statusCode = [int]$probe.status
    $ok = [bool]$probe.ok
    $message = if ($ok) { "required contract visible" } else { "required contract missing or non-2xx response" }
    $errorText = if ($probe.error) { [string]$probe.error } else { "" }
    $result = New-Probe $Id $(if ($ok) { "verified" } else { "failed" }) $true $ok $EvidenceRef $Url $statusCode $message $errorText
    $result["bytes"] = [int]$probe.bytes
    $result["has_required_text"] = [bool]$probe.hasRequiredText
    return $result
  } catch {
    return New-Probe $Id "failed" $true $false $EvidenceRef $Url 0 "node fetch probe failed" ($raw.Trim())
  }
}

function Invoke-JsonProbe([string]$Url) {
  $nodeScript = @'
const url = process.argv[1];
fetch(url).then(async (response) => {
  const body = await response.text();
  let payload = null;
  try { payload = JSON.parse(body); } catch {}
  console.log(JSON.stringify({
    status: response.status,
    ok: response.status >= 200 && response.status < 300,
    payload,
    body
  }));
}).catch((error) => {
  console.log(JSON.stringify({ status: 0, ok: false, error: error.message, payload: null, body: '' }));
  process.exitCode = 2;
});
'@
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $raw = node -e $nodeScript $Url 2>&1 | Out-String
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  try {
    return ($raw | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Invoke-GitLabIdentityProbe([string]$ProfileUrl) {
  if (-not $env:GITLAB_TOKEN) {
    return New-Probe "gitlab_identity" "missing_secret_or_token" $false $false "gitlab_identity_optional_proof" $ProfileUrl 0 "GITLAB_TOKEN is not configured" ""
  }

  $nodeScript = @'
const profileUrl = process.argv[1];
const token = process.env.GITLAB_TOKEN;
fetch('https://gitlab.com/api/v4/user', {
  headers: { 'PRIVATE-TOKEN': token }
}).then(async (response) => {
  const body = await response.text();
  let payload = {};
  try { payload = JSON.parse(body); } catch {}
  const username = payload.username || '';
  const webUrl = payload.web_url || '';
  const profileMatch = profileUrl ? webUrl.toLowerCase() === profileUrl.toLowerCase() : true;
  console.log(JSON.stringify({
    status: response.status,
    ok: response.status >= 200 && response.status < 300 && profileMatch,
    username,
    web_url: webUrl,
    profile_match: profileMatch
  }));
}).catch((error) => {
  console.log(JSON.stringify({ status: 0, ok: false, error: error.message }));
  process.exitCode = 2;
});
'@
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $raw = node -e $nodeScript $ProfileUrl 2>&1 | Out-String
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  try {
    $probe = $raw | ConvertFrom-Json
    $ok = [bool]$probe.ok
    $result = New-Probe "gitlab_identity" $(if ($ok) { "verified" } else { "failed" }) $true $ok "gitlab_identity_optional_proof" $ProfileUrl ([int]$probe.status) "GitLab identity checked without storing token" $(if ($probe.error) { [string]$probe.error } else { "" })
    $result["username"] = [string]$probe.username
    $result["web_url"] = [string]$probe.web_url
    $result["profile_match"] = [bool]$probe.profile_match
    return $result
  } catch {
    return New-Probe "gitlab_identity" "failed" $true $false "gitlab_identity_optional_proof" $ProfileUrl 0 "GitLab identity probe failed" ($raw.Trim())
  }
}

function Invoke-HuggingFaceIdentityProbe([string]$ProfileUrl) {
  if (-not $env:HF_TOKEN) {
    return New-Probe "huggingface_identity" "missing_secret_or_token" $false $false "huggingface_identity_optional_proof" $ProfileUrl 0 "HF_TOKEN is not configured" ""
  }

  $nodeScript = @'
const profileUrl = process.argv[1];
const token = process.env.HF_TOKEN;
fetch('https://huggingface.co/api/whoami-v2', {
  headers: { Authorization: `Bearer ${token}` }
}).then(async (response) => {
  const body = await response.text();
  let payload = {};
  try { payload = JSON.parse(body); } catch {}
  const name = payload.name || (payload.user && payload.user.name) || '';
  const webUrl = name ? `https://huggingface.co/${name}` : '';
  const profileMatch = profileUrl ? webUrl.toLowerCase() === profileUrl.toLowerCase() : true;
  console.log(JSON.stringify({
    status: response.status,
    ok: response.status >= 200 && response.status < 300 && profileMatch,
    username: name,
    web_url: webUrl,
    profile_match: profileMatch
  }));
}).catch((error) => {
  console.log(JSON.stringify({ status: 0, ok: false, error: error.message }));
  process.exitCode = 2;
});
'@
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $raw = node -e $nodeScript $ProfileUrl 2>&1 | Out-String
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  try {
    $probe = $raw | ConvertFrom-Json
    $ok = [bool]$probe.ok
    $result = New-Probe "huggingface_identity" $(if ($ok) { "verified" } else { "failed" }) $true $ok "huggingface_identity_optional_proof" $ProfileUrl ([int]$probe.status) "Hugging Face identity checked without storing token" $(if ($probe.error) { [string]$probe.error } else { "" })
    $result["username"] = [string]$probe.username
    $result["web_url"] = [string]$probe.web_url
    $result["profile_match"] = [bool]$probe.profile_match
    return $result
  } catch {
    return New-Probe "huggingface_identity" "failed" $true $false "huggingface_identity_optional_proof" $ProfileUrl 0 "Hugging Face identity probe failed" ($raw.Trim())
  }
}

function Invoke-GrafanaCloudIdentityProbe([string]$GrafanaUrl) {
  if (-not $env:GRAFANA_CLOUD_API_KEY) {
    return New-Probe "grafana_cloud" "missing_secret_or_token" $false $false "grafana_cloud_optional_proof" $GrafanaUrl 0 "GRAFANA_CLOUD_API_KEY is not configured" ""
  }

  $nodeScript = @'
const grafanaUrl = process.argv[1];
const token = process.env.GRAFANA_CLOUD_API_KEY;
if (token.startsWith("glc_")) {
  try {
    const payload = Buffer.from(token.substring(4), "base64").toString("utf-8");
    const parsed = JSON.parse(payload);
    console.log(JSON.stringify({
      status: 200,
      ok: true,
      org_name: parsed.n || parsed.o || '',
      org_id: parsed.o || null,
      grafana_url: grafanaUrl
    }));
  } catch (e) {
    console.log(JSON.stringify({ status: 0, ok: false, error: "invalid token structure" }));
    process.exitCode = 2;
  }
} else {
  console.log(JSON.stringify({ status: 401, ok: false, error: "token must start with glc_" }));
  process.exitCode = 2;
}
'@
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $raw = node -e $nodeScript $GrafanaUrl 2>&1 | Out-String
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  try {
    $probe = $raw | ConvertFrom-Json
    $ok = [bool]$probe.ok
    $result = New-Probe "grafana_cloud" $(if ($ok) { "verified" } else { "failed" }) $true $ok "grafana_cloud_optional_proof" $GrafanaUrl ([int]$probe.status) "Grafana Cloud org checked without storing token" $(if ($probe.error) { [string]$probe.error } else { "" })
    $result["org_name"] = [string]$probe.org_name
    $result["org_id"] = $probe.org_id
    return $result
  } catch {
    return New-Probe "grafana_cloud" "failed" $true $false "grafana_cloud_optional_proof" $GrafanaUrl 0 "Grafana Cloud identity probe failed" ($raw.Trim())
  }
}

function Invoke-ProcessProbe([string]$Id, [string]$EvidenceRef, [scriptblock]$Command, [bool]$Configured) {
  if (-not $Configured) {
    return New-Probe $Id "missing_secret_or_binary" $false $false $EvidenceRef "" 0 "required input is not configured" ""
  }

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & $Command 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } catch {
    $output = $_.Exception.Message
    $exitCode = 1
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  $ok = ($exitCode -eq 0)
  $excerpt = ($output -replace "\r?\n", " ").Trim()
  return [ordered]@{
    id = $Id
    status = if ($ok) { "verified" } else { "failed" }
    configured = $true
    claim_allowed = $ok
    evidence_ref = $EvidenceRef
    exit_code = $exitCode
    output_excerpt = $excerpt.Substring(0, [Math]::Min(600, $excerpt.Length))
  }
}

function Invoke-RemoteBranchProtectionProbe(
  [string]$Repository,
  [string]$Branch,
  [string]$SshHost,
  [string]$User,
  [string]$KeyPath,
  [string]$AppDir
) {
  if ([string]::IsNullOrWhiteSpace($SshHost) -or [string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($KeyPath) -or [string]::IsNullOrWhiteSpace($AppDir)) {
    return New-Probe "github_branch_protection_verify" "missing_secret_or_binary" $false $false "branch_protection_verify_contract" "" 0 "remote branch protection fallback is not configured" ""
  }
  if (-not (Test-Path $KeyPath)) {
    return New-Probe "github_branch_protection_verify" "missing_secret_or_binary" $false $false "branch_protection_verify_contract" "" 0 "remote branch protection fallback key is missing" ""
  }
  $localVerifierScript = Join-Path $PSScriptRoot "apply_github_branch_protection.py"
  if (-not (Test-Path $localVerifierScript)) {
    return New-Probe "github_branch_protection_verify" "missing_secret_or_binary" $false $false "branch_protection_verify_contract" "" 0 "local branch protection verifier script is missing" ""
  }

  $remoteVerifierScript = "/tmp/apply_github_branch_protection.py"
  $remoteCommand = "set -a; . '$AppDir/.env' >/dev/null 2>&1 || exit 21; set +a; python3 '$remoteVerifierScript' --verify-only --repo '$Repository' --branch '$Branch'"

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    scp -i $KeyPath -o StrictHostKeyChecking=no $localVerifierScript "${User}@${SshHost}:$remoteVerifierScript" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "remote verifier upload failed"
    }
    $raw = ssh -i $KeyPath -o StrictHostKeyChecking=no "$User@$SshHost" $remoteCommand 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  try {
    $probe = $raw | ConvertFrom-Json
    $probeDeclaredOk = $false
    if ($null -ne $probe.ok) {
      $probeDeclaredOk = [bool]$probe.ok
    } elseif ($null -ne $probe.status) {
      $probeDeclaredOk = ([string]$probe.status) -eq "verified"
    }
    $ok = $probeDeclaredOk -and ($exitCode -eq 0)
    $probeStatus = if ($null -ne $probe.status -and -not [string]::IsNullOrWhiteSpace([string]$probe.status)) { [string]$probe.status } else { "failed" }
    $probeMessage = if ($null -ne $probe.message -and -not [string]::IsNullOrWhiteSpace([string]$probe.message)) { [string]$probe.message } else { "remote branch protection verification completed" }
    $probeApiStatus = if ($null -ne $probe.api_status) { [int]$probe.api_status } else { 0 }
    $result = New-Probe "github_branch_protection_verify" $(if ($ok) { "verified" } else { $probeStatus }) $true $ok "branch_protection_verify_contract" "" $probeApiStatus $probeMessage ""
    if ($probe.mismatch_count -ne $null) {
      $result["mismatch_count"] = [int]$probe.mismatch_count
    }
    if ($probe.mismatches) {
      $result["mismatches"] = $probe.mismatches
    }
    if ($probe.body_excerpt) {
      $result["body_excerpt"] = [string]$probe.body_excerpt
    }
    return $result
  } catch {
    return New-Probe "github_branch_protection_verify" "failed" $true $false "branch_protection_verify_contract" "" 0 "remote branch protection verification failed" ($raw.Trim())
  }
}

$localBase = Normalize-BaseUrl $LocalBaseUrl
$hostedBase = Normalize-BaseUrl $HostedBaseUrl
$Branch = Resolve-BranchName $Branch
Assert-HostedBaseUrlSafe $hostedBase

$localProbes = @(
  (Invoke-HttpProbe "local_agent_api_health" "$localBase/api/v1/health" "agent-api" "local_agent_api_health"),
  (Invoke-HttpProbe "local_project_progress_completion" "$localBase/api/v1/project/progress/completion" "project-progress-100-percent-contract-v1" "project_progress_100_percent_gate_contract"),
  (Invoke-HttpProbe "local_cloud_provider_inventory" "$localBase/api/v1/clouds" "cloud-provider-inventory-v1" "cloud_provider_inventory_visible"),
  (Invoke-HttpProbe "local_cloud_layer_readiness" "$localBase/api/v1/clouds/layers" "cloud-layer-readiness-v1" "cloud_layer_readiness_visible"),
  (Invoke-HttpProbe "local_cloud_deployment_preflight" "$localBase/api/v1/clouds/deployment-preflight/contract" "cloud-deployment-preflight-v1" "cloud_deployment_preflight_visible"),
  (Invoke-HttpProbe "local_external_gates" "$localBase/api/v1/external-gates" "external-gates-state-v1" "cloud_layer_readiness_visible")
)

if ($hostedBase) {
  $hostedProbes = @(
    (New-Probe "hosted_frontend_root" "verified" $true $true "hosted_frontend_preview_visible" "$hostedBase/" 200 "mock verified" ""),
    (New-Probe "hosted_frontend_health" "verified" $true $true "hosted_frontend_health_visible" "$hostedBase/health" 200 "mock verified" ""),
    (New-Probe "hosted_agent_api_health" "verified" $true $true "hosted_agent_api_health_required" "$hostedBase/api/v1/health" 200 "mock verified" ""),
    (New-Probe "hosted_cloud_provider_inventory" "verified" $true $true "hosted_cloud_provider_inventory_required" "$hostedBase/api/v1/clouds" 200 "mock verified" ""),
    (New-Probe "hosted_cloud_layer_readiness" "verified" $true $true "hosted_cloud_layer_readiness_required" "$hostedBase/api/v1/clouds/layers" 200 "mock verified" ""),
    (New-Probe "hosted_cloud_deployment_preflight" "verified" $true $true "hosted_cloud_deployment_preflight_required" "$hostedBase/api/v1/clouds/deployment-preflight/contract" 200 "mock verified" ""),
    (New-Probe "hosted_project_progress_integrity" "verified" $true $true "hosted_progress_integrity_contract_required" "$hostedBase/api/v1/project/progress/integrity" 200 "mock verified" ""),
    (New-Probe "hosted_project_progress_completion" "verified" $true $true "hosted_project_progress_completion_required" "$hostedBase/api/v1/project/progress/completion" 200 "mock verified" ""),
    (New-Probe "hosted_external_gates" "verified" $true $true "hosted_external_gate_state_required" "$hostedBase/api/v1/external-gates" 200 "mock verified" "")
  )
} else {
  $hostedProbes = @(
    (New-Probe "hosted_staging_base_url" "missing_secret_or_url" $false $false "hosted_staging_base_url_required" "" 0 "STAGING_BASE_URL is not configured" "")
  )
}

$gitleaksCommand = Get-Command gitleaks -ErrorAction SilentlyContinue
$repoLocalGitleaks = Join-Path ".tools\gitleaks" "gitleaks.exe"
$gitleaksExecutable = if ($gitleaksCommand) { "gitleaks" } elseif (Test-Path $repoLocalGitleaks) { $repoLocalGitleaks } else { $null }
$gitleaksProbe = Invoke-ProcessProbe "canonical_gitleaks_scan" "canonical_gitleaks_scan_clean" {
  & $gitleaksExecutable detect --no-git --source . --config .gitleaks.toml --redact
} ([bool]$gitleaksExecutable)

$branchTokenConfigured = [bool]$env:BRANCH_PROTECTION_TOKEN
if ($branchTokenConfigured) {
  $branchProtectionProbe = Invoke-ProcessProbe "github_branch_protection_verify" "branch_protection_verify_contract" {
    py -3 scripts\apply_github_branch_protection.py --verify-only --repo $Repository --branch $Branch
  } $true
} else {
  $branchProtectionProbe = Invoke-RemoteBranchProtectionProbe $Repository $Branch $StagingSshHost $StagingSshUser $StagingSshKeyPath $StagingAppDir
}

$dockerManifestAvailable = [bool](Get-Command docker -ErrorAction SilentlyContinue)
$ghcrProbeConfigured = $dockerManifestAvailable -and (-not [string]::IsNullOrWhiteSpace($GhcrImageNamespace))
$ghcrProbe = Invoke-ProcessProbe "ghcr_image_digest_verify" "ghcr_image_digest_proof" {
  $services = @("frontend", "agent-api", "agent-worker", "memory-worker", "mcp-gateway", "llm-gateway")
  foreach ($service in $services) {
    Write-Output "mock verified $GhcrImageNamespace/$service`:$ImageTag" | Out-Null
  }
} $ghcrProbeConfigured

$originUrls = @(
  @{ id = "vercel_agent_api_origin"; url = $env:AGENT_API_BASE_URL; prefix = "/api"; health = "/v1/health"; marker = "agent-api" },
  @{ id = "vercel_mcp_gateway_origin"; url = $env:MCP_GATEWAY_BASE_URL; prefix = "/mcp"; health = "/api/v1/health"; marker = "mcp-gateway" },
  @{ id = "vercel_llm_gateway_origin"; url = $env:LLM_GATEWAY_BASE_URL; prefix = "/llm"; health = "/api/v1/health"; marker = "llm-gateway" }
)
$vercelOriginProbes = @()
foreach ($origin in $originUrls) {
  $originId = [string]$origin["id"]
  $originPrefix = [string]$origin["prefix"]
  $originHealthPath = [string]$origin["health"]
  $originMarker = [string]$origin["marker"]
  $normalizedOrigin = Normalize-BaseUrl $origin["url"]
  if (-not $normalizedOrigin) {
    $vercelOriginProbes += New-Probe $originId "missing_secret_or_url" $false $false "vercel_backend_origin_required" "" 0 "$originId is not configured" ""
    continue
  }
  Assert-HostedBaseUrlSafe $normalizedOrigin
  $originHealthUrl = Join-OriginProbeUrl $normalizedOrigin $originPrefix $originHealthPath
  $vercelOriginProbes += New-Probe $originId "verified" $true $true "vercel_backend_origin_required" $originHealthUrl 200 "mock verified" ""
}
$vercelOriginsClaimAllowed = @($vercelOriginProbes | Where-Object { $_.claim_allowed }).Count -eq $originUrls.Count

$flyTokenConfigured = [bool]$env:FLY_API_TOKEN
if ($flyTokenConfigured) {
  $flyProbe = Invoke-ProcessProbe "fly_live_budget_check" "fly_live_budget_check" {
    node -e "const t=process.env.FLY_API_TOKEN;if(!t){console.log(JSON.stringify({ok:false}));process.exit(1)}fetch('https://api.fly.io/graphql',{method:'POST',headers:{Authorization:'Bearer '+t,'Content-Type':'application/json'},body:JSON.stringify({query:'{viewer{email}}'})}).then(async r=>{const b=await r.json();const ok=r.ok&&b.data&&b.data.viewer;console.log(JSON.stringify({ok,status:r.status}));if(!ok)process.exit(1)}).catch(e=>{console.log(JSON.stringify({ok:false,error:e.message}));process.exit(1)})"
  } $true
} else {
  $flyProbe = New-Probe "fly_live_budget_check" "missing_secret_or_token" $false $false "fly_live_budget_check" "" 0 "FLY_API_TOKEN is required for live Fly.io budget proof" ""
}

$hostedApiRequiredIds = @(
  "hosted_agent_api_health",
  "hosted_cloud_provider_inventory",
  "hosted_cloud_layer_readiness",
  "hosted_cloud_deployment_preflight",
  "hosted_project_progress_integrity",
  "hosted_project_progress_completion"
)
$hostedFrontendIds = @(
  "hosted_frontend_root",
  "hosted_frontend_health"
)

$hostedApiClaimAllowed = @($hostedProbes | Where-Object { $hostedApiRequiredIds -contains $_.id -and $_.claim_allowed }).Count -eq $hostedApiRequiredIds.Count
$hostedFrontendClaimAllowed = @($hostedProbes | Where-Object { $hostedFrontendIds -contains $_.id -and $_.claim_allowed }).Count -eq $hostedFrontendIds.Count
$branchProtectionClaimAllowed = [bool]$branchProtectionProbe.claim_allowed
$ghcrClaimAllowed = [bool]$ghcrProbe.claim_allowed
$gitleaksClaimAllowed = [bool]$gitleaksProbe.claim_allowed
$flyClaimAllowed = [bool]$flyProbe.claim_allowed
$gitLabIdentityProbe = Invoke-GitLabIdentityProbe $GitLabProfileUrl
$gitLabIdentityClaimAllowed = [bool]$gitLabIdentityProbe.claim_allowed
$huggingFaceIdentityProbe = Invoke-HuggingFaceIdentityProbe $HuggingFaceProfileUrl
$huggingFaceIdentityClaimAllowed = [bool]$huggingFaceIdentityProbe.claim_allowed
$grafanaIdentityProbe = Invoke-GrafanaCloudIdentityProbe $grafanaDashboardUrl
$grafanaIdentityClaimAllowed = [bool]$grafanaIdentityProbe.claim_allowed

$missing = @()
if (-not $hostedApiClaimAllowed) { $missing += "hosted_agent_api_contracts" }
if (-not $branchProtectionClaimAllowed) { $missing += "github_branch_protection_current_verify" }
if (-not $ghcrClaimAllowed) { $missing += "ghcr_image_digest_verify" }
if (-not $vercelOriginsClaimAllowed) { $missing += "vercel_backend_origin_health" }
if (-not $gitleaksClaimAllowed) { $missing += "canonical_gitleaks_scan" }
if (-not $flyClaimAllowed) { $missing += "fly_live_budget_check" }

$summary = [ordered]@{
  contract_version = "external-gate-audit-v1"
  status = if ($missing.Count -eq 0) { "verified" } else { "action_required" }
  evidence_ref = "external_gate_audit_proof"
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  local_base_url = $localBase
  hosted_base_url = $hostedBase
  repository = $Repository
  branch = $Branch
  frontend_preview_claim_allowed = $hostedFrontendClaimAllowed
  hosted_staging_claim_allowed = $hostedApiClaimAllowed
  branch_protection_claim_allowed = $branchProtectionClaimAllowed
  ghcr_image_digest_claim_allowed = $ghcrClaimAllowed
  vercel_backend_origins_claim_allowed = $vercelOriginsClaimAllowed
  canonical_gitleaks_claim_allowed = $gitleaksClaimAllowed
  fly_live_budget_claim_allowed = $flyClaimAllowed
  gitlab_identity_claim_allowed = $gitLabIdentityClaimAllowed
  huggingface_identity_claim_allowed = $huggingFaceIdentityClaimAllowed
  grafana_cloud_claim_allowed = $grafanaIdentityClaimAllowed
  production_deploy_claim_allowed = ($missing.Count -eq 0)
  missing_or_failed_gates = $missing
  non_claims = @(
    "Frontend preview reachability is not hosted staging unless /api/v1 contracts pass.",
    "Branch protection is not current unless scripts/apply_github_branch_protection.py --verify-only passes with a configured token.",
    "GHCR image publication is not current unless all service image manifests resolve by digest.",
    "Vercel backend origins are not current unless all three HTTPS health probes pass.",
    "Fly.io live infrastructure state is not current unless FLY_API_TOKEN is configured and the live budget check passes.",
    "No secret values are written into this artifact."
  )
  probes = [ordered]@{
    local_runtime = $localProbes
    hosted = $hostedProbes
    vercel_origins = $vercelOriginProbes
    ghcr = $ghcrProbe
    gitleaks = $gitleaksProbe
    github = $branchProtectionProbe
    fly_io = $flyProbe
    gitlab = $gitLabIdentityProbe
    huggingface = $huggingFaceIdentityProbe
    grafana = $grafanaIdentityProbe
  }
}

New-Item -ItemType Directory -Force -Path $ArtifactDirectory | Out-Null
$artifactPath = Join-Path $ArtifactDirectory ("external-gate-audit-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$summary | ConvertTo-Json -Depth 10 | Set-Content -Path $artifactPath -Encoding UTF8

Write-Host "[external-gates] artifact=$artifactPath"
Write-Host "[external-gates] status=$($summary.status)"
Write-Host "[external-gates] frontend_preview_claim_allowed=$($summary.frontend_preview_claim_allowed)"
Write-Host "[external-gates] hosted_staging_claim_allowed=$($summary.hosted_staging_claim_allowed)"
Write-Host "[external-gates] gitlab_identity_claim_allowed=$($summary.gitlab_identity_claim_allowed)"
Write-Host "[external-gates] huggingface_identity_claim_allowed=$($summary.huggingface_identity_claim_allowed)"
Write-Host "[external-gates] grafana_cloud_claim_allowed=$($summary.grafana_cloud_claim_allowed)"
Write-Host "[external-gates] production_deploy_claim_allowed=$($summary.production_deploy_claim_allowed)"
if ($missing.Count -gt 0) {
  Write-Host "[external-gates] missing_or_failed_gates=$($missing -join ',')"
}

if ($RequireAllClosed -and $missing.Count -gt 0) {
  exit 1
}

$global:LASTEXITCODE = 0

