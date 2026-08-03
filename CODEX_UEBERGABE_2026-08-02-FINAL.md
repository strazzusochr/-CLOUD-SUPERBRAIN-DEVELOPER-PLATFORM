# 🏁 ÜBERGABE — ENDSPURT AUF MARKTREIFE (Stand 2026-08-03, RC13)

> **Aktive Übergabe.** `CODEX_UEBERGABE_2026-08-02-SESSION14.md` = Detailprotokoll (§14–§17 mit
> allen Herleitungen), `…SESSION13.md` = Historie.
> **Reihenfolge:** (1) `CODEX_ZIELVERFOLGUNG_KURZ.md` → (2) diese Datei → (3) Preflight §3 → (4) arbeiten.

---

## 1. DIE LAGE IN SECHS SÄTZEN

1. **RC13 ist gebunden, der Verifier bestätigt es selbst:**
   `verified mode=fully_itemized computed=89 credited=89 verified=17/19 blocked=I1,I5`
2. **Ein technischer Blocker steht noch:** der gehostete Cloudflare-Worker läuft auf alter Quelle.
   Das ist eine **Owner-Entscheidung**, kein Bug (§5.1).
3. **Drei Capability-Gates bleiben owner-gewallt** — Klicks und Secrets, keine Arbeit (§5).
4. **Overall 89 ist echt.** Kein Prozent wurde je hochgesetzt; die Verifier machen es strukturell unmöglich.
5. **`/organism` ist visuell fertig — 7 von 7 Effekten** (`db6c8c18`) und **in RC13 verifiziert** (§6).
6. **Die fünf Substanz-Achsen sind gemessen** (`4c526c69`, `LAYER_MATRIX.md`): bei **L4/L5 fehlt
   echte Funktion**, kein zurückgehaltener Credit (§8).

---

## 2. IST-STAND (gemessen)

| Gegenstand | Wert |
|---|---|
| Branch | `codex/organism-visual-v2` (Default `chore/repo-bootstrap`, **kein `main`**) |
| **Kandidat (RC13)** | `db631ab3ffe2254309ae80aadc691b0bba6c372d` |
| Kontroll-Commit | `f5f0a2fac884a443fe3f34ef20272c1fc67991a0` (Branch `rc13-ctl`, gemerged) |
| **CI grün** | Run `30815984573` — **alle Steps** |
| Bindung | `source_checkout_attestation_v1`, `checked_out_sha == candidate_sha`, control_delta = 1 erlaubter Pfad |
| Overall | **89** = `round(Σ H / 7)` · P3 44 · P5 89 · P6 90 · L4 55 · L5 56 |
| P5 | `fully_itemized`, 17/19, blockiert **I1** + **I5** |
| Gates | **7/10 zu**; offen: `production_auth_identity`, `docker_registry_publish`, `phase6_scale_runtime` |
| Rollback-Anker | **RC12** `6261f9f89d803c36b449ba87a4d93e14411b31d0` |

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
`docs/runtime-state/cloudflare-native-hosted-current.json` nennt `af61146e`, Kandidat ist `db631ab3`.

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

**Optik ist FERTIG — 7 von 7 Effekten (Plan §12.3), geliefert von Codex in `db6c8c18`:**

| # | Geplant | Status |
|---|---|---|
| 1 | Brain-Mesh: `Edges` + `Points` + `MeshTransmissionMaterial` | ✅ |
| 2 | Bloom | ✅ |
| 3 | Dot-Globus (Fibonacci-Sphäre) | ✅ |
| 4 | Matrix-Rain (auch in `styles.css`) | ✅ |
| 5 | Scanlines/HUD | ✅ |
| 6 | Shards (`PlaneGeometry`) | ✅ |
| 7 | Waveform (`LineSegments`) aus echter Telemetrie | ✅ |

**Und verifiziert:** Der Slice ist als **RC13** eingefroren, lokal qualifiziert (6 Images, Runtime,
Browser, Security, Candidate-Runtime) und über CI `30815984573` source-attestiert.

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

## 8. DIE FÜNF SUBSTANZ-ACHSEN — jetzt gemessen

**Erledigt.** Codex hat die fünf Achsen gemessen (`4c526c69`); Ergebnis ist kanonisch in
`LAYER_MATRIX.md`. Meine frühere Aussage *„nie gemessen"* ist damit überholt.

**Die Antwort auf „überall fehlt die Hälfte":** bei L4/L5 **stimmt es — und es ist echte
fehlende Funktion, kein zurückgehaltener Credit.**

| Layer | vorhanden | was fehlt (Zitat `LAYER_MATRIX.md`) |
|---|---|---|
| **L4 55 %** | OpenAI-kompatible Chat-/Responses-Verträge, Routing/Policy/Fallback/Budget, begrenzter Workers-AI-Livepfad | Standardmodus ist `deterministic_dry_run`; **volle Live-Flotte, dynamisches Routing und Responses-Streaming sind nicht belegt** |
| **L5 56 %** | Safe-Envelopes mit Scope/Timeout/Audit/Versionspins, interne Read-only-Tools, begrenzter O4-Dateiwrite | GitHub-, PostgreSQL-, Filesystem-, Playwright- und **E2B-Adapter bleiben contract/dry-run**; Writes allowlist- und owner-gegatet |

L1–L3, L6, L7 stehen bei 100 % mit benannter Implementierung; der Wahrheitsrand ist überall
**DEV-ONLY, Hosted-Parität je Kandidat neu zu belegen**.

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
5. [ERLEDIGT] RC13 gebunden, CI 30815984573 gruen    -> 7/7 Effekte verifiziert
6. Agent: L4/L5 echte Funktion bauen (§8)           -> Live-Flotte, Routing, Adapter
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

*Stand 2026-08-03 · Kandidat **RC13** `db631ab3` · CI `30815984573` grün · Overall 89 ·
Gates 7/10 zu · `MARKET_READY:false` · DEV-ONLY; hosted proof still blocked*
