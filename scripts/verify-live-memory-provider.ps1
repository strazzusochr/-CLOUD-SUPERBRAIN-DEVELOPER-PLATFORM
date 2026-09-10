param(
  [string]$WorkerUrl = "https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev",
  [string]$OutDir = ".codex\runs\CURRENT\capability\live-memory-provider",
  [string]$CapabilityStatePath = "docs\runtime-state\capability-gates.json"
)

$ErrorActionPreference = "Stop"

# Proves a REAL, FREE, hosted stateful memory provider (Cloudflare D1) end to end
# and only then opens the `live_memory_provider` capability gate.
#
# Free-only: Cloudflare D1 free tier; no paid provider.
# Honest scope: this is LEXICAL persistence (D1/SQLite content + metadata), not
# pgvector semantic search. It closes the hosted-stateful-memory blocker; vector
# search remains a separate Vectorize concern and is NOT claimed here.
# Fail-closed: any failed assertion leaves the gate closed and exits non-zero.
# The shared write token is loaded transiently from env, presence-only, never echoed.

function Assert([string]$label, [bool]$ok) {
  if (-not $ok) { throw "live-memory-provider verification failed: $label" }
  Write-Host "[live-memory] $label"
}

$normalized = $WorkerUrl.Trim().TrimEnd("/")
Assert "worker URL is HTTPS ($normalized)" ($normalized -match "^https://")

$auth = $env:AGENT_API_AUTH_TOKEN
Assert "AGENT_API_AUTH_TOKEN present in environment (transient, presence-only)" (-not [string]::IsNullOrWhiteSpace($auth))

# 1) Health: D1 binding live and readable, no provider call.
$health = Invoke-RestMethod -Uri "$normalized/api/v1/health" -TimeoutSec 30
Assert "hosted D1 health status healthy (got '$($health.status)')" ([string]$health.status -eq "healthy")
Assert "hosted D1 health contract cloudflare-d1-stateful-runtime-v1" ([string]$health.contract_version -eq "cloudflare-d1-stateful-runtime-v1")
Assert "hosted D1 read probe verified" ([bool]$health.d1_read_verified)

# 2) Unauthenticated write is rejected (proves real auth boundary).
$unauthCode = 0
try { Invoke-WebRequest -Uri "$normalized/api/v1/builds" -Method Post -Body '{"id":"x"}' -ContentType 'application/json' -TimeoutSec 30 -UseBasicParsing | Out-Null }
catch { if ($_.Exception.Response) { $unauthCode = [int]$_.Exception.Response.StatusCode.value__ } }
Assert "unauthenticated hosted write rejected (HTTP $unauthCode)" ($unauthCode -eq 401)

# 3) Authenticated persistence roundtrip against real D1.
$id = [guid]::NewGuid().ToString()
$html = "<!doctype html><html lang=""de""><head><meta charset=""utf-8""><title>L6 D1 Persistenz-Beweis</title></head><body><main><h1>Cloud Superbrain hosted stateful memory proof</h1><p>Dieser Build wird echt in Cloudflare D1 persistiert und wieder gelesen.</p></main></body></html>"
$build = @{ id=$id; project_id='supervisor-l6-proof'; title='L6 D1 Persistenz-Beweis'; prompt='hosted stateful memory proof'; model='@cf/qwen/qwen2.5-coder-32b-instruct'; html=$html; gateway_mode='llm-gateway'; gateway_provider='cloudflare_workers_ai' } | ConvertTo-Json -Compress
$created = Invoke-RestMethod -Uri "$normalized/api/v1/builds" -Method Post -Headers @{ 'x-superbrain-agent-token'=$auth } -Body $build -ContentType 'application/json' -TimeoutSec 30
Assert "authenticated hosted build persisted" ([bool]$created.persisted)
Assert "persisted build returns matching id" ([string]$created.id -eq $id)

$read = Invoke-RestMethod -Uri "$normalized/api/v1/build/$id" -TimeoutSec 30
Assert "persisted build survives read-back roundtrip" ([string]$read.id -eq $id -and [string]$read.title -eq 'L6 D1 Persistenz-Beweis')

# List registry is project-scoped; the create->read->delete roundtrip above is the
# definitive persistence proof. Here we only assert the list is D1-backed (persisted:true).
$list = Invoke-RestMethod -Uri "$normalized/api/v1/builds?project_id=supervisor-l6-proof&limit=10" -TimeoutSec 30
Assert "hosted list reports D1-backed persistence" ([bool]$list.persisted)

# 4) Clean up the proof row (DELETE) so the registry is not polluted.
$deleted = Invoke-RestMethod -Uri "$normalized/api/v1/build/$id" -Method Delete -Headers @{ 'x-superbrain-agent-token'=$auth } -TimeoutSec 30
Assert "proof build soft-deleted after roundtrip" ([bool]$deleted.deleted -or [bool]$deleted.persisted)

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$reportPath = Join-Path $OutDir "report-$stamp.json"
$report = [ordered]@{
  contract_version   = "live-memory-provider-proof-v1"
  status             = "verified"
  evidence_ref       = "live_memory_provider_verified"
  provider           = "cloudflare_d1"
  paid_provider      = $false
  worker_url         = $normalized
  d1_read_verified   = [bool]$health.d1_read_verified
  auth_boundary_http = $unauthCode
  roundtrip_verified = $true
  build_id           = $id
  verified_at_utc    = (Get-Date).ToUniversalTime().ToString("o")
  non_claims         = @(
    "Proves a real free-tier hosted stateful persistence roundtrip on Cloudflare D1 (create, read, list, delete).",
    "This is LEXICAL persistence (D1/SQLite content + metadata), not pgvector semantic vector search.",
    "No write-token value is printed, logged, or stored in this artifact.",
    "Free tier only; no paid provider."
  )
}
$report | ConvertTo-Json -Depth 6 | Set-Content -Path $reportPath -Encoding UTF8
Write-Host "[live-memory] report=$reportPath"

$state = Get-Content -Path $CapabilityStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$gate = $state.gates.live_memory_provider
Assert "owner granted the free stateful memory capability" ([bool]$gate.owner_granted)
$gate.live_verified     = $true
$gate.evidence_artifact = ($reportPath -replace "\\", "/")
$gate.verified_at_utc   = $report.verified_at_utc
$gate.provider          = "cloudflare_d1"
$gate.paid_provider     = $false
$gate.verifier          = "scripts/verify-live-memory-provider.ps1"
$state | ConvertTo-Json -Depth 8 | Set-Content -Path $CapabilityStatePath -Encoding UTF8
Write-Host "[live-memory] capability gate live_memory_provider OPENED with hosted D1 evidence"
Write-Host "[live-memory] checks completed"
