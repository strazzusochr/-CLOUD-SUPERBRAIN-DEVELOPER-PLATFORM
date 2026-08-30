# CODEX ZIEL-MASTER — STAND 2026-08-29

Status: `ACTIVE_CURRENT_TRUTH`
Branch: `codex/organism-visual-v2`
Truth-Ref: gepushter Selection-Commit `67cd698c`; eingefrorene Candidate-Source `7db18d90`
Market Status: `MARKET_READY:false`

**Dies ist die einzige Zieldatei.** Sie sagt, was zu tun ist.
Die Lage steht in `CODEX_UEBERGABE_MASTER_2026-08-29.md`.

Alles hier ist **gemessen**, nicht aus einem Protokoll uebernommen. Wo etwas nur
protokolliert und nicht nachmessbar war, steht das ausdruecklich dabei.
Ersetzt und vereint: `CODEX_ZIELVERFOLGUNG_KURZ.md`,
`CODEX_100_PROZENT_ZIEL_2026-08-29.md`, `CODEX_AUFTRAG_GESAMTANALYSE_2026-08-29.md`,
`docs/runbooks/PRODUCTION_OAUTH_FIXPLAN_2026-08-29.md`.

---

## 0. Aktueller Rebind — 2026-08-30

Dieser Abschnitt ersetzt alle zeitabhaengigen Koordinaten und erledigt/offen-Angaben der
darunter erhaltenen Messung auf `a7ff9714`. Die Strukturblocker und Owner-Gates bleiben
weiter bindend, soweit sie hier nicht ausdruecklich aktualisiert werden.

- RC23 `prod-candidate-2026-08-29-local-rc23` ist lokal an Source
  `7db18d907bcfa4f4b5a34b7c498fb2d91e3a2927` qualifiziert. Kontroll-Commit
  `5cfbf1f4b8a70116985cb27d7b949f4e2aaf45b1`; GitHub Actions `33273326919`:
  `25/25` beobachtete Schritte gruen, `0` skipped, exakter Source-Checkout attestiert.
- Alle fuenf unabhaengigen lokalen Ketten sind source-gebunden gruen. Das unveraenderliche
  Evidence-Set enthaelt exakt `27` Dateien. Phase-5 bleibt `17/19 = 89`; nur I1/I5 offen.
- A1 bis A6 des historischen Plans sind erledigt. Zusaetzlich ist der generierte Game-TDZ-
  Guard in Source `7db18d90` gebunden und mit `20/20` Regressionstests sowie echter
  Browserausfuehrung belegt.
- Post-Selection fokussiert gruen: `verify:phase5-credit`,
  `verify:current-release-candidate` und `verify_project_progress_manifest.py`.
- Der finale lokale `npm run verify`-Sweep ist bis zum exakten externen Stop gruen und endet
  erst bei `current Cloudflare-native hosted Worker source parity`. Das ist der unveraenderte
  I1/B5-C1-Blocker, kein lokaler Testfehler. Der Current-Candidate-Verifier akzeptiert den
  bereits streng durch Phase-5 validierten, exakt dreipfadigen No-Credit-Rebind jetzt
  fail-closed; Teilmengen oder Zusatzpfade bleiben verboten.
- Selection-Commit `67cd698c6cff4f4230283bc5d2f91c3170f41485` ist auf den Feature-Branch
  gepusht. Final-Head-CI `33282524897` attestierte exakt diesen SHA und bestand `29/29`
  Schritte, `0` skipped, `0` failed. Ein nachfolgender reiner Doku-Freeze-Commit gilt nur
  nach einem nochmals gruenen Head-`pr-check`; dessen Run-ID wird nicht in denselben Commit
  zurueckgeschrieben, damit keine endlose Folge rein dokumentarischer Heads entsteht.
- Erster Doku-Freeze `6a62e28af18f4692a93641bbe9bfecf00c73ffa6` ist gepusht und durch
  `pr-check` `33282746874` mit `29/29`, `0` skipped, `0` failed belegt. Fuer jeden
  spaeteren reinen Truth-Sync gilt dauerhaft statt einer selbstreferenziellen Run-ID:
  `git rev-parse origin/codex/organism-visual-v2` muss exakt dem `headSha` des neuesten
  abgeschlossenen `pr-check` mit `conclusion=success`, `skipped=0`, `failed=0` entsprechen.
- Browser-Pass 1 ist kanonisch gruen (`22/22`, `29/29`, `161/161`). Der erste sichtbare
  headed Pass 2 bestand 159 direkte Aktionen plus den exakten P0-Beweis; der einzige
  `replay-organism-performance-reset`-Deltatiming-Fehler wurde durch den anschliessenden
  sichtbaren exakten Scoreboard/Performance/Reset-Test (`1/1`) isoliert widerlegt. Der danach
  neu gestartete monolithische Pass 2 bestand vollstaendig in `39,1` Minuten: `22/22`
  Routen, `29/29` Familien, `161/161` Aktionen (`160` direkt, `1` exakt vorverifiziert),
  zwei freigegebene echte Gateway-Providerantworten, keine Mocks/Interceptions,
  unerwarteten Providerpfade, Console-/Page-Fehler oder Secret-Ausgabe. Working-Report SHA-256:
  `4E844972CA953C03A76746B7E1AE49726215133B648B45EC813DF55D0EDB80948`.
- Overall/Horizontal/Vertikal bleiben exakt `89` sowie die unten dokumentierten Werte.
  `MARKET_READY:false`; `DEV-ONLY; hosted proof still blocked`.
- Read-only Gate-/Hosted-Reaudit `2026-08-30T00:31Z`: `B1=F | B2=F | B3=F | B4=F |
  B5=F`. Worker bleibt auf `d0674bfc`, damit `108` Commits hinter Candidate-Source
  `7db18d90` und `111` hinter dem damaligen Branch-Head `6a62e28a`; Progress bleibt `84`,
  Team-Status `500`, Auth-Vertrag im alten Dry-run-Modus, OAuth nicht konfiguriert.
- C1/C2-Praezisierung aus Live-Beweis: Ein reiner Worker-Source-Rebind kann die native
  Team-Route reparieren, aber weder Progress `89` noch Production OAuth liefern, solange
  `CONTRACT_ORIGIN` weiter auf den veralteten Backend-Stand `21913f8c` zeigt. C2 braucht
  zusaetzlich einen current source-bound Contract-Origin-Rebind/Deploy oder eine explizit
  verifizierte native Worker-Projektion. Beides bleibt Teil der expliziten Hosted-/OAuth-
  Freigaben, nicht autonome Arbeit.
- B3 ist auch strukturell geschlossen: Environment `phase6-scale-hosted-writes` fehlt live
  (`404`), das benoetigte Secret ist nicht nachweisbar und der Workflow ist auf dem Default-
  Branch nicht registriert. B4 ist nicht dispatchbar: `registry-publication` ist nur
  konfiguriert, Default-Branch fuehrt noch den alten `main-deploy`-Blob `555e8325`, waehrend
  der sichere Feature-Blob `14e84b31` Owner-autorisiert auf den geschuetzten Default-
  Kontrollstand gelangen muss.

Aktueller autonomer Rest vor jedem Owner-Gate: kein Implementierungsitem. Ein reiner
Truth-Sync gilt erst nach Erfuellung der oben definierten dynamischen Head-CI-Bedingung.
Danach bleiben ausschliesslich die expliziten Owner-/Hosted-Stufen B bis H.

Danach bleiben ausschliesslich die expliziten Owner-/Hosted-Stufen B bis H. Kein Main-
Push, GHCR-Push, Hosted-Deploy, OAuth-Gate-Flip oder Production-Rollout ist dadurch erlaubt.

## 1. Endziel

`npm run verify:market-ready` druckt real:

```text
MARKET_READY: true
```

Dafuer muessen beide Matrizen evidenzbasiert 100 sein. Production-Deploy und
Release-Promotion bleiben danach **separate** Owner-Entscheidungen.

## 2. Fortschritt und Restdelta

```text
Overall 89

Horizontal:  P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 89 | P6 90
Vertikal:    L1 100 | L2 100 | L3 100 | L4 55 | L5 56 | L6 100 | L7 100
```

| Zelle | Heute | Rest | Abschlussbedingung |
|---|---:|---:|---|
| P3 | 44 | **+56** | 8 binaere Rubrikzeilen, alle hosted OAuth (Rubrik existiert, nicht freigegeben) |
| P5 | 89 | +11 | genau zwei Items: I1 `hosted_candidate_parity`, I5 `production_auth_identity` |
| P6 | 90 | +10 | 3 binaere Zeilen P6-H01/H02/H03, alle hosted Scale-Writes |
| L4 | 55 | +45 | Rubrikfreigabe + 5 fehlende Hosted-LLM-Verifier |
| L5 | 56 | +44 | Rubrikfreigabe + 5 fehlende Hosted-MCP/SBOM-Verifier |
| Optik | — | — | bewusst zuletzt: Cortex-Bug und 3-Sterne-Look separat |

**Rechenregel:** `overall = round(sum(7 Phasen)/7)`
(`scripts/verify_project_progress_manifest.py:151`). Layerarbeit ist wichtig,
bewegt die 89 aber **nie**. Keine Prozentanhebung durch Doku, Konsolenwerte oder
Wiederholung bereits kreditierter Beweise.

**166 offene Punkte gesamt.** 99 davon (L4 45 + L5 44 + P6 10) haengen an einer
einzigen Wurzelbedingung: der Hosted Worker laeuft hinter HEAD (B5/C1).

---

## 3. Die fuenf Strukturblocker — Stand gemessen

### B1 — Kriterienkataloge existieren, sind aber nicht freigegeben — TEILWEISE GELOEST

Drei Rubriken liegen jetzt vor, alle unter `docs/runtime-contracts/`:

| Datei | Zelle | Status | Credit-Anwendung |
|---|---|---|---|
| `phase3-credit-rubric.md` | P3 | `DRAFT_OWNER_APPROVAL_REQUIRED` | `false` |
| `phase6-credit-rubric.md` | P6 | `DRAFT_OWNER_APPROVAL_REQUIRED` | `false` |
| `layer-credit-rubric.md` | L4/L5 | `DRAFT_OWNER_APPROVAL_REQUIRED` | `false` |

Die Spezifikationsluecke ist geschlossen. Es fehlt ausschliesslich die
Owner-Freigabe (Stufe B). Ohne sie darf kein Punkt aus diesen Rubriken
kreditiert werden.

**P3 — die 8 offenen Zeilen, Summe 56** (`44` bleibt historischer Gesamtblock):

| ID | Kriterium | Pkt |
|---|---|---:|
| P3-01 | Hosted OAuth-Start: echte freigegebene `client_id`, exakt Scope `read:user`, kryptographischer One-Time-State | 8 |
| P3-02 | Hosted Callback tauscht echten Code gegen verifizierte numerische GitHub-Identitaet, Session erst danach | 12 |
| P3-03 | Owner-Allowlist bindet die numerische Identitaet fail-closed | 8 |
| P3-04 | State-Cookie `__Host-`/`Secure`/`HttpOnly`/`SameSite=Lax`; Auth-Cookies `SameSite=Strict`, kein `Domain`, freigegebene TTL | 6 |
| P3-05 | Refresh rotiert atomar; Replay -> exakt `401`, widerruft die Tokenfamilie | 8 |
| P3-06 | Logout widerruft genau einen aktiven Refresh-Token, loescht beide Cookies, persistiert Audit, Post-Logout-Refresh `401` | 6 |
| P3-07 | Callback-Replay und State-Reuse fail-closed abgewiesen | 4 |
| P3-08 | Auditkette request-/session-korreliert, vor Credential-Ausgabe persistiert, ohne Codes/State/Tokens/Cookies/Secrets | 4 |

**P6 — die 3 offenen Zeilen, Summe 10:**

| ID | Kriterium | Pkt |
|---|---|---:|
| P6-H01 | Exakt 800 Hosted Reads in drei Stufen (`60@1`, `240@10`, `500@50`) | 3 |
| P6-H02 | Exakt 50 authentisierte D1-Creates bei Concurrency `10`, ohne Verlust/Duplikat, vollstaendiger Readback | 3 |
| P6-H03 | Exakt 50 auditierte Deletes, `soft_delete_then_active_row_absence_and_audit_readback`, vollstaendiger Cleanup | 2 |

Die restlichen 2 Punkte liegen in der P6-Rubrik auf p95/5xx/Requestzahl.

### B2 — Die L4/L5-Rubrik benennt 10 Verifier, die nicht existieren — UNVERAENDERT

Einzeln gegen den Truth-Ref geprueft, **alle 10 fehlen**:

```
verify-llm-hosted-stream-parity.ps1          verify-mcp-hosted-write.ps1
verify-llm-hosted-fallback.ps1               verify-mcp-hosted-auth-scope.ps1
verify-llm-hosted-budget-guard.ps1           verify-mcp-hosted-timeout-idempotency.ps1
verify-llm-hosted-trace-correlation.ps1      verify-mcp-hosted-audit-readback-rollback.ps1
verify-llm-hosted-negative-guards.ps1        verify-mcp-candidate-sbom.ps1
```

L4 +45 und L5 +44 sind zu 100 % Neubau, nicht Nachweis.

### B3 — P5-Codepin — TEILWEISE GELOEST, I1 bleibt gepinnt

Frueherer Stand: `CURRENT_BLOCKED_IDS = {"I1","I5"}` plus harte Zusicherung
`require(computed_percent == 89)`. Beides ist **weg**.

Aktueller Stand, `scripts/verify_phase5_credit_itemization.py`:

```python
:44   BASELINE_BLOCKED_IDS = {"I1"}

:277  def expected_blocked_ids(*, auth_transition_verified: bool) -> set[str]:
:278      blocked = set(BASELINE_BLOCKED_IDS)
:280      if not auth_transition_verified: blocked.add("I5")
:281      return blocked

:1593 computed_percent = rounded_binary_percent(verified_count, len(items))
:1604 require(computed_percent == expected_percent, ...)
:1633 require(phase5.get("percent") == computed_percent, ...)
```

Daraus folgt exakt, ohne Auslegung:

- **I5 ist evidenzgetrieben.** Sobald das Capability-Gate `production_auth_identity`
  `owner_granted` **und** `live_verified` traegt (plus `paid_provider:false` und
  gesetzte `owner_grant_ref`), verschwindet I5 aus `expected_blocked`.
  **Kein Codewechsel noetig.** P5 geht dann 89 -> **95** (18/19).
- **I1 ist weiterhin hart gepinnt.** `I1` steht in `BASELINE_BLOCKED_IDS` und wird
  an keiner Stelle je entfernt (`blocked.add` existiert, `discard`/`remove` nicht).
  Fuer I1 braucht es den Beweis **und** die Aenderung der Konstante — sonst schlaegt
  `computed_percent == expected_percent` fehl. Erst dann 95 -> **100**.

**Das ist eine Korrektur an einer frueheren Fassung dieser Datei**, die B3 als
vollstaendig geloest und I1 als beweisgenuegend bezeichnet hat. Gegenprobe:

```bash
grep -nE "BASELINE_BLOCKED_IDS|blocked\.(add|discard|remove)" scripts/verify_phase5_credit_itemization.py
```

Zaehlprobe: `rounded_binary_percent = floor(v*100/19 + 0.5)` -> 17/19 = 89,
18/19 = 95, 19/19 = 100.

### B4 — Der Delta-Ledger wurde nie benutzt — UNVERAENDERT

```
docs/runtime-state/project-progress-delta-ledger.json
  contract_version = project-progress-delta-ledger-v2
  entries          = 0
```

Das Schema ist auf v2 gehoben, der Mechanismus bleibt **null mal erprobt**. Er
ist der einzige sanktionierte Weg, eine Manifestzelle zu bewegen, gebunden an
`BASELINE_SOURCE_SHA = 9a3776ff`. Der erste echte Kreditversuch waere zugleich
der erste Test des Mechanismus — deshalb steht A1 vor allem anderen.

**Praezisierung:** Die Prozentwerte in `CANONICAL_HORIZONTAL` /
`CANONICAL_VERTICAL` sind **kein** Deckel auf das aktuelle Manifest. Die
Pruefschleife verwirft die Prozentspalte (`_`) und prueft nur `0 <= v <= 100`.
Sie beschreiben ausschliesslich den eingefrorenen Baseline-Commit.

### B5 — Hosted laeuft hinter HEAD — VERSCHLECHTERT: 106 Commits

`d0674bfc` (Hosted) vs `a7ff9714` (Truth-HEAD). Bei der urspruenglichen Analyse
waren es 86. Wurzelbedingung fuer **99 der 166 offenen Punkte** plus P5-I1 und
den hosted Teil von P3.

Live gemessen, unauthentifizierte GET:

```text
worker /api/v1/health            200   source_commit_sha = d0674bfc   d1_read_verified = true
worker /api/v1/project/progress  200   overall_percent = 84   (Repo: 89)
worker /api/v1/team/status       500
worker /api/v1/auth/callback     503   stateless_contract_origin_read_only
```

---

## 4. Kritischer Pfad

```
A1 Ledger-Probelauf ──┐
A5 / A6 ──────────────┴─> autonom, keine Freigabe noetig

B1 Rubriken freigeben ─┐
B2 OAuth-ADR ──────────┤
B3 P6-Environment ─────┤
B4 GHCR-Dispatch ──────┤
B5 + C1 Worker auf HEAD┼─> D OAuth   ──> P3 100, P5-I5  (P5 = 95)
   (Wurzel fuer 99 Pkt)├─> E L4/L5   ──> L4 100, L5 100
                       ├─> F Scale   ──> P6 100
                       └─> G GHCR/I1 ──> P5 100 (Codewechsel noetig)
                                            └─> H overall 100
```

**Engpass 1: C1** — Worker auf HEAD redeployen. Entsperrt 99 Punkte auf einmal,
braucht keinen neuen Code. Er ist seit der Analyse **nicht** ausgefuehrt worden,
und der Abstand ist von 86 auf 106 Commits gewachsen.

**Engpass 2: B2** — OAuth-ADR. Ohne sie ist der groesste Rest (P3 +56) nicht startbar.

---

## 5. Arbeitspakete

### STUFE A — autonom, ohne Owner ausfuehrbar

**A1 · Delta-Ledger-Probelauf** — zuerst, alles Weitere baut darauf auf.
Red-first-Test mit synthetischem Delta-Eintrag gegen die Schema-`const`-Baseline;
`verify_project_progress_manifest.py` muss Hash-, Baseline- und Ancestor-Pruefung
greifen lassen. Negativfaelle: falscher `source_sha`, falscher Projection-Hash,
Zelle ausserhalb 0-100, Summe passt nicht zu `overall`. Eintrag danach entfernen.
**Kein Prozentwert wird veraendert.**

**A2 · P3-Kriterienkatalog — ERLEDIGT.**
`docs/runtime-contracts/phase3-credit-rubric.md` existiert, Summe 100,
`DRAFT_OWNER_APPROVAL_REQUIRED`. Nichts mehr zu tun; wartet auf B1.

**A3 · P6-Kriterienkatalog — ERLEDIGT.**
`docs/runtime-contracts/phase6-credit-rubric.md` existiert, Summe 100,
`DRAFT_OWNER_APPROVAL_REQUIRED`. Die 22 `*_blocked`-Eintraege sind **absichtliche
Nichtziele** und bleiben korrekt draussen. Wartet auf B1.

**A4 · `/api/v1/team/status` = 500 — erst nach C1 als Defekt behandeln.**
Der 500er ist gegen das **veraltete** Deployment gemessen. Die Route existiert im
aktuellen Quellcode (`services/cloudflare-stateful-runtime/src/index.js:33`,
`AUTONOMOUS_TEAM_STATUS_PATHS`). Reihenfolge: erst C1, dann neu messen. Nur wenn
der 500er dann bleibt, ist es ein echter Codedefekt — sonst war es Staleness.
Ein Fix vor C1 waere Arbeit an einer Diagnose, die noch nicht steht.

**A5 · Vercel-Origin-Widerspruch** — der Worker reicht an
`cloud-superbrain-developer-platform.vercel.app` durch, die OAuth-Variablen wurden
im Projekt `frontend` gepflegt. Entscheiden und dokumentieren, nicht raten.

**A6 · Stale Gate-Name im Kandidatenpfad** —
`services/agent-api/app/main.py:7455` fuehrt im Exception-Zweig
`active_target_gate: cloudflare_native_zero_card_hosted_runtime`. Dieses Gate ist
inzwischen **geschlossen** (`owner_granted` und `live_verified` beide `true`).
Real offen ist nur `ghcr_image_digest_verify`. Wirkung begrenzt — der Pfad ist ein
Fehlerzweig, kein Normalpfad; entsprechend niedrig priorisieren, aber richtigstellen.

### STUFE B — Owner-Entscheidungen (blockieren alles Weitere)

| ID | Entscheidung | Blockiert |
|---|---|---|
| **B1** | Die drei Rubriken freigeben (`DRAFT_OWNER_APPROVAL_REQUIRED` -> approved, Freigabecommit benennen) | P3 +56, P6 +10, L4 +45, L5 +44 |
| **B2** | OAuth-ADR: **Option A** Cloudflare-native (Zero-card, empfohlen) oder **Option B** Hosted FastAPI + PostgreSQL + Redis | gesamter OAuth-Strang |
| **B3** | Konsole: Environment `phase6-scale-hosted-writes` anlegen **und Environment-Secret `AGENT_API_AUTH_TOKEN` setzen** | P6 +10 |
| **B4** | Konsole: `main-deploy` dispatchen, `registry-publication` freigeben | letztes External Gate |
| **B5** | Explizite Hosted-Deploy-Freigabe fuer C1 (kein Production-Alias) | 99 Punkte |

**Zu B3 — der uebersehene zwoelfte Konsolenpunkt:**
`.github/workflows/phase6-scale-runtime.yml:28` verlangt
`environment: phase6-scale-hosted-writes`; `:41` prueft dessen
`AGENT_API_AUTH_TOKEN`. GitHub legt ein referenziertes Environment beim Lauf
implizit an — **ohne Secrets**. Der Owner-Gate-Check (`:67`) faellt dann
fail-closed, bevor ein Request rausgeht. **P6 ist ohne B3 nicht ausfuehrbar.**

**Zu B4 — kein Deadlock.** `scripts/verify-main-deploy-transition.ps1:56-68`
fuehrt `market_ready` in der Liste **verbotener** Tokens
(`forbidden legacy or runtime-release token is absent`). Die Kandidatenpublikation
setzt `MARKET_READY:true` also **nicht** voraus. Sie braucht nur Owner-Dispatch
plus Reviewer-Freigabe. Gegenprobe jederzeit:

```powershell
Select-String -Path .\scripts\verify-main-deploy-transition.ps1 -Pattern 'market_ready'
```

Ein allgemeines "ja" oder ein Browser-Login ist **keine** dieser Freigaben.

### STUFE C — Hosted-Source-Paritaet (Wurzel fuer 99 Punkte + I1)

**C1** Worker aus dem aktuellen Kandidaten-Commit neu deployen,
`SOURCE_COMMIT_SHA` und `SOURCE_ARCHIVE_SHA256` neu binden, `/api/v1/health` muss
den neuen SHA melden. Vorbedingung: B5.

**C2** Danach muss `/api/v1/project/progress` 89 melden, `snapshot_stale=false`,
und `/api/v1/team/status` neu gemessen werden (siehe A4).

### STUFE D — Production OAuth (P3 +56 und P5-I5)

Erst nach B2. Bei Option A:

1. **D1** Worker-Auth-Oberflaeche implementieren: `GET /api/v1/auth/github`
   (echter `client_id`, One-Time-State in D1) und `GET /api/v1/auth/callback`
   (Code-Tausch, Identitaetsbindung, Session). Beide fehlen — der Worker kennt nur
   `auth/sessions{,/verify,/revoke}`
   (`services/cloudflare-stateful-runtime/src/index.js:2057-2059`); alles Uebrige
   faellt auf `CONTRACT_ORIGIN` durch.
2. **D2** Die 4 fehlenden Worker-Variablen setzen: `GITHUB_OAUTH_CLIENT_ID`,
   `GITHUB_OAUTH_REDIRECT_URI`, `GITHUB_OAUTH_OWNER_IDS`, `JWT_SIGNING_SECRET`
   (vorhanden sind nur `AGENT_API_AUTH_TOKEN` und `GITHUB_OAUTH_CLIENT_SECRET`).
3. **D3** `production_auth_identity.owner_granted = true` — erst **nach**
   bewiesenem Callback, nie vorher. `live_verified` niemals von Hand.
4. **D4** Echte Browserabnahme mit Handklicks: privates Fenster, `/login`,
   "Mit GitHub anmelden"; erster Versuch **Cancel** (erwartet 401, State geloescht);
   zweiter Versuch Scope zeigt nur `read:user`; Owner klickt Authorize selbst
   (Passwort/2FA/CAPTCHA bleiben beim Owner); Callback beweist echte GitHub-ID,
   konsumierten One-Time-State und persistiertes Audit; Reload behaelt Session;
   Refresh rotiert; alter Token -> 401; Callback-Replay scheitert; Logout widerruft
   und auditiert.

Ergebnis bei Erfolg: P3-Rubrikzeilen erfuellt (nach B1 kreditierbar) und
P5-I5 faellt weg -> **P5 = 95**.

### STUFE E — L4/L5-Hosted-Verifier (10 Skripte, +89 Punkte)

Erst nach B1 und C1, je Skript red-first, dann Hosted-Lauf:

```
L4  stream-parity 10 · negative-guards 7 · fallback 3 · budget-guard 3 ·
    trace-correlation 4 · generativer Hosted-Beweis 10 · Routing+Audit nach Rebind 8
L5  hosted-write 10 · auth-scope 6 · timeout-idempotency 4 ·
    audit-readback-rollback 10 · SBOM 3 · Digest+Scan+approvierter Lauf 11
```

### STUFE F — Phase-6-Scale (+10)

Erst nach B3 und C1. Exakt 900 Worker-Requests: 60 Reads @1, 240 @10, 500 @50,
50 parallele `POST /api/v1/builds` @10, serverseitiger D1-Readback je Datensatz,
50 authentifizierte DELETEs.
Erfolg: Quote >= 0,99 · p95 <= 1500 ms · eigene 5xx = 0 · 50 erstellt/eindeutig/
geloescht · Verlust 0 · Duplikate 0 · Cleanup vollstaendig · Audit persistiert ·
Evidence SHA-256-gebunden. Token nur im Prozess-Environment, nie in Ausgabe.

### STUFE G — GHCR, I1 und der P5-Uebergang

1. **G1** Nach B4: sechs unveraenderliche SHA-Digests fuer frontend, agent-api,
   agent-worker, memory-worker, mcp-gateway, llm-gateway. Schliesst
   `ghcr_image_digest_verify` — das letzte External Gate.
2. **G2** Kandidatengebundenes Hosted-Staging mit **denselben** Digests -> **I1**.
   Hier werden auch die **6 stillgelegten P5-Beweise** neu erbracht.
3. **G3** Nach D4 -> **I5**. Rein evidenzgetrieben, kein Codewechsel.
4. **G4** Erst wenn I1 real belegt ist: Readiness-Zeilen auf 19/19 "JA",
   Itemization `blocked_owner` -> `verified`, **und im selben Zug**
   `BASELINE_BLOCKED_IDS = {"I1"}` -> `set()` in
   `scripts/verify_phase5_credit_itemization.py`. Ohne diesen Codewechsel bleibt
   `expected_percent` bei 95 und `require(computed_percent == expected_percent)`
   schlaegt fehl. Fuer I5 gilt das **nicht** — dort genuegt der Beweis.

### STUFE H — Abschluss

1. Delta-Ledger-Eintraege je bewegter Zelle (Mechanismus in A1 erprobt).
2. Manifest: P3 100, P5 100, P6 100, L4 100, L5 100 -> `overall = 100`.
3. Wahrheitsdateien synchronisieren: `PROJECT_STATE.md`, `AI_HANDOFF.md`,
   `docs/verification-register.md`, `LAYER_MATRIX.md`, `docs/screen-inventory.md`,
   diese Datei.
4. Finaler serieller Gate-Stack, dann
   `pwsh -NoProfile -File .\scripts\verify-market-ready.ps1 -IncludeExternalGates`.
5. Optik ganz zuletzt: Cortex-Bug und 3-Sterne-Look.

---

## 6. Naechster sicherer Ablauf ohne jede Freigabe

Der aktuelle Ablauf steht verbindlich in Abschnitt 0. A1, A5 und A6 sind inzwischen
erledigt; die alte Reihenfolge wird nicht erneut ausgefuehrt. Vor den Owner-Gates fehlen
nur noch Master-Sync,
Selection-Commit, Feature-Push und final-head CI mit `skipped=0`.

## 7. Schutzregeln

- nie `git add -A`; exakte Pathspecs; nie `git commit` ohne Pathspec;
- kein Stash, kein Force-Push, kein Default-Branch-Push;
- Playwright, Docker-Build und Verifier **nie parallel**;
- keine Frontend-Dateiaenderung waehrend eines Browserlaufs;
- keine Evidence nachbearbeiten;
- keine Secrets, Passwoerter, 2FA-, CAPTCHA- oder Zahlungsdaten ausgeben;
- `.phase1-artifacts/` und `docs/release-artifacts/` nicht aufraeumen;
- `PROJECT_STATE.md` nie allein aktualisieren;
- `TEMP`/`TMP` = `D:\_sb_tmp` vor Verifierlaeufen;
- Verifier nie abschwaechen, um gruen zu werden;
- die 22 P6- und 2 P3-`*_blocked`-Eintraege sind **absichtliche Grenzen** und
  duerfen nicht "geschlossen" werden;
- `live_verified` niemals von Hand setzen;
- solange ein RC an einem SourceSha eingefroren ist: kein neuer Runtime-Source-Commit.
  Ein separater verifier-akzeptierter Qualification-Truth-/Selection-Commit darf den
  eingefrorenen SourceSha, immutable Evidence, Pointer und Truth-Dokumente binden, solange
  `runtime_source_parity=true` bleibt und keine Runtime-Source-Pfade geaendert werden.

Der historische Vier-Pfade-Prequalification-Uebergang war:

```text
PROJECT_STATE.md
apps/frontend/lib/endpoint-snapshot.json
apps/frontend/lib/platform.ts
docs/project-progress.manifest.json
```

Die abschliessende Selection darf zusaetzlich nur das immutable Evidence-Set, Readiness,
Candidate-Pointer, verifier-generierte O4-Gate-Wahrheit und die synchronen Master-/Handoff-
Dokumente enthalten. `git add -A` bleibt verboten.

## 8. Fremde Dirty-Pfade bewahren

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

**Eigene uncommittete Pfade** (nachgeprueft, nicht fremd — duerfen bearbeitet werden):

```text
scripts/verify-phase1.ps1        Claim-Flag-basierter External-Gate-Set-Fix
AI_HANDOFF.md                    +63 Zeilen Cross-Audit-Abschnitt
CODEX_ZIELVERFOLGUNG_KURZ.md     +38 Zeilen Cross-Audit-Abschnitt
```

Die beiden Dokumentaenderungen verweisen noch auf `0a6277b8` und den alten
Dokumentensatz. Sie sind durch diese Datei und die Uebergabe **ueberholt**.

## 9. Non-Claims

- kein Main-/Default-Branch-Push;
- kein GHCR-Push;
- kein Production-Deploy, keine Promotion, kein Rollout;
- kein Phase-6-Hosted-Write-Lauf;
- keine production OAuth identity;
- keine Rubrikaktivierung;
- kein Secret- oder Payment-Output;
- `MARKET_READY:false`;
- `DEV-ONLY; hosted proof still blocked.`
