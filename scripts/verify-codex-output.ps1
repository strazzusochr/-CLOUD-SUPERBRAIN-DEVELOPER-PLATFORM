param(
  [string]$Repo = 'D:/PLATTFORM/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='SilentlyContinue'
Push-Location $Repo
$score = 100
$msg = "CLEAN"
$trash = git diff --name-only | Where-Object { $_ -match '^(node_modules|\.next|\.cache|\.git|dist)/' } | Measure-Object
$count = 0
if($trash){ $count = $trash.Count }
if ($count -gt 40){ $score -= 50; $msg = "TRASH|OBVIOUS (too many dirty files)" }
if ($score -lt 80){ $msg = "TRASH|OBVIOUS (score=$score)" }
$out = "score=$score msg=$msg dirty_files=$count"
Pop-Location
Write-Output $out
if ($msg -match 'TRASH|OBVIOUS') { exit 1 } else { exit 0 }
