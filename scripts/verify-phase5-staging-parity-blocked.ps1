param(
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

function Assert-Matches($label, $value, $pattern) {
  $text = ($value | Out-String)
  if ($text -notmatch $pattern) {
    throw "Verification failed: $label did not match pattern '$pattern'."
  }
}

function Assert-Equal($label, $actual, $expected) {
  if ($actual -ne $expected) {
    throw "Verification failed: $label expected '$expected' but got '$actual'."
  }
}

function Get-Json($uri) {
@"
import json, urllib.request
with urllib.request.urlopen(r'''$uri''', timeout=30) as response:
    print(json.dumps(json.load(response)))
"@ | py -3 -
}

function Get-GhcrManifestDigest($service, $tag) {
@"
import json, urllib.parse, urllib.request
repo = "strazzusochr/cloud-superbrain-developer-platform/$service"
query = urllib.parse.urlencode({"scope": f"repository:{repo}:pull"})
with urllib.request.urlopen("https://ghcr.io/token?" + query, timeout=30) as response:
    token = json.load(response)["token"]
req = urllib.request.Request(
    f"https://ghcr.io/v2/{repo}/manifests/$tag",
    method="HEAD",
    headers={
        "Authorization": f"Bearer {token}",
        "Accept": ",".join([
            "application/vnd.oci.image.index.v1+json",
            "application/vnd.docker.distribution.manifest.list.v2+json",
            "application/vnd.oci.image.manifest.v1+json",
            "application/vnd.docker.distribution.manifest.v2+json"
        ]),
        "User-Agent": "Codex"
    }
)
with urllib.request.urlopen(req, timeout=30) as response:
    print(response.headers["Docker-Content-Digest"])
"@ | py -3 -
}

function Invoke-DeployPlan($Arguments, [bool]$ShouldPass, [string]$ExpectedText) {
  $previousErrorActionPreference = $ErrorActionPreference
  $hasNativePreference = Test-Path variable:PSNativeCommandUseErrorActionPreference
  if ($hasNativePreference) {
    $previousNativePreference = $PSNativeCommandUseErrorActionPreference
  }
  $ErrorActionPreference = "Continue"
  if ($hasNativePreference) {
    $PSNativeCommandUseErrorActionPreference = $false
  }
  try {
    $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\deploy-to-staging.ps1" @Arguments 2>&1 | ForEach-Object { $_.ToString() }) | Out-String
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
    if ($hasNativePreference) {
      $PSNativeCommandUseErrorActionPreference = $previousNativePreference
    }
  }
  if ($ShouldPass -and $exitCode -ne 0) {
    throw "Verification failed: deploy plan expected PASS but failed with exit code $exitCode. Output: $output"
  }
  if (-not $ShouldPass -and $exitCode -eq 0) {
    throw "Verification failed: deploy plan expected FAIL but passed. Output: $output"
  }
  Assert-Contains "deploy plan output" $output $ExpectedText
  return $output
}

$manifest = Get-Content "docs\project-progress.manifest.json" -Raw | ConvertFrom-Json
$expectedOverall = [int]$manifest.overall_percent
$expectedPhase5 = [int](($manifest.horizontal.items | Where-Object { $_.id -eq "phase_5" }).percent)
$immutableTag = "ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5"

$artifactPath = "docs\release-artifacts\$ReleaseId-staging-parity-blocked.md"
if (-not (Test-Path $artifactPath)) {
  throw "Missing staging parity blocker artifact: $artifactPath"
}
$artifact = Get-Content $artifactPath -Raw
foreach ($required in @(
  'Status: `blocked`',
  "release_id: ``$ReleaseId``",
  "overall_percent: ``$expectedOverall``",
  "phase_5_percent: ``$expectedPhase5``",
  'owner_decision: `no-release`',
  'current_hosted_selector: `IMAGE_TAG=staging`',
  'parity_classification: `blocked_staging_tag_parity`',
  'service_hot_mount_parity: `blocked`',
  'runtime_source_drift: `blocked`',
  'immutable_image_filesystem_plan: `supported_by scripts/deploy-to-staging.ps1 -UseImageFilesystem -ImageTag ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`',
  'positive_parity_verifier: `scripts/manual/verify-phase5-staging-immutable-parity.ps1 -RequireVerified`',
  'Hosted staging digest parity to immutable candidate tag set: `blocked`',
  'Hosted service hot-mount parity to immutable candidate tag set: `blocked`',
  'Runtime source parity to immutable candidate source SHA: `blocked`',
  'Immutable image-filesystem staging deploy plan exists: `yes`',
  'Positive immutable staging parity verifier exists: `yes`',
  'Immutable SHA deploy plans are guarded: a 40-character SHA image tag is rejected unless it uses `-UseImageFilesystem` or a matching `-SourceRef`.',
  'Remote staging selector files are backed up before mutation and restored if copy, selector update, compose pull/up, or hosted health probes fail.',
  'Because `:staging` is retagged by every successful `main-deploy` run, the digest lines below are historical evidence. The verifier re-queries GHCR live and requires current `:staging` to remain different from the immutable candidate tag set.',
  'Candidate remains fail-closed for release: `yes`'
)) {
  Assert-Contains "staging parity blocker artifact" $artifact $required
}

$candidate = Get-Content "docs\release-artifacts\$ReleaseId.md" -Raw
Assert-Contains "candidate staging parity status" $candidate 'staging_tag_parity_status: `blocked`'
Assert-Contains "candidate staging parity proof" $candidate 'staging_tag_parity_blocked_proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`'
Assert-Contains "candidate staging parity evidence bullet" $candidate 'Staging tag parity blocked proof: `docs/release-artifacts/prod-candidate-2026-05-05-rc1-staging-parity-blocked.md`'
Assert-Contains "candidate rollback selector note" $candidate 'restored to IMAGE_TAG=staging'
Assert-Contains "candidate hot mount parity note" $candidate 'Service hot-mounts can also override image-contained code, so runtime parity requires an image-filesystem deploy or a freshly built immutable candidate.'

$cloudCompose = Get-Content "docker-compose.cloud.yml" -Raw
$hotMountPattern = '(?m)^[ \t]+- \./services/(agent-api|agent-worker|memory-worker|mcp-gateway|llm-gateway)/app:/app/app:ro\r?$'
$hotMountCount = [regex]::Matches($cloudCompose, $hotMountPattern).Count
if ($hotMountCount -lt 1) {
  throw "Verification failed: expected service hot-mounts to remain present while parity is blocked."
}

$deployScript = Get-Content "scripts\deploy-to-staging.ps1" -Raw
Assert-Contains "deploy script immutable image filesystem option" $deployScript "[switch]`$UseImageFilesystem"
Assert-Contains "deploy script plan-only option" $deployScript "[switch]`$PlanOnly"
Assert-Contains "deploy script immutable hot-mount guard" $deployScript "Immutable image tag deploys must use -UseImageFilesystem or matching -SourceRef"
Assert-Contains "deploy script remote env backup" $deployScript '$remoteEnvBackupName = ".env.bak.codex-$remoteBackupSuffix"'
Assert-Contains "deploy script remote compose backup" $deployScript '$remoteComposeBackupName = "docker-compose.cloud.yml.bak.codex-$remoteBackupSuffix"'
Assert-Contains "deploy script remote rollback warning" $deployScript "Staging deploy failed; restoring previous remote selector files."
Assert-Contains "deploy script temp cleanup" $deployScript "finally {"

if (-not (Test-Path "scripts\manual\verify-phase5-staging-immutable-parity.ps1")) {
  throw "Missing positive immutable staging parity verifier."
}
$positiveVerifier = Get-Content "scripts\manual\verify-phase5-staging-immutable-parity.ps1" -Raw
Assert-Contains "positive verifier require switch" $positiveVerifier "[switch]`$RequireVerified"
Assert-Contains "positive verifier ready mode" $positiveVerifier "[phase5-staging-immutable-parity] ready"
Assert-Contains "positive verifier verified mode" $positiveVerifier "[phase5-staging-immutable-parity] verified"

$planOutput = Invoke-DeployPlan @(
  "-PlanOnly",
  "-UseImageFilesystem",
  "-ImageTag",
  $immutableTag
) $true "Use image filesystem: True"
Assert-Contains "immutable plan image tag" $planOutput "Image tag: $immutableTag"
Assert-Contains "immutable plan hot mount count" $planOutput "Service hot-mount entries in source compose: 5"
Assert-Contains "immutable plan caddy" $planOutput "Compose has caddy: True"

Invoke-DeployPlan @(
  "-PlanOnly",
  "-ImageTag",
  $immutableTag
) $false "Immutable image tag deploys must use -UseImageFilesystem or matching -SourceRef" | Out-Null

Invoke-DeployPlan @(
  "-PlanOnly",
  "-UseImageFilesystem",
  "-ImageTag",
  $immutableTag,
  "-SourceRef",
  "main"
) $false "Immutable image tag deploys must use an empty SourceRef for the current infra overlay or a SourceRef matching" | Out-Null

$services = @("agent-api", "mcp-gateway", "frontend", "llm-gateway", "agent-worker", "memory-worker")
$mismatchCount = 0
foreach ($service in $services) {
  $stagingDigest = (Get-GhcrManifestDigest $service "staging").Trim()
  $immutableDigest = (Get-GhcrManifestDigest $service $immutableTag).Trim()
  if ($stagingDigest -eq $immutableDigest) {
    throw "Verification failed: current staging digest for $service now matches immutable candidate digest; blocker artifact must be retired or rewritten."
  }
  $mismatchCount += 1
  $artifactDigestPattern = "(?m)^- ``$([regex]::Escape($service))``: staging ``sha256:[0-9a-f]+`` != immutable ``$([regex]::Escape($immutableDigest))``$"
  Assert-Matches "artifact historical digest line $service" $artifact $artifactDigestPattern
  Write-Host "[phase5-staging-parity-blocked] live digest mismatch $service"
}
if ($mismatchCount -lt 1) {
  throw "Verification failed: staging and immutable candidate digests no longer diverge; blocker artifact must be retired or rewritten."
}

$runtimeDriftPaths = @(
  "docker-compose.cloud.yml",
  "docs/project-progress.manifest.json",
  "PROJECT_STATE.md",
  "services/agent-api/app",
  "services/agent-worker/app",
  "services/memory-worker/app",
  "services/mcp-gateway/app",
  "services/llm-gateway/app"
)
$runtimeDrift = @(git diff --name-only $immutableTag -- $runtimeDriftPaths)
if ($LASTEXITCODE -ne 0) {
  throw "Verification failed: git diff against immutable candidate source failed."
}
if ($runtimeDrift.Count -lt 1) {
  throw "Verification failed: runtime source no longer drifts from immutable candidate source; blocker artifact must be retired or rewritten."
}

$progress = Get-Json "$BaseUrl/api/v1/project/progress" | ConvertFrom-Json
$integrity = Get-Json "$BaseUrl/api/v1/project/progress/integrity" | ConvertFrom-Json
$completion = Get-Json "$BaseUrl/api/v1/project/progress/completion" | ConvertFrom-Json
$phase5 = $progress.horizontal.items | Where-Object { $_.id -eq "phase_5" } | Select-Object -First 1
Assert-Equal "hosted overall percent" $progress.overall_percent $expectedOverall
Assert-Equal "hosted phase5 percent" $phase5.percent $expectedPhase5
Assert-Equal "hosted integrity status" $integrity.status "verified"
if ($completion.can_set_all_to_100 -ne $false) {
  throw "Verification failed: completion gate must remain fail-closed."
}

Write-Host "[phase5-staging-parity-blocked] verified"
