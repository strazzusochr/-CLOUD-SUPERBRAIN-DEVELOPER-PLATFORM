[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
  [string]$Repository,

  [Parameter(Mandatory = $true)]
  [ValidateRange(1, [long]::MaxValue)]
  [long]$RunId,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$ExpectedSourceSha,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9a-f]{40}$')]
  [string]$ExpectedQualificationSha,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath,

  [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$builder = Join-Path $PSScriptRoot 'build_exact_head_ci_attestation.py'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Resolve-RepoPath([string]$Path, [bool]$MustExist) {
  $rootPrefix = [IO.Path]::GetFullPath($repoRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  $absolute = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repoRoot $Path)) }
  Assert-True $absolute.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) 'OutputPath must stay inside the repository.'
  if ($MustExist) { Assert-True (Test-Path -LiteralPath $absolute -PathType Leaf) 'CI attestation output is missing.' }
  $relative = [IO.Path]::GetRelativePath($repoRoot, $absolute).Replace('\', '/')
  Assert-True ($relative -match '^docs/release-artifacts/prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-local-rc[0-9]+-evidence/ci/exact-head-ci-attestation\.json$') `
    'OutputPath must use the canonical release-scoped CI evidence path.'
  return [pscustomobject]@{ absolute = $absolute; relative = $relative }
}

function Assert-Boolean([object]$Object, [string]$Name, [bool]$Expected) {
  $property = $Object.PSObject.Properties[$Name]
  Assert-True ($null -ne $property -and $property.Value -is [bool] -and $property.Value -eq $Expected) "CI attestation $Name mismatch."
}

foreach ($sha in @($ExpectedSourceSha, $ExpectedQualificationSha)) {
  & git -C $repoRoot cat-file -e "$sha^{commit}" 2>$null
  Assert-True ($LASTEXITCODE -eq 0) "CI binding commit is missing: $sha"
}
$qualificationParent = (& git -C $repoRoot rev-parse "$ExpectedQualificationSha^").Trim()
Assert-True ($LASTEXITCODE -eq 0 -and $qualificationParent -ceq $ExpectedSourceSha) 'Qualification must be a direct child of the source.'
$qualificationDelta = @(& git -C $repoRoot diff --name-only $ExpectedSourceSha $ExpectedQualificationSha)
Assert-True ($LASTEXITCODE -eq 0 -and $qualificationDelta.Count -eq 1 -and $qualificationDelta[0] -ceq 'docs/runtime-state/source-qualification-control.json') `
  'Qualification delta must contain only the source qualification control.'

$output = Resolve-RepoPath $OutputPath $ValidateOnly.IsPresent
if ($ValidateOnly) {
  & git -C $repoRoot ls-files --error-unmatch -- $output.relative 2>$null | Out-Null
  Assert-True ($LASTEXITCODE -eq 0) 'CI attestation must be tracked by Git.'
  & git -C $repoRoot diff --quiet HEAD -- $output.relative
  Assert-True ($LASTEXITCODE -eq 0) 'CI attestation must be clean relative to HEAD.'
  try { $attestation = Get-Content -LiteralPath $output.absolute -Raw | ConvertFrom-Json } catch { throw 'CI attestation must be valid JSON.' }
  Assert-True ([string]$attestation.contract_version -ceq 'exact-head-ci-attestation-v2') 'CI attestation contract mismatch.'
  Assert-True ([string]$attestation.status -ceq 'verified') 'CI attestation status mismatch.'
  Assert-True ([string]$attestation.repository -ceq $Repository) 'CI attestation repository mismatch.'
  Assert-True ([long]$attestation.run_id -eq $RunId -and [int]$attestation.run_attempt -eq 1) 'CI attestation run identity mismatch.'
  Assert-True ([string]$attestation.source_commit_sha -ceq $ExpectedSourceSha) 'CI attestation source mismatch.'
  Assert-True ([string]$attestation.qualification_commit_sha -ceq $ExpectedQualificationSha) 'CI attestation qualification mismatch.'
  Assert-True ([string]$attestation.run_head_sha -ceq $ExpectedQualificationSha) 'CI attestation run-head mismatch.'
  Assert-True ([string]$attestation.source_checkout_binding_mode -ceq 'source_checkout_attestation_v1') 'CI source-checkout binding mismatch.'
  Assert-True ($attestation.source_prequalification -is [bool] -and $attestation.source_prequalification) 'CI source-prequalification flag mismatch.'
  Assert-True ([string]$attestation.source_checkout_attestation_sha256 -cmatch '^[0-9a-f]{64}$') 'CI source-checkout hash is invalid.'
  Assert-True ([int]$attestation.failed_job_count -eq 0 -and [int]$attestation.skipped_job_count -eq 0 -and [int]$attestation.skipped_step_count -eq 0) 'CI attestation contains failed or skipped work.'
  foreach ($field in @('required_checks_passed', 'branch_protection_verified', 'secret_scan_verified', 'oauth_regression_verified', 'api_readback_complete')) {
    Assert-Boolean $attestation $field $true
  }
  Assert-Boolean $attestation 'provider_writes' $false
  Assert-Boolean $attestation 'secret_output' $false
  $sha = (Get-FileHash -LiteralPath $output.absolute -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-Host "[exact-head-ci-attestation] status=verified validation_mode=true source_sha=$ExpectedSourceSha qualification_sha=$ExpectedQualificationSha run_id=$RunId failed=0 skipped=0 evidence_sha256=$sha secret_output=false"
  exit 0
}

Assert-True (-not (Test-Path -LiteralPath $output.absolute)) 'CI attestation output already exists.'
Assert-True (Test-Path -LiteralPath $builder -PathType Leaf) 'CI attestation builder is missing.'
Assert-True ($null -ne (Get-Command gh -ErrorAction SilentlyContinue)) 'GitHub CLI is unavailable.'
& gh auth status --hostname github.com 1>$null 2>$null
Assert-True ($LASTEXITCODE -eq 0) 'GitHub CLI is not authenticated.'

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) "sb-ci-attestation-$([Guid]::NewGuid().ToString('N'))"
$null = New-Item -ItemType Directory -Path $temporaryRoot
try {
  $runPath = Join-Path $temporaryRoot 'run.json'
  $jobsPath = Join-Path $temporaryRoot 'jobs.json'
  $repoPath = Join-Path $temporaryRoot 'repository.json'
  $branchPath = Join-Path $temporaryRoot 'branch.json'
  $checkoutArtifactRoot = Join-Path $temporaryRoot 'source-checkout-artifact'
  & gh api "repos/$Repository/actions/runs/$RunId" | Set-Content -LiteralPath $runPath -Encoding utf8NoBOM
  Assert-True ($LASTEXITCODE -eq 0) 'Unable to read the GitHub workflow run.'
  & gh api "repos/$Repository/actions/runs/$RunId/jobs?per_page=100" | Set-Content -LiteralPath $jobsPath -Encoding utf8NoBOM
  Assert-True ($LASTEXITCODE -eq 0) 'Unable to read the GitHub workflow jobs.'
  & gh api "repos/$Repository" | Set-Content -LiteralPath $repoPath -Encoding utf8NoBOM
  Assert-True ($LASTEXITCODE -eq 0) 'Unable to read the GitHub repository.'
  $repositoryReadback = Get-Content -LiteralPath $repoPath -Raw | ConvertFrom-Json
  $defaultBranch = [string]$repositoryReadback.default_branch
  Assert-True (-not [string]::IsNullOrWhiteSpace($defaultBranch)) 'GitHub repository has no default branch.'
  $escapedBranch = [Uri]::EscapeDataString($defaultBranch)
  & gh api "repos/$Repository/branches/$escapedBranch" | Set-Content -LiteralPath $branchPath -Encoding utf8NoBOM
  Assert-True ($LASTEXITCODE -eq 0) 'Unable to read default-branch protection.'
  $artifactName = "pr-check-source-checkout-attestation-$RunId-1"
  $null = New-Item -ItemType Directory -Path $checkoutArtifactRoot
  & gh run download $RunId --repo $Repository --name $artifactName --dir $checkoutArtifactRoot 1>$null 2>$null
  Assert-True ($LASTEXITCODE -eq 0) 'Unable to download the exact source-checkout attestation artifact.'
  $checkoutFiles = @(Get-ChildItem -LiteralPath $checkoutArtifactRoot -File -Force)
  Assert-True ($checkoutFiles.Count -eq 1 -and $checkoutFiles[0].Name -ceq 'ci-source-checkout-attestation.json') 'Source-checkout artifact contents are not exact.'
  $checkoutPath = $checkoutFiles[0].FullName

  $builderOutput = @(
    & py -3 $builder `
      --repository $Repository `
      --source-sha $ExpectedSourceSha `
      --qualification-sha $ExpectedQualificationSha `
      --run $runPath `
      --jobs $jobsPath `
      --repository-readback $repoPath `
      --branch-readback $branchPath `
      --source-checkout-attestation $checkoutPath `
      --output $output.absolute 2>&1
  )
  Assert-True ($LASTEXITCODE -eq 0) "CI attestation builder failed: $($builderOutput -join ' ')"
} finally {
  if (Test-Path -LiteralPath $temporaryRoot) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force }
}

Assert-True (Test-Path -LiteralPath $output.absolute -PathType Leaf) 'CI attestation builder did not create the output.'
$sha = (Get-FileHash -LiteralPath $output.absolute -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "[exact-head-ci-attestation] status=evidence_written source_sha=$ExpectedSourceSha qualification_sha=$ExpectedQualificationSha run_id=$RunId evidence_sha256=$sha commit_required_before_validation=true provider_writes=false secret_output=false"
