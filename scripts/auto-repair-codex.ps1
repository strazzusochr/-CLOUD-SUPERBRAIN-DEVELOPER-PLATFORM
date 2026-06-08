param([string]$Repo='D:/PLATTFORM/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM')
Set-StrictMode -Version Latest
$ErrorActionPreference='SilentlyContinue'
Push-Location $Repo
git checkout -- AGENTS.md 2>$null
git checkout -- PROJECT_STATE.md 2>$null
git checkout -- AI_HANDOFF.md 2>$null
$log=Join-Path $Repo 'monitoring/watch.jsonl'
Add-Content -Path $log -Value (@{time=(Get-Date -Format o); event='REPAIR'; repo=$Repo} | ConvertTo-Json -Compress)
Pop-Location
Write-Output 'auto-repair executed'
