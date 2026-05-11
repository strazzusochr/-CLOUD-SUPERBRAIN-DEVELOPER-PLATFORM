param(
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Phase4 hosted progress-completion-contract verification failed: $label"
  }
}

function Invoke-WebResponse($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = $null, $timeoutSeconds = 30) {
  $bodyBase64 = $null
  if ($null -ne $body) {
    $bodyBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$body))
  }
  $payload = [pscustomobject]@{
    url = $url
    method = $method
    bodyBase64 = $bodyBase64
    headers = $headers
    contentType = $contentType
    timeoutSeconds = $timeoutSeconds
  } | ConvertTo-Json -Depth 8 -Compress
  $python = @'
import base64
import json
import ssl
import sys
import urllib.error
import urllib.request

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
body_base64 = payload.get("bodyBase64")
data = None
if body_base64 is not None:
    data = base64.b64decode(body_base64.encode("ascii"))
headers = payload.get("headers") or {}
content_type = payload.get("contentType")
if content_type and "Content-Type" not in headers and "content-type" not in headers:
    headers["Content-Type"] = content_type
request = urllib.request.Request(payload["url"], data=data, headers=headers, method=payload["method"])
context = ssl._create_unverified_context() if payload["url"].startswith("https://") else None
try:
    with urllib.request.urlopen(request, timeout=payload.get("timeoutSeconds", 30), context=context) as response:
        result = {"status_code": response.getcode(), "content": response.read().decode("utf-8", errors="replace")}
except urllib.error.HTTPError as error:
    result = {"status_code": error.code, "content": error.read().decode("utf-8", errors="replace")}
print(json.dumps(result))
'@
  $payloadFile = Join-Path $env:TEMP ("phase4-progress-completion-contract-" + [Guid]::NewGuid().ToString("N") + ".json")
  try {
    Set-Content -LiteralPath $payloadFile -Value $payload -NoNewline
    $raw = $python | py -3 - $payloadFile
  } finally {
    if (Test-Path $payloadFile) { Remove-Item -LiteralPath $payloadFile -Force }
  }
  $parsed = $raw | ConvertFrom-Json
  return [pscustomobject]@{ StatusCode = [int]$parsed.status_code; Content = [string]$parsed.content }
}

function Invoke-JsonApi($url, $method = "GET", $body = $null, [hashtable]$headers = $null, $contentType = "application/json", $timeoutSeconds = 30) {
  $response = Invoke-WebResponse -url $url -method $method -body $body -headers $headers -contentType $contentType -timeoutSeconds $timeoutSeconds
  if ([int]$response.StatusCode -ge 400) {
    throw "Phase4 hosted progress-completion-contract verification failed: $method $url returned HTTP $($response.StatusCode). Value: $($response.Content)"
  }
  if (-not ($response.Content | Out-String).Trim()) {
    return $null
  }
  return ($response.Content | ConvertFrom-Json)
}

if (-not $BaseUrl) { throw "BaseUrl is required" }
$BaseUrl = $BaseUrl.TrimEnd("/")
if ($BaseUrl -notmatch "^https://") { throw "Phase4 hosted progress-completion-contract proof requires HTTPS" }

$contract = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress/completion/contract" -method "GET" -contentType $null -timeoutSeconds 20
Assert-True "contract version" ($contract.contract_version -eq "project-progress-completion-surface-v1")
Assert-True "runtime contract version" ($contract.runtime_contract_version -eq "project-progress-100-percent-contract-v1")
Assert-True "completion endpoint parity" ($contract.endpoint -eq "GET /api/v1/project/progress/completion")
Assert-True "visibility progress endpoint" (@($contract.visibility_endpoints) -contains "/api/v1/project/progress")
Assert-True "visibility integrity endpoint" (@($contract.visibility_endpoints) -contains "/api/v1/project/progress/integrity")
Assert-True "visibility external gates endpoint" (@($contract.visibility_endpoints) -contains "/api/v1/external-gates")
Assert-True "required can_set_all_to_100 field" (@($contract.required_top_level_fields) -contains "can_set_all_to_100")
Assert-True "required phase_completion field" (@($contract.required_top_level_fields) -contains "phase_completion")
Assert-True "blocked external gate status declared" (@($contract.expected_statuses) -contains "blocked_external_gates")
Assert-True "blocked unverified progress gaps status removed" (-not (@($contract.expected_statuses) -contains "blocked_unverified_progress_gaps"))
Assert-True "required local progress blocker declared" (@($contract.required_hard_blockers) -contains "local_progress_gaps_require_verified_evidence_for_each_phase_and_layer")

$progress = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress" -method "GET" -contentType $null -timeoutSeconds 20
$integrity = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress/integrity" -method "GET" -contentType $null -timeoutSeconds 20
$completion = Invoke-JsonApi -url "$BaseUrl/api/v1/project/progress/completion" -method "GET" -contentType $null -timeoutSeconds 20
$gates = Invoke-JsonApi -url "$BaseUrl/api/v1/external-gates" -method "GET" -contentType $null -timeoutSeconds 20

Assert-True "integrity verified" ($integrity.status -eq "verified")
Assert-True "completion contract version runtime" ($completion.contract_version -eq "project-progress-100-percent-contract-v1")
Assert-True "completion status allowed" (@($contract.expected_statuses) -contains [string]$completion.status)
Assert-True "completion runtime status blocked by surfaced hard blockers" ([string]$completion.status -eq "blocked_external_gates")
Assert-True "requested target is 100" ([int]$completion.requested_target_percent -eq 100)
Assert-True "overall parity" ([int]$completion.current_overall_percent -eq [int]$progress.overall_percent)
Assert-True "truth policy parity" ([string]$completion.truth_policy -eq [string]$progress.truth_policy)
Assert-True "cannot set all to 100" ($completion.can_set_all_to_100 -eq $false)
Assert-True "hard blockers array visible" (@($completion.hard_blockers).Count -ge 1)
Assert-True "local gap blocker present" (@($completion.hard_blockers) -contains "local_progress_gaps_require_verified_evidence_for_each_phase_and_layer")
Assert-True "phase completion visible" (@($completion.phase_completion).Count -ge 1)
Assert-True "layer completion visible" (@($completion.layer_completion).Count -ge 1)

$phase4Progress = @($progress.horizontal.items) | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
$phase4Completion = @($completion.phase_completion) | Where-Object { $_.id -eq "phase_4" } | Select-Object -First 1
Assert-True "phase4 progress item visible" ($null -ne $phase4Progress)
Assert-True "phase4 completion item visible" ($null -ne $phase4Completion)
Assert-True "phase4 percent parity" ([int]$phase4Completion.current_percent -eq [int]$phase4Progress.percent)
Assert-True "phase4 target percent 100" ([int]$phase4Completion.target_percent -eq 100)
Assert-True "phase4 remaining percent parity" ([int]$phase4Completion.remaining_percent -eq (100 - [int]$phase4Progress.percent))

if ($gates.status -eq "verified") {
  Assert-True "no missing external gate blockers on verified gates" (@($completion.missing_external_gate_blockers).Count -eq 0)
}

Write-Host "[phase4-progress-completion-contract-runtime] base_url=$BaseUrl"
Write-Host "[phase4-progress-completion-contract-runtime] result=verified"
