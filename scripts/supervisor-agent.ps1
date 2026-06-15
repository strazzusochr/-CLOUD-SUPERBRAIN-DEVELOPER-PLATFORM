param(
  [ValidateSet("PrepushStrict", "PrepushDev")]
  [string]$Mode = "PrepushDev",
  [switch]$FailFast
)

$ErrorActionPreference = "Stop"

function Get-TimestampToken {
  return (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
}

function Invoke-PowerShellFile([string]$Path, [string[]]$Arguments = @()) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Path exited with code $LASTEXITCODE"
  }
}

function Resolve-WorkflowArgs([string]$ModeValue) {
  if ($ModeValue -eq "PrepushStrict") {
    return @()
  }
  return @("-AllowNonCandidateHead")
}

function Extract-ArtifactPath([string]$OutputText) {
  $text = ($OutputText | Out-String)
  $match = [regex]::Match($text, "artifact=([^\r\n]+)")
  if (-not $match.Success) {
    return ""
  }
  return $match.Groups[1].Value.Trim()
}

function Get-LatestWorkflowArtifactPath {
  $latest = Get-ChildItem -Path ".phase1-artifacts" -Filter "autonomous-release-workflow-*.json" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
  if ($null -eq $latest) {
    return ""
  }
  return $latest.FullName
}

function Invoke-Workflow([string[]]$Arguments, [switch]$PlanOnly) {
  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $before = Get-LatestWorkflowArtifactPath
    if ($PlanOnly.IsPresent) {
      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\run-autonomous-release-workflow.ps1" -PlanOnly @Arguments 2>&1
    } else {
      $output = & powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\run-autonomous-release-workflow.ps1" @Arguments 2>&1
    }
    $after = Get-LatestWorkflowArtifactPath
    $artifact = $after
    if (-not [string]::IsNullOrWhiteSpace($before) -and ($before -eq $after)) {
      $artifact = $after
    }
    return [ordered]@{
      exit_code = $LASTEXITCODE
      output = ($output | Out-String)
      artifact = $artifact
    }
  } finally {
    $ErrorActionPreference = $previous
  }
}

$artifactDirectory = ".phase1-artifacts"
New-Item -ItemType Directory -Force -Path $artifactDirectory | Out-Null
$supervisorReportPath = Join-Path $artifactDirectory ("supervisor-agent-report-{0}.json" -f (Get-TimestampToken))

$workflowArgs = Resolve-WorkflowArgs -ModeValue $Mode
if ($FailFast.IsPresent) {
  $workflowArgs += "-FailFast"
}

$planInvocation = Invoke-Workflow -Arguments $workflowArgs -PlanOnly
$planArtifact = $planInvocation.artifact

$runInvocation = Invoke-Workflow -Arguments $workflowArgs
$runExit = [int]$runInvocation.exit_code
$runArtifact = $runInvocation.artifact

$workflow = $null
if (-not [string]::IsNullOrWhiteSpace($runArtifact) -and (Test-Path -LiteralPath $runArtifact)) {
  $workflow = Get-Content -LiteralPath $runArtifact -Raw | ConvertFrom-Json
}

$summarySteps = @()
if ($null -ne $workflow -and $null -ne $workflow.steps) {
  foreach ($step in @($workflow.steps)) {
    $summarySteps += [ordered]@{
      id = $step.id
      status = $step.status
      message = $step.message
    }
  }
}

$report = [ordered]@{
  contract_version = "supervisor-agent-report-v1"
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  mode = $Mode
  workflow_exit_code = $runExit
  workflow_plan_artifact = $planArtifact
  workflow_artifact = $runArtifact
  workflow_status = $(if ($null -ne $workflow) { $workflow.status } else { "unknown" })
  release_boundary_blockers = $(if ($null -ne $workflow) { @($workflow.release_boundary_blockers) } else { @() })
  steps = $summarySteps
  non_claims = @(
    "This supervisor does not perform production deployment.",
    "This supervisor does not push to main/master.",
    "Hosted proof is not claimed unless a real HTTPS staging URL exists and hosted verifiers pass."
  )
}

if ($null -ne $workflow -and $workflow.PSObject.Properties.Name -contains "failure") {
  $report.failure = $workflow.failure
}

$report | ConvertTo-Json -Depth 8 | Set-Content -Path $supervisorReportPath -Encoding UTF8
Write-Host ("[supervisor-agent] report={0}" -f $supervisorReportPath)

if ($runExit -ne 0) {
  exit $runExit
}
