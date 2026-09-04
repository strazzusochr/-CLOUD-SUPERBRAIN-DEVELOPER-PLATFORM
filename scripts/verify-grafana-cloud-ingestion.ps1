param(
  [string]$OutDir = ".codex\runs\CURRENT\capability\hosted-observability",
  [string]$CapabilityStatePath = "docs\runtime-state\capability-gates.json"
)

$ErrorActionPreference = "Stop"

# Proves REAL hosted telemetry ingestion into Grafana Cloud (free tier) and only
# then opens the `hosted_observability_endpoint` capability gate.
#
# This is stronger than the existing identity read (access-policy list): it
# authenticates against the Grafana Cloud OTLP gateway with a real Basic-auth
# tenant credential and pushes a live log record and a live metric data point,
# asserting the gateway ACCEPTS them (HTTP 2xx). It is owner-assisted (uses the
# already-present GRAFANA_CLOUD_API_KEY transiently) which is allowed; the key
# value is never printed, logged, or written to any artifact.
#
# Fail-closed: any failed assertion leaves the gate closed and exits non-zero.
# Free-only: Grafana Cloud free tier, no paid provider.

function Assert([string]$label, [bool]$ok) {
  if (-not $ok) { throw "grafana-cloud-ingestion verification failed: $label" }
  Write-Host "[grafana-ingestion] $label"
}

$token = $env:GRAFANA_CLOUD_API_KEY
Assert "GRAFANA_CLOUD_API_KEY present in environment (transient, presence-only)" (-not [string]::IsNullOrWhiteSpace($token))
Assert "token is a Grafana Cloud access-policy token (glc_ prefix)" ($token.StartsWith("glc_"))

# Decode ONLY the region from the token metadata; never emit the token.
$b64 = $token.Substring(4)
$pad = $b64.PadRight([math]::Ceiling($b64.Length / 4) * 4, '=').Replace('-', '+').Replace('_', '/')
$region = $null
try {
  $meta = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pad)) | ConvertFrom-Json
  $region = [string]$meta.m.r
} catch { throw "grafana-cloud-ingestion verification failed: token metadata region is not decodable" }
Assert "token embeds a valid region ($region)" ($region -match '^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$')

# Read-only identity + scope proof: the token must actually grant write scopes.
$policies = Invoke-RestMethod -Uri "https://grafana.com/api/v1/accesspolicies?region=$region" -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 20
$scopes = @()
$stackId = $null
foreach ($p in $policies.items) {
  $scopes += $p.scopes
  foreach ($rl in $p.realms) { if ([string]$rl.type -eq "stack") { $stackId = [string]$rl.identifier } }
}
$scopes = $scopes | Sort-Object -Unique
Assert "access policy grants metrics:write" ($scopes -contains "metrics:write")
Assert "access policy grants logs:write" ($scopes -contains "logs:write")
Assert "access policy exposes the numeric stack tenant id" (-not [string]::IsNullOrWhiteSpace($stackId))

$basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($stackId + ':' + $token)))
$otlpBase = "https://otlp-gateway-$region.grafana.net/otlp"
$ns = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000).ToString()
$runTag = "supervisor-l7-" + ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString())

function Push-Otlp([string]$signal, [string]$body) {
  try {
    $resp = Invoke-WebRequest -Uri "$otlpBase/v1/$signal" -Method Post -Headers @{ Authorization = ("Basic " + $basic) } -ContentType 'application/json' -Body $body -TimeoutSec 25 -UseBasicParsing
    return [int]$resp.StatusCode
  } catch {
    if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode.value__ }
    throw
  }
}

$logBody = '{"resourceLogs":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"cloud-superbrain-observability-proof"}},{"key":"run.tag","value":{"stringValue":"' + $runTag + '"}}]},"scopeLogs":[{"logRecords":[{"timeUnixNano":"' + $ns + '","severityText":"INFO","body":{"stringValue":"cloud-superbrain hosted observability ingestion proof"}}]}]}]}'
$logCode = Push-Otlp "logs" $logBody
Assert "OTLP log record accepted by Grafana Cloud (HTTP $logCode)" ($logCode -ge 200 -and $logCode -lt 300)

$metricBody = '{"resourceMetrics":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"cloud-superbrain-observability-proof"}}]},"scopeMetrics":[{"metrics":[{"name":"superbrain_observability_ingestion_proof","gauge":{"dataPoints":[{"asDouble":1,"timeUnixNano":"' + $ns + '"}]}}]}]}]}'
$metricCode = Push-Otlp "metrics" $metricBody
Assert "OTLP metric data point accepted by Grafana Cloud (HTTP $metricCode)" ($metricCode -ge 200 -and $metricCode -lt 300)

# Negative control: a corrupted tenant credential must be rejected (proves the
# 2xx above was real authentication, not an open endpoint).
$badBasic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($stackId + ':glc_invalid-tenant-credential')))
$badCode = 0
try {
  Invoke-WebRequest -Uri "$otlpBase/v1/logs" -Method Post -Headers @{ Authorization = ("Basic " + $badBasic) } -ContentType 'application/json' -Body $logBody -TimeoutSec 25 -UseBasicParsing | Out-Null
} catch { if ($_.Exception.Response) { $badCode = [int]$_.Exception.Response.StatusCode.value__ } }
Assert "invalid tenant credential is rejected (HTTP $badCode, proves real auth)" ($badCode -eq 401 -or $badCode -eq 403)

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$reportPath = Join-Path $OutDir "report-$stamp.json"
$report = [ordered]@{
  contract_version         = "hosted-observability-ingestion-proof-v1"
  status                   = "verified"
  evidence_ref             = "hosted_observability_ingestion_verified"
  provider                 = "grafana_cloud"
  paid_provider            = $false
  region                   = $region
  otlp_gateway             = "$otlpBase"
  write_scopes_present     = @("metrics:write", "logs:write")
  log_ingestion_http       = $logCode
  metric_ingestion_http    = $metricCode
  invalid_credential_http  = $badCode
  run_tag                  = $runTag
  verified_at_utc          = (Get-Date).ToUniversalTime().ToString("o")
  non_claims               = @(
    "Proves authenticated live ingestion ACCEPTANCE (HTTP 2xx) of one log and one metric into Grafana Cloud.",
    "Does not claim dashboards, alerting, retention, or read-back query throughput.",
    "No Grafana token value is printed, logged, or stored in this artifact.",
    "Free tier only; no paid provider."
  )
}
$report | ConvertTo-Json -Depth 6 | Set-Content -Path $reportPath -Encoding UTF8
Write-Host "[grafana-ingestion] report=$reportPath"

$state = Get-Content -Path $CapabilityStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$gate = $state.gates.hosted_observability_endpoint
Assert "owner granted the hosted observability capability" ([bool]$gate.owner_granted)
$gate.live_verified     = $true
$gate.evidence_artifact = ($reportPath -replace "\\", "/")
$gate.verified_at_utc   = $report.verified_at_utc
$gate.provider          = "grafana_cloud"
$gate.paid_provider     = $false
$gate.verifier          = "scripts/verify-grafana-cloud-ingestion.ps1"
$state | ConvertTo-Json -Depth 8 | Set-Content -Path $CapabilityStatePath -Encoding UTF8
Write-Host "[grafana-ingestion] capability gate hosted_observability_endpoint OPENED with live ingestion evidence"
Write-Host "[grafana-ingestion] checks completed"
