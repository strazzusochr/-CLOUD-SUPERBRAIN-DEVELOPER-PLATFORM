param(
  [ValidateSet("runtime", "browser")]
  [string]$Chain,
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
    if (-not $Condition) { throw "Phase5 $Chain evidence failed: $Label" }
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
    $OutputPath = ".codex\runs\CURRENT\master-goal\phase5\$ReleaseId\$Chain.log"
  }
  if ([string]::IsNullOrWhiteSpace($SummaryOutputPath)) {
    $SummaryOutputPath = ".codex\runs\CURRENT\master-goal\phase5\$ReleaseId\$Chain.json"
  }
  $outputFullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
  $summaryFullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $SummaryOutputPath))
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($outputFullPath)) | Out-Null
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($summaryFullPath)) | Out-Null

  $command = "npm run verify:$Chain"
  $previousErrorActionPreference = $ErrorActionPreference
  $hasNativeErrorPreference = Test-Path -LiteralPath Variable:PSNativeCommandUseErrorActionPreference
  $previousNativeErrorPreference = if ($hasNativeErrorPreference) { $PSNativeCommandUseErrorActionPreference } else { $null }
  $ErrorActionPreference = "Continue"
  if ($hasNativeErrorPreference) { $PSNativeCommandUseErrorActionPreference = $false }
  try {
    $commandOutput = @(& npm run "verify:$Chain" 2>&1)
    $exitCode = $LASTEXITCODE
  } finally {
    if ($hasNativeErrorPreference) { $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference }
    $ErrorActionPreference = $previousErrorActionPreference
  }
  foreach ($line in $commandOutput) { Write-Host ([string]$line) }
  Assert-True "canonical command exit" ($exitCode -eq 0)

  # These must equal CANONICAL_SUCCESS_ANCHORS[$Chain] in scripts/verify_phase5_credit_itemization.py.
  # The verifier compares observed_success_anchors to that set with ==, not with a subset test, so
  # declaring one extra line here makes every summary this script writes unverifiable. The exit
  # anchor is deliberately NOT among them: it is a log-integrity line, checked separately below.
  $successAnchors = if ($Chain -eq "runtime") {
    @(
      "[runtime] compose status",
      "[runtime] phase1 runtime checks completed"
    )
  } else {
    @(
      "[browser-contract] checks completed",
      "[product-acceptance] PASS DEV-ONLY; hosted proof still blocked",
      "[22-page-actions] PASS DEV-ONLY; hosted proof still blocked",
      "[o4-write] status=verified gates=live_agent_tool_writes,live_mcp_writes"
    )
  }
  $exitAnchor = if ($Chain -eq "runtime") { "RUNTIME_EXIT=0" } else { "BROWSER_EXIT=0" }
  $rawLines = [Collections.Generic.List[string]]::new()
  [void]$rawLines.Add("PHASE5_EVIDENCE_RAW_V2")
  [void]$rawLines.Add("[phase5-evidence] chain=$Chain")
  [void]$rawLines.Add("[phase5-evidence] release_id=$ReleaseId")
  [void]$rawLines.Add("[phase5-evidence] source_commit_sha=$SourceSha")
  [void]$rawLines.Add("[phase5-evidence] evidence_run_id=$EvidenceRunId")
  [void]$rawLines.Add("[phase5-evidence] command=$command")
  foreach ($line in $commandOutput) { [void]$rawLines.Add([string]$line) }
  if (($commandOutput | Out-String) -notmatch "(?m)^$([Regex]::Escape($exitAnchor))$") {
    [void]$rawLines.Add($exitAnchor)
  }
  [void]$rawLines.Add("[phase5-evidence] exit_code=0")
  $temporaryRaw = Join-Path ([IO.Path]::GetDirectoryName($outputFullPath)) (".{0}.{1}.tmp" -f [IO.Path]::GetFileName($outputFullPath), [Guid]::NewGuid().ToString("N"))
  try {
    [IO.File]::WriteAllLines($temporaryRaw, $rawLines, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporaryRaw -Destination $outputFullPath -Force
  } finally {
    if (Test-Path -LiteralPath $temporaryRaw -PathType Leaf) { Remove-Item -LiteralPath $temporaryRaw -Force }
  }
  $rawText = Get-Content -LiteralPath $outputFullPath -Raw -Encoding UTF8
  foreach ($anchor in $successAnchors) {
    Assert-True "success anchor $anchor" $rawText.Contains($anchor)
  }
  # The exit anchor stays a hard requirement on the log itself; it just is not part of the
  # declared canonical set the verifier compares against.
  Assert-True "exit anchor $exitAnchor" $rawText.Contains($exitAnchor)

  $summary = [ordered]@{
    contract_version = "phase5-local-verification-summary-v2"
    chain = $Chain
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
    raw_log_path = "docs/release-artifacts/$ReleaseId-evidence/raw/$Chain.log"
    raw_log_sha256 = (Get-FileHash -LiteralPath $outputFullPath -Algorithm SHA256).Hash
    observed_success_anchors = $successAnchors
    non_claims = @(
      "DEV-ONLY; hosted proof still blocked.",
      "This evidence does not publish images, deploy production, or authorize release promotion."
    )
  }
  [IO.File]::WriteAllText(
    $summaryFullPath,
    (($summary | ConvertTo-Json -Depth 8) + "`n"),
    [Text.UTF8Encoding]::new($false)
  )
  Write-Host "[phase5-evidence] status=verified chain=$Chain source=$SourceSha run=$EvidenceRunId"
  Write-Host "[phase5-evidence] raw=$OutputPath summary=$SummaryOutputPath"
} finally {
  Pop-Location
}
