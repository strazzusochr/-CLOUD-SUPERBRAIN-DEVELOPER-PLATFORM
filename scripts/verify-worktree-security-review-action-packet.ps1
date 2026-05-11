param(
  [string]$SecurityReviewPacketPath = ".phase1-artifacts\worktree-security-review-packet-20260511.json",
  [string]$BaselinePath = ".secrets.baseline",
  [string]$SecurityClearancePath = "docs\analysis\security-review-clearance-20260511.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-security-review-action-packet-20260511.json",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Invoke-DependencyVerifier([string]$ScriptName, [string]$OutputPath) {
  if (Test-Path -LiteralPath $OutputPath) {
    return
  }

  $scriptPath = Join-Path $PSScriptRoot $ScriptName
  if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Missing dependency verifier: $ScriptName"
  }

  & $scriptPath -ReportOnly -OutputPath $OutputPath | Out-Null
}

function Read-JsonArtifact([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing $Label artifact: $Path"
  }

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Add-Finding([System.Collections.Generic.List[object]]$Findings, [string]$Id, [string]$Expected, [string]$Actual) {
  $Findings.Add([pscustomobject]@{
    id = $Id
    expected = $Expected
    actual = $Actual
  })
}

function Convert-ToForwardSlash([string]$Path) {
  return ($Path -replace '\\', '/')
}

function Read-SecurityClearance([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }

  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Test-ClearedBaselineHotspot([object]$Clearance, [string]$Path, [int]$FindingCount) {
  if ($null -eq $Clearance) {
    return $false
  }

  $normalized = Convert-ToForwardSlash -Path $Path
  $match = @($Clearance.baseline_hotspots | Where-Object {
    (Convert-ToForwardSlash -Path ([string]$_.source_path)) -eq $normalized
  } | Select-Object -First 1)

  if ($match.Count -eq 0) {
    return $false
  }

  return (
    $match[0].approved_for_release_boundary -eq $true -and
    [int]$match[0].finding_count -eq $FindingCount -and
    -not [string]::IsNullOrWhiteSpace([string]$match[0].disposition)
  )
}

function Test-IgnoredSecretScanPath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $false
  }

  return $Path -match '(^|[\\/])(\.git|\.tools|node_modules|dist|build|coverage|\.next|out|\.phase1-artifacts|debug-artifacts|secrets|\.venv|venv|\.cache|\.tmp|tmp|playwright-report|test-results|screenshots|\.playwright-mcp)([\\/]|$)|(\.secrets\.baseline|\.tsbuildinfo)$|\.(png|jpe?g|gif|webp|ico|woff2?|ttf|map|pyc|zip|7z|gz|pdf|mp4|mov|avi)$'
}

function Get-BaselineHotspots([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    return @()
  }

  $baseline = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  if ($null -eq $baseline -or $null -eq $baseline.results) {
    return @()
  }

  $items = @()
  foreach ($property in $baseline.results.PSObject.Properties) {
    if (Test-IgnoredSecretScanPath -Path ([string]$property.Name)) {
      continue
    }

    $items += [pscustomobject]@{
      path = Convert-ToForwardSlash -Path ([string]$property.Name)
      finding_count = @($property.Value).Count
    }
  }

  return @($items | Sort-Object path)
}

function New-OwnerAction([object]$Item) {
  $path = Convert-ToForwardSlash -Path ([string]$Item.path)
  return [pscustomobject]@{
    id = "security-clearance-required:$path"
    kind = "owner_security_review_required"
    source_path = $path
    required_review = "manual_secret_sensitive_diff_review"
    required_clearance = "Owner must confirm no token, private key, session cookie, project secret, raw env value, credential path leak, or cloud account identifier requiring redaction is introduced."
    required_checks = @($Item.required_checks)
    verification_gate = "scripts\\verify.ps1 -Suite security must pass after review; release-boundary must still pass in ReportOnly mode."
    may_stage_after_this_packet = $false
    executable_by_this_gate = $false
    mutates_repository = $false
    file_contents_included = $false
    diff_contents_included = $false
  }
}

function New-BaselineHotspotReviewItem([object]$Item) {
  $path = Convert-ToForwardSlash -Path ([string]$Item.path)
  return [pscustomobject]@{
    id = "detect-secrets-hotspot-review-required:$path"
    kind = "detect_secrets_baseline_hotspot_review_required"
    source_path = $path
    finding_count = [int]$Item.finding_count
    required_review = "manual_detect_secrets_baseline_hotspot_review"
    required_clearance = "Owner must inspect the path-specific detect-secrets finding without copying secret values into artifacts, then mark it as resolved or accepted false-positive before staging or release scope changes."
    verification_gate = "scripts\\verify.ps1 -Suite security must pass after review; security-review action packet must keep baseline_hotspot_count at 0 before clearance."
    may_stage_after_this_packet = $false
    executable_by_this_gate = $false
    mutates_repository = $false
    file_contents_included = $false
    diff_contents_included = $false
    secret_values_included = $false
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-security-review-packet.ps1" -OutputPath $SecurityReviewPacketPath

  $securityPacket = Read-JsonArtifact -Path $SecurityReviewPacketPath -Label "security-review-packet"
  $reviewItems = @($securityPacket.review_items)
  $baselineHotspots = @(Get-BaselineHotspots -Path $BaselinePath)
  $securityClearance = Read-SecurityClearance -Path $SecurityClearancePath
  $findings = [System.Collections.Generic.List[object]]::new()

  if ($securityPacket.valid -ne $true) {
    Add-Finding $findings "security_review_packet_valid" "true" ([string]$securityPacket.valid)
  }
  if ($securityPacket.security_probe.passed -ne $true) {
    Add-Finding $findings "security_probe_passed" "true" ([string]$securityPacket.security_probe.passed)
  }
  if ([int]$securityPacket.security_review_count -ne $reviewItems.Count) {
    Add-Finding $findings "security_review_count" ([string]$securityPacket.security_review_count) ([string]$reviewItems.Count)
  }
  if ($null -ne $securityClearance) {
    if ([string]$securityClearance.status -ne "security-clearance-approved") {
      Add-Finding $findings "security_clearance.status" "security-clearance-approved" ([string]$securityClearance.status)
    }
    foreach ($flag in @("raw_secret_values_included", "secret_values_included", "diff_contents_included", "file_contents_included")) {
      if ($securityClearance.$flag -ne $false) {
        Add-Finding $findings "security_clearance.$flag" "false" ([string]$securityClearance.$flag)
      }
    }
    if ([int]$securityClearance.checks.baseline_hotspot_pattern_hits -ne 0) {
      Add-Finding $findings "security_clearance.baseline_hotspot_pattern_hits" "0" ([string]$securityClearance.checks.baseline_hotspot_pattern_hits)
    }
  }

  foreach ($item in $reviewItems) {
    $path = Convert-ToForwardSlash -Path ([string]$item.path)

    if ([string]::IsNullOrWhiteSpace($path)) {
      Add-Finding $findings "path_empty" "non-empty" "empty"
    }
    if ($path -like "../*" -or $path -like "*/../*" -or $path -like "*..\\*") {
      Add-Finding $findings "path_traversal:$path" "no parent traversal" $path
    }
    if ([string]$item.review_type -ne "security-review") {
      Add-Finding $findings "review_type:$path" "security-review" ([string]$item.review_type)
    }
    if ([string]$item.required_review -ne "manual_secret_sensitive_diff_review") {
      Add-Finding $findings "required_review:$path" "manual_secret_sensitive_diff_review" ([string]$item.required_review)
    }
    if ($item.content_included_in_artifact -ne $false) {
      Add-Finding $findings "content_included_in_artifact:$path" "false" ([string]$item.content_included_in_artifact)
    }
    if ($item.may_stage_after_this_packet -ne $false) {
      Add-Finding $findings "may_stage_after_this_packet:$path" "false" ([string]$item.may_stage_after_this_packet)
    }
    if (@($item.required_checks).Count -lt 4) {
      Add-Finding $findings "required_checks:$path" ">=4" ([string]@($item.required_checks).Count)
    }
  }

  if (-not (Test-Path -LiteralPath $BaselinePath)) {
    Add-Finding $findings "detect_secrets_baseline" "exists" $BaselinePath
  }

  foreach ($hotspot in $baselineHotspots) {
    $path = Convert-ToForwardSlash -Path ([string]$hotspot.path)
    if ([string]::IsNullOrWhiteSpace($path)) {
      Add-Finding $findings "baseline_hotspot_path_empty" "non-empty" "empty"
    }
    if ([int]$hotspot.finding_count -lt 1) {
      Add-Finding $findings "baseline_hotspot_count:$path" ">=1" ([string]$hotspot.finding_count)
    }
  }

  $ownerActions = @()
  if ($reviewItems.Count -gt 0) {
    $ownerActions = @($reviewItems | ForEach-Object { New-OwnerAction -Item $_ })
  }

  $unclearedBaselineHotspots = @($baselineHotspots | Where-Object {
    -not (Test-ClearedBaselineHotspot -Clearance $securityClearance -Path ([string]$_.path) -FindingCount ([int]$_.finding_count))
  })
  $baselineHotspotReviewItems = @()
  if ($unclearedBaselineHotspots.Count -gt 0) {
    $baselineHotspotReviewItems = @($unclearedBaselineHotspots | ForEach-Object { New-BaselineHotspotReviewItem -Item $_ })
  }
  $baselineHotspotFindingCount = 0
  foreach ($hotspot in $baselineHotspotReviewItems) {
    $baselineHotspotFindingCount += [int]$hotspot.finding_count
  }
  $valid = ($findings.Count -eq 0)
  $ready = ($valid -and $ownerActions.Count -eq 0 -and $baselineHotspotReviewItems.Count -eq 0)
  $status = if ($valid) {
    if ($ready) { "security-review-action-packet-clear" } else { "security-review-action-packet-valid-blocked" }
  } else {
    "security-review-action-packet-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $valid
    ready = $ready
    action_count = $ownerActions.Count
    baseline_hotspot_count = $baselineHotspotReviewItems.Count
    baseline_hotspot_finding_count = $baselineHotspotFindingCount
    finding_count = $findings.Count
    findings = @($findings)
    owner_actions = @($ownerActions)
    baseline_hotspot_review_items = @($baselineHotspotReviewItems)
    source_artifacts = [ordered]@{
      security_review_packet = $SecurityReviewPacketPath
      detect_secrets_baseline = $BaselinePath
      security_clearance = $SecurityClearancePath
    }
    security_clearance = [ordered]@{
      present = ($null -ne $securityClearance)
      status = if ($null -ne $securityClearance) { [string]$securityClearance.status } else { $null }
    }
    security_probe = [ordered]@{
      status = $securityPacket.security_probe.status
      passed = $securityPacket.security_probe.passed
    }
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
      required_next_action = if ($ready) {
        "Security-review action list is clear; rerun release-boundary."
      } else {
        "Owner must manually clear every security-review path and detect-secrets baseline hotspot before staging or committing it."
      }
    }
    leak_prevention = [ordered]@{
      file_contents_included = $false
      diff_contents_included = $false
      secret_values_included = $false
      detect_secrets_values_included = $false
      tokens_included = $false
      env_values_included = $false
      path_only_artifact = $true
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputParent = Split-Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
      New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
    }
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  }

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 10
  } else {
    Write-Host "[worktree-security-review-action-packet] status=$($summary.status)"
    Write-Host "[worktree-security-review-action-packet] valid=$($summary.valid)"
    Write-Host "[worktree-security-review-action-packet] ready=$($summary.ready)"
    Write-Host "[worktree-security-review-action-packet] action_count=$($summary.action_count)"
    Write-Host "[worktree-security-review-action-packet] baseline_hotspot_count=$($summary.baseline_hotspot_count)"
    Write-Host "[worktree-security-review-action-packet] baseline_hotspot_finding_count=$($summary.baseline_hotspot_finding_count)"
    Write-Host "[worktree-security-review-action-packet] security_probe_passed=$($summary.security_probe.passed)"
    Write-Host "[worktree-security-review-action-packet] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[worktree-security-review-action-packet] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}
