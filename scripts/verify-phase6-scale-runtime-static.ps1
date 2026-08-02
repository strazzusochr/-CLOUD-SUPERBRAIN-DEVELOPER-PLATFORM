[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourcePath = Join-Path $PSScriptRoot "verify-phase6-scale-runtime.ps1"
$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)
if (@($parseErrors).Count -gt 0) {
  throw "phase6 scale verifier has PowerShell parse errors: $($parseErrors[0].Message)"
}

$source = Get-Content -LiteralPath $sourcePath -Raw
function Assert-Contains([string]$Needle, [string]$Label) {
  if (-not $source.Contains($Needle)) { throw "missing source contract: $Label" }
}

Assert-Contains 'Blocked "$authEnvName is missing (the value is never printed); zero HTTP requests issued"' "missing-token zero-request guard"
Assert-Contains 'Blocked "-AllowHostedWrites is missing; zero HTTP requests issued"' "Owner-write zero-request guard"
Assert-Contains 'Blocked "phase6_scale_runtime has no recorded Owner grant; zero HTTP requests issued"' "recorded Owner gate guard"
Assert-Contains '$expectedCriterionSha256 = "edeeac95fac6fefe1dcde5b77a5d8b236685f28adf66f357706aed26971ed85f"' "locked criterion byte hash"
Assert-Contains 'caller-supplied criterion files are forbidden for a hosted write run' "canonical criterion path guard"
Assert-Contains 'caller-supplied hosted-state files are forbidden for a hosted write run' "canonical hosted-state path guard"
Assert-Contains 'git.exe -C $repoRoot diff --quiet HEAD -- $trackedTruthRelativePath' "tracked truth HEAD-byte guard"
Assert-Contains '$handler.AllowAutoRedirect = $false' "cross-origin redirect/token-leak guard"
Assert-Contains 'cloudflare-d1-stateful-runtime-hosted-proof-v2' "immutable deployment rebind contract"
Assert-Contains 'Get-GitArchiveSha256' "Git archive source recomputation"
Assert-Contains 'hostedEvidence.worker_version_id' "Worker version binding"
Assert-Contains 'hostedEvidence.deployment_id' "deployment identity binding"
Assert-Contains '$readExpected -eq 800' "exact 800-read contract"
Assert-Contains '$declaredReadTiers.Count -eq 3' "exact three-tier contract"
Assert-Contains '@{ concurrency = 1; requests = 60 }' "locked c1 read tier"
Assert-Contains '@{ concurrency = 10; requests = 240 }' "locked c10 read tier"
Assert-Contains '@{ concurrency = 50; requests = 500 }' "locked c50 read tier"
Assert-Contains '$writeExpected -eq 50' "exact 50-record contract"
Assert-Contains '$writeConcurrency -eq 10' "write concurrency 10 contract"
Assert-Contains '$maxWorkerRequests -eq 900' "900-Worker-request cap"
Assert-Contains 'url = "$BaseUrl/api/v1/builds"' "real build POST path"
Assert-Contains 'url = "$BaseUrl/api/v1/build/$id"' "real build DELETE path"
Assert-Contains '} finally {' "literal cleanup finally block"
Assert-Contains '$deleteResponses = Invoke-HttpBatch $deleteSpecs $writeConcurrency $true' "cleanup invoked from finally path"
Assert-Contains 'response_readback_verified' "response readback proof"
Assert-Contains 'audit_persisted_verified' "audit proof"
Assert-Contains 'audit_readback_verified' "audit event readback proof"
Assert-Contains 'delete_readback_verified' "active-row absence proof"
Assert-Contains 'field:request_id' "request correlation validation"
Assert-Contains 'field:audit_event_id' "audit event identity validation"
Assert-Contains 'source_archive_sha256' "archive binding"
Assert-Contains 'verifier_script_sha256' "verifier byte binding"
Assert-Contains 'repository_head_sha' "repository HEAD binding"
Assert-Contains 'capability_state_sha256' "pre-run capability-state binding"
Assert-Contains 'gate_identity_sha256' "pre-run Owner-gate identity binding"
Assert-Contains '[IO.FileMode]::CreateNew' "immutable evidence creation"
Assert-Contains '$shaStream = [IO.File]::Open($shaPath, [IO.FileMode]::CreateNew' "immutable digest sidecar creation"
Assert-Contains '$post429 -gt 0 -or $delete429 -gt 0' "write 429 fail-closed contract"
Assert-Contains '$readOther = [int](($tierResults | Measure-Object -Property other_status -Sum).Sum)' "unexpected read status accounting"
Assert-Contains '$transportTotal -gt 0' "transport failure fail-closed contract"
Assert-Contains '$readOther -gt 0' "unexpected read status fail-closed contract"
Assert-Contains 'gate_promotion_performed = $false' "no gate promotion"
Assert-Contains 'percentage_credit_awarded = 0' "no percentage credit"

$authGuardOffset = $source.IndexOf('if ([string]::IsNullOrWhiteSpace($authValue))')
$ownerGuardOffset = $source.IndexOf('if (-not $AllowHostedWrites)')
$recordedOwnerGuardOffset = $source.IndexOf('if ($null -eq $scaleGate -or $scaleGate.owner_granted -ne $true')
$clientOffset = $source.IndexOf('Add-Type -AssemblyName System.Net.Http')
if ($authGuardOffset -lt 0 -or $ownerGuardOffset -lt 0 -or $recordedOwnerGuardOffset -lt 0 -or $clientOffset -lt 0 -or
    $authGuardOffset -ge $clientOffset -or $ownerGuardOffset -ge $clientOffset -or $recordedOwnerGuardOffset -ge $clientOffset) {
  throw "authorization guard must precede HttpClient construction"
}

Write-Host "[phase6-scale-static] PASS: parser, zero-request preflight, request budget, source binding, evidence, and no-promotion contracts"
