param(
  [Parameter(Mandatory = $true)][string]$SourceSha,
  [Parameter(Mandatory = $true)][string]$ReleaseId,
  [string]$OutputPath = "docs\runtime-state\source-qualification-control.json"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-True([string]$Label, [bool]$Value) {
  if (-not $Value) { throw "Source qualification control failed: $Label" }
}

function Get-GitArchiveSha256([string]$CommitSha) {
  $archivePath = Join-Path ([IO.Path]::GetTempPath()) ("source-qualification-{0}.tar" -f ([Guid]::NewGuid().ToString('N')))
  try {
    & git -C $repoRoot archive --format=tar "--output=$archivePath" $CommitSha
    Assert-True "source archive created" ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $archivePath -PathType Leaf))
    return (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
  } finally {
    if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
  }
}

Assert-True "source SHA is exact" ($SourceSha -cmatch '^[0-9a-f]{40}$')
Assert-True "release ID is exact" ($ReleaseId -cmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-local-rc[0-9]+$')
& git -C $repoRoot cat-file -e "$SourceSha^{commit}" 2>$null
Assert-True "source commit exists" ($LASTEXITCODE -eq 0)
$sourceArchiveSha256 = Get-GitArchiveSha256 $SourceSha
Assert-True "source archive SHA-256 is exact" ($sourceArchiveSha256 -cmatch '^[0-9a-f]{64}$')

$resolvedOutput = [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
$expectedOutput = [IO.Path]::GetFullPath((Join-Path $repoRoot 'docs\runtime-state\source-qualification-control.json'))
Assert-True "output path is exact" ($resolvedOutput -ceq $expectedOutput)

$control = [ordered]@{
  '$schema' = "../runtime-contracts/source-qualification-control.schema.json"
  contract_version = "source-qualification-control-v1"
  release_id = $ReleaseId
  runtime_candidate_sha = $SourceSha
  source_archive_sha256 = $sourceArchiveSha256
  production_rollout_claimed = $false
  percentage_credit_awarded = 0
  secret_output = $false
}
New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedOutput) -Force | Out-Null
$control | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $resolvedOutput -Encoding utf8NoBOM
Write-Host "[source-qualification-control] written release=$ReleaseId source=$SourceSha archive=$sourceArchiveSha256 credit=0 rollout=false secret_output=false"
