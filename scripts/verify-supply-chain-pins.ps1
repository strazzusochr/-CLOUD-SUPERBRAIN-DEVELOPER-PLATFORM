$ErrorActionPreference = "Stop"

function Fail-SupplyChainVerification {
  param([string]$Message)
  throw "Supply-chain pin verification failed: $Message"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Get-TrackedFiles {
  param(
    [string]$Label,
    [string[]]$Pathspecs
  )

  $trackedFiles = @(& git -C $repoRoot ls-files -- @Pathspecs)
  if ($LASTEXITCODE -ne 0) {
    Fail-SupplyChainVerification "git ls-files failed while discovering $Label"
  }
  return @($trackedFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}

$workflowFiles = @(Get-TrackedFiles `
  -Label ".github YAML files" `
  -Pathspecs @(":(glob).github/**/*.yml", ":(glob).github/**/*.yaml"))
if ($workflowFiles.Count -eq 0) {
  Fail-SupplyChainVerification "no tracked .github YAML files discovered"
}

$expectedActions = @(
  [pscustomobject]@{ Action = "actions/checkout"; Sha = "11d5960a326750d5838078e36cf38b85af677262"; Comment = "v4"; Count = 1 },
  [pscustomobject]@{ Action = "actions/checkout"; Sha = "d23441a48e516b6c34aea4fa41551a30e30af803"; Comment = "v6"; Count = 7 },
  [pscustomobject]@{ Action = "actions/upload-artifact"; Sha = "ea165f8d65b6e75b540449e92b4886f43607fa02"; Comment = "v4.6.2"; Count = 1 },
  [pscustomobject]@{ Action = "actions/setup-node"; Sha = "49933ea5288caeca8642d1e84afbd3f7d6820020"; Comment = "v4"; Count = 1 },
  [pscustomobject]@{ Action = "actions/setup-node"; Sha = "249970729cb0ef3589644e2896645e5dc5ba9c38"; Comment = "v6"; Count = 1 },
  [pscustomobject]@{ Action = "actions/setup-python"; Sha = "a26af69be951a213d495a4c3e4e4022e16d87065"; Comment = "v5"; Count = 1 },
  [pscustomobject]@{ Action = "actions/setup-python"; Sha = "ece7cb06caefa5fff74198d8649806c4678c61a1"; Comment = "v6"; Count = 3 },
  [pscustomobject]@{ Action = "pnpm/action-setup"; Sha = "eae0cfeb286e66ffb5155f1a79b90583a127a68b"; Comment = "v2.4.1"; Count = 1 },
  [pscustomobject]@{ Action = "docker/setup-qemu-action"; Sha = "96fe6ef7f33517b61c61be40b68a1882f3264fb8"; Comment = "v4"; Count = 1 },
  [pscustomobject]@{ Action = "docker/setup-buildx-action"; Sha = "bb05f3f5519dd87d3ba754cc423b652a5edd6d2c"; Comment = "v4"; Count = 1 },
  [pscustomobject]@{ Action = "docker/login-action"; Sha = "abd2ef45e78c5afb21d64d4ca52ee8550d9572c7"; Comment = "v4"; Count = 1 },
  [pscustomobject]@{ Action = "docker/build-push-action"; Sha = "53b7df96c91f9c12dcc8a07bcb9ccacbed38856a"; Comment = "v7"; Count = 1 }
)

$expectedActionKeys = @{}
foreach ($expected in $expectedActions) {
  $key = "$($expected.Action)@$($expected.Sha)#$($expected.Comment)"
  if ($expectedActionKeys.ContainsKey($key)) {
    Fail-SupplyChainVerification "duplicate expected action key: $key"
  }
  $expectedActionKeys[$key] = [int]$expected.Count
}

$actualActionCounts = @{}
$externalActionCount = 0
foreach ($relativePath in $workflowFiles) {
  $absolutePath = Join-Path $repoRoot $relativePath
  if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
    Fail-SupplyChainVerification "missing workflow: $relativePath"
  }

  $lineNumber = 0
  foreach ($line in Get-Content -LiteralPath $absolutePath) {
    $lineNumber += 1
    if ($line -notmatch "^\s*uses:\s*") {
      continue
    }
    if ($line -notmatch "^\s*uses:\s*(\S+)(?:\s+#\s*(.*?)\s*)?$") {
      Fail-SupplyChainVerification "malformed uses reference at ${relativePath}:${lineNumber}"
    }

    $target = $Matches[1]
    $comment = if ($Matches[2]) { $Matches[2].Trim() } else { "" }
    if ($target.StartsWith("./", [System.StringComparison]::Ordinal)) {
      continue
    }
    if ($target -notmatch "^([^@]+)@([0-9a-f]{40})$") {
      Fail-SupplyChainVerification "external action is not pinned to a lowercase 40-character SHA at ${relativePath}:${lineNumber}: $target"
    }

    $action = $Matches[1]
    $sha = $Matches[2]
    $key = "${action}@${sha}#${comment}"
    if (-not $expectedActionKeys.ContainsKey($key)) {
      Fail-SupplyChainVerification "unexpected action pin or tag comment at ${relativePath}:${lineNumber}: $key"
    }
    if (-not $actualActionCounts.ContainsKey($key)) {
      $actualActionCounts[$key] = 0
    }
    $actualActionCounts[$key] += 1
    $externalActionCount += 1
  }
}

if ($externalActionCount -ne 20) {
  Fail-SupplyChainVerification "expected exactly 20 external action references, found $externalActionCount"
}
foreach ($key in $expectedActionKeys.Keys) {
  $actual = if ($actualActionCounts.ContainsKey($key)) { [int]$actualActionCounts[$key] } else { 0 }
  if ($actual -ne $expectedActionKeys[$key]) {
    Fail-SupplyChainVerification "action occurrence mismatch for ${key}: expected $($expectedActionKeys[$key]), found $actual"
  }
}

$expectedImageDigests = @{
  "node:24.16.0-alpine" = "sha256:21f403ab171f2dc89bad4dd69d7721bfd15f084ccb46cdd225f31f2bc59b5c9a"
  "python:3.14-slim" = "sha256:cea0e6040540fb2b965b6e7fb5ffa00871e632eef63719f0ea54bca189ce14a6"
  "python:3.14-alpine" = "sha256:26730869004e2b9c4b9ad09cab8625e81d256d1ce97e72df5520e806b1709f92"
  "pgvector/pgvector:0.8.2-pg16" = "sha256:00ba258a66dac104fd5171074a0084462a64a1369d8513f3d0a634e2f24d15bc"
  "redis:7.4.2-alpine" = "sha256:02419de7eddf55aa5bcf49efb74e88fa8d931b4d77c07eff8a6b2144472b6952"
  "nginx:1.27.4-alpine" = "sha256:4ff102c5d78d254a6f0da062b3cf39eaf07f01eec0927fd21e219d0af8bc0591"
  "caddy:2.9.1-alpine" = "sha256:b4e3952384eb9524a887633ce65c752dd7c71314d2c2acf98cd5c715aaa534f0"
  "ghcr.io/ggml-org/llama.cpp:server" = "sha256:4f02c560799a1569be08b0183d52b94b0d4a6e4b88f52f20562d2334c73837d4"
  "nginxinc/nginx-unprivileged:1.27-alpine" = "sha256:65e3e85dbaed8ba248841d9d58a899b6197106c23cb0ff1a132b7bfe0547e4c0"
}

$trackedDockerfiles = @(Get-TrackedFiles `
  -Label "Dockerfiles" `
  -Pathspecs @(":(glob)Dockerfile", ":(glob)**/Dockerfile"))
$trackedComposeFiles = @(Get-TrackedFiles `
  -Label "root docker-compose YAML files" `
  -Pathspecs @(":(glob)docker-compose*.yml", ":(glob)docker-compose*.yaml"))
if ($trackedDockerfiles.Count -eq 0) {
  Fail-SupplyChainVerification "no tracked Dockerfiles discovered"
}
if ($trackedComposeFiles.Count -eq 0) {
  Fail-SupplyChainVerification "no tracked root docker-compose YAML files discovered"
}

$imageFiles = @(
  @($trackedDockerfiles | ForEach-Object {
    [pscustomobject]@{ Path = $_; Kind = "dockerfile" }
  })
  @($trackedComposeFiles | ForEach-Object {
    [pscustomobject]@{ Path = $_; Kind = "compose" }
  })
)

$expectedImageOccurrences = @{
  "apps/frontend/Dockerfile|node:24.16.0-alpine" = 4
  "services/agent-api/Dockerfile|python:3.14-alpine" = 2
  "services/agent-worker/Dockerfile|python:3.14-slim" = 1
  "services/llm-gateway/Dockerfile|python:3.14-slim" = 1
  "services/mcp-gateway/Dockerfile|python:3.14-slim" = 1
  "services/memory-worker/Dockerfile|python:3.14-slim" = 1
  "docker-compose.dev.yml|ghcr.io/ggml-org/llama.cpp:server" = 1
  "docker-compose.dev.yml|pgvector/pgvector:0.8.2-pg16" = 1
  "docker-compose.dev.yml|redis:7.4.2-alpine" = 1
  "docker-compose.dev.yml|nginxinc/nginx-unprivileged:1.27-alpine" = 1
  "docker-compose.cloud.yml|pgvector/pgvector:0.8.2-pg16" = 1
  "docker-compose.cloud.yml|redis:7.4.2-alpine" = 1
  "docker-compose.cloud.yml|nginx:1.27.4-alpine" = 1
  "docker-compose.cloud.yml|caddy:2.9.1-alpine" = 1
}

$actualImageOccurrences = @{}
$actualUniqueImages = @{}
$externalImageCount = 0
$expectedInternalGhcrServices = @(
  "frontend",
  "agent-api",
  "agent-worker",
  "memory-worker",
  "mcp-gateway",
  "llm-gateway"
)
$actualInternalGhcrServices = @{}
$internalVariableImageCount = 0
foreach ($imageFile in $imageFiles) {
  $absolutePath = Join-Path $repoRoot $imageFile.Path
  if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
    Fail-SupplyChainVerification "missing image source file: $($imageFile.Path)"
  }

  $lineNumber = 0
  foreach ($line in Get-Content -LiteralPath $absolutePath) {
    $lineNumber += 1
    $imageReference = $null
    if ($imageFile.Kind -eq "dockerfile" -and $line -match "^\s*FROM\s+") {
      if ($line -notmatch "^\s*FROM\s+(\S+)(?:\s+AS\s+\S+)?\s*$") {
        Fail-SupplyChainVerification "malformed FROM reference at $($imageFile.Path):${lineNumber}"
      }
      $imageReference = $Matches[1]
    } elseif ($imageFile.Kind -eq "compose" -and $line -match "^\s*image:\s*") {
      if ($line -notmatch "^\s*image:\s*(\S+)\s*$") {
        Fail-SupplyChainVerification "malformed compose image reference at $($imageFile.Path):${lineNumber}"
      }
      $imageReference = $Matches[1]
      if ($imageReference.StartsWith('${GHCR_IMAGE_NAMESPACE:-', [System.StringComparison]::Ordinal)) {
        if ($imageFile.Path -ne "docker-compose.cloud.yml") {
          Fail-SupplyChainVerification "variable internal GHCR image is only allowed in docker-compose.cloud.yml: $($imageFile.Path):${lineNumber}"
        }
        if ($imageReference -notmatch '^\$\{GHCR_IMAGE_NAMESPACE:-ghcr\.io/strazzusochr/cloud-superbrain-developer-platform\}/(frontend|agent-api|agent-worker|memory-worker|mcp-gateway|llm-gateway):\$\{IMAGE_TAG:-staging\}$') {
          Fail-SupplyChainVerification "unexpected variable internal GHCR image at $($imageFile.Path):${lineNumber}: $imageReference"
        }
        $service = $Matches[1]
        if ($actualInternalGhcrServices.ContainsKey($service)) {
          Fail-SupplyChainVerification "duplicate variable internal GHCR image for service: $service"
        }
        $actualInternalGhcrServices[$service] = $true
        $internalVariableImageCount += 1
        continue
      }
    } else {
      continue
    }

    if ($imageReference -notmatch "^(.+)@(sha256:[0-9a-f]{64})$") {
      Fail-SupplyChainVerification "external image is not pinned to a sha256 digest at $($imageFile.Path):${lineNumber}: $imageReference"
    }
    $tag = $Matches[1]
    $digest = $Matches[2]
    if (-not $expectedImageDigests.ContainsKey($tag)) {
      Fail-SupplyChainVerification "unexpected external image at $($imageFile.Path):${lineNumber}: $tag"
    }
    if ($digest -ne $expectedImageDigests[$tag]) {
      Fail-SupplyChainVerification "digest mismatch for $tag at $($imageFile.Path):${lineNumber}"
    }

    $occurrenceKey = "$($imageFile.Path)|${tag}"
    if (-not $expectedImageOccurrences.ContainsKey($occurrenceKey)) {
      Fail-SupplyChainVerification "unexpected image/file mapping: $occurrenceKey"
    }
    if (-not $actualImageOccurrences.ContainsKey($occurrenceKey)) {
      $actualImageOccurrences[$occurrenceKey] = 0
    }
    $actualImageOccurrences[$occurrenceKey] += 1
    $actualUniqueImages[$tag] = $true
    $externalImageCount += 1
  }
}

if ($externalImageCount -ne 18) {
  Fail-SupplyChainVerification "expected exactly 18 external image occurrences, found $externalImageCount"
}
if ($actualUniqueImages.Count -ne 9) {
  Fail-SupplyChainVerification "expected exactly 9 unique external images, found $($actualUniqueImages.Count)"
}
if ($internalVariableImageCount -ne 6) {
  Fail-SupplyChainVerification "expected exactly 6 variable internal GHCR image references, found $internalVariableImageCount"
}
foreach ($service in $expectedInternalGhcrServices) {
  if (-not $actualInternalGhcrServices.ContainsKey($service)) {
    Fail-SupplyChainVerification "missing variable internal GHCR image for service: $service"
  }
}
foreach ($key in $expectedImageOccurrences.Keys) {
  $actual = if ($actualImageOccurrences.ContainsKey($key)) { [int]$actualImageOccurrences[$key] } else { 0 }
  if ($actual -ne $expectedImageOccurrences[$key]) {
    Fail-SupplyChainVerification "image occurrence mismatch for ${key}: expected $($expectedImageOccurrences[$key]), found $actual"
  }
}

Write-Host "[verify] supply-chain pins PASS (20 external actions, 18 external image occurrences, 9 unique external images, 6 internal GHCR references)"
