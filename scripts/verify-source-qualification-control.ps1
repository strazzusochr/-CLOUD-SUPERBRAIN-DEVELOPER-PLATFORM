param(
  [Parameter(Mandatory = $true)][string]$ExpectedSourceSha,
  [Parameter(Mandatory = $true)][string]$ExpectedReleaseId,
  [string]$ControlPath = "docs\runtime-state\source-qualification-control.json"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-True([string]$Label, [bool]$Value) {
  if (-not $Value) { throw "Source qualification control verification failed: $Label" }
}

function Get-GitArchiveSha256([string]$CommitSha) {
  $archivePath = Join-Path ([IO.Path]::GetTempPath()) ("source-qualification-verify-{0}.tar" -f ([Guid]::NewGuid().ToString('N')))
  try {
    & git -C $repoRoot archive --format=tar "--output=$archivePath" $CommitSha
    Assert-True "source archive created" ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $archivePath -PathType Leaf))
    return (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
  } finally {
    if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
  }
}

$resolvedControl = [IO.Path]::GetFullPath((Join-Path $repoRoot $ControlPath))
$expectedControl = [IO.Path]::GetFullPath((Join-Path $repoRoot 'docs\runtime-state\source-qualification-control.json'))
Assert-True "control path is exact" ($resolvedControl -ceq $expectedControl)
Assert-True "control exists" (Test-Path -LiteralPath $resolvedControl -PathType Leaf)
$control = Get-Content -LiteralPath $resolvedControl -Raw | ConvertFrom-Json
Assert-True "field set is exact" ((@($control.PSObject.Properties.Name | Sort-Object) -join ',') -ceq '$schema,contract_version,percentage_credit_awarded,production_rollout_claimed,release_id,runtime_candidate_sha,secret_output,source_archive_sha256')
Assert-True "schema" ([string]$control.'$schema' -ceq '../runtime-contracts/source-qualification-control.schema.json')
Assert-True "contract" ([string]$control.contract_version -ceq 'source-qualification-control-v1')
Assert-True "source" ([string]$control.runtime_candidate_sha -ceq $ExpectedSourceSha)
Assert-True "archive shape" ([string]$control.source_archive_sha256 -cmatch '^[0-9a-f]{64}$')
Assert-True "release" ([string]$control.release_id -ceq $ExpectedReleaseId)
Assert-True "rollout false" ($control.production_rollout_claimed -is [bool] -and -not $control.production_rollout_claimed)
Assert-True "credit zero" ([int]$control.percentage_credit_awarded -eq 0)
Assert-True "secret output false" ($control.secret_output -is [bool] -and -not $control.secret_output)
& git -C $repoRoot cat-file -e "$ExpectedSourceSha^{commit}" 2>$null
Assert-True "source commit exists" ($LASTEXITCODE -eq 0)
$computedArchiveSha256 = Get-GitArchiveSha256 $ExpectedSourceSha
Assert-True "archive matches source commit" ([string]$control.source_archive_sha256 -ceq $computedArchiveSha256)
Write-Host "[source-qualification-control] verified release=$ExpectedReleaseId source=$ExpectedSourceSha archive=$computedArchiveSha256 credit=0 rollout=false secret_output=false"
