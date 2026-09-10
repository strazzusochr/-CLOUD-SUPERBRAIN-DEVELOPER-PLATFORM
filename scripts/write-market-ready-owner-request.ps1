param(
  [Parameter(Mandatory = $true)][string]$SourceSha,
  [Parameter(Mandatory = $true)][string]$QualificationSha,
  [Parameter(Mandatory = $true)][string]$ReleaseId,
  [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

function Assert-True([string]$Label, [bool]$Value) {
  if (-not $Value) { throw "Owner-request precondition failed: $Label" }
}

Assert-True "source SHA is exact" ($SourceSha -cmatch '^[0-9a-f]{40}$')
Assert-True "qualification SHA is exact" ($QualificationSha -cmatch '^[0-9a-f]{40}$')
Assert-True "release ID is bounded" ($ReleaseId -cmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-local-rc[0-9]+$')

& git -C $repoRoot cat-file -e "$SourceSha^{commit}" 2>$null
Assert-True "source commit exists" ($LASTEXITCODE -eq 0)
& git -C $repoRoot cat-file -e "$QualificationSha^{commit}" 2>$null
Assert-True "qualification commit exists" ($LASTEXITCODE -eq 0)
& git -C $repoRoot merge-base --is-ancestor $SourceSha $QualificationSha
Assert-True "qualification descends from source" ($LASTEXITCODE -eq 0)

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
$safeParents = @(
  [IO.Path]::GetFullPath((Join-Path $repoRoot '.codex\runs\CURRENT')).TrimEnd('\', '/'),
  [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
)
Assert-True "output is confined to a temporary/request artifact root" (@(
  $safeParents | Where-Object {
    $resolvedOutput.StartsWith($_ + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
  }
).Count -eq 1)

$actions = @(
  [ordered]@{
    id = "MR1"
    action = "cloudflare_preview_loop_guard_deploy"
    exact_source_sha = $SourceSha
    owner_decision = "pending"
    boundary = "preview_only_control_plane; no production alias; no health request"
  },
  [ordered]@{
    id = "MR2"
    action = "protected_default_branch_merge"
    exact_qualification_sha = $QualificationSha
    owner_decision = "pending"
    boundary = "protected PR only; preserve source ancestry; no direct push; no squash; no rebase"
  },
  [ordered]@{
    id = "MR3"
    action = "private_ghcr_candidate_publication"
    exact_source_sha = $SourceSha
    service_count = 6
    owner_decision = "pending"
    boundary = "private append-only SHA images; registry-publication review; no promotion or rollout"
  },
  [ordered]@{
    id = "MR4"
    action = "ephemeral_codespaces_candidate_staging"
    exact_source_sha = $SourceSha
    owner_decision = "pending"
    boundary = "zero-cost quota only; one temporary public HTTPS port; private package read; delete after receipt"
  },
  [ordered]@{
    id = "MR5"
    action = "cloudflare_native_production_oauth_acceptance"
    exact_source_sha = $SourceSha
    owner_decision = "pending"
    boundary = "read:user only; Owner handles password, 2FA, CAPTCHA, Cancel and Authorize; no secret output"
  },
  [ordered]@{
    id = "MR6"
    action = "bounded_llm_gateway_acceptance"
    exact_source_sha = $SourceSha
    maximum_provider_calls = 9
    owner_decision = "pending"
    boundary = "gateway-only Workers AI; budget guard and audit required; no direct provider calls"
  },
  [ordered]@{
    id = "MR7"
    action = "phase6_production_worker_and_scale_run"
    exact_source_sha = $SourceSha
    owner_decision = "pending"
    boundary = "zero-card; one deployment health read; one attempt; phase6-scale-hosted-writes review; no rerun"
  },
  [ordered]@{
    id = "MR8"
    action = "vercel_truth_projection_preview"
    exact_source_sha = $SourceSha
    owner_decision = "pending"
    boundary = "preview only; no production alias; truth projection must pass dual-binding verifier"
  }
)

$request = [ordered]@{
  contract_version = "market-ready-owner-request-v1"
  status = "owner_approval_required"
  generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
  repository = "strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM"
  release_id = $ReleaseId
  runtime_candidate_sha = $SourceSha
  qualification_sha = $QualificationSha
  actions = $actions
  hard_exclusions = @(
    "production_release_promotion",
    "production_frontend_alias_mutation",
    "public_registry_publication",
    "direct_default_or_main_push",
    "force_push",
    "paid_plan_or_payment_method",
    "secret_value_output",
    "manual_live_verified_mutation"
  )
  evidence_policy = [ordered]@{
    owner_granted_is_not_live_verified = $true
    only_dedicated_promoters_may_set_live_verified = $true
    percentage_credit_from_request = 0
    secret_output = $false
  }
  owner_ai_prompt = "Pruefe jede Aktion MR1-MR8 gegen die exakten SHAs. Setze pro Aktion owner_decision nur auf approved oder denied, nenne deine unveraenderliche Grant-Referenz und veraendere keine Evidence-/live_verified-Felder. Die hard_exclusions gelten ohne Ausnahme."
}

$parent = Split-Path -Parent $resolvedOutput
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$request | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutput -Encoding utf8NoBOM

$readback = Get-Content -LiteralPath $resolvedOutput -Raw | ConvertFrom-Json
Assert-True "request readback contract" ([string]$readback.contract_version -ceq 'market-ready-owner-request-v1')
Assert-True "request carries eight bounded actions" (@($readback.actions).Count -eq 8)
Assert-True "request grants no credit" ([int]$readback.evidence_policy.percentage_credit_from_request -eq 0)
Assert-True "request emits no secret" ($readback.evidence_policy.secret_output -is [bool] -and -not $readback.evidence_policy.secret_output)

Write-Host "[market-ready-owner-request] status=owner_approval_required actions=8 source=$SourceSha qualification=$QualificationSha credit=0 secret_output=false"
