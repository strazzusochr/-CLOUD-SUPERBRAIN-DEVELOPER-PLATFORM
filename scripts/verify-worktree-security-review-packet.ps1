param(
  [string]$QuarantinePlanPath = ".phase1-artifacts\worktree-quarantine-plan-20260510.json",
  [string]$SecurityClearancePath = "docs\analysis\security-review-clearance-20260511.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-security-review-packet-20260511.json",
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

function Test-ClearedSecurityPath([object]$Clearance, [string]$Path) {
  if ($null -eq $Clearance) {
    return $false
  }

  $normalized = Convert-ToForwardSlash -Path $Path
  $match = @($Clearance.security_review_paths | Where-Object {
    (Convert-ToForwardSlash -Path ([string]$_.source_path)) -eq $normalized
  } | Select-Object -First 1)

  if ($match.Count -eq 0) {
    return $false
  }

  return (
    $match[0].approved_for_release_boundary -eq $true -and
    $match[0].no_high_confidence_secret_patterns -eq $true -and
    -not [string]::IsNullOrWhiteSpace([string]$match[0].disposition)
  )
}

function Invoke-SecurityProbe() {
  $scriptPath = Join-Path $PSScriptRoot "verify-security.ps1"
  if (-not (Test-Path -LiteralPath $scriptPath)) {
    return [pscustomobject]@{
      checked = $false
      status = "missing"
      passed = $false
      error = "verify-security.ps1 not found"
    }
  }

  try {
    $global:LASTEXITCODE = 0
    & $scriptPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "verify-security.ps1 exited with code $LASTEXITCODE"
    }
    return [pscustomobject]@{
      checked = $true
      status = "passed"
      passed = $true
      error = $null
    }
  } catch {
    return [pscustomobject]@{
      checked = $true
      status = "failed"
      passed = $false
      error = $_.Exception.Message
    }
  }
}

function New-ReviewItem([object]$Action) {
  return [pscustomobject]@{
    path = [string]$Action.path
    review_type = "security-review"
    required_review = "manual_secret_sensitive_diff_review"
    required_checks = @(
      "Inspect path-specific diff manually without copying secret values into artifacts.",
      "Run scripts\\verify.ps1 -Suite security after review.",
      "Confirm no token, private key, session cookie, project secret, or raw env value is introduced.",
      "Keep commit, push, deploy, and release blocked until all security-review paths are cleared."
    )
    content_included_in_artifact = $false
    may_stage_after_this_packet = $false
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-quarantine-plan.ps1" -OutputPath $QuarantinePlanPath

  $quarantinePlan = Read-JsonArtifact -Path $QuarantinePlanPath -Label "quarantine-plan"
  $securityActions = @($quarantinePlan.security_review_actions)
  $securityProbe = Invoke-SecurityProbe
  $securityClearance = Read-SecurityClearance -Path $SecurityClearancePath
  $findings = [System.Collections.Generic.List[object]]::new()

  if ([int]$quarantinePlan.counts.security_review -ne $securityActions.Count) {
    Add-Finding $findings "security_review_count" ([string]$quarantinePlan.counts.security_review) ([string]$securityActions.Count)
  }
  foreach ($action in $securityActions) {
    if ([string]$action.review_type -ne "security-review") {
      Add-Finding $findings "review_type:$($action.path)" "security-review" ([string]$action.review_type)
    }
    if ($action.content_included_in_artifact -ne $false) {
      Add-Finding $findings "content_included:$($action.path)" "false" ([string]$action.content_included_in_artifact)
    }
  }
  if ($securityProbe.passed -ne $true) {
    Add-Finding $findings "security_probe_passed" "true" ([string]$securityProbe.passed)
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
    if ([int]$securityClearance.checks.gitleaks_findings -ne 0) {
      Add-Finding $findings "security_clearance.gitleaks_findings" "0" ([string]$securityClearance.checks.gitleaks_findings)
    }
    if ([int]$securityClearance.checks.security_review_path_pattern_hits -ne 0) {
      Add-Finding $findings "security_clearance.security_review_path_pattern_hits" "0" ([string]$securityClearance.checks.security_review_path_pattern_hits)
    }
  }

  $reviewItems = @($securityActions | Where-Object {
    -not (Test-ClearedSecurityPath -Clearance $securityClearance -Path ([string]$_.path))
  } | ForEach-Object { New-ReviewItem -Action $_ })
  $valid = ($findings.Count -eq 0)
  $ready = ($valid -and $reviewItems.Count -eq 0)
  $status = if ($valid) {
    if ($ready) { "security-review-packet-clear" } else { "security-review-packet-valid-blocked" }
  } else {
    "security-review-packet-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $valid
    ready = $ready
    security_review_count = $reviewItems.Count
    finding_count = $findings.Count
    findings = @($findings)
    review_items = @($reviewItems)
    source_artifacts = [ordered]@{
      quarantine_plan = $QuarantinePlanPath
      security_clearance = $SecurityClearancePath
    }
    security_clearance = [ordered]@{
      present = ($null -ne $securityClearance)
      status = if ($null -ne $securityClearance) { [string]$securityClearance.status } else { $null }
    }
    security_probe = [ordered]@{
      checked = $securityProbe.checked
      status = $securityProbe.status
      passed = $securityProbe.passed
      error = $securityProbe.error
    }
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      file_contents_included = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
      required_next_action = if ($ready) {
        "Security-review path list is clear; rerun release-boundary."
      } else {
        "Review each listed path manually; do not copy secret values into any artifact."
      }
    }
    leak_prevention = [ordered]@{
      file_contents_included = $false
      secret_values_included = $false
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
    Write-Host "[worktree-security-review-packet] status=$($summary.status)"
    Write-Host "[worktree-security-review-packet] valid=$($summary.valid)"
    Write-Host "[worktree-security-review-packet] ready=$($summary.ready)"
    Write-Host "[worktree-security-review-packet] security_review_count=$($summary.security_review_count)"
    Write-Host "[worktree-security-review-packet] security_probe_passed=$($summary.security_probe.passed)"
    Write-Host "[worktree-security-review-packet] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[worktree-security-review-packet] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}
