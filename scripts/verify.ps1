param(
  [string]$Suite,
  [switch]$List,
  [switch]$Plan,
  [switch]$FailFast,
  [switch]$RefreshSecretScans,
  [string]$BaseUrl,
  [string]$ReleaseId,
  [switch]$AllowLocalhost,
  [switch]$SeedMemoryConsolidation,
  [switch]$SafeProfile,
  [switch]$SkipPublicStreaming,
  [switch]$SkipOrchestratorStreaming,
  [switch]$SkipStreamingSections,
  [switch]$SkipLangGraphStress,
  [switch]$StopAfterCoreContracts,
  [switch]$StopAfterLlmGateway,
  [switch]$StopAfterMcpToolPaths,
  [switch]$StopAfterPublicDashboard,
  [switch]$StopAfterPublicStreaming,
  [switch]$StopAfterOrchestratorDryRun,
  [switch]$StopAfterPhase2Runtime,
  [int]$MaxWaitSeconds = 0,
  [int]$IntervalSeconds = 0,
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

$registryPath = Join-Path $PSScriptRoot "verify.suites.json"
if (-not (Test-Path $registryPath)) {
  throw "Missing suite registry: $registryPath"
}

$registry = Get-Content $registryPath -Raw | ConvertFrom-Json
$suiteIndex = @{}
foreach ($entry in $registry) {
  $suiteIndex[$entry.id] = $entry
}

function Get-DeclaredParameters([string]$ScriptPath) {
  $tokens = $null
  $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errors)
  $parameters = @{}
  if ($ast.ParamBlock) {
    foreach ($parameter in $ast.ParamBlock.Parameters) {
      $parameters[$parameter.Name.VariablePath.UserPath] = $true
    }
  }
  return $parameters
}

function Resolve-Suite([string]$SuiteId, [System.Collections.Generic.HashSet[string]]$Stack) {
  if (-not $suiteIndex.ContainsKey($SuiteId)) {
    throw "Unknown suite '$SuiteId'. Use -List to inspect the registry."
  }
  if ($Stack.Contains($SuiteId)) {
    throw "Suite registry cycle detected at '$SuiteId'."
  }

  $null = $Stack.Add($SuiteId)
  $entry = $suiteIndex[$SuiteId]
  $resolved = [System.Collections.Generic.List[object]]::new()

  if ($entry.PSObject.Properties.Name -contains "patterns") {
    foreach ($pattern in @($entry.patterns)) {
      $pathPattern = Join-Path $PSScriptRoot $pattern
      $matches = @(Get-ChildItem -Path $pathPattern -File | Sort-Object Name)
      if ($matches.Count -eq 0) {
        throw "Suite '$SuiteId' pattern '$pattern' resolved to no scripts."
      }
      foreach ($match in $matches) {
        $resolved.Add([pscustomobject]@{
          SuiteId = $SuiteId
          ScriptPath = $match.FullName
          ScriptName = $match.Name
          DefaultSwitches = @($entry.default_switches)
        })
      }
    }
  }

  if ($entry.PSObject.Properties.Name -contains "suites") {
    foreach ($childSuite in @($entry.suites)) {
      foreach ($child in Resolve-Suite -SuiteId $childSuite -Stack $Stack) {
        $resolved.Add($child)
      }
    }
  }

  $null = $Stack.Remove($SuiteId)
  return $resolved
}

function Get-UncoveredVerifierScripts() {
  if (-not $suiteIndex.ContainsKey("all")) {
    return @()
  }

  $registered = @{}
  foreach ($item in Resolve-Suite -SuiteId "all" -Stack ([System.Collections.Generic.HashSet[string]]::new())) {
    $registered[[System.IO.Path]::GetFullPath($item.ScriptPath)] = $true
  }

  $uncovered = @()
  foreach ($script in Get-ChildItem -Path (Join-Path $PSScriptRoot "verify-*.ps1") -File | Sort-Object Name) {
    $fullPath = [System.IO.Path]::GetFullPath($script.FullName)
    if (-not $registered.ContainsKey($fullPath)) {
      $uncovered += $script.Name
    }
  }

  return $uncovered
}

function Get-InvocationArgs([hashtable]$DeclaredParameters, [string[]]$DefaultSwitches = @()) {
  $arguments = [ordered]@{}
  $candidateValues = [ordered]@{
    BaseUrl = $BaseUrl
    HostedBaseUrl = $BaseUrl
    ReleaseId = $ReleaseId
    MaxWaitSeconds = $(if ($MaxWaitSeconds -gt 0) { $MaxWaitSeconds } else { $null })
    IntervalSeconds = $(if ($IntervalSeconds -gt 0) { $IntervalSeconds } else { $null })
  }
  foreach ($key in $candidateValues.Keys) {
    if ($DeclaredParameters.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace([string]$candidateValues[$key])) {
      $arguments[$key] = $candidateValues[$key]
    }
  }

  $candidateSwitches = [ordered]@{
    RefreshSecretScans = $RefreshSecretScans
    AllowLocalhost = $AllowLocalhost
    SeedMemoryConsolidation = $SeedMemoryConsolidation
    SafeProfile = $SafeProfile
    SkipPublicStreaming = $SkipPublicStreaming
    SkipOrchestratorStreaming = $SkipOrchestratorStreaming
    SkipStreamingSections = $SkipStreamingSections
    SkipLangGraphStress = $SkipLangGraphStress
    StopAfterCoreContracts = $StopAfterCoreContracts
    StopAfterLlmGateway = $StopAfterLlmGateway
    StopAfterMcpToolPaths = $StopAfterMcpToolPaths
    StopAfterPublicDashboard = $StopAfterPublicDashboard
    StopAfterPublicStreaming = $StopAfterPublicStreaming
    StopAfterOrchestratorDryRun = $StopAfterOrchestratorDryRun
    StopAfterPhase2Runtime = $StopAfterPhase2Runtime
    ReportOnly = $ReportOnly
    JsonOnly = $JsonOnly
  }
  foreach ($key in $candidateSwitches.Keys) {
    $isRequested = $candidateSwitches[$key].IsPresent -or ($DefaultSwitches -contains $key)
    if ($DeclaredParameters.ContainsKey($key) -and $isRequested) {
      $arguments[$key] = $true
    }
  }

  return $arguments
}

function Format-InvocationArgs([hashtable]$Arguments) {
  if ($Arguments.Count -eq 0) {
    return "(default parameters)"
  }

  $parts = @()
  foreach ($key in $Arguments.Keys) {
    $value = $Arguments[$key]
    if ($value -is [bool]) {
      $parts += "-$key"
    } else {
      $parts += "-$key"
      $parts += $value
    }
  }
  return ($parts -join " ")
}

if ($List) {
  foreach ($entry in $registry) {
    $mode = if ($entry.PSObject.Properties.Name -contains "patterns") { "patterns" } else { "suites" }
    $members = if ($mode -eq "patterns") { @($entry.patterns) } else { @($entry.suites) }
    Write-Host ("{0,-18} {1}" -f $entry.id, $entry.description)
    foreach ($member in $members) {
      Write-Host ("  - {0}" -f $member)
    }
  }
  $uncoveredScripts = @(Get-UncoveredVerifierScripts)
  if ($uncoveredScripts.Count -gt 0) {
    Write-Warning ("[verify-registry] uncovered scripts outside suite 'all': {0}" -f ($uncoveredScripts -join ", "))
  } else {
    Write-Host "[verify-registry] all verify-*.ps1 scripts are covered by suite 'all'"
  }
  return
}

if ([string]::IsNullOrWhiteSpace($Suite)) {
  throw "Missing -Suite. Use -List to inspect the registry."
}

$resolved = Resolve-Suite -SuiteId $Suite -Stack ([System.Collections.Generic.HashSet[string]]::new())
$seen = @{}
$scripts = [System.Collections.Generic.List[object]]::new()
foreach ($item in $resolved) {
  if (-not $seen.ContainsKey($item.ScriptPath)) {
    $seen[$item.ScriptPath] = $true
    $scripts.Add($item)
  }
}

if ($scripts.Count -eq 0) {
  throw "Suite '$Suite' resolved to no scripts."
}

if ($Plan) {
  Write-Host ("[verify-plan] suite={0} scripts={1}" -f $Suite, $scripts.Count)
  foreach ($script in $scripts) {
    $declaredParameters = Get-DeclaredParameters -ScriptPath $script.ScriptPath
    $invocationArgs = Get-InvocationArgs -DeclaredParameters $declaredParameters -DefaultSwitches $script.DefaultSwitches
    Write-Host ("[verify-plan] {0} {1}" -f $script.ScriptName, (Format-InvocationArgs -Arguments $invocationArgs))
  }
  return
}

$results = [System.Collections.Generic.List[object]]::new()
foreach ($script in $scripts) {
  $declaredParameters = Get-DeclaredParameters -ScriptPath $script.ScriptPath
  $invocationArgs = Get-InvocationArgs -DeclaredParameters $declaredParameters -DefaultSwitches $script.DefaultSwitches
  Write-Host ("[verify] running {0} {1}" -f $script.ScriptName, (Format-InvocationArgs -Arguments $invocationArgs))

  try {
    $global:LASTEXITCODE = 0
    & $script.ScriptPath @invocationArgs
    if ($LASTEXITCODE -ne 0) {
      throw "Verifier exited with code $LASTEXITCODE"
    }
    $results.Add([pscustomobject]@{
      Script = $script.ScriptName
      Status = "passed"
      Message = ""
    })
  } catch {
    $results.Add([pscustomobject]@{
      Script = $script.ScriptName
      Status = "failed"
      Message = $_.Exception.Message
    })
    if ($FailFast) {
      throw
    }
  }
}

$failed = @($results | Where-Object { $_.Status -eq "failed" })
Write-Host ("[verify] suite={0} scripts={1} failed={2}" -f $Suite, $results.Count, $failed.Count)
foreach ($result in $failed) {
  Write-Error ("{0}: {1}" -f $result.Script, $result.Message)
}
if ($failed.Count -gt 0) {
  exit 1
}
