param(
  [string]$GateName = "docker-dependent gate",
  [int]$MaxWaitSeconds = 120,
  [int]$IntervalSeconds = 10
)

$ErrorActionPreference = "Stop"

$verifier = Join-Path $PSScriptRoot "verify-docker-readiness.ps1"
if (-not (Test-Path -LiteralPath $verifier)) {
  throw "[BLOCKED] $GateName requires Docker readiness, but the Docker readiness verifier is missing: $verifier"
}

& $verifier -MaxWaitSeconds $MaxWaitSeconds -IntervalSeconds $IntervalSeconds
if (-not $?) {
  throw "[BLOCKED] $GateName requires Docker readiness. Use scripts\verify-docker-readiness.ps1 -ReportOnly for diagnostics; docker-dependent verification is [SKIPPED-REASON: docker-unavailable]."
}
