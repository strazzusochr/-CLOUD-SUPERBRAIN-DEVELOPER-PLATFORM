#Requires -Version 7.0
[CmdletBinding()]
param()

# Offline contract integration: inspect the REAL writer and reader, never send HTTP.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Read-ScriptAst([string]$Name) {
  $tokens = $null; $errors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $Name), [ref]$tokens, [ref]$errors)
  if (@($errors).Count -ne 0) { throw "Contract script parse failed: $Name" }
  return $ast
}

function Get-WriterKeys($Ast, [string]$UniqueKey) {
  $tables = @($Ast.FindAll({ param($node) $node -is [Management.Automation.Language.HashtableAst] }, $true) | Where-Object {
    @($_.KeyValuePairs | ForEach-Object { $_.Item1.SafeGetValue() }) -ccontains $UniqueKey
  })
  if ($tables.Count -ne 1) { throw "Ambiguous writer contract: $UniqueKey" }
  return @($tables[0].KeyValuePairs | ForEach-Object { [string]$_.Item1.SafeGetValue() })
}

function Get-ReaderKeys($Ast, [string]$Variable, [switch]$Assignment) {
  if ($Assignment) {
    $matches = @($Ast.FindAll({ param($node)
      $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -ceq $Variable
    }, $true))
    if ($matches.Count -ne 1) { throw "Ambiguous reader property set: $Variable" }
    $value = $matches[0].Right.Extent.Text
  } else {
    $matches = @($Ast.FindAll({ param($node)
      $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ceq 'Assert-ExactProperties' -and
        $node.CommandElements.Count -gt 2 -and $node.CommandElements[1].Extent.Text -ceq $Variable
    }, $true))
    if ($matches.Count -ne 1) { throw "Ambiguous reader contract: $Variable" }
    $value = $matches[0].CommandElements[2].Extent.Text
  }
  # Only literal arrays are accepted; never execute script commands from the writer.
  if ($value -notmatch "^@\([\s\S]*\)$" -or $value -match '[`$;{}]') { throw 'Reader property set is not a literal array.' }
  return @(& ([scriptblock]::Create($value)))
}

function Assert-SameKeys([string[]]$Expected, [string[]]$Actual, [string]$Label) {
  $delta = @(Compare-Object $Expected $Actual -CaseSensitive)
  if ($Expected.Count -ne $Actual.Count -or $delta.Count -ne 0) {
    throw "$Label writer/reader property mismatch: $(@($delta.InputObject) -join ', ')"
  }
}

$runtimeAst = Read-ScriptAst 'verify-phase6-scale-runtime.ps1'
$evidenceAst = Read-ScriptAst 'verify-phase6-scale-evidence.ps1'
Assert-SameKeys (Get-WriterKeys $runtimeAst 'verifier_script_sha256') (Get-ReaderKeys $evidenceAst '$sourceProperties' -Assignment) 'Source binding'
Assert-SameKeys (Get-WriterKeys $runtimeAst 'post_run_api_readback_required') (Get-ReaderKeys $evidenceAst '$executionBinding') 'Execution binding'
foreach ($pair in @(
  @('criterion_binding', '$topProperties', $true),
  @('declared_before_first_full_write_run', '$evidence.criterion_binding', $false),
  @('control_edge_requests_issued', '$evidence.request_budget', $false),
  @('review_artifact_sha256', '$environmentReviewBinding', $false),
  @('execution_readback_artifact', '$postRunReadback', $false),
  @('active_release_id', '$releaseBinding', $false)
)) {
  Assert-SameKeys (Get-WriterKeys $runtimeAst $pair[0]) (Get-ReaderKeys $evidenceAst $pair[1] -Assignment:$pair[2]) $pair[0]
}

. (Join-Path $PSScriptRoot 'phase6-control-contract.ps1')
function Assert-Rejected([scriptblock]$Action, [string]$Label) {
  $rejected = $false
  try { $null = & $Action } catch { $rejected = $true }
  if (-not $rejected) { throw "Negative contract unexpectedly accepted: $Label" }
}

$candidate = ConvertFrom-Phase6Json (Get-Content -LiteralPath (Join-Path $repoRoot 'docs/release-artifacts/current-release-candidate.json') -Raw)
$hosted = ConvertFrom-Phase6Json (Get-Content -LiteralPath (Join-Path $repoRoot 'docs/runtime-state/cloudflare-native-hosted-current.json') -Raw)
$deployment = ConvertFrom-Phase6Json (Get-Content -LiteralPath (Join-Path $repoRoot 'docs/runtime-state/phase6-scale-hosted-current.json') -Raw)
$sourceSha = [string]$hosted.source_commit_sha
$controlReleaseId = [string]$candidate.active_release_id
$trackedScaleEvidence = @(& git -C $repoRoot ls-files -- '.phase1-artifacts/phase6-scale/scale-evidence-*.json')
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate tracked Phase6 scale evidence.' }
$trackedScaleEvidence = @($trackedScaleEvidence | Where-Object { $_ -cnotmatch '\.execution-readback\.json$' })

if ($trackedScaleEvidence.Count -gt 1) {
  throw 'Static control-position probe found ambiguous tracked Phase6 scale evidence.'
}

if ($trackedScaleEvidence.Count -eq 1) {
  # Once immutable evidence exists, HEAD is intentionally later than the live-run control.
  # Reconstruct the audited S -> control prefix from the evidence instead of treating the
  # subsequent evidence commit as runtime drift.
  $evidenceRelativePath = [string]$trackedScaleEvidence[0]
  if ($evidenceRelativePath -cnotmatch '^\.phase1-artifacts/phase6-scale/scale-evidence-[A-Za-z0-9-]+\.json$') {
    throw 'Tracked Phase6 scale evidence path is noncanonical.'
  }
  $scaleEvidence = ConvertFrom-Phase6Json (Get-Content -LiteralPath (Join-Path $repoRoot $evidenceRelativePath) -Raw)
  if ([string]$scaleEvidence.contract_version -cne 'phase6-scale-evidence-v2') {
    throw 'Tracked Phase6 scale evidence contract is invalid.'
  }
  $recordedRelease = $scaleEvidence.source_binding.release_candidate
  if ([string]$recordedRelease.active_release_id -cnotmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-local-rc[1-9][0-9]*$' -or
      [string]$recordedRelease.source_commit_sha -cne $sourceSha) {
    throw 'Tracked Phase6 scale evidence cannot identify its audited release/source pair.'
  }
  # The P6 control prefix belongs to the immutable release recorded by the one-shot
  # evidence. A later no-credit candidate selection must not reinterpret historical
  # RC48 paths under the newer release prefix.
  $controlReleaseId = [string]$recordedRelease.active_release_id
  $attestation = $scaleEvidence.source_binding.execution_attestation
  if ([string]$attestation.contract_version -cne 'phase6-scale-execution-provenance-v1' -or
      [string]$attestation.source_commit_sha -cne $sourceSha -or
      [string]$attestation.head_sha -cnotmatch '^[0-9a-f]{40}$') {
    throw 'Tracked Phase6 scale execution attestation cannot identify the audited control prefix.'
  }
  $controlHead = [string]$attestation.head_sha
  & git -C $repoRoot cat-file -e "$controlHead^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0) { throw 'Recorded Phase6 control commit is unavailable.' }
  & git -C $repoRoot merge-base --is-ancestor $sourceSha $controlHead
  if ($LASTEXITCODE -ne 0) { throw 'Recorded Phase6 control commit does not descend from the hosted source.' }
  & git -C $repoRoot merge-base --is-ancestor $controlHead HEAD
  if ($LASTEXITCODE -ne 0) { throw 'Recorded Phase6 control commit is not an ancestor of the current evidence head.' }

  [string[]]$actualDelta = @(& git -C $repoRoot diff --name-only --diff-filter=ACDMRTUXB $sourceSha $controlHead --)
  if ($LASTEXITCODE -ne 0) { throw 'Cannot reconstruct the recorded source/control delta.' }
  if (@($attestation.control_delta | Where-Object { $_ -isnot [string] }).Count -ne 0) {
    throw 'Recorded Phase6 control delta contains a non-string path.'
  }
  [string[]]$recordedDelta = @($attestation.control_delta)
  [Array]::Sort($actualDelta, [StringComparer]::Ordinal)
  [Array]::Sort($recordedDelta, [StringComparer]::Ordinal)
  if ($actualDelta.Count -ne $recordedDelta.Count -or
      ($actualDelta -join "`n") -cne ($recordedDelta -join "`n")) {
    throw 'Recorded Phase6 control delta differs from the reconstructed Git prefix.'
  }
  [string[]]$auditedDelta = @($actualDelta)
} else {
  [string[]]$actualDelta = @(& git -C $repoRoot diff --name-only --diff-filter=ACDMRTUXB $sourceSha HEAD --)
  if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve source/control delta for the integration test.' }
  # Before the transport repair exists, test its exact prospective control-only extension.
  # Once those files exist, Select-Object keeps the audited path set stable.
  $fixExtension = @('scripts/phase6-control-contract.ps1', 'scripts/verify-phase6-contract-chain-static.ps1',
    'scripts/verify-phase6-scale-evidence.ps1', 'scripts/verify-phase6-scale-evidence-static.ps1',
    'scripts/collect-phase6-scale-execution-readback.ps1')
  [string[]]$auditedDelta = @(@($actualDelta) + $fixExtension | Select-Object -Unique)
}
[Array]::Sort($auditedDelta, [StringComparer]::Ordinal)
$policy = @{ ReleaseId=$controlReleaseId; HostedEvidencePath=[string]$hosted.evidence_artifact; DeploymentEvidencePath=[string]$deployment.evidence_artifact }
$accepted = @(Assert-Phase6ControlDelta -Paths $auditedDelta -SafePaths $auditedDelta @policy)
if ($accepted.Count -ne 81) { throw 'Unexpected audited P6 control path count.' }

# Invoke each real call site with its production fingerprint check enabled.
foreach ($ast in @($runtimeAst, $evidenceAst)) {
  $call = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ceq 'Assert-Phase6ControlDelta' }, $true))
  if ($call.Count -ne 1) { throw 'Each P6 verifier must use exactly one shared delta check.' }
  $controlDelta = $auditedDelta; $safeControlDelta = $auditedDelta; $controlDeltaPaths = $auditedDelta
  $activeReleaseId = $policy.ReleaseId; $canonicalHostedEvidenceRelativePath = $policy.HostedEvidencePath
  $hostedEvidenceRelativePath = $policy.DeploymentEvidencePath; $AllowTestPaths = $false
  $releaseBinding = [pscustomobject]@{ active_release_id=$policy.ReleaseId }
  $evidence = [pscustomobject]@{ source_binding=[pscustomobject]@{ hosted_runtime_evidence_artifact=$policy.HostedEvidencePath; deployment_evidence_artifact=$policy.DeploymentEvidencePath } }
  $null = & ([scriptblock]::Create($call[0].Extent.Text))
}
foreach ($badPath in @('services/agent-api/app/main.py', '.github/workflows/main-deploy.yml', 'apps/frontend/app/page.tsx',
  "docs/release-artifacts/$($policy.ReleaseId)-evidence/../escape.json", 'docs/release-artifacts/other-evidence/report.json',
  "docs/release-artifacts/$($policy.ReleaseId)-evidence/unreviewed.json", '../escape.json', '/tmp/report.json')) {
  $bad = @($auditedDelta) + $badPath
  Assert-Rejected { Assert-Phase6ControlDelta -Paths $bad -SafePaths $bad @policy } $badPath
}
$duplicate = @($auditedDelta) + $auditedDelta[0]
Assert-Rejected { Assert-Phase6ControlDelta -Paths $duplicate -SafePaths $duplicate @policy } 'duplicate path'
Assert-Rejected { Assert-Phase6ControlDelta -Paths $auditedDelta -SafePaths $auditedDelta[1..80] @policy } 'deleted or renamed path'
Assert-Rejected { Assert-Phase6ControlDelta -Paths $auditedDelta[1..80] -SafePaths $auditedDelta[1..80] @policy } 'missing audited path'

# Exercise the actual collector serializer, not a separately handwritten fixture.
$collectorAst = Read-ScriptAst 'collect-phase6-scale-execution-readback.ps1'
$collectorSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'collect-phase6-scale-execution-readback.ps1') -Raw
$evidenceSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'verify-phase6-scale-evidence.ps1') -Raw
foreach ($transportSource in @($collectorSource, $evidenceSource)) {
  foreach ($requiredTransportContract in @(
    'UseGitHubCliCredentialForArtifactDownload',
    'ExpectedPostRunTransportRepairSha',
    "Environment.Remove('GH_TOKEN')",
    "Environment.Remove('GITHUB_TOKEN')",
    "'--hostname', 'github.com', '--method', 'GET'"
  )) {
    if (-not $transportSource.Contains($requiredTransportContract)) { throw "Missing authenticated read-only transport contract: $requiredTransportContract" }
  }
  if ($transportSource -match '(?i)DefaultRequestHeaders\.Authorization|Bearer\s|\$env:(?:GITHUB_TOKEN|GH_TOKEN)') {
    throw 'Authenticated read-only transport must stay inside GitHub CLI and must not export or directly handle a token.'
  }
}
$writer = @($collectorAst.FindAll({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -ceq '$readback' }, $true))
if ($writer.Count -ne 1) { throw 'Collector readback writer is ambiguous.' }
$repository = 'fixture/repository'
$sampleJson = '{"id":34266062638,"run_attempt":1,"event":"workflow_dispatch","status":"completed","conclusion":"success","head_branch":"test","head_sha":"0000000000000000000000000000000000000000","html_url":"https://github.com/fixture/repository/actions/runs/34266062638","created_at":"2026-09-08T18:57:00Z","updated_at":"2026-09-08T18:58:00.1234567Z"}'
$run = ConvertFrom-Phase6Json $sampleJson
$artifact = ConvertFrom-Phase6Json '{"id":12345,"name":"fixture","expired":false,"digest":"sha256:fixture","url":"https://api.github.com/fixture","archive_download_url":"https://api.github.com/fixture/zip","workflow_run":{"id":34266062638,"head_sha":"0000000000000000000000000000000000000000"},"created_at":"2026-09-08T18:57:00Z","updated_at":"2026-09-08T18:58:00.1234567Z"}'
$archiveSha256 = 'a' * 64; $downloadedEvidenceSha256 = 'b' * 64; $downloadedSidecarSha256 = 'c' * 64; $evidenceSha256 = 'b' * 64
. ([scriptblock]::Create($writer[0].Extent.Text))
$roundtrip = ConvertFrom-Phase6Json ($readback | ConvertTo-Json -Depth 20)
foreach ($value in @($roundtrip.collected_at_utc, $roundtrip.run.created_at, $roundtrip.run.updated_at, $roundtrip.artifact.created_at, $roundtrip.artifact.updated_at)) {
  if ($value -isnot [string] -or $value -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?Z$') { throw 'Collector emitted a noncanonical UTC timestamp.' }
}
if ($roundtrip.run.id -ne 34266062638L -or $roundtrip.run.id -isnot [long]) { throw 'Collector truncated the GitHub Int64 run ID.' }
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$utcReader = @($evidenceAst.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'ConvertTo-UtcTimestamp' }, $true))
if ($utcReader.Count -ne 1) { throw 'UTC reader is ambiguous.' }
. ([scriptblock]::Create($utcReader[0].Extent.Text))
foreach ($value in @($roundtrip.collected_at_utc, $roundtrip.run.created_at, $roundtrip.run.updated_at, $roundtrip.artifact.created_at, $roundtrip.artifact.updated_at)) {
  $null = ConvertTo-UtcTimestamp $value 'actual collector roundtrip'
}
foreach ($value in @('2026-09-08T18:57:00+00:00', '09/08/2026 18:57:00', '2026-09-08T18:57:00', [DateTime]::UtcNow)) {
  Assert-Rejected { ConvertTo-UtcTimestamp $value 'invalid collector timestamp' } 'noncanonical UTC timestamp'
}
Assert-SameKeys @($readback.Keys) (Get-ReaderKeys $evidenceAst '$executionReadback') 'Collector readback'
Assert-SameKeys @($readback.run.Keys) (Get-ReaderKeys $evidenceAst '$executionRun') 'Collector run'
Assert-SameKeys @($readback.artifact.Keys) (Get-ReaderKeys $evidenceAst '$executionArtifact') 'Collector artifact'
$liveReads = @($evidenceAst.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Assert-LiveGithubExecutionProvenance' }, $true))
if ($liveReads.Count -ne 1 -or $liveReads[0].Extent.Text -match '\|\s*ConvertFrom-Json') { throw 'Live readback must preserve JSON dates as strings.' }

$workflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github/workflows/phase6-scale-runtime.yml') -Raw
if (-not $workflow.Contains('include-hidden-files: true') -or -not $workflow.Contains('always() && steps.scale-proof.outputs.evidence_path')) { throw 'P6 upload drops hidden or failed evidence.' }
$upload = [regex]::Match($workflow, '(?ms)- name: Upload immutable provisional evidence pair\s+.*\z').Value
$uploadPaths = @([regex]::Matches($upload, '(?m)^            \$\{\{ steps\.(?<step>[^\r\n]+) \}\}$'))
if ($uploadPaths.Count -ne 4 -or $upload -match '(?m)^            (?!\$\{\{ steps\.)\S') { throw 'P6 upload must select exactly four explicit sanitized files, never directories or wildcards.' }
$outputOffset = $workflow.IndexOf('"sidecar_path=$sidecarPath"')
$failureOffset = $workflow.IndexOf('immutable failure evidence retained.')
if ($outputOffset -lt 0 -or $failureOffset -lt $outputOffset) { throw 'Failure must stay red after exposing immutable evidence outputs.' }

# Execute the actual workflow step with in-memory process/file doubles. The double
# cannot launch pwsh, write files or contact a Worker. Both success and failure use
# exactly the same checked-in step body, rather than a look-alike implementation.
$stepMatch = [regex]::Match($workflow, '(?ms)      - name: Execute bounded Phase6 scale proof\r?\n.*?        run: \|\r?\n(?<body>.*?)(?=\r?\n      - name:)')
if (-not $stepMatch.Success) { throw 'Cannot extract the real scale workflow step.' }
$stepBody = [regex]::Replace($stepMatch.Groups['body'].Value, '(?m)^          ', '')
foreach ($case in @(@{ exit=0; report=$true; pass=$true; outputs=2 }, @{ exit=1; report=$true; pass=$false; outputs=2 }, @{ exit=1; report=$false; pass=$false; outputs=0 }, @{ exit=0; report=$false; pass=$false; outputs=0 })) {
  & {
    $scan = [pscustomobject]@{ count=0 }
    $captured = [Collections.Generic.List[string]]::new()
    function Join-Path { return 'fixture/phase6-scale' }
    function New-Item { }
    function Get-ChildItem {
      $scan.count++
      if ($scan.count -eq 2 -and $case.report) { [pscustomobject]@{ FullName='fixture/phase6-scale/scale-evidence-fixture.json' } }
    }
    function pwsh { Set-Variable -Name LASTEXITCODE -Value $case.exit -Scope 1 }
    function Test-Path { return $true }
    function Out-File {
      param([Parameter(ValueFromPipeline)]$InputObject, $FilePath, $Encoding, [switch]$Append)
      process { [void]$captured.Add([string]$InputObject) }
    }
    function Write-Host { }
    $passed = $true
    try { . ([scriptblock]::Create($stepBody)) } catch { $passed = $false }
    if ($passed -ne $case.pass -or $captured.Count -ne $case.outputs) {
      throw "Actual workflow case exit=$($case.exit) report=$($case.report) did not preserve its verdict and evidence outputs."
    }
  }
}
Write-Host '[phase6-contract-chain-static] PASS: real schemas, both production delta callsites (81 paths), negative paths/fingerprint, actual collector Int64/UTC roundtrip, four actual workflow success/failure cases, exact failed/hidden upload; HTTP=0'
