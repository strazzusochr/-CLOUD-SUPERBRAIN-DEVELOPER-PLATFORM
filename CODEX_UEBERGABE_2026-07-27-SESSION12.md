# CODEX-ÜBERGABE — SESSION 12 (2026-07-27) — ✅ ALLES SAUBER GEPUSHT · nur HOSTED offen
> **Ersetzt SESSION11.** Jede Zahl gegen Repo-Artefakte verifiziert (`git log`, Report-JSONs, Verifier-Läufe).
> **Codex' abgebrochene Arbeit wurde geprüft, zu Ende geführt und gesichert. Working Tree ist sauber.**

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

> ⚠️ **STALE-MARKER, bitte ernst nehmen:** Die Registry enthält jetzt zusätzlich die Familie
> `technology-runtime-controls` mit 3 Mitgliedern (`technology-runtime-refresh`, `technology-provider-filter`,
> `technology-layer-select`, alle `requireEffectDelta: true`) → **31 Familien / 198 Mitglieder / 187 enabled**.
> Der protokollierte Abnahmelauf **`22/22 · 184/184` stammt von VOR dieser Ergänzung.** Die drei neuen Aktionen
> sind einzeln über `technology.spec.ts` (Chromium 6/6) bewiesen, **nicht** über den 22-Seiten-Runner.
> **P1 für Codex: `npm run verify:22-page-actions` erneut fahren, bevor Prozente/Gates angefasst werden.**
> Bis dahin gilt `184/184` als *historisch*, nicht als aktuell. Der Marker steht auch in
> `docs/audit/22-page-action-matrix.md`.

## 3. 📊 STAND
- Overall **86 %** · `MARKET_READY: false` · **autonom offen: 0** (außer P1 oben)
- `P0 100·P1 100·P2 100·P3 44·P4 100·P5 68·P6 90` — `FE 100·ORC 100·AP 69·LLM 55·MCP 56·MEM 90·OBS 100`
- **RC10** `prod-candidate-2026-07-24-local-rc10` aus `2ae4c61a`; Rollback RC9 @ `0cbe644c`; GHCR unveröffentlicht
- **Working Tree sauber** bzgl. Slice; 33 fremde untracked Dateien (alte Übergaben, ZIPs, Screenshots) **unberührt**
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
der Befund ist konsistent mit **nicht aktiviertem R2 auf dem Konto**. → **Owner-Restaufgabe: R2 im Dashboard
aktivieren** (Free-Tier 10 GB). Erst danach ist `-Profile Full`/`O2WithR2` grün.

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

## 6. GATE-INVENTAR (10 Gates: 3 offen · 7 zu)
✅ offen: `live_llm_provider_calls` · `live_memory_provider` · `hosted_observability_endpoint`
🔴 zu: `cloudflare_native_zero_card_hosted_runtime` (**O2′**) · `live_vector_memory_search` (**O5**) ·
`production_auth_identity` (**O1**) · `live_mcp_writes` + `live_agent_tool_writes` (**O4**) ·
`docker_registry_publish` (**O3**) · `phase6_scale_runtime` (folgt aus O2′)
**Kein Gate je handsetzen — nur der echte Verifier darf `live_verified: true` schreiben.**

## 7. ✅ HOSTED-ROLLOUT-RUNBOOK — JETZT STARTBAR (O2Core ist offen)
> **Neuer Einstiegspunkt:** Der Kandidat ist 4/4 (O2Core) + 1/1 (O5). **Schritt 1 ist erledigt.**
> Beginne bei Schritt 2, aber **ohne R2** bis der Owner R2 aktiviert hat — Artefaktablage vorerst über D1/DO lösen
> oder den R2-Teil sauber als blockiert markieren. Der erste echte Write qualifiziert den Kandidaten und darf
> erst dann `CLOUDFLARE_API_TOKEN` ersetzen.
1. ~~`owner-set-cloudflare-token.ps1 -ProbeOnly` → muss 6/6 sein~~ → **erledigt: 5/6, O2Core 4/4, O5 1/1**
2. **Ressourcen selbst anlegen** (dafür sind die `Edit`-Rechte da, kein Owner nötig):
   `wrangler d1 create cloud-superbrain-state-prod` (+`-preview`) · `queues create cloud-superbrain-runtime-candidate` ·
   `r2 bucket create cloud-superbrain-artifacts-candidate` · `vectorize create …`
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
