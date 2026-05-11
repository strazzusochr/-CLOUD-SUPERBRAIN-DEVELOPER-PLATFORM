param(
  [string]$BaseUrl = $env:STAGING_BASE_URL
)

$ErrorActionPreference = "Stop"

if (-not $BaseUrl) {
  throw "STAGING_BASE_URL is required"
}

$BaseUrl = $BaseUrl.TrimEnd("/")

$progressManifestPath = Join-Path $PSScriptRoot "..\docs\project-progress.manifest.json"
$progressManifest = Get-Content -Path $progressManifestPath -Raw | ConvertFrom-Json
$expectedOverallPercent = [int]$progressManifest.overall_percent

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Hosted staging smoke verification failed: $label did not contain '$expected'. Value: $text"
  }
}

function Invoke-JsonRequest($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $timeoutSeconds = 20) {
  $payload = [pscustomobject]@{
    url = $url
    method = $method
    body = $body
    headers = $headers
    timeoutSeconds = $timeoutSeconds
  } | ConvertTo-Json -Depth 8 -Compress
  $python = @'
import json
import sys
import base64
import urllib.error
import urllib.request

payload = json.loads(base64.b64decode(sys.argv[1]).decode("utf-8"))
headers = payload.get("headers") or {}
data = payload.get("body")
if data is not None:
    data = json.dumps(data).encode("utf-8")
    if "Content-Type" not in headers and "content-type" not in headers:
        headers["Content-Type"] = "application/json"
request = urllib.request.Request(
    payload["url"],
    data=data,
    headers=headers,
    method=payload.get("method", "GET"),
)
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 20)) as response:
        result = {
            "status": response.getcode(),
            "body": response.read().decode("utf-8", errors="replace"),
        }
except urllib.error.HTTPError as error:
    result = {
        "status": error.code,
        "body": error.read().decode("utf-8", errors="replace"),
    }
print(json.dumps(result))
'@
  $payload64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payload))
  $raw = $python | py -3 - $payload64
  return ($raw | ConvertFrom-Json)
}

Write-Host "[hosted-smoke] base url: $BaseUrl"

$root = Invoke-JsonRequest -url "$BaseUrl/"
if ($root.status -ne 200) {
  throw "Hosted staging smoke verification failed: root returned HTTP $($root.status)"
}
Assert-Contains "root title" $root.body "Cloud Superbrain"

$nginxHealth = Invoke-JsonRequest -url "$BaseUrl/health"
if ($nginxHealth.status -ne 200) {
  throw "Hosted staging smoke verification failed: /health returned HTTP $($nginxHealth.status)"
}
Assert-Contains "nginx health body" $nginxHealth.body "ok"

$apiHealth = Invoke-JsonRequest -url "$BaseUrl/api/v1/health"
if ($apiHealth.status -ne 200) {
  throw "Hosted staging smoke verification failed: /api/v1/health returned HTTP $($apiHealth.status)"
}
Assert-Contains "api health status" $apiHealth.body '"status":"healthy"'

$progress = Invoke-JsonRequest -url "$BaseUrl/api/v1/project/progress"
if ($progress.status -ne 200) {
  throw "Hosted staging smoke verification failed: /api/v1/project/progress returned HTTP $($progress.status)"
}
Assert-Contains "project progress overall" $progress.body ('"overall_percent":{0}' -f $expectedOverallPercent)

$integrity = Invoke-JsonRequest -url "$BaseUrl/api/v1/project/progress/integrity"
if ($integrity.status -ne 200) {
  throw "Hosted staging smoke verification failed: /api/v1/project/progress/integrity returned HTTP $($integrity.status)"
}
Assert-Contains "progress integrity status" $integrity.body '"status":"verified"'
Assert-Contains "progress integrity manifest" $integrity.body ('"manifest_overall_percent":{0}' -f $expectedOverallPercent)

$externalGates = Invoke-JsonRequest -url "$BaseUrl/api/v1/external-gates"
if ($externalGates.status -ne 200) {
  throw "Hosted staging smoke verification failed: /api/v1/external-gates returned HTTP $($externalGates.status)"
}
Assert-Contains "external gates status" $externalGates.body '"status":"verified"'
Assert-Contains "external gates blocked cleared" $externalGates.body '"blocked_release_gates":[]'

$externalGateMirror = Invoke-JsonRequest -url "$BaseUrl/api/v1/external-gates/mirror"
if ($externalGateMirror.status -ne 200) {
  throw "Hosted staging smoke verification failed: /api/v1/external-gates/mirror returned HTTP $($externalGateMirror.status)"
}
Assert-Contains "external gate mirror status" $externalGateMirror.body '"status":"verified"'
Assert-Contains "external gate mirror hosted claim" $externalGateMirror.body '"hosted_staging_claim_allowed":true'
Assert-Contains "external gate mirror production claim" $externalGateMirror.body '"production_deploy_claim_allowed":true'

$preflight = Invoke-JsonRequest -url "$BaseUrl/api/v1/clouds/deployment-preflight"
if ($preflight.status -ne 200) {
  throw "Hosted staging smoke verification failed: /api/v1/clouds/deployment-preflight returned HTTP $($preflight.status)"
}
Assert-Contains "deployment preflight status" $preflight.body '"status":"verified"'
Assert-Contains "deployment preflight ready" $preflight.body '"preflight_ready":true'
Assert-Contains "deployment preflight no blocked gates" $preflight.body '"missing_or_blocked_gates":[]'

$promptOverflow = Invoke-JsonRequest -url "$BaseUrl/api/v1/prompt" -method "POST" -headers @{ "x-request-id" = "hosted-smoke-overflow" } -body @{
  project_id = "hosted-smoke-overflow"
  prompt = ("x" * 10001)
  stream = $true
}
if ($promptOverflow.status -ne 422) {
  throw "Hosted staging smoke verification failed: prompt overflow returned HTTP $($promptOverflow.status)"
}
Assert-Contains "prompt overflow validation type" $promptOverflow.body "string_too_long"
Assert-Contains "prompt overflow error contract" $promptOverflow.body '"contract_version":"error-response-contract-v1"'

Write-Host "[hosted-smoke] checks completed"
