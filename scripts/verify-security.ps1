param(
  [string]$DetectSecretsPackagePath = "D:\PLATTFORM\.tools\detect-secrets-pkg",
  [string]$BaselinePath,
  [string]$GitleaksReportPath,
  [switch]$RefreshSecretScans
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Security verification failed: $label"
  }
}

function Assert-LastExitCode($label) {
  if ($LASTEXITCODE -ne 0) {
    throw "Security verification failed: $label"
  }
}

function Get-PythonLauncher() {
  $pyCommand = Get-Command py -ErrorAction SilentlyContinue
  if ($pyCommand) {
    return @($pyCommand.Source, "-3")
  }

  $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
  if ($pythonCommand) {
    return @($pythonCommand.Source)
  }

  throw "Security verification failed: Python launcher not found. Install Python or ensure 'py' or 'python' is on PATH."
}

function Invoke-PythonFile([string]$ScriptPath, [string]$WorkingDirectory, [string]$Label) {
  $launcher = Get-PythonLauncher
  Push-Location $WorkingDirectory
  try {
    if ($launcher.Count -gt 1) {
      & $launcher[0] $launcher[1] $ScriptPath
    } else {
      & $launcher[0] $ScriptPath
    }
    Assert-LastExitCode $Label
  } finally {
    Pop-Location
  }
}

function Test-IgnoredSecretScanPath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $false
  }

  return $Path -match '(^|[\\/])(\.git|\.tools|node_modules|dist|build|coverage|\.next|out|\.phase1-artifacts|debug-artifacts|secrets|\.venv|venv|\.cache|\.tmp|tmp|playwright-report|test-results|screenshots|\.playwright-mcp)([\\/]|$)|(\.secrets\.baseline|\.tsbuildinfo)$|\.(png|jpe?g|gif|webp|ico|woff2?|ttf|map|pyc|zip|7z|gz|pdf|mp4|mov|avi)$'
}

function Read-GitleaksFindings([string]$ReportPath) {
  if (-not (Test-Path $ReportPath)) {
    return @()
  }

  $raw = Get-Content $ReportPath -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return @()
  }

  $parsed = $raw | ConvertFrom-Json
  if ($null -eq $parsed) {
    return @()
  }
  if ($parsed -is [System.Array]) {
    return @($parsed)
  }
  if ($parsed.PSObject.Properties.Name -contains "findings") {
    return @($parsed.findings)
  }
  return @($parsed)
}

function Get-GitleaksFindingPath($Finding) {
  foreach ($propertyName in @("File", "file", "Path", "path", "Filename", "filename")) {
    if ($Finding.PSObject.Properties.Name -contains $propertyName) {
      $value = [string]$Finding.$propertyName
      if (-not [string]::IsNullOrWhiteSpace($value)) {
        return $value
      }
    }
  }

  return ""
}

$repoRoot = Split-Path $PSScriptRoot -Parent
if ([string]::IsNullOrWhiteSpace($GitleaksReportPath)) {
  $GitleaksReportPath = Join-Path $repoRoot ".tools\secret-scans\gitleaks.json"
}
if ([string]::IsNullOrWhiteSpace($BaselinePath)) {
  $BaselinePath = Join-Path $repoRoot ".secrets.baseline"
}

$shouldRefresh = $RefreshSecretScans -or -not (Test-Path $GitleaksReportPath) -or -not (Test-Path $BaselinePath)
if ($shouldRefresh) {
  & (Join-Path $PSScriptRoot "run-secret-scans.ps1") `
    -DetectSecretsPackagePath $DetectSecretsPackagePath `
    -RepoRoot $repoRoot `
    -BaselinePath $BaselinePath `
    -GitleaksReportPath $GitleaksReportPath
  Assert-LastExitCode "run-secret-scans"
}

Assert-True "gitleaks report exists" (Test-Path $GitleaksReportPath)
Assert-True "detect-secrets baseline exists" (Test-Path $BaselinePath)

$gitleaksFindings = @(Read-GitleaksFindings -ReportPath $GitleaksReportPath)
$actionableGitleaksFindings = @(
  $gitleaksFindings |
    Where-Object {
      $findingPath = Get-GitleaksFindingPath $_
      -not (Test-IgnoredSecretScanPath -Path $findingPath)
    }
)
Assert-True "gitleaks report contains findings" ($actionableGitleaksFindings.Count -eq 0)

$baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json
$baselineItems = @()
if ($baseline -and $baseline.results) {
  foreach ($property in $baseline.results.PSObject.Properties) {
    if (Test-IgnoredSecretScanPath -Path ([string]$property.Name)) {
      continue
    }
    $baselineItems += [pscustomobject]@{
      Path = $property.Name
      Count = @($property.Value).Count
    }
  }
}
$baselineFindingCount = ($baselineItems | Measure-Object -Property Count -Sum).Sum
if ($null -eq $baselineFindingCount) {
  $baselineFindingCount = 0
}

Write-Host "[verify-security] gitleaks findings: $($actionableGitleaksFindings.Count)"
if ($gitleaksFindings.Count -ne $actionableGitleaksFindings.Count) {
  Write-Host "[verify-security] gitleaks ignored findings: $($gitleaksFindings.Count - $actionableGitleaksFindings.Count)"
}
Write-Host "[verify-security] detect-secrets files: $($baselineItems.Count)"
Write-Host "[verify-security] detect-secrets findings: $baselineFindingCount"
foreach ($item in ($baselineItems | Sort-Object @{ Expression = "Count"; Descending = $true }, Path | Select-Object -First 10)) {
  Write-Host ("[verify-security] baseline hotspot {0}x {1}" -f $item.Count, $item.Path)
}

Invoke-PythonFile -ScriptPath (Join-Path $PSScriptRoot "secret_scan_fallback.py") -WorkingDirectory $repoRoot -Label "fallback secret scan"

Write-Host "[verify-security] verified"
