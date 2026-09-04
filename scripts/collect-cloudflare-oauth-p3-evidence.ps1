[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$ExpectedCandidateSha,

  [string]$FlowEvidencePath = 'docs/runtime-state/cloudflare-oauth-hosted-current-flow.json',
  [string]$RuntimeEvidencePath = 'docs/runtime-state/cloudflare-oauth-hosted-current.json',
  [string]$FrontendEvidencePath = 'docs/runtime-state/frontend-hosted-current.json',
  [string]$ArchitectureDecisionPath = 'docs/runtime-state/production-auth-architecture-decision.json',

  [Parameter(Mandatory = $true)]
  [string]$CiAttestationPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath,

  [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot 'build_production_auth_identity_evidence.py'
$verifier = Join-Path $PSScriptRoot 'verify-production-auth-identity-evidence.ps1'
$capabilityPath = Join-Path $repoRoot 'docs/runtime-state/capability-gates.json'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Resolve-RepoPath([string]$Path, [bool]$MustExist) {
  Assert-True (-not [string]::IsNullOrWhiteSpace($Path)) 'A repository path is required.'
  $root = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  $absolute = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repoRoot $Path)) }
  Assert-True $absolute.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) 'Path escapes the repository.'
  if ($MustExist) { Assert-True (Test-Path -LiteralPath $absolute -PathType Leaf) "Required file is missing: $Path" }
  $relative = [IO.Path]::GetRelativePath($repoRoot, $absolute).Replace('\', '/')
  Assert-True (-not $relative.Split('/').Contains('..')) 'Path traversal is forbidden.'
  return [pscustomobject]@{ absolute = $absolute; relative = $relative }
}

function Assert-TrackedClean([object]$Resolved, [string]$Label) {
  & git -C $repoRoot ls-files --error-unmatch -- $Resolved.relative 2>$null | Out-Null
  Assert-True ($LASTEXITCODE -eq 0) "$Label must be tracked by Git."
  & git -C $repoRoot diff --quiet HEAD -- $Resolved.relative
  Assert-True ($LASTEXITCODE -eq 0) "$Label must be clean relative to HEAD."
}

Assert-True (Test-Path -LiteralPath $builder -PathType Leaf) 'Production-auth evidence builder is missing.'
Assert-True (Test-Path -LiteralPath $verifier -PathType Leaf) 'Production-auth evidence verifier is missing.'
& git -C $repoRoot cat-file -e "${ExpectedCandidateSha}^{commit}" 2>$null
Assert-True ($LASTEXITCODE -eq 0) 'Expected candidate SHA does not resolve to a commit.'
& git -C $repoRoot merge-base --is-ancestor $ExpectedCandidateSha HEAD
Assert-True ($LASTEXITCODE -eq 0) 'Expected candidate SHA is not an ancestor of HEAD.'

$output = Resolve-RepoPath $OutputPath $ValidateOnly.IsPresent
Assert-True ($output.relative -match '^docs/release-artifacts/prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-local-rc[0-9]+-evidence/oauth/production-auth-identity\.json$') `
  'OutputPath must be the canonical release-scoped production-auth evidence path.'

if ($ValidateOnly) {
  Assert-TrackedClean $output 'Production-auth evidence'
  $powerShellExecutable = (Get-Process -Id $PID).Path
  $verifyOutput = @(
    & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass `
      -File $verifier `
      -EvidencePath $output.relative `
      -ExpectedCandidateSha $ExpectedCandidateSha `
      -ValidateOnly 2>&1
  )
  Assert-True ($LASTEXITCODE -eq 0) 'Production-auth evidence validation failed.'
  $verifyText = ($verifyOutput | ForEach-Object { [string]$_ }) -join "`n"
  Assert-True $verifyText.Contains('[production-auth-evidence] status=verified') 'Production-auth verifier success marker is missing.'
  $sha = (Get-FileHash -LiteralPath $output.absolute -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-Host "[phase3-oauth-collector] status=verified validation_mode=true evidence_sha256=$sha gate_promotion=false secret_output=false"
  exit 0
}

Assert-True (-not (Test-Path -LiteralPath $output.absolute)) 'OutputPath already exists; immutable evidence is never overwritten.'
$inputs = [ordered]@{
  flow = Resolve-RepoPath $FlowEvidencePath $true
  runtime = Resolve-RepoPath $RuntimeEvidencePath $true
  frontend = Resolve-RepoPath $FrontendEvidencePath $true
  architecture = Resolve-RepoPath $ArchitectureDecisionPath $true
  ci = Resolve-RepoPath $CiAttestationPath $true
}
foreach ($entry in $inputs.GetEnumerator()) { Assert-TrackedClean $entry.Value "Production-auth $($entry.Key) input" }

$capabilityBefore = (Get-FileHash -LiteralPath $capabilityPath -Algorithm SHA256).Hash
$pythonOutput = @(
  & py -3 $builder `
    --candidate-sha $ExpectedCandidateSha `
    --flow $inputs.flow.absolute `
    --runtime $inputs.runtime.absolute `
    --frontend $inputs.frontend.absolute `
    --architecture-decision $inputs.architecture.absolute `
    --ci-attestation $inputs.ci.absolute `
    --output $output.absolute 2>&1
)
Assert-True ($LASTEXITCODE -eq 0) "Production-auth evidence builder failed: $($pythonOutput -join ' ')"
Assert-True (Test-Path -LiteralPath $output.absolute -PathType Leaf) 'Production-auth evidence builder did not create the requested output.'
$capabilityAfter = (Get-FileHash -LiteralPath $capabilityPath -Algorithm SHA256).Hash
Assert-True ($capabilityBefore -ceq $capabilityAfter) 'Production-auth evidence collection mutated capability gates.'

try { $evidence = Get-Content -LiteralPath $output.absolute -Raw | ConvertFrom-Json } catch { throw 'Generated production-auth evidence is invalid JSON.' }
Assert-True ([string]$evidence.contract_version -ceq 'production-auth-identity-proof-v1') 'Generated production-auth evidence contract mismatch.'
Assert-True ([string]$evidence.status -ceq 'verified') 'Generated production-auth evidence is not verified.'
Assert-True ($evidence.gate_promotion_performed -is [bool] -and -not [bool]$evidence.gate_promotion_performed) 'Collector may not promote the auth gate.'
Assert-True ($evidence.secret_output -is [bool] -and -not [bool]$evidence.secret_output) 'Collector emitted a secret claim.'
$sha = (Get-FileHash -LiteralPath $output.absolute -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "[phase3-oauth-collector] status=evidence_written candidate_sha=$ExpectedCandidateSha evidence_sha256=$sha commit_required_before_validation=true gate_promotion=false secret_output=false"
