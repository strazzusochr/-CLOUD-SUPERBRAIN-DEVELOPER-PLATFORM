<#
.SYNOPSIS
  Deploys the Cloudflare stateful runtime worker with a mandatory source binding.

.DESCRIPTION
  wrangler replaces the whole plain_text var set with the `vars` block of
  wrangler.jsonc on every deploy. SOURCE_COMMIT_SHA and SOURCE_ARCHIVE_SHA256 are
  intentionally NOT stored in that file, because they change per candidate. A plain
  `wrangler deploy` therefore silently wipes them and the hosted source parity check
  in scripts/verify-cloudflare-stateful-runtime.ps1 fails closed.

  This script is the only sanctioned deploy path. It recomputes both values from the
  given commit and passes them explicitly, so the binding can never be lost again.

  Regression this guards: 2026-08-30, a deploy without these vars left the hosted
  worker reporting source_commit_sha=null.
#>
param(
  [string]$CommitSha = "HEAD",
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) { throw "Worker deploy precondition failed: $Label" }
  Write-Host "[worker-deploy] $Label"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
  $resolved = (& git rev-parse --verify "$CommitSha^{commit}").Trim()
  Assert-True "commit resolved ($resolved)" ($LASTEXITCODE -eq 0 -and $resolved -match "^[0-9a-f]{40}$")

  $workerDiff = & git diff --name-only $resolved -- services/cloudflare-stateful-runtime
  Assert-True "worker tree matches the deployed commit" ([string]::IsNullOrWhiteSpace(($workerDiff -join "")))

  $tempArchive = Join-Path ([System.IO.Path]::GetTempPath()) ("worker-src-" + [Guid]::NewGuid().ToString("N") + ".tar")
  try {
    & git archive --format=tar "--output=$tempArchive" $resolved
    Assert-True "source archive created" ($LASTEXITCODE -eq 0)
    $archiveSha = (Get-FileHash -LiteralPath $tempArchive -Algorithm SHA256).Hash.ToLowerInvariant()
  } finally {
    if (Test-Path -LiteralPath $tempArchive) { Remove-Item -LiteralPath $tempArchive -Force }
  }
  Assert-True "archive SHA-256 computed ($archiveSha)" ($archiveSha -match "^[0-9a-f]{64}$")

  $workerDir = Join-Path $repoRoot "services/cloudflare-stateful-runtime"
  $wrangler  = Join-Path $workerDir "node_modules/wrangler/bin/wrangler.js"
  Assert-True "wrangler present" (Test-Path -LiteralPath $wrangler)

  $deployArgs = @(
    $wrangler, "deploy", "--env", "",
    "--var", "SOURCE_COMMIT_SHA:$resolved",
    "--var", "SOURCE_ARCHIVE_SHA256:$archiveSha"
  )
  if ($DryRun) { $deployArgs += @("--dry-run", "--outdir", (Join-Path ([System.IO.Path]::GetTempPath()) "worker-dryrun")) }

  Push-Location $workerDir
  try {
    & node @deployArgs
    Assert-True "wrangler deploy exit code 0" ($LASTEXITCODE -eq 0)
  } finally { Pop-Location }

  if ($DryRun) {
    Write-Host "[worker-deploy] dry-run complete; nothing was published"
    return
  }

  $health = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 `
    -Uri "https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev/api/v1/health").Content | ConvertFrom-Json
  Assert-True "hosted source_commit_sha rebound"    ([string]$health.source_commit_sha    -eq $resolved)
  Assert-True "hosted source_archive_sha256 rebound" ([string]$health.source_archive_sha256 -eq $archiveSha)
  Write-Host "[worker-deploy] hosted source binding verified against the live health payload"
} finally { Pop-Location }
