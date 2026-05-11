param(
  [string]$CleanupPlanPath = ".phase1-artifacts\worktree-cleanup-plan-20260510.json",
  [string]$OutputPath = ".phase1-artifacts\worktree-review-action-matrix-20260511.json",
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

function Get-OwnerRole([string]$BatchId) {
  switch ($BatchId) {
    "security-review" { "security-owner" }
    "exclude-or-quarantine" { "repository-owner" }
    "split-required" { "release-owner" }
    "verification" { "verification-owner" }
    "release-artifacts" { "release-owner" }
    "runbooks" { "operations-owner" }
    "analysis" { "truth-state-owner" }
    "runtime-review" { "runtime-owner" }
    "senior-review" { "senior-operator" }
    "standard-review" { "repository-owner" }
    default { "repository-owner" }
  }
}

function New-BatchAction([object]$Batch) {
  $paths = @($Batch.paths | ForEach-Object { Convert-ToForwardSlash -Path ([string]$_) })
  return [pscustomobject]@{
    order = [int]$Batch.order
    batch_id = [string]$Batch.id
    owner_role = Get-OwnerRole -BatchId ([string]$Batch.id)
    action = [string]$Batch.action
    gate = [string]$Batch.gate
    path_count = $paths.Count
    blocks_release = ($Batch.blocks_release -eq $true)
    required_owner_decision = "include, exclude, quarantine, split, or rebaseline this batch before release scope changes"
    verification_gate = [string]$Batch.gate
    paths = $paths
    executable_by_this_gate = $false
    mutates_repository = $false
    file_contents_included = $false
    diff_contents_included = $false
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Invoke-DependencyVerifier -ScriptName "verify-worktree-cleanup-plan.ps1" -OutputPath $CleanupPlanPath

  $cleanupPlan = Read-JsonArtifact -Path $CleanupPlanPath -Label "cleanup-plan"
  $batches = @($cleanupPlan.batches)
  $batchIds = @($batches | Select-Object -ExpandProperty id)
  $findings = [System.Collections.Generic.List[object]]::new()
  $requiredBatchIds = @(
    "verification",
    "release-artifacts",
    "runbooks",
    "analysis",
    "runtime-review",
    "senior-review",
    "standard-review"
  )
  if ($batchIds -contains "split-required") {
    $requiredBatchIds += "split-required"
  }
  if ($batchIds -contains "exclude-or-quarantine") {
    $requiredBatchIds += "exclude-or-quarantine"
  }
  if ($batchIds -contains "security-review") {
    $requiredBatchIds += "security-review"
  }

  if ([int]$cleanupPlan.batch_count -ne $batches.Count) {
    Add-Finding $findings "batch_count" ([string]$cleanupPlan.batch_count) ([string]$batches.Count)
  }

  foreach ($required in $requiredBatchIds) {
    if ($batchIds -notcontains $required) {
      Add-Finding $findings "missing_batch:$required" "present" "missing"
    }
  }

  $uniquePaths = [System.Collections.Generic.SortedSet[string]]::new()
  $batchPathReferenceCount = 0
  foreach ($batch in $batches) {
    $paths = @($batch.paths)
    if ([int]$batch.count -ne $paths.Count) {
      Add-Finding $findings "batch_path_count:$($batch.id)" ([string]$batch.count) ([string]$paths.Count)
    }
    if ([string]::IsNullOrWhiteSpace([string]$batch.gate)) {
      Add-Finding $findings "batch_gate:$($batch.id)" "non-empty" "empty"
    }
    foreach ($pathItem in $paths) {
      $path = Convert-ToForwardSlash -Path ([string]$pathItem)
      $batchPathReferenceCount++
      if ([string]::IsNullOrWhiteSpace($path)) {
        Add-Finding $findings "path_empty:$($batch.id)" "non-empty" "empty"
      } elseif ($path -like "../*" -or $path -like "*/../*" -or $path -like "*..\\*") {
        Add-Finding $findings "path_traversal:$($batch.id)" "no parent traversal" $path
      } else {
        [void]$uniquePaths.Add($path)
      }
    }
  }

  $expectedUniquePathCount = if ($null -ne $cleanupPlan.PSObject.Properties["blocking_entry_count"]) {
    [int]$cleanupPlan.blocking_entry_count
  } else {
    [int]$cleanupPlan.total_entries
  }
  if ($expectedUniquePathCount -ne $uniquePaths.Count) {
    Add-Finding $findings "unique_path_count" ([string]$expectedUniquePathCount) ([string]$uniquePaths.Count)
  }
  foreach ($flag in @("mutates_repository", "may_delete", "may_unstage", "may_stage", "may_commit", "may_push", "may_deploy")) {
    if ($cleanupPlan.policy.$flag -ne $false) {
      Add-Finding $findings "policy.$flag" "false" ([string]$cleanupPlan.policy.$flag)
    }
  }

  $batchActions = @($batches | Sort-Object order | ForEach-Object { New-BatchAction -Batch $_ })
  $valid = ($findings.Count -eq 0)
  $ready = ($valid -and $uniquePaths.Count -eq 0)
  $status = if ($valid) {
    if ($ready) { "review-action-matrix-clear" } else { "review-action-matrix-valid-blocked" }
  } else {
    "review-action-matrix-invalid"
  }

  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    valid = $valid
    ready = $ready
    batch_count = $batchActions.Count
    unique_path_count = $uniquePaths.Count
    batch_path_reference_count = $batchPathReferenceCount
    duplicate_reference_count = ($batchPathReferenceCount - $uniquePaths.Count)
    finding_count = $findings.Count
    findings = @($findings)
    batch_actions = @($batchActions)
    source_artifacts = [ordered]@{
      cleanup_plan = $CleanupPlanPath
    }
    policy = [ordered]@{
      mutates_repository = $false
      executes_requested_actions = $false
      may_delete = $false
      may_unstage = $false
      may_stage = $false
      may_commit = $false
      may_push = $false
      may_deploy = $false
      may_release = $false
      required_next_action = if ($ready) {
        "Review matrix is clear; rerun release-boundary."
      } else {
        "Owner must resolve each non-empty review batch before cleanup, staging, commit, push, deploy, or release."
      }
    }
    leak_prevention = [ordered]@{
      file_contents_included = $false
      diff_contents_included = $false
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
    Write-Host "[worktree-review-action-matrix] status=$($summary.status)"
    Write-Host "[worktree-review-action-matrix] valid=$($summary.valid)"
    Write-Host "[worktree-review-action-matrix] ready=$($summary.ready)"
    Write-Host "[worktree-review-action-matrix] batch_count=$($summary.batch_count)"
    Write-Host "[worktree-review-action-matrix] unique_path_count=$($summary.unique_path_count)"
    Write-Host "[worktree-review-action-matrix] batch_path_reference_count=$($summary.batch_path_reference_count)"
    Write-Host "[worktree-review-action-matrix] finding_count=$($summary.finding_count)"
    foreach ($finding in @($findings)) {
      Write-Host ("[worktree-review-action-matrix] finding={0} expected={1} actual={2}" -f $finding.id, $finding.expected, $finding.actual)
    }
  }

  if (-not $valid -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}
