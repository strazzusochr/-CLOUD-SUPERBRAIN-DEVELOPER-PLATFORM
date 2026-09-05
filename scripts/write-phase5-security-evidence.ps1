param(
  [string]$ReleaseId = "",
  [string]$SourceSha = "",
  [string]$EvidenceRunId = "",
  [string]$OutputPath = "",
  [string]$SummaryOutputPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
Push-Location -LiteralPath $repoRoot
try {
  function Assert-True([string]$Label, [bool]$Condition) {
    if (-not $Condition) { throw "Phase5 security evidence failed: $Label" }
  }

  if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
    $pointer = Get-Content -LiteralPath "docs\release-artifacts\current-release-candidate.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $ReleaseId = [string]$pointer.active_release_id
  }
  Assert-True "release id" ($ReleaseId -match '^prod-candidate-\d{4}-\d{2}-\d{2}-local-rc\d+$')
  $candidatePath = Join-Path $repoRoot "docs\release-artifacts\$ReleaseId.md"
  Assert-True "candidate artifact exists" (Test-Path -LiteralPath $candidatePath -PathType Leaf)
  $candidate = Get-Content -LiteralPath $candidatePath -Raw -Encoding UTF8
  Assert-True "candidate source commit is declared" ($candidate -match '(?m)^source_commit_sha:\s*`([0-9a-f]{40})`\s*$')
  $declaredSourceSha = $Matches[1]
  if ([string]::IsNullOrWhiteSpace($SourceSha)) { $SourceSha = $declaredSourceSha }
  Assert-True "source matches candidate" ($SourceSha -eq $declaredSourceSha)
  $resolvedSourceSha = (& git rev-parse "$SourceSha^{commit}" 2>$null | Out-String).Trim()
  Assert-True "source commit resolves exactly" ($LASTEXITCODE -eq 0 -and $resolvedSourceSha -eq $SourceSha)
  Assert-True "v2 does not relabel RC11 legacy evidence" (-not (
    $ReleaseId -eq "prod-candidate-2026-07-31-local-rc11" -and
    $SourceSha -eq "bae3cdc1692e1e99e7f546f72664a3c747958b8c"
  ))
  if ([string]::IsNullOrWhiteSpace($EvidenceRunId)) {
    $EvidenceRunId = [Guid]::NewGuid().ToString("D").ToLowerInvariant()
  }
  Assert-True "evidence run id" (
    $EvidenceRunId -match '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  )
  if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = ".codex\runs\CURRENT\master-goal\phase5\$ReleaseId\security.log"
  }
  if ([string]::IsNullOrWhiteSpace($SummaryOutputPath)) {
    $SummaryOutputPath = ".codex\runs\CURRENT\master-goal\phase5\$ReleaseId\security.json"
  }
  $outputFullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
  $summaryFullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $SummaryOutputPath))
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($outputFullPath)) | Out-Null
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($summaryFullPath)) | Out-Null

  $tempBase = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) "superbrain-phase5-security-v2"))
  [IO.Directory]::CreateDirectory($tempBase) | Out-Null
  $workPath = [IO.Path]::GetFullPath((Join-Path $tempBase ([Guid]::NewGuid().ToString("N"))))
  $tempPrefix = $tempBase.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  Assert-True "temporary workspace is bounded" (
    $workPath.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and $workPath -ne $tempBase
  )
  $sourcePath = Join-Path $workPath "source"
  $archivePath = Join-Path $workPath "source.tar"
  [IO.Directory]::CreateDirectory($sourcePath) | Out-Null

  $command = (
    "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/write-phase5-security-evidence.ps1 " +
    "-ReleaseId $ReleaseId -SourceSha $SourceSha -EvidenceRunId $EvidenceRunId"
  )
  $lines = [Collections.Generic.List[string]]::new()
  [void]$lines.Add("PHASE5_EVIDENCE_RAW_V2")
  [void]$lines.Add("[phase5-evidence] chain=security")
  [void]$lines.Add("[phase5-evidence] release_id=$ReleaseId")
  [void]$lines.Add("[phase5-evidence] source_commit_sha=$SourceSha")
  [void]$lines.Add("[phase5-evidence] evidence_run_id=$EvidenceRunId")
  [void]$lines.Add("[phase5-evidence] command=$command")
  [void]$lines.Add("PHASE5_SECURITY_EVIDENCE_V2")
  [void]$lines.Add("[phase5-security] source_boundary=committed_git_archive_only")
  try {
    & git archive --format=tar "--output=$archivePath" $SourceSha
    Assert-True "git archive" ($LASTEXITCODE -eq 0)
    & tar.exe -xf $archivePath -C $sourcePath
    Assert-True "archive extraction" ($LASTEXITCODE -eq 0)

    [void]$lines.Add("=== npm audit --audit-level=moderate (candidate apps/frontend) ===")
    # Same reason as the gitleaks call below: npm writes progress and warnings to stderr, and
    # under $ErrorActionPreference = 'Stop' those records become a terminating NativeCommandError
    # before the exit code can be read. The exit code remains the gate.
    $previousAuditErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $auditOutput = @(& npm audit --audit-level=moderate --prefix (Join-Path $sourcePath "apps\frontend") 2>&1)
      $auditExit = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousAuditErrorAction
    }
    foreach ($line in $auditOutput) { [void]$lines.Add([string]$line) }
    [void]$lines.Add("NPM_AUDIT_EXIT=$auditExit")
    Assert-True "npm audit" ($auditExit -eq 0)
    # Written only after the exit code proved clean. CANONICAL_SUCCESS_ANCHORS["security"] in
    # verify_phase5_credit_itemization.py requires this exact line, so a log without it cannot
    # be credited — which is the point: the verdict is recorded, not inferred from prose.
    [void]$lines.Add("[phase5-security] npm_audit_verified=true")

    $gitleaksCommand = Get-Command gitleaks -ErrorAction SilentlyContinue
    $repoLocalGitleaks = Join-Path $repoRoot ".tools\gitleaks\gitleaks.exe"
    if ($null -ne $gitleaksCommand) {
      $gitleaksExecutable = $gitleaksCommand.Source
    } elseif (Test-Path -LiteralPath $repoLocalGitleaks -PathType Leaf) {
      $gitleaksExecutable = $repoLocalGitleaks
    } else {
      throw "Phase5 security evidence failed: canonical gitleaks binary is unavailable"
    }
    [void]$lines.Add("=== canonical gitleaks (candidate archive) ===")
    [void]$lines.Add("[phase5-security] gitleaks_config=.gitleaks.toml")
    # gitleaks prints its banner and its summary line to stderr even on a clean scan, and under
    # $ErrorActionPreference = 'Stop' PowerShell turns those into a terminating
    # NativeCommandError before the exit code can be read — a passing scan looked like a crash.
    $previousGitleaksErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $gitleaksOutput = @(
        & $gitleaksExecutable detect --no-git --source $sourcePath --config (Join-Path $sourcePath ".gitleaks.toml") --redact --timeout 600 2>&1
      )
      $gitleaksExit = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousGitleaksErrorAction
    }
    foreach ($line in $gitleaksOutput) { [void]$lines.Add([string]$line) }
    [void]$lines.Add("GITLEAKS_EXIT=$gitleaksExit")
    Assert-True "gitleaks" ($gitleaksExit -eq 0)
    [void]$lines.Add("[phase5-security] gitleaks_verified=true")
    [void]$lines.Add("PHASE5_SECURITY_EXIT=0")
    [void]$lines.Add("[phase5-evidence] exit_code=0")

    $temporaryRaw = Join-Path ([IO.Path]::GetDirectoryName($outputFullPath)) (".{0}.{1}.tmp" -f [IO.Path]::GetFileName($outputFullPath), [Guid]::NewGuid().ToString("N"))
    try {
      [IO.File]::WriteAllLines($temporaryRaw, $lines, [Text.UTF8Encoding]::new($false))
      Move-Item -LiteralPath $temporaryRaw -Destination $outputFullPath -Force
    } finally {
      if (Test-Path -LiteralPath $temporaryRaw -PathType Leaf) { Remove-Item -LiteralPath $temporaryRaw -Force }
    }
  } finally {
    if (Test-Path -LiteralPath $workPath -PathType Container) {
      $resolvedWorkPath = (Resolve-Path -LiteralPath $workPath).Path
      Assert-True "cleanup remains bounded" (
        $resolvedWorkPath.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and $resolvedWorkPath -ne $tempBase
      )
      Remove-Item -LiteralPath $resolvedWorkPath -Recurse -Force
    }
  }

  # Must equal CANONICAL_SUCCESS_ANCHORS["security"] in verify_phase5_credit_itemization.py —
  # the verifier compares with ==, so tool-prose lines like "found 0 vulnerabilities" or
  # "no leaks found" cannot appear here. They stay in the raw log; what is DECLARED are the two
  # explicit verdict lines this script writes only after each exit code proved clean.
  $successAnchors = @(
    "PHASE5_SECURITY_EVIDENCE_V2",
    "[phase5-security] source_boundary=committed_git_archive_only",
    "[phase5-security] npm_audit_verified=true",
    "NPM_AUDIT_EXIT=0",
    "[phase5-security] gitleaks_config=.gitleaks.toml",
    "[phase5-security] gitleaks_verified=true",
    "GITLEAKS_EXIT=0",
    "PHASE5_SECURITY_EXIT=0"
  )
  $rawText = Get-Content -LiteralPath $outputFullPath -Raw -Encoding UTF8
  foreach ($anchor in $successAnchors) { Assert-True "success anchor $anchor" $rawText.Contains($anchor) }
  $summary = [ordered]@{
    contract_version = "phase5-local-verification-summary-v2"
    chain = "security"
    release_id = $ReleaseId
    source_commit_sha = $SourceSha
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    command = $command
    status = "passed"
    exit_code = 0
    dev_only = $true
    hosted_proof = $false
    secret_output = $false
    evidence_run_id = $EvidenceRunId
    raw_log_path = "docs/release-artifacts/$ReleaseId-evidence/raw/security.log"
    raw_log_sha256 = (Get-FileHash -LiteralPath $outputFullPath -Algorithm SHA256).Hash
    observed_success_anchors = $successAnchors
    non_claims = @(
      "DEV-ONLY; hosted proof still blocked.",
      "The scan boundary is the committed candidate git archive only.",
      "This evidence does not publish a registry image, deploy production, or disclose secrets."
    )
  }
  [IO.File]::WriteAllText($summaryFullPath, (($summary | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
  Write-Host "[phase5-security] status=verified source=$SourceSha run=$EvidenceRunId"
  Write-Host "[phase5-security] raw=$OutputPath summary=$SummaryOutputPath"
} finally {
  Pop-Location
}
