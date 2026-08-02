# 🎯 ZIEL-VERFOLGUNG (KURZ) — Stand 2026-08-02 (Session 14)

> **Reihenfolge in JEDER Session:**
> (1) diese Datei → (2) `CODEX_UEBERGABE_2026-08-02-SESSION14.md` → (3) Preflight → (4) arbeiten.
> `CODEX_UEBERGABE_2026-07-31-SESSION13.md` ist **Historie** (Rulings, Organism-Plan §12) —
> der Ist-Stand steht in Session 14.

## ENDZIEL

`npm run verify:market-ready` druckt real **`MARKET_READY: true`**.
Beide Matrizen **100 %**, jede Zelle mit echtem Artefakt.
Owner-gewallte Reste ehrlich als **OWNER-BLOCKED** listen — **nie faken (R0)**.

---

## 🚀 START HIER — HEAD = `7b366b45` · origin = `fe88c2a0` · **7 Commits ungepusht**

**Workspace:** `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM` (Hauptordner, nicht `.claude/worktrees/*`)
**Branch:** `claude/cloud-superbrain-analysis-127d2e` · Default = `chore/repo-bootstrap` (**kein `main`**)

**Ist-Stand (nachgemessen, nicht aus einem Report übernommen):**
Overall **89** = `round(Σ H / 7)` · P3 **44** · P5 **89** (`fully_itemized`, 17/19, blockiert I1+I5) ·
P6 **90** · L4 **55** · L5 **56** · Capability-Gates **7/10 geschlossen** · `MARKET_READY:false`.

**Letzte CI-verifizierte Wahrheit:** `f7830977`, Run `30712183385` = success.
**Alles danach ist lokal unbewiesen.**

**Codex ist rate-limited bis 2026-08-09.**

### ⚠️ ERSTE HANDLUNG VOR JEDEM BROWSER-/RUNTIME-BEWEIS

```powershell
pwsh -NoProfile -File scripts\start-dev-live.ps1
```

Compose-Standard ist **absichtlich** `deterministic_dry_run`. Ohne diesen Aufruf meldet
`/api/v1/build` immer „kein vollständiges Build-Artefakt" — **Schutz, kein Defekt**.

---

## ⚠️ DER BAUM IST NICHT SAUBER — XDIRTY ist NICHT mehr 3

**12 tracked dirty + 9 untracked.** Codex wurde mitten im Slice abgeschnitten.

**Fremd, nie anfassen:**
`.codex/runs/CURRENT/product-acceptance/report.json` · `apps/frontend/tsconfig.tsbuildinfo` ·
`apps/frontend/next-env.d.ts`

**Unfertige Codex-Arbeit (9), darunter ZWEI Wahrheitsdateien:**
`.github/workflows/pr-check.yml` · `.phase1-artifacts/o4-live-writes/{proof,browser-proof,runtime-proof}.json` ·
**`docs/runtime-state/capability-gates.json`** · **`docs/runtime-state/owner-input-manifest.json`** ·
`scripts/verify_phase5_credit_itemization.py` · `scripts/tests/test_verify_phase5_credit_itemization.py` ·
`scripts/verify-main-deploy-transition.ps1` · `scripts/verify-supply-chain-pins.ps1`

**Neu und NICHT integriert:** `services/model-registry/*` (kompletter Service, kein Verifier
kennt ihn) · `services/agent-api/app/core/{access_classes,cost_gate}.py`

Vor jedem Commit die zwei Wahrheitsdateien einzeln begründen:

```bash
git diff --unified=1 -- docs/runtime-state/capability-gates.json docs/runtime-state/owner-input-manifest.json
```

---

## 🔧 NÄCHSTE SCHRITTE — Stand nach Session 15 (Übergabe §13)

**Schon erledigt, nicht nochmal anfangen:**
- ✅ MAJOR-Befund §6.1 (GHCR-Gate) — **Codex hat selbst nachgezogen**,
  `verify-main-deploy-transition.ps1:89-90`
- ✅ Scale-False-Green — **widerlegt**: ohne `-AllowHostedWrites` null Requests, `Blocked` = exit 2,
  null Schreibzugriffe → kann sich nicht selbst freischalten
- ✅ Beide Wahrheitsdateien — semantisch geprüft: **nur O4-Rebind**, Hash `B7CC7705…` korrekt
  gebunden, **kein Gate umgelegt**
- ✅ **1 echter Bug gefixt** (liegt fertig im Worktree, **absichtlich nicht committet**):
  `verify-supply-chain-pins.ps1` nutzte `[IO.Path]::GetRelativePath` — gibt es in
  **Windows PowerShell 5.1 nicht**, und `npm run verify` startet genau die. Jetzt unter beiden
  Editionen grün mit identischer Zählung (23/18/9/6).

**🛑 DER EINE VERBLEIBENDE BLOCKER — und er ist KEIN Bug:**

```
[phase5-credit] active candidate has committed or staged runtime-source drift
                outside the exact post-qualification truth transition
```

Aktiver Kandidat ist **RC11 (`bae3cdc1`)**. Seit dessen Qualifikation hat sich die Runtime-Quelle
geändert (8 Commits + 42 dirty). Der Verifier weigert sich, P5=89 für einen Kandidaten
gutzuschreiben, dessen Quelle nicht mehr passt.
**Wer hier einen Verifier patcht, um grün zu werden, begeht Fake-Completion.**

**Die Auflösung ist RC12:**

1. **Commit A** = Codex' Slice (42 dirty + 9 untracked, inkl. meines Fixes), **mit Pathspec**,
   in sinnvollen Teilen. `verify-supply-chain-pins.ps1` **muss zusammen mit** `pr-check.yml`
   rein — sonst prüft der Verifier 23 Actions gegen eine alte Datei mit 20 → HEAD sofort rot.
2. **Clean-Clone** auf Commit A — **kein Worktree** (Docker kann dessen `.git`-Datei nicht mounten).
3. **6 Images bauen** (`build-phase5-production-candidate-local.ps1`), Source = Commit A · ≈60 Min.
4. **Fünf Ketten:** Runtime · Browser · Images · Candidate-Runtime · Security · ≈45 Min.
5. **Commit B** = RC12-Metadaten, die exakt auf A zeigen.
6. Erst **B** als Kandidat verifizieren → `changed_paths` wieder leer → P5-Credit gültig.
7. `npm run verify` grün → pushen → `pr-check` per Dispatch auf genau diesem SHA.

Vorarbeit liegt in `D:\_sb_tmp\superbrain-clean-proof-96a9c5e4` (RC12-Metadaten geschrieben,
Kette unvollendet). Alles seriell, `TEMP`/`TMP=D:\_sb_tmp`, C: > 6 GB frei.

**Noch offen aus dem Audit:** OAuth-Frontend · Backend-Auth · Truth-Integrität —
ungeprüfte Funde, weder bestätigt noch entkräftet.

Danach: Owner-Wände (unten) oder Produkt-Slice **`organism-visual-v2`** (Session 13 §12).

---

## 🧱 DIE DREI OWNER-WÄNDE — Entscheidungen, keine offene Arbeit

| Wand | öffnet | Art |
|---|---|---|
| **O1** GitHub-OAuth-Identität | P3 +56 | braucht **zuerst** Architekturentscheidung: CF-native stateful **oder** hosted Agent-API+PG+Redis. Vercel-Backend ist read-only und kann O1 **nicht** erfüllen. Scope nur `read:user` |
| **`AGENT_API_AUTH_TOKEN`** | P6 +10 | **Secret, keine Zahlung.** Danach 900 echte Requests: 800 Reads + 50 POST/D1-Readback + 50 DELETE |
| **O3** GHCR | P5 +11 | **zyklisch blockiert**: Push verboten vor `MARKET_READY:true`, das aber GHCR-Digests verlangt. Owner muss entscheiden, welche Seite nachgibt |

**Zahlung öffnet NICHTS.** `payment_required` ist bei O1/O2/O3 `false`; eine im Manifest
abgebildete Zahlung macht `owner-input-matrix` **rot**.

**L4 (55) / L5 (56)** sind **bewusst null-kreditiert** und werden von **zwei** Verifiern geprüft.
Hochsetzen = Fake-Completion.

---

## ⛔ VERBOTE

`git add -A` · `git commit` **ohne Pathspec** (R-NEU-10) · Force-Push · Push auf Default-Branch ·
Prozente hochsetzen · `live_verified` von Hand · L4/L5 hochsetzen ·
Zahlung / Kreditkarte / Paid Provider / Fly.io / R2 / CF Containers ·
Secrets in Chat, Datei, Log oder Commit (nur **Pfad + Fundtyp** melden) ·
Token rotieren („Roll") — vom Owner **ausdrücklich abgelehnt** ·
parallel Playwright / Docker / Verifier · `TEMP`/`TMP` ≠ `D:\_sb_tmp` ·
DEV-ONLY-Evidenz als Hosted-Beweis ausgeben.

**Vier Wände, die kein Agent überschreitet:** Kreditkarte/Zahlung · Passwort-Konten · CAPTCHA ·
Secrets ausgeben/committen.

---

## 🧠 DIE VIER REGELN, DIE TEUER GELERNT WURDEN

- **R-NEU-7** — Die Lastmessung maß sich selbst: `ForEach-Object -Parallel` + `Invoke-WebRequest`
  = ein TLS-Handshake **pro Request**. 21.180 ms → **299,9 ms** mit gepooltem `HttpClient`.
  **98,6 % war Messfehler.** Schwelle wurde nicht gesenkt.
- **R-NEU-8** — „blockiert" heißt *noch nicht erledigt* **oder** *dauerhaft eingefroren*.
  Nur das Erste ist Arbeit.
- **R-NEU-9** — Eine Kette darf **nie** ihre eigene Ausgabe als Eingabe verlangen.
  Folge des Verstoßes: HEAD war rot **und gepusht**.
- **R-NEU-10** — `git commit` ohne Pathspec committet den **gesamten** Index.
  Beleg `a8331d89`: Doku-Nachricht, **34 Dateien**.

---

## 🪤 FALLEN

Phantom-503 = `start-dev-live.ps1` vergessen ·
Playwright `networkidle` bei pausierter Clock **kann nie** eintreten → `load` + `pauseAt(+1000ms)` ·
`wrangler secret put` scheitert an CF-**10053** (es sind `plain_text`-Vars) → `deploy --keep-vars --var …` ·
Docker kann die `.git`-**Datei** eines Worktrees nicht mounten → echten Clean-Clone nutzen ·
C: < 6 GB vor Docker-Build → erst `docker builder prune` (ein disk-full-Abbruch hat schon das
ext4-Journal zerschossen) · `#Requires -Version 7` → Verifier mit `pwsh` starten ·
`endpoint-snapshot.json` ist **minified single-line** (`separators=(',',':')`, `+"\n"`) ·
P5-Prozent hat **fünf** Spiegel inkl. hartem Pin `verify-phase1.ps1:571`.

---

*Kurzfassung — Details, Belege und Owner-Klickfolgen in `CODEX_UEBERGABE_2026-08-02-SESSION14.md`*
