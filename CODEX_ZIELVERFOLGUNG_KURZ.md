# 🎯 ZIEL-VERFOLGUNG (KURZ) — Endspurt, Stand 2026-08-02

> **Reihenfolge in JEDER Session:** (1) diese Datei → (2) `CODEX_UEBERGABE_2026-08-02-FINAL.md`
> → (3) Preflight → (4) arbeiten. `…SESSION14.md` = Detailprotokoll, `…SESSION13.md` = Historie.

## ENDZIEL

`npm run verify:market-ready` druckt real **`MARKET_READY: true`**.
Beide Matrizen 100 %, jede Zelle mit echtem Artefakt.
Owner-gewallte Reste ehrlich als **OWNER-BLOCKED** listen — **nie faken (R0)**.

---

## 🚀 START HIER — Kandidat `6261f9f8` · CI `30762156522` **grün**

**RC12 ist gebunden. Der Verifier bestätigt es selbst:**

```
[phase5-credit] verified mode=fully_itemized computed=89 credited=89 verified=17/19 blocked=I1,I5
```

Overall **89** · P3 44 · P5 89 · P6 90 · L4 55 · L5 56 · Gates **7/10 zu** · `MARKET_READY:false`

**Preflight (PSModulePath ist Pflicht aus pwsh 7):**

```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
$env:PSModulePath='C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
```

---

## ⛔ DER EINE BLOCKER — Owner-Entscheidung, kein Bug

`npm run verify` stoppt an **Cloudflare-Worker-Source-Parität**: der gehostete Worker läuft auf
`af61146e`, der Kandidat ist `6261f9f8`.

Auflösen heißt **einen öffentlich erreichbaren Live-Worker neu deployen**. Kostenlos
(zero-card), aber eine Live-Fläche — deshalb rührt kein Agent das an. Danach läuft die Kette durch.

---

## 🧱 DIE VIER WÄNDE

| Wand | öffnet | Art |
|---|---|---|
| **Worker-Deploy** auf `6261f9f8` | `npm run verify` | Live-Fläche, keine Zahlung |
| **O1** OAuth-Identität | P3 +56 | braucht **zuerst** Architekturentscheidung: CF-native **oder** hosted PG+Redis. Vercel ist read-only und kann O1 nicht erfüllen. Scope nur `read:user` |
| **`AGENT_API_AUTH_TOKEN`** | P6 +10 | **Secret, keine Zahlung.** Danach 900 echte Requests |
| **O3** GHCR | P5 +11 | **zyklisch** — Push verboten vor `MARKET_READY:true`, das GHCR-Digests verlangt. Owner muss den Zyklus brechen |

**Zahlung öffnet nichts** — `payment_required` ist überall `false`; eine abgebildete Zahlung
macht die Owner-Matrix **rot**.

---

## ✅ AUTONOM, SOFORT MÖGLICH

1. **`organism-visual-v2`** — nach Codex' Nachtlauf sind **3 von 7** fertig (Brain-Mesh mit
   Edges/Points/MeshTransmission, Bloom, Scanlines). Es fehlen: **Dot-Globus, Matrix-Rain,
   Shards, Waveform**. Die Substanz ist echt: GLB lädt, Szene kommt aus
   `/api/v1/organism/live-state|events|replay`. **Optik-Lücke, keine Substanz-Lücke.**
   Additiv auf `CortexCanvas3D`, `data-testid` unverändert, voller `verify:browser` als Abnahme.
2. **Die 5 ungemessenen Achsen** (Übergabe §8): 22 Seiten · L4/L5 · Docs-Versprechen ·
   halbfertiger Code · Inspector/Replay/Design-System. Das Audit lief **zweimal ins Limit** —
   **sequenziell inline messen, nicht per Subagent.**

---

## 🔒 ACHT REGELN, DIE JEDEN LAUF ENTSCHEIDEN

1. **O4 zuletzt** vor den Ketten — jeder Commit danach macht den Beweis stale.
2. **`start-dev-live.ps1` NACH `verify:runtime`, VOR `verify:browser`** — die Runtime-Kette setzt
   den Gateway auf `deterministic_dry_run` zurück; danach liefert das Modell einen 129-Zeichen-Stub.
   Prüfen: `docker exec …llm-gateway-1 sh -c 'echo $LLM_GATEWAY_MODE'` muss `…_live` sagen.
3. **Evidenz VERBATIM** aus dem erzeugenden Lauf — Nachbearbeiten bricht die Kreuzreferenz-Hashes.
4. **CI-Dispatch:** `gh workflow run` nimmt einen **Ref, keinen SHA**. Kontroll-Commit direkt auf
   den Kandidaten, eigener Branch, dispatchen, danach **mergen** (nicht cherry-picken).
5. **Nie `git add -A`**, nie `git commit` ohne Pathspec.
6. **`PSModulePath` setzen** — sonst fehlen PS-5.1-Standard-Cmdlets.
7. **Nie parallel** Playwright / Docker / Verifier.
8. **Jedem neuen CI-Step erst nach einem roten Lauf glauben.** Vier Steps liefen monatelang nur
   `skipped` — und enthielten **alle** Fehler.

---

## ⛔ VERBOTEN

Prozente oder `live_verified` von Hand · L4/L5 hochsetzen · kanonische Anker aufweichen ·
Hosted-Deploy ohne Freigabe · Zahlung/Karte/Paid Provider/Fly.io/R2 · Secrets ausgeben
(**nur Pfad + Fundtyp**) · Token rotieren · Force-Push · Push auf Default-Branch ·
DEV-ONLY-Evidenz als Hosted-Beweis ausgeben.

**Vier Wände:** Kreditkarte/Zahlung · Passwort-Konten · CAPTCHA · Secrets ausgeben/committen.

---

*Details, Belege und Owner-Klickfolgen: `CODEX_UEBERGABE_2026-08-02-FINAL.md`*

---

# 📋 ANWEISUNGEN FÜR CODEX — Stand nach deinem Nachtlauf

## Was du gebaut hast (gemessen, nicht behauptet)

**56 Dateien, +2.749 / −803** gegenüber Kandidat `6261f9f8`. Am Organism sind jetzt fertig:
`Edges` ✅ · `Scanline` ✅ · `MeshTransmissionMaterial` ✅ — zusammen mit `Points` und `Bloom`
sind das **3 von 7** Plan-Effekten (vorher 1,5).

**Noch offen:** Dot-Globus (Fibonacci-Sphäre) · Matrix-Rain (DOM-Layer, billiger als Shader) ·
Shards (`PlaneGeometry`, opacity 0.06) · Waveform aus **echter** Telemetrie.

## Deine Arbeit ist NICHT verifiziert — das ist der wichtigste Satz hier

`apps/frontend` ist in `RUNTIME_SOURCE_PATHS`. Deine 56 Dateien erzeugen deshalb
**Kandidaten-Drift**: `npm run verify` meldet
`active candidate has committed or staged runtime-source drift`.

**RC12 (`6261f9f8`) ist vollständig gebunden und CI-grün** — dein Slice hängt daran vorbei.
Du brauchst **RC13**. Das ist kein Rückschritt, das ist die Regel: neue Runtime-Quelle = neuer Kandidat.

## Deine nächsten Schritte, exakt in dieser Reihenfolge

```
1.  Slice fertig machen, dann Quelle EINFRIEREN. Ab hier kein Source-Commit mehr.
2.  Statisch gruen fahren (schnell, kein Docker):
      python -m unittest discover -s scripts/tests -p "test_verify_phase5_credit_itemization.py"   # 21/21
      node --test apps/frontend/tests/oauth-boundary-readiness.test.mjs                            # 22/22
      npm run verify:phase6-scale:static
      pwsh -File scripts/verify-supply-chain-pins.ps1
      npx tsc --noEmit -p apps/frontend/tsconfig.json
3.  Images bauen:  build-phase5-production-candidate-local.ps1 -SourceSha <FROZEN>
                   -ReleaseId prod-candidate-<datum>-local-rc13
                   -RollbackTarget 6261f9f89d803c36b449ba87a4d93e14411b31d0
                   -OutputDir .codex\runs\CURRENT\master-goal\phase5\production-candidate-local
4.  O4 dreifach beweisen  (RuntimeProof -> Browser -> PromoteGateOnFullPass)   <- LETZTER Schritt vor den Ketten
5.  npm run verify:runtime
6.  start-dev-live.ps1  +  Gateway-Modus pruefen (MUSS 'cloudflare_workers_ai_live' sein)
7.  Evidenz erzeugen (die Schreiber fahren die Ketten selbst):
      write-phase5-local-verification-evidence.ps1 -Chain runtime
      start-dev-live erneut  ->  -Chain browser
      write-phase5-security-evidence.ps1
      npm run verify:phase5-candidate-local
8.  Metadaten + Evidenz committen   (Docs liegen ausserhalb RUNTIME_SOURCE_PATHS)
9.  Kontroll-Commit DIREKT AUF DEN KANDIDATEN, eigener Branch:
      git branch rc13-ctl <FROZEN> && <eine erlaubte Datei aendern> && commit && push
10. gh workflow run pr-check.yml --ref rc13-ctl -f candidate_sha=<FROZEN> -f source_prequalification=true
11. Attestation + GitHub-Readback herunterladen, in <release>-evidence/ committen,
    Readiness schreiben, Itemisierung auf RC13 umhaengen
12. python scripts/verify_phase5_credit_itemization.py   -> muss 'verified' sagen
13. Kontroll-Branch in die Hauptlinie MERGEN (nicht cherry-picken)
```

## Fünf Fallen, die dich sonst Stunden kosten

1. **`gh workflow run` nimmt einen Ref, keinen SHA.** Deshalb der eigene Branch in Schritt 9.
   Alles, was zwischen Kandidat und Kontrolle liegt, landet im Kontroll-Delta — und der erlaubt
   nur: `pr-check.yml`, `verify_phase5_credit_itemization.py` (+Tests),
   `verify-main-deploy-transition.ps1`, `verify-supply-chain-pins.ps1`.
2. **`verify:runtime` setzt den Gateway auf `deterministic_dry_run` zurück.** Danach liefert das
   Modell einen 129-Zeichen-Stub und Product-Acceptance scheitert mit
   `llm_gateway_generation_unavailable` — irreführend, aber korrekt. Immer Schritt 6 dazwischen.
3. **O4 verlangt einen sauberen Worktree inkl. untracked unter `services/`.** Deine Entwürfe
   (`model-registry`, `access_classes`, `cost_gate`) liegen deshalb jetzt in
   `D:\_sb_tmp\superbrain-drafts-2026-08-02\`. **Nicht zurückkopieren** — sie brachen ausserdem
   `verify-supply-chain-pins` (unpinned `python:3.12-slim`). Genau das war der Grund, warum du
   immer einen Clean-Clone gebraucht hast.
4. **Evidenz VERBATIM übernehmen.** Ich habe Summaries nachträglich „aufgeräumt" und damit die
   Kreuzreferenz-Hashes gebrochen — genau der Manipulationsschutz.
5. **Aus pwsh 7 vorher setzen:**
   `$env:PSModulePath='C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'`
   sonst findet PS 5.1 sein eigenes `Get-FileHash` nicht. 38 von 39 npm-Scripts rufen 5.1.

## Was ich in deinem Slice repariert habe — bitte nicht rückgängig machen

**Alle fünf Evidenz-Schreiber** waren von `CANONICAL_SUCCESS_ANCHORS` abgekoppelt (Vergleich ist
`==`, nicht Teilmenge). Behoben in `write-phase5-local-verification-evidence.ps1`,
`write-phase5-security-evidence.ps1`, `verify-phase5-production-candidate-local.ps1`.
Exit-Anker sind **Log-Pflicht**, aber **kein deklarierter Anker**.

**Sechs Plattformfehler**, wegen derer dein Phase-6-CI-Step **nie gelaufen** ist (Backslash-Pfade,
`git.exe`, hardcodiertes `D:\_sb_tmp`, nicht committete Workflow-Datei). Alle vier neuen CI-Steps
liefen monatelang nur `skipped` — und enthielten beim ersten echten Lauf **alle** Fehler.

**Regel daraus:** Einem neuen CI-Step erst nach einem **roten** Lauf glauben.

## Was NICHT du bist — die Owner-Wände

Worker-Deploy · O1 OAuth · `AGENT_API_AUTH_TOKEN` · O3 GHCR. Details in
`CODEX_UEBERGABE_2026-08-02-FINAL.md` §5. **Nicht versuchen zu umgehen.**
