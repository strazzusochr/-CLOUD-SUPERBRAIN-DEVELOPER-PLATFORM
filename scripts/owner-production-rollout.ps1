<#
.SYNOPSIS
  Owner-only, guided production rollout for Cloud Superbrain. Opens the deploy/release
  gates by executing the documented sequence WITH THE OWNER'S OWN CREDENTIALS.

.DESCRIPTION
  This script is run by the OWNER on the owner's machine. It reads every credential from
  environment variables only — it never prints a token value, never reads a secrets file,
  and never auto-approves the irreversible production gate (that is a manual GitHub UI
  action). Each mutating step pauses for explicit confirmation. An AI assistant must not
  run this script or supply the secrets; only the human owner may.

  Set the env vars first (e.g. from your secrets store), then run:
    $env:GITHUB_TOKEN="…"; $env:GHCR_TOKEN="…"; $env:FLY_API_TOKEN="…"
    $env:BRANCH_PROTECTION_TOKEN="…"; $env:VERCEL_TOKEN="…"
    $env:STAGING_BASE_URL="https://<vercel-or-fly-staging-host>"
    $env:AGENT_API_BASE_URL="…"; $env:MCP_GATEWAY_BASE_URL="…"; $env:LLM_GATEWAY_BASE_URL="…"
    powershell -ExecutionPolicy Bypass -File scripts\owner-production-rollout.ps1

.NOTES
  Reference: docs/audit/gate-opening-analysis.md (the 10-step sequence and why each gate
  is owner-only). Truth: production_deploy_claim_allowed=true is a preflight signal, NOT a
  deployment. The committed manifest stays evidence-based; this script does not fake progress.
#>
[CmdletBinding()]
param(
  [string]$FlyRuntimeOperator = $env:FLY_RUNTIME_OPERATOR,
  [string]$ReleaseId = ("prod-candidate-{0}-rc1" -f (Get-Date -Format 'yyyy-MM-dd')),
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

function Step($n, $title) { Write-Host "`n=== [$n/10] $title ===" -ForegroundColor Cyan }
function Confirm($msg) {
  if ($DryRun) { Write-Host "[dry-run] would: $msg" -ForegroundColor DarkGray; return $false }
  $a = Read-Host "$msg  [y/N]"
  return ($a -eq 'y' -or $a -eq 'Y')
}
function NeedEnv($names) {
  $missing = @($names | Where-Object { [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_)) })
  if ($missing.Count) { Write-Host "  ! missing env vars (set them first, values never printed): $($missing -join ', ')" -ForegroundColor Yellow; return $false }
  Write-Host "  env present: $($names -join ', ')" -ForegroundColor DarkGreen; return $true
}

Write-Host "Cloud Superbrain — OWNER production rollout (guided, gate-respecting)" -ForegroundColor White
Write-Host "Repo: $repo  ·  ReleaseId: $ReleaseId  ·  DryRun: $DryRun"

# 0. Truth-integrity precondition
Step 0 "Truth-integrity precondition"
Write-Host "  Confirm docs/project-progress.manifest.json reflects reality before sign-off."
py -3 "$repo\scripts\verify_project_progress_manifest.py"

# 1. Credentials present (values never printed)
Step 1 "Owner credentials present as env vars"
$haveCreds = NeedEnv @('GITHUB_TOKEN','GHCR_TOKEN','FLY_API_TOKEN','BRANCH_PROTECTION_TOKEN','VERCEL_TOKEN','STAGING_BASE_URL')

# 2. Canonical secret scan (hard-block)
Step 2 "Canonical secret scan (gitleaks hard-block)"
if (Confirm "Run gitleaks detect (must exit 0)?") {
  gitleaks detect --no-git --source "$repo" --redact
  if ($LASTEXITCODE -ne 0) { throw "gitleaks found leaks — hard block. Rollout stopped." }
}

# 3. Publish images to GHCR (provider write)
Step 3 "Publish 6 service images to GHCR (gh workflow run main-deploy.yml)"
if (Confirm "Dispatch main-deploy.yml (staging tags) now?") {
  gh workflow run main-deploy.yml
  Write-Host "  Then verify all 6 digests with: docker manifest inspect ghcr.io/<owner>/cloud-superbrain-developer-platform/<svc>:staging"
}

# 4. Start pull-based stack on the Fly.io runtime (infra mutation)
Step 4 "Start pull-based stack on Fly.io runtime"
$pullCmd = "docker compose -f docker-compose.cloud.yml pull && docker compose -f docker-compose.cloud.yml up -d"
if ($FlyRuntimeOperator -and (Confirm "Use Fly.io operator path and run pull/up?")) {
  Write-Host "  (run on Fly.io runtime/operator shell) $pullCmd"
  Write-Host "  Left as a manual Fly.io operator command for safety." -ForegroundColor Yellow
} else {
  Write-Host "  Run on the Fly.io runtime/operator shell: $pullCmd" -ForegroundColor Yellow
}

# 5. Point Vercel frontend at hosted HTTPS backend origins (Vercel env write)
Step 5 "Configure Vercel backend origins"
Write-Host "  Set AGENT_API_BASE_URL / MCP_GATEWAY_BASE_URL / LLM_GATEWAY_BASE_URL on the Vercel project, then confirm 2xx health."

# 6. Hosted staging proof (non-localhost HTTPS)
Step 6 "Hosted staging verifier"
if ($env:STAGING_BASE_URL -and (Confirm "Run verify-hosted-staging.ps1 against $($env:STAGING_BASE_URL)?")) {
  powershell -ExecutionPolicy Bypass -File "$repo\scripts\verify-hosted-staging.ps1" -BaseUrl $env:STAGING_BASE_URL
}

# 7. Branch protection (GitHub PUT)
Step 7 "Apply + verify protected main"
if (Confirm "Verify branch protection (apply_github_branch_protection.py --verify-only)?") {
  py -3 "$repo\scripts\apply_github_branch_protection.py" --verify-only
  Write-Host "  To APPLY (mutating), run it WITHOUT --verify-only as the human owner." -ForegroundColor Yellow
}

# 8. Release artifact + signed sign-off
Step 8 "Create + sign the release artifact"
Write-Host "  Create docs/release-artifacts/$ReleaseId.md and record explicit owner written sign-off."

# 9. THE irreducible human approval — never automated
Step 9 "Production environment approval (MANUAL, GitHub UI)"
Write-Host "  STOP. Trigger main-deploy.yml with deploy_environment=production, then APPROVE the" -ForegroundColor Yellow
Write-Host "  GitHub 'production' environment gate in the Actions UI. This is the irreducible human" -ForegroundColor Yellow
Write-Host "  decision that flips owner_review_before_production. This script will NOT do it for you." -ForegroundColor Yellow

# 10. Post-rollout
Step 10 "Post-rollout verification"
Write-Host "  Re-run hosted health + smoke; record the outcome. SECRET_OUTPUT stays permanently closed."

Write-Host "`nGuided sequence complete. Gates open only after YOU approve step 9. No secret value was printed." -ForegroundColor Green
