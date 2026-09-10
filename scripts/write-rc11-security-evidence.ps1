param(
  [string]$ReleaseId = "",
  [string]$SourceSha = "",
  [string]$OutputPath = ".codex\runs\CURRENT\master-goal\phase5\rc11\security.log"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
Set-Location -LiteralPath $repoRoot

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) {
    throw "RC11 security evidence failed: $Label"
  }
}

if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
  $pointer = Get-Content -LiteralPath "docs\release-artifacts\current-release-candidate.json" -Raw -Encoding UTF8 | ConvertFrom-Json
  $ReleaseId = [string]$pointer.active_release_id
}
Assert-True "release id" ($ReleaseId -match "^[A-Za-z0-9._-]{1,128}$")

$candidatePath = Join-Path $repoRoot ("docs\release-artifacts\{0}.md" -f $ReleaseId)
Assert-True "candidate artifact exists" (Test-Path -LiteralPath $candidatePath -PathType Leaf)
$candidateText = Get-Content -LiteralPath $candidatePath -Raw -Encoding UTF8
Assert-True "candidate source commit is declared" ($candidateText -match '(?m)^source_commit_sha:\s*`([0-9a-f]{40})`\s*$')
$declaredSourceSha = $Matches[1]
if ([string]::IsNullOrWhiteSpace($SourceSha)) {
  $SourceSha = $declaredSourceSha
}
Assert-True "requested source matches candidate" ($SourceSha -eq $declaredSourceSha)

$resolvedSourceSha = (& git -C $repoRoot rev-parse "$SourceSha^{commit}" 2>$null | Out-String).Trim()
Assert-True "candidate source commit resolves" ($LASTEXITCODE -eq 0 -and $resolvedSourceSha -match "^[0-9a-f]{40}$")
Assert-True "candidate source commit is exact" ($resolvedSourceSha -eq $SourceSha)

$outputFullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
$outputDirectory = [IO.Path]::GetDirectoryName($outputFullPath)
[IO.Directory]::CreateDirectory($outputDirectory) | Out-Null

$tempBase = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) "superbrain-rc11-security"))
[IO.Directory]::CreateDirectory($tempBase) | Out-Null
$workPath = [IO.Path]::GetFullPath((Join-Path $tempBase ([Guid]::NewGuid().ToString("N"))))
$tempPrefix = $tempBase.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
Assert-True "temporary workspace is bounded" (
  $workPath.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
  $workPath -ne $tempBase
)

$sourcePath = Join-Path $workPath "source"
$archivePath = Join-Path $workPath "source.tar"
[IO.Directory]::CreateDirectory($sourcePath) | Out-Null

$lines = [Collections.Generic.List[string]]::new()
[void]$lines.Add("RC11_SECURITY_EVIDENCE_V1")
[void]$lines.Add("[rc11-security] release_id=$ReleaseId")
[void]$lines.Add("[rc11-security] source_commit_sha=$resolvedSourceSha")
[void]$lines.Add("[rc11-security] source_boundary=committed_git_archive_only")

try {
  & git -C $repoRoot archive --format=tar "--output=$archivePath" $resolvedSourceSha
  Assert-True "git archive" ($LASTEXITCODE -eq 0)

  & tar.exe -xf $archivePath -C $sourcePath
  Assert-True "archive extraction" ($LASTEXITCODE -eq 0)

  [void]$lines.Add("=== npm audit --audit-level=moderate (candidate apps/frontend) ===")
  $auditOutput = @(& npm audit --audit-level=moderate --prefix (Join-Path $sourcePath "apps\frontend") 2>&1)
  $auditExit = $LASTEXITCODE
  foreach ($line in $auditOutput) {
    [void]$lines.Add([string]$line)
  }
  [void]$lines.Add("NPM_AUDIT_EXIT=$auditExit")
  Assert-True "npm audit" ($auditExit -eq 0)

  $gitleaksCommand = Get-Command gitleaks -ErrorAction SilentlyContinue
  $repoLocalGitleaks = Join-Path $repoRoot ".tools\gitleaks\gitleaks.exe"
  if ($null -ne $gitleaksCommand) {
    $gitleaksExecutable = $gitleaksCommand.Source
  } elseif (Test-Path -LiteralPath $repoLocalGitleaks -PathType Leaf) {
    $gitleaksExecutable = $repoLocalGitleaks
  } else {
    throw "RC11 security evidence failed: canonical gitleaks binary is unavailable"
  }

  [void]$lines.Add("=== canonical gitleaks (candidate archive) ===")
  [void]$lines.Add("[rc11-security] gitleaks_config=.gitleaks.toml")
  [void]$lines.Add("[rc11-security] gitleaks_scope=candidate_git_archive")
  $gitleaksOutput = @(
    & $gitleaksExecutable detect `
      --no-git `
      --source $sourcePath `
      --config (Join-Path $sourcePath ".gitleaks.toml") `
      --redact `
      --timeout 600 2>&1
  )
  $gitleaksExit = $LASTEXITCODE
  foreach ($line in $gitleaksOutput) {
    [void]$lines.Add([string]$line)
  }
  [void]$lines.Add("GITLEAKS_EXIT=$gitleaksExit")
  Assert-True "gitleaks" ($gitleaksExit -eq 0)

  [void]$lines.Add("RC11_SECURITY_EXIT=0")
  $temporaryOutput = Join-Path $outputDirectory (".{0}.{1}.tmp" -f [IO.Path]::GetFileName($outputFullPath), [Guid]::NewGuid().ToString("N"))
  try {
    [IO.File]::WriteAllLines($temporaryOutput, $lines, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryOutput -Destination $outputFullPath -Force
  } finally {
    if (Test-Path -LiteralPath $temporaryOutput -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryOutput -Force
    }
  }
} finally {
  if (Test-Path -LiteralPath $workPath -PathType Container) {
    $resolvedWorkPath = (Resolve-Path -LiteralPath $workPath).Path
    Assert-True "cleanup target remains bounded" (
      $resolvedWorkPath.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
      $resolvedWorkPath -ne $tempBase
    )
    Remove-Item -LiteralPath $resolvedWorkPath -Recurse -Force
  }
}

$hash = (Get-FileHash -LiteralPath $outputFullPath -Algorithm SHA256).Hash
Write-Host "[rc11-security] status=verified source=$resolvedSourceSha sha256=$hash"
Write-Host "[rc11-security] artifact=$OutputPath"
