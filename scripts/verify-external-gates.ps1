param(
  # Public, non-secret hosted origin of the free-tier Vercel contract origin.
  # Committed as a default (same convention as the GitLab/HuggingFace/Grafana/GHCR
  # identities below) so the reproducible no-token bootstrap can probe it.
  # Env STAGING_BASE_URL still overrides. No credential is involved: every probe
  # below is an anonymous HTTPS GET against a public deployment and stays fail-closed.
  [string]$HostedBaseUrl = $(if ($env:STAGING_BASE_URL) { $env:STAGING_BASE_URL } else { "https://cloud-superbrain-developer-platform.vercel.app" }),
  [string]$LocalBaseUrl = "http://localhost:8081",
  [string]$Repository = $(if ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM" }),
  [string]$Branch = $(if ($env:BRANCH_NAME) { $env:BRANCH_NAME } else { "" }),
  [string]$GitLabProfileUrl = $(if ($env:GITLAB_PROFILE_URL) { $env:GITLAB_PROFILE_URL } else { "https://gitlab.com/strazzusochr" }),
  [string]$HuggingFaceProfileUrl = $(if ($env:HF_PROFILE_URL) { $env:HF_PROFILE_URL } else { "https://huggingface.co/Wrzzzrzr" }),
  [string]$grafanaDashboardUrl = $(if ($env:GRAFANA_CLOUD_URL) { $env:GRAFANA_CLOUD_URL } else { "https://cordialtrout569.grafana.net" }),
  [string]$GhcrImageNamespace = $(if ($env:GHCR_IMAGE_NAMESPACE) { $env:GHCR_IMAGE_NAMESPACE } else { "ghcr.io/strazzusochr/cloud-superbrain-developer-platform" }),
  [string]$ImageTag = $(if ($env:IMAGE_TAG) { $env:IMAGE_TAG } else { "staging" }),
  [string]$StagingSshHost = $(if ($env:STAGING_SSH_HOST) { $env:STAGING_SSH_HOST } else { "" }),
  [string]$StagingSshUser = $(if ($env:STAGING_SSH_USER) { $env:STAGING_SSH_USER } else { "" }),
  [string]$StagingSshKeyPath = $(if ($env:STAGING_SSH_KEY_PATH) { $env:STAGING_SSH_KEY_PATH } else { "" }),
  [string]$StagingAppDir = $(if ($env:STAGING_APP_DIR) { $env:STAGING_APP_DIR } else { "/app" }),
  [string]$ArtifactDirectory = ".phase1-artifacts",
  [string]$SummaryPath = "docs\runtime-state\external-gate-summary.json",
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

function Test-RetiredHostedBaseUrl([string]$value) {
  if ([string]::IsNullOrWhiteSpace($value)) {
    return $false
  }
  try {
    $uri = [System.Uri]$value
    $uriHost = $uri.Host.ToLowerInvariant()
    return ($uriHost -eq "188-34-191-140.sslip.io" -or $uriHost.EndsWith(".sslip.io"))
  } catch {
    return $false
  }
}

function Join-OriginProbeUrl([string]$BaseUrl, [string]$OptionalPrefix, [string]$RootHealthPath, [string]$PrefixedHealthPath) {
  $normalized = Normalize-BaseUrl $BaseUrl
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    return $null
  }

  $prefix = $OptionalPrefix.TrimEnd("/")
  if ($prefix -and $normalized.EndsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    return "$normalized$PrefixedHealthPath"
  }

  return "$normalized$RootHealthPath"
}

function Get-TimeoutSeconds([string]$EnvName, [int]$DefaultSeconds) {
  $raw = [Environment]::GetEnvironmentVariable($EnvName, "Process")
  $parsed = 0
  if ([int]::TryParse($raw, [ref]$parsed) -and $parsed -gt 0) {
    return $parsed
  }
  return $DefaultSeconds
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
const timeoutMs = Number(process.env.EXTERNAL_GATE_HTTP_TIMEOUT_MS || '12000');
const startedAt = Date.now();
const signal = AbortSignal.timeout(timeoutMs);
function classifyNetworkError(error) {
  const code = error?.cause?.code || error?.code || '';
  const name = error?.name || '';
  const message = error?.message || '';
  if (name === 'TimeoutError' || name === 'AbortError' || code === 'UND_ERR_CONNECT_TIMEOUT' || code === 'ETIMEDOUT') return 'timeout';
  if (code === 'ENOTFOUND' || code === 'EAI_AGAIN') return 'dns';
  if (code === 'ECONNREFUSED') return 'connection_refused';
  if (code === 'ECONNRESET' || code === 'EPIPE') return 'connection_reset';
  if (code.includes('CERT') || message.toLowerCase().includes('certificate')) return 'tls';
  if (message.toLowerCase().includes('fetch failed')) return 'network_error';
  return 'unknown_network_error';
}
fetch(url, { signal }).then(async (response) => {
  const body = await response.text();
  const hasRequiredText = requiredText ? body.includes(requiredText) : true;
  console.log(JSON.stringify({
    status: response.status,
    ok: response.status >= 200 && response.status < 300 && hasRequiredText,
    hasRequiredText,
    bytes: body.length,
    elapsedMs: Date.now() - startedAt,
    responseUrl: response.url,
    contentType: response.headers.get('content-type') || '',
    snippet: body.slice(0, 160).replace(/\s+/g, ' ')
  }));
}).catch((error) => {
  console.log(JSON.stringify({
    status: 0,
    ok: false,
    hasRequiredText: false,
    bytes: 0,
    elapsedMs: Date.now() - startedAt,
    responseUrl: url,
    error: error.message,
    errorName: error.name || '',
    errorCode: error?.cause?.code || error.code || '',
    networkClassification: classifyNetworkError(error)
  }));
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
    $networkClassification = if ($probe.networkClassification) { [string]$probe.networkClassification } else { "" }
    $probeStatus = if ($ok) { "verified" } elseif ($networkClassification -eq "timeout") { "timeout" } else { "failed" }
    $result = New-Probe $Id $probeStatus $true $ok $EvidenceRef $Url $statusCode $message $errorText
    $result["bytes"] = [int]$probe.bytes
    $result["has_required_text"] = [bool]$probe.hasRequiredText
    if ($null -ne $probe.elapsedMs) {
      $result["elapsed_ms"] = [int]$probe.elapsedMs
    }
    if ($probe.responseUrl) {
      $result["response_url"] = [string]$probe.responseUrl
    }
    if ($probe.contentType) {
      $result["content_type"] = [string]$probe.contentType
    }
    if ($networkClassification) {
      $result["network_classification"] = $networkClassification
    }
    if ($probe.errorName) {
      $result["error_name"] = [string]$probe.errorName
    }
    if ($probe.errorCode) {
      $result["error_code"] = [string]$probe.errorCode
    }
    if ($probe.snippet) {
      $result["snippet"] = [string]$probe.snippet
    }
    return $result
  } catch {
    return New-Probe $Id "failed" $true $false $EvidenceRef $Url 0 "node fetch probe failed" ($raw.Trim())
  }
}

function Invoke-JsonProbe([string]$Url) {
  $nodeScript = @'
const url = process.argv[1];
const timeoutMs = Number(process.env.EXTERNAL_GATE_HTTP_TIMEOUT_MS || '12000');
const signal = AbortSignal.timeout(timeoutMs);
fetch(url, { signal }).then(async (response) => {
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
const timeoutMs = Number(process.env.EXTERNAL_GATE_HTTP_TIMEOUT_MS || '12000');
const signal = AbortSignal.timeout(timeoutMs);
fetch('https://gitlab.com/api/v4/user', {
  headers: { 'PRIVATE-TOKEN': token },
  signal
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
const timeoutMs = Number(process.env.EXTERNAL_GATE_HTTP_TIMEOUT_MS || '12000');
const signal = AbortSignal.timeout(timeoutMs);
fetch('https://huggingface.co/api/whoami-v2', {
  headers: { Authorization: `Bearer ${token}` },
  signal
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

  try {
    $uri = [System.Uri]$GrafanaUrl
  } catch {
    return New-Probe "grafana_cloud" "failed" $true $false "grafana_cloud_optional_proof" $GrafanaUrl 0 "Grafana Cloud URL is invalid" "invalid_url"
  }
  if ($uri.Scheme -ne "https") {
    return New-Probe "grafana_cloud" "failed" $true $false "grafana_cloud_optional_proof" $GrafanaUrl 0 "Grafana Cloud URL must use HTTPS" "non_https_url"
  }

  $token = [string]$env:GRAFANA_CLOUD_API_KEY
  try {
    $probeKind = ""
    if ($token.StartsWith("glc_")) {
      $encoded = $token.Substring(4).Replace("-", "+").Replace("_", "/")
      switch ($encoded.Length % 4) {
        0 { }
        2 { $encoded += "==" }
        3 { $encoded += "=" }
        default { throw "Grafana Cloud token metadata has invalid base64 length" }
      }
      $metadataJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encoded))
      $metadata = $metadataJson | ConvertFrom-Json -ErrorAction Stop
      $region = [string]$metadata.m.r
      if ($region -notmatch '^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$') {
        throw "Grafana Cloud token region is missing or invalid"
      }
      $probeUrl = "https://grafana.com/api/v1/accesspolicies?region=$([System.Uri]::EscapeDataString($region))&pageSize=1"
      $probeKind = "cloud_access_policy"
    } elseif ($token.StartsWith("glsa_")) {
      if (-not $uri.Host.EndsWith(".grafana.net", [System.StringComparison]::OrdinalIgnoreCase) -or $uri.UserInfo -or ($uri.Port -notin @(443, -1))) {
        throw "Grafana instance URL must be an HTTPS grafana.net host"
      }
      $probeUrl = "$($GrafanaUrl.TrimEnd('/'))/api/access-control/user/permissions"
      $probeKind = "service_account"
    } else {
      throw "Grafana token must start with glc_ or glsa_"
    }

    $null = Invoke-RestMethod -Method Get -Uri $probeUrl -Headers @{
      Authorization = "Bearer $token"
      Accept = "application/json"
    } -TimeoutSec 20 -ErrorAction Stop

    $result = New-Probe "grafana_cloud" "verified" $true $true "grafana_cloud_optional_proof" $GrafanaUrl 200 "Grafana Cloud identity checked without storing token" ""
    $result["probe_kind"] = $probeKind
    return $result
  } catch {
    $statusCode = 0
    try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { $statusCode = 0 }
    $errorText = [string]$_.Exception.Message
    if (-not [string]::IsNullOrWhiteSpace($token)) {
      $errorText = $errorText.Replace($token, "[redacted-token]")
    }
    return New-Probe "grafana_cloud" "failed" $true $false "grafana_cloud_optional_proof" $GrafanaUrl $statusCode "Grafana Cloud identity probe failed" $errorText
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

function Invoke-BoundedNativeCommand([string]$FilePath, [string[]]$Arguments, [int]$TimeoutSeconds) {
  $timeout = [Math]::Max(1, $TimeoutSeconds)
  $argumentText = (@($Arguments) | ForEach-Object {
    $value = [string]$_
    if ($value -match '[\s"]') {
      '"' + ($value -replace '"', '\"') + '"'
    } else {
      $value
    }
  }) -join " "

  $stdoutPath = [System.IO.Path]::GetTempFileName()
  $stderrPath = [System.IO.Path]::GetTempFileName()
  $process = $null
  try {
    $process = Start-Process -FilePath $FilePath -ArgumentList $argumentText -WorkingDirectory (Get-Location).Path -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru
    $completed = $process.WaitForExit($timeout * 1000)
    if (-not $completed) {
      try {
        $process.Kill($true)
      } catch {
        try { $process.Kill() } catch {}
      }
      $output = "$(Get-Content -Raw -LiteralPath $stdoutPath -ErrorAction SilentlyContinue) $(Get-Content -Raw -LiteralPath $stderrPath -ErrorAction SilentlyContinue)".Trim()
      return [ordered]@{
        exit_code = 124
        timed_out = $true
        output = "timed out after ${timeout}s $output".Trim()
      }
    }
    $output = "$(Get-Content -Raw -LiteralPath $stdoutPath -ErrorAction SilentlyContinue) $(Get-Content -Raw -LiteralPath $stderrPath -ErrorAction SilentlyContinue)".Trim()
    return [ordered]@{
      exit_code = [int]$process.ExitCode
      timed_out = $false
      output = $output
    }
  } catch {
    return [ordered]@{
      exit_code = 1
      timed_out = $false
      output = $_.Exception.Message
    }
  } finally {
    if ($process) {
      $process.Dispose()
    }
    Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-NativeProcessProbe(
  [string]$Id,
  [string]$EvidenceRef,
  [string]$FilePath,
  [string[]]$Arguments,
  [bool]$Configured,
  [int]$TimeoutSeconds
) {
  if (-not $Configured) {
    return New-Probe $Id "missing_secret_or_binary" $false $false $EvidenceRef "" 0 "required input is not configured" ""
  }

  $nativeResult = Invoke-BoundedNativeCommand $FilePath $Arguments $TimeoutSeconds
  $ok = ([int]$nativeResult.exit_code -eq 0) -and -not [bool]$nativeResult.timed_out
  $excerpt = ([string]$nativeResult.output -replace "\r?\n", " ").Trim()
  return [ordered]@{
    id = $Id
    status = if ($nativeResult.timed_out) { "timeout" } elseif ($ok) { "verified" } else { "failed" }
    configured = $true
    claim_allowed = $ok
    evidence_ref = $EvidenceRef
    exit_code = [int]$nativeResult.exit_code
    timeout_seconds = $TimeoutSeconds
    output_excerpt = $excerpt.Substring(0, [Math]::Min(600, $excerpt.Length))
  }
}

function Invoke-GhcrDigestProbe([string]$Namespace, [string]$Tag) {
  $dockerAvailable = [bool](Get-Command docker -ErrorAction SilentlyContinue)
  if (-not $dockerAvailable) {
    return New-Probe "ghcr_image_digest_verify" "missing_secret_or_binary" $false $false "ghcr_image_digest_proof" "" 0 "docker is required to verify GHCR image digests" ""
  }
  if ([string]::IsNullOrWhiteSpace($Namespace)) {
    return New-Probe "ghcr_image_digest_verify" "missing_secret_or_url" $false $false "ghcr_image_digest_proof" "" 0 "GHCR image namespace is not configured. Set env:GHCR_IMAGE_NAMESPACE (example: ghcr.io/<owner>/<repo>)" ""
  }

  $services = @("frontend", "agent-api", "agent-worker", "memory-worker", "mcp-gateway", "llm-gateway")
  $digests = @()
  $inspectTimeoutSeconds = Get-TimeoutSeconds "EXTERNAL_GATE_DOCKER_TIMEOUT_SECONDS" 45
  foreach ($service in $services) {
    $imageRef = "$Namespace/$service`:$Tag"
    $dockerResult = Invoke-BoundedNativeCommand "docker" @("buildx", "imagetools", "inspect", $imageRef) $inspectTimeoutSeconds
    $raw = [string]$dockerResult.output
    $dockerExitCode = [int]$dockerResult.exit_code
    if ($dockerResult.timed_out) {
      return New-Probe "ghcr_image_digest_verify" "timeout" $true $false "ghcr_image_digest_proof" "" 0 "GHCR digest inspection timed out for $service after ${inspectTimeoutSeconds}s" ($raw.Trim())
    }
    if ($dockerExitCode -ne 0) {
      if ($raw -match "unauthorized|denied|authentication|forbidden") {
        return New-Probe "ghcr_image_digest_verify" "missing_secret_or_token" $true $false "ghcr_image_digest_proof" "" 0 "GHCR digest verification is BLOCKED. Authenticate Docker for GHCR (docker login ghcr.io) with a token that has read:packages, then re-run verify:external-gates." ($raw.Trim())
      }
      return New-Probe "ghcr_image_digest_verify" "failed" $true $false "ghcr_image_digest_proof" "" 0 "GHCR digest inspection failed" ($raw.Trim())
    }
    $match = [regex]::Match($raw, "Digest:\s*(sha256:[0-9a-f]{64})", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
      return New-Probe "ghcr_image_digest_verify" "failed" $true $false "ghcr_image_digest_proof" "" 0 "GHCR digest inspection did not return a digest" ($raw.Trim())
    }
    $digests += "$service=$($match.Groups[1].Value)"
  }

  $result = New-Probe "ghcr_image_digest_verify" "verified" $true $true "ghcr_image_digest_proof" "" 200 "GHCR digests resolved for all service images" ""
  $result["digests"] = $digests
  return $result
}

function Invoke-PublicBranchProtectionProbe([string]$Repository, [string]$Branch) {
  # Token-free baseline for PUBLIC repositories. GitHub exposes branch protection
  # ENABLEMENT and the required status-check contexts anonymously on public repos.
  # This proves protection is on and fail-closes the moment anyone disables it.
  # It deliberately does NOT claim the review/force-push/deletion settings: those stay
  # anonymous-invisible and remain the stronger BRANCH_PROTECTION_TOKEN verification.
  $probeId = "github_branch_protection_verify"
  $evidence = "branch_protection_verify_contract"
  $blockedMessage = "Branch protection verify is BLOCKED. Set env:BRANCH_PROTECTION_TOKEN to verify the full protection contract via the GitHub API."
  try {
    $repoUrl = "https://api.github.com/repos/$Repository"
    $repoInfo = Invoke-RestMethod -Uri $repoUrl -Method Get -Headers @{ Accept = "application/vnd.github+json"; "X-GitHub-Api-Version" = "2022-11-28" } -TimeoutSec 30
    if ([bool]$repoInfo.private) {
      return New-Probe $probeId "missing_secret_or_token" $false $false $evidence "" 0 $blockedMessage ""
    }
    $branchUrl = "https://api.github.com/repos/$Repository/branches/" + [uri]::EscapeDataString($Branch)
    $branchInfo = Invoke-RestMethod -Uri $branchUrl -Method Get -Headers @{ Accept = "application/vnd.github+json"; "X-GitHub-Api-Version" = "2022-11-28" } -TimeoutSec 30
    $protection = $branchInfo.protection
    $contexts = @()
    if ($protection -and $protection.required_status_checks -and $protection.required_status_checks.contexts) {
      $contexts = @($protection.required_status_checks.contexts | ForEach-Object { [string]$_ })
    }
    $enforcement = ""
    if ($protection -and $protection.required_status_checks) {
      $enforcement = [string]$protection.required_status_checks.enforcement_level
    }
    $ok = ([bool]$branchInfo.protected) -and ($protection -and [bool]$protection.enabled) -and ($contexts -contains "verify") -and ($enforcement -ne "off")
    $status = if ($ok) { "verified" } else { "failed" }
    $message = if ($ok) {
      "public repository branch protection is enabled with required status check 'verify' (anonymous subset; review/force-push/deletion settings are not anonymously readable and require BRANCH_PROTECTION_TOKEN)"
    } else {
      "public repository branch protection is NOT enabled or is missing the required 'verify' status check on $Branch"
    }
    $result = New-Probe $probeId $status $true $ok $evidence $branchUrl 200 $message ""
    $result["verification_scope"] = "public_anonymous_subset"
    $result["protected"] = [bool]$branchInfo.protected
    $result["required_status_check_contexts"] = $contexts
    $result["enforcement_level"] = $enforcement
    $result["non_claims"] = @(
      "Anonymous verification proves protection enablement and required status checks only.",
      "required_pull_request_reviews, allow_force_pushes, allow_deletions and lock_branch are NOT anonymously readable and are NOT claimed here.",
      "Full protection-contract parity requires env:BRANCH_PROTECTION_TOKEN."
    )
    return $result
  } catch {
    return New-Probe $probeId "missing_secret_or_token" $false $false $evidence "" 0 $blockedMessage ""
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
    return New-Probe "github_branch_protection_verify" "missing_secret_or_token" $false $false "branch_protection_verify_contract" "" 0 "Branch protection verify is BLOCKED. Set env:BRANCH_PROTECTION_TOKEN (recommended) to verify via GitHub API, or configure env:STAGING_SSH_HOST/env:STAGING_SSH_USER/env:STAGING_SSH_KEY_PATH/env:STAGING_APP_DIR for remote --verify-only." ""
  }
  if (-not (Test-Path $KeyPath)) {
    return New-Probe "github_branch_protection_verify" "missing_secret_or_binary" $false $false "branch_protection_verify_contract" "" 0 "Branch protection verify remote key missing. Set env:STAGING_SSH_KEY_PATH to an existing private key or set env:BRANCH_PROTECTION_TOKEN to verify via API." ""
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

if ($hostedBase -and (Test-RetiredHostedBaseUrl $hostedBase)) {
  $hostedProbes = @(
    (New-Probe "hosted_staging_base_url" "retired_provider_url" $true $false "hosted_staging_base_url_required" $hostedBase 0 "Hosted staging is BLOCKED. The configured STAGING_BASE_URL is a retired sslip.io/Hetzner-era target; set it to the real Vercel HTTPS staging URL." "")
  )
} elseif ($hostedBase) {
  $hostedProbes = @(
    (Invoke-HttpProbe "hosted_frontend_root" "$hostedBase/" "" "hosted_frontend_preview_visible"),
    (Invoke-HttpProbe "hosted_frontend_health" "$hostedBase/health" "" "hosted_frontend_health_visible"),
    (Invoke-HttpProbe "hosted_agent_api_health" "$hostedBase/api/v1/health" "agent-api" "hosted_agent_api_health_required"),
    (Invoke-HttpProbe "hosted_cloud_provider_inventory" "$hostedBase/api/v1/clouds" "cloud-provider-inventory-v1" "hosted_cloud_provider_inventory_required"),
    (Invoke-HttpProbe "hosted_cloud_layer_readiness" "$hostedBase/api/v1/clouds/layers" "cloud-layer-readiness-v1" "hosted_cloud_layer_readiness_required"),
    (Invoke-HttpProbe "hosted_cloud_deployment_preflight" "$hostedBase/api/v1/clouds/deployment-preflight/contract" "cloud-deployment-preflight-v1" "hosted_cloud_deployment_preflight_required"),
    (Invoke-HttpProbe "hosted_project_progress_integrity" "$hostedBase/api/v1/project/progress/integrity" "project-progress-integrity-v1" "hosted_progress_integrity_contract_required"),
    (Invoke-HttpProbe "hosted_project_progress_completion" "$hostedBase/api/v1/project/progress/completion" "project-progress-100-percent-contract-v1" "hosted_progress_completion_contract_required"),
    (Invoke-HttpProbe "hosted_external_gates" "$hostedBase/api/v1/external-gates" "external-gates-state-v1" "hosted_external_gate_state_required")
  )
} else {
  $hostedProbes = @(
    (New-Probe "hosted_staging_base_url" "missing_secret_or_url" $false $false "hosted_staging_base_url_required" "" 0 "Hosted staging is BLOCKED. Set env:STAGING_BASE_URL to the real HTTPS staging base URL (example: https://staging.example.com)." "")
  )
}

$gitleaksCommand = Get-Command gitleaks -ErrorAction SilentlyContinue
$repoLocalGitleaks = Join-Path ".tools\gitleaks" "gitleaks.exe"
$gitleaksExecutable = if ($gitleaksCommand) { "gitleaks" } elseif (Test-Path $repoLocalGitleaks) { $repoLocalGitleaks } else { $null }
if ($gitleaksExecutable) {
  $gitleaksScanRoot = $null
  try {
    $repoRoot = (Resolve-Path ".").Path
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $gitleaksScanRoot = Join-Path $tempRoot ("superbrain-external-gitleaks-scan-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $gitleaksScanRoot | Out-Null
    $trackedAndUntrackedFiles = git ls-files -z --cached --others --exclude-standard
    if ($LASTEXITCODE -ne 0) {
      throw "git ls-files for external gitleaks scan failed"
    }
    $scanFileCount = 0
    foreach ($relativePath in ($trackedAndUntrackedFiles -split "`0")) {
      if ([string]::IsNullOrWhiteSpace($relativePath)) { continue }
      $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $relativePath))
      if (-not $sourcePath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "gitleaks source escaped repo root: $relativePath"
      }
      if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { continue }
      $targetPath = [System.IO.Path]::GetFullPath((Join-Path $gitleaksScanRoot $relativePath))
      if (-not $targetPath.StartsWith($gitleaksScanRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "gitleaks target escaped scan root: $relativePath"
      }
      $targetParent = Split-Path -Parent $targetPath
      if (-not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
      }
      Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
      $scanFileCount += 1
    }
    if ($scanFileCount -lt 100) {
      throw "external gitleaks scan mirror unexpectedly small: $scanFileCount files"
    }
    $gitleaksProbe = Invoke-NativeProcessProbe "canonical_gitleaks_scan" "canonical_gitleaks_scan_clean" $gitleaksExecutable @("detect", "--no-git", "--source", $gitleaksScanRoot, "--config", ".gitleaks.toml", "--redact", "--timeout", "600") $true (Get-TimeoutSeconds "EXTERNAL_GATE_GITLEAKS_TIMEOUT_SECONDS" 900)
    $gitleaksProbe["scan_file_count"] = $scanFileCount
  } catch {
    $gitleaksProbe = New-Probe "canonical_gitleaks_scan" "failed" $true $false "canonical_gitleaks_scan_clean" "" 0 "canonical gitleaks scan preparation failed" $_.Exception.Message
  } finally {
    if ($gitleaksScanRoot -and (Test-Path -LiteralPath $gitleaksScanRoot)) {
      $resolvedScanRoot = (Resolve-Path -LiteralPath $gitleaksScanRoot).Path
      $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
      if (-not $resolvedScanRoot.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove non-temp external gitleaks scan root: $resolvedScanRoot"
      }
      Remove-Item -LiteralPath $resolvedScanRoot -Recurse -Force
    }
  }
} else {
  $gitleaksProbe = Invoke-NativeProcessProbe "canonical_gitleaks_scan" "canonical_gitleaks_scan_clean" $gitleaksExecutable @("detect", "--no-git", "--source", ".", "--config", ".gitleaks.toml", "--redact") $false (Get-TimeoutSeconds "EXTERNAL_GATE_GITLEAKS_TIMEOUT_SECONDS" 900)
}

$branchTokenConfigured = [bool]$env:BRANCH_PROTECTION_TOKEN
if ($branchTokenConfigured) {
  $branchProtectionProbe = Invoke-NativeProcessProbe "github_branch_protection_verify" "branch_protection_verify_contract" "py" @("-3", "scripts\apply_github_branch_protection.py", "--verify-only", "--repo", $Repository, "--branch", $Branch) $true (Get-TimeoutSeconds "EXTERNAL_GATE_BRANCH_TIMEOUT_SECONDS" 60)
} else {
  # Token-free path: public repositories expose protection enablement anonymously.
  # Fall back to the SSH-based full verification only if the anonymous probe cannot decide.
  $branchProtectionProbe = Invoke-PublicBranchProtectionProbe $Repository $Branch
  if (-not $branchProtectionProbe.claim_allowed) {
    $remoteBranchProtectionProbe = Invoke-RemoteBranchProtectionProbe $Repository $Branch $StagingSshHost $StagingSshUser $StagingSshKeyPath $StagingAppDir
    if ($remoteBranchProtectionProbe.claim_allowed) {
      $branchProtectionProbe = $remoteBranchProtectionProbe
    }
  }
}

$ghcrProbe = Invoke-GhcrDigestProbe $GhcrImageNamespace $ImageTag

# Public, non-secret consolidated free-tier origins. Env vars still override.
# These are anonymous HTTPS health probes with required response markers; if the
# deployment breaks or drifts, the probe fails and the gate closes again.
$publicBackendOrigin = "https://cloud-superbrain-developer-platform.vercel.app"
$originUrls = @(
  @{ id = "vercel_agent_api_origin"; url = $(if ($env:AGENT_API_BASE_URL) { $env:AGENT_API_BASE_URL } else { $publicBackendOrigin }); prefix = "/api"; root_health = "/api/v1/health"; prefixed_health = "/v1/health"; marker = "agent-api" },
  @{ id = "vercel_mcp_gateway_origin"; url = $(if ($env:MCP_GATEWAY_BASE_URL) { $env:MCP_GATEWAY_BASE_URL } else { "$publicBackendOrigin/mcp" }); prefix = "/mcp"; root_health = "/api/v1/health"; prefixed_health = "/api/v1/health"; marker = "mcp-gateway" },
  @{ id = "vercel_llm_gateway_origin"; url = $(if ($env:LLM_GATEWAY_BASE_URL) { $env:LLM_GATEWAY_BASE_URL } else { "$publicBackendOrigin/llm" }); prefix = "/llm"; root_health = "/api/v1/health"; prefixed_health = "/api/v1/health"; marker = "llm-gateway" }
)
$vercelOriginProbes = @()
foreach ($origin in $originUrls) {
  $originId = [string]$origin["id"]
  $originPrefix = [string]$origin["prefix"]
  $originRootHealthPath = [string]$origin["root_health"]
  $originPrefixedHealthPath = [string]$origin["prefixed_health"]
  $originMarker = [string]$origin["marker"]
  $normalizedOrigin = Normalize-BaseUrl $origin["url"]
  if (-not $normalizedOrigin) {
    $requiredEnv = switch ($originId) {
      "vercel_agent_api_origin" { "AGENT_API_BASE_URL" }
      "vercel_mcp_gateway_origin" { "MCP_GATEWAY_BASE_URL" }
      "vercel_llm_gateway_origin" { "LLM_GATEWAY_BASE_URL" }
      default { "AGENT_API_BASE_URL / MCP_GATEWAY_BASE_URL / LLM_GATEWAY_BASE_URL" }
    }
    $vercelOriginProbes += New-Probe $originId "missing_secret_or_url" $false $false "vercel_backend_origin_required" "" 0 "Vercel origin is BLOCKED. Set env:$requiredEnv to the real HTTPS origin URL for $originId." ""
    continue
  }
  Assert-HostedBaseUrlSafe $normalizedOrigin
  $originHealthUrl = Join-OriginProbeUrl $normalizedOrigin $originPrefix $originRootHealthPath $originPrefixedHealthPath
  $vercelOriginProbes += Invoke-HttpProbe $originId $originHealthUrl $originMarker "vercel_backend_origin_required"
}
$vercelOriginsClaimAllowed = @($vercelOriginProbes | Where-Object { $_.claim_allowed }).Count -eq $originUrls.Count

$flyTokenConfigured = [bool]$env:FLY_API_TOKEN
$flyBudgetScript = Join-Path $PSScriptRoot "check_fly_infra_budget.py"
if (-not (Test-Path -LiteralPath $flyBudgetScript)) {
  $flyProbe = New-Probe "fly_live_budget_check" "missing_secret_or_binary" $false $false "fly_live_budget_check" "" 0 "Fly.io live budget verifier script is missing." ""
} elseif ($flyTokenConfigured) {
  $flyProbe = Invoke-NativeProcessProbe "fly_live_budget_check" "fly_live_budget_check" "py" @("-3", $flyBudgetScript) $true (Get-TimeoutSeconds "EXTERNAL_GATE_FLY_TIMEOUT_SECONDS" 60)
} else {
  $flyProbe = New-Probe "fly_live_budget_check" "missing_secret_or_token" $false $false "fly_live_budget_check" "" 0 "Fly.io live budget is BLOCKED. Set env:FLY_API_TOKEN to a real Fly.io API token." ""
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
$failedHostedRequiredIds = @($hostedApiRequiredIds | Where-Object {
  $requiredId = $_
  @($hostedProbes | Where-Object { $_.id -eq $requiredId -and $_.claim_allowed }).Count -eq 0
})
$failedVercelOriginIds = @($vercelOriginProbes | Where-Object { -not $_.claim_allowed } | ForEach-Object { [string]$_.id })
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
  status = if ($missing.Count -eq 0) { "verified" } else { "blocked" }
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
  failed_hosted_required_probe_ids = $failedHostedRequiredIds
  failed_vercel_origin_probe_ids = $failedVercelOriginIds
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

$runtimeSummary = [ordered]@{
  contract_version = "external-gate-summary-v1"
  source_contract_version = [string]$summary.contract_version
  source_artifact = $artifactPath
  generated_at_utc = [string]$summary.generated_at_utc
  status = [string]$summary.status
  gate_ids = @(
    "hosted_agent_api_contracts",
    "github_branch_protection_current_verify",
    "vercel_backend_origin_health",
    "fly_live_budget_check"
  )
  frontend_preview_claim_allowed = [bool]$summary.frontend_preview_claim_allowed
  hosted_staging_claim_allowed = [bool]$summary.hosted_staging_claim_allowed
  branch_protection_claim_allowed = [bool]$summary.branch_protection_claim_allowed
  ghcr_image_digest_claim_allowed = [bool]$summary.ghcr_image_digest_claim_allowed
  vercel_backend_origins_claim_allowed = [bool]$summary.vercel_backend_origins_claim_allowed
  canonical_gitleaks_claim_allowed = [bool]$summary.canonical_gitleaks_claim_allowed
  fly_live_budget_claim_allowed = [bool]$summary.fly_live_budget_claim_allowed
  gitlab_identity_claim_allowed = [bool]$summary.gitlab_identity_claim_allowed
  huggingface_identity_claim_allowed = [bool]$summary.huggingface_identity_claim_allowed
  grafana_cloud_claim_allowed = [bool]$summary.grafana_cloud_claim_allowed
  production_deploy_claim_allowed = [bool]$summary.production_deploy_claim_allowed
  missing_or_failed_gates = @($summary.missing_or_failed_gates | ForEach-Object { [string]$_ })
  failed_hosted_required_probe_ids = @($summary.failed_hosted_required_probe_ids | ForEach-Object { [string]$_ })
  failed_vercel_origin_probe_ids = @($summary.failed_vercel_origin_probe_ids | ForEach-Object { [string]$_ })
  non_claims = @(
    "This is a sanitized runtime summary, not the full audit artifact.",
    "Probe snippets, URLs, logs, and token values are not included.",
    "No hosted, production, branch-protection, Fly budget, or Vercel-origin claim is allowed while missing_or_failed_gates is non-empty."
  )
}
$summaryDir = Split-Path -Parent $SummaryPath
if (-not [string]::IsNullOrWhiteSpace($summaryDir)) {
  New-Item -ItemType Directory -Force -Path $summaryDir | Out-Null
}
$runtimeSummary | ConvertTo-Json -Depth 6 | Set-Content -Path $SummaryPath -Encoding UTF8

Write-Host "[external-gates] artifact=$artifactPath"
Write-Host "[external-gates] summary=$SummaryPath"
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

