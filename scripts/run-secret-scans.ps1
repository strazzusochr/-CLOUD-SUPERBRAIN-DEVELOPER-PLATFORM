param(
  [string]$DetectSecretsPackagePath = "D:\PLATTFORM\.tools\detect-secrets-pkg",
  [string]$RepoRoot,
  [string]$BaselinePath,
  [string]$GitleaksReportPath,
  [switch]$SkipDetectSecrets,
  [switch]$SkipGitleaks
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $RepoRoot = Split-Path $PSScriptRoot -Parent
}
$repoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
if ([string]::IsNullOrWhiteSpace($BaselinePath)) {
  $BaselinePath = Join-Path $repoRoot ".secrets.baseline"
}
if ([string]::IsNullOrWhiteSpace($GitleaksReportPath)) {
  $GitleaksReportPath = Join-Path $repoRoot ".tools\secret-scans\gitleaks.json"
}

$secretScanDir = Split-Path $GitleaksReportPath -Parent
if (-not (Test-Path $secretScanDir)) {
  New-Item -ItemType Directory -Path $secretScanDir -Force | Out-Null
}

$excludeFilesRegex = '(^|[\\/])(\.git|\.tools|node_modules|dist|build|coverage|\.next|out|\.phase1-artifacts|debug-artifacts|secrets|\.venv|venv|\.cache|\.tmp|tmp|playwright-report|test-results|screenshots|\.playwright-mcp)([\\/]|$)|(\.secrets\.baseline|\.tsbuildinfo)$|\.(png|jpe?g|gif|webp|ico|woff2?|ttf|map|pyc|zip|7z|gz|pdf|mp4|mov|avi)$'

function Assert-LastExitCode($label) {
  if ($LASTEXITCODE -ne 0) {
    throw "$label failed with exit code $LASTEXITCODE"
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

  throw "Python launcher not found. Install Python or ensure 'py' or 'python' is on PATH."
}

function Invoke-PythonStdinScript([string]$ScriptText, [string]$WorkingDirectory, [string]$Label) {
  $launcher = Get-PythonLauncher
  Push-Location $WorkingDirectory
  try {
    if ($launcher.Count -gt 1) {
      $ScriptText | & $launcher[0] $launcher[1] -
    } else {
      $ScriptText | & $launcher[0] -
    }
    Assert-LastExitCode $Label
  } finally {
    Pop-Location
  }
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

function Get-BaselineFindingCount([string]$Path) {
  if (-not (Test-Path $Path)) {
    return 0
  }
  $baseline = Get-Content $Path -Raw | ConvertFrom-Json
  $count = 0
  foreach ($property in $baseline.results.PSObject.Properties) {
    $count += @($property.Value).Count
  }
  return $count
}

function Get-GitleaksFindingCount([string]$Path) {
  if (-not (Test-Path $Path)) {
    return 0
  }
  $raw = Get-Content $Path -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return 0
  }
  $parsed = $raw | ConvertFrom-Json
  if ($null -eq $parsed) {
    return 0
  }
  if ($parsed -is [System.Array]) {
    return @($parsed).Count
  }
  if ($parsed.PSObject.Properties.Name -contains "findings") {
    return @($parsed.findings).Count
  }
  return 1
}

if (-not $SkipDetectSecrets) {
  if (-not (Test-Path $DetectSecretsPackagePath)) {
    throw "detect-secrets package path not found: $DetectSecretsPackagePath"
  }

  $baselineScript = @"
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, r'$DetectSecretsPackagePath')

from detect_secrets.core.baseline import format_for_output
from detect_secrets.core.scan import get_files_to_scan
from detect_secrets.core.secrets_collection import SecretsCollection
from detect_secrets.settings import default_settings

exclude = re.compile(r'''$excludeFilesRegex''')
out_path = Path(r'$BaselinePath')
root = Path(r'$repoRoot')

with default_settings():
    secrets = SecretsCollection(root='')
    for filename in get_files_to_scan('.', should_scan_all_files=True, root=''):
        normalized = filename.replace('\\\\', '/')
        if exclude.search(normalized):
            continue
        try:
            secrets.scan_file(filename)
        except Exception:
            continue
    out_path.write_text(json.dumps(format_for_output(secrets), indent=2) + '\n', encoding='utf-8')
    results = secrets.json()
    count = sum(len(v) for v in results.values())
    print(f'[secret-scans] detect-secrets files: {len(results)}')
    print(f'[secret-scans] detect-secrets findings: {count}')
"@

  Invoke-PythonStdinScript -ScriptText $baselineScript -WorkingDirectory $repoRoot -Label "detect-secrets baseline generation"

  Write-Host "[secret-scans] detect-secrets baseline: $BaselinePath"
  Write-Host "[secret-scans] detect-secrets findings: $(Get-BaselineFindingCount -Path $BaselinePath)"
}

if (-not $SkipGitleaks) {
  $gitleaksCommand = Get-Command gitleaks -ErrorAction SilentlyContinue
  if ($gitleaksCommand) {
    & $gitleaksCommand.Source detect --no-banner --no-git --redact --report-format json --report-path $GitleaksReportPath --source $repoRoot
    if ($LASTEXITCODE -gt 1) {
      throw "gitleaks execution failed with exit code $LASTEXITCODE"
    }
    Write-Host "[secret-scans] gitleaks report: $GitleaksReportPath"
    Write-Host "[secret-scans] gitleaks findings: $(Get-GitleaksFindingCount -Path $GitleaksReportPath)"
  } elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    $gitleaksReportDir = Split-Path $GitleaksReportPath -Parent
    $repoMount = $repoRoot -replace '\\', '/'
    $reportMount = ([System.IO.Path]::GetFullPath($gitleaksReportDir)) -replace '\\', '/'
    & docker run --rm -v "${repoMount}:/repo" -v "${reportMount}:/out" zricethezav/gitleaks:latest detect --source=/repo --config=/repo/.gitleaks.toml --no-banner --redact --report-format json --report-path=/out/gitleaks.json
    if ($LASTEXITCODE -gt 1) {
      throw "dockerized gitleaks execution failed with exit code $LASTEXITCODE"
    }
    Write-Host "[secret-scans] gitleaks report: $GitleaksReportPath"
    Write-Host "[secret-scans] gitleaks findings: $(Get-GitleaksFindingCount -Path $GitleaksReportPath)"
  } else {
    if (-not (Test-Path $GitleaksReportPath)) {
      '[]' | Set-Content -Path $GitleaksReportPath -Encoding UTF8
    }
    Write-Warning "gitleaks is not installed. Reusing cached report at $GitleaksReportPath"
  }
}

Invoke-PythonFile -ScriptPath (Join-Path $PSScriptRoot "secret_scan_fallback.py") -WorkingDirectory $repoRoot -Label "fallback secret scan"

Write-Host "[secret-scans] completed"
