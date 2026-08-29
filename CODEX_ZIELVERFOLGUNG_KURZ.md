# ZIELVERFOLGUNG KURZ - STAND 2026-08-29

Status: `ACTIVE_CURRENT_TRUTH`
Branch: `codex/organism-visual-v2`
Market Status: `MARKET_READY:false`

Diese Datei ist die kurze Steuerung. Details:

- aktuelle Uebergabe: `CODEX_UEBERGABE_2026-08-29-SESSION16.md`
- Weg zu 100: `CODEX_100_PROZENT_ZIEL_2026-08-29.md`
- OAuth: `docs/runbooks/PRODUCTION_OAUTH_FIXPLAN_2026-08-29.md`
- Optikregeln: `REGELN_OPTIK_UND_FERTIG.md`
- RC21-Arbeitsauftrag/Historie: `AGENT_AUFTRAG_RC21_UND_RESTLISTE.md`

## 1. Endziel

`npm run verify:market-ready` druckt real:

```text
MARKET_READY: true
```

Dafuer muessen beide Matrizen evidenzbasiert 100 sein. Production-Deploy und Release-
Promotion bleiben danach separate Owner-Entscheidungen.

## 2. Aktueller Koordinatensatz

| Feld | Stand |
|---|---|
| lokaler HEAD vor diesem Dokumentensatz | `740bafe92314b36f047a07443567df403ea5a45d` |
| Remote vor diesem Dokumentensatz | `e98f68a6e5ce8544f8504f38a57c0e17672fe253` |
| aktiver Kandidat | `prod-candidate-2026-08-28-local-rc21` |
| Candidate Source | `c1b022a884eb16939fe0542b2eb9056b60706b20` |
| Candidate Control | `9f2ee3838492079bd5c65b53a03cd4b29c9a6c49` |
| Qualifikations-CI | `33217980790` |
| Follow-up-CI | `33223542872` auf `e98f68a6`, `25/25`, `0 skipped` |
| Readiness | `17/19 = 89%`; offen I1 und I5 |
| Rollback | RC20 Source `c29c738b82e4e35cc1288bc603319cba60d167d2` |

RC21 bleibt immutable. Neue Runtime-Source-Aenderungen benoetigen einen neuen Kandidaten.

## 3. Fortschritt

```text
Overall 89

Horizontal:
P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 89 | P6 90

Vertikal:
L1 100 | L2 100 | L3 100 | L4 55 | L5 56 | L6 100 | L7 100
```

Keine Prozentanhebung durch Doku, Konsolenwerte oder lokale Wiederholungen bereits
kreditierter Beweise.

## 4. Seit RC21 erledigt

- RC21 Source-Paritaet wiederhergestellt.
- Runtime-Verifier auf active-provider-only-Wahrheit korrigiert.
- Fuenf-Achsen-Audit und Regression in der statischen Gate-Kette.
- GitHub-Actions-`api_error` als stale Container-Environment gemessen und durch scoped
  Agent-API-Recreate behoben; kein Token rotiert oder ausgegeben.
- Phase-5-CI so geroutet, dass kein mutually-exclusive Schritt mehr skipped wird.
- Follow-up-CI `33223542872`: ein Job, `25/25` success, `0 skipped`.
- L4/L5-Rubrik als Owner-Draft erstellt; beide Tabellen summieren 100, aber kein Credit.
- GitHub-Environments/Reviewer, OAuth App, Worker-Secret-Namen und Vercel-Callback-
  Konfiguration vorbereitet.
- lokaler Build `21/21` gruen.
- kompletter Runtime-Umbrella gruen.
- DEV-LIVE `10/10 healthy`.
- kompletter lokaler Browser-Umbrella gruen:
  - responsive `22x2 = 44`, ohne Overflow/Overlay/Console-Fehler,
  - echter Cloudflare-Workers-AI-Build,
  - `22/22` Routen,
  - `29/29` Familien,
  - `161/161` Aktionen,
  - O4 Audit/Readback/Rollback.

`161/161` bedeutet sichtbare UI-Effektabdeckung, nicht 161 Backend- oder Layeraufrufe.
Responsive-Report-SHA: `723D2DEF1E3B98C25885E2F6242342EB02D2238CAC46D510A5F7E103AEED8E5B`.
Fresh Product-/Aktionsreports sind DEV-/Worktree-Proofs, nicht neue source-gebundene
Kandidatenevidenz; ihre `source_commit_sha`-Felder sind leer.
Alle neuen Browser-/Runtimebeweise: `DEV-ONLY; hosted proof still blocked`.

## 5. Letzter Verifier

Letzter realer `npm run verify`-Exit:

```text
FAIL: current Cloudflare-native hosted Worker source parity
```

Gemessene Ursache:

- Hosted Worker Source: `d0674bfc1367b04d95ca2bf745e89fabf12046ad`
- aktueller Worker-Tree enthaelt danach die Runnability-Fixes `0cf451d0` und `bbc2ad48`
- geaendert sind `services/cloudflare-stateful-runtime/src/index.js` und
  `services/cloudflare-stateful-runtime/test/index.test.js`
- Hosted Fortschritt `84`, Repo Fortschritt `89`

Das Gate bleibt rot, bis ein Owner-freigegebener aktueller Hosted-Deploy plus erneuerte
source-gebundene Evidence existiert. Verifier nicht abschwaechen.

Uncommittet in `scripts/verify-phase1.ps1`: ein Claim-Flag-basierter External-Gate-Set-Fix.
Er bestand im Full-Verifier und liess den Lauf bis zur echten Worker-Paritaet weiterlaufen,
bleibt aber bis zur vereinbarten Akzeptanzbedingung uncommittet.

## 6. Hosted-Wahrheit

Aktuelle anonyme Readbacks:

| Surface | Stand |
|---|---|
| Worker `/health` | 200, healthy, Source `d0674bfc` |
| Worker `/project/progress` | 200, Overall 84 |
| Worker `/team/status` | 500 |
| Worker `/auth/contract` | 200, read-only Contract-Origin; OAuth nicht konfiguriert/live |
| Worker `/auth/me` | 404 |
| Vercel `/health` | 200, degraded, Backends nicht konfiguriert |
| Vercel `/project/progress` | 200, Overall 84 |
| Vercel `/team/status` | 200, ehrliche Frontend-Projektion |
| Vercel `/auth/me` | 200, ehrliche leere Projektion, keine Identity |

HTTP 200 ist kein Auth-, Backend- oder Release-Beweis.

DEV-ONLY Cloud-Inventar: `8/8` konfiguriert, `7/8` live gelesen; Cloud-Layer `6/7`.
GitHub Actions und GitLab sind verifiziert. Nur GHCR bleibt `api_error`, wodurch L5 wegen
`ghcr_registry_live_read_not_verified` partial bleibt. `PROMPT_ANTIGRAVITY_CLOUD.md` ist
historisch und nicht mehr auszufuehren.

Bekannter Next-Candidate-Defekt: `services/agent-api/app/main.py:7455` und
`apps/frontend/lib/endpoint-snapshot.json` erwarten noch den bereits geschlossenen
Cloudflare-Gate-Namen. Real fehlen `hosted_agent_api_contracts`,
`ghcr_image_digest_verify` und `vercel_backend_origin_health`.

## 7. Offen bis 100

| Block | Heute | Abschluss |
|---|---|---|
| P3 | 44 | echte production OAuth identity mit Session-/Replay-/Audit-Beweis |
| P5 | 89 | I1 aktueller Hosted Candidate + I5 Production Auth |
| P6 | 90 | freigegebener 900-Request-Scale-Beweis |
| L4 | 55 | Owner-freigegebene Rubrik + Hosted-Gateway-Evidence |
| L5 | 56 | Owner-freigegebene Rubrik + Hosted-MCP-/Registry-/SBOM-/Scan-Evidence |
| Market Ready | false | alle Zellen 100 + realer Market-Ready-Verifier |
| Optik | bewusst zuletzt | Organismus-/Cortex-Bug und 3-Sterne-Look separat abnehmen |

## 8. Exakte Owner-Entscheidungen

### V0 - Rubrik

Erforderlich sind exakter Rubrik-Commit und vier ausdrueckliche Entscheidungen:

1. L4-Kriterien/Gewichte akzeptiert?
2. L5-Kriterien/Gewichte akzeptiert?
3. fehlende Hosted-Verifier unter den benannten Pfaden erlaubt?
4. darf erst nach deren Evidence-Readback Credit berechnet werden?

Bis dahin: `credit_application_allowed=false`, L4 55, L5 56.

### O1 - OAuth-Architektur

Waehlen:

- Cloudflare-native D1 + Durable Object im Zero-card-Pfad, oder
- ausdruecklich freigegebener Hosted FastAPI/PostgreSQL/Redis-Stack.

Der aktuelle Worker besitzt die Browser-OAuth-Routen nicht. Callback muss mit der
Frontend-Origin-/Cookie-Grenze uebereinstimmen. Details im OAuth-Fixplan.

### I1 - aktueller Hosted Candidate

Owner autorisiert den konkreten non-local HTTPS-Deploy. Source-/Image-/Browser-/State-/
Audit-/Rollback-Paritaet muss gegen denselben Kandidaten verifiziert werden.

### P6 - Scale

Owner autorisiert genau einen `-AllowHostedWrites`-Lauf mit exakt 900 Requests. Ohne diese
Freigabe: null Writes.

### O3 - GHCR

Owner loest den Policyzyklus:

- einmalige private kandidatengebundene Publikation ueber `registry-publication` mit
  Required Reviewer, ohne Deploy/Promotion, oder
- Rubrik/Policy macht Remote-Digests explizit post-market.

Keine Public-Schaltung.

### Production

Production-Deploy, Promotion, Rollout und Default-Branch-Write bleiben jeweils eigene
Freigaben nach Market-Ready.

Ein allgemeines `ja` oder ein Browser-Login ist keine dieser spezifischen Freigaben.

## 9. Naechster sicherer Ablauf

Autonom:

1. aktuellen Dokumentensatz pruefen und nur die eigenen Dokumentpfade committen;
2. `npm run verify:phase5-credit`;
3. `npm run verify:current-release-candidate`;
4. `py -3 scripts/verify_project_progress_manifest.py`;
5. Feature-Branch pushen;
6. CI auf finalem Head: success und `skipped=0` pruefen.

Nach Owner-Freigaben:

1. OAuth-ADR und Red-first-Implementierung;
2. aktueller source-gleicher Worker-/Vercel-Staging-Deploy;
3. Hosted OAuth/I1/Scale/L4/L5 Beweise;
4. neue Candidate-Qualifikation nach der letzten Runtime-Source-Aenderung;
5. finaler serieller Gate-Stack;
6. Optik ganz zuletzt.

## 10. Schutzregeln

- nie `git add -A`;
- kein Stash, Force-Push oder Default-Branch-Push;
- Playwright, Docker-Build und Verifier nie parallel;
- keine Frontend-Dateiaenderung waehrend eines Browserlaufs;
- keine Evidence nachbearbeiten;
- keine Secrets, Passwoerter, 2FA-, CAPTCHA- oder Zahlungsdaten ausgeben;
- `.phase1-artifacts/` und `docs/release-artifacts/` nicht aufraeumen;
- `PROJECT_STATE.md` nie allein aktualisieren.

Der erlaubte Qualification-Truth-Uebergang umfasst exakt:

```text
PROJECT_STATE.md
apps/frontend/lib/endpoint-snapshot.json
apps/frontend/lib/platform.ts
docs/project-progress.manifest.json
```

## 11. Fremde Dirty-Pfade bewahren

```text
.codex/runs/CURRENT/product-acceptance/report.json
.phase1-artifacts/o4-live-writes/proof.json
.phase1-artifacts/o4-live-writes/runtime-proof.json
.phase1-artifacts/o4-live-writes/browser-proof.json
docs/runtime-state/capability-gates.json
docs/runtime-state/external-gate-audit-v2.json
docs/runtime-state/external-gate-summary.json
docs/runtime-state/owner-input-manifest.json
docs/release-artifacts/prod-candidate-2026-08-02-local-rc12.md  (fremd gestaged)
```

Eigener uncommitteter Codepfad: `scripts/verify-phase1.ps1`.

## 12. Non-Claims

- kein Main-/Default-Branch-Push;
- kein GHCR-Push;
- kein Production-Deploy, keine Promotion, kein Rollout;
- kein Phase-6-Hosted-Write-Lauf;
- keine production OAuth identity;
- keine Rubrikaktivierung;
- kein Secret- oder Payment-Output;
- `MARKET_READY:false`.
