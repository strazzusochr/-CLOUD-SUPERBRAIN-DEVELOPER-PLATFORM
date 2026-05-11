param(
  [string]$OutputPath = ".phase1-artifacts\worktree-change-inventory-20260510.json",
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Convert-GitStatusLine([string]$Line) {
  if ([string]::IsNullOrWhiteSpace($Line) -or $Line.Length -lt 3) {
    return $null
  }

  $indexStatus = $Line.Substring(0, 1)
  $worktreeStatus = $Line.Substring(1, 1)
  $path = $Line.Substring(3) -replace '\\', '/'
  $staged = ($indexStatus -ne " " -and $indexStatus -ne "?")
  $unstaged = ($worktreeStatus -ne " " -and $worktreeStatus -ne "?")
  $untracked = ($indexStatus -eq "?" -and $worktreeStatus -eq "?")

  $state = "unknown"
  if ($untracked) {
    $state = "untracked"
  } elseif ($staged -and $unstaged) {
    $state = "staged_and_modified"
  } elseif ($staged) {
    $state = "staged_only"
  } elseif ($unstaged) {
    $state = "unstaged_only"
  }

  return [pscustomobject]@{
    raw = $Line
    index_status = $indexStatus
    worktree_status = $worktreeStatus
    path = $path
    state = $state
    staged = $staged
    unstaged = $unstaged
    untracked = $untracked
    staged_and_modified = ($staged -and $unstaged)
  }
}

function Get-ChangeScope([string]$Path) {
  $p = $Path -replace '\\', '/'
  if ($p -match '^apps/frontend/') { return "frontend" }
  if ($p -match '^services/agent-api/') { return "agent-api" }
  if ($p -match '^services/agent-worker/') { return "agent-worker" }
  if ($p -match '^services/llm-gateway/') { return "llm-gateway" }
  if ($p -match '^services/mcp-gateway/') { return "mcp-gateway" }
  if ($p -match '^(docker-compose|infrastructure/|provision_|staging\.env\.template)') { return "infrastructure" }
  if ($p -match '^scripts/(verify-|manual/verify-)') { return "verification" }
  if ($p -match '^scripts/(deploy|build|backup|restore|measure|import|run-secret|check_|generate_|add_)') { return "operations" }
  if ($p -match '^scripts/(debug_|list_|extract_|scan_|test_)') { return "debug-tooling" }
  if ($p -match '^docs/release-artifacts/') { return "release-artifacts" }
  if ($p -match '^docs/runbooks/') { return "runbooks" }
  if ($p -match '^docs/analysis/') { return "analysis" }
  if ($p -match '^docs/') { return "docs" }
  if ($p -match '^(\.gitignore|\.gitleaks\.toml|\.gitattributes)$') { return "security-config" }
  if ($p -match '^(AGENTS\.md|AI_HANDOFF\.md|PROJECT_|CODEX_|SUPERBRAIN_)') { return "governance" }
  return "other"
}

function Get-ReviewTier([string]$Path, [string]$Scope, [string]$State) {
  if ($Path -match '(?i)(token|secret|password|credential|vercel_storage|hetzner_.*\.(json|png|html)|\.local\.env|\.secrets\.baseline)') {
    return "security-review"
  }
  if ($State -eq "staged_and_modified") {
    return "split-required"
  }
  if ($Scope -in @("infrastructure", "operations", "security-config")) {
    return "senior-review"
  }
  if ($Scope -in @("agent-api", "agent-worker", "llm-gateway", "mcp-gateway", "frontend")) {
    return "runtime-review"
  }
  if ($Scope -in @("verification", "release-artifacts", "runbooks", "analysis")) {
    return "evidence-review"
  }
  if ($Scope -eq "debug-tooling") {
    return "exclude-or-quarantine"
  }
  return "standard-review"
}

function Group-Count($Items, [string]$PropertyName) {
  $rows = @()
  foreach ($group in ($Items | Group-Object -Property $PropertyName | Sort-Object Name)) {
    $rows += [pscustomobject]@{
      name = [string]$group.Name
      count = [int]$group.Count
    }
  }
  return @($rows)
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  $statusLines = @(git status --porcelain=v1)
  $entries = @()
  foreach ($line in $statusLines) {
    $entry = Convert-GitStatusLine -Line $line
    if ($null -ne $entry) {
      $scope = Get-ChangeScope -Path $entry.path
      $reviewTier = Get-ReviewTier -Path $entry.path -Scope $scope -State $entry.state
      $entries += [pscustomobject]@{
        path = $entry.path
        state = $entry.state
        index_status = $entry.index_status
        worktree_status = $entry.worktree_status
        scope = $scope
        review_tier = $reviewTier
        staged = $entry.staged
        unstaged = $entry.unstaged
        untracked = $entry.untracked
        staged_and_modified = $entry.staged_and_modified
      }
    }
  }

  $tierCounts = Group-Count -Items $entries -PropertyName "review_tier"
  $scopeCounts = Group-Count -Items $entries -PropertyName "scope"
  $stateCounts = Group-Count -Items $entries -PropertyName "state"
  $securityReview = @($entries | Where-Object { $_.review_tier -eq "security-review" })
  $splitRequired = @($entries | Where-Object { $_.review_tier -eq "split-required" })
  $quarantine = @($entries | Where-Object { $_.review_tier -eq "exclude-or-quarantine" })

  $status = if ($entries.Count -eq 0) { "clean" } else { "inventory-blocked" }
  $summary = [ordered]@{
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo = $repoRoot
    status = $status
    total_entries = $entries.Count
    state_counts = $stateCounts
    scope_counts = $scopeCounts
    review_tier_counts = $tierCounts
    split_required_paths = @($splitRequired | Select-Object -ExpandProperty path)
    security_review_paths = @($securityReview | Select-Object -ExpandProperty path)
    quarantine_paths = @($quarantine | Select-Object -ExpandProperty path)
    recommended_batch_order = @(
      "security-review",
      "exclude-or-quarantine",
      "split-required",
      "verification",
      "runbooks",
      "analysis",
      "release-artifacts",
      "runtime-review",
      "infrastructure",
      "operations",
      "governance"
    )
    policy = [ordered]@{
      mutates_repository = $false
      may_stage = $false
      may_commit = $false
      may_deploy = $false
      required_next_action = "Use this inventory to choose an explicit cleanup or rebaseline strategy before staging, committing, pushing, or deploying."
    }
    entries = @($entries)
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
    Write-Host "[worktree-change-inventory] status=$($summary.status)"
    Write-Host "[worktree-change-inventory] total_entries=$($summary.total_entries)"
    Write-Host "[worktree-change-inventory] state_counts=$(($stateCounts | ForEach-Object { "$($_.name):$($_.count)" }) -join ',')"
    Write-Host "[worktree-change-inventory] scope_counts=$(($scopeCounts | ForEach-Object { "$($_.name):$($_.count)" }) -join ',')"
    Write-Host "[worktree-change-inventory] review_tier_counts=$(($tierCounts | ForEach-Object { "$($_.name):$($_.count)" }) -join ',')"
    Write-Host "[worktree-change-inventory] split_required=$($splitRequired.Count); security_review=$($securityReview.Count); quarantine=$($quarantine.Count)"
  }

  if ($entries.Count -gt 0 -and -not $ReportOnly) {
    exit 1
  }
} finally {
  Pop-Location
}
