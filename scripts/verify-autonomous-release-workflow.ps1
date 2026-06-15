$ErrorActionPreference = "Stop"

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Verification failed: $Label did not contain '$Expected'."
  }
}

$scriptPath = "scripts\run-autonomous-release-workflow.ps1"
if (-not (Test-Path -LiteralPath $scriptPath)) {
  throw "Missing autonomous release workflow script: $scriptPath"
}

$content = Get-Content -LiteralPath $scriptPath -Raw
foreach ($required in @(
  "autonomous-release-workflow-v1",
  "verify-worktree-release-boundary.ps1",
  "verify.ps1",
  "release-boundary",
  "release-boundary-regression",
  "npm run build",
  "npm run test:e2e --prefix apps/frontend",
  "npm run verify",
  "npm run verify:runtime",
  "npm run verify:browser",
  "npm run verify:external-gates",
  "release-candidate",
  "git push",
  "main",
  "master",
  "HostedBaseUrl",
  "PlanOnly",
  "AllowNonCandidateHead",
  "Push was not requested"
)) {
  Assert-Contains "workflow script" $content $required
}

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_.Message }
  throw "Autonomous release workflow script has parser errors"
}

$planOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -PlanOnly -HostedBaseUrl "https://staging.example.invalid" -AllowNonCandidateHead 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "PlanOnly run for autonomous release workflow failed"
}

Assert-Contains "workflow plan output" $planOutput "[autonomous-release-workflow] status=passed"
Assert-Contains "workflow plan output" $planOutput "artifact="

Write-Host "[verify-autonomous-release-workflow] checks completed"
