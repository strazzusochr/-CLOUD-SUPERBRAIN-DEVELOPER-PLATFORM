[CmdletBinding()]
param(
  [string]$CurrentCandidatePath = "docs/release-artifacts/current-release-candidate.json",
  [string]$CandidateImageEvidencePath = "",
  [string]$RegistryDigestEvidencePath = "",
  [string]$RubricApprovalCommit = $env:LAYER_CREDIT_RUBRIC_APPROVAL_SHA,
  [string]$SyftCommand = "syft",
  [string]$DockerCommand = "docker",
  [string]$GitleaksCommand = "gitleaks",
  [switch]$RequireCreditEligible,
  [string]$OutDir = ".phase1-artifacts/mcp-gateway/candidate-sbom"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$rubricPath = "docs/runtime-contracts/layer-credit-rubric.md"
$requiredServices = @("frontend", "agent-api", "agent-worker", "memory-worker", "mcp-gateway", "llm-gateway")
$ghcrNamespace = "ghcr.io/strazzusochr/cloud-superbrain-developer-platform"
$sourceRepositoryUrl = "https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM"
$requiredSyftVersion = "1.51.0"
$requiredSyftBinarySha256 = "75adfff66c266adac51fe8addeca97702f82b4d822d02bf70b79f556c84d3a46"

function Assert-True([string]$Label, [bool]$Condition) { if (-not $Condition) { throw $Label } }
function Get-PropertyValue($Object, [string]$Name) {
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}
function Read-Json([string]$Path) {
  Assert-True "json_file_missing:$Path" (Test-Path -LiteralPath $Path -PathType Leaf)
  try { return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw "json_file_invalid:$Path" }
}
function Write-TextAtomic([string]$Path, [string]$Text) {
  $full = [IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
  [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)) | Out-Null
  $temporary = "$full.$([Guid]::NewGuid().ToString('N')).tmp"
  try {
    [IO.File]::WriteAllText($temporary, $Text, (New-Object Text.UTF8Encoding($false)))
    [IO.File]::Move($temporary, $full, $true)
  } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Get-StringSha256([string]$Text) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
  } finally { $sha.Dispose() }
}
function Write-Evidence($Value, [string]$TargetDir) {
  $path = Join-Path $TargetDir "report.json"
  Write-TextAtomic $path (($Value | ConvertTo-Json -Depth 30) + [Environment]::NewLine)
  $full = [IO.Path]::GetFullPath((Join-Path $repoRoot $path))
  $digest = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
  Write-TextAtomic (Join-Path $TargetDir "report.sha256") ("$digest  report.json$([Environment]::NewLine)")
  return $digest
}
function Test-RubricApproval([string]$Commit) {
  if ($Commit -notmatch "^[0-9a-f]{40}$") { return $false }
  & git -C $repoRoot cat-file -e "$Commit^{commit}" 2>$null
  if ($LASTEXITCODE -ne 0) { return $false }
  & git -C $repoRoot merge-base --is-ancestor $Commit HEAD 2>$null
  if ($LASTEXITCODE -ne 0) { return $false }
  $rubric = (& git -C $repoRoot show "${Commit}:$rubricPath" 2>$null | Out-String)
  return (
    $rubric -match '(?m)^Status:\s*`APPROVED`\s*$' -and
    $rubric -match '(?m)^Credit-Anwendung erlaubt:\s*`true`\s*$' -and
    $rubric.Contains("scripts/verify-mcp-candidate-sbom.ps1")
  )
}
function Assert-NoSecretMaterial([string]$Path) {
  $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  foreach ($pattern in @(
    '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----',
    '(?i)github_pat_[A-Za-z0-9_]{20,}',
    '(?i)gh[pousr]_[A-Za-z0-9]{20,}',
    '(?i)sk-[A-Za-z0-9_-]{20,}',
    '(?i)bearer\s+[A-Za-z0-9._~+/-]{16,}'
  )) {
    Assert-True "sbom_high_confidence_secret_pattern_detected" ($content -notmatch $pattern)
  }
  foreach ($entry in Get-ChildItem Env:) {
    if ($entry.Name -match '(?i)(TOKEN|SECRET|PASSWORD|PRIVATE_KEY|API_KEY)$' -and [string]$entry.Value -and ([string]$entry.Value).Length -ge 8) {
      Assert-True "sbom_contains_process_secret_value" (-not $content.Contains([string]$entry.Value))
    }
  }
}
function Get-RegistryDigestMap([string]$Path, [string]$ReleaseId, [string]$SourceSha) {
  $result = @{}
  if ([string]::IsNullOrWhiteSpace($Path)) { return $result }
  $evidence = Read-Json $Path
  Assert-True "registry_digest_contract_mismatch" ([string](Get-PropertyValue $evidence "contract_version") -eq "candidate-registry-digests-v1")
  Assert-True "registry_digest_release_mismatch" ([string](Get-PropertyValue $evidence "release_id") -eq $ReleaseId)
  Assert-True "registry_digest_source_mismatch" ([string](Get-PropertyValue $evidence "source_commit_sha") -eq $SourceSha)
  Assert-True "registry_publish_not_verified" ((Get-PropertyValue $evidence "registry_publish_verified") -eq $true)
  foreach ($item in @((Get-PropertyValue $evidence "images"))) {
    $service = [string](Get-PropertyValue $item "service")
    $digest = [string](Get-PropertyValue $item "digest")
    $reference = [string](Get-PropertyValue $item "immutable_reference")
    Assert-True "registry_service_unknown" ($requiredServices -contains $service)
    Assert-True "registry_digest_invalid:$service" ($digest -match '^sha256:[0-9a-f]{64}$')
    Assert-True "registry_reference_not_exact:$service" ($reference -ceq "$ghcrNamespace/$service@$digest")
    Assert-True "registry_oci_revision_mismatch:$service" ([string](Get-PropertyValue $item "oci_revision") -ceq $SourceSha)
    Assert-True "registry_oci_source_mismatch:$service" ([string](Get-PropertyValue $item "oci_source") -ceq $sourceRepositoryUrl)
    $attestation = Get-PropertyValue $item "attestation"
    Assert-True "registry_attestation_missing:$service" (
      (Get-PropertyValue $attestation "verified") -eq $true -and
      [string](Get-PropertyValue $attestation "image_digest") -ceq $digest -and
      [string](Get-PropertyValue $attestation "source_commit_sha") -ceq $SourceSha -and
      [string](Get-PropertyValue $attestation "statement_sha256") -match '^[0-9a-f]{64}$'
    )
    $remoteScan = Get-PropertyValue $item "remote_scan"
    Assert-True "registry_remote_scan_missing:$service" (
      (Get-PropertyValue $remoteScan "verified") -eq $true -and
      [string](Get-PropertyValue $remoteScan "image_digest") -ceq $digest -and
      [string](Get-PropertyValue $remoteScan "scanner") -match '^(trivy|grype)$' -and
      [string](Get-PropertyValue $remoteScan "report_sha256") -match '^[0-9a-f]{64}$'
    )
    Assert-True "registry_service_duplicate:$service" (-not $result.ContainsKey($service))
    $result[$service] = @{
      digest=$digest
      immutable_reference=$reference
      oci_revision=$SourceSha
      oci_source=$sourceRepositoryUrl
      attestation_sha256=[string](Get-PropertyValue $attestation "statement_sha256")
      remote_scan_sha256=[string](Get-PropertyValue $remoteScan "report_sha256")
    }
  }
  Assert-True "registry_digest_service_count_mismatch" ($result.Count -eq $requiredServices.Count)
  return $result
}

Push-Location $repoRoot
try {
  $syftCommandInfo = Get-Command $SyftCommand -CommandType Application -ErrorAction SilentlyContinue
  Assert-True "syft_command_missing" ($null -ne $syftCommandInfo)
  Assert-True "docker_command_missing" ($null -ne (Get-Command $DockerCommand -ErrorAction SilentlyContinue))
  Assert-True "gitleaks_command_missing" ($null -ne (Get-Command $GitleaksCommand -ErrorAction SilentlyContinue))

  $current = Read-Json $CurrentCandidatePath
  $releaseId = [string](Get-PropertyValue $current "active_release_id")
  $sourceSha = [string](Get-PropertyValue $current "source_commit_sha")
  Assert-True "active_release_id_invalid" ($releaseId -match '^prod-candidate-[A-Za-z0-9._-]+$')
  Assert-True "candidate_source_sha_invalid" ($sourceSha -match '^[0-9a-f]{40}$')
  & git -C $repoRoot cat-file -e "$sourceSha^{commit}" 2>$null
  Assert-True "candidate_source_commit_unknown" ($LASTEXITCODE -eq 0)

  if ([string]::IsNullOrWhiteSpace($CandidateImageEvidencePath)) {
    $CandidateImageEvidencePath = "docs/release-artifacts/$releaseId-evidence/candidate-images.json"
  }
  $candidate = Read-Json $CandidateImageEvidencePath
  Assert-True "candidate_image_contract_mismatch" ([string](Get-PropertyValue $candidate "contract_version") -eq "phase5-production-candidate-local-v2")
  Assert-True "candidate_image_status_not_verified" ([string](Get-PropertyValue $candidate "status") -eq "verified")
  Assert-True "candidate_image_release_mismatch" ([string](Get-PropertyValue $candidate "release_id") -eq $releaseId)
  Assert-True "candidate_image_source_mismatch" ([string](Get-PropertyValue $candidate "source_commit_sha") -eq $sourceSha)
  Assert-True "candidate_image_source_boundary_mismatch" ([string](Get-PropertyValue $candidate "source_boundary") -eq "committed_git_archive_only")
  Assert-True "candidate_image_service_count_mismatch" ([int](Get-PropertyValue $candidate "service_count") -eq $requiredServices.Count)
  Assert-True "candidate_secret_output_must_be_false" ((Get-PropertyValue $candidate "secret_output") -eq $false)
  Assert-True "candidate_production_deploy_must_be_false" ((Get-PropertyValue $candidate "production_deploy") -eq $false)

  $registryMap = Get-RegistryDigestMap $RegistryDigestEvidencePath $releaseId $sourceSha
  $rubricApproved = Test-RubricApproval $RubricApprovalCommit
  $targetDir = Join-Path $OutDir $releaseId
  $resolvedTargetDir = [IO.Path]::GetFullPath((Join-Path $repoRoot $targetDir))
  [IO.Directory]::CreateDirectory($resolvedTargetDir) | Out-Null

  $syftVersionJson = (& $SyftCommand version -o json 2>$null | Out-String)
  Assert-True "syft_version_failed" ($LASTEXITCODE -eq 0)
  try { $syftVersion = $syftVersionJson | ConvertFrom-Json } catch { throw "syft_version_json_invalid" }
  Assert-True "syft_version_not_pinned" ([string](Get-PropertyValue $syftVersion "version") -ceq $requiredSyftVersion)
  $syftBinaryPath = [IO.Path]::GetFullPath([string]$syftCommandInfo.Source)
  Assert-True "syft_binary_missing" (Test-Path -LiteralPath $syftBinaryPath -PathType Leaf)
  $syftBinarySha256 = (Get-FileHash -LiteralPath $syftBinaryPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Assert-True "syft_binary_hash_mismatch" ($syftBinarySha256 -ceq $requiredSyftBinarySha256)

  $imageResults = @()
  $seen = @{}
  foreach ($service in $requiredServices) {
    $image = @((Get-PropertyValue $candidate "images") | Where-Object { [string](Get-PropertyValue $_ "service") -eq $service })
    Assert-True "candidate_image_entry_count_mismatch:$service" ($image.Count -eq 1)
    $entry = $image[0]
    $tag = [string](Get-PropertyValue $entry "image_tag")
    $expectedImageId = [string](Get-PropertyValue $entry "image_id")
    Assert-True "candidate_image_tag_not_source_bound:$service" ($tag.EndsWith(":$sourceSha"))
    Assert-True "candidate_image_id_invalid:$service" ($expectedImageId -match '^sha256:[0-9a-f]{64}$')
    Assert-True "candidate_embedded_hash_mismatch:$service" (
      [string](Get-PropertyValue $entry "source_file_sha256") -eq [string](Get-PropertyValue $entry "embedded_file_sha256")
    )
    Assert-True "candidate_service_duplicate:$service" (-not $seen.ContainsKey($service))
    $seen[$service] = $true

    $actualImageId = (& $DockerCommand image inspect $tag "--format={{.Id}}" 2>$null | Out-String).Trim()
    Assert-True "candidate_image_not_local:$service" ($LASTEXITCODE -eq 0 -and $actualImageId -eq $expectedImageId)
    $sbomRelativePath = Join-Path $targetDir "$service.cdx.json"
    $sbomFullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $sbomRelativePath))
    & $SyftCommand scan $tag --from docker --output "cyclonedx-json=$sbomFullPath" --quiet 2>$null
    Assert-True "syft_scan_failed:$service" ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $sbomFullPath -PathType Leaf))
    Assert-NoSecretMaterial $sbomFullPath
    $sbom = Read-Json $sbomFullPath
    Assert-True "sbom_format_mismatch:$service" ([string](Get-PropertyValue $sbom "bomFormat") -eq "CycloneDX")
    Assert-True "sbom_spec_version_missing:$service" ([string](Get-PropertyValue $sbom "specVersion") -match '^1\.[4-9]$')
    $components = @((Get-PropertyValue $sbom "components"))
    Assert-True "sbom_components_missing:$service" ($components.Count -gt 0)
    $sbomDigest = (Get-FileHash -LiteralPath $sbomFullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $registry = if ($registryMap.ContainsKey($service)) { $registryMap[$service] } else { $null }
    $imageResults += [ordered]@{
      service = $service
      candidate_image_tag = $tag
      local_image_id = $expectedImageId
      registry_digest = if ($null -ne $registry) { [string]$registry.digest } else { $null }
      immutable_registry_reference = if ($null -ne $registry) { [string]$registry.immutable_reference } else { $null }
      oci_revision = if ($null -ne $registry) { [string]$registry.oci_revision } else { $null }
      oci_source = if ($null -ne $registry) { [string]$registry.oci_source } else { $null }
      attestation_sha256 = if ($null -ne $registry) { [string]$registry.attestation_sha256 } else { $null }
      remote_scan_sha256 = if ($null -ne $registry) { [string]$registry.remote_scan_sha256 } else { $null }
      sbom_path = $sbomRelativePath.Replace("\", "/")
      sbom_sha256 = $sbomDigest
      bom_format = "CycloneDX"
      spec_version = [string](Get-PropertyValue $sbom "specVersion")
      component_count = $components.Count
      secret_value_scan = "passed"
    }
  }
  Assert-True "candidate_service_inventory_mismatch" ($seen.Count -eq $requiredServices.Count)

  $gitleaksOutput = (& $GitleaksCommand detect --no-git --source $resolvedTargetDir --config (Join-Path $repoRoot ".gitleaks.toml") --redact --no-banner 2>&1 | Out-String)
  $gitleaksExit = $LASTEXITCODE
  $gitleaksOutput = ""
  Assert-True "sbom_gitleaks_scan_failed" ($gitleaksExit -eq 0)

  $bindingMaterial = ($imageResults | ForEach-Object { "$($_.service)|$($_.local_image_id)|$($_.registry_digest)|$($_.oci_revision)|$($_.oci_source)|$($_.attestation_sha256)|$($_.remote_scan_sha256)|$($_.sbom_sha256)" }) -join "`n"
  $bindingDigest = Get-StringSha256 ($bindingMaterial + "`n")
  $registryBound = $registryMap.Count -eq $requiredServices.Count
  $creditEligible = $rubricApproved -and $registryBound
  $report = [ordered]@{
    contract_version = "mcp-candidate-sbom-evidence-v2"
    evidence_ref = "candidate_images_cyclonedx_sbom_digest_bound"
    status = "verified"
    checked_at = [DateTime]::UtcNow.ToString("o")
    release_id = $releaseId
    source_commit_sha = $sourceSha
    source_boundary = "committed_git_archive_only"
    service_count = $requiredServices.Count
    sbom_count = $imageResults.Count
    sbom_format = "CycloneDX JSON"
    syft_version = [string](Get-PropertyValue $syftVersion "version")
    syft_binary_sha256 = $syftBinarySha256
    images = $imageResults
    aggregate_binding_sha256 = $bindingDigest
    gitleaks_scan = "passed"
    rubric_approval_commit = $RubricApprovalCommit
    rubric_owner_approved = $rubricApproved
    immutable_registry_digests_bound = $registryBound
    credit_eligible = $creditEligible
    credit_blockers = @(
      if (-not $rubricApproved) { "layer_credit_rubric_owner_approval_missing" }
      if (-not $registryBound) { "immutable_registry_digest_evidence_missing" }
    )
    registry_publish_performed = $false
    provider_writes = $false
    production_deploy = $false
    secret_output = $false
    non_claims = @(
      "SBOM generation reads existing local candidate images and does not publish or pull them.",
      "Local Docker image IDs are not remote registry digests.",
      "No L5 credit is eligible without owner-approved rubric and immutable registry digest evidence."
    )
  }
  $reportDigest = Write-Evidence $report $targetDir
  if ($RequireCreditEligible -and -not $creditEligible) {
    throw "candidate_sbom_credit_blocked:$(@($report.credit_blockers) -join ',')"
  }
  Write-Host "[mcp-candidate-sbom] PASS sboms=$($imageResults.Count) binding_sha256=$bindingDigest evidence_sha256=$reportDigest credit_eligible=$($creditEligible.ToString().ToLowerInvariant()) secret_output=false"
} finally {
  Pop-Location
}
