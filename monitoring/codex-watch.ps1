Set-StrictMode -Version Latest
$ErrorActionPreference='SilentlyContinue'
$repo = 'D:/PLATTFORM/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$verify = Join-Path $repo 'scripts/verify-phase5.ps1'
$logFile = Join-Path $repo 'monitoring/watch.jsonl'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  exit 2
}
New-Item -Path (Split-Path $logFile) -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
while ($true) {
  Push-Location $repo
  $statusOutput = git status --short
  Pop-Location
  $changes = @($statusOutput).Count
  if ($changes -gt 0) {
    $ts = Get-Date -Format o
    Write-Host "[$ts] CodeX: $changes uncommitted change(s)"
    $stats = @{}
    foreach ($line in $statusOutput) {
      if ($line -match '^ (.+)$') {
        $path = $matches[1]
        $ns = git -C $repo diff --numstat -- $path 2>$null | Select-Object -First 1
        if ($ns) {
          $parts = $ns -split '\s+'
          if ($parts.Length -ge 3) {
            $add = [int]$parts[0]
            $del = [int]$parts[1]
            $stats[$path] = "+$add -$del"
          }
        }
      }
    }
    if (Test-Path $verify) {
      $res = powershell -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Out-String
      $vmsg = $res.Trim()
    } else {
      $vmsg = 'verifier_missing'
    }
    $entry = @{ Time=$ts; Changes=$changes; Stats=$stats; Verify=$vmsg } | ConvertTo-Json -Compress
    Add-Content -Path $logFile -Value $entry
    if ($vmsg -match 'TRASH|OBVIOUS|LOOP') {
      Write-Host "[$ts] TRASH/LOOP suspected; calling watchdog auto-repair..."
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'scripts/auto-repair-codex.ps1')
    }
  }
  Start-Sleep -Seconds 10
}
