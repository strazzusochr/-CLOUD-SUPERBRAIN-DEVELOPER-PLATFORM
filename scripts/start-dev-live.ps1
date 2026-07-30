#Requires -Version 7.0
<#
.SYNOPSIS
  Startet den lokalen Dev-Stack mit AKTIVIERTEM Live-LLM-Pfad (Cloudflare Workers AI).

.DESCRIPTION
  Der Compose-Standard ist bewusst fail-closed:
    - `LLM_GATEWAY_MODE`                        = deterministic_dry_run
    - `PRODUCT_ACCEPTANCE_LIVE_PROVIDER_APPROVED` = false
  Damit liefert `/api/v1/build` nach jedem Container-Neuaufbau die Meldung
  „Das LLM-Gateway hat kein vollständiges Build-Artefakt geliefert" — das ist KEIN Defekt,
  sondern der Schutz gegen unbeabsichtigte Provider-Aufrufe.

  Für die Workbench müssen BEIDE Schalter gesetzt sein:
    1. Gateway   : LLM_GATEWAY_MODE=cloudflare_workers_ai_live
    2. Frontend  : PRODUCT_ACCEPTANCE_LIVE_PROVIDER_APPROVED=true
  Das Gateway prüft zusätzlich pro Request das Metadatenfeld `live_provider_calls_allowed`,
  das die Build-Route aus Schalter 2 ableitet.

  Voraussetzungen (bereits erfüllt, wenn die Secrets-Datei gepflegt ist):
    CF_WORKERS_AI_TOKEN, CLOUDFLARE_ACCOUNT_ID

.PARAMETER DryRun
  Startet den Stack im sicheren Trockenmodus (Compose-Standard) — kein Provider-Aufruf.

.EXAMPLE
  pwsh -NoProfile -File scripts\start-dev-live.ps1
.EXAMPLE
  pwsh -NoProfile -File scripts\start-dev-live.ps1 -DryRun
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [string]$ComposeFile = 'docker-compose.dev.yml',
  [int]$HealthTimeoutSeconds = 240
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath 'D:\_sb_tmp')) { New-Item -ItemType Directory -Force -Path 'D:\_sb_tmp' | Out-Null }
$env:TEMP = 'D:\_sb_tmp'
$env:TMP  = 'D:\_sb_tmp'

if (-not (Test-Path -LiteralPath $ComposeFile)) {
  throw "Compose-Datei nicht gefunden: $ComposeFile — bitte im Repo-Wurzelverzeichnis ausführen."
}

# --- Freier Speicher: bekannter Stolperstein, tarnt sich als Verifier-Fehler --------------
$freeGb = [math]::Round((Get-PSDrive -Name D).Free / 1GB, 2)
Write-Host ("Freier Speicher D: {0} GB" -f $freeGb)
if ($freeGb -lt 5) {
  Write-Host 'WARNUNG: unter 5 GB frei. Builds und Verifier scheitern dann mit irreführenden Fehlern.' -ForegroundColor Yellow
}

$CfModel = '@cf/qwen/qwen2.5-coder-32b-instruct'

if ($DryRun) {
  $env:LLM_GATEWAY_MODE = 'deterministic_dry_run'
  $env:PRODUCT_ACCEPTANCE_LIVE_PROVIDER_APPROVED = 'false'
  Write-Host 'Modus: SICHERER TROCKENLAUF — keine Provider-Aufrufe, Workbench-Build liefert kein Artefakt.' -ForegroundColor Cyan
} else {
  $env:LLM_GATEWAY_MODE = 'cloudflare_workers_ai_live'
  $env:PRODUCT_ACCEPTANCE_LIVE_PROVIDER_APPROVED = 'true'
  # Dritter, leicht zu übersehender Schalter: der Compose-Standard ist `gemma-3-1b-it`,
  # das lokale llama.cpp-Modell. Es steht NICHT auf der Workers-AI-Allowlist
  # ({ @cf/qwen/qwen2.5-coder-32b-instruct, @cf/meta/llama-3.1-8b-instruct }).
  # Ohne diese Zeile antwortet das Gateway mit 400 und der Build mit 503
  # „llm_gateway_generation_unavailable".
  $env:WORKBENCH_LLM_MODEL = $CfModel
  $env:CF_WORKERS_AI_MODEL = $CfModel
  Write-Host 'Modus: LIVE (Cloudflare Workers AI) — echte Provider-Aufrufe sind zugelassen.' -ForegroundColor Green
  Write-Host ("Workbench-Modell: {0}" -f $CfModel)
}

# --- Interner Service-Token zwischen Frontend und Agent API ------------------------------
# `/api/v1/builds` verweigert JEDEN Write, solange AGENT_API_AUTH_TOKEN leer ist
# (fail-closed: `bool(expected_token and ...)`). Ohne ihn scheitert der Workbench-Build mit
# `build_persistence_unavailable`, OBWOHL die LLM-Generierung erfolgreich war.
# Es ist ein rein lokaler Shared Secret zwischen zwei Containern auf diesem Rechner —
# kein externer Zugang. Er wird einmalig erzeugt und in der Secrets-Datei abgelegt.
$secretsPath = [IO.Path]::Combine([Environment]::GetFolderPath('UserProfile'), '.codex', 'secrets', 'cloud-superbrain.local.env')
$serviceToken = $null
if (Test-Path -LiteralPath $secretsPath) {
  foreach ($line in (Get-Content -LiteralPath $secretsPath)) {
    if ($line -match '^\s*AGENT_API_AUTH_TOKEN\s*=(.*)$') {
      $candidate = $matches[1].Trim().Trim('"')
      if (-not [string]::IsNullOrWhiteSpace($candidate)) { $serviceToken = $candidate }
    }
  }
}
if ([string]::IsNullOrWhiteSpace($serviceToken)) {
  $randomBytes = [byte[]]::new(32)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($randomBytes)
  $serviceToken = -join ($randomBytes | ForEach-Object { $_.ToString('x2') })
  if (Test-Path -LiteralPath $secretsPath) {
    Copy-Item -LiteralPath $secretsPath -Destination "$secretsPath.bak-svctoken-$((Get-Date).ToString('yyyyMMdd-HHmmss'))" -Force
    Add-Content -LiteralPath $secretsPath -Value "AGENT_API_AUTH_TOKEN=$serviceToken"
    Write-Host ("Interner Service-Token erzeugt und in der Secrets-Datei ergaenzt ({0} Zeichen, Wert nicht angezeigt)." -f $serviceToken.Length) -ForegroundColor Green
  } else {
    Write-Host 'Secrets-Datei nicht gefunden — Token gilt nur fuer diesen Lauf.' -ForegroundColor Yellow
  }
} else {
  Write-Host ("Interner Service-Token aus Secrets-Datei uebernommen ({0} Zeichen, Wert nicht angezeigt)." -f $serviceToken.Length)
}
$env:AGENT_API_AUTH_TOKEN = $serviceToken

# --- O1: GitHub-OAuth + JWT-Signierschluessel aus der Secrets-Datei -----------------------
# Die Agent API leitet `github_oauth_configured` und `credential_issuance_ready` aus genau
# vier Werten ab. Fehlt einer, bleibt Auth fail-closed. Der JWT-Schluessel ist ein rein
# lokaler Signierschluessel (kein Fremdzugang) und wird bei Bedarf einmalig erzeugt.
$oauthKeys = @('GITHUB_OAUTH_CLIENT_ID', 'GITHUB_OAUTH_CLIENT_SECRET', 'GITHUB_OAUTH_REDIRECT_URI', 'JWT_SIGNING_SECRET')
$secretsMap = @{}
if (Test-Path -LiteralPath $secretsPath) {
  foreach ($line in (Get-Content -LiteralPath $secretsPath)) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$') {
      $entryKey = $matches[1]
      $entryValue = $matches[2].Trim().Trim('"')
      if (($oauthKeys -contains $entryKey) -and -not [string]::IsNullOrWhiteSpace($entryValue) -and -not $secretsMap.ContainsKey($entryKey)) {
        $secretsMap[$entryKey] = $entryValue
      }
    }
  }
}
if (-not $secretsMap.ContainsKey('JWT_SIGNING_SECRET')) {
  $jwtBytes = [byte[]]::new(32)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($jwtBytes)
  $jwtSecret = [Convert]::ToBase64String($jwtBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
  if (Test-Path -LiteralPath $secretsPath) {
    Add-Content -LiteralPath $secretsPath -Value "JWT_SIGNING_SECRET=$jwtSecret"
    Write-Host ('JWT-Signierschluessel erzeugt und in der Secrets-Datei ergaenzt ({0} Zeichen, Wert nicht angezeigt).' -f $jwtSecret.Length) -ForegroundColor Green
  }
  $secretsMap['JWT_SIGNING_SECRET'] = $jwtSecret
}
foreach ($oauthKey in $oauthKeys) {
  if ($secretsMap.ContainsKey($oauthKey)) { Set-Item -Path "env:$oauthKey" -Value $secretsMap[$oauthKey] }
}
$missingOauth = @($oauthKeys | Where-Object { -not $secretsMap.ContainsKey($_) })
if ($missingOauth.Count -gt 0) {
  Write-Host ('O1 unvollstaendig — fehlt in der Secrets-Datei: {0}' -f ($missingOauth -join ', ')) -ForegroundColor Yellow
} else {
  Write-Host 'O1-Konfiguration vollstaendig (4/4, Werte nicht angezeigt).' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Starte Stack ...'
docker compose -f $ComposeFile up -d
if ($LASTEXITCODE -ne 0) { throw "docker compose up fehlgeschlagen (Exit $LASTEXITCODE)" }

# --- Auf Health warten --------------------------------------------------------------------
Write-Host ''
Write-Host 'Warte auf Container-Health ...'
$deadline = (Get-Date).AddSeconds($HealthTimeoutSeconds)
$healthy = 0
$total = 0
do {
  $rows = @(docker compose -f $ComposeFile ps --format json 2>$null | ForEach-Object { $_ | ConvertFrom-Json })
  $total = $rows.Count
  $healthy = @($rows | Where-Object { $_.Health -eq 'healthy' }).Count
  if ($total -gt 0 -and $healthy -eq $total) { break }
  Start-Sleep -Seconds 5
} while ((Get-Date) -lt $deadline)

Write-Host ("Health: {0}/{1}" -f $healthy, $total)
if ($total -eq 0 -or $healthy -ne $total) {
  @($rows | Where-Object { $_.Health -ne 'healthy' }) | ForEach-Object {
    Write-Host ("  nicht gesund: {0} State={1} Health={2}" -f $_.Service, $_.State, $_.Health) -ForegroundColor Yellow
  }
  throw "Nicht alle Dienste sind gesund ($healthy/$total)."
}

# --- Effektiv gesetzte Schalter zurücklesen (nicht raten) ---------------------------------
Write-Host ''
Write-Host '=== Effektive Schalter ===' -ForegroundColor Cyan
$gatewayMode = (docker compose -f $ComposeFile exec -T llm-gateway sh -lc 'printf "%s" "$LLM_GATEWAY_MODE"' 2>$null)
$frontendFlag = (docker compose -f $ComposeFile exec -T frontend sh -lc 'printf "%s" "$PRODUCT_ACCEPTANCE_LIVE_PROVIDER_APPROVED"' 2>$null)
$workbenchModel = (docker compose -f $ComposeFile exec -T frontend sh -lc 'printf "%s" "$WORKBENCH_LLM_MODEL"' 2>$null)
$tokenSet = (docker compose -f $ComposeFile exec -T llm-gateway sh -lc 'if [ -n "$CF_WORKERS_AI_TOKEN" ]; then printf yes; else printf no; fi' 2>$null)
$accountSet = (docker compose -f $ComposeFile exec -T llm-gateway sh -lc 'if [ -n "$CLOUDFLARE_ACCOUNT_ID" ]; then printf yes; else printf no; fi' 2>$null)
$allowedModels = @('@cf/qwen/qwen2.5-coder-32b-instruct', '@cf/meta/llama-3.1-8b-instruct')
$modelOk = $allowedModels -contains $workbenchModel
Write-Host ("  Gateway-Modus            : {0}" -f $gatewayMode)
Write-Host ("  Frontend erlaubt Live    : {0}" -f $frontendFlag)
Write-Host ("  Workbench-Modell         : {0} {1}" -f $workbenchModel, $(if ($modelOk) { '(auf Allowlist)' } else { '(NICHT auf Allowlist -> Gateway 400)' }))
Write-Host ("  CF_WORKERS_AI_TOKEN      : {0}" -f $tokenSet)
Write-Host ("  CLOUDFLARE_ACCOUNT_ID    : {0}" -f $accountSet)

$liveReady = ($gatewayMode -eq 'cloudflare_workers_ai_live') -and ($frontendFlag -eq 'true') -and $modelOk -and ($tokenSet -eq 'yes') -and ($accountSet -eq 'yes')
Write-Host ''
if ($DryRun) {
  Write-Host 'Trockenlauf aktiv. Die Workbench baut bewusst KEIN Artefakt.' -ForegroundColor Cyan
} elseif ($liveReady) {
  Write-Host 'LIVE-PFAD BEREIT — die Workbench kann jetzt echte Builds erzeugen.' -ForegroundColor Green
  Write-Host '  Öffnen: http://localhost:8081/workbench  (vorher einloggen)' -ForegroundColor Green
} else {
  Write-Host 'LIVE-PFAD NICHT VOLLSTAENDIG. Fehlende Voraussetzung oben pruefen.' -ForegroundColor Red
  exit 1
}

Write-Host ''
Write-Host 'Hinweis: "session_missing" bedeutet NICHT eingeloggt — zuerst /login benutzen.'
exit 0
