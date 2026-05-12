param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)
$ErrorActionPreference = "Stop"
function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) { throw "Verification failed: $label did not contain '$expected'." }
}
function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) { throw "Verification failed: $label expected '$expected' but got '$actual'." }
}
function Get-JsonPy($code) {
  $content = $code | py -3 -
  return ($content | ConvertFrom-Json)
}
$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase4 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_4" }).percent)
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)
$artifactPath = "docs\release-artifacts\$ReleaseId-auth-gate-recheck.md"
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `verified`',
  "release_id: ``$ReleaseId``",
  'auth_contract_version: `auth-github-jwt-refresh-v1`',
  'live_github_oauth_call: `false`',
  "overall_percent: ``$expectedOverall``",
  "phase_4_percent: ``$expectedPhase4``",
  "phase_5_percent: ``$expectedPhase5``"
)) { Assert-Contains "auth gate recheck artifact" $artifact $required }
$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate auth recheck proof linked" $candidate 'auth_gate_recheck_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-auth-gate-recheck.md`'
Assert-Contains "candidate evidence auth recheck proof linked" $candidate 'Auth gate recheck proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-auth-gate-recheck.md`'
$json = @"
import json, urllib.request, urllib.parse, http.cookiejar
base=r'''$BaseUrl'''
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
with opener.open(base + '/api/v1/auth/contract', timeout=20) as r:
    contract=json.load(r)
with opener.open(base + '/api/v1/auth/github', timeout=20) as r:
    start=json.load(r)
callback_url = base + '/api/v1/auth/callback?' + urllib.parse.urlencode({'code':'dry-run','state':start.get('state')})
with opener.open(callback_url, timeout=20) as r:
    callback=json.load(r)
req = urllib.request.Request(base + '/api/v1/auth/refresh', data=json.dumps({'trace_id':'phase5-auth-recheck'}).encode('utf-8'), headers={'Content-Type':'application/json'}, method='POST')
with opener.open(req, timeout=20) as r:
    refresh=json.load(r)
req2 = urllib.request.Request(base + '/api/v1/auth/logout', data=b'', method='POST')
with opener.open(req2, timeout=20) as r:
    logout=json.load(r)
with urllib.request.urlopen(base + '/api/v1/project/progress', timeout=20) as r:
    progress=json.load(r)
with urllib.request.urlopen(base + '/api/v1/project/progress/integrity', timeout=20) as r:
    integrity=json.load(r)
with urllib.request.urlopen(base + '/api/v1/external-gates', timeout=20) as r:
    gates=json.load(r)
print(json.dumps({'contract':contract,'start':start,'callback':callback,'refresh':refresh,'logout':logout,'progress':progress,'integrity':integrity,'gates':gates}))
"@
$result = Get-JsonPy $json
Assert-Equal "auth contract version" $result.contract.contract_version "auth-github-jwt-refresh-v1"
if ($result.contract.live_github_oauth_call -ne $false) { throw "Verification failed: live_github_oauth_call must remain false." }
Assert-Equal "auth github start status" $result.start.status "configuration_required"
Assert-Equal "auth callback status" $result.callback.status "authenticated"
if ($result.callback.refresh_token_issued -ne $true) { throw "Verification failed: auth callback must issue refresh token." }
Assert-Equal "auth refresh status" $result.refresh.status "rotated"
if ($result.refresh.old_refresh_token_blacklisted -ne $true) { throw "Verification failed: old refresh token must be blacklisted." }
Assert-Equal "auth logout status" $result.logout.status "logged_out"
if ($result.logout.refresh_token_revoked -ne $true) { throw "Verification failed: logout must revoke refresh token." }
$phase4 = $result.progress.horizontal.items | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$phase5 = $result.progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1
Assert-Equal "hosted overall percent" $result.progress.overall_percent $expectedOverall
Assert-Equal "hosted phase4 percent" $phase4.percent $expectedPhase4
Assert-Equal "hosted phase5 percent" $phase5.percent $expectedPhase5
Assert-Equal "hosted integrity status" $result.integrity.status "verified"
Assert-Equal "hosted external gates status" $result.gates.status "verified"
Write-Host "[phase5-auth-gate-recheck] verified"
