# 🎯 ZIEL-VERFOLGUNG (KURZ) — Endspurt, Stand 2026-08-03 (RC13)

> **Reihenfolge in JEDER Session:** (1) diese Datei → (2) `CODEX_UEBERGABE_2026-08-02-FINAL.md`
> → (3) Preflight → (4) arbeiten. `…SESSION14.md` = Detailprotokoll, `…SESSION13.md` = Historie.

## ENDZIEL

`npm run verify:market-ready` druckt real **`MARKET_READY: true`**.
Beide Matrizen 100 %, jede Zelle mit echtem Artefakt.
Owner-gewallte Reste ehrlich als **OWNER-BLOCKED** listen — **nie faken (R0)**.

---

## 🚀 START HIER — Kandidat **RC13** `db631ab3` · CI `30815984573` **grün**

**RC13 ist gebunden. Der Verifier bestätigt es selbst:**

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
`af61146e`, der Kandidat ist `db631ab3`.

Auflösen heißt **einen öffentlich erreichbaren Live-Worker neu deployen**. Kostenlos
(zero-card), aber eine Live-Fläche — deshalb rührt kein Agent das an. Danach läuft die Kette durch.

---

## 🧱 DIE VIER WÄNDE

| Wand | öffnet | Art |
|---|---|---|
| **Worker-Deploy** auf `db631ab3` | `npm run verify` | Live-Fläche, keine Zahlung |
| **O1** OAuth-Identität | P3 +56 | braucht **zuerst** Architekturentscheidung: CF-native **oder** hosted PG+Redis. Vercel ist read-only und kann O1 nicht erfüllen. Scope nur `read:user` |
| **`AGENT_API_AUTH_TOKEN`** | P6 +10 | **Secret, keine Zahlung.** Danach 900 echte Requests |
| **O3** GHCR | P5 +11 | **zyklisch** — Push verboten vor `MARKET_READY:true`, das GHCR-Digests verlangt. Owner muss den Zyklus brechen |

**Zahlung öffnet nichts** — `payment_required` ist überall `false`; eine abgebildete Zahlung
macht die Owner-Matrix **rot**.

---

## ✅ AUTONOM, SOFORT MÖGLICH

**Beides ist erledigt — von Codex, in seinem Nachtlauf:**

1. ✅ **`organism-visual-v2` ist FERTIG — 7 von 7 Effekten** (`db6c8c18`). Im Baum nachgemessen:
   `Edges` · `MeshTransmission` · `Bloom` · `Scanline` · Fibonacci-Dot-Globus · Shards ·
   Waveform · Matrix-Rain (auch in `styles.css`). **Unverifiziert** — braucht RC13.
2. ✅ **Die 5 Achsen sind gemessen** (`4c526c69`, kanonisch in `LAYER_MATRIX.md`).
   Antwort auf *„überall fehlt die Hälfte"*: **bei L4/L5 stimmt es, es ist echte Arbeit** —
   L4 55 %: Standardmodus ist `deterministic_dry_run`, volle Live-Flotte, dynamisches Routing
   und Responses-Streaming sind **nicht belegt**. L5 56 %: GitHub-/PostgreSQL-/Filesystem-/
   Playwright-/E2B-Adapter bleiben contract/dry-run, Writes allowlist- und owner-gegatet.
   **Das ist fehlende Funktion, nicht zurückgehaltener Credit.**

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

# 📋 ANWEISUNGEN FÜR CODEX — RC13 ist gebunden, was jetzt zählt

## Was du geliefert hast (unabhängig nachgemessen)

| | |
|---|---|
| **RC13** | `db631ab3ffe2254309ae80aadc691b0bba6c372d` — eingefroren, lokal qualifiziert |
| **CI grün** | Run `30815984573`, Kontroll-Commit `f5f0a2fa` auf `rc13-ctl`, sauber gemerged |
| **P5-Verifier** | `verified mode=fully_itemized computed=89 credited=89 verified=17/19 blocked=I1,I5` |
| **Organism** | **7 von 7** Effekten — nicht nur gebaut, sondern **kandidatengebunden bewiesen** |
| **5 Achsen** | gemessen, kanonisch in `LAYER_MATRIX.md` |

**Der 13-Schritt-Plan der Vorversion ist vollständig abgearbeitet.** Zwei Dinge hast du dabei
selbst gelöst, die nicht im Plan standen: den `.gitattributes`-Eintrag, ohne den die
Roh-Log-Hashes zwischen Worktree und Index auseinanderlaufen, und den D:-Platzmangel
(`.next` ausgelagert statt Beweise abgebrochen). Beides war richtig.

**Prozente unverändert 89** — korrekt, RC13 fügt keine horizontale Phase hinzu.

---

## ⛔ WAS JETZT BLOCKIERT — und es ist nicht deine Arbeit

`npm run verify` stoppt weiterhin an **Cloudflare-Worker-Source-Parität**:
gehostet läuft `af61146e`, Kandidat ist `db631ab3`.

**Nicht umgehen.** Es ist eine Live-Fläche und eine Owner-Entscheidung. Wer den Verifier hier
aufweicht, fälscht Hosted-Parität. Du hast das selbst einmal richtig benannt — dabei bleibt es.

Dasselbe gilt für O1 (OAuth), `AGENT_API_AUTH_TOKEN` (P6), O3 (GHCR). **Vier Owner-Wände.**

---

## ✅ WAS AUTONOM ÜBRIG BLEIBT — die ehrliche Liste

Nach dem Audit ist genau **eine** substanzielle Fläche offen. Sie bewegt die Prozente **nicht**
(Vertikale zählen nicht ins `overall`), schließt aber die echte Funktionslücke:

**L4 (55 %) — LLM Gateway.** Fehlt laut eigener Messung: volle Live-Flotte · dynamisches
Routing · Responses-**Streaming**. Standardmodus `deterministic_dry_run` ist der Schutz,
nicht der Defekt.

**L5 (56 %) — MCP Gateway.** Fehlt: GitHub-, PostgreSQL-, Filesystem-, Playwright- und
E2B-Adapter jenseits von contract/dry-run; Writes bleiben allowlist- und owner-gegatet.

**Bevor du daran arbeitest:** Für L4/L5 existiert **keine autoritative Credit-Rubrik**. Ohne sie
ist jede Prozentbewegung Fake-Grün — zwei Verifier prüfen die Null aktiv. Ein Rubrik-Vorschlag
steht in `CODEX_UEBERGABE_2026-08-02-SESSION14.md`; er braucht **Owner-Freigabe**, bevor er zählt.

**Reihenfolge:** Funktion bauen und lokal beweisen → Rubrik freigeben lassen → RC14.
Nicht umgekehrt.

---

## 🧹 AUFRÄUMEN BEIM NÄCHSTEN LAUF

- `rc13-ctl` (lokal + origin) erst löschen, wenn RC13 nicht mehr aktiv ist — **nicht vorher**,
  die Attestation verweist darauf.
- Worktree unter `D:\_sb_tmp\rc13-ctl` entfernen.
- `.next` liegt unter `C:\Users\immer\AppData\Local\Temp\superbrain-generated-next-rc13-market-ready`.
- **`D:` war bei ~0 GB.** Vor jedem Image-Build Platz prüfen — ein voller Datenträger hat schon
  einmal das Docker-Dateisystem beschädigt (Session 14, `fsck` nötig).

---

## 🚫 UNVERÄNDERT VERBOTEN

Prozente oder `live_verified` von Hand · L4/L5 ohne freigegebene Rubrik hochsetzen ·
kanonische Anker aufweichen · Hosted-Deploy ohne Freigabe · Zahlung/Karte/Paid Provider ·
Secrets ausgeben (**nur Pfad + Fundtyp**) · Token rotieren · Force-Push ·
Push auf Default-Branch · `git add -A` · DEV-ONLY als Hosted-Beweis ausgeben.

**Vier Wände:** Kreditkarte/Zahlung · Passwort-Konten · CAPTCHA · Secrets ausgeben/committen.

---

*RC13 `db631ab3` · CI `30815984573` grün · Overall 89 · Gates 7/10 zu · `MARKET_READY:false`*
