param()

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  $text = ($value | Out-String)
  if (-not $text.Contains($expected)) {
    throw "Verification failed: $label did not contain '$expected'."
  }
}

$helperPath = "scripts\require-docker-readiness.ps1"
if (-not (Test-Path -LiteralPath $helperPath)) {
  throw "Missing Docker readiness guard helper: $helperPath"
}

$helper = Get-Content -LiteralPath $helperPath -Raw
foreach ($required in @(
  "verify-docker-readiness.ps1",
  "[BLOCKED]",
  "[SKIPPED-REASON: docker-unavailable]",
  "Docker readiness"
)) {
  Assert-Contains "Docker readiness guard helper" $helper $required
}

$guardedScripts = @(
  "scripts\verify-phase1-runtime.ps1",
  "scripts\verify-redis-persistence-phase1.ps1",
  "scripts\backup-postgres-phase1.ps1",
  "scripts\restore-postgres-phase1-proof.ps1",
  "scripts\measure-compose-resources.ps1",
  "scripts\build-and-push.ps1"
)

foreach ($script in $guardedScripts) {
  if (-not (Test-Path -LiteralPath $script)) {
    throw "Missing guarded Docker script: $script"
  }
  $content = Get-Content -LiteralPath $script -Raw
  Assert-Contains $script $content "require-docker-readiness.ps1"
}

Write-Host "[docker-readiness-guard] verified"
