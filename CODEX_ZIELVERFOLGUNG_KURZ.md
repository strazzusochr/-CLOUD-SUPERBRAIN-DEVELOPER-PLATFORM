# ZIELVERFOLGUNG KURZ - STAND 2026-08-29

Status: `ACTIVE_CURRENT_TRUTH`
Branch: `codex/organism-visual-v2`
Market Status: `MARKET_READY:false`

Diese Datei ist die kurze Steuerung. Details:

- aktuelle Uebergabe: `AI_HANDOFF.md#current-rc22-handoff--2026-08-29`
- Weg zu 100: `CODEX_100_PROZENT_ZIEL_2026-08-29.md`
- OAuth: `docs/runbooks/PRODUCTION_OAUTH_FIXPLAN_2026-08-29.md`
- Optikregeln: `REGELN_OPTIK_UND_FERTIG.md`
- RC21-Arbeitsauftrag/Historie: `AGENT_AUFTRAG_RC21_UND_RESTLISTE.md` (`HISTORICAL`)

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
| eingefrorene Candidate Source | `28727b198b057a6bdef6b5f34e9aa946fb2757a0` |
| source-attestation Control | `a7ea8ea27c640f5430977b86b115bbea9ad8464e` |
| aktiver Kandidat | `prod-candidate-2026-08-29-local-rc22` |
| Qualifikations-CI | `33248839880`, success, alle beobachteten Job-Schritte gruen |
| Evidence | exakt `27` immutable Dateien; 5 lokale Ketten + CI-Attestation/Readback |
| Readiness | `17/19 = 89%`; offen I1 und I5 |
| Rollback | RC21 Source `c1b022a884eb16939fe0542b2eb9056b60706b20` |

RC22 bleibt immutable. Neue Runtime-Source-Aenderungen benoetigen einen neuen Kandidaten.

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

## 4. Seit RC21 erledigt / in RC22 gebunden

- External-Gate-Claim-Set aus den exakten Claim-Flags abgeleitet; keine Duplikat- oder
  Case-Maskierung.
- I5-Transition fail-closed: Production-Auth-Credit nur nach dediziertem, getracktem,
  gehashtem, source-gebundenem Read-only-Verifier; Gate-Booleans allein reichen nicht.
- Phase-6-Netcode-Browserbeweis auf gemessenen SwiftShader-/Trace-Overhead stabilisiert;
  Produktzustandsmaschine unveraendert.
- lokaler Build `21/21`, Runtime `10/10 healthy`, sechs Clean-Archive-Images und
  candidate-runtime real selection/click gruen.
- kompletter lokaler Browser-Umbrella gruen: echter Cloudflare-Workers-AI-Build,
  `22/22` Routen, `29/29` Familien, `161/161` Aktionen, Phase-6-Ketten und O4
  Audit/Readback/Rollback; keine Mocks, Interceptions, Console-/Page-Fehler.
- candidate-scoped npm audit und canonical gitleaks gruen.
- GitHub Actions `33248839880`: exact source checkout, single-path Control-Delta,
  alle beobachteten Job-Schritte gruen.
- exakt 27 Evidence-Dateien mit reproduzierten SHA-256-Werten gebunden.

`161/161` bedeutet sichtbare UI-Effektabdeckung, nicht 161 Backend- oder Layeraufrufe.
Responsive-Report-SHA: `723D2DEF1E3B98C25885E2F6242342EB02D2238CAC46D510A5F7E103AEED8E5B`.
Der generierte Working-Report unter `.codex/runs/CURRENT/product-acceptance/report.json`
bleibt ausserhalb des Selection-Commits; die kanonische RC22-Browser-Summary ist dagegen
source-gebunden und Teil des 27-Dateien-Sets. Alle lokalen Browser-/Runtimebeweise:
`DEV-ONLY; hosted proof still blocked`.

## 5. Letzter bindender Verifier

RC22-Qualifikation:

```text
PASS: five local chains on source 28727b198b057a6bdef6b5f34e9aa946fb2757a0
PASS: GitHub Actions 33248839880 via control a7ea8ea27c640f5430977b86b115bbea9ad8464e
PASS: exact 27-file evidence set
```

Post-selection real gemessen:

```text
PASS verify:phase5-credit -> 17/19, blocked I1/I5
PASS verify:current-release-candidate -> technical/source parity true, promotion false
PASS verify_project_progress_manifest.py -> overall 89, deltas 0, mirrors 2
FAIL npm run verify -> current Cloudflare-native hosted Worker source parity
```

Der Full-Sweep-Stop ist der erwartete ungeschlossene Hosted-I1-Ownerblock und kein Fehler
der fuenf source-gebundenen lokalen RC22-Ketten. Hosted I1 und Production Auth I5 bleiben
rot. Kein Full-Sweep-Gruen wird behauptet; Verifier nicht abschwaechen.

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

Die fruehere Missing-Gate-Claim-Drift wurde in RC22 Red-first repariert. Hosted Readbacks
sind weiterhin kein RC22-Paritaetsbeweis und koennen I1 nicht schliessen.

## 6a. A1 Delta-Ledger-Probelauf abgeschlossen

- Red-first: synthetisches P3-Delta gegen v1 wurde erwartungsgemaess abgewiesen.
- Aktiv: `project-progress-delta-ledger-v2`; kanonische `entries=[]` und alle Prozente
  bleiben unveraendert.
- Replay bindet jede kuenftige Erhoehung an exakte Zelle, alte/neue Projektion,
  Source-Commit/Ancestor-Kette, committed Evidence-SHA und einen fest allowlisteten
  zellenspezifischen Scorer.
- Die produktive Allowlist ist absichtlich leer: der bestehende P5-Verifier ist kein
  evidence-only/source-commit-kompatibler Delta-Scorer. P3/P5/P6/L4/L5 bleiben ohne
  eigenen Evidence-Scorer technisch nicht kreditierbar.
- Gruen: Replay-Regression `22/22`, kombinierte Five-Axis-Regression `6/6`,
  fresh-checkout-safe Ledger-Integration `4/4`, realer Five-Axis-Audit,
  Main-Deploy-Transition, Manifest `89% / deltas=0 / mirrors=2`.
- Full Sweep: weiterhin ausschliesslich rot an Hosted-Worker-Source-Paritaet (I1).

Naechster autonomer Punkt: A2 als `DRAFT_OWNER_APPROVAL_REQUIRED`; null Credit.

## 6b. A2/A3 Rubrikentwuerfe abgeschlossen

- P3: `44 + 56 = 100` itemisiert; Status bleibt `DRAFT_OWNER_APPROVAL_REQUIRED`.
- P6: `90 + 10 = 100` itemisiert; der Hosted-Block bleibt atomar und unaktiviert.
- P6-Laufgrenze: `900` Worker + `244` Edge-Kontrolle = `1.144` HTTP-Requests.
- Die geordnete 22-Eintraege-Blocked-Multimenge und beide absichtlichen Duplikate bleiben
  unveraendert.
- Read-only-Verifier + Regression: `13/13` gruen; `credit_applied=false`.
- A1-CI auf `d5bdad62f159bbc0a401fcedf2e324def77e6657`: Run `33253659212`,
  `26/26` beobachtete Schritte gruen, `0 skipped`.

Keine Prozent-, Gate-, Hosted-, Deploy- oder Release-Transition. Naechster autonomer Punkt:
A4 `/api/v1/team/status` im Worker Red-first reparieren.

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

1. A1-Checkpoint explizit committen und nur den Feature-Branch pushen; generierten
   ungebundenen Working-Report ausschliessen;
2. A2 P3-Rubrik als Owner-gated Null-Credit-Draft;
3. A3 P6-Rubrik als Owner-gated Null-Credit-Draft;
4. A4 `/team/status` Red-first/Fix;
5. A5 Vercel-Origin-Entscheidungspaket ohne Provider-Write;
6. A6 verbleibende Summary-/Snapshot-/Freshness-Paritaet Red-first fuer einen neuen
   Kandidaten; den bereits in RC22 geschlossenen Altdefekt nicht erneut reparieren.

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

## 11. Dirty-/Evidence-Schutz

```text
.codex/runs/CURRENT/product-acceptance/report.json
.codex/runs/CURRENT/master-goal/phase5/**
apps/frontend/test-results/**
apps/frontend/playwright-report/**
```

Die drei O4-Proofs, `capability-gates.json`, `owner-input-manifest.json`, die RC22-Note,
Readiness, das 27-Dateien-Set und die synchronisierten Truth-Dokumente gehoeren zum
expliziten RC22-Selection-Slice. Keine anderen Pfade stagen.

## 12. Non-Claims

- kein Main-/Default-Branch-Push;
- kein GHCR-Push;
- kein Production-Deploy, keine Promotion, kein Rollout;
- kein Phase-6-Hosted-Write-Lauf;
- keine production OAuth identity;
- keine Rubrikaktivierung;
- kein Secret- oder Payment-Output;
- `MARKET_READY:false`.
