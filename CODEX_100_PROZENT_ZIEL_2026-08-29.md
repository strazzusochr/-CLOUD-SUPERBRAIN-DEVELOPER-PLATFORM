> **UEBERHOLT — NICHT ALS ZIEL- ODER UEBERGABEDATEI VERWENDEN.**
> Massgeblich sind ausschliesslich `CODEX_ZIEL_MASTER_2026-08-29.md` (was zu tun ist) und
> `CODEX_UEBERGABE_MASTER_2026-08-29.md` (was los ist). Diese Datei bleibt nur als
> historische Provenienz erhalten; ihre Koordinaten, Prozentwerte und Anweisungen sind
> nicht mehr gueltig. Stand der Markierung: 2026-08-30.

# CLOUD SUPERBRAIN - 100-PROZENT-ZIEL

Status: `PLAN_ONLY`
Credit-Anwendung: `false`
Stand: 2026-08-29
Ausgangswert: Overall `89%`
Marktstatus: `MARKET_READY:false`

Dieses Dokument plant den restlichen Weg. Es setzt keine Prozentzahl, oeffnet kein Gate,
autorisiert keinen Deploy und ersetzt keinen Verifier.

## 1. Definition des Endziels

Das Endziel ist erst erreicht, wenn gleichzeitig gilt:

1. jede horizontale Phase P0-P6 steht evidenzbasiert auf 100,
2. jeder vertikale Layer L1-L7 steht evidenzbasiert auf 100,
3. `npm run verify:market-ready` druckt real `MARKET_READY:true`,
4. der aktive Kandidat ist source-, image-, security-, runtime-, browser- und CI-gebunden,
5. alle erforderlichen Hosted-Beweise stammen von einem aktuellen, nicht-lokalen HTTPS-Stack,
6. die Projektwahrheit, Laufzeitspiegel und Release-Artefakte sind widerspruchsfrei,
7. kein Secret, Fake-Live-Wert oder unbewiesener Prozentcredit verwendet wurde.

`MARKET_READY:true` ist nicht gleich Production-Deploy. Release-Promotion und
Production-Rollout bleiben danach separate Owner-Entscheidungen.

## 2. Ausgangsmatrix und Restdelta

### Horizontal

| Zelle | Jetzt | Ziel | Restfaehigkeit |
|---|---:|---:|---|
| P0 | 100 | 100 | keine |
| P1 | 100 | 100 | keine |
| P2 | 100 | 100 | keine |
| P3 | 44 | 100 | production OAuth identity, gehostete Session-/Replay-Sicherheit |
| P4 | 100 | 100 | keine |
| P5 | 89 | 100 | I1 current hosted candidate parity und I5 production auth |
| P6 | 90 | 100 | genehmigter 900-Request-Scale-/Persistenzbeweis |

### Vertikal

| Zelle | Jetzt | Ziel | Restfaehigkeit |
|---|---:|---:|---|
| L1 | 100 | 100 | keine |
| L2 | 100 | 100 | keine |
| L3 | 100 | 100 | keine |
| L4 | 55 | 100 | freigegebene Rubrik plus aktuelle Hosted-Gateway-Beweise |
| L5 | 56 | 100 | freigegebene Rubrik plus Hosted-MCP-/Registry-/SBOM-/Scan-Beweise |
| L6 | 100 | 100 | keine |
| L7 | 100 | 100 | keine |

Horizontale und vertikale Punkte messen verschiedene Achsen. Sie werden nicht addiert und
nicht gegenseitig als Doppelcredit verwendet.

## 3. Binding der L4/L5-Rubrik

Quelle: `docs/runtime-contracts/layer-credit-rubric.md`

Aktueller Status:

- `DRAFT_OWNER_APPROVAL_REQUIRED`
- `credit_application_allowed=false`
- L4-Tabelle summiert 100
- L5-Tabelle summiert 100
- heutige Werte bleiben L4 `55`, L5 `56`

Eine wirksame Owner-Freigabe muss alle vier Punkte enthalten:

1. exakter Commit-SHA der freigegebenen Rubrik,
2. ausdrueckliches Ja zur L4-Tabelle und ihren Gewichten,
3. ausdrueckliches Ja zur L5-Tabelle und ihren Gewichten,
4. Freigabe, die benannten noch fehlenden Hosted-Verifier zu implementieren und nach
   erfolgreichem Evidence-Readback Credit anzuwenden.

Ein allgemeines `ja`, eine Konsolenfreigabe oder das Vorhandensein des Drafts reicht nicht.

## 4. Abhaengigkeitsgraph

```text
Rubrik-Commit + Owner-Freigabe
  -> fehlende L4/L5-Verifier implementieren
  -> aktuelle Hosted-Evidence erzeugen
  -> verifierberechneter L4/L5-Credit

OAuth-ADR
  -> Cloudflare-native Auth oder freigegebener Hosted FastAPI-Stack
  -> Frontend-/Backend-Source deployen
  -> 12-Schritt-Session-/Replay-Beweis
  -> P3 + I5

aktueller Hosted Candidate
  -> Source/Image/Runtime/Browser/Audit/Rollback-Paritaet
  -> I1

Owner-Freigabe Phase-6 Hosted Writes
  -> exakt 900 Requests
  -> p95/Fehler/Persistenz/Cleanup/Audit-Evidence
  -> P6

Owner-Ausnahme fuer private GHCR-Publikation
  -> sechs Remote-Digests + SBOM + Remote-Scan
  -> L5-Registryblock

letzte Runtime-Source-Aenderung
  -> neuer Source-Freeze (voraussichtlich RC22 oder spaeter)
  -> fuenf lokale Ketten
  -> source-attestierter CI-Lauf, keine skipped Steps
  -> finaler Market-Ready-Gate-Stack
```

## 5. Arbeitspakete bis 100

### G0 - aktuelle Wahrheit stabilisieren

Ziel:

- Dokumentensatz auf dem Feature-Branch committen und pushen,
- `npm run verify:phase5-credit`, `verify:current-release-candidate` und Manifest-Verifier
  gruen halten,
- roten Full-Verifier exakt dokumentieren,
- keine immutable RC21-Evidence mutieren.

Aktueller Blocker: Hosted Worker source-stale (`d0674bfc`) gegen den heutigen
`services/cloudflare-stateful-runtime`-Tree.

### G1 - Hosted Source-Paritaet wiederherstellen

Vorbedingung: explizite Owner-Freigabe fuer den konkreten Hosted Deploy; kein Production-Alias-
Wechsel und keine Release-Promotion.

Erforderlich:

1. Source-SHA fuer Worker und Vercel immutable festlegen.
2. Cloudflare-stateful Runtime und Vercel Preview/Staging auf denselben Source-Stand bringen.
3. Variablen bewahren; keine Secretwerte ausgeben.
4. Health, Source-SHA, Archive-/Deployment-Binding und negative Guards readback-pruefen.
5. Erst danach Hosted-Verifier starten; waehrenddessen nicht deployen.

Akzeptanz:

- `git diff --quiet <hosted-source-sha> -- services/cloudflare-stateful-runtime`
- `npm run verify` passiert den Worker-Source-Paritaetsguard
- Hosted `/api/v1/project/progress` spiegelt den beabsichtigten aktuellen Kandidatenstand,
  nicht den alten Wert 84

### G2 - Production OAuth Identity

Plan: `docs/runbooks/PRODUCTION_OAUTH_FIXPLAN_2026-08-29.md`

Vorbedingung: Owner waehlt die Auth-Architektur. Empfohlener Zero-card-Pfad ist
Cloudflare-native D1 + dedizierter `AuthCoordinator` Durable Object. Alternative ist nur ein
ausdruecklich freigegebener Hosted FastAPI/PostgreSQL/Redis-Stack. Eine kanonische
Browser-Callback-Origin sowie alle fuenf Konfigurationsnamen einschliesslich
`GITHUB_OAUTH_OWNER_IDS` muessen gebunden sein.

Akzeptanz:

- echter GitHub-Consent mit exakt `read:user`,
- numerische Owner-ID-Allowlist,
- einmaliger OAuth-State,
- persistiertes Audit vor Credential-Issuance,
- Access-/Refresh-Cookies korrekt gesichert,
- atomare Refresh-Rotation,
- Replay alt/Callback nachweislich gesperrt,
- Logout widerruft und wird auditiert,
- Callback, Refresh und Logout besitzen eine stabile redigierte Sessionketten-Korrelation,
- unauthentifiziertes `/auth/me` liefert 401, nicht 404 oder Projection-200,
- Source-SHAs von Frontend und Auth-Runtime sind kandidatengebunden.

Credit: erst nach dediziertem nicht-mutierendem Verifier, Hosted Evidence und einem
getrennten Owner-genehmigten Gate-Promoter; dann P3 und I5 nach ihrer kanonischen Rubrik,
ohne Doppelcredit.

### G3 - Current Hosted Candidate Parity (I1)

Erforderlich ist derselbe immutable Kandidat auf non-local HTTPS:

- sechs Images oder aequivalent gebundene immutable Deploy-Artefakte,
- Health und sichtbare Source-SHA,
- Prompt -> Agent API -> LLM Gateway -> Provider -> persistiertes Artefakt,
- reales WebGL, echte Interaktion, identischer Reload-Hash,
- `22/22`, `29/29`, `161/161`, keine toten Controls,
- D1/Queue/Durable-Object Create/Read/Conflict/Delete,
- negative Statuscodes 401/403/409/422,
- Request-/Trace-/Audit-Korrelation,
- realer Rollback auf Last-known-good und Requalifizierung.

Lokale RC21-Beweise duerfen nicht als Hosted-I1 wiederverwendet werden.

### G4 - Phase-6 Scale

Owner-Freigabe muss den exakten Worker, die Write-Scope-Grenze und den einen Verifierlauf
nennen. Ohne `-AllowHostedWrites` muss der Verifier bei null Requests blockieren.

Exakt 900 Requests:

| Laststufe | Requests |
|---|---:|
| Read Concurrency 1 | 60 |
| Read Concurrency 10 | 240 |
| Read Concurrency 50 | 500 |
| Write/Create mit serverseitigem Readback | 50 |
| authentifizierte Deletes/Cleanup | 50 |

Die Arithmetik ist exakt: `800 Reads + 50 Creates + 50 Deletes = 900`. Control-Requests
bleiben ausserhalb dieser Lastmenge und muessen unter dem kriterienspezifischen Cap bleiben.

Schwellen:

- Erfolgsquote mindestens 0,99
- schlechtester p95 hoechstens 1500 ms
- eigene 5xx exakt 0
- 50 eindeutige Records erstellt und gelesen
- 50 geloescht, aktiver Readback danach leer
- keine Duplikate oder Verluste
- persistiertes, SHA-256-gebundenes Audit

### G5 - L4 Hosted-Abschlussblock

Nur nach Rubrikfreigabe:

- source-gebundene generative Hosted-Erreichbarkeit,
- Stream-/Non-Stream-Semantikparitaet,
- Provider-Allowlist,
- begrenzter/auditierter Fallback,
- Budget-Guard vor Providercall,
- persistiertes Completion-Audit,
- Trace-Korrelation,
- 401/403, 422 und Policy-Negativpfade ohne Providercall.

Jeder Punkt benoetigt den im Rubrik-Draft benannten Verifier oder einen vom Owner freigegebenen
Nachfolger.

### G6 - L5 Hosted-/Registry-Abschlussblock

Nur nach Rubrikfreigabe:

- authentifizierter, scoped Hosted-MCP-Write,
- Timeout ohne Nachwirkung,
- Replay-Idempotenz,
- Audit vor und nach Write,
- serverseitiger Readback,
- Rollback bei Auditfehler,
- sechs immutable Remote-Digests,
- kandidatengebundenes SBOM,
- Remote-Secret-/Vulnerability-Scan,
- geschuetzter Workflow mit Environment-Review.

### G7 - GHCR-Policyzyklus aufloesen

Aktuell verbietet die Release-Policy Registry-Publish vor `MARKET_READY:true`, waehrend der
Draft fuer L5 Remote-Digests vor L5=100 verlangt. Das ist ein echter Owner-Zyklus.

Zwei erlaubte Entscheidungen:

1. bevorzugt: einmalige, private, kandidatengebundene GHCR-Publikation ueber
   `registry-publication` mit Required Reviewer, ohne Deploy oder Promotion;
2. Rubrik/Policy explizit so aendern, dass Remote-Digests post-market liegen und vorher kein
   Credit dafuer verlangt wird.

Nicht erlaubt: stiller Push, Public-Schaltung, generischer `GITHUB_TOKEN`-Bypass oder
Behauptung lokaler Image-IDs als Remote-Digests.

### G8 - neuer Kandidatenfreeze

OAuth, Hosted-Runtime- und Verifier-Code sind Runtime-Source-Aenderungen. RC21 darf deshalb
nicht als finaler Kandidat umetikettiert werden.

Vor dem Freeze muessen ausserdem drei heute bekannte Transition-Defekte Red-first behoben
werden:

1. `services/agent-api/app/main.py` und `apps/frontend/lib/endpoint-snapshot.json` muessen
   statt des geschlossenen Cloudflare-Gates die reale External-Audit-Missing-Menge spiegeln.
2. `scripts/verify_phase5_credit_itemization.py` darf I5 nach einem gueltigen Owner-Grant und
   source-gebundenen Proof nicht weiter hart auf `owner_granted=false` und
   `live_verified=false` festnageln.
3. `scripts/verify-market-ready.ps1` darf
   `auth_dedicated_non_mutating_verifier_unavailable` erst entfernen, wenn der dedizierte
   nicht-mutierende OAuth-Verifier existiert; seine Evidence muss Scope, One-Time-State,
   Callback-Replay, Refresh-Familien-Replay und Audit-before-credential explizit abdecken.

Nach der letzten Runtime-Source-Aenderung:

1. Projektwahrheit vor dem Freeze synchronisieren.
2. neuen Source-SHA festlegen.
3. sechs Candidate-Artefakte aus dem committed Archiv bauen.
4. Runtime, Browser, Candidate-Runtime, Security und Images strikt seriell beweisen.
5. O4 als letzten source-gebundenen Write-Beweis erneuern.
6. Control-Commit erzeugen und source-attestierten CI-Lauf ausfuehren.
7. `0 skipped` pruefen.
8. aktive Candidate-Auswahl und Readiness hashgebunden aktualisieren.

### G9 - finaler Gate-Stack

Serielle Reihenfolge nach dem finalen Source-Freeze:

```powershell
npm run build
npm run verify:runtime
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/start-dev-live.ps1
npm run verify:browser
npm run verify
npm run verify:release-boundary
npm run verify:current-release-candidate
npm run verify:release-candidate
npm run verify:market-ready:static
npm run verify:market-ready
```

Hosted-Verifier laufen nur gegen den freigegebenen aktuellen HTTPS-Kandidaten. Playwright,
Docker-Builds und Verifier laufen nicht parallel.

### G10 - Optik ganz zuletzt

Erst nach Funktion, Hosted-Ketten und Release-Gates:

- doppelten/kurz sichtbaren Cortex im Organismus reproduzieren und beseitigen,
- Organismus-Optik gegen `REGELN_OPTIK_UND_FERTIG.md` abnehmen,
- 3-Sterne-Look der generierten Spiele als eigener visueller Slice,
- visuelle Regression oder bildgebundene Abnahme einfuehren, falls der Owner sie freigibt.

Optik darf keine funktionalen Prozentgates verdecken oder vortaeuschen.

## 6. Evidence-/Verifier-Matrix

| Restkriterium | Pflicht-Evidence | Verifier/Entry Point | Gate-Owner |
|---|---|---|---|
| Hosted Worker Source-Paritaet | Deployment-Metadata, sichtbare Source-SHA, Tree-Paritaet | `npm run verify` | Owner fuer Deploy |
| P3 / I5 OAuth | Consent, Cookie-, Replay-, Audit- und Identity-Readback | neuer Hosted-OAuth-Verifier + `npm run verify:browser` | Owner + Codex |
| I1 Hosted Candidate | immutable Candidate, Browser, Runtime, State, Rollback | Hosted-Candidate-Verifier | Owner + Codex |
| P6 Scale | 900-Request-Report, p95, 5xx, Readback, Cleanup, Audit | `scripts/verify-phase6-scale-runtime.ps1` | Owner |
| L4 Rest | Rubrikzeilen einzeln mit Hosted Reports | Rubrik-Verifier | Owner fuer Rubrik |
| L5 Rest | Hosted-MCP, Remote-Digests, SBOM, Scans, Review | Rubrik-/Supply-Chain-Verifier | Owner fuer Rubrik/Publish |
| Candidate final | fuenf Ketten + CI-Attestation | Phase-5-Verifier | Codex; Owner nur externe Gates |
| Market Ready | alle Matrizen 100, External Gates | `npm run verify:market-ready` | geteilt |

## 7. Truth-Transition-Regel

`PROJECT_STATE.md` steht zugleich in Runtime-Source und Qualification-Truth. Es darf nach
einem Candidate-Freeze nie allein aktualisiert werden.

Ein Prozent-/Truth-Update erfolgt entweder vor dem neuen Source-Freeze oder als exakt
erlaubter Viereruebergang:

1. `PROJECT_STATE.md`
2. `apps/frontend/lib/endpoint-snapshot.json`
3. `apps/frontend/lib/platform.ts`
4. `docs/project-progress.manifest.json`

Prozente steigen nur nach Code, Laufzeitbeweis, Verifier und Doku-Evidence.

## 8. Stop-Gates

Explizite Owner-Freigabe bleibt erforderlich fuer:

- Rubrikaktivierung,
- Hosted Deploy/Env-/Secret-Aenderung,
- Production OAuth App/Scopes und Human Consent,
- Phase-6 Hosted Writes,
- GHCR-Publikation,
- Default-Branch-Write oder Merge,
- Production-Deploy, Promotion oder Rollout,
- Zahlung, Planwechsel oder kostenpflichtige Ressource.

Keine Freigabe wird aus einem allgemeinen `ja`, einem Login im Browser oder einem bereits
vorhandenen Secret abgeleitet.

## 9. Rollback und Abbruch

- Bei rotem Verifier: sofort anhalten, Ursache messen, keine Folgeschritte behaupten.
- Hosted Deploy: vorab Last-known-good Deployment-/Source-ID notieren.
- Candidate: RC21 bleibt immutable; RC20 ist sein dokumentierter Rollback.
- OAuth: bei Audit-/D1-/DO-Ausfall keine Credentials ausgeben.
- Scale: bei unerwarteten 5xx oder Scope-Drift abbrechen und Cleanup verifizieren.
- GHCR: Packages privat lassen; keine Sichtbarkeitsaenderung.

## 10. Abschlusskriterium

Das Dokument wird erst als erledigt markiert, wenn der reale Terminalauszug enthaelt:

```text
MARKET_READY: true
```

und die zugehoerigen manifest-, candidate-, hosted-, CI- und security-gebundenen Evidence-
Artefakte existieren. Bis dahin bleibt dieses Dokument `PLAN_ONLY`.
