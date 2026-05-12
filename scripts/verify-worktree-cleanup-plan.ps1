param(
  [string]$InventoryPath = ".phase1-artifacts\worktree-change-inventory-20260510.json",
  [string]$SecurityClearancePath = "docs\analysis\security-review-clearance-20260511.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-cleanup-plan-20260510.json",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function New-Batch([int]$Order, [string]$Id, [string]$Action, [object[]]$Entries, [string]$Gate, [bool]$BlocksRelease = $true) {
  return [pscustomobject]@{
    order = $Order
    id = $Id
    action = $Action
    count = @($Entries).Count
    blocks_release = $BlocksRelease
    gate = $Gate
    paths = @($Entries | Select-Object -ExpandProperty path)
  }
}

function Convert-ToForwardSlash([string]$Path) {
  return ($Path -replace '\\', '/')
}

function Read-OptionalJsonArtifact([string]$Path) {
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
    $match[0].no_high_confidence_secret_patterns -eq $true
  )
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if (-not (Test-Path -LiteralPath $InventoryPath)) {
    & (Join-Path $PSScriptRoot "verify-worktree-change-inventory.ps1") -ReportOnly -OutputPath $InventoryPath | Out-Null
  }

  if (-not (Test-Path -LiteralPath $InventoryPath)) {
    throw "Missing worktree inventory artifact: $InventoryPath"
  }

  $inventory = Get-Content -LiteralPath $InventoryPath -Raw | ConvertFrom-Json
  $entries = @($inventory.entries)
  $securityClearance = Read-OptionalJsonArtifact -Path $SecurityClearancePath
  $allSecurityReview = @($entries | Where-Object { $_.review_tier -eq "security-review" })
  $securityReview = @($entries | Where-Object {
    $_.review_tier -eq "security-review" -and
    -not (Test-ClearedSecurityPath -Clearance $securityClearance -Path ([string]$_.path))
  })
  $clearedSecurityReviewCount = $allSecurityReview.Count - $securityReview.Count
  $quarantine = @($entries | Where-Object { $_.review_tier -eq "exclude-or-quarantine" })
  $splitRequired = @($entries | Where-Object { $_.review_tier -eq "split-required" })
  $verification = @($entries | Where-Object { $_.scope -eq "verification" -and $_.review_tier -ne "security-review" })
  $releaseArtifacts = @($entries | Where-Object { $_.scope -eq "release-artifacts" -and $_.review_tier -ne "security-review" })
  $runbooks = @($entries | Where-Object { $_.scope -eq "runbooks" -and $_.review_tier -ne "security-review" })
  $analysis = @($entries | Where-Object { $_.scope -eq "analysis" -and $_.review_tier -ne "security-review" })
  $runtime = @($entries | Where-Object { $_.review_tier -eq "runtime-review" })
  $senior = @($entries | Where-Object { $_.review_tier -eq "senior-review" })
  $standard = @($entries | Where-Object { $_.review_tier -eq "standard-review" })

  $batches = @(
    (New-Batch 1 "security-review" "manual secret-sensitive path review; do not stage until reviewed" $securityReview "security suite must remain clean after review")
    (New-Batch 2 "exclude-or-quarantine" "decide whether debug/extract/list scripts belong outside release scope" $quarantine "debug tooling must be excluded, quarantined, or explicitly accepted")
    (New-Batch 3 "split-required" "normalize staged-vs-worktree mismatch before any commit boundary" $splitRequired "no file may remain staged and modified")
    (New-Batch 4 "verification" "review verifier scripts as evidence tooling batch" $verification "registry coverage and targeted verifier runs must pass")
    (New-Batch 5 "release-artifacts" "review candidate and Phase-5 evidence artifacts" $releaseArtifacts "candidate verifier and release-readiness rerun must pass")
    (New-Batch 6 "runbooks" "review operational runbooks" $runbooks "runbook applicability checks must pass")
    (New-Batch 7 "analysis" "review handoff and truth-state docs" $analysis "docs must not claim release readiness without evidence")
    (New-Batch 8 "runtime-review" "review runtime code and frontend changes separately from evidence-only work" $runtime "runtime, hosted, browser, and security gates must pass before runtime rebaseline")
    (New-Batch 9 "senior-review" "review infra, operations, and security config changes" $senior "infra and operations changes require senior/operator review before deployment")
    (New-Batch 10 "standard-review" "review remaining governance/docs/other changes" $standard "remaining changes must be intentionally included or excluded")
  )

  $nonEmptyBatches = @($batches | Where-Object { $_.count -gt 0 })
  $blockingEntryCount = 0
  foreach ($batch in $nonEmptyBatches) {
    $blockingEntryCount += [int]$batch.count
  }
  $status = if ($entries.Count -eq 0) { "clean" } else { "cleanup-plan-blocked" }
  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    inventory_path = $InventoryPath
    security_clearance_path = $SecurityClearancePath
    security_clearance_present = ($null -ne $securityClearance)
    status = $status
    total_entries = [int]$inventory.total_entries
    blocking_entry_count = $blockingEntryCount
    cleared_security_review_count = $clearedSecurityReviewCount
    batch_count = $nonEmptyBatches.Count
    batches = $nonEmptyBatches
    recommended_strategy = if ($entries.Count -eq 0) { "none" } else { "cleanup-first-before-rebaseline" }
    release_blockers = @(
      "dirty_worktree",
      "staged_and_modified_files",
      "unreviewed_debug_tooling",
      "vercel_project_visibility_blocked",
      "candidate_owner_decision_no_release"
    )
    policy = [ordered]@{
      mutates_repository = $false
      may_delete = $false
      may_unstage = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      required_next_action = "Choose a cleanup/rebaseline strategy explicitly; this plan is not permission to mutate the repository."
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputParent = Split-Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
      New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  }

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 8
  } else {
    Write-Host "[worktree-cleanup-plan] status=$($summary.status)"
    Write-Host "[worktree-cleanup-plan] total_entries=$($summary.total_entries)"
    Write-Host "[worktree-cleanup-plan] batch_count=$($summary.batch_count)"
    foreach ($batch in $nonEmptyBatches) {
      Write-Host ("[worktree-cleanup-plan] batch={0} count={1} action={2}" -f $batch.id, $batch.count, $batch.action)
    }
  }

  if ($entries.Count -gt 0 -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}
