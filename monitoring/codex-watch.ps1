param(
    [string]$Repo = 'D:/PLATTFORM/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
)

Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

Push-Location $Repo

$verify = Join-Path $Repo 'scripts/verify-phase5.ps1'
$log = Join-Path $Repo 'monitoring/watch.jsonl'
New-Item -Path (Split-Path $log) -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

$statusOutput = git status --short
$changes = @($statusOutput).Count
$ts = Get-Date -Format o

if ($changes -gt 0) {
    $stats = @{}
    foreach ($line in $statusOutput) {
        if ($line -match '^ (.+)$') {
            $path = $matches[1]
            $path = $path.Trim()
            if ([string]::IsNullOrWhiteSpace($path)) {
                continue
            }
            $ns = git -C $Repo diff --numstat -- "$path" 2>$null | Select-Object -First 1
            if ($ns) {
                $parts = $ns -split '\s+'
                if ($parts.Length -ge 3 -and [int]::TryParse($parts[0], $null) -and [int]::TryParse($parts[1], $null)) {
                    $add = [int]$parts[0]
                    $del = [int]$parts[1]
                    $stats[$path] = "+$add -$del"
                }
            }
        }
    }

    $vmsg = 'verifier_missing'
    if (Test-Path $verify) {
        $res = & powershell -NoProfile -ExecutionPolicy Bypass -File $verify 2>&1 | Out-String
        $res = $res.Trim()
        if (-not [string]::IsNullOrWhiteSpace($res)) {
            $vmsg = $res
        }
    }

    $entry = @{ Time = $ts; Changes = $changes; Stats = $stats; Verify = $vmsg } | ConvertTo-Json -Compress
    Add-Content -Path $log -Value $entry
    Write-Host "[$ts] CodeX check ran once with $changes change(s). No auto-repair loop."
} else {
    Write-Host "[$ts] No working-tree changes detected; nothing to do in this run."
}

Pop-Location
exit 0
