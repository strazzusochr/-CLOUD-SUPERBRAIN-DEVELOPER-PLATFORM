param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-NotContains($label, $value, $unexpected) {
  $text = ($value | Out-String)
  if ($text.Contains($unexpected)) {
    throw "Verification failed: $label unexpectedly contained '$unexpected'."
  }
}

$candidatePath = "docs\release-artifacts\$ReleaseId.md"
if (-not (Test-Path -LiteralPath $candidatePath)) {
  throw "Missing candidate artifact: $candidatePath"
}

$artifactPath = "docs\release-artifacts\prod-candidate-2026-05-05-rc1-owner-decision-reconciliation.md"
if (-not (Test-Path -LiteralPath $artifactPath)) {
  throw "Missing owner decision reconciliation artifact: $artifactPath"
}

$ownerDecisionPath = ".phase1-artifacts\phase5-owner-decision-no-release-20260505.md"
if (-not (Test-Path -LiteralPath $ownerDecisionPath)) {
  throw "Missing owner decision proof artifact: $ownerDecisionPath"
}

$candidate = Get-Content -LiteralPath $candidatePath -Raw
$artifact = Get-Content -LiteralPath $artifactPath -Raw
$ownerDecision = Get-Content -LiteralPath $ownerDecisionPath -Raw

foreach ($required in @(
  "Status: ``verified-blocked``",
  "release_id: ``$ReleaseId``",
  "scope: ``owner_decision_signal_vs_repo_release_truth``",
  "Repo candidate owner decision: ``no-release``",
  "Repo owner decision proof: ``.phase1-artifacts/phase5-owner-decision-no-release-20260505.md``",
  "Local tooling owner signal: ``approved``",
  "Local tooling release strategy signal: ``deploy immutable candidate``",
  "Local tooling live LLM test signal: ``true``",
  "Tooling signal source: ``private_env_tooling_readiness``",
  "Effective release state: ``blocked_until_candidate_reconciled``",
  "Production promotion claim: ``forbidden``",
  "Cloud mutation authorized by this artifact: ``no``",
  "The local ``approved`` signal is treated as owner intent only, not as release proof.",
  "Candidate artifact owner decision must be changed from ``no-release`` to ``approved``.",
  "A new owner-decision proof artifact for ``approved`` must exist.",
  "Immutable staging parity must be verified with ``scripts/manual/verify-phase5-staging-immutable-parity.ps1 -RequireVerified``.",
  "Repo/worktree parity must be resolved or a new immutable candidate must be built from the current repo state.",
  "Vercel must be verified or explicitly marked non-blocking by owner decision.",
  "Release verifiers must pass after the candidate truth update.",
  "This artifact is not a production approval.",
  "This artifact does not contain secret values."
)) {
  Assert-Contains "owner decision reconciliation artifact" $artifact $required
}

Assert-Contains "candidate owner decision" $candidate "owner_decision: ``no-release``"
Assert-Contains "candidate reconciliation link" $candidate "owner_decision_reconciliation_proof: ``docs/release-artifacts/prod-candidate-2026-05-05-rc1-owner-decision-reconciliation.md``"
Assert-Contains "owner decision proof" $ownerDecision "Decision: ``no-release``"
Assert-Contains "owner decision proof review gate" $ownerDecision "Review gate: ``reviewed``"

foreach ($forbidden in @("sk-proj-", "vck_", "cfut_", "GZki")) {
  Assert-NotContains "owner decision reconciliation artifact" $artifact $forbidden
}

Write-Host "[phase5-owner-decision-reconciliation] verified"
