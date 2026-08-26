$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label missing '$expected'."
  }
}

function Assert-NotContains($label, $value, $forbidden) {
  $text = ($value | Out-String)
  if ($text.Contains($forbidden)) {
    throw "Verification failed: $label contains forbidden active marker '$forbidden'."
  }
}

function Assert-NotMatches($label, $value, $pattern) {
  $text = ($value | Out-String)
  if ($text -match $pattern) {
    throw "Verification failed: $label matched forbidden active pattern '$pattern'."
  }
}

Write-Host "[verify-retired-hosted-boundary] checks"

$projectState = Get-Content -Path "PROJECT_STATE.md" -Raw
$aiHandoff = Get-Content -Path "AI_HANDOFF.md" -Raw
$verificationRegister = Get-Content -Path "docs\verification-register.md" -Raw
$deployScript = Get-Content -Path "scripts\deploy-to-staging.ps1" -Raw
$externalGateScript = Get-Content -Path "scripts\verify-external-gates.ps1" -Raw
$candidate = Get-Content -Path "docs\release-artifacts\prod-candidate-2026-05-05-rc1.md" -Raw
$browserProof = Get-Content -Path "docs\release-artifacts\prod-candidate-2026-05-05-rc1-browser-proof.md" -Raw
$postRollbackBrowserProof = Get-Content -Path "docs\release-artifacts\prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md" -Raw
$progressManifest = Get-Content -Path "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$canonicalExternalGateAuditRef = "docs/runtime-state/external-gate-audit-v2.json"
if (-not (Test-Path -LiteralPath $canonicalExternalGateAuditRef -PathType Leaf)) {
  throw "Verification failed: canonical external gate audit not found."
}
$canonicalExternalGateAudit = Get-Content -LiteralPath $canonicalExternalGateAuditRef -Raw | ConvertFrom-Json
if ([string]$canonicalExternalGateAudit.contract_version -ne "external-gate-audit-v2") {
  throw "Verification failed: canonical external gate audit contract is not v2."
}

Assert-Contains "PROJECT_STATE current external audit" $projectState $canonicalExternalGateAuditRef
Assert-Contains "PROJECT_STATE retired provider boundary" $projectState "Hetzner, GitKraken und Oracle sind aus dem aktiven Pfad entfernt oder als historische Altlast markiert"
Assert-Contains "PROJECT_STATE no-token external baseline" $projectState "GitLab-, Hugging-Face- und Grafana-Identity bleiben im Basislauf ohne Token fail-closed"
Assert-Contains "PROJECT_STATE historical Hetzner boundary" $projectState "historische Provenance"
Assert-NotContains "PROJECT_STATE next safe work" $projectState "authoritative hosted gate truth is on the Hetzner staging URL"

Assert-Contains "AI_HANDOFF current external audit" $aiHandoff $canonicalExternalGateAuditRef
Assert-Contains "AI_HANDOFF no-token external baseline" $aiHandoff "GitLab, Hugging Face, and Grafana identity checks are fail-closed in this no-token baseline"
Assert-Contains "AI_HANDOFF current frontend proof" $aiHandoff 'frontend-hosted-current-proof-v1'
Assert-Contains "AI_HANDOFF current contract origin" $aiHandoff 'frontend and the stateless read-only Backend Contract Origin are deployed on Vercel'
Assert-NotContains "AI_HANDOFF active Hetzner next safe work" $aiHandoff "authoritative hosted gate truth is on the Hetzner staging URL"

Assert-Contains "verification register hosted boundary" $verificationRegister "Current Hosted Boundary"
Assert-Contains "verification register historical boundary" $verificationRegister "historical provenance only"
Assert-Contains "verification register current frontend authority" $verificationRegister 'Current frontend truth is `frontend-hosted-current-proof-v1`'
Assert-Contains "verification register current external authority" $verificationRegister 'current external truth is `external-gate-audit-v2` plus `external-gate-summary-v2`'
Assert-Contains "verification register stateful backend non-claim" $verificationRegister 'Neither one proves a stateful full-backend rollout, release promotion, or full-platform production release'
Assert-Contains "verification register current external audit" $verificationRegister $canonicalExternalGateAuditRef

Assert-NotContains "deploy-to-staging active default IP" $deployScript '[string]$StagingIp = "188.34.191.140"'
Assert-NotContains "deploy-to-staging active sslip derivation" $deployScript 'return ($Ip -replace ''.'', ''-'') + ".sslip.io"'
Assert-Contains "deploy-to-staging retired mutation guard" $deployScript "scripts/deploy-to-staging.ps1 is retired for active cloud mutation"
Assert-Contains "deploy-to-staging plan placeholder" $deployScript "retired-plan.invalid"

Assert-Contains "external gate Grafana powershell probe" $externalGateScript "Invoke-RestMethod -Method Get"
Assert-Contains "external gate Grafana redaction" $externalGateScript "[redacted-token]"

Assert-Contains "browser proof retired status" $browserProof 'Status: `superseded`'
Assert-Contains "browser proof retired boundary" $browserProof 'retired_boundary: `sslip_io_hetzner`'
Assert-Contains "browser proof non-current" $browserProof 'current_candidate_evidence: `false`'
Assert-Contains "post-rollback browser proof retired status" $postRollbackBrowserProof 'Status: `superseded`'
Assert-Contains "post-rollback browser proof retired boundary" $postRollbackBrowserProof 'retired_boundary: `sslip_io_hetzner`'
Assert-Contains "post-rollback browser proof non-current" $postRollbackBrowserProof 'current_candidate_evidence: `false`'

Assert-Contains "candidate historical browser status" $candidate 'browser_rerun_status: `superseded; historical sslip/Hetzner browser artifacts retained for provenance only; current browser evidence requires Vercel HTTPS STAGING_BASE_URL plus reachable Fly origins`'
Assert-Contains "candidate historical browser proof" $candidate 'historical_browser_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md`'
Assert-Contains "candidate historical post-rollback browser proof" $candidate 'historical_post_rollback_browser_revalidation_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md`'
Assert-Contains "candidate historical browser reactivation" $candidate 'historical_browser_evidence_reactivation_proof: `.phase1-artifacts/phase5-browser-evidence-reactivation-20260507.md`'
Assert-Contains "candidate historical final browser" $candidate 'historical_final_browser_e2e_recheck_proof: `.phase1-artifacts/phase5-final-browser-e2e-recheck-20260507.md`'
Assert-NotMatches "candidate active browser proof" $candidate '(?m)^browser_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof\.md`$'
Assert-NotMatches "candidate active post-rollback browser proof" $candidate '(?m)^post_rollback_browser_revalidation_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation\.md`$'
Assert-NotContains "candidate active browser evidence status" $candidate "current browser artifacts active candidate evidence"

$phase5 = $progressManifest.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1
if (-not $phase5) {
  throw "Verification failed: progress manifest missing phase_5."
}
Assert-Contains "progress manifest retired browser bridge" $phase5.status "candidate_browser_bridge_retired_current_hosted_blocked"
Assert-Contains "progress manifest retired browser evidence" $phase5.status "candidate_browser_evidence_retired_current_hosted_blocked"
Assert-Contains "progress manifest retired post-rollback browser evidence" $phase5.status "candidate_post_rollback_browser_revalidation_retired_current_hosted_blocked"
Assert-Contains "progress manifest retired final browser evidence" $phase5.status "candidate_final_browser_e2e_retired_current_hosted_blocked"
Assert-NotContains "progress manifest active browser bridge" $phase5.status "candidate_browser_bridge_recovery_verified"
Assert-NotContains "progress manifest active browser evidence" $phase5.status "candidate_browser_evidence_rerun_verified"
Assert-NotContains "progress manifest active post-rollback browser evidence" $phase5.status "candidate_post_rollback_browser_revalidation_rerun_verified"
Assert-NotContains "progress manifest active final browser evidence" $phase5.status "candidate_final_browser_e2e_recheck_verified"

Write-Host "[verify-retired-hosted-boundary] checks completed"
