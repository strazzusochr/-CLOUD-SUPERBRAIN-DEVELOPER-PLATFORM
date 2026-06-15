param(
  [string]$EnvFilePath = (Join-Path $HOME ".codex\secrets\cloud-superbrain.local.env"),
  [switch]$Overwrite,
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Set-ProcessEnvIfAllowed([string]$Name, [string]$Value, [bool]$AllowOverwrite) {
  if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Value)) {
    return $false
  }

  $existing = [Environment]::GetEnvironmentVariable($Name, "Process")
  if (-not [string]::IsNullOrWhiteSpace($existing) -and -not $AllowOverwrite) {
    return $false
  }

  [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
  return $true
}

function Read-EnvFile([string]$Path) {
  $values = @{}
  if (-not (Test-Path -LiteralPath $Path)) {
    return $values
  }

  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match "^\s*#") {
      continue
    }
    if ($line -match "^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$") {
      $name = $Matches[1]
      $value = $Matches[2].Trim()
      if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      $values[$name] = $value
    }
  }

  return $values
}

$loaded = [System.Collections.Generic.List[string]]::new()
$aliases = [System.Collections.Generic.List[string]]::new()
$values = Read-EnvFile -Path $EnvFilePath

foreach ($name in ($values.Keys | Sort-Object)) {
  if (Set-ProcessEnvIfAllowed -Name $name -Value ([string]$values[$name]) -AllowOverwrite ([bool]$Overwrite)) {
    $loaded.Add($name)
  }
}

$aliasPairs = @(
  @{ Source = "VERCEL_TEAM_ID"; Target = "VERCEL_ORG_ID" },
  @{ Source = "VERCEL_ORG_ID"; Target = "VERCEL_TEAM_ID" },
  @{ Source = "FLY_TOKEN"; Target = "FLY_API_TOKEN" },
  @{ Source = "GITHUB_TOKEN"; Target = "BRANCH_PROTECTION_TOKEN" }
)

foreach ($pair in $aliasPairs) {
  $source = [string]$pair.Source
  $target = [string]$pair.Target
  $sourceValue = [Environment]::GetEnvironmentVariable($source, "Process")
  $targetValue = [Environment]::GetEnvironmentVariable($target, "Process")
  if (-not [string]::IsNullOrWhiteSpace($sourceValue) -and ([string]::IsNullOrWhiteSpace($targetValue) -or $Overwrite)) {
    [Environment]::SetEnvironmentVariable($target, $sourceValue, "Process")
    $aliases.Add("$source->$target")
  }
}

if (-not $Quiet) {
  $status = if (Test-Path -LiteralPath $EnvFilePath) { "present" } else { "missing" }
  Write-Host "[import-local-env] env_file=$status"
  Write-Host "[import-local-env] loaded_keys=$($loaded.Count)"
  Write-Host "[import-local-env] alias_keys=$($aliases.Count)"
}
