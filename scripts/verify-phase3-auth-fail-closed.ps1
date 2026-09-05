param(
  [string]$BaseUrl = "http://localhost:8081",
  [string]$OutDir = ".codex\runs\CURRENT\phase3\auth-fail-closed",
  [switch]$AllowLocalhost,
  [switch]$StaticOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Phase 3 auth fail-closed verification failed: $Label" }
  Write-Host "[auth-fail-closed] $Label"
}

function Assert-Equal([string]$Label, $Actual, $Expected) {
  Assert-True "$Label expected '$Expected' got '$Actual'" ($Actual -eq $Expected)
}

function Invoke-Probe(
  [string]$Label,
  [string]$Method,
  [string]$Url,
  [string]$Body = "",
  [string[]]$Headers = @()
) {
  $probeDir = Join-Path ([System.IO.Path]::GetTempPath()) "cloud-superbrain-auth-probes"
  New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
  $id = [Guid]::NewGuid().ToString("N")
  $bodyPath = Join-Path $probeDir "$id-body.json"
  $headerPath = Join-Path $probeDir "$id-headers.txt"
  $requestPath = $null
  $arguments = @("-sS", "--max-time", "30", "--dump-header", $headerPath, "--output", $bodyPath, "--write-out", "%{http_code}", "--request", $Method)
  foreach ($header in $Headers) { $arguments += @("--header", $header) }
  if ($Body) {
    $requestPath = Join-Path $probeDir "$id-request.json"
    Set-Content -LiteralPath $requestPath -Value $Body -Encoding utf8 -NoNewline
    $arguments += @("--header", "Content-Type: application/json", "--data-binary", "@$requestPath")
  }
  $arguments += $Url
  $status = & curl.exe @arguments
  Assert-True "$Label curl exit" ($LASTEXITCODE -eq 0)
  $result = [ordered]@{
    status = [int]$status
    body = Get-Content -LiteralPath $bodyPath -Raw
    headers = Get-Content -LiteralPath $headerPath -Raw
  }
  Remove-Item -LiteralPath $bodyPath, $headerPath -Force -ErrorAction SilentlyContinue
  if ($requestPath) { Remove-Item -LiteralPath $requestPath -Force -ErrorAction SilentlyContinue }
  return $result
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $source = Get-Content -LiteralPath "services\agent-api\app\main.py" -Raw
  foreach ($required in @(
    "AUTH_OAUTH_STATE_PREFIX",
    "AUTH_REFRESH_ACTIVE_PREFIX",
    "AUTH_OAUTH_STATE_COOKIE",
    "AUTH_OAUTH_STATE_PATTERN",
    "AUTH_SIGNING_SECRET_PATTERN",
    "auth_signing_secret_is_strong",
    "consume_oauth_state",
    "consume_refresh_token",
    "oauth_state_cookie_clear_headers",
    "RedirectResponse",
    "credential_issuance_ready",
    "oauth_state_invalid",
    "oauth_callback_parameters_invalid",
    "oauth_provider_denied",
    "refresh_token_body_not_allowed",
    "auth_configuration_required",
    "production_auth_owner_activation_required",
    "auth_audit_unavailable",
    "github_identity_verification_failed",
    "auth_logout_no_active_token",
    '"scope": "read:user"',
    "auth_credential_issuance_fail_closed",
    "oauth_state_one_time_enforced",
    "refresh_token_registry_enforced"
  )) {
    Assert-True "source guard $required" $source.Contains($required)
  }
  foreach ($forbidden in @(
    'create_access_jwt("github:local-contract-user"',
    'supplied_token = (request.refresh_token if request else None) or refresh_token_cookie',
    '"blacklist_key": blacklist_key',
    'phase3-local-dry-run-signing-secret',
    '"authorize_url": authorize_url',
    '"scope": "read:user user:email"',
    '"mode": "local_contract"'
    'jwt_signing_configured = len(signing_secret.encode("utf-8")) >= 32'
  )) {
    Assert-True "unsafe source absent: $forbidden" (-not $source.Contains($forbidden))
  }

  $env:PYTHONPATH = Join-Path $repoRoot "services\agent-api"
  py -3 -m unittest discover -s services\agent-api\tests -p test_auth_security.py
  Assert-True "auth unit tests" ($LASTEXITCODE -eq 0)
  $unitTestSource = Get-Content -LiteralPath "services\agent-api\tests\test_auth_security.py" -Raw
  $unitTestCount = ([regex]::Matches($unitTestSource, '(?m)^\s+def test_')).Count
  Assert-True "auth unit test coverage count" ($unitTestCount -ge 19)
  if ($StaticOnly) {
    Write-Host "[auth-fail-closed] status=verified_static"
    exit 0
  }

  $base = $BaseUrl.TrimEnd("/")
  $isLocal = $base -match '^https?://(localhost|127\.0\.0\.1|\[::1\])(?::\d+)?$'
  if ($isLocal -and -not $AllowLocalhost) {
    throw "Local auth proof requires -AllowLocalhost."
  }

  $contractProbe = Invoke-Probe "contract" "GET" "$base/api/v1/auth/contract"
  Assert-Equal "contract HTTP" $contractProbe.status 200
  $contract = $contractProbe.body | ConvertFrom-Json
  Assert-Equal "contract version" ([string]$contract.contract_version) "auth-github-jwt-refresh-v1"
  Assert-Equal "contract mode" ([string]$contract.mode) "verified_identity_fail_closed"
  Assert-Equal "contract read has no provider call" ([bool]$contract.live_github_oauth_call) $false
  Assert-Equal "OAuth state is one-time" ([bool]$contract.oauth_state.one_time) $true
  Assert-Equal "OAuth state store" ([string]$contract.oauth_state.server_store) "redis"
  Assert-Equal "OAuth start body excludes state" ([bool]$contract.oauth_state.response_body_contains_state) $false
  Assert-Equal "OAuth minimal scope" ([string]$contract.oauth_state.scope) "read:user"
  Assert-Equal "OAuth state format" ([string]$contract.oauth_state.state_format) "phase3-auth-state-<32_urlsafe_chars>"
  Assert-Equal "JWT signing secret format" ([string]$contract.jwt.signing_secret_format) "base64url_256_bit_minimum"
  Assert-Equal "refresh active registry required" ([bool]$contract.refresh_token.active_registry_required) $true
  Assert-Equal "refresh body token disabled" ([bool]$contract.refresh_token.body_token_allowed) $false
  Assert-Equal "refresh signing secret required" ([bool]$contract.refresh_token.signing_secret_required) $true
  Assert-Equal "refresh complete issuance configuration required" ([bool]$contract.refresh_token.complete_issuance_configuration_required) $true
  Assert-Equal "host-prefixed cookies" ([bool]$contract.cookie_flags.host_prefix) $true
  Assert-Equal "credential issuance audit persistence required" ([bool]$contract.audit.credential_issuance_requires_persistence) $true
  Assert-Equal "owner activation is an explicit issuance gate" ([bool]$contract.owner_activation_required) $true
  $ownerActivationBlocked = ([bool]$contract.credentials_configured) -and (-not [bool]$contract.owner_activation_granted)

  if (-not $isLocal) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    $hostedReport = [ordered]@{
      contract_version = "phase3-auth-credential-issuance-fail-closed-v1"
      status = "verified_readonly_contract_only"
      evidence_refs = @(
        "auth_credential_issuance_fail_closed",
        "oauth_state_one_time_enforced",
        "refresh_token_registry_enforced"
      )
      checked_at = [DateTime]::UtcNow.ToString("o")
      base_url = $base
      localhost_dev_only = $false
      source_guards_verified = $true
      unit_tests_passed = $unitTestCount
      contract_read_verified = $true
      runtime_state_mutations = $false
      credentials_issued = $false
      live_github_oauth_call = $false
      provider_write = $false
      secret_output = $false
      production_identity_verified = $false
      hosted_stateful_auth_verified = $false
      non_claims = @(
        "Hosted execution is read-only and does not start OAuth, consume state, rotate refresh tokens, or log out a session.",
        "No GitHub authorization code exchange or provider write is performed by this verifier.",
        "A visible contract does not prove hosted stateful auth or production identity."
      )
    }
    $hostedReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutDir "report.json") -Encoding utf8
    Write-Host "[auth-fail-closed] status=verified_readonly_contract_only hosted_stateful_auth_verified=false"
    exit 0
  }

  $realRedisConcurrencyProbe = @'
from concurrent.futures import ThreadPoolExecutor
import secrets

from app import main

client = main.redis_client()
state = "phase3-auth-state-" + secrets.token_urlsafe(24)
token = main.create_refresh_token()
try:
    main.register_oauth_state(client, state)
    with ThreadPoolExecutor(max_workers=2) as pool:
        state_results = list(pool.map(lambda _index: main.consume_oauth_state(main.redis_client(), state), range(2)))
    assert sorted(state_results) == [False, True], state_results

    main.register_refresh_token(client, token, "github:123")
    with ThreadPoolExecutor(max_workers=2) as pool:
        refresh_results = list(
            pool.map(lambda _index: main.consume_refresh_token(main.redis_client(), token, "concurrency_probe"), range(2))
        )
    successes = [result for result in refresh_results if result == ("github:123", None)]
    rejections = [
        result
        for result in refresh_results
        if result[0] is None and result[1] in {"blacklisted", "unknown"}
    ]
    assert len(successes) == 1, refresh_results
    assert len(rejections) == 1, refresh_results
    assert client.get(main.auth_blacklist_key(token)) == "concurrency_probe"
    print("auth_real_redis_concurrency_verified")
finally:
    client.delete(main.auth_oauth_state_key(state))
    client.delete(main.auth_refresh_active_key(token))
    client.delete(main.auth_blacklist_key(token))
'@
  $realRedisConcurrencyOutput = $realRedisConcurrencyProbe | docker compose -f docker-compose.dev.yml exec -T agent-api python - 2>&1 | Out-String
  Assert-True "real Redis OAuth-state and refresh concurrency" (
    $LASTEXITCODE -eq 0 -and $realRedisConcurrencyOutput.Contains("auth_real_redis_concurrency_verified")
  )

  $startProbe = Invoke-Probe "OAuth start" "GET" "$base/api/v1/auth/github"
  if ([bool]$contract.credential_issuance_ready) {
    $oauthStartGateStatus = "ready_redirect"
    Assert-True "configured start redirect HTTP" ($startProbe.status -in @(302, 303, 307))
    Assert-True "configured start fixed GitHub host" ($startProbe.headers -match '(?im)^Location:\s*https://github\.com/login/oauth/authorize\?')
    Assert-True "configured start minimal scope" ($startProbe.headers -match 'scope=read%3Auser(?:&|\r?$)')
    Assert-True "configured start no email scope" (-not $startProbe.headers.Contains("user%3Aemail"))
    Assert-True "configured start state cookie" $startProbe.headers.Contains("__Host-sb_oauth_state=")
    Assert-True "configured start empty response body" ([string]::IsNullOrWhiteSpace($startProbe.body))
  } else {
    Assert-Equal "OAuth start HTTP" $startProbe.status 200
    $start = $startProbe.body | ConvertFrom-Json
    Assert-Equal "OAuth start issued no credentials" ([bool]$start.credentials_issued) $false
    Assert-Equal "OAuth start made no provider call" ([bool]$start.live_github_oauth_call) $false
    $oauthStartGateStatus = if ($ownerActivationBlocked) { "owner_activation_required" } else { "configuration_required" }
    Assert-Equal "OAuth start blocked by the exact inactive gate" ([string]$start.status) $oauthStartGateStatus
    Assert-Equal "OAuth start configuration truth" ([bool]$start.credentials_configured) ([bool]$contract.credentials_configured)
    Assert-Equal "OAuth start owner activation truth" ([bool]$start.owner_activation_granted) ([bool]$contract.owner_activation_granted)
    Assert-Equal "blocked start state not issued" ([bool]$start.state_issued) $false
  }

  $callbackProbe = Invoke-Probe "arbitrary callback" "GET" "$base/api/v1/auth/callback?code=invalid-proof-code&state=invalid-proof-state"
  if ([bool]$contract.credential_issuance_ready) {
    Assert-Equal "arbitrary callback invalid state HTTP" $callbackProbe.status 401
    Assert-True "arbitrary callback invalid state error" $callbackProbe.body.Contains("oauth_state_invalid")
  } elseif ($ownerActivationBlocked) {
    Assert-Equal "arbitrary callback owner gate HTTP" $callbackProbe.status 403
    Assert-True "arbitrary callback owner gate error" $callbackProbe.body.Contains("production_auth_owner_activation_required")
  } else {
    Assert-Equal "arbitrary callback configuration HTTP" $callbackProbe.status 503
    Assert-True "arbitrary callback configuration error" $callbackProbe.body.Contains("github_oauth_not_configured")
  }
  Assert-True "arbitrary callback issued no credentials" $callbackProbe.body.Contains('"credentials_issued":false')
  Assert-True "arbitrary callback set no access cookie" (-not $callbackProbe.headers.Contains("__Host-sb_access="))
  Assert-True "arbitrary callback set no refresh cookie" (-not $callbackProbe.headers.Contains("__Host-sb_refresh="))
  Assert-True "arbitrary callback clears state cookie" $callbackProbe.headers.Contains('__Host-sb_oauth_state=""')
  Assert-True "arbitrary callback expires state cookie" $callbackProbe.headers.Contains("Max-Age=0")

  $bodyRefreshToken = "csr_" + ("A" * 43)
  $bodyRefresh = @{ refresh_token = $bodyRefreshToken; trace_id = "auth-fail-closed-body" } | ConvertTo-Json -Compress
  $bodyRefreshProbe = Invoke-Probe "body refresh" "POST" "$base/api/v1/auth/refresh" $bodyRefresh
  Assert-Equal "body refresh HTTP" $bodyRefreshProbe.status 400
  Assert-True "body refresh rejected" $bodyRefreshProbe.body.Contains("refresh_token_body_not_allowed")
  Assert-True "body refresh issued no credentials" $bodyRefreshProbe.body.Contains('"credentials_issued":false')

  $cookieRefreshToken = "csr_" + ("B" * 43)
  $cookieRefreshProbe = Invoke-Probe "unknown cookie refresh" "POST" "$base/api/v1/auth/refresh" "" @("Cookie: __Host-sb_refresh=$cookieRefreshToken")
  Assert-Equal "unknown cookie refresh HTTP" $cookieRefreshProbe.status 401
  Assert-True "unknown cookie refresh rejected" $cookieRefreshProbe.body.Contains("refresh_token_invalid")
  Assert-True "unknown cookie refresh reason" $cookieRefreshProbe.body.Contains('"reason":"unknown"')
  # A rejected refresh actively CLEARS stale cookies (empty value + Max-Age=0). That emits a
  # Set-Cookie header for __Host-sb_access, so a plain substring match would flag the hardened
  # behaviour as a failure. What must never happen is the issuance of a real credential, so every
  # access-cookie header on this response is required to be the cleared form.
  $accessCookieHeaders = @(
    $cookieRefreshProbe.headers -split "`r?`n" |
      Where-Object { $_ -match '(?i)^\s*set-cookie:\s*__Host-sb_access=' }
  )
  foreach ($accessCookieHeader in $accessCookieHeaders) {
    Assert-True "unknown cookie refresh issued no access credential" (
      ($accessCookieHeader -match '(?i)__Host-sb_access=(""|)\s*;') -and
      ($accessCookieHeader -match '(?i)max-age=0')
    )
  }

  $logoutToken = "csr_" + ("C" * 43)
  $logoutProbe = Invoke-Probe "unknown cookie logout" "POST" "$base/api/v1/auth/logout" "" @("Cookie: __Host-sb_refresh=$logoutToken")
  Assert-Equal "unknown cookie logout HTTP" $logoutProbe.status 200
  $logout = $logoutProbe.body | ConvertFrom-Json
  Assert-Equal "unknown logout does not claim revoke" ([bool]$logout.refresh_token_revoked) $false
  Assert-Equal "logout body token not accepted" ([bool]$logout.body_token_accepted) $false
  Assert-Equal "unknown logout audit persisted" ([bool]$logout.audit_persisted) $true
  Assert-True "logout exposes no blacklist key" (-not $logoutProbe.body.Contains("blacklist_key"))

  New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
  $report = [ordered]@{
    contract_version = "phase3-auth-credential-issuance-fail-closed-v1"
    status = "verified_dev_only"
    evidence_refs = @(
      "auth_credential_issuance_fail_closed",
      "oauth_state_one_time_enforced",
      "refresh_token_registry_enforced"
    )
    checked_at = [DateTime]::UtcNow.ToString("o")
    base_url = $base
    localhost_dev_only = $isLocal
    source_guards_verified = $true
    unit_tests_passed = $unitTestCount
    real_redis_concurrency_verified = $true
    oauth_start_status = $startProbe.status
    oauth_start_gate_status = $oauthStartGateStatus
    credentials_configured = [bool]$contract.credentials_configured
    owner_activation_granted = [bool]$contract.owner_activation_granted
    credential_issuance_ready = [bool]$contract.credential_issuance_ready
    oauth_start_state_in_json = $false
    oauth_scope = "read:user"
    oauth_state_error_cookie_cleared = $true
    callback_arbitrary_input_status = $callbackProbe.status
    body_refresh_status = $bodyRefreshProbe.status
    unknown_cookie_refresh_status = $cookieRefreshProbe.status
    unknown_cookie_logout_status = $logoutProbe.status
    logout_audit_persisted = $true
    credentials_issued = $false
    live_github_oauth_call = $false
    provider_write = $false
    secret_output = $false
    production_identity_verified = $false
    hosted_stateful_auth_verified = $false
    non_claims = @(
      "DEV-ONLY; hosted proof still blocked.",
      "No GitHub authorization code exchange or provider write is performed by this verifier.",
      "Positive issuance mechanics are unit-tested with a mocked verified identity; no production identity is claimed."
    )
  }
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutDir "report.json") -Encoding utf8
  Write-Host "[auth-fail-closed] status=verified_dev_only credentials_issued=false live_github_oauth_call=false"
  Write-Host "[auth-fail-closed] DEV-ONLY; hosted proof still blocked"
} finally {
  Pop-Location
}
