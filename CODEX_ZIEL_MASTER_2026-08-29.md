# CODEX ZIEL-MASTER — MARKTREIFE-ZIELVERFOLGUNG

Status: `ACTIVE_CURRENT_TRUTH`
Stand: **2026-08-31**
Branch: `codex/organism-visual-v2`
Measurement-Ref: **`8adb6183`** (Truth-Doku; Runtime-/Candidate-Source unveraendert)
RC24 Qualification Source: **`1cb03979`** · Control: **`d016e4b9`** · Selection: **`378a66bf`**
Hosted Worker: **`bc0f4dc8`** — acht Commits hinter RC24-Source
Market Status: `MARKET_READY:false` — Overall `89`, Delta-Ledger `0`

**Dies ist die einzige Zieldatei.** Sie sagt, *was zu tun ist*.
Die Lage steht in `CODEX_UEBERGABE_MASTER_2026-08-29.md`.

> Der Dateiname bleibt bewusst auf `2026-08-29` stehen, damit Codex genau eine Zieldatei und
> genau eine Uebergabe findet. Massgeblich ist das Feld `Stand` oben.

**Vorrangregel.** Im Repository liegen weitere `CODEX_*.md` aus historischen Gruenden.
Gueltig sind ausschliesslich diese beiden Dateien. Ueberholt und im Kopf markiert sind
`CODEX_100_PROZENT_ZIEL_2026-08-29.md`, `CODEX_ZIELVERFOLGUNG_KURZ.md`,
`CODEX_UEBERGABE_2026-08-29-SESSION16.md`, `CODEX_MASTER_GOAL_AUTONOM_WEITER.md` und
`CODEX_MASTER_GOAL_FINALE.md`.

**Diese Fassung ist vollstaendig neu geschrieben.** Sie enthaelt keine ueberholten Stufen
mehr. Alles, was hier steht, ist gegen `8adb6183`, gegen D1 oder gegen den Live-Endpunkt
gemessen.

---

## 1. Endziel

`pwsh -NoProfile -File .\scripts\verify-market-ready.ps1 -IncludeExternalGates` druckt real:

```text
MARKET_READY: true
```

Beide Matrizen **evidenzbasiert** 100. Production-Deploy und Release-Promotion bleiben
danach **separate** Owner-Entscheidungen.

---

## 2. Restdelta

```text
Horizontal:  P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 89 | P6 90
Vertikal:    L1 100 | L2 100 | L3 100 | L4 55 | L5 56 | L6 100 | L7 100
Delta-Ledger: 0 Eintraege
```

| Zelle | Rest | Was jetzt konkret fehlt |
| --- | ---: | --- |
| P3 | **+56** | OAuth-Kette ist hosted gefahren. Es fehlen **5 von 12** Evidence-Schritten, das Evidence-Dokument und B1. |
| P5 | **+11** | `I5` faellt evidenzgetrieben nach P3. `I1` braucht Hosted-Candidate-Paritaet **plus** Codeaenderung. |
| P6 | **+10** | Verifier ist scharf, aber Environment und Secret fehlen (B3). Der alte 900er-Lauf zaehlt nicht. |
| L4 | **+45** | Verifier sind jetzt **echt**. Es fehlen B1-Approval-Commit, Source-Rebind und die realen Hosted-Laeufe. |
| L5 | **+44** | Dito, inkl. echtem SBOM. |

**166 offene Punkte.** `overall = round(sum(7 Phasen)/7)`
(`scripts/verify_project_progress_manifest.py:328`). L4/L5 sind Pflicht fuer die vertikale
100, bewegen die 89 aber **nie**.

---

## 3. Kritischer Pfad

```text
S1  B1  Rubriken freigeben  ──────────────┐  HARTER ENGPASS
      (Approval-COMMIT, nicht nur Text)   │  ohne ihn laufen die L4/L5-Verifier gar nicht
                                          │
S2  B5 + Hosted-Rebind auf RC24-Source ───┤  Voraussetzung fuer jeden Hosted-Beweis
                                          │
      ├─> S3  L4/L5 Hosted-Laeufe ────────┼──> L4 +45, L5 +44
      │                                   │
      ├─> S4  P3-Evidence vervollstaendigen ──> P3 +56 ──> P5-I5   (braucht B2)
      │                                   │
      ├─> S5  P6-Scale mit echtem Verifier ──> P6 +10              (braucht B3)
      │                                   │
      └─> S6  I1: Candidate-Paritaet + Codepin ──> P5 100          (braucht B4/GHCR)
                                          │
                          S7  Delta-Ledger buchen ──> Finalstack ──> MARKET_READY
```

**Engpass ist jetzt B1, nicht mehr der Deploy.** Die zehn Verifier verlangen
`-RubricApprovalCommit` als 40-stelligen Git-Commit, der **Ancestor der Kandidatenquelle**
sein muss, und sie lesen den freigegebenen Rubriktext aus genau diesem Commit. Ohne einen
solchen Commit brechen sie fail-closed ab — es gibt keinen Umweg.

---

## 4. Was bereits erledigt ist — nicht wiederholen

- **F1/F2 sind live.** Deployment `6bf89fc8`, Source-Bindung gesetzt und geprueft.
  `GITHUB_OAUTH_REDIRECT_URI` zeigt auf den Worker-Callback und stimmt mit der GitHub-App
  ueberein (Wildcard aus, Scope `read:user`).
- **Die OAuth-Kette ist hosted gefahren** — der Owner hat einmal Authorize geklickt.
  Serverseitig in D1 belegt: Cancel fail-closed, Authorize mit `identity_verified` und
  `oauth_state_consumed`, Familie `subject=github:237145441`, Refresh `rotated`, Logout
  `revoked` mit `revocation_reason=user_logout`, danach `me=401`/`refresh=401`.
  **Der teure Teil ist erbracht.**
- **RC24 ist lokal qualifiziert**: fuenf Ketten gruen, 27-Dateien-Evidence-Set,
  CI `33359506266` `30/30`, Selection-CI `33369934779` `30/30`, Browser `22/22`/`29/29`/`161/161`.
- **Die zehn L4/L5-Verifier sind echte Skripte** (88–307 Zeilen statt 43–69), mit
  Pflichtparametern, Owner-Grant-Pruefung gegen `capability-gates.json`, Rubrik-Bindung und
  echten Hosted-Operationen inklusive Readback. Dazu neuer Worker-Code
  (`src/mcp-hosted.js`, Migrationen 0006/0008).
- **`scripts/deploy-cloudflare-stateful-runtime.ps1`** ist der einzige zugelassene
  Deploy-Pfad und verhindert den Var-Verlust strukturell.

---

## 5. Die Stufen im Detail

### S1 — B1: Rubriken freigeben (harter Engpass)

Drei Dateien unter `docs/runtime-contracts/` stehen auf
`DRAFT_OWNER_APPROVAL_REQUIRED` mit `Credit-Anwendung erlaubt: false`:
`phase3-credit-rubric.md`, `phase6-credit-rubric.md`, `layer-credit-rubric.md`.

**Die Freigabe ist ein Commit, kein Satz.** Die Verifier prüfen:

```text
-RubricApprovalCommit  muss ^[0-9a-f]{40}$ sein
                       muss ein existierender Commit sein
                       muss Ancestor von ExpectedSourceCommitSha sein
                       der Rubriktext wird aus GENAU diesem Commit gelesen
Contract-Feld rubric_approval_sha  muss identisch sein
```

Praktisch: Status auf approved setzen, Freigabe-Referenz eintragen, committen — und diesen
Commit-SHA danach in jeden Verifier-Aufruf und in jedes Evidence-Dokument geben. Der
Freigabe-Commit muss **vor** der Kandidatenquelle liegen, an der die Verifier laufen; bei
RC25 also zuerst freigeben, dann einfrieren.

**Kredit:** keiner. B1 macht Kredit nur *moeglich*.

### S2 — B5 und Hosted-Rebind auf die RC24-Source

Der Worker laeuft auf `bc0f4dc8`, RC24-Source ist `1cb03979`. Acht Commits Abstand, darunter
neuer Worker-Code (`mcp-hosted.js`) und die Migrationen 0006/0008. Solange das so bleibt,
kann kein L4/L5-Verifier Source-Paritaet feststellen.

```powershell
Set-Location <RC24-Arbeitsbaum>
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
Get-Content 'C:\Users\immer\.codex\secrets\cloud-superbrain.local.env' | ForEach-Object {
  if ($_ -match '^(CLOUDFLARE_API_TOKEN|CLOUDFLARE_ACCOUNT_ID)=(.*)$') {
    Set-Item -Path "env:$($Matches[1])" -Value ($Matches[2].Trim().Trim('"').Trim("'"))
  }
}
pwsh -NoProfile -File .\scripts\deploy-cloudflare-stateful-runtime.ps1 -CommitSha 1cb03979740859f0350cf18f6f08ef06c3d72b72
```

**Vorher:** D1-Migrationen 0006 und 0008 remote anwenden, sonst laeuft der neue Worker gegen
ein Schema, das die MCP-Write-Tabellen nicht hat.

**Abnahme:** `/api/v1/health` meldet `source_commit_sha = 1cb03979...` und den passenden
`source_archive_sha256`. Das Skript prueft das selbst.

**Kredit:** keiner. Voraussetzung fuer S3 bis S6.

**Erwartung daempfen:** `/api/v1/project/progress` bleibt bei `84` — siehe §7.

### S3 — L4/L5: die zehn Verifier hosted fahren (+45 / +44)

Erst nach S1 und S2. Jeder Verifier braucht mindestens:

```text
-ExpectedSourceCommitSha 1cb03979...
-ExpectedSourceBundleSha256 <64 hex>
-OwnerGrantRef <exakte Referenz aus capability-gates.json>
-RubricApprovalCommit <40 hex aus S1>
```

Der Verifier prueft zusaetzlich, dass das passende Gate in
`docs/runtime-state/capability-gates.json` `owner_granted = true` traegt **und** die
`owner_grant_ref` exakt uebereinstimmt. Beispiel `verify-mcp-hosted-write.ps1`: Gate
`live_mcp_writes`, Evidence-Felder `write_performed`, `readback_verified`,
`immutable_receipt_verified`, `channel_state_current`, `audit_persisted`,
`audit_fail_closed`, `rollback_on_audit_failure`, `live_mcp_writes`; Contract-Phasen
`bounded_write`, `server_readback`, `audit_prewrite`, `audit_postwrite`.

Nur der Erfolgspfad setzt `credit_eligible = $true`. Ein blockierter Lauf schreibt
`credit_eligible = $false` — dann **nicht** kreditieren, sondern die Ursache beheben.

**Kredit:** L4 `55 -> 100`, L5 `56 -> 100`.

### S4 — P3 vervollstaendigen und Evidence schreiben (+56, danach I5)

`scripts/verify-production-auth-identity-evidence.ps1 -ValidateOnly -EvidencePath <pfad>
-ExpectedCandidateSha <40 hex>` verlangt `production-auth-identity-proof-v1` mit **exakten**
Feldmengen — unbekannte Felder lassen ihn ebenso scheitern wie fehlende.

**Die zwoelf Kettenschritte** in `human_flow_verified_steps`:

```text
bewiesen   github_cancel_no_credentials     github_authorize_owner_identity
           callback_one_time_state          auth_me_verified_identity
           refresh_atomic_rotation          logout_revocation_audited
           post_logout_refresh_rejected

offen      anonymous_login_no_identity      github_start_exact_query
           reload_session_continuity        old_refresh_replay_rejected
           callback_replay_rejected
```

`old_refresh_replay_rejected` ist der anspruchsvollste: der **alte** Refresh-Token muss nach
der Rotation erneut gesendet werden. Aus dem Browser geht das nicht — die Cookies sind
`HttpOnly` und werden bei der Rotation ersetzt. Es braucht einen Client, der den
`Set-Cookie`-Wert vor der Rotation mitschneidet und danach replayt (`curl` mit Cookie-Jar
oder ein Playwright-Kontext).

**25 Felder muessen `true` sein**, darunter `hosted_https`, `real_browser`,
`oauth_scope_exact_read_user_verified`, `callback_replay_rejected_verified`,
`refresh_family_replay_rejected_verified`, `audit_before_credential_verified`,
`rollback_verified`, `unauthenticated_me_401_verified`, `cookie_policy_verified`,
`owner_numeric_id_allowlist_verified`, `source_parity_verified`,
`request_session_audit_correlation_verified`, `redaction_verified`,
`branch_protection_verified`, `secret_scan_verified`, `live_github_oauth_call`.
**Vier muessen `false` sein:** `dev_only`, `secret_output`, `gate_promotion_performed`,
`verifier_mutations_performed`.

**`source_binding` verlangt drei Mal denselben Kandidaten-SHA:**

```text
source_commit_sha == frontend_source_commit_sha == auth_runtime_source_commit_sha == ExpectedCandidateSha
deployment_id     == auth_runtime_deployment_id
immutable_frontend_deployment_verified     = true
immutable_auth_runtime_deployment_verified = true
```

Das heisst: **auch das Vercel-Frontend muss aus demselben Commit unveraenderlich deployt
sein**, nicht nur der Worker. Dazu Hash-gebundene Referenzen auf
`docs/runtime-state/frontend-hosted-current.json`, auf ein Auth-Runtime-Evidence-Dokument
und auf eine **Owner-Architekturentscheidung** (`owner_architecture_decision_ref` mit
`owner_approved` und `selected_architecture`) — das ist **B2**.

**Kredit:** P3 `44 -> 100`. Danach faellt `I5` automatisch, weil `expected_blocked_ids` es
rein evidenzgetrieben behandelt (`verify_phase5_credit_itemization.py:290`). P5 geht auf
`95` (18/19).

### S5 — P6: 900 Requests mit dem zugelassenen Verifier (+10)

Voraussetzung **B3**: GitHub-Environment `phase6-scale-hosted-writes` existiert, enthaelt
das Secret `AGENT_API_AUTH_TOKEN`, und `.github/workflows/phase6-scale-runtime.yml` liegt
auf dem **Default-Branch**. Alle drei Teile sind noetig, nicht zwei.

Der vorhandene 900er-Lauf zaehlt **nicht** — er lief am Verifier vorbei, waehrend das Gate
`phase6_scale_runtime` auf `owner_granted=false` stand, und liefert weder D1-Readback noch
No-Loss/No-Duplicate-Zaehlung noch Cleanup-Semantik noch Control-Tier.

Gegen `docs/runtime-state/phase6-scale-criterion.json` (v2):

```text
Reads   60 @ concurrency 1 | 240 @ 10 | 500 @ 50
Writes  50 x POST /api/v1/builds @ 10, serverseitiger D1-Readback je Record
Deletes 50 authentifiziert, soft_delete_then_active_row_absence_and_audit_readback
Control /cdn-cgi/trace, separates Budget, max 500
Gesamt  exakt 900 Worker-Requests
```

Bestehen: Quote >= `0.99`, p95 <= `1500 ms`, eigene 5xx = `0`, 50 erstellt/eindeutig/
geloescht, Verlust `0`, Duplikate `0`, Cleanup vollstaendig, Audit persistiert, Evidence
SHA-256-gebunden. `429` ist **nur** auf Health-Read-Tiers zulaessig und muss fail-closed
sein. Der Token gehoert ausschliesslich ins Prozess-Environment.

**Kredit:** P6 `90 -> 100`.

### S6 — I1 und der P5-Abschluss

1. **B4** freigeben: gehaerteten `main-deploy`-Blob auf den Default-Branch bringen, dann
   Candidate dispatchen und `registry-publication` freigeben. Sechs unveraenderliche
   SHA-Digests fuer frontend, agent-api, agent-worker, memory-worker, mcp-gateway,
   llm-gateway. Das schliesst `ghcr_image_digest_verify` — das letzte External Gate.
   **Kein Deadlock:** `scripts/verify-main-deploy-transition.ps1:63` fuehrt `market_ready`
   in der Liste **verbotener** Tokens; die Publikation setzt `MARKET_READY:true` nicht voraus.
2. Kandidatgebundenes Hosted-Staging mit **denselben** Digests -> das ist I1.
3. **Erst danach** die Codeaenderung:

```python
# scripts/verify_phase5_credit_itemization.py:44
BASELINE_BLOCKED_IDS = set()      # war: {"I1"}
```

Ohne sie bleibt `expected_percent` bei 95 und `require(computed_percent == expected_percent)`
schlaegt fehl. Fuer `I5` gilt das **nicht** — dort genuegt der Beweis.

**Kredit:** P5 `95 -> 100` (19/19).

### S7 — Delta-Ledger und Finalstack

`docs/runtime-state/project-progress-delta-ledger.json` ist der **einzige** zugelassene Weg,
eine Manifestzelle zu bewegen. `entries = 0`, `baseline.source_sha = 9a3776ff`.

Der synthetische Protokoll-Probelauf ist am Measurement-Ref `8adb6183` erledigt:
`py -3 -m unittest scripts.tests.test_verify_project_progress_manifest -v` bestand
`27/27`. Er akzeptiert den source-gebundenen P3-Replay und weist unter anderem falschen
`source_sha`, Nicht-Ancestor, falschen Projection-Hash, Prozent ueber 100, falschen
`overall`, alte Prozent-/Baseline-Kette, fehlende oder hash-abweichende Artefakte sowie
nicht approvierte/fehlgeschlagene/timeoutende Scorer fail-closed ab. Das reale Ledger blieb
unveraendert leer; kein Prozentwert wurde bewegt. Der erste **reale Kredit** bleibt damit
weiterhin die erste Production-Anwendung des Mechanismus, aber nicht mehr dessen erster
Protokolltest.

Je bewegter Zelle **ein** SHA-gebundener Eintrag. Danach muss
`py -3 scripts/verify_project_progress_manifest.py` die neuen Werte akzeptieren. **Niemals**
einen Prozentwert direkt im Manifest setzen.

Finalstack, streng seriell:

```powershell
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'; $env:PYTHONUTF8='1'
npm run verify
npm run verify:runtime
pwsh -NoProfile -File .\scripts\start-dev-live.ps1
npm run verify:browser
npm run verify:csrf
npm run verify:responsive
npm run verify:frontend-hosted-current
npm run verify:backend-hosted-current
npm run verify:phase5-credit
npm run verify:current-release-candidate
npm run verify:release-candidate
npm run verify:external-gates
pwsh -NoProfile -File .\scripts\verify-market-ready.ps1 -IncludeExternalGates
```

Zielausgabe muss **real** sein: `MARKET_READY: true`, Overall `100`, alle Zellen `100`,
Ledger enthaelt die legitimen Eintraege, Hosted-SHA = Kandidatenquelle, keine
`OWNER_BLOCKED` mehr.

---

## 6. Owner-Gates

| Gate | Entscheidung | Blockiert |
| --- | --- | --- |
| **B1** | Die drei Rubriken freigeben — **als Commit**, dessen SHA jeder Verifier bekommt | L4 +45, L5 +44, P3 +56, P6 +10 |
| **B2** | OAuth-ADR festschreiben (`owner_architecture_decision_ref`, `owner_approved`, `selected_architecture`) | P3-Evidence |
| **B3** | Environment `phase6-scale-hosted-writes` + Secret `AGENT_API_AUTH_TOKEN` + Workflow auf Default-Branch | P6 +10 |
| **B4** | `main-deploy`-Blob auf Default, dispatchen, `registry-publication` freigeben | GHCR / I1 |
| **B5** | Hosted-Deploy-Freigabe fuer Worker **und** Vercel-Frontend aus derselben Quelle | S2, S4 |

### Drei Waende, die keine Freigabe verschiebt

1. **Der GitHub-Authorize-Klick** braucht Passwort und 2FA des Owners. *Fuer die aktuelle
   Kette bereits erledigt* — bei einem neuen Kandidaten faellt er erneut an.
2. **Secret-Werte in Konsolen-Felder eintippen** ist einem Agenten kategorisch untersagt.
3. **Die Deploy-Sperre der Claude-Code-Harness** — Codex hat sie nicht, der Owner kann sie
   per Permission-Regel aufheben oder den Befehl selbst ausfuehren.

---

## 7. Der offene Architekturpunkt: drei Origins

`/api/v1/project/progress` liefert hosted `84` statt `89`. **Kein Worker-Deploy aendert
das.** Der Worker hat keine native Progress-Route; alles Unbekannte faellt auf
`CONTRACT_ORIGIN` durch (`src/index.js:2011`), und dieser Origin meldet selbst `degraded`
und `84`.

```text
Frontend   frontend-seven-psi-78.vercel.app
Backend    cloud-superbrain-developer-platform.vercel.app   (= CONTRACT_ORIGIN, degraded)
Session    cloud-superbrain-stateful-runtime.strazzusochr.workers.dev
```

Drei Origins, und `__Host-`-Cookies gelten nur auf einem davon. Dieselbe Wurzel erklaert,
warum der Login zeitweise in einem 404 endete und warum ein Nutzer auf einer Frontend-Seite
nicht als angemeldet erscheinen kann. Zwei saubere Wege, beide Owner-Entscheidung:

- **A** — den Contract-Origin source-gebunden neu deployen, oder
- **B** — eine native Progress-Projektion in den Worker bauen und `CONTRACT_ORIGIN` fuer
  diese Route nicht mehr benutzen; Frontend-Pfade ueber den Worker routen.

`source_binding` in S4 verlangt ohnehin ein Frontend-Deployment aus derselben Quelle — diese
Entscheidung laesst sich also nicht umgehen.

---

## 8. Schutzregeln — bindend

- nie `git add -A`; immer exakte Pathspecs; nie `git commit` ohne Pathspec
- kein `git stash`, kein Force-Push, kein Push auf `chore/repo-bootstrap`
- Playwright, Docker-Build und Verifier **nie parallel**
- keine Frontend-Datei aendern, waehrend ein Browserlauf laeuft
- Evidence nie nachbearbeiten; `.phase1-artifacts/` und `docs/release-artifacts/` nie
  aufraeumen
- `live_verified` **niemals** von Hand setzen
- Verifier **nie** abschwaechen, um gruen zu werden
- keine Secrets in Ausgabe, Log oder Commit
- fremde Dirty-Pfade weder stagen noch zuruecksetzen
- Worker **nur** ueber `scripts/deploy-cloudflare-stateful-runtime.ps1` deployen
- `PYTHONUTF8=1` vor jedem Python-Verifier, `TEMP`/`TMP` auf `D:\_sb_tmp`
- solange ein RC eingefroren ist: kein neuer Produktcode-Commit

---

## 9. Was ausdruecklich verboten bleibt

Ein Kredit ohne den zugehoerigen echten Beweis ist Fake-Done. Konkret heute:

- **Keinen L4/L5-Verifier kreditieren, der `credit_eligible = false` schreibt.**
- Den alten 900er-Lauf **nicht** fuer P6 kreditieren.
- `production_auth_identity` **nicht** oeffnen, bevor das Evidence-Dokument den Verifier
  besteht — die gefahrene Kette allein reicht nicht.
- `BASELINE_BLOCKED_IDS` **nicht** leeren, bevor I1 belegt ist.
- Keinen Prozentwert direkt im Manifest setzen — ausschliesslich ueber den Delta-Ledger.
- Kein lokaler RC-Beweis darf als hosted, Production-Deploy, Promotion, Registry-Push,
  Produktions-OAuth oder Marktfreigabe umgedeutet werden.

`MARKET_READY:false` · `DEV-ONLY; hosted proof still blocked.`
