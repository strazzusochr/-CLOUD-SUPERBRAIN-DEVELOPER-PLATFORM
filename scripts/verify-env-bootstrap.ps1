param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactDir = Join-Path $repoRoot ".phase1-artifacts"
$envFile = Join-Path $artifactDir "env-bootstrap-test.local.env"
$importScript = Join-Path $PSScriptRoot "import-local-env.ps1"

if (-not (Test-Path -LiteralPath $importScript)) {
  throw "Missing env import helper: $importScript"
}

New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

$namesToRestore = @(
  "VERCEL_TEAM_ID",
  "VERCEL_ORG_ID",
  "FLY_TOKEN",
  "FLY_API_TOKEN",
  "GITHUB_TOKEN",
  "BRANCH_PROTECTION_TOKEN",
  "EXTRA_DUMMY",
  "QUOTED_VALUE"
)

$previousValues = @{}
foreach ($name in $namesToRestore) {
  $previousValues[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

function Assert-Equal([string]$Name, [string]$Actual, [string]$Expected) {
  if ($Actual -ne $Expected) {
    throw "$Name mismatch"
  }
}

function Assert-DoesNotContain([string]$Name, [string]$Haystack, [string]$Needle) {
  if ($Haystack.Contains($Needle)) {
    throw "$Name leaked a secret-like value"
  }
}

try {
  foreach ($name in $namesToRestore) {
    [Environment]::SetEnvironmentVariable($name, $null, "Process")
  }

  [Environment]::SetEnvironmentVariable("VERCEL_ORG_ID", "preexisting_org_dummy", "Process")

  @(
    "VERCEL_TEAM_ID=team_dummy_123",
    "FLY_TOKEN=fly_dummy_secret",
    "GITHUB_TOKEN=github_dummy_secret",
    "EXTRA_DUMMY=extra_value",
    "QUOTED_VALUE=`"quoted dummy value`""
  ) | Set-Content -LiteralPath $envFile -Encoding UTF8

  $output = (& $importScript -EnvFilePath $envFile 2>&1 | Out-String)

  Assert-Equal "VERCEL_TEAM_ID" ([Environment]::GetEnvironmentVariable("VERCEL_TEAM_ID", "Process")) "team_dummy_123"
  Assert-Equal "VERCEL_ORG_ID no-overwrite" ([Environment]::GetEnvironmentVariable("VERCEL_ORG_ID", "Process")) "preexisting_org_dummy"
  Assert-Equal "FLY_TOKEN" ([Environment]::GetEnvironmentVariable("FLY_TOKEN", "Process")) "fly_dummy_secret"
  Assert-Equal "FLY_API_TOKEN alias" ([Environment]::GetEnvironmentVariable("FLY_API_TOKEN", "Process")) "fly_dummy_secret"
  Assert-Equal "GITHUB_TOKEN" ([Environment]::GetEnvironmentVariable("GITHUB_TOKEN", "Process")) "github_dummy_secret"
  Assert-Equal "BRANCH_PROTECTION_TOKEN alias" ([Environment]::GetEnvironmentVariable("BRANCH_PROTECTION_TOKEN", "Process")) "github_dummy_secret"
  Assert-Equal "QUOTED_VALUE" ([Environment]::GetEnvironmentVariable("QUOTED_VALUE", "Process")) "quoted dummy value"

  foreach ($secretLikeValue in @("team_dummy_123", "fly_dummy_secret", "github_dummy_secret", "extra_value", "quoted dummy value")) {
    Assert-DoesNotContain "import-local-env output" $output $secretLikeValue
  }

  & $importScript -EnvFilePath $envFile -Quiet -Overwrite
  Assert-Equal "VERCEL_ORG_ID overwrite alias" ([Environment]::GetEnvironmentVariable("VERCEL_ORG_ID", "Process")) "team_dummy_123"

  Write-Host "[env-bootstrap] verified"
} finally {
  Remove-Item -LiteralPath $envFile -Force -ErrorAction SilentlyContinue
  foreach ($name in $namesToRestore) {
    [Environment]::SetEnvironmentVariable($name, $previousValues[$name], "Process")
  }
}

