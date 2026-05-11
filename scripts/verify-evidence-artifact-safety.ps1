param(
  [string]$ArtifactRoot = ".phase1-artifacts",
  [string[]]$AdditionalArtifactRoots = @("docs"),
  [string]$OutputPath = ".phase1-artifacts\evidence-artifact-safety-20260510.json",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function New-SecretPattern([string]$Id, [string]$Regex) {
  return [pscustomobject]@{
    id = $Id
    regex = $Regex
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if (-not (Test-Path -LiteralPath $ArtifactRoot)) {
    throw "Missing artifact root: $ArtifactRoot"
  }

  $patterns = @(
    (New-SecretPattern "openai_api_key" "(?<![A-Za-z0-9])sk-(proj-)?[A-Za-z0-9_-]{20,}"),
    (New-SecretPattern "vercel_token" "vck_[A-Za-z0-9_-]{20,}"),
    (New-SecretPattern "github_token" "gh[pousr]_[A-Za-z0-9_]{20,}"),
    (New-SecretPattern "jwt_token" "eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}"),
    (New-SecretPattern "private_key_block" "-----BEGIN ([A-Z0-9 ]+ )?PRIVATE KEY-----"),
    (New-SecretPattern "sensitive_env_assignment" "(?i)(OPENAI_API_KEY|VERCEL_TOKEN|CLOUDFLARE_API_TOKEN|HCLOUD_TOKEN|GITHUB_TOKEN|HUGGINGFACE_TOKEN|HF_TOKEN)\s*[:=]\s*[`"']?[^`"',\s]{8,}")
  )

  $artifactFiles = @(
    Get-ChildItem -LiteralPath $ArtifactRoot -Filter "*.json" -File | Sort-Object FullName
    foreach ($additionalRoot in @($AdditionalArtifactRoots)) {
      if (Test-Path -LiteralPath $additionalRoot) {
        Get-ChildItem -LiteralPath $additionalRoot -Include "*.md", "*.json" -File -Recurse | Sort-Object FullName
      }
    }
  )
  $findings = [System.Collections.Generic.List[object]]::new()

  foreach ($file in $artifactFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($pattern in $patterns) {
      $matches = [regex]::Matches($content, $pattern.regex)
      if ($matches.Count -gt 0) {
        $findings.Add([pscustomobject]@{
          file = ($file.FullName.Substring($repoRoot.Length + 1) -replace '\\', '/')
          pattern_id = $pattern.id
          count = $matches.Count
          values_included = $false
        })
      }
    }
  }

  $safe = ($findings.Count -eq 0)
  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    artifact_root = $ArtifactRoot
    additional_artifact_roots = @($AdditionalArtifactRoots)
    status = if ($safe) { "safe" } else { "unsafe" }
    safe = $safe
    artifact_count = $artifactFiles.Count
    finding_count = $findings.Count
    findings = @($findings)
    leak_prevention = [ordered]@{
      finding_values_included = $false
      file_contents_included = $false
      secret_values_included = $false
      tokens_included = $false
      env_values_included = $false
    }
    policy = [ordered]@{
      mutates_repository = $false
      may_cleanup = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputParent = Split-Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
      New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
    }
    $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  }

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 6
  } else {
    Write-Host "[evidence-artifact-safety] status=$($summary.status)"
    Write-Host "[evidence-artifact-safety] artifact_count=$($summary.artifact_count)"
    Write-Host "[evidence-artifact-safety] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[evidence-artifact-safety] finding file={0} pattern={1} count={2} values_included=false" -f $finding.file, $finding.pattern_id, $finding.count)
    }
  }

  if (-not $safe -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}
