param(
  [string]$BaseUrl = "https://frontend-seven-psi-78.vercel.app",
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\capability\live-llm-free-provider",
  [string]$CapabilityStatePath = "docs\runtime-state\capability-gates.json"
)

$ErrorActionPreference = "Stop"

# Proves the free live LLM capability end to end against a real runtime and only
# then opens the `live_llm_provider_calls` capability gate.
#
# Free-only: the model must be a Cloudflare Workers AI model. A paid provider
# must never satisfy this gate.
# Budget: exactly ONE mini prompt per run (Workers AI 10k neurons/day).
# Fail-closed: any failed assertion leaves the gate closed and exits non-zero.

function Assert([string]$label, [bool]$ok) {
  if (-not $ok) { throw "live-llm-free-provider verification failed: $label" }
  Write-Host "[live-llm] $label"
}

$normalized = $BaseUrl.Trim().TrimEnd("/")
if ($normalized -match "^http://(localhost|127\.0\.0\.1)") {
  if (-not $AllowLocalhost) { throw "Localhost proof is DEV-ONLY; pass -AllowLocalhost to acknowledge it cannot close a hosted claim." }
} elseif ($normalized -notmatch "^https://") {
  throw "Live provider proof requires HTTPS"
}
$isHosted = $normalized -match "^https://"

Write-Host "[live-llm] base url: $normalized"
Write-Host "[live-llm] budget: exactly one mini prompt"

$body = @{ prompt = "Eine Digitaluhr mit Sekundenanzeige" } | ConvertTo-Json -Compress
$started = Get-Date
# Windows PowerShell 5.1 has no -SkipHttpErrorCheck; treat an HTTP error as a
# real failure rather than letting the cmdlet throw an opaque exception.
$statusCode = 0
$responseBody = ""
try {
  $response = Invoke-WebRequest -Uri "$normalized/api/v1/build" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 240 -UseBasicParsing
  $statusCode = [int]$response.StatusCode
  $responseBody = [string]$response.Content
} catch {
  $webResponse = $_.Exception.Response
  if ($webResponse) {
    $statusCode = [int]$webResponse.StatusCode
    $reader = New-Object System.IO.StreamReader($webResponse.GetResponseStream())
    $responseBody = $reader.ReadToEnd()
    $reader.Close()
  } else {
    throw
  }
}
$elapsedMs = [int]((Get-Date) - $started).TotalMilliseconds

Assert "build endpoint returns HTTP 200 (got $statusCode)" ($statusCode -eq 200)

$payload = $responseBody | ConvertFrom-Json
$model = [string]$payload.model
$html = [string]$payload.html

Assert "response names a model" (-not [string]::IsNullOrWhiteSpace($model))
Assert "model is a free Cloudflare Workers AI model (got '$model')" ($model -like "@cf/*")
Assert "generated html is present" (-not [string]::IsNullOrWhiteSpace($html))
Assert "generated html is a real document (>=400 chars, got $($html.Length))" ($html.Length -ge 400)
Assert "generated html declares a doctype" ($html -match "(?i)<!doctype html")
Assert "generated html carries executable script" ($html -match "(?i)<script")
Assert "response exposes no secret material" ($responseBody -notmatch "(?i)(ghp_|glc_|glsa_|Bearer [A-Za-z0-9_\-]{20,})")

$artifactId = [string]$payload.id
Assert "build result carries an id" (-not [string]::IsNullOrWhiteSpace($artifactId))

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$reportPath = Join-Path $OutDir "report-$stamp.json"
$report = [ordered]@{
  contract_version   = "live-llm-free-provider-proof-v1"
  status             = "verified"
  evidence_ref       = "live_llm_free_provider_verified"
  base_url           = $normalized
  hosted             = $isHosted
  scope              = if ($isHosted) { "hosted_https" } else { "DEV-ONLY" }
  model              = $model
  provider           = "cloudflare_workers_ai"
  paid_provider      = $false
  prompts_used       = 1
  html_length        = $html.Length
  build_id           = $artifactId
  elapsed_ms         = $elapsedMs
  verified_at_utc    = (Get-Date).ToUniversalTime().ToString("o")
  non_claims         = @(
    "Proves one real free-tier generation call only.",
    "Does not claim throughput, availability, paid provider access, or a release promotion.",
    "Does not claim persistence: build registry persistence is tracked separately."
  )
}
$report | ConvertTo-Json -Depth 6 | Set-Content -Path $reportPath -Encoding UTF8
Write-Host "[live-llm] report=$reportPath"

if (-not $isHosted) {
  Write-Host "[live-llm] DEV-ONLY run: capability gate NOT opened (hosted HTTPS proof required)."
  Write-Host "[live-llm] checks completed"
  exit 0
}

$state = Get-Content -Path $CapabilityStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$gate = $state.gates.live_llm_provider_calls
Assert "owner granted the free live provider capability" ([bool]$gate.owner_granted)
$gate.live_verified     = $true
$gate.evidence_artifact = ($reportPath -replace "\\","/")
$gate.verified_at_utc   = $report.verified_at_utc
$gate.provider          = "cloudflare_workers_ai"
$gate.paid_provider     = $false
$state | ConvertTo-Json -Depth 8 | Set-Content -Path $CapabilityStatePath -Encoding UTF8
Write-Host "[live-llm] capability gate live_llm_provider_calls OPENED with hosted evidence"
Write-Host "[live-llm] checks completed"
