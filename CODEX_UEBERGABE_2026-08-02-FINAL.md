# 🏁 ÜBERGABE — ENDSPURT AUF MARKTREIFE (Stand 2026-08-02)

> **Aktive Übergabe.** `CODEX_UEBERGABE_2026-08-02-SESSION14.md` = Detailprotokoll (§14–§17 mit
> allen Herleitungen), `…SESSION13.md` = Historie.
> **Reihenfolge:** (1) `CODEX_ZIELVERFOLGUNG_KURZ.md` → (2) diese Datei → (3) Preflight §3 → (4) arbeiten.

---

## 1. DIE LAGE IN SECHS SÄTZEN

1. **RC12 ist gebunden, der Verifier bestätigt es selbst:**
   `verified mode=fully_itemized computed=89 credited=89 verified=17/19 blocked=I1,I5`
2. **Ein technischer Blocker steht noch:** der gehostete Cloudflare-Worker läuft auf alter Quelle.
   Das ist eine **Owner-Entscheidung**, kein Bug (§5.1).
3. **Drei Capability-Gates bleiben owner-gewallt** — Klicks und Secrets, keine Arbeit (§5).
4. **Overall 89 ist echt.** Kein Prozent wurde je hochgesetzt; die Verifier machen es strukturell unmöglich.
5. **`/organism` sieht nicht aus wie das Referenzvideo** — 5 von 7 Effekten fehlen. Er ist aber
   **echt datengetrieben**, kein Screensaver (§6).
6. **Nie gemessen:** ob die 22 Seiten, L4/L5 und die Docs-Versprechen substanziell sind (§8).
   **Nicht raten — messen.**

---

## 2. IST-STAND (gemessen)

| Gegenstand | Wert |
|---|---|
| Branch | `claude/cloud-superbrain-analysis-127d2e` (Default `chore/repo-bootstrap`, **kein `main`**) |
| **Kandidat** | `6261f9f89d803c36b449ba87a4d93e14411b31d0` |
| Kontroll-Commit | `16a16fd03e69a3cc3a4941a5c82f4b2c9e68eb85` |
| **CI grün** | Run `30762156522` — **alle Steps** |
| Bindung | `source_checkout_attestation_v1`, `checked_out_sha == candidate_sha`, control_delta = 1 erlaubter Pfad |
| Overall | **89** = `round(Σ H / 7)` · P3 44 · P5 89 · P6 90 · L4 55 · L5 56 |
| P5 | `fully_itemized`, 17/19, blockiert **I1** + **I5** |
| Gates | **7/10 zu**; offen: `production_auth_identity`, `docker_registry_publish`, `phase6_scale_runtime` |
| Rollback-Anker | RC11 `bae3cdc1692e1e99e7f546f72664a3c747958b8c` |

**Fremd-dirty, nie mitcommitten:** `.codex/runs/CURRENT/product-acceptance/report.json`
**Entwürfe ausgelagert:** `D:\_sb_tmp\superbrain-drafts-2026-08-02\` — model-registry,
access_classes, cost_gate brachen Supply-Chain **und** O4. Nichts gelöscht.

---

## 3. PREFLIGHT — jedes Mal

```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP = 'D:\_sb_tmp'; $env:TMP = 'D:\_sb_tmp'
$env:PSModulePath = 'C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
git rev-parse --short HEAD "@{u}"
git status --short --untracked-files=no
```

Die `PSModulePath`-Zeile ist **Pflicht**, wenn du aus pwsh 7 startest: 5.1 erbt sonst die
7er-Modulpfade und findet sein eigenes `Get-FileHash` nicht. 38 von 39 npm-Scripts rufen 5.1.

**Vor jedem Browser-/Runtime-Beweis:**

```powershell
pwsh -NoProfile -File scripts\start-dev-live.ps1
docker exec cloud-superbrain-phase1-dev-llm-gateway-1 sh -c 'echo $LLM_GATEWAY_MODE'
```

Muss `cloudflare_workers_ai_live` sagen. Der Startmeldung allein nicht trauen.

---

## 4. TEST-INVENTAR

### 4.1 Statisch (kein Docker)

| Befehl | Prüft |
|---|---|
| `npm run verify` | Gesamtkette Phase 1 |
| `python scripts/verify_phase5_credit_itemization.py` | P5-Credit, Evidenz, CI-Bindung, 32 Anker |
| `python -m unittest discover -s scripts/tests -p "test_verify_phase5_credit_itemization.py"` | **21/21** |
| `node --test apps/frontend/tests/oauth-boundary-readiness.test.mjs` | **22/22** OAuth-Grenze |
| `npm run verify:phase6-scale:static` | Zero-Request-Preflight, Tamper-Guards |
| `pwsh -File scripts/verify-supply-chain-pins.ps1` | 23 Actions / 18 Images / 9 unique / 6 GHCR |
| `pwsh -File scripts/verify-main-deploy-transition.ps1` | Immutable-Candidate-GHCR-Vertrag |
| `npm run verify:current-release-candidate` | Kandidatenbindung |

### 4.2 Runtime (~15 min, Docker)

`npm run verify:runtime` — 86 Prüfungen: Compose-Health, Contracts, O4-Revalidierung.

### 4.3 Browser (~30 min, seriell, DEV-LIVE nötig)

`npm run verify:browser` = Contract → Product-Acceptance (**echter** Workers-AI-Build) →
22 Seiten / 161 Aktionen → O4-Browser-Write → O4-Promote.

### 4.4 Service-Tests

```
cd services/agent-api && python -m unittest tests.test_auth_security     # 27/27
cd services/cloudflare-stateful-runtime && npm test                       # 24/24
```

### 4.5 Owner-gated (laufen NICHT autonom)

`verify-phase6-scale-runtime.ps1 -AllowHostedWrites` (900 echte Requests, braucht
`AGENT_API_AUTH_TOKEN`) · `verify-market-ready.ps1 -IncludeExternalGates`

---

## 5. DIE VIER WÄNDE ZUR MARKTREIFE

### 5.1 SOFORT ENTSCHEIDBAR — Cloudflare-Worker-Deploy

`npm run verify` stoppt an `current Cloudflare-native hosted Worker source parity`.
`docs/runtime-state/cloudflare-native-hosted-current.json` nennt `af61146e`, Kandidat ist `6261f9f8`.

- **Was fehlt:** Worker aus dem Kandidaten neu deployen.
- **Warum kein Agent das tut:** verändert eine **öffentlich erreichbare Live-Fläche**.
- **Kosten:** keine — zero-card, freier Tarif.
- **Danach:** `npm run verify` läuft durch.
- **Falle:** `wrangler secret put` scheitert mit CF-**10053** — es sind `plain_text`-Vars.
  Richtig: `deploy --keep-vars --var …`

### 5.2 O1 — Production-OAuth-Identität → P3 (+56)

Braucht **zuerst** eine Architekturentscheidung: CF-native stateful **oder** hosted Agent-API mit
PostgreSQL+Redis. Der Vercel-Ursprung ist read-only und kann O1 **nicht** erfüllen.

Dann: GitHub → Settings → Developer settings → OAuth Apps → New OAuth App ·
Callback `https://<AUTH_PUBLIC_ORIGIN>/api/v1/auth/callback` · Scope **nur `read:user`**.
Variablennamen: `GITHUB_OAUTH_CLIENT_ID` · `_CLIENT_SECRET` · `_REDIRECT_URI` · `JWT_SIGNING_SECRET`.

**Abnahme = 10 echte Browserschritte:** Cancel→401 · Scope-Prüfung · Authorize · Reload ·
Refresh rotiert · Replay→401 · Callback-Replay scheitert · Logout widerruft + Audit.

### 5.3 `AGENT_API_AUTH_TOKEN` → P6 (+10)

**Ein Secret, keine Zahlung.** Danach exakt 900 Requests: 60@c1 + 240@c10 + 500@c50 Reads,
50 POST + serverseitiger D1-Readback, 50 authentifizierte DELETEs.
Schwellen: Erfolg ≥ 0,99 · p95 ≤ 1500 ms · eigene 5xx **exakt 0** · Cleanup vollständig.
Ohne Flag: **null Requests**, `Blocked` = exit 2 — das Skript kann sich nicht selbst freischalten.

### 5.4 O3 — GHCR → P5 (+11) · zyklisch

Push verboten vor `MARKET_READY:true`, das aber GHCR-Digests verlangt. **Owner muss den Zyklus
brechen.** Setup: Settings → Environments → `registry-publication` **und** `production`, je mit
Required Reviewer. Pakete **privat** lassen — public ist irreversibel.

> **Zahlung öffnet nichts.** `payment_required` ist bei O1/O2/O3 `false`; eine im Manifest
> abgebildete Zahlung macht `owner-input-matrix` **rot**.

---

## 6. ORGANISM — gemessen, nicht vermutet

**Substanz ist echt:** `useGLTF('/organism/core.glb')` lädt · Szene gespeist aus
`/api/v1/organism/live-state`, `/events`, `/replay` · Bloom + Vignette + EffectComposer aktiv ·
`runState` aus echter Telemetrie.

**Optik fehlt — 5 von 7 Effekten (Plan §12.3):**

| # | Geplant | Status |
|---|---|---|
| 1 | Brain-Mesh: `Edges` + `Points` + `MeshTransmissionMaterial` | **teilweise** (`Points` ✅) |
| 2 | Bloom | ✅ |
| 3 | Dot-Globus (Fibonacci-Sphäre) | ❌ |
| 4 | Matrix-Rain (DOM-Layer, billiger als Shader) | ❌ |
| 5 | Scanlines/HUD | ❌ |
| 6 | Shards (`PlaneGeometry`, opacity 0.06) | ❌ |
| 7 | Waveform aus **echter** Telemetrie | ❌ |

**Optik-Lücke, keine Substanz-Lücke** — Stunden bis Tage.
**Regeln:** eigener Branch · **additiv** auf `CortexCanvas3D` (997 Zeilen, an 7 Phase-6-Browser-
beweise gebunden) · `data-testid` **unverändert** · voller `verify:browser` als Abnahme ·
**nie während eines offenen RC**.

---

## 7. ARBEITSREGELN, DIE JEDEN LAUF ENTSCHEIDEN

1. **O4 ist der LETZTE Schritt vor den Ketten.** Jeder Commit danach macht den Beweis stale.
2. **`start-dev-live.ps1` NACH `verify:runtime`, unmittelbar VOR `verify:browser`.** Die
   Runtime-Kette recycelt Container → Gateway fällt auf `deterministic_dry_run` → das Modell
   liefert einen 129-Zeichen-Stub → Product-Acceptance scheitert irreführend. Gilt auch nach
   **jedem** `docker compose up --build`.
3. **Evidenz VERBATIM übernehmen.** Nachbearbeiten bricht die Kreuzreferenz-Hashes — genau der
   Manipulationsschutz, der greifen soll.
4. **CI-Dispatch:** `gh workflow run` nimmt einen **Ref, keinen SHA**. Kontroll-Commit direkt auf
   den Kandidaten, eigener Branch, dispatchen, danach **mergen** (nicht cherry-picken).
5. **`git commit` nie ohne Pathspec** · **nie `git add -A`**.
6. **`PSModulePath` setzen** (§3).
7. **Nie parallel** Playwright / Docker / Verifier.
8. **Jeder neue CI-Step braucht einen roten Lauf, bevor man ihm glaubt.** Vier Steps liefen
   monatelang nur `skipped` und enthielten **alle** Fehler.

---

## 8. WAS NIE GEMESSEN WURDE — nicht raten

Ein 6-Achsen-Audit *„im Dokument versprochen, nie gebaut"* wurde **zweimal gestartet und lief nie
durch** (Session-Limits). **Null Ergebnisse.** Ehrlich unbekannt:

| Achse | Frage |
|---|---|
| 22 Seiten | Echte Features oder Hüllen? Der Audit beweist Klickbarkeit, **nicht** Substanz |
| L4 (55) / L5 (56) | Was fehlt **wirklich** vs. was existiert und nur nicht gutgeschrieben ist |
| Docs-Versprechen | Jeder benannte Endpoint/Service gegen den Code |
| Halbfertiges | TODO/stub/`NotImplementedError` auf dem Produktpfad |
| Ziel vs. Realität | Inspector? Replay-UI? NeuroGlass-Design-System als Tokens? |

**Sequenziell inline messen, nicht per Subagent** — die liefen zweimal ins Limit.

**Offener Sicherheitshinweis:** Ein Vollscan des Arbeitsverzeichnisses meldet **7 gitleaks-Funde**
— alle in **untracked** Build-/Testartefakten. Das **Kandidaten-Archiv ist sauber**. Sie können
nur schaden, wenn jemand `git add -A` benutzt. Genau deshalb ist das verboten.

---

## 9. ENDSPURT — Reihenfolge

```
1. Owner: Cloudflare-Worker auf 6261f9f8 deployen   -> npm run verify laeuft durch
2. Owner: AGENT_API_AUTH_TOKEN setzen                -> P6 900-Request-Beweis -> P6 100
3. Owner: Architekturentscheidung Hosted-Auth        -> O1 -> P3 100
4. Owner: O3-Zyklus brechen + Environments anlegen   -> GHCR -> P5 100
5. Agent: organism-visual-v2 (§6)                    -> Optik zum Referenzvideo
6. Agent: die 5 ungemessenen Achsen (§8) messen      -> L4/L5-Wahrheit
7. verify:market-ready -IncludeExternalGates         -> MARKET_READY: true
```

**1–4 sind Owner-Wände. 5–6 sind autonome Arbeit und können sofort beginnen.**

---

## 10. WAS NIEMAND TUN DARF

`git add -A` · `git commit` ohne Pathspec · Force-Push · Push auf Default-Branch ·
Prozente oder `live_verified` von Hand setzen · L4/L5 hochsetzen (zwei Verifier prüfen die Null) ·
Zahlung / Kreditkarte / Paid Provider / Fly.io / R2 / CF Containers ·
Secrets in Chat, Datei, Log oder Commit — **nur Pfad + Fundtyp melden** ·
Token rotieren („Roll") — vom Owner ausdrücklich abgelehnt ·
kanonische Anker aufweichen, um grün zu werden ·
Hosted-Deploy ohne Owner-Freigabe ·
DEV-ONLY-Evidenz als Hosted-Beweis ausgeben.

**Vier Wände, die kein Agent überschreitet:** Kreditkarte/Zahlung · Passwort-Konten · CAPTCHA ·
Secrets ausgeben oder committen.

---

*Stand 2026-08-02 · Kandidat `6261f9f8` · CI `30762156522` grün · Overall 89 · Gates 7/10 zu ·
`MARKET_READY:false` · DEV-ONLY; hosted proof still blocked*
