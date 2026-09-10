#Requires -Version 7.0

$ErrorActionPreference = 'Stop'
$targetScript = Join-Path $PSScriptRoot 'owner-set-cloudflare-token.ps1'

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

function ConvertTo-SingleQuotedLiteral([string]$Value) {
  return $Value.Replace("'", "''")
}

Assert-True (Test-Path -LiteralPath $targetScript -PathType Leaf) 'Owner token helper is missing.'
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
  $targetScript,
  [ref]$null,
  [ref]$parseErrors
)
Assert-True (@($parseErrors).Count -eq 0) 'Owner token helper has PowerShell parse errors.'

$shortFunctions = @(
  $ast.FindAll(
    { param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] },
    $true
  ) | Where-Object { $_.Name.Length -le 2 }
)
Assert-True ($shortFunctions.Count -eq 0) 'Owner token helper contains a one- or two-character function name.'

$source = Get-Content -Raw -LiteralPath $targetScript
foreach ($required in @(
  'CLOUDFLARE_API_TOKEN_CANDIDATE',
  'Resolve-ApprovedSecretFile',
  'Assert-NoReparseSecretPath',
  'Test-ResultShape',
  'Invoke-SanitizedGet',
  'Write-CandidateAtomically',
  'Remove-SupersededTokenRollbacks',
  'Assert-TokenFileHash',
  '[IO.File]::Replace',
  '[IO.SearchOption]::TopDirectoryOnly',
  '[IO.FileAttributes]::ReparsePoint',
  'cloud-superbrain.local.env',
  '-Method GET',
  '-SkipHttpErrorCheck',
  'permission_or_account_scope',
  'rate_limited',
  'provider_failure',
  'transport_failure',
  'unexpected_response',
  'Edit-Rechte bleiben unbewiesen.',
  'finally {',
  'Set-Clipboard -Value',
  'exit 2'
)) {
  Assert-True $source.Contains($required) "Owner token helper is missing guard: $required"
}
foreach ($forbidden in @(
  '-Method POST',
  '-Method PUT',
  '-Method PATCH',
  '-Method DELETE',
  'Invoke-RestMethod',
  'Write-Host $plain',
  'Write-Output $plain',
  'Write-Error $plain',
  'throw $plain',
  'Write-Host $headers',
  'Write-Output $headers',
  'Remove-Item -Recurse',
  '$env:TEMP =',
  '$env:TMP ='
)) {
  Assert-True (-not $source.Contains($forbidden)) "Owner token helper contains forbidden marker: $forbidden"
}

$testRoot = Join-Path 'D:\_sb_tmp' ('owner-token-verifier-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$scenarioCount = 0

function Invoke-SyntheticScenario(
  [string]$Name,
  [string]$Mode,
  [bool]$ExpectSuccess,
  [bool]$ExpectCandidateWrite,
  [string]$Profile = 'Full',
  [bool]$UseCurlEnvelope = $true,
  [bool]$InitialCandidateMatches = $false,
  [bool]$InitialMainMatches = $false,
  [bool]$InvalidAccount = $false,
  [bool]$AllowTestPath = $true,
  [int]$InitialRollbackCount = 0,
  [bool]$ExpectRetentionFailure = $false
) {
  $script:scenarioCount += 1
  $scenarioRoot = Join-Path $testRoot $Name
  [IO.Directory]::CreateDirectory($scenarioRoot) | Out-Null
  $secretFile = Join-Path $scenarioRoot 'cloud-superbrain.local.env'
  $clipboardMarker = Join-Path $scenarioRoot 'clipboard-cleared.txt'
  $syntheticAccountId = if ($InvalidAccount) { 'z' * 32 } else { 'a' * 32 }
  $oldSyntheticToken = if ($InitialMainMatches) { 'N' * 40 } else { 'O' * 40 }
  $newSyntheticToken = 'N' * 40
  $beforeLines = @(
    "CLOUDFLARE_ACCOUNT_ID=$syntheticAccountId"
    "CLOUDFLARE_API_TOKEN=$oldSyntheticToken"
  )
  if ($InitialCandidateMatches) {
    $beforeLines += "CLOUDFLARE_API_TOKEN_CANDIDATE=$newSyntheticToken"
  }
  $before = ($beforeLines -join "`n") + "`n"
  [IO.File]::WriteAllText($secretFile, $before, [Text.UTF8Encoding]::new($false))
  $initialRollbackPaths = @(
    for ($index = 0; $index -lt $InitialRollbackCount; $index += 1) {
      $qualifier = if ($index % 2 -eq 0) { 'qualified-' } else { '' }
      $rollbackPath = Join-Path $scenarioRoot (
        'cloud-superbrain.local.env.rollback-' +
        $qualifier +
        ('20000101-00000{0}-{1}' -f $index, ('a' * 8))
      )
      [IO.File]::WriteAllText($rollbackPath, $before, [Text.UTF8Encoding]::new($false))
      $rollbackPath
    }
  )

  $wrapper = @'
$ErrorActionPreference = 'Stop'
$global:SyntheticScenarioMode = '__MODE__'
$global:SyntheticClipboardMarker = '__CLIPBOARD_MARKER__'
$global:SyntheticUseCurlEnvelope = __USE_CURL__
$global:SyntheticRetentionHashFailure = __RETENTION_HASH_FAILURE__

function global:Get-Clipboard {
  param([switch]$Raw)
  $syntheticToken = 'N' * 40
  if ($global:SyntheticUseCurlEnvelope) {
    return 'curl -H "Authorization: Bearer ' + $syntheticToken + '" https://api.cloudflare.com/client/v4/user/tokens/verify'
  }
  return $syntheticToken
}

function global:Set-Clipboard {
  param([object]$Value)
  [IO.File]::WriteAllText($global:SyntheticClipboardMarker, 'cleared', [Text.UTF8Encoding]::new($false))
}

function global:Get-FileHash {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$LiteralPath,
    [string]$Algorithm
  )
  $actual = Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath $LiteralPath -Algorithm $Algorithm
  if ($global:SyntheticRetentionHashFailure -and $LiteralPath -like '*.rollback-*') {
    return [pscustomobject]@{ Hash = ('0' * 64) }
  }
  return $actual
}

function global:Invoke-WebRequest {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [hashtable]$Headers,
    [string]$Method,
    [int]$TimeoutSec,
    [switch]$SkipHttpErrorCheck
  )
  if ($Method -ne 'GET') { throw 'synthetic_non_get_request' }
  $expectedHeader = 'Bearer ' + ('N' * 40)
  if ([string]$Headers.Authorization -ne $expectedHeader) { throw 'synthetic_bad_authorization_header' }

  $isUserVerify = $Uri.EndsWith('/user/tokens/verify')
  $isAccountVerify = $Uri -match '/accounts/[A-Fa-f0-9]{32}/tokens/verify$'
  $isVerify = $isUserVerify -or $isAccountVerify
  $isQueue = $Uri.EndsWith('/queues')

  if ($global:SyntheticScenarioMode -eq 'timeout' -and $isQueue) {
    throw 'synthetic_transport_failure'
  }
  if ($global:SyntheticScenarioMode -eq 'invalid' -and $isVerify) {
    return [pscustomobject]@{
      StatusCode = 403
      Content = '{"success":false,"errors":[{"code":9106}],"result":{"id":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","status":"disabled"}}'
    }
  }
  if ($global:SyntheticScenarioMode -eq 'account-token' -and $isUserVerify) {
    return [pscustomobject]@{
      StatusCode = 403
      Content = '{"success":false,"errors":[{"code":9106}],"result":{"id":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","status":"disabled"}}'
    }
  }
  if ($global:SyntheticScenarioMode -eq 'disabled' -and $isUserVerify) {
    return [pscustomobject]@{
      StatusCode = 200
      Content = '{"success":true,"errors":[],"result":{"id":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","status":"disabled"}}'
    }
  }
  if ($global:SyntheticScenarioMode -eq 'partial' -and $isQueue) {
    return [pscustomobject]@{
      StatusCode = 403
      Content = '{"success":false,"errors":[{"code":10000}],"result":[]}'
    }
  }
  if ($global:SyntheticScenarioMode -eq 'http500' -and $isQueue) {
    return [pscustomobject]@{
      StatusCode = 500
      Content = '{"success":true,"errors":[],"result":[]}'
    }
  }
  if ($global:SyntheticScenarioMode -eq 'string-false' -and $isQueue) {
    return [pscustomobject]@{
      StatusCode = 200
      Content = '{"success":"false","errors":[],"result":[]}'
    }
  }
  if ($global:SyntheticScenarioMode -eq 'bad-shape' -and $isQueue) {
    return [pscustomobject]@{
      StatusCode = 200
      Content = '{"success":true,"errors":[],"result":{}}'
    }
  }
  if ($global:SyntheticScenarioMode -eq 'malformed' -and $isQueue) {
    return [pscustomobject]@{
      StatusCode = 200
      Content = 'not-json'
    }
  }
  if ($global:SyntheticScenarioMode -eq 'rate-limited' -and $isQueue) {
    return [pscustomobject]@{
      StatusCode = 429
      Content = '{"success":false,"errors":[{"code":1015}],"result":[]}'
    }
  }
  if ($isVerify) {
    return [pscustomobject]@{
      StatusCode = 200
      Content = '{"success":true,"errors":[],"result":{"id":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","status":"active"}}'
    }
  }
  if ($Uri.EndsWith('/r2/buckets')) {
    return [pscustomobject]@{
      StatusCode = 200
      Content = '{"success":true,"errors":[],"result":{"buckets":[]}}'
    }
  }
  return [pscustomobject]@{
    StatusCode = 200
    Content = '{"success":true,"errors":[],"result":[]}'
  }
}

& '__TARGET_SCRIPT__' -SecretFile '__SECRET_FILE__' -FromClipboard -Profile '__PROFILE__' __ALLOW_TEST__
'@

  $wrapper = $wrapper.
    Replace('__MODE__', (ConvertTo-SingleQuotedLiteral $Mode)).
    Replace('__CLIPBOARD_MARKER__', (ConvertTo-SingleQuotedLiteral $clipboardMarker)).
    Replace('__USE_CURL__', $(if ($UseCurlEnvelope) { '$true' } else { '$false' })).
    Replace('__RETENTION_HASH_FAILURE__', $(if ($ExpectRetentionFailure) { '$true' } else { '$false' })).
    Replace('__TARGET_SCRIPT__', (ConvertTo-SingleQuotedLiteral $targetScript)).
    Replace('__SECRET_FILE__', (ConvertTo-SingleQuotedLiteral $secretFile)).
    Replace('__PROFILE__', (ConvertTo-SingleQuotedLiteral $Profile)).
    Replace('__ALLOW_TEST__', $(if ($AllowTestPath) { '-AllowTestSecretPath' } else { '' }))

  $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($wrapper))
  $output = (& pwsh -NoProfile -EncodedCommand $encoded 2>&1 3>&1 4>&1 5>&1 6>&1 | Out-String)
  $exitCode = $LASTEXITCODE
  $safeOutput = $output.
    Replace($oldSyntheticToken, '[stored-token-redacted]').
    Replace($newSyntheticToken, '[candidate-token-redacted]').
    Replace($syntheticAccountId, '[account-id-redacted]').
    Trim()

  if ($ExpectSuccess) {
    Assert-True ($exitCode -eq 0) "$Name expected success actual=$exitCode output=$safeOutput"
  } else {
    Assert-True ($exitCode -ne 0) "$Name expected failure but exited zero."
  }
  Assert-True (-not $output.Contains($oldSyntheticToken)) "$Name exposed the stored synthetic token."
  Assert-True (-not $output.Contains($newSyntheticToken)) "$Name exposed the candidate synthetic token."
  Assert-True (-not $output.Contains($syntheticAccountId)) "$Name exposed the synthetic account identifier."
  if ($UseCurlEnvelope -and -not $InvalidAccount -and $AllowTestPath) {
    Assert-True $output.Contains('reinen Token mit') "$Name did not extract the Bearer token from the curl envelope."
  }

  $after = [IO.File]::ReadAllText($secretFile)
  $rollbacks = @(Get-ChildItem -LiteralPath $scenarioRoot -Filter 'cloud-superbrain.local.env.rollback-*')
  $candidateTemps = @(Get-ChildItem -LiteralPath $scenarioRoot -Filter 'cloud-superbrain.local.env.candidate-*')
  Assert-True ($candidateTemps.Count -eq 0) "$Name left a plaintext candidate temporary file."

  if ($ExpectRetentionFailure) {
    Assert-True ($after.Contains("CLOUDFLARE_API_TOKEN=$oldSyntheticToken")) "$Name changed the active token during the failed retention check."
    Assert-True ($after.Contains("CLOUDFLARE_API_TOKEN_CANDIDATE=$newSyntheticToken")) "$Name did not finish the atomic candidate write before the retention check."
    foreach ($initialRollbackPath in $initialRollbackPaths) {
      Assert-True (Test-Path -LiteralPath $initialRollbackPath -PathType Leaf) "$Name deleted an old rollback before hash verification completed."
    }
    Assert-True ($rollbacks.Count -eq ($InitialRollbackCount + 1)) "$Name retention failure did not preserve every rollback."
  } elseif ($ExpectCandidateWrite) {
    Assert-True ($after.Contains("CLOUDFLARE_API_TOKEN=$oldSyntheticToken")) "$Name changed the active token."
    Assert-True ($after.Contains("CLOUDFLARE_API_TOKEN_CANDIDATE=$newSyntheticToken")) "$Name did not stage the candidate."
    Assert-True ($rollbacks.Count -eq 1) "$Name did not retain exactly the newest verified rollback."
    Assert-True $output.Contains('Edit-Rechte bleiben unbewiesen.') "$Name overclaimed Edit readiness."
  } else {
    Assert-True ($after -eq $before) "$Name changed the secret file despite a non-write outcome."
    Assert-True ($rollbacks.Count -eq $InitialRollbackCount) "$Name changed rollback retention despite a non-write outcome."
  }

  $clipboardWasRead = $AllowTestPath -and -not $InvalidAccount
  if ($clipboardWasRead) {
    Assert-True (Test-Path -LiteralPath $clipboardMarker) "$Name did not clear the clipboard."
  } else {
    Assert-True (-not (Test-Path -LiteralPath $clipboardMarker)) "$Name touched the clipboard before path/account validation."
  }
  return $safeOutput
}

Invoke-SyntheticScenario -Name 'full-success-curl' -Mode 'success' -ExpectSuccess $true -ExpectCandidateWrite $true -InitialRollbackCount 4 | Out-Null
$o2Output = Invoke-SyntheticScenario -Name 'o2-core-success' -Mode 'success' -ExpectSuccess $true -ExpectCandidateWrite $true -Profile 'O2Core'
Assert-True (-not $o2Output.Contains('R2                   HTTP')) 'O2Core incorrectly required R2.'
Assert-True (-not $o2Output.Contains('Vectorize            HTTP')) 'O2Core incorrectly required Vectorize.'
Invoke-SyntheticScenario -Name 'account-token-fallback' -Mode 'account-token' -ExpectSuccess $true -ExpectCandidateWrite $true | Out-Null
Invoke-SyntheticScenario -Name 'candidate-noop' -Mode 'success' -ExpectSuccess $true -ExpectCandidateWrite $false -InitialCandidateMatches $true | Out-Null
Invoke-SyntheticScenario -Name 'active-token-rejected-as-replacement' -Mode 'success' -ExpectSuccess $false -ExpectCandidateWrite $false -InitialMainMatches $true | Out-Null
Invoke-SyntheticScenario -Name 'permission-partial' -Mode 'partial' -ExpectSuccess $false -ExpectCandidateWrite $false | Out-Null
Invoke-SyntheticScenario -Name 'invalid-token' -Mode 'invalid' -ExpectSuccess $false -ExpectCandidateWrite $false -UseCurlEnvelope $false | Out-Null
Invoke-SyntheticScenario -Name 'disabled-token' -Mode 'disabled' -ExpectSuccess $false -ExpectCandidateWrite $false | Out-Null
Invoke-SyntheticScenario -Name 'http-500-success-true' -Mode 'http500' -ExpectSuccess $false -ExpectCandidateWrite $false | Out-Null
Invoke-SyntheticScenario -Name 'string-false' -Mode 'string-false' -ExpectSuccess $false -ExpectCandidateWrite $false | Out-Null
Invoke-SyntheticScenario -Name 'wrong-result-shape' -Mode 'bad-shape' -ExpectSuccess $false -ExpectCandidateWrite $false | Out-Null
Invoke-SyntheticScenario -Name 'malformed-json' -Mode 'malformed' -ExpectSuccess $false -ExpectCandidateWrite $false | Out-Null
Invoke-SyntheticScenario -Name 'rate-limited' -Mode 'rate-limited' -ExpectSuccess $false -ExpectCandidateWrite $false | Out-Null
Invoke-SyntheticScenario -Name 'transport-failure' -Mode 'timeout' -ExpectSuccess $false -ExpectCandidateWrite $false | Out-Null
Invoke-SyntheticScenario -Name 'invalid-account-id' -Mode 'success' -ExpectSuccess $false -ExpectCandidateWrite $false -InvalidAccount $true | Out-Null
Invoke-SyntheticScenario -Name 'repo-local-path-rejected' -Mode 'success' -ExpectSuccess $false -ExpectCandidateWrite $false -AllowTestPath $false | Out-Null
Invoke-SyntheticScenario -Name 'retention-hash-failure' -Mode 'success' -ExpectSuccess $false -ExpectCandidateWrite $false -InitialRollbackCount 3 -ExpectRetentionFailure $true | Out-Null

Write-Host (
  '[verify-owner-token] parse=pass static=pass synthetic={0}/{0} candidate_only=true atomic=true rollback_retention=1 hash_guard=true clipboard_failures_cleared=true secret_output=false cloud_mutation=false' -f
  $scenarioCount
)
