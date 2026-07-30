# CODEX-ÜBERGABE — SESSION 12 (2026-07-27) + NACHTRAG 2026-07-30 — P1 + O2Core HOSTED GRÜN
> **Ersetzt SESSION11.** Jede Zahl gegen Repo-Artefakte verifiziert (`git log`, Report-JSONs, Verifier-Läufe).
> Fremde Working-Tree-Dateien bleiben unberührt; Slice-Dateien werden ausschließlich explizit gestaged.

## NACHTRAG 2026-07-31 — HEAD WAR ROT; ZWEI REGRESSIONEN REPARIERT + BP-FRAGE BEANTWORTET

### 🔴 Der wichtigste Befund: `0a982c2a` war ein kaputter Baum
Codex hat die letzten **beiden** Commits (`53e4d242`, `0a982c2a`) committet und gepusht, **ohne danach
`npm run verify` laufen zu lassen** — obwohl `0a982c2a` ausgerechnet `verify-phase1.ps1` verändert hat.
Der Gesamt-Static-Verifier war auf HEAD **rot**. Zwei unabhängige Regressionen, beide aus `53e4d242`:

**(1) Verifier-Widerspruch bei den Hosted-Acceptance-Flags.**
`53e4d242` setzte `product_acceptance_hosted_proof` und `workspace_22_page_hosted_proof` in
`docs/runtime-state/cloudflare-native-hosted-current.json` auf `true` und zog `verify-market-ready.ps1`
korrekt nach — aber `verify-phase1.ps1` bestand weiterhin darauf, dass genau diese beiden Flags **`false`**
sind. Ein Verifier nachgeführt, der andere vergessen.
**Fix:** Der pauschale Verbots-Guard ist durch einen **evidenzgebundenen** ersetzt. `false` heißt jetzt
„es darf kein Evidenzfeld gesetzt sein"; `true` verlangt Artefakt, SHA-256-Abgleich, 40-stelligen
Source-Commit mit Ancestry-Prüfung, Deployment-ID, `https`-Base-URL und Widerspruchsfreiheit zum Report.
Das ist **strenger** als vorher — der alte Guard prüfte die Hashes überhaupt nicht.
**Negativtest bestanden:** ein einziges verändertes Hex-Zeichen im hinterlegten Hash → Ablehnung mit
`evidence SHA-256 does not match its recorded value`, Datei danach byte-exakt wiederhergestellt.

**(2) Gelöschter Wahrheits-Marker in `AI_HANDOFF.md`.**
`53e4d242` ersetzte den Satz `…frontend and the stateless read-only Backend Contract Origin are deployed on
Vercel` durch die neue Hosted-Aussage, statt sie zu ergänzen. `verify-retired-hosted-boundary.ps1` pinnt
diesen Wortlaut. **Fix:** Satz wiederhergestellt und mit der neuen Aussage verbunden — er ist weiterhin
wahr, die Hosted-Beweise laufen buchstäblich gegen genau diese Vercel-Origins.

### ⚠️ (3) Strukturbefund: die Pflichtkette hängt an **untracked** Artefakten
`verify-live-llm-evidence-chain.ps1` vergleicht `stateful-build-browser/report.json` mit
`cloudflare-d1-local/report.json`. **Beide sind untracked und gitignored.** Sie waren auseinandergelaufen:
Codex hat am 30.07. den D1-Verifier neu geseedet (`…-2050d1a2`), das Browser-Artefakt blieb vom **25.07.**
(`…-aaa2605b`). Der `html_sha256` war in beiden identisch — nur die ID-Bindung fehlte.
**Behoben** über Codex' eigenen Helfer `.codex/tmp/stateful-browser-sync.ps1` (Worker 8791 + Next 3018,
Browser-Verifier mit der *aktuellen* Seed-ID). Kette grün, `new_provider_calls=0` → **kein Prozent-Credit**.
**Bleibende Konsequenz für Codex:** Weil der Verifier bei fehlendem Artefakt hart scheitert (`MustExist`),
kann **`npm run verify` auf einem frischen Clone nie grün werden**. Das ist kein Bug von heute, aber es
gehört auf die Liste — entweder Artefakte versionieren oder den Verifier bei Abwesenheit ehrlich skippen.

### ✅ Branch Protection: Codex' offene GATE-Frage ist durch Evidenz beantwortet — **nichts anwenden**
Codex' letzte Zeile war `GATE: BP anwenden? JA/NEIN`. Die Antwort lautet **NEIN, weil es nichts zu tun gibt.**
Es lagen **zwei Illusionsschichten** übereinander:
1. **Codex' Fund (korrekt repariert in `0a982c2a`):** Das Skript kannte nur `dry-run` und `verify-only` —
   es gab **keinen Codepfad, der Schutz jemals angewendet hätte**.
2. **Die Schicht darunter (neu):** `DEFAULT_BRANCH_NAME = "main"` — **`main` existiert in diesem Repo
   überhaupt nicht.** Der Default-Branch ist **`chore/repo-bootstrap`**. Jeder Live-Aufruf lief in einen
   nichtssagenden `404 Branch not found`.

**Der real ausgelieferte Default-Branch ist bereits korrekt geschützt** — read-only nachgewiesen:
`status: verified`, **0 Abweichungen**, `allow_force_pushes=false`, `allow_deletions=false`,
`required_approving_review_count=1`, Exit `0`. **Kein Write, kein Owner-Eingriff nötig.**

**Härtung** in `scripts/apply_github_branch_protection.py`: `resolve_target_branch()` liest den echten
Default-Branch über die API, sobald ein Token da ist (die Konstante bleibt reiner Dry-Run-Fallback);
`assert_branch_exists()` bricht **vor** jedem Schutz-Anspruch ab und nennt den tatsächlichen Default-Branch;
`request_json(..., missing_ok=True)` trennt „existiert nicht" von „echter Fehler"; zwei zusätzliche
Offline-Selbsttests. Live gegengeprüft: `--branch main` → klare Fail-closed-Meldung; ohne `--branch` →
löst `chore/repo-bootstrap` auf und verifiziert.
⚠️ **Merke:** Die Owner-Matrix und §5e sprechen von „`main` niemals". Das bleibt als Regel richtig, meint
aber faktisch **`chore/repo-bootstrap`**. Die CI-Workflow-Datei war übrigens korrekt — sie nutzt
`github.event.repository.default_branch`; falsch war nur der manuelle Pfad und das Runbook.

### 🔑 CF-Token: die Promotion hat stattgefunden — O5-Scope-Blockade ist weg
Read-only-Scope-Probe (nur HTTP-Codes, keine Werte): aktiv **und** Kandidat liefern
`token_verify/workers/d1/queues/durable_object/vectorize` je **200**; Fingerprint-Vergleich sagt
**`identical: true`**. Das in §4b beschriebene Risiko „aktiver Token schwächer als Kandidat" ist damit
**erledigt** — das Promotionsskript hat den Kandidaten atomar aktiviert.
**`workers_ai` liefert 403 — das ist die Management-API (Modell-Liste), nicht die Inferenz.** Die Inferenz
läuft über das Worker-Binding und ist im Hosted-Produktbeweis mit `live_provider_calls=true` belegt.
**Nicht verwechseln und daraus keinen Blocker bauen.**

### 📊 Korrektur am Gate-Inventar (§6 war veraltet)
Gemessen sind **4 offen / 6 zu**, nicht 3/7: `cloudflare_native_zero_card_hosted_runtime` ist seit dem
30.07. **offen** (owner+live+evidence). Offen: `live_llm_provider_calls`, `live_memory_provider`,
`hosted_observability_endpoint`, `cloudflare_native_zero_card_hosted_runtime`.

### 🎯 Warum das Gate `github_branch_protection_current_verify` trotzdem noch offen steht
Der Schutz **ist** da (oben belegt) — das Gate steht aus einem anderen Grund offen:
`scripts/verify-external-gates.ps1` hat `[string]$Branch = $env:BRANCH_NAME` mit Fallback **`""`**.
Ohne gesetztes `BRANCH_NAME` baut die Probe die URL `…/branches/` **ohne Branch** und kann nichts prüfen.
**Konkreter nächster Schritt (klein, aber vollständig durchzuziehen):** Den Fallback auf den echten
Default-Branch auflösen (analog zu `resolve_target_branch()`), `verify-external-gates` neu erzeugen und
**erst dann** `docs/runtime-state/external-gate-summary.json` fortschreiben.
⚠️ **Achtung, gekoppelt:** `verify-phase1.ps1` behauptet an einer Stelle hart, es seien **genau zwei**
Gates offen (`github_branch_protection_current_verify` + `ghcr_image_digest_verify`). Wer das Gate
schließt, **muss diese Assertion im selben Slice** auf ein verbleibendes Gate umstellen — sonst ist der
Baum sofort wieder rot. Nicht einzeln anfassen.

### 🔨 Nächster Codex-Schritt (unverändert höchste Priorität)
`scripts/verify-live-vector-memory-search.ps1` **existiert nicht**, wird aber von
`docs/runtime-state/owner-input-manifest.json` als O5-Verifier referenziert — eine tote Referenz.
Da der Token Vectorize jetzt liest, ist das der erste echte Schritt für **L6 90 → 100**.
Index-Anlage ist eine Ressourcenerzeugung **außerhalb** der in `actions[O2].owner_scope_decision`
freigegebenen Liste (Workers, D1, DO, Queues) — **dafür zuerst die Owner-Freigabe einholen.**

## NACHTRAG 2026-07-30 — O2Core HOSTED VERIFIZIERT

Der source-gebundene Worker
`https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev` bestand den echten Hosted-Verifier gegen
Commit `826a78b29a4dbf82a7115ecdd5562b238ade3594` und Archiv-SHA-256
`f3d86b36883d743713c1c7e86477776dc575b87b9e941af849dfd2c4f94e325b`.
D1 W/R/D, Queue, SQLite-DO, LangGraph, Build-/Workspace-Artefakte und alle gebundenen Negativpfade sind grün;
R2 blieb ungebunden, kein Paid-Fallback. Report-SHA-256:
`FEEE5D40E14E547C9B8EB5903B993E61BC324E2C2CAD64ECF8C7DF3BA9049D0B`.

Das Capability-Gate wurde ausschließlich durch den Verifier geöffnet. Danach ersetzte das fail-closed
Promotionsskript atomar den aktiven Management-Token durch den qualifizierten Kandidaten; Rollback bleibt privat.
Der neue externe Audit bestätigt Hosted Staging, Vercel-Origins, Gitleaks und O2Core. Offen sind exakt Branch
Protection und GHCR-Digests; `production_deploy_claim_allowed=false`.

Vercel-Preview ist jetzt auf den Worker gebunden; `AGENT_API_AUTH_TOKEN`,
`PRODUCT_ACCEPTANCE_LIVE_PROVIDER_APPROVED=true` und das Workers-AI-Workbench-Modell sind Preview-only gesetzt.
Nächster Schritt: Slice committen/pushen, automatisches Preview-Deployment abwarten, dann
`verify-product-acceptance` mit `hosted_proof:true` und anschließend die Hosted-22-Seiten-Matrix.
Overall bleibt `86 %`, `MARKET_READY:false`.

## NACHTRAG 2026-07-30 — AKTUELLE 22-SEITEN-ABNAHME

Der vollständige aktuelle Real-Chromium-Lauf ist grün:
**22/22 Routen · 29/29 aktivierte Familien · 161/161 aktivierte Member · 0 tote · 0 unregistrierte ·
0 Click-only/Non-direct · 0 unerwartete Console-Fehler · 0 Page-Fehler**. Zwei erlaubte Provider-Builds waren
live; zwei erwartete 403 waren exakt mit den gegateten Games-/Apps-DELETEs korreliert.

Die Registry besitzt **31 Familien / 173 Mitglieder / 161 enabled**. Die frühere Angabe `198/187` war eine
falsche Hochrechnung: `/organism/map` besitzt jetzt 7 dedizierte Topologie-Controls statt 33 wiederverwendeter
Phase-6-Controls; `/technology` besitzt 4 Mitglieder (3 enabled, 1 conditional). Knoten- und Adjazenzbuttons
verwenden einen explizit registrierten Auswahlhandler. Der transiente P0-Build-Read wird ohne 503-Whitelist
zweimal begrenzt auf je 15 Sekunden versucht. Fokussierter Map-Test, 40/40 Reads, TypeScript, ESLint,
Next-Build 21/21, `verify-phase1`, npm audit und Gitleaks bestanden.

Report-SHA-256: `399F310FBDA0D4D584C6847F6462D1B1CF4895037FAB9FAFF90D123E7C183F6F`.
Kein Prozentcredit: Overall `86 %`, `MARKET_READY:false`. DEV-ONLY; hosted proof still blocked.

---

# TEIL I — WAS SEIT SESSION 11 PASSIERTE

## 0. FÜNF COMMITS, ALLE GEPUSHT — HEAD `23c11c21`
| Commit | Inhalt |
|---|---|
| `0d0ff548` | **Härtung des Owner-Token-Skripts.** 4 High-Risiken behoben: Candidate-only-Schreibweise, atomarer Write, Clipboard-Leerung im `finally`, echte Response-Prüfung. Plus `verify-owner-set-cloudflare-token.ps1` mit 16/16 Tests. |
| `d726ddc1` | Agent-Research an sichere Projektquellen gebunden: Allowlist, Lexik, Redaction, **Prompt-Injection-Guard** |
| `e4271e76` | **Vier-Rollen-Quellenanalyse** `agent-research-run-v3` (Planner→Coder→Tester→DevOps), 23/23 Tests |
| `6750ed70` | **`/organism/map` von Stub auf echten Topologie-Vertrag** — 245 Knoten / 495 Kanten Frontend↔Backend gespiegelt, Chromium 4/4 |
| `23c11c21` | **`/technology` an Runtime-Verträge gebunden** (diese Session fertiggestellt) — Details §1 |

**Remote-Parität geprüft:** HEAD = Upstream = Remote = `23c11c21`. Branch `claude/cloud-superbrain-analysis-127d2e`.

## 1. ✅ `/technology` — DER ABGEBROCHENE SLICE IST FERTIG UND BEWIESEN
Codex wurde vom Nutzungslimit **mitten im Review** unterbrochen; der Slice lag uncommitted im Baum.
Ich habe ihn vollständig geprüft, die Truth-Dateien nachgezogen und gesichert.

**Was er tut:** `TechnologyRuntimeView` ersetzt die statische Ansicht, die Fly/Postgres/Redis noch als aktuelle
Laufzeit behauptete (ADR-010-Widerspruch). Sie liest read-only exakt drei kanonische Verträge —
`GET /api/v1/clouds` · `GET /api/v1/clouds/layers` · `GET /api/v1/clouds/deployment-preflight` — validiert alle drei
**gemeinsam** und prüft sie zusätzlich quer (`areContractsConsistent`): Layer-Label und `required_providers` müssen
der `seven_layer_mapping` entsprechen, `configured`/`live_verified` müssen Teilmengen sein, Fly muss
`historical_only` und in **keiner** Layer-Zuordnung sein, die Cloudflare-Layermenge muss exakt stimmen.
Der Response-Stream ist vor dem JSON-Parsing hart begrenzt.

**Der sicherheitskritische Kern** steckt in drei nginx-Zeilen (`dev.conf` + `cloud.conf`):
```nginx
proxy_set_header  X-Superbrain-Source "";                        # Client kann nichts einschleusen
proxy_hide_header X-Superbrain-Source;                           # Upstream kann nichts fälschen
add_header        X-Superbrain-Source agent-api-boundary always; # nginx stempelt autoritativ
```
Nur wenn **alle drei** Antworten diese Quelle tragen, gilt `current_live_proof=true`; sonst zeigt die UI
`projection_not_current` und „Projizierter Live-Vertragswert" statt eines Live-Status. **Damit kann niemand
Live-Grün vortäuschen — auch die UI selbst nicht.**

**Verifiziert (2026-07-27, DEV-ONLY):**
- `verify-technology-runtime-view.ps1` statisch ✅ **und gegen die laufende Runtime** ✅
  → `providers=8 · layers=7 · missing_gates=1 · sources=agent-api-boundary ×3 · current_live_proof=true`
- Next.js-Produktionsbuild **exit 0**
- **Chromium 6/6**, davon fünf Fail-closed-Beweise: ungültiges Schema · Querverweis-Bruch · Übergrößen-Payload ·
  `503`-Retry über alle drei GETs · **unmögliche Live-Behauptung an der Agent-Boundary**
- TypeScript `0` · ESLint `0` · Python-Compile OK · PowerShell-Parse OK
- **`verify-phase1.ps1` PASS** inkl. **Gitleaks 0 Leaks über 3.726 Dateien**
- Audit-Neubewertung: `/technology` **STUB/MOCK → NUR CONTRACT**

## 2. AUDIT-STAND 22 SEITEN
**9 ECHT NUTZBAR · 11 NUR CONTRACT · 2 STUB/MOCK · 0 FEHLT/BROKEN** (`docs/audit/vision-vs-reality-2026-07-25.md`)

> ✅ **Aktueller Nachlauf:** `22/22 · 29/29 · 161/161`, ohne tote oder unregistrierte Controls.
> Maßgeblich ist der Nachtrag am Dateianfang; `184/184` bleibt ausschließlich historische Session-10-Evidenz.

## 3. 📊 STAND
- Overall **86 %** · `MARKET_READY: false` · autonom offen: Hosted-O2Core und nachfolgende Hosted-Abnahme
- `P0 100·P1 100·P2 100·P3 44·P4 100·P5 68·P6 90` — `FE 100·ORC 100·AP 69·LLM 55·MCP 56·MEM 90·OBS 100`
- **RC10** `prod-candidate-2026-07-24-local-rc10` aus `2ae4c61a`; Rollback RC9 @ `0cbe644c`; GHCR unveröffentlicht
- Fremder Product-Acceptance-Report und fremde untracked Dateien bleiben **unberührt**
- Projekt-Integrität geprüft: **833/833 versionierte Dateien vorhanden, `git fsck` sauber**

---

# TEIL II — DER BLOCKER

## 4. 🟢 DURCHBRUCH: CF-TOKEN LIEFERT 5/6 — O2Core UND O5 SIND OFFEN
**Der Owner hat am 2026-07-27 einen neuen Token mit korrekten Permissions geliefert.** Er lag zunächst
unbrauchbar in der Datei (68 Zeichen: Tokenwert **plus Token-Name** `CloudeflareAi` in derselben Zeile → `err=6003`,
Authorization-Header ungültig). Nach Extraktion des reinen 53-Zeichen-Werts:

| Ressource | Ergebnis |
|---|---|
| Token-Verify | ✅ HTTP 200 |
| Workers Scripts | ✅ HTTP 200 |
| D1 | ✅ HTTP 200 |
| Queues | ✅ HTTP 200 |
| Durable Objects | ✅ HTTP 200 |
| Vectorize | ✅ HTTP 200 |
| **R2** | ❌ HTTP 403 · **`err=10042`** |

**`10042` ist KEIN Permission-Fehler** (das wäre `10000`, wie zuvor bei allen sechs). Die Berechtigung sitzt;
der Befund ist „R2 auf dem Konto nicht aktiviert".

### ⛔ ARCHITEKTURENTSCHEID 2026-07-27: **R2 IST RAUS** (wie Fly.io)
Recherche am 2026-07-27: **Cloudflare verlangt für die R2-Aktivierung eine hinterlegte Zahlungsmethode —
auch für den kostenlosen 10-GB-Tarif.** In der Cloudflare-Community existieren zusätzlich Berichte über eine
5-USD-Belastung bei Aktivierung. Damit fällt R2 unter die **Free-Only-Wand „keine Kreditkarte"**, exakt wie Fly.io.
**Der Owner hat R2 deshalb nicht aktiviert. Das ist final; nicht erneut vorschlagen.**

**Konsequenz — R2 ist KEIN Blocker, weil es nicht gebraucht wird:**
- Artefakt-Ablage (gebaute HTML-Artefakte = Textblobs) läuft über **D1**; Session-/Koordinationszustand über
  **Durable Objects**. Beide sind offen und karten­frei.
- **Verbindliches Verifier-Profil ist `O2Core`** (+ `O5` für Vectorize). `-Profile Full` und `-Profile O2WithR2`
  dürfen **nicht** mehr als Zielzustand behandelt werden — sie enthalten R2 und sind bauartbedingt unerreichbar.
- Wo R2 im Code/Contract noch vorkommt: **als `historical_only` / nicht-aktiver Pfad führen**, exakt wie Fly
  (`layers=[]`, ohne Token `None`). Kein stiller Fallback, keine Fake-Grün-Umgehung.
- `5/6` ist damit der **Zielzustand**, nicht ein Zwischenstand. 6/6 ist unter Free-Only nicht erreichbar.

**Persistiert (fail-closed, wie von `0d0ff548` vorgesehen):**
`owner-set-cloudflare-token.ps1 -FromClipboard -Profile O2Core` → **4/4 PASS**, Wert gespeichert als
**`CLOUDFLARE_API_TOKEN_CANDIDATE`** in `~/.codex/secrets/cloud-superbrain.local.env`, Rollback-Datei angelegt.
`-Profile O5` → **1/1 PASS** (Vectorize).
**Bewusst NICHT als aktiver `CLOUDFLARE_API_TOKEN` gesetzt:** Ein GET-Beweis zeigt nur Leserechte;
**die Edit-Rechte bleiben unbewiesen**, bis der freigegebene Hosted-Write-Verifier einen echten
Write-/Read-/Delete-Beweis erbringt. Der alte, unprivilegierte Token bleibt bis dahin der aktive Wert.

> 🧹 **Bereinigt:** Die kanonische Secrets-Datei enthielt zwei `CLOUDFLARE_API_TOKEN`-Zeilen, davon die defekte
> 68-Zeichen-Variante. Je nach Parser hätte mal die eine, mal die andere gewonnen — alle Dienste wären mit `6003`
> gescheitert. Defekte Zeile entfernt, Backup daneben. Aktueller Stand: `CLOUDFLARE_API_TOKEN` (alt, 0/6) +
> `CLOUDFLARE_API_TOKEN_CANDIDATE` (neu, 5/6).

> ⚠️ **Owner-Entscheidung respektiert:** Der Tokenwert ist am 2026-07-27 in einem Chatverlauf gelandet. Der Owner
> hat ein „Roll" **ausdrücklich abgelehnt**; der Wert bleibt unverändert in Gebrauch. Nicht erneut vorschlagen.

## 5. ⛔ TOKEN-ERSTELLUNG BLEIBT OWNER-ONLY
Unverändert gültig aus Session 11 — **Codex darf es nicht versuchen:**
1. **Unmöglich:** `POST /user/tokens` braucht `User·API Tokens·Edit`; der vorhandene Token hat 0/6. Kein Bootstrap.
2. **R0-Wand:** Dashboard = Passwort/2FA. Vier Wände: Kreditkarte · Passwort-Konten · CAPTCHA · Secret-Ausgabe.
3. **Es würde Fake-Done erzwingen.**

Owner-Schnittstelle ist `scripts/owner-set-cloudflare-token.ps1` (fail-closed, gehärtet in `0d0ff548`):
SecureString **oder** `-FromClipboard`, extrahiert den Token aus `Bearer`/curl-Drumherum, prüft alle 6 Scopes,
**schreibt nur bei 6/6**, Backup vorher, leert die Zwischenablage, gibt nie einen Wert aus. `-ProbeOnly` = nur prüfen.
Fehlercodes: `6003` = kein reiner Token · `1000`/`9106` = Token ungültig · `10000` = **Permission fehlt**.
🔁 **Alter `CLOUDFLARE_API_TOKEN` ist zu revoken** — Wert geriet 2026-07-26 in ein Transkript.

---

# TEIL III — WEG UND REGELN

## 4b. 🔑 SECRETS-DATEI BEREINIGT UND VOLLSTÄNDIG LIVE-VALIDIERT (2026-07-30)
Der Owner ergänzt Werte, ohne alte zu löschen. Ergebnis waren **zwei tote Duplikate**, bei denen die übliche
Parser-Regel *(letzter Wert gewinnt)* jeweils den **ungültigen** Wert geliefert hätte — Codex wäre mit beiden
in Sackgassen gelaufen. Entfernt, Backup `cloud-superbrain.local.env.bak-dedup-20260730-180631`:

| Key | entfernt | verbleibt |
|---|---|---|
| `GITHUB_TOKEN` | Zeile 15 `ghp_…` 40 Z. → **HTTP 401 abgelaufen** | Zeile 2 `github_pat_…` 93 Z. → **HTTP 200** |
| `CLOUDFLARE_API_TOKEN` | Zeile 11 → 0/2 lesbar | Zeile 9 |

**Live-Validierung nach der Bereinigung:** `GITHUB_TOKEN` 200 (`strazzusochr`), Repo-Permissions
`admin=true push=true pull=true` → **O4-tauglich**; Branch-Protection-API **404** (= noch nicht gesetzt, korrekt);
`VERCEL_TOKEN` 200; `GITHUB_REPOSITORY` in `owner/name`-Form; O1-Konfiguration **4/4**;
**keine Duplikate**, keine Leerzeichen-/Anführungszeichen-Fehler in kritischen Werten.

### ⚠️ AKTIVER CF-TOKEN IST SCHWÄCHER ALS DER KANDIDAT — O5 WÜRDE SCHEITERN
`CLOUDFLARE_API_TOKEN` (aktiv) und `CLOUDFLARE_API_TOKEN_CANDIDATE` sind **verschiedene Werte**.
Gemessen 2026-07-30: aktiv **4/6** (Workers·D1·Queues·DO = 200, **Vectorize 403 `10000`** = Recht fehlt,
R2 403 `10000`) gegen Kandidat **5/6** (dieselben vier = 200, **Vectorize 200**, R2 403 **`10042`** =
nur Konto-Aktivierung, siehe §4).
**Der Kandidat ist der richtige Token** — verifiziert über `owner-set-cloudflare-token.ps1` mit
`O2Core 4/4` + `O5 1/1`.
> **Codex: den Kandidaten NICHT eigenmächtig aktivieren.** Die fail-closed Regel aus `0d0ff548` bleibt:
> erst der echte Hosted-Write-/Read-/Delete-Beweis qualifiziert ihn, dann darf er `CLOUDFLARE_API_TOKEN`
> ersetzen. Für Vectorize-Arbeiten bis dahin **ausdrücklich den Kandidaten** verwenden und das im Report
> vermerken — nicht stillschweigend tauschen.

## 5a. ✅ O1 KONFIGURATION ERLEDIGT — DER BLOCKER WAR EIN COMPOSE-DEFEKT
Der Owner lieferte gültige OAuth-Daten, trotzdem blieb Auth tot. **Ursache war nicht seine Eingabe:**
`docker-compose.dev.yml` reichte `GITHUB_OAUTH_CLIENT_ID`, `_CLIENT_SECRET` und `_REDIRECT_URI`
**nie an die agent-api durch**. Die berechnet `github_oauth_configured` und `credential_issuance_ready` aber
ausschließlich daraus (`services/agent-api/app/main.py:2285`) → dauerhaft fail-closed, unabhängig von
Secrets-Datei und Vercel. **Behoben in `99bc9c3e`** (vier Variablen mit bewusst leeren Standards).

**Vierte Voraussetzung, die in keiner Anleitung stand: `JWT_SIGNING_SECRET`.** Ohne ihn bleibt
`credential_issuance_ready` false trotz gültiger OAuth-Daten. `start-dev-live.ps1` erzeugt ihn einmalig
(rein lokaler Signierschlüssel) und legt ihn in der Secrets-Datei ab.

**Nachweis lokal:** `github_oauth_configured: true` · `jwt_signing_configured: true` ·
`credential_issuance_ready: true` · `missing_configuration: []` ·
`mode: verified_identity_fail_closed` (vorher `local_contract_with_dry_run_oauth`).
`verify-phase3-auth-fail-closed.ps1` **PASS**, `status=verified_dev_only`,
`credentials_issued=false`, `live_github_oauth_call=false`.

**Vercel-Seite (vom Assistenten erledigt):** Die drei Variablen lagen nur als Team-„Shared"-Einträge; das
Projekt `frontend` (`prj_ZbSNRVz5ijLQ4tQR61liHFw1x5eY`) hatte **keine** davon. Sie sind jetzt direkt am Projekt
verankert (`production,preview`), Redeploy `dpl_5uLu9a2BpEBb5BDPiuqRtyfkSFY1` READY.
> ⚠️ **Auf Vercel wird `github_oauth_configured` trotzdem nie `true`** — dort läuft keine agent-api; die Seite
> liefert eine statische Projektion mit hart kodiertem `false` (`apps/frontend/lib/endpointDefaults.ts:29`).
> Die Variablen sind korrekt, aber **inert bis O2′**. Das Gate `production_auth_identity` verlangt danach noch
> den **hosted** OAuth-Austausch; die lokale Evidenz ist ausdrücklich `verified_dev_only`, kein Hosted-Proof.

> 🔑 **`GITHUB_TOKEN` ist abgelaufen (HTTP 401).** Es blockierte den Git-Push und hätte auch
> `apply_github_branch_protection.py` in O4 scheitern lassen. Der Owner hat `gh auth login` erneuert;
> der **Token in der Secrets-Datei bleibt ungültig** und wird durch den neuen O4-Fine-grained-Token ersetzt.

## 5b. ✅ PFLICHT AUS DER OWNER-MATRIX ERLEDIGT: **ECHTER ZERO-CARD-ADAPTER**
ADR-010 und `cloudflare-native-runtime-candidate-v2` verwenden jetzt
`cloudflare-d1-bounded-text`: begrenzte UTF-8-Artefakte bis `32768` Bytes liegen in D1; Queue und SQLite
Durable Objects koordinieren ausschließlich Referenz, Hash und Status. Rohinhalt erscheint weder in Queue,
DO-State, Antwort noch Audit. Migration `0003_zero_card_d1_artifacts.sql` ist vorhanden. R2 wurde aus den
Wrangler-Bindings entfernt und bleibt nur ungebunden als `historical_only`; es gibt keinen Spillover.
`17/17` Unit-Tests, statischer Verifier und echter lokaler Wrangler-Create→Queue→DO→D1-Read/Delete-Lauf
bestanden. Evidence `.codex/runs/CURRENT/master-goal/t3/cloudflare-d1-local-v2/report.json`, SHA-256
`CB108383C338E41C47440FA2618009DC174053E08E6401CAD7255AD333A65F43`.
DEV-ONLY; hosted proof still blocked. Kein Prozentcredit.

## 5c. ✅ O5 IST ERLEDIGT — OWNER-TEIL ENTFÄLLT
Die Matrix fordert für O5 ausschließlich „Extend the Cloudflare token with Vectorize Edit". Der gelieferte Token
liest Vectorize (HTTP 200), `-Profile O5` **1/1 PASS**. Verbleibende O5-Arbeit ist **rein Codex**: Index anlegen,
Embedding, Roundtrip, hosted Semantic-Search-Beweis über `verify-live-vector-memory-search.ps1`.
**`live_verified` nie handsetzen** — die lexikalische D1-Suche ist keine semantische Vektorsuche.

## 5d. 📖 OWNER-RUNBOOK
Vollständige Klick-für-Klick-Anleitung für die verbleibenden drei Gates:
**`docs/runbooks/OWNER_SCHRITT_FUER_SCHRITT_2026-07-27.md`** — exakte Feldwerte, Variablennamen,
Berechtigungsstufen, Reihenfolge. **Reihenfolge ist bindend: O1 → O4 → O3.**
O3 (GHCR) darf laut Matrix-`codex_boundary` **erst nach `MARKET_READY: true`** erfolgen.

## 5e. ✅ O4 — OWNER-FREIGABEN ERTEILT (2026-07-30)
> **Der Owner hat die vier Vorschläge unverändert bestätigt („ja, so").** Gespiegelt in
> `docs/runtime-state/owner-input-manifest.json` → `actions[O4].owner_scope_decision`
> (`decision: approved_as_proposed`, `gate_state_unchanged: true`).
> **Gegengeprüft: `live_agent_tool_writes` und `live_mcp_writes` stehen weiterhin auf
> `owner_granted=false, live_verified=false`.** Die Freigabe ist eine Scope-Entscheidung, **kein Gate-Öffnen**.
>
> **Damit ist der Owner-Teil von O4 vollständig.** Der Token ist tauglich (§4b), die Grenzen sind schriftlich.
> **Verbleibende O4-Arbeit ist rein Codex:** `python scripts/apply_github_branch_protection.py` ausführen,
> den gebundenen Live-Write-Verifier bauen/fahren und die Gates **ausschließlich** über
> `npm run verify:runtime` + `npm run verify:browser` öffnen. **`live_verified` nie handsetzen.**

### Die bestätigte Fassung im Wortlaut
Die Owner-Matrix verlangt für `live_agent_tool_writes` + `live_mcp_writes` vier ausdrückliche Entscheidungen.
Der Token ist bereits tauglich (`admin=true push=true pull=true`, §4b) — es fehlen **nur** diese Antworten.

> ⚠️ **Namensklärung, weil es zu Missverständnissen führte:** `claude/…` ist ein **historischer
> Branch-Namenspräfix**, **keine Zuständigkeitsgrenze**. Codex hat auf `claude/cloud-superbrain-analysis-127d2e`
> genauso committed wie der Assistent (`d726ddc1`, `e4271e76`, `6750ed70` sind Codex-Arbeit). Beide committen
> zudem unter dem Git-Autor des Owners — der Autorname sagt nichts über den Urheber.
> `C:\Users\immer\.codex` ist Codex' **Konfigurations-/Secrets-Ordner außerhalb des Repos** und hat mit
> Branches nichts zu tun. Der Git-Working-Tree ist ausschließlich
> `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`.
> **Maßgeblich ist nicht der Präfix, sondern: niemals `main`.**

| # | Frage | Vorschlag (Owner bestätigt oder ändert) |
|---|---|---|
| 1 | **Welche Repositories** dürfen beschrieben werden? | **Nur** `strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`. Keine anderen Repos des Kontos, keine Forks, keine Organisationen. |
| 2 | **Welche Branches?** | **Nur der jeweils aktive Arbeitsbranch** — aktuell `claude/cloud-superbrain-analysis-127d2e`, unabhängig vom Präfix auch künftige Arbeitsbranches. **`main` niemals**, weder direkt noch per Force-Push noch per Merge ohne Owner-Freigabe. Branch-Protection auf `main` erzwingt das zusätzlich. |
| 3 | **Welche MCP-Tools** dürfen schreiben? | **Filesystem** nur innerhalb `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM` (keine Pfade außerhalb, insbesondere **nicht** `C:\Users\immer\.codex` und **nicht** `<SECRETS_DIR>`); **Git** nur auf dem Arbeitsbranch. Alles andere (GitHub-Issues/PR-Writes, externe APIs, Paket-Publishing) bleibt **read-only**. |
| 4 | **Audit-Aufbewahrung** | Jeder Write wird im Audit-Log persistiert (Zeitpunkt, Agent/Rolle, Pfad bzw. Ref, Ergebnis) — **niemals Secret-Werte**. Aufbewahrung unbegrenzt; ein Write ohne erfolgreichen Audit-Eintrag gilt als **fehlgeschlagen** und wird zurückgerollt (gleiches Fail-closed-Muster wie bei der Auth-Credential-Ausgabe). |

**Erst nach schriftlicher Owner-Bestätigung** darf Codex `live_agent_tool_writes`/`live_mcp_writes` über die
echten Verifier (`npm run verify:runtime`, `npm run verify:browser`) öffnen. **Kein stilles Aktivieren**,
kein Handsetzen von `live_verified`. Die bestätigte Fassung ist in
`docs/runtime-state/owner-input-manifest.json` (O4) zu spiegeln.

## 6. GATE-INVENTAR (10 Gates: 4 offen · 6 zu — Stand 2026-07-31 gemessen)
✅ offen: `live_llm_provider_calls` · `live_memory_provider` · `hosted_observability_endpoint` ·
`cloudflare_native_zero_card_hosted_runtime` (**O2′**, seit 30.07. durch den Hosted-Verifier geöffnet)
🔴 zu: `live_vector_memory_search` (**O5**) · `production_auth_identity` (**O1**) ·
`live_mcp_writes` + `live_agent_tool_writes` (**O4**) · `docker_registry_publish` (**O3**) ·
`phase6_scale_runtime` (Zahlung, echte Wand)
**Kein Gate je handsetzen — nur der echte Verifier darf `live_verified: true` schreiben.**

## 7. ✅ HOSTED-ROLLOUT-RUNBOOK — JETZT STARTBAR (O2Core ist offen)
> **Neuer Einstiegspunkt:** Der Kandidat ist 4/4 (O2Core) + 1/1 (O5). **Schritt 1 ist erledigt.**
> Beginne bei Schritt 2. **R2 wird nicht verwendet** (§4, Kreditkarten-Wand) — Artefakte über **D1**,
> Session/Koordination über **Durable Objects**. Der erste echte Write qualifiziert den Kandidaten und darf
> erst dann `CLOUDFLARE_API_TOKEN` ersetzen.
1. ~~`owner-set-cloudflare-token.ps1 -ProbeOnly` → muss 6/6 sein~~ → **erledigt: O2Core 4/4, O5 1/1 = Zielzustand**
2. **Ressourcen selbst anlegen** (dafür sind die `Edit`-Rechte da, kein Owner nötig):
   `wrangler d1 create cloud-superbrain-state-prod` (+`-preview`) · `queues create cloud-superbrain-runtime-candidate` ·
   `vectorize create …` — **kein `r2 bucket create`** (§4). Artefakte in D1, Koordination in Durable Objects.
3. IDs in `services/cloudflare-stateful-runtime/wrangler.jsonc` binden — **nie Secrets dort**
4. D1-Migrationen ausrollen, Readback verifizieren
5. Worker deployen → `verify-cloudflare-stateful-runtime.ps1` **ohne** `-StaticOnly` hosted grün
6. Gate `cloudflare_native_zero_card_hosted_runtime` **über den echten Verifier** öffnen
7. 🎯 `verify-product-acceptance.ps1` gegen die **gehostete** URL → **`hosted_proof: true`**
8. Hosted 22-Seiten-Lauf, gleiche Latte: 0 tote Aktionen
9. O5/MEM: Vectorize-Index, Semantic Search hosted → MEM 90→100
10. **Erst danach** Manifest/RC/`verify:market-ready`

## 8. FEHLER-PLAYBOOK
| Symptom | Ursache | Handlung |
|---|---|---|
| `-ProbeOnly` → `FAIL … 10000` | Permission fehlt | exakte Liste in den Statusbericht, **auf P3 ausweichen** |
| `6003` | Eingabe war kein reiner Token | Copy-Button **am Token**, nicht am curl-Beispiel |
| **Verifier scheitert unerklärlich** | ⚠️ **zuerst `Get-PSDrive D` prüfen** | siehe §9 — das kostete diese Session Zeit |
| Frontend-Build hängt in `chown`/Export | Windows-Layer-I/O, kein Fehler | auslaufen lassen, nicht parallel verifizieren |
| Turbopack-Panik im Dev-Boot | bekannt | auf Webpack-Dev wechseln |
| HMR zeigt alten Stand | Container-Cache | `docker compose restart frontend` |

## 8b. 🔴 WICHTIGSTER OPERATIVER BEFUND: DIE WORKBENCH BRAUCHT **VIER** SCHALTER
Der Owner meldete am 2026-07-27: *„Die Workbench funktioniert nicht — ✗ Das LLM-Gateway hat kein vollständiges
Build-Artefakt geliefert."* **Kein Codefehler.** Es waren vier Konfigurationsschalter, die der Compose-Standard
bewusst fail-closed hält und die **nach jedem Container-Neuaufbau zurückfallen**. Sie wurden einzeln
herausdiagnostiziert, jeder erzeugte eine andere Fehlermeldung:

| # | Schalter | Ort | Standard | Fehler, wenn falsch |
|---|---|---|---|---|
| 1 | `LLM_GATEWAY_MODE=cloudflare_workers_ai_live` | llm-gateway | `deterministic_dry_run` | Build meldet „kein vollständiges Artefakt"; Gateway antwortet mit `chatcmpl-dryrun-…` |
| 2 | `PRODUCT_ACCEPTANCE_LIVE_PROVIDER_APPROVED=true` | **frontend** | `false` | Gateway bleibt im Trockenmodus — der Live-Pfad wird **pro Request** über das Metadatenfeld `live_provider_calls_allowed` entschieden, das die Build-Route hieraus ableitet |
| 3 | `WORKBENCH_LLM_MODEL=@cf/qwen/qwen2.5-coder-32b-instruct` | frontend | ⚠️ **`gemma-3-1b-it`** | **Echter Konfigurationsdefekt:** der Compose-Standard ist das *lokale llama.cpp*-Modell und steht **nicht** auf der Workers-AI-Allowlist → Gateway `400` → Build `503 llm_gateway_generation_unavailable` |
| 4 | `AGENT_API_AUTH_TOKEN` (identisch in frontend **und** agent-api) | beide | **leer** | `_build_registry_authenticated` verlangt ein nicht-leeres Token → jeder Build-Write abgelehnt → `503 build_persistence_unavailable`, **obwohl die LLM-Generierung erfolgreich war** |

**Lösung eingebaut: `scripts/start-dev-live.ps1`.** Setzt alle vier, erzeugt den internen Service-Token einmalig
und legt ihn in der Secrets-Datei ab, wartet auf 10/10 Health und **liest die effektiven Werte aus den Containern
zurück** statt sie anzunehmen. `-DryRun` startet den sicheren Trockenmodus.
```
pwsh -NoProfile -File scripts\start-dev-live.ps1
```
**Beweis nach dem Fix:** `verify-product-acceptance.ps1 … -ApproveLiveProviderCall` → **PASS**,
Build `cba73a86-d10d-41b8-9f6c-d8fcc77abe58`, `provider=cloudflare-workers-ai`, `live_provider_calls=true`.

### ✅ `session_missing` ist endgültig geklärt
Ein Direktaufruf von `POST /api/v1/build` ohne Session liefert **lokal** exakt
`401 write_session_required / session_missing`. **`session_missing` heißt schlicht „nicht eingeloggt".**
Das war auch die Ursache der ursprünglichen Vercel-Meldung — kein Bug, keine fehlende Runtime.
**Codex: diese Meldung nie wieder als Backend-Defekt interpretieren.**

## 9. ⚠️ NEUE LEHRE: VOLLES LAUFWERK TARNT SICH ALS CODE-FEHLER
`D:` lief auf **0,41 GB** voll. `verify-phase1.ps1` brach daraufhin mit
`Verification failed: organism topology static surface` ab — **das sah exakt wie eine Regression in `6750ed70` aus,
war aber reiner Speichermangel.** Nach Freigabe lief derselbe Verifier fehlerfrei (245 Knoten / 495 Kanten).
**Regel: Bei jedem unerklärlichen Verifier-Fehlschlag zuerst den freien Speicher prüfen, dann den Code verdächtigen.**
Ursache war ein Windows-Backup-Satz (~37 GB) unter `D:\NEWPC`; der Owner hat ihn selbst entfernt. Aktuell **37 GB frei**.

## 10. ANTI-PATTERNS (11+ Sessions)
- **Contract-Beweis ≠ Produkt-Beweis.** „HTTP 200" und „Klick gezählt" sind KEINE Abnahme.
- **Verifier-grün ≠ produkt-lebendig.**
- **Nie 1–2-Zeichen-Funktionsnamen in Secret-Skripten** (`H` kollidierte mit `Get-History` und spiegelte einen
  Token-Wert in eine Exception). Exception-Texte fremder Cmdlets nie ungefiltert ausgeben.
- **Keine unerfüllbaren Pflichtaufgaben im Zielprompt** — sie erzwingen Fake-Done.
- **Nie parallel** verifizieren/Playwright/Docker-bauen.
- **Erst Speicher prüfen, dann Code verdächtigen** (§9).
- **Blockiert ehrlich melden** schlägt „irgendwie grün".

## 11. PREFLIGHT (jede Session)
1. `git log -1` ≥ **`23c11c21`**, Branch `claude/cloud-superbrain-analysis-127d2e`
2. `$env:TEMP` / `$env:TMP` = `D:\_sb_tmp`
3. **`Get-PSDrive D` → mindestens 10 GB frei**, sonst zuerst aufräumen
4. `docker compose -f docker-compose.dev.yml ps` → 10/10 healthy
5. Lesen: diese Datei → `CODEX_ZIELVERFOLGUNG_KURZ.md` → `master-goal-final.md` →
   `owner-input-manifest.json` → `capability-gates.json` → `docs/project-progress.manifest.json` (**%-Wahrheit = 86 %**)
6. `git status --short` — **33 fremde untracked Dateien nie stagen, nie reverten, NIE `git add -A`**

## 12. ⏸ CODEX RATE-LIMITED BIS **2026-08-02, 23:54**
Nutzungslimit. Kein Absturz, kein Datenverlust, alles committed und gepusht.

## 13. REGELN (R0)
No-Fake-Done/Live · `live_verified` nur durch echten Verifier · **Free-Only: kein bezahlter Provider, keine
Kreditkarte, kein Fly, keine CF-Containers, kein bezahltes Docker-Abo** · Localhost/Preview = **DEV-ONLY** ·
Push nur `claude/cloud-superbrain-analysis-127d2e` (kein main, kein force) · kein GHCR/Promotion ohne O3 ·
kein paralleler verify/Playwright/Docker-Build · Secrets nur in `<SECRETS_DIR>`, **nie** in Projektdateien, Logs,
Reports oder Commits · fremde dirty Dateien tabu · **NIE `git add -A`**.
**Vier Wände:** Kreditkarte/Zahlung · Passwort-Konten · CAPTCHA · Secret-Ausgabe.

## 14. 🏁 FINISH-LINE
`npm run verify:market-ready` → **`MARKET_READY: true`** **UND** `verify-product-acceptance` mit
**`hosted_proof: true`** (echtes spielbares 3D-Game aus echtem Prompt, in der Cloud, persistiert) **UND**
hosted 22-Seiten-Matrix ohne tote Aktionen.
**Lokal ist alles bewiesen. Es fehlt nur die Cloud — und die ist gratis.**
