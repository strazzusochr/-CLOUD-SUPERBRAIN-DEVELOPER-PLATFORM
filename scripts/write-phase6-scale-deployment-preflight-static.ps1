#Requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$writerPath = Join-Path $PSScriptRoot 'write-phase6-scale-deployment-preflight.ps1'
if (-not (Test-Path -LiteralPath $writerPath -PathType Leaf)) {
  throw 'Phase6 deployment-preflight writer is missing.'
}

$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($writerPath, [ref]$tokens, [ref]$parseErrors)
if (@($parseErrors).Count -gt 0) {
  throw "Phase6 deployment-preflight writer has parse errors: $($parseErrors[0].Message)"
}

$source = Get-Content -LiteralPath $writerPath -Raw
foreach ($required in @(
  'phase6-scale-deployment-preflight-evidence-v1',
  'phase6-scale-hosted-deployment-current-v1',
  'hosted_write_read_delete_verified = $false',
  'phase6_scale_run_started = $false',
  'phase6_scale_run_verified = $false',
  '[IO.FileMode]::CreateNew',
  'Get-GitArchiveSha256',
  'health_json_source_binding_verified = $true',
  'cloudflare-phase6-preview-guard-deploy-result-v1',
  'preview_guard_verified = $true',
  'production_worker_request_count = 1',
  'preview_worker_request_count = 0',
  'worker_request_count',
  'Preview-to-production deployment window exceeded ten minutes.'
)) {
  if (-not $source.Contains($required)) { throw "Writer is missing contract: $required" }
}
if ($source -match '(?i)Invoke-WebRequest|Invoke-RestMethod|HttpClient|curl(?:\.exe)?|wrangler\s+(?:deploy|versions|deployments)') {
  throw 'Deployment-preflight writer must perform zero network/provider operations.'
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
$preferredTestRoot = if (-not [string]::IsNullOrWhiteSpace($env:SUPERBRAIN_TEST_ROOT)) {
  $env:SUPERBRAIN_TEST_ROOT
} elseif (Test-Path -LiteralPath 'D:/_sb_tmp' -PathType Container) {
  'D:/_sb_tmp'
} else {
  [IO.Path]::GetTempPath()
}
$testRoot = [IO.Path]::GetFullPath($preferredTestRoot).TrimEnd('\', '/')
$tempRoot = Join-Path $testRoot ('phase6-deploy-preflight-static-' + [Guid]::NewGuid().ToString('N'))
$utf8NoBom = [Text.UTF8Encoding]::new($false)

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Write-Json([string]$Path, $Value) {
  [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 10) + "`n"), $utf8NoBom)
}

function Get-GitArchiveSha256([string]$CommitSha) {
  $archivePath = Join-Path $tempRoot 'source.tar'
  & git -C $repoRoot archive --format=tar "--output=$archivePath" $CommitSha
  Assert-True ($LASTEXITCODE -eq 0) 'Static fixture could not create source archive.'
  return (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-WriterFailure([string]$ResultPath, [string]$PreviewResultPath, [string]$EvidencePath, [string]$StatePath, [string]$Label) {
  $output = @(& pwsh -NoProfile -File $writerPath `
    -DeployResultPath $ResultPath `
    -PreviewGuardResultPath $PreviewResultPath `
    -EvidencePath $EvidencePath `
    -HostedStatePath $StatePath `
    -AllowTestPaths 2>&1)
  Assert-True ($LASTEXITCODE -ne 0) "$Label unexpectedly passed."
  Assert-True (-not (Test-Path -LiteralPath $EvidencePath)) "$Label left false evidence behind."
}

[IO.Directory]::CreateDirectory($tempRoot) | Out-Null
try {
  $sourceSha = (& git -C $repoRoot rev-parse HEAD).Trim()
  $sourceArchiveSha256 = Get-GitArchiveSha256 $sourceSha
  $deployResult = [ordered]@{
    contract_version = 'cloudflare-phase6-production-deploy-result-v1'
    base_url = 'https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev'
    verified_at_utc = [DateTime]::UtcNow.AddMinutes(-1).ToString('o')
    source_commit_sha = $sourceSha
    source_archive_sha256 = $sourceArchiveSha256
    source_bundle_sha256 = ('3' * 64)
    worker_version_id = '11111111-1111-4111-8111-111111111111'
    deployment_id = '22222222-2222-4222-8222-222222222222'
    health_status = 200
    d1_read_verified = $true
    worker_request_count = 1
    secret_output = $false
  }
  $previewResult = [ordered]@{
    contract_version = 'cloudflare-phase6-preview-guard-deploy-result-v1'
    base_url = 'https://cloud-superbrain-stateful-runtime-preview.strazzusochr.workers.dev'
    verified_at_utc = [DateTime]::UtcNow.AddMinutes(-2).ToString('o')
    source_commit_sha = $sourceSha
    source_archive_sha256 = $sourceArchiveSha256
    source_bundle_sha256 = ('3' * 64)
    worker_version_id = '33333333-3333-4333-8333-333333333333'
    deployment_id = '44444444-4444-4444-8444-444444444444'
    control_plane_verified = $true
    worker_request_count = 0
    secret_output = $false
  }
  $resultPath = Join-Path $tempRoot 'deploy-result.json'
  $previewResultPath = Join-Path $tempRoot 'preview-result.json'
  $evidencePath = Join-Path $tempRoot 'valid/report.json'
  $statePath = Join-Path $tempRoot 'valid/phase6-scale-hosted-current.json'
  Write-Json $resultPath $deployResult
  Write-Json $previewResultPath $previewResult
  $output = @(& pwsh -NoProfile -File $writerPath `
    -DeployResultPath $resultPath `
    -PreviewGuardResultPath $previewResultPath `
    -EvidencePath $evidencePath `
    -HostedStatePath $statePath `
    -AllowTestPaths 2>&1)
  Assert-True ($LASTEXITCODE -eq 0) ('Valid deployment preflight failed: ' + ($output -join ' | '))
  Assert-True (Test-Path -LiteralPath $evidencePath -PathType Leaf) 'Writer did not create immutable evidence.'
  Assert-True (Test-Path -LiteralPath "$evidencePath.sha256" -PathType Leaf) 'Writer did not create evidence digest.'
  Assert-True (Test-Path -LiteralPath $statePath -PathType Leaf) 'Writer did not create P6 hosted state.'
  $evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json -Depth 20
  $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -Depth 20
  Assert-True ([string]$evidence.contract_version -ceq 'phase6-scale-deployment-preflight-evidence-v1') 'Evidence contract mismatch.'
  Assert-True ([string]$state.contract_version -ceq 'phase6-scale-hosted-deployment-current-v1') 'Hosted-state contract mismatch.'
  Assert-True ($evidence.health_status -eq 200 -and $state.health_status -eq 200) 'Health HTTP 200 was not preserved.'
  Assert-True ($evidence.production_worker_request_count -eq 1 -and $state.production_worker_request_count -eq 1) 'Exactly-one production Worker request was not preserved.'
  Assert-True ($evidence.preview_worker_request_count -eq 0 -and $state.preview_worker_request_count -eq 0) 'Zero-request Preview guard was not preserved.'
  Assert-True ($evidence.hosted_write_read_delete_verified -eq $false -and $state.hosted_write_read_delete_verified -eq $false) 'Preflight falsely claims write/read/delete verification.'
  Assert-True ($evidence.phase6_scale_run_verified -eq $false -and $state.phase6_scale_run_verified -eq $false) 'Preflight falsely claims Phase6 execution.'
  Assert-True ($evidence.preview_guard_verified -eq $true -and $state.preview_guard_verified -eq $true) 'Preview guard was not preserved.'
  Assert-True ([string]$evidence.preview_worker_version_id -ceq [string]$previewResult.worker_version_id -and [string]$state.preview_deployment_id -ceq [string]$previewResult.deployment_id) 'Preview deployment identity was not preserved.'
  Assert-True ([string]$state.source_archive_sha256 -ceq $sourceArchiveSha256) 'State archive binding mismatch.'
  $evidenceSha256 = (Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash.ToLowerInvariant()
  Assert-True ([string]$state.evidence_sha256 -ceq $evidenceSha256) 'State evidence digest mismatch.'
  Assert-True ((Get-Content -LiteralPath "$evidencePath.sha256" -Raw).Trim() -ceq "$evidenceSha256  report.json") 'Evidence sidecar mismatch.'

  $overwriteOutput = @(& pwsh -NoProfile -File $writerPath `
    -DeployResultPath $resultPath `
    -PreviewGuardResultPath $previewResultPath `
    -EvidencePath $evidencePath `
    -HostedStatePath $statePath `
    -AllowTestPaths 2>&1)
  Assert-True ($LASTEXITCODE -ne 0) 'Immutable evidence overwrite unexpectedly passed.'

  $deployResult.health_status = 503
  $badHealthPath = Join-Path $tempRoot 'bad-health.json'
  Write-Json $badHealthPath $deployResult
  Invoke-WriterFailure $badHealthPath $previewResultPath (Join-Path $tempRoot 'bad-health/report.json') (Join-Path $tempRoot 'bad-health/state.json') 'Non-200 health result'
  $deployResult.health_status = 200

  $deployResult.worker_request_count = 2
  $badProductionRequestCountPath = Join-Path $tempRoot 'bad-production-request-count.json'
  Write-Json $badProductionRequestCountPath $deployResult
  Invoke-WriterFailure $badProductionRequestCountPath $previewResultPath (Join-Path $tempRoot 'bad-production-request-count/report.json') (Join-Path $tempRoot 'bad-production-request-count/state.json') 'Non-single production Worker request count'
  $deployResult.worker_request_count = 1

  $deployResult.source_archive_sha256 = ('4' * 64)
  $badArchivePath = Join-Path $tempRoot 'bad-archive.json'
  Write-Json $badArchivePath $deployResult
  Invoke-WriterFailure $badArchivePath $previewResultPath (Join-Path $tempRoot 'bad-archive/report.json') (Join-Path $tempRoot 'bad-archive/state.json') 'Mismatched source archive'
  $deployResult.source_archive_sha256 = $sourceArchiveSha256

  $deployResult.extra = 'forbidden'
  $extraPath = Join-Path $tempRoot 'extra-property.json'
  Write-Json $extraPath $deployResult
  Invoke-WriterFailure $extraPath $previewResultPath (Join-Path $tempRoot 'extra/report.json') (Join-Path $tempRoot 'extra/state.json') 'Extra deploy-result property'

  $deployResult.PSObject.Properties.Remove('extra')
  $previewResult.worker_request_count = 1
  $previewRequestPath = Join-Path $tempRoot 'preview-request.json'
  Write-Json $previewRequestPath $previewResult
  Invoke-WriterFailure $resultPath $previewRequestPath (Join-Path $tempRoot 'preview-request/report.json') (Join-Path $tempRoot 'preview-request/state.json') 'Preview Worker request'
  $previewResult.worker_request_count = 0

  $previewResult.source_bundle_sha256 = ('5' * 64)
  $previewMismatchPath = Join-Path $tempRoot 'preview-source-mismatch.json'
  Write-Json $previewMismatchPath $previewResult
  Invoke-WriterFailure $resultPath $previewMismatchPath (Join-Path $tempRoot 'preview-mismatch/report.json') (Join-Path $tempRoot 'preview-mismatch/state.json') 'Preview source mismatch'
  $previewResult.source_bundle_sha256 = ('3' * 64)

  $deployResult.verified_at_utc = [DateTime]::UtcNow.AddMinutes(1).ToString('o')
  $previewResult.verified_at_utc = [DateTime]::UtcNow.AddMinutes(-9.5).ToString('o')
  $longWindowResultPath = Join-Path $tempRoot 'long-window-deploy-result.json'
  $longWindowPreviewPath = Join-Path $tempRoot 'long-window-preview-result.json'
  Write-Json $longWindowResultPath $deployResult
  Write-Json $longWindowPreviewPath $previewResult
  Invoke-WriterFailure $longWindowResultPath $longWindowPreviewPath (Join-Path $tempRoot 'long-window/report.json') (Join-Path $tempRoot 'long-window/state.json') 'Preview-to-production deployment window over ten minutes'
  $deployResult.verified_at_utc = [DateTime]::UtcNow.AddMinutes(-1).ToString('o')
  $previewResult.verified_at_utc = [DateTime]::UtcNow.AddMinutes(-2).ToString('o')

  $previewResult.extra = 'forbidden'
  $previewExtraPath = Join-Path $tempRoot 'preview-extra.json'
  Write-Json $previewExtraPath $previewResult
  Invoke-WriterFailure $resultPath $previewExtraPath (Join-Path $tempRoot 'preview-extra/report.json') (Join-Path $tempRoot 'preview-extra/state.json') 'Extra Preview-result property'

  Write-Host '[phase6-deployment-preflight-static] PASS: exact production/Preview parsers, ten-minute deployment window, source/archive/bundle/ID/health bindings, Production=1 and Preview=0 Worker request accounting, immutable report, explicit pre-run non-claim, and zero network'
} finally {
  $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
  Assert-True ($resolvedTemp.StartsWith($testRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) 'Refusing unsafe fixture cleanup.'
  if (Test-Path -LiteralPath $resolvedTemp) { Remove-Item -LiteralPath $resolvedTemp -Recurse -Force }
}
