[CmdletBinding()]
param(
  [string]$RuntimeEvidencePath = 'docs/runtime-state/cloudflare-oauth-hosted-current.json',
  [string]$FlowEvidencePath = 'docs/runtime-state/cloudflare-oauth-hosted-current-flow.json',

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$ExpectedCandidateSha,

  [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ValidateOnly) {
  throw 'Phase-3 OAuth raw-evidence verification is read-only and requires -ValidateOnly.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$delegate = Join-Path $PSScriptRoot 'verify-cloudflare-oauth-hosted-current.ps1'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $delegate -PathType Leaf) 'Cloudflare OAuth evidence verifier is missing.'

$before = & git -C $repoRoot status --porcelain=v1 --untracked-files=all
Assert-True ($LASTEXITCODE -eq 0) 'Unable to snapshot repository state.'

$powerShellExecutable = (Get-Process -Id $PID).Path
$output = @(
  & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass `
    -File $delegate `
    -EvidencePath $RuntimeEvidencePath `
    -FlowEvidencePath $FlowEvidencePath `
    -ExpectedCandidateSha $ExpectedCandidateSha `
    -ValidateOnly 2>&1
)
Assert-True ($LASTEXITCODE -eq 0) 'Cloudflare OAuth raw-evidence delegate rejected the evidence.'
$text = ($output | ForEach-Object { [string]$_ }) -join "`n"
foreach ($marker in @(
  '[production-auth-runtime] status=verified',
  'architecture=cloudflare_native',
  'validation_mode=true',
  'read_only=true',
  'source_parity=true',
  'exact_human_flow_steps=12',
  'atomic_replay_evidence=scored',
  'audit_correlation_evidence=scored',
  'gate_promotion_performed=false',
  'live_verified_set=false',
  'secret_output=false'
)) {
  Assert-True $text.Contains($marker) "Cloudflare OAuth raw-evidence delegate is missing marker: $marker"
}

$after = & git -C $repoRoot status --porcelain=v1 --untracked-files=all
Assert-True ($LASTEXITCODE -eq 0) 'Unable to re-check repository state.'
Assert-True ((@($before) -join "`n") -ceq (@($after) -join "`n")) 'OAuth raw-evidence validation mutated the repository.'

Write-Host "[phase3-oauth-raw-evidence] status=verified candidate_sha=$ExpectedCandidateSha read_only=true human_flow_steps=12 gate_promotion=false percentage_credit=false secret_output=false"
