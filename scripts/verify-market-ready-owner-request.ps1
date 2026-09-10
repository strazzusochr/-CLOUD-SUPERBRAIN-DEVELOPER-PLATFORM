param(
  [Parameter(Mandatory = $true)][string]$RequestPath,
  [Parameter(Mandatory = $true)][string]$ExpectedSourceSha,
  [Parameter(Mandatory = $true)][string]$ExpectedQualificationSha
)

$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Value) {
  if (-not $Value) { throw "Owner-request verification failed: $Label" }
}

Assert-True "request exists" (Test-Path -LiteralPath $RequestPath -PathType Leaf)
$request = Get-Content -LiteralPath $RequestPath -Raw | ConvertFrom-Json
Assert-True "contract" ([string]$request.contract_version -ceq 'market-ready-owner-request-v1')
Assert-True "status" ([string]$request.status -ceq 'owner_approval_required')
Assert-True "source" ([string]$request.runtime_candidate_sha -ceq $ExpectedSourceSha)
Assert-True "qualification" ([string]$request.qualification_sha -ceq $ExpectedQualificationSha)
Assert-True "actions" (@($request.actions).Count -eq 8)
Assert-True "action IDs" ((@($request.actions | ForEach-Object { [string]$_.id } | Sort-Object) -join ',') -ceq 'MR1,MR2,MR3,MR4,MR5,MR6,MR7,MR8')
Assert-True "all decisions remain pending" (@($request.actions | Where-Object { [string]$_.owner_decision -cne 'pending' }).Count -eq 0)
Assert-True "provider cap" ([int](($request.actions | Where-Object { $_.id -eq 'MR6' }).maximum_provider_calls) -eq 9)
Assert-True "hard exclusions" (@($request.hard_exclusions).Count -eq 8)
Assert-True "no credit" ([int]$request.evidence_policy.percentage_credit_from_request -eq 0)
Assert-True "grant is not live verification" ($request.evidence_policy.owner_granted_is_not_live_verified -is [bool] -and $request.evidence_policy.owner_granted_is_not_live_verified)
Assert-True "promoter-only live verification" ($request.evidence_policy.only_dedicated_promoters_may_set_live_verified -is [bool] -and $request.evidence_policy.only_dedicated_promoters_may_set_live_verified)
Assert-True "secret output false" ($request.evidence_policy.secret_output -is [bool] -and -not $request.evidence_policy.secret_output)

$raw = Get-Content -LiteralPath $RequestPath -Raw
Assert-True "no credential-shaped fields" ($raw -notmatch '(?i)"(token|password|client_secret|api_key|authorization)"\s*:')
Assert-True "no bearer credential" ($raw -notmatch '(?i)bearer\s+[a-z0-9._~+/-]{8,}')

Write-Host "[market-ready-owner-request] verified actions=8 source=$ExpectedSourceSha qualification=$ExpectedQualificationSha credit=0 secret_output=false"
