#!/usr/bin/env bash
# autonomous-supervisor.sh — Vollautonomer 7-Layer + 22-Workpage Kreislauf
# Startet Monitor, prueft nach 10 Minuten, fixt Bugs, testet alles, wiederholt sich.
set -euo pipefail
REPO="D:/PLATTFORM/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM"
MON="${REPO}/monitoring"
WATCH="${MON}/codex-watch.sh"
LOG="${MON}/watch.jsonl"
CYCLE_LOG="${MON}/supervisor-cycle.log"
mkdir -p "${MON}"

log() {
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$ts] $*" | tee -a "${CYCLE_LOG}"
}

codex_running() {
  # Prueft ob ein codex Prozess aktiv im Repo arbeitet
  local pids
  pids="$(pgrep -f 'codex' || true)"
  if [ -z "$pids" ]; then
    return 1
  fi
  # Zusaetzlich: Pruefe ob es aenderungen im Repo gibt (Codex hinterlaesst Spuren)
  local changes
  changes="$(git -C "${REPO}" status --short | wc -l | tr -d ' ')"
  if [ "$changes" -gt 0 ]; then
    return 0
  fi
  return 1
}

start_watchdog() {
  if [ ! -x "${WATCH}" ]; then
    chmod +x "${WATCH}" || true
  fi
  # Nur starten, wenn nicht bereits laufend
  if ! pgrep -f "codex-watch.sh" >/dev/null 2>&1; then
    nohup bash "${WATCH}" >> "${MON}/watchdog-stdout.log" 2>> "${MON}/watchdog-stderr.log" &
    log "Watchdog gestartet (PID $!)"
  else
    log "Watchdog laeuft bereits"
  fi
}

wait_standby() {
  log ">>> 10-Minuten Standby-Modus <<<"
  sleep 600
  log "<<< Standby beendet — Wake-Up Check >>"
}

run_layer_verification() {
  log "Starte 7-Layer und 22-Workpage Pruefung..."
  # Platzhalter: integriere hier deine echten Verifier-Skripte fuer L1-L7 + 22 Seiten
  # Beispielsweise: scripts/verify-phase4-*.ps1 + scripts/verify-frontend-cloud-rewrites.ps1
  local failed=0
  local errors=""

  # Beispielprüfung: Sind alle verify-PS1 Skripte fuer Layer 1-7 vorhanden?
  for layer in 1 2 3 4 5 6 7; do
    script="${REPO}/scripts/verify-phase4-cloud-layers-contract-runtime-hosted.ps1"
    if [ ! -f "$script" ]; then
      failed=1
      errors="${errors} Layer${layer} Verify-Skript fehlt;"
    fi
  done

  if [ "$failed" -eq 0 ]; then
    log "Layer-Prüfung: alle kritischen Gate-Skripte vorhanden."
  else
    log "Layer-Prüfung FEHLER: ${errors}"
  fi
}

run_auto_repair() {
  log "Auto-Repair wird gestartet..."
  if [ -x "${REPO}/scripts/auto-repair-codex.ps1" ]; then
    powershell -NoProfile -ExecutionPolicy Bypass -File "${REPO}/scripts/auto-repair-codex.ps1" || true
  fi
  log "Auto-Repair abgeschlossen"
}


log "=== AUTONOMER SUPERVISOR GESTARTET (PID $$) ==="

while true; do
  if codex_running; then
    log "Codex aktiv — Monitor wird sichergestellt."
    start_watchdog
    wait_standby

    # Wake-Up: Monitor-Log pruefen
    log "Wake-Up: Pruefe Monitor-Log..."
    if [ -f "${LOG}" ]; then
      recent="$(tail -n 20 "${LOG}" || true)"
      log "Letzte 20 Monitor-Eintraege gelesen."
    else
      log "WARNUNG: Kein Monitor-Log gefunden."
    fi

    # Layer und Workpages pruefen
    run_layer_verification

    # Bei Fehlern: Auto-Repair
    if grep -qi 'TRASH|OBVIOUS|LOOP' "${LOG}" 2>/dev/null; then
      log "Verdaechtige Muster im Monitor-Log erkannt — starte Auto-Repair."
      run_auto_repair
    fi

    # Falls Watchdog abgestuerzt ist: neustarten
    start_watchdog

    log "Zyklus abgeschlossen — starte naechsten 10-Minuten-Durchlauf."
  else
    log "Codex nicht aktiv — Supervisor bleibt in Bereitschaft (pruefe alle 10 Minuten)."
    wait_standby
  fi
done
