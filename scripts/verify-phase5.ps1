Set-StrictMode -Version Latest
$ErrorActionPreference='SilentlyContinue'
$score=100
$msg='CLEAN'
$count=(git diff --name-only | Where-Object { $_ -match '^(node_modules|\.next|\.cache|dist)/' } | Measure-Object).Count
if ($count -gt 40) { $score -= 50; $msg = "TRASH|OBVIOUS (too many dirty files)" }
Write-Output "score=$score msg=$msg dirty_files=$count"
exit (if($msg -match 'TRASH|OBVIOUS'){1}else{0})
