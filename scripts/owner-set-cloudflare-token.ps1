#Requires -Version 7.0
<#
.SYNOPSIS
  Owner-Helfer: Cloudflare-API-Token sicher als Kandidat aufnehmen und
  Management-Inventare ausschliesslich read-only pruefen.

.DESCRIPTION
  - Liest einen Token verdeckt oder aus der Zwischenablage.
  - Leert eine verwendete Zwischenablage in jedem Erfolgs- und Fehlerpfad.
  - Prueft Tokenstatus, HTTP-Status, JSON-Typ, Fehlerliste und Ergebnisform.
  - Fuehrt ausschliesslich GET-Anfragen aus.
  - Schreibt niemals direkt CLOUDFLARE_API_TOKEN, sondern nur
    CLOUDFLARE_API_TOKEN_CANDIDATE.
  - Ein erfolgreicher GET beweist Management-Zugriff, nicht das Edit-Recht.
    Erst der freigegebene Hosted-Write-Verifier darf den Kandidaten qualifizieren.
  - Schreibt atomar und nur in das private Codex-Secrets-Verzeichnis.

.EXAMPLE
  pwsh -NoProfile -File scripts\owner-set-cloudflare-token.ps1 -FromClipboard -Profile Full
#>
[CmdletBinding()]
param(
  [string]$SecretFile = ([IO.Path]::Combine(
    [Environment]::GetFolderPath('UserProfile'),
    '.codex',
    'secrets',
    'cloud-superbrain.local.env'
  )),
  [switch]$ProbeOnly,
  [switch]$FromClipboard,
  [switch]$KeepClipboard,
  [ValidateSet('Full', 'O2Core', 'O2WithR2', 'O5')]
  [string]$Profile = 'Full',
  [switch]$AllowTestSecretPath
)

$ErrorActionPreference = 'Stop'
$candidateKey = 'CLOUDFLARE_API_TOKEN_CANDIDATE'

function Get-TokenCandidate([string]$Raw) {
  if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
  $trimmed = $Raw.Trim().Trim('"').Trim("'")
  $bearerMatch = [regex]::Match($trimmed, 'Bearer\s+([A-Za-z0-9_\-]{20,80})')
  if ($bearerMatch.Success) { return $bearerMatch.Groups[1].Value }
  $candidateRuns = [regex]::Matches($trimmed, '[A-Za-z0-9_\-]{25,80}')
  if ($candidateRuns.Count -gt 0) {
    return ($candidateRuns |
      Sort-Object -Property { $_.Value.Length } -Descending |
      Select-Object -First 1).Value
  }
  return $trimmed
}

function Read-EnvMap([string]$Path) {
  $map = [ordered]@{}
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $map }
  foreach ($line in (Get-Content -LiteralPath $Path)) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$') {
      $map[$matches[1]] = $matches[2].Trim().Trim('"')
    }
  }
  return $map
}

function Resolve-ApprovedSecretFile([string]$Path, [bool]$AllowTestPath) {
  if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Secrets-Dateipfad fehlt.' }
  $resolved = [IO.Path]::GetFullPath($Path)
  $approvedRoot = [IO.Path]::GetFullPath([IO.Path]::Combine(
    [Environment]::GetFolderPath('UserProfile'),
    '.codex',
    'secrets'
  )).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $testRoot = [IO.Path]::GetFullPath('D:\_sb_tmp').
    TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $underApprovedRoot = $resolved.StartsWith(
    $approvedRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
  )
  $underTestRoot = $AllowTestPath -and $resolved.StartsWith(
    $testRoot + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
  )
  if (-not ($underApprovedRoot -or $underTestRoot)) {
    throw 'Secrets-Datei muss im privaten Codex-Secrets-Verzeichnis liegen.'
  }
  if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    throw 'Secrets-Datei fehlt; keine Datei wurde angelegt.'
  }
  return $resolved
}

function Test-ResultShape([object]$Payload, [string]$Shape) {
  if ($null -eq $Payload) { return $false }
  $resultProperty = $Payload.PSObject.Properties['result']
  if ($null -eq $resultProperty) { return $false }
  $result = $resultProperty.Value
  switch ($Shape) {
    'token' {
      if ($null -eq $result) { return $false }
      $statusProperty = $result.PSObject.Properties['status']
      $idProperty = $result.PSObject.Properties['id']
      return (
        $null -ne $statusProperty -and
        [string]$statusProperty.Value -eq 'active' -and
        $null -ne $idProperty -and
        [string]$idProperty.Value -match '^[A-Fa-f0-9]{32}$'
      )
    }
    'array' {
      return $result -is [array]
    }
    'buckets' {
      if ($null -eq $result) { return $false }
      $bucketsProperty = $result.PSObject.Properties['buckets']
      return $null -ne $bucketsProperty -and $bucketsProperty.Value -is [array]
    }
    default {
      return $false
    }
  }
}

function Invoke-SanitizedGet(
  [string]$Name,
  [string]$Url,
  [string]$Need,
  [string]$Shape,
  [hashtable]$Headers
) {
  $status = 'REQ_FAIL'
  $codes = ''
  $ok = $false
  $kind = 'transport_failure'
  try {
    $response = Invoke-WebRequest -Uri $Url -Headers $Headers -Method GET -TimeoutSec 20 -SkipHttpErrorCheck
    $status = [int]$response.StatusCode
    $payload = $null
    try { $payload = $response.Content | ConvertFrom-Json } catch {}

    if ($null -eq $payload) {
      $kind = 'unexpected_response'
    } else {
      $successProperty = $payload.PSObject.Properties['success']
      $errorsProperty = $payload.PSObject.Properties['errors']
      $successIsTrue = (
        $null -ne $successProperty -and
        $successProperty.Value -is [bool] -and
        $successProperty.Value -eq $true
      )
      $errors = if ($null -ne $errorsProperty) { @($errorsProperty.Value) } else { @() }
      $codes = (($errors | ForEach-Object {
        if ($null -ne $_ -and $null -ne $_.PSObject.Properties['code']) {
          [string]$_.code
        }
      }) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ','
      $shapeOk = Test-ResultShape $payload $Shape
      $ok = $status -eq 200 -and $successIsTrue -and $errors.Count -eq 0 -and $shapeOk

      if ($ok) {
        $kind = 'ok'
      } elseif ($status -eq 429) {
        $kind = 'rate_limited'
      } elseif ($status -ge 500) {
        $kind = 'provider_failure'
      } elseif ($status -in @(401, 403) -and $codes -match '(^|,)10000(,|$)') {
        $kind = 'permission_or_account_scope'
      } elseif ($Name -like 'Token-Verify*' -and $codes -match '(^|,)(6003|9106|1000)(,|$)') {
        $kind = 'auth_invalid'
      } else {
        $kind = 'unexpected_response'
      }
    }
  } catch {
    # Fremde Exception-Texte werden absichtlich nie ausgegeben.
    $status = 'REQ_FAIL'
    $kind = 'transport_failure'
  }
  return [pscustomobject]@{
    Resource = $Name
    Status = $status
    Ok = $ok
    Err = $codes
    Kind = $kind
    Need = $Need
  }
}

function Write-CandidateAtomically(
  [string]$Path,
  [string]$Key,
  [string]$Value
) {
  $lines = @(Get-Content -LiteralPath $Path)
  $replaced = $false
  $outputLines = foreach ($line in $lines) {
    if ($line -match ('^\s*' + [regex]::Escape($Key) + '\s*=')) {
      $replaced = $true
      $Key + '=' + $Value
    } else {
      $line
    }
  }
  if (-not $replaced) { $outputLines = @($outputLines) + ($Key + '=' + $Value) }

  $temporaryPath = $Path + '.candidate-' + [Guid]::NewGuid().ToString('N')
  $rollbackPath = (
    $Path +
    '.rollback-' +
    (Get-Date).ToString('yyyyMMdd-HHmmss') +
    '-' +
    [Guid]::NewGuid().ToString('N').Substring(0, 8)
  )
  try {
    [IO.File]::WriteAllLines($temporaryPath, [string[]]$outputLines, [Text.UTF8Encoding]::new($false))
    $temporaryMap = Read-EnvMap $temporaryPath
    if ($temporaryMap[$Key] -ne $Value) {
      throw 'Kandidaten-Schreibprüfung fehlgeschlagen; Originaldatei unverändert.'
    }
    [IO.File]::Replace($temporaryPath, $Path, $rollbackPath, $true)
    $writtenMap = Read-EnvMap $Path
    if ($writtenMap[$Key] -ne $Value) {
      throw 'Atomare Schreibprüfung fehlgeschlagen; Rollback-Datei liegt bereit.'
    }
    return $rollbackPath
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force
    }
  }
}

$resolvedSecretFile = Resolve-ApprovedSecretFile $SecretFile $AllowTestSecretPath
$existing = Read-EnvMap $resolvedSecretFile
$accountId = [string]$existing['CLOUDFLARE_ACCOUNT_ID']
if ($accountId -notmatch '^[A-Fa-f0-9]{32}$') {
  throw 'CLOUDFLARE_ACCOUNT_ID fehlt oder ist nicht exakt 32-stellig hexadezimal.'
}

Write-Host "Secrets-Datei : $resolvedSecretFile"
Write-Host 'Account-ID    : vorhanden (nicht angezeigt)'
Write-Host ("Profil        : {0}" -f $Profile)
Write-Host ''

$clipboardCaptured = $false
try {
  if ($ProbeOnly) {
    $tokenSource = if (-not [string]::IsNullOrWhiteSpace([string]$existing[$candidateKey])) {
      $candidateKey
    } else {
      'CLOUDFLARE_API_TOKEN'
    }
    $plain = [string]$existing[$tokenSource]
    if ([string]::IsNullOrWhiteSpace($plain)) {
      throw 'Kein gespeicherter Cloudflare-Token zum Testen.'
    }
    Write-Host ("Modus: ProbeOnly auf {0}." -f $tokenSource) -ForegroundColor Yellow
  } elseif ($FromClipboard) {
    $plain = Get-Clipboard -Raw
    if ($null -ne $plain) {
      $plain = [string]$plain
      $clipboardCaptured = $true
    }
    if ([string]::IsNullOrWhiteSpace($plain)) {
      throw 'Zwischenablage ist leer; Datei unverändert.'
    }
    Write-Host ('Aus Zwischenablage gelesen: {0} Zeichen (Wert wird nicht angezeigt).' -f $plain.Length) -ForegroundColor Green
  } else {
    Write-Host 'Cloudflare-API-Token verdeckt eingeben, dann Enter.' -ForegroundColor Cyan
    $secureToken = Read-Host -AsSecureString
    $plain = [Net.NetworkCredential]::new('', $secureToken).Password
    if ([string]::IsNullOrWhiteSpace($plain)) {
      throw 'Keine Eingabe erhalten; Datei unverändert.'
    }
  }

  if (-not $ProbeOnly) {
    $rawLength = $plain.Length
    $extracted = Get-TokenCandidate $plain
    if ([string]::IsNullOrWhiteSpace($extracted)) {
      throw 'Kein Token aus der Eingabe extrahierbar; Datei unverändert.'
    }
    if ($extracted -ne $plain) {
      Write-Host ('Eingabe {0} Zeichen; reinen Token mit {1} Zeichen extrahiert.' -f $rawLength, $extracted.Length) -ForegroundColor Yellow
      $plain = $extracted
    } else {
      $plain = $plain.Trim()
    }
    if ($plain.Length -lt 20 -or $plain.Length -gt 80) {
      throw ('Tokenlänge {0} liegt ausserhalb 20–80; Datei unverändert.' -f $plain.Length)
    }
  }

  $headers = @{ Authorization = 'Bearer ' + $plain }
  $baseUrl = 'https://api.cloudflare.com/client/v4'

  $userVerify = Invoke-SanitizedGet `
    -Name 'Token-Verify/User' `
    -Url "$baseUrl/user/tokens/verify" `
    -Need 'aktiver User API Token' `
    -Shape 'token' `
    -Headers $headers
  $verify = $userVerify
  if (
    -not $userVerify.Ok -and (
      $userVerify.Kind -in @('auth_invalid', 'permission_or_account_scope') -or
      $userVerify.Status -in @(401, 403)
    )
  ) {
    $verify = Invoke-SanitizedGet `
      -Name 'Token-Verify/Account' `
      -Url "$baseUrl/accounts/$accountId/tokens/verify" `
      -Need 'aktiver Account API Token' `
      -Shape 'token' `
      -Headers $headers
  }

  if (-not $verify.Ok) {
    Write-Host '=== READ-ONLY-ERGEBNIS ===' -ForegroundColor Cyan
    Write-Host (
      'FAIL {0,-21} HTTP {1,-9} err={2,-10} kind={3}' -f
      $verify.Resource,
      $verify.Status,
      $verify.Err,
      $verify.Kind
    ) -ForegroundColor Red
    Write-Host ''
    if ($verify.Kind -eq 'auth_invalid') {
      Write-Host 'TOKEN ABGELEHNT; Datei unverändert.' -ForegroundColor Red
      switch -Regex ([string]$verify.Err) {
        '6003' { Write-Host '6003 = kein gültiger reiner Bearer-Token.' -ForegroundColor Yellow }
        '9106|1000\b' { Write-Host '9106/1000 = Token ungültig, abgelaufen oder gerollt.' -ForegroundColor Yellow }
        default { Write-Host 'Authentifizierung fehlgeschlagen.' -ForegroundColor Yellow }
      }
      exit 2
    }
    Write-Host ("TOKEN NICHT VERIFIZIERBAR: {0}; keine Credential-Diagnose, Datei unverändert." -f $verify.Kind) -ForegroundColor Red
    exit 3
  }

  $allResourceChecks = @(
    @{ Name = 'Workers Scripts'; Url = "$baseUrl/accounts/$accountId/workers/scripts"; Shape = 'array'; Need = 'Account · Workers Scripts · Edit'; Profiles = @('Full', 'O2Core', 'O2WithR2') }
    @{ Name = 'D1'; Url = "$baseUrl/accounts/$accountId/d1/database"; Shape = 'array'; Need = 'Account · D1 · Edit'; Profiles = @('Full', 'O2Core', 'O2WithR2') }
    @{ Name = 'Queues'; Url = "$baseUrl/accounts/$accountId/queues"; Shape = 'array'; Need = 'Account · Queues · Edit'; Profiles = @('Full', 'O2Core', 'O2WithR2') }
    @{ Name = 'Durable Objects'; Url = "$baseUrl/accounts/$accountId/workers/durable_objects/namespaces"; Shape = 'array'; Need = 'Account · Workers Scripts · Edit'; Profiles = @('Full', 'O2Core', 'O2WithR2') }
    @{ Name = 'R2'; Url = "$baseUrl/accounts/$accountId/r2/buckets"; Shape = 'buckets'; Need = 'Account · Workers R2 Storage · Edit plus separater Zero-Card-Proof'; Profiles = @('Full', 'O2WithR2') }
    @{ Name = 'Vectorize'; Url = "$baseUrl/accounts/$accountId/vectorize/v2/indexes"; Shape = 'array'; Need = 'Account · Vectorize · Edit (O5 separat)'; Profiles = @('Full', 'O5') }
  )
  $selectedChecks = @($allResourceChecks | Where-Object { $_.Profiles -contains $Profile })
  $resourceResults = @(
    foreach ($check in $selectedChecks) {
      Invoke-SanitizedGet `
        -Name $check.Name `
        -Url $check.Url `
        -Need $check.Need `
        -Shape $check.Shape `
        -Headers $headers
    }
  )

  Write-Host '=== READ-ONLY-ERGEBNIS ===' -ForegroundColor Cyan
  foreach ($result in @($verify) + $resourceResults) {
    $mark = if ($result.Ok) { 'OK  ' } else { 'FAIL' }
    $color = if ($result.Ok) { 'Green' } else { 'Red' }
    Write-Host (
      '{0} {1,-21} HTTP {2,-9} err={3,-10} kind={4}' -f
      $mark,
      $result.Resource,
      $result.Status,
      $result.Err,
      $result.Kind
    ) -ForegroundColor $color
  }

  $passed = @($resourceResults | Where-Object { $_.Ok })
  $failed = @($resourceResults | Where-Object { -not $_.Ok })
  Write-Host ''
  Write-Host ('Ergebnis: {0}/{1} Management-Inventare lesbar.' -f $passed.Count, $resourceResults.Count)

  if ($failed.Count -gt 0) {
    $permissionFailures = @($failed | Where-Object { $_.Kind -eq 'permission_or_account_scope' })
    $otherFailures = @($failed | Where-Object { $_.Kind -ne 'permission_or_account_scope' })
    if ($permissionFailures.Count -gt 0) {
      Write-Host ''
      Write-Host 'ZIEL-PERMISSIONS für die fehlenden Inventare:' -ForegroundColor Yellow
      foreach ($need in ($permissionFailures.Need | Sort-Object -Unique)) {
        Write-Host ('  - ' + $need) -ForegroundColor Yellow
      }
    }
    if ($otherFailures.Count -gt 0) {
      Write-Host ''
      Write-Host 'Keine Permission-Diagnose für:' -ForegroundColor Yellow
      foreach ($failure in $otherFailures) {
        Write-Host ('  - {0}: {1}' -f $failure.Resource, $failure.Kind) -ForegroundColor Yellow
      }
    }
    Write-Host ''
    Write-Host 'Datei NICHT verändert (fail-closed).' -ForegroundColor Yellow
    exit 1
  }

  Write-Host ''
  Write-Host 'GET-Probe PASS; Edit-Rechte bleiben unbewiesen.' -ForegroundColor Yellow
  if ($ProbeOnly) {
    Write-Host 'ProbeOnly: keine Dateiänderung.' -ForegroundColor Green
    exit 0
  }

  $existingMainToken = [string]$existing['CLOUDFLARE_API_TOKEN']
  $existingCandidate = [string]$existing[$candidateKey]
  if ($plain -eq $existingMainToken) {
    Write-Host 'Eingabe entspricht dem aktiven Token; kein Kandidat geschrieben, aktiven Token nicht als Ersatz revoken.' -ForegroundColor Red
    exit 4
  }
  if ($plain -eq $existingCandidate) {
    Write-Host 'Identischer Kandidat ist bereits gespeichert; keine Dateiänderung.' -ForegroundColor Green
    exit 0
  }

  $rollbackPath = Write-CandidateAtomically `
    -Path $resolvedSecretFile `
    -Key $candidateKey `
    -Value $plain
  Write-Host ("Rollback-Datei: {0}" -f $rollbackPath)
  Write-Host ("Gespeichert: {0} ({1} Zeichen; Wert nicht angezeigt)" -f $candidateKey, $plain.Length) -ForegroundColor Green
  Write-Host ''
  Write-Host 'NÄCHSTER SCHRITT:' -ForegroundColor Cyan
  Write-Host '  Kandidat nur prozesslokal für den freigegebenen Hosted-Write-Verifier verwenden.'
  Write-Host '  Erst dessen echter Write-/Read-/Delete-Beweis darf den Kandidaten qualifizieren.'
  Write-Host '  Kompromittierten alten Token unabhängig davon im Dashboard revoken.'
  exit 0
} finally {
  if ($clipboardCaptured -and -not $KeepClipboard) {
    try {
      Set-Clipboard -Value ''
      Write-Host 'Zwischenablage geleert.'
    } catch {
      Write-Host 'Zwischenablage konnte nicht geleert werden; bitte sofort manuell überschreiben.' -ForegroundColor Yellow
    }
  }
}
