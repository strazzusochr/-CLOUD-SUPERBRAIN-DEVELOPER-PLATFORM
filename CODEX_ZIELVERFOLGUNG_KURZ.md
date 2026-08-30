# ZIELVERFOLGUNG KURZ - STAND 2026-08-29

Status: `ACTIVE_CURRENT_TRUTH`
Branch: `codex/organism-visual-v2`
Market Status: `MARKET_READY:false`

Diese Datei ist nur ein synchroner Kurzspiegel. Einzige Zielautoritaet ist
`CODEX_ZIEL_MASTER_2026-08-29.md`; einzige Uebergabeautoritaet ist
`CODEX_UEBERGABE_MASTER_2026-08-29.md`.

Weitere Referenzen:

- aktuelle Uebergabe: `AI_HANDOFF.md#current-rc23-handoff--2026-08-29`
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
| eingefrorene Candidate Source | `7db18d907bcfa4f4b5a34b7c498fb2d91e3a2927` |
| source-attestation Control | `5cfbf1f4b8a70116985cb27d7b949f4e2aaf45b1` |
| gepushter Selection-Commit | `67cd698c6cff4f4230283bc5d2f91c3170f41485` |
| aktiver Kandidat | `prod-candidate-2026-08-29-local-rc23` |
| Qualifikations-CI | `33273326919`, success, `25/25` beobachtete Schritte gruen, `0` skipped |
| Selection-Head-CI | `33282524897`, success, `29/29`, `0` skipped, `0` failed |
| Evidence | exakt `27` immutable Dateien; 5 lokale Ketten + CI-Attestation/Readback |
| Readiness | `17/19 = 89%`; offen I1 und I5 |
| Rollback | RC22 Source `28727b198b057a6bdef6b5f34e9aa946fb2757a0` |

RC23 bleibt nach Auswahl immutable. Neue Runtime-Source-Aenderungen benoetigen einen neuen Kandidaten.

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

## 4. Seit RC22 erledigt / in RC23 gebunden

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
- GitHub Actions `33273326919`: exact source checkout, exaktes Vier-Dateien-Control-Delta,
  `25/25` beobachtete Job-Schritte gruen, `0 skipped`.
- exakt 27 Evidence-Dateien mit reproduzierten SHA-256-Werten gebunden.
- zweiter kompletter monolithischer Chromium-Lauf gruen: `22/22`, `29/29`, `161/161`,
  Working-Report SHA-256
  `4E844972CA953C03A76746B7E1AE49726215133B648B45EC813DF55D0EDB80948`.

`161/161` bedeutet sichtbare UI-Effektabdeckung, nicht 161 Backend- oder Layeraufrufe.
Responsive-Report-SHA: `723D2DEF1E3B98C25885E2F6242342EB02D2238CAC46D510A5F7E103AEED8E5B`.
Der generierte Working-Report unter `.codex/runs/CURRENT/product-acceptance/report.json`
bleibt ausserhalb des Selection-Commits; die kanonische RC23-Browser-Summary ist dagegen
source-gebunden und Teil des 27-Dateien-Sets. Alle lokalen Browser-/Runtimebeweise:
`DEV-ONLY; hosted proof still blocked`.

## 5. Letzter bindender Verifier

RC23-Qualifikation:

```text
PASS: five local chains on source 7db18d907bcfa4f4b5a34b7c498fb2d91e3a2927
PASS: GitHub Actions 33273326919 via control 5cfbf1f4b8a70116985cb27d7b949f4e2aaf45b1
PASS: exact 27-file evidence set
```

Post-selection real gemessen:

```text
PASS verify:phase5-credit -> 17/19, blocked I1/I5
PASS verify:current-release-candidate -> technical/source parity true, no-credit rebind true, promotion false
PASS verify_project_progress_manifest.py -> overall 89, deltas 0, mirrors 2
EXPECTED STOP npm run verify -> current Cloudflare-native hosted Worker source parity
PASS pr-check 33282524897 -> exact 67cd698c, 29/29, skipped=0, failed=0
```

A6/Selection aktuell:

```text
PASS endpoint snapshot -> 34/34, epoch_complete=true, current=false/prequalification
PASS go-live runtime -> blocked_external_gates (Branch Protection + GHCR)
PASS focused tests -> Agent API 95/95, Manifest 27/27, Snapshot 8/8
PASS verify_project_progress_manifest.py -> candidate_source_bound=true, freshness=verified
```

Der Full-Sweep-Stop ist der erwartete ungeschlossene Hosted-I1-Ownerblock und kein Fehler
der fuenf source-gebundenen lokalen RC23-Ketten. Hosted I1 und Production Auth I5 bleiben
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
- A2/A3-CI auf `4c20b4f6`: Run `33256222000`, `27/27` beobachtete Schritte gruen,
  `0 skipped`.

Keine Prozent-, Gate-, Hosted-, Deploy- oder Release-Transition. A4 folgt als naechster
Runtime-Contract-Punkt.

## 6c. A4 Team-Status lokal repariert

- Fresh Hosted-Readback vor dem Fix: Worker API-Pfad `500`, Worker-Alias `404`, stateless
  Contract Origin `500`, Frontend `200` mit der unvollstaendigen Projektion `roles=[]`.
- Worker-Source: beide GET-Aliase jetzt nativ `external_degraded`, exakt fuenf logische Rollen,
  kanonische Ausfuehrungsmap, fuenf `unavailable` Members, Queue `0` und
  `queue_depth_observed=false`.
- Nichtleere `dispatch_id` am zustandslosen Worker wird HTTP `404 dispatch_not_found` ohne
  Echo. Das Frontend blockiert unsichere IDs vor dem Proxy; gueltige UUIDv4 duerfen einen
  konfigurierten stateful Origin erreichen und fallen nur bei dessen Ausfall auf 404.
- Alle Provider-/MCP-Write-/Deploy-/Rollout-/Secret-Claims bleiben `false`.
- Red-first Worker `2` Fehler, danach Worker `28/28`; Frontend `5/5`, Lint, Build und statischer
  Worker-Verifier gruen.

Kein Deploy und keine Hosted-Umetikettierung: die Tabelle in Abschnitt 6 bleibt bis zu einem
freigegebenen source-gebundenen Deploy unveraendert. Overall/P3/P6/L4/L5 bleiben
`89/44/90/55/56`. Naechster autonomer Punkt: A5 Vercel-Origin-/OAuth-Ownership-Beweis.

## 6d. A5 Frontend-Origin und Auth-Evidence fail-closed gebunden

- Browser-UI, Same-Origin-Cookies und OAuth-Callback gehoeren zum Vercel-Projekt `frontend`;
  `cloud-superbrain-developer-platform` bleibt stateless read-only Contract Origin.
- Der Auth-Verifier akzeptiert nur die kanonische getrackte/saubere/hash-gebundene
  Frontend-Hosted-Evidence, den exakten Production-Alias, die feste Frontend-Projektidentitaet
  und einen existierenden Candidate-Ancestor.
- Human-Flow-Reihenfolge und Evidence-Schemas sind exakt; unbekannte oder secret-foermige
  Felder werden fail-closed abgewiesen.
- I5 verlangt zusaetzlich eine gehashte Owner-ADR plus architecture-spezifische Runtime-
  Evidence und einen dynamischen read-only Verifier. Erlaubte Auswahl:
  `cloudflare_native` oder `hosted_fastapi`.
- ADR, Hosted-Auth-Evidence und beide Runtime-Verifier fehlen absichtlich noch. Das ist der
  messbare Owner-/Implementierungsblock, kein stiller Default.
- Frontend-Hosted `-ValidateOnly` fuehrt volle Vercel-Metadata-/Alias-/Content-/Read-Pruefung
  ohne Browser-Rerun und ohne Proof-Write aus.
- Gruen: Auth `13/13`, Market/No-write `6/6`, OAuth `26/26`, Team `5/5`, PS-AST und Diff-Check.

Keine Provider-Writes, kein Deploy, kein Gate-/Prozent-/Release-Uebergang. Overall/P3/P6/L4/L5
bleiben `89/44/90/55/56`. Naechster autonomer Punkt: A6 Gate-/Summary-/Snapshot-/Freshness-
Paritaet Red-first und danach neue Candidate-Qualifikation.

## 6e. A6 Go-Live-Wahrheit und Candidate-Freshness lokal repariert

- Sechs kanonische External-Gates werden in Agent API und PowerShell-Verifier unabhaengig aus
  den sechs Boolean-Claims abgeleitet; Reihenfolge, Case, Eindeutigkeit, Status, Production-
  Claim und Provenienz sind fail-closed.
- Full Snapshot: `34/34`, `payload_epoch_complete=true`, `gate_atomic=true`; reservierte
  `__snapshot_metadata` und SHA-256 fuer Pointer, Candidate-Artefakt, Manifest und External-
  Gate-Summary. Mangels unabhaengiger Runtime-Source-Attestation bleibt er ehrlich
  `current=false/prequalification` und schreibt die DEV-Payloads nicht RC22 zu.
- Manifest-Freshness bindet Candidate-Schema, Phase-5-Release/Source/Timestamp, existierenden
  Ancestor und beide Runtime-Mirrors. Post-RC22-Runtime-Drift wird vor der neuen Qualifikation
  absichtlich abgewiesen.
- Read-only External-Gate-Refresh auf RC22-Selector bleibt `blocked`; offen sind exakt
  `github_branch_protection_current_verify` und `ghcr_image_digest_verify`.
  `active_release_candidate_sha` bleibt leer, Production bleibt false.
- Gruen: Go-Live `14/14`, Agent API `95/95`, Manifest `27/27`, Snapshot `8/8`, Frontend-
  Rewrite-Verifier, DEV-ONLY Go-Live-Runtime, AST/Compile und Diff-Check.

Kein Prozent- oder Gate-Credit: Overall/P3/P6/L4/L5 bleiben `89/44/90/55/56`; I1/I5 bleiben
geschlossen. A6 ist neue Source und benoetigt RC23 mit allen fuenf lokalen Ketten.
`DEV-ONLY; hosted proof still blocked`.

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

A1 bis A6 sind lokal abgeschlossen und bleiben ohne neuen Credit. Jetzt:

1. A6 plus synchrone Truth-Dateien exakt committen; fremden Working-Report ausschliessen;
2. Feature-Branch pushen und source-attestiertes CI lesen;
3. RC23 aus der finalen Source einfrieren;
4. Candidate-Images, Runtime, Browser/22-Seiten/O4, Candidate-Runtime und Security seriell;
5. erst nach vollstaendiger Evidence den separaten Selection-Commit erstellen.

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

Der vierteilige Qualification-Truth-Uebergang gilt ausschliesslich fuer den vom Phase-5-
Verifier erkannten post-qualification Mirror-Uebergang:

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
historischen, abgeschlossenen RC22-Selection-Slice. A6 darf diese Evidence nicht veraendern
oder umetikettieren. RC23 bekommt einen eigenen Source-Freeze, eigene fuenf Ketten, eigene
CI-Attestation, eigene Selection-Evidence und einen getrennten Selection-Commit. Keine
fremden Working-Reports stagen.

## 12. Non-Claims

- kein Main-/Default-Branch-Push;
- kein GHCR-Push;
- kein Production-Deploy, keine Promotion, kein Rollout;
- kein Phase-6-Hosted-Write-Lauf;
- keine production OAuth identity;
- keine Rubrikaktivierung;
- kein Secret- oder Payment-Output;
- `MARKET_READY:false`.
