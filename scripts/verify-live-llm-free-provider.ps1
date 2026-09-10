param(
  [string]$BaseUrl = "https://frontend-seven-psi-78.vercel.app",
  [switch]$AllowLocalhost,
  [string]$OutDir = ".codex\runs\CURRENT\capability\live-llm-free-provider",
  [string]$CapabilityStatePath = "docs\runtime-state\capability-gates.json"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

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

function Resolve-RepoPath([string]$Candidate, [string]$Label, [bool]$MustExist = $false) {
  if ([string]::IsNullOrWhiteSpace($Candidate)) { throw "$Label path is empty" }
  $resolved = if ([IO.Path]::IsPathRooted($Candidate)) {
    [IO.Path]::GetFullPath($Candidate)
  } else {
    [IO.Path]::GetFullPath((Join-Path $repoRoot $Candidate))
  }
  $root = [IO.Path]::GetFullPath($repoRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  if (-not $resolved.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "$Label must stay inside the repository"
  }
  if ($MustExist -and -not (Test-Path -LiteralPath $resolved)) { throw "$Label not found" }
  return $resolved
}

function Save-CapabilityState([object]$State, [string]$Path) {
  $resolved = [IO.Path]::GetFullPath($Path)
  $parent = Split-Path -Parent $resolved
  if (-not (Test-Path -LiteralPath $parent)) { throw "Capability state parent is missing: $parent" }
  $temporary = Join-Path $parent ("." + [IO.Path]::GetFileName($resolved) + "." + [Guid]::NewGuid().ToString("N") + ".tmp")
  try {
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $resolved -Force
  } finally {
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
  }
}

$normalized = $BaseUrl.Trim().TrimEnd("/")
try { $targetUri = [Uri]$normalized } catch { throw "Live provider proof requires a valid URL origin" }
if ($targetUri.UserInfo -or $targetUri.Query -or $targetUri.Fragment -or ($targetUri.AbsolutePath -ne "/" -and $targetUri.AbsolutePath -ne "")) {
  throw "Live provider proof BaseUrl must be an origin without credentials, path, query, or fragment"
}
if ($targetUri.IsLoopback) {
  if ($targetUri.Scheme -ne "http" -and $targetUri.Scheme -ne "https") { throw "Localhost proof requires HTTP or HTTPS" }
  if (-not $AllowLocalhost) { throw "Localhost proof is DEV-ONLY; pass -AllowLocalhost to acknowledge it cannot close a hosted claim." }
} elseif ($targetUri.Scheme -ne "https") {
  throw "Live provider proof requires HTTPS"
}
$isHosted = -not $targetUri.IsLoopback

$resolvedCapabilityStatePath = Resolve-RepoPath $CapabilityStatePath "Capability state" $true
$resolvedOutDir = Resolve-RepoPath $OutDir "Evidence output directory" $false
$state = Get-Content -LiteralPath $resolvedCapabilityStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$gate = $state.gates.live_llm_provider_calls
Assert "capability gate exists" ($null -ne $gate)
Assert "owner granted the free live provider capability" ([bool]$gate.owner_granted)
Assert "owner grant reference is present" (-not [string]::IsNullOrWhiteSpace([string]$gate.owner_grant_ref))

# A hosted revalidation is fail-closed from the moment it begins. A timeout,
# malformed response, paid-provider result, or failed assertion therefore
# cannot leave an older live_verified=true claim active.
if ($isHosted) {
  $gate.live_verified = $false
  $gate.evidence_artifact = ""
  $gate.verified_at_utc = ""
  $gate.provider = ""
  $gate.paid_provider = $false
  $gate.verifier = "scripts/verify-live-llm-free-provider.ps1"
  Save-CapabilityState $state $resolvedCapabilityStatePath
}

Write-Host "[live-llm] base url: $normalized"
Write-Host "[live-llm] budget: exactly one mini prompt"

$body = @{ prompt = "Eine Digitaluhr mit Sekundenanzeige" } | ConvertTo-Json -Compress
$started = Get-Date
# Windows PowerShell 5.1 has no -SkipHttpErrorCheck; treat an HTTP error as a
# real failure rather than letting the cmdlet throw an opaque exception.
$statusCode = 0
$responseBody = ""
$response = $null
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
$responseSource = [string]$response.Headers["x-superbrain-source"]

Assert "response names a model" (-not [string]::IsNullOrWhiteSpace($model))
Assert "model is a free Cloudflare Workers AI model (got '$model')" ($model -like "@cf/*")
Assert "response crossed the LLM Gateway boundary" ($responseSource -eq "llm-gateway-boundary")
Assert "response proves one live provider call" ($payload.live_provider_calls -is [bool] -and [bool]$payload.live_provider_calls)
Assert "response rejects direct provider bypass" ($payload.direct_provider_calls -is [bool] -and -not [bool]$payload.direct_provider_calls)
Assert "response identifies Workers AI behind the gateway" ([string]$payload.gateway_provider -eq "cloudflare-workers-ai")
Assert "response identifies live gateway mode" ([string]$payload.gateway_mode -eq "cloudflare_workers_ai_live")
Assert "response reports no secret output" ($payload.secret_output -is [bool] -and -not [bool]$payload.secret_output)
Assert "generated html is present" (-not [string]::IsNullOrWhiteSpace($html))
Assert "generated html is a real document (>=400 chars, got $($html.Length))" ($html.Length -ge 400)
Assert "generated html declares a doctype" ($html -match "(?i)<!doctype html")
Assert "generated html carries executable script" ($html -match "(?i)<script")
Assert "response exposes no secret material" ($responseBody -notmatch "(?i)(ghp_|glc_|glsa_|Bearer [A-Za-z0-9_\-]{20,})")

$artifactId = [string]$payload.id
Assert "build result carries an id" (-not [string]::IsNullOrWhiteSpace($artifactId))

if (-not (Test-Path -LiteralPath $resolvedOutDir)) { New-Item -ItemType Directory -Path $resolvedOutDir -Force | Out-Null }
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$reportPath = Join-Path $resolvedOutDir "report-$stamp.json"
$reportArtifact = $reportPath.Substring(([IO.Path]::GetFullPath($repoRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar).Length + 1)).Replace("\", "/")
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
  response_source    = $responseSource
  gateway_mode       = [string]$payload.gateway_mode
  gateway_provider   = [string]$payload.gateway_provider
  live_provider_calls = $true
  direct_provider_calls = $false
  secret_output      = $false
  html_length        = $html.Length
  html_sha256        = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($html)))).Replace("-", "").ToLowerInvariant()
  build_id           = $artifactId
  elapsed_ms         = $elapsedMs
  verified_at_utc    = (Get-Date).ToUniversalTime().ToString("o")
  non_claims         = @(
    "Proves one real free-tier generation call only.",
    "Does not claim throughput, availability, paid provider access, or a release promotion.",
    "Does not claim persistence: build registry persistence is tracked separately.",
    "Does not claim exact deployed-source attribution unless a separate source-bound evidence chain names this response."
  )
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding UTF8
Write-Host "[live-llm] report=$reportPath"

if (-not $isHosted) {
  Write-Host "[live-llm] DEV-ONLY run: capability gate NOT opened (hosted HTTPS proof required)."
  Write-Host "[live-llm] checks completed"
  exit 0
}

$gate.live_verified     = $true
$gate.evidence_artifact = $reportArtifact
$gate.verified_at_utc   = $report.verified_at_utc
$gate.provider          = "cloudflare_workers_ai"
$gate.paid_provider     = $false
$gate.verifier          = "scripts/verify-live-llm-free-provider.ps1"
Save-CapabilityState $state $resolvedCapabilityStatePath
Write-Host "[live-llm] capability gate live_llm_provider_calls OPENED with hosted evidence"
Write-Host "[live-llm] checks completed"
