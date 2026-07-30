#Requires -Version 7.0

$ErrorActionPreference = 'Stop'
$targetScript = Join-Path $PSScriptRoot 'promote-cloudflare-token-candidate.ps1'
$testRoot = Join-Path 'D:\_sb_tmp' ('cloudflare-token-promotion-' + [Guid]::NewGuid().ToString('N'))

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function Write-JsonFile([string]$Path, [object]$Value) {
  [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
}

Assert-True (Test-Path -LiteralPath $targetScript -PathType Leaf) 'Token promotion helper is missing.'
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($targetScript, [ref]$null, [ref]$parseErrors)
Assert-True (@($parseErrors).Count -eq 0) 'Token promotion helper has parse errors.'
$shortFunctions = @(
  $ast.FindAll(
    { param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] },
    $true
  ) | Where-Object { $_.Name.Length -le 2 }
)
Assert-True ($shortFunctions.Count -eq 0) 'Token promotion helper contains a short function name.'
$source = Get-Content -LiteralPath $targetScript -Raw
foreach ($required in @(
  'CLOUDFLARE_API_TOKEN_CANDIDATE',
  'cloudflare-d1-stateful-runtime-hosted-proof-v1',
  'cloudflare_native_d1_artifact_write_read_delete',
  'cloudflare_native_hosted_source_parity_verified',
  'cloudflare_native_zero_card_execution_verified',
  'evidence_sha256',
  'owner-set-cloudflare-token.ps1',
  '-ProbeOnly',
  '-Profile O2Core',
  'Write-ActiveTokenAtomically',
  '[IO.File]::Replace',
  'Token promotion requires -OwnerGate.',
  'secret_output=false'
)) {
  Assert-True $source.Contains($required) "Token promotion helper missing guard: $required"
}
foreach ($forbidden in @(
  'Write-Host $candidateToken',
  'Write-Output $candidateToken',
  'Write-Error $candidateToken',
  'throw $candidateToken',
  'CLOUDFLARE_API_TOKEN=$activeToken'
)) {
  Assert-True (-not $source.Contains($forbidden)) "Token promotion helper contains forbidden marker: $forbidden"
}

[IO.Directory]::CreateDirectory($testRoot) | Out-Null
try {
  $activeToken = 'A' * 40
  $candidateToken = 'B' * 40
  $secretPath = Join-Path $testRoot 'cloud-superbrain.local.env'
  [IO.File]::WriteAllText(
    $secretPath,
    "CLOUDFLARE_API_TOKEN=$activeToken`nCLOUDFLARE_API_TOKEN_CANDIDATE=$candidateToken`n",
    [Text.UTF8Encoding]::new($false)
  )

  $evidencePath = Join-Path $testRoot 'hosted-report.json'
  $evidence = [ordered]@{
    contract_version = 'cloudflare-d1-stateful-runtime-hosted-proof-v1'
    status = 'verified'
    cloudflare_native_hosted_proof = $true
    cloudflare_native_runtime_exercised = $true
    cloudflare_native_create_enqueue_queue_do_d1_artifact_roundtrip = $true
    cloudflare_native_d1_artifact_write_read_delete = $true
    cloudflare_native_hosted_source_parity_verified = $true
    cloudflare_native_r2_binding_absent = $true
    cloudflare_native_zero_card_execution_verified = $true
    cloudflare_native_dev_only = $false
    cloudflare_native_paid_fallback_used = $false
    cloudflare_native_live_provider_calls = $false
    cloudflare_native_live_mcp_writes = $false
    cloudflare_native_production_deploy = $false
    secret_output = $false
    source_commit_sha = 'a' * 40
    source_archive_sha256 = 'b' * 64
  }
  Write-JsonFile $evidencePath $evidence
  $evidenceHash = (Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash.ToUpperInvariant()

  $capabilityPath = Join-Path $testRoot 'capability-gates.json'
  $capability = [ordered]@{
    gates = [ordered]@{
      cloudflare_native_zero_card_hosted_runtime = [ordered]@{
        owner_granted = $true
        local_candidate_verified = $true
        zero_card_verified = $true
        hosted_source_parity_verified = $true
        hosted_stateful_roundtrip_verified = $true
        live_verified = $true
        r2_enabled = $false
        paid_provider = $false
        artifact_adapter = 'cloudflare-d1-bounded-text'
        r2_status = 'historical_only'
        evidence_artifact = $evidencePath
        evidence_sha256 = $evidenceHash
        source_commit_sha = 'a' * 40
        source_archive_sha256 = 'b' * 64
      }
    }
  }
  Write-JsonFile $capabilityPath $capability

  $planOutput = (& pwsh -NoProfile -File $targetScript `
    -SecretFile $secretPath `
    -HostedEvidencePath $evidencePath `
    -CapabilityStatePath $capabilityPath `
    -AllowTestPaths `
    -SkipManagementProbeForTests 2>&1 | Out-String)
  Assert-True ($LASTEXITCODE -eq 0) "Token promotion plan failed: $planOutput"
  Assert-True $planOutput.Contains('eligible=true apply=false') 'Token promotion plan marker missing.'
  Assert-True ((Get-Content -LiteralPath $secretPath -Raw).Contains("CLOUDFLARE_API_TOKEN=$activeToken")) 'Plan changed the active token.'

  $blockedOutput = (& pwsh -NoProfile -File $targetScript `
    -SecretFile $secretPath `
    -HostedEvidencePath $evidencePath `
    -CapabilityStatePath $capabilityPath `
    -AllowTestPaths `
    -SkipManagementProbeForTests `
    -Apply 2>&1 | Out-String)
  Assert-True ($LASTEXITCODE -ne 0) 'Token promotion without OwnerGate succeeded.'
  Assert-True ((Get-Content -LiteralPath $secretPath -Raw).Contains("CLOUDFLARE_API_TOKEN=$activeToken")) 'Blocked promotion changed the active token.'

  $applyOutput = (& pwsh -NoProfile -File $targetScript `
    -SecretFile $secretPath `
    -HostedEvidencePath $evidencePath `
    -CapabilityStatePath $capabilityPath `
    -AllowTestPaths `
    -SkipManagementProbeForTests `
    -Apply `
    -OwnerGate 2>&1 | Out-String)
  Assert-True ($LASTEXITCODE -eq 0) "Qualified token promotion failed: $applyOutput"
  Assert-True (-not $applyOutput.Contains($activeToken)) 'Promotion output exposed the old token.'
  Assert-True (-not $applyOutput.Contains($candidateToken)) 'Promotion output exposed the candidate token.'
  $after = Get-Content -LiteralPath $secretPath -Raw
  Assert-True $after.Contains("CLOUDFLARE_API_TOKEN=$candidateToken") 'Promotion did not activate the candidate.'
  Assert-True $after.Contains("CLOUDFLARE_API_TOKEN_CANDIDATE=$candidateToken") 'Promotion changed the candidate source.'
  Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Filter 'cloud-superbrain.local.env.rollback-qualified-*').Count -eq 1) 'Promotion rollback file missing.'
  Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Filter 'cloud-superbrain.local.env.candidate-promotion-*').Count -eq 0) 'Promotion left a plaintext temporary file.'
  Write-Host '[verify-cloudflare-token-promotion] parse=pass synthetic=3/3 atomic=true evidence_bound=true secret_output=false'
} finally {
  $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
  Assert-True $resolvedTestRoot.StartsWith(
    [IO.Path]::GetFullPath('D:\_sb_tmp') + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
  ) 'Test cleanup path escaped D:\_sb_tmp.'
  if (Test-Path -LiteralPath $resolvedTestRoot) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
  }
}
