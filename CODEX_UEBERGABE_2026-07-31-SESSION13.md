# CODEX-ÜBERGABE — SESSION 13 (2026-07-31)
### Ersetzt `CODEX_UEBERGABE_2026-07-27-SESSION12.md` als aktive Übergabe.
> Jede Zahl in diesem Dokument stammt aus einem Verifier-Lauf oder einem Repo-Artefakt dieser Session.
> Nichts ist geschätzt. Wo etwas **nicht** bewiesen ist, steht es ausdrücklich als offen.

---

# 0 · SOFORT-EINSTIEG (2 Minuten)

```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'     # PFLICHT vor JEDEM Verifier
git log -1 --format='%H %s'                        # erwartet: c8ef2263 oder Nachfolger
git status --short --untracked-files=no            # erwartet: genau 2 fremde dirty Dateien
docker ps --filter 'name=cloud-superbrain-phase1-dev' --format '{{.Names}} {{.Status}}'
```

**Erwarteter Zustand:** Branch `claude/cloud-superbrain-analysis-127d2e`, HEAD = `origin`,
10/10 Container healthy, Overall **86 %**, `MARKET_READY: false`.

**Zwei fremde dirty Dateien sind normal und dürfen NIE gestaged werden:**
`.codex/runs/CURRENT/product-acceptance/report.json` · `apps/frontend/tsconfig.tsbuildinfo`

---

# 1 · WO DAS PROJEKT STEHT

## 1.1 Kennzahlen
| Größe | Wert |
|---|---|
| Overall | **86 %** |
| Horizontal | P0 100 · P1 100 · P2 100 · **P3 44** · P4 100 · **P5 68** · **P6 90** |
| Vertikal | FE 100 · ORC 100 · **AP 100** · **LLM 55** · **MCP 56** · **MEM 100** · OBS 100 |
| Capability-Gates | **7 offen / 3 zu** |
| Externe Gates | **1 offen** (`ghcr_image_digest_verify`) |
| `MARKET_READY` | **false** — korrekt, kein Fehler |

## 1.2 Capability-Gates (gemessen 2026-07-31 nach O4, nicht geschätzt)
**✅ offen (7):** `live_llm_provider_calls` · `live_memory_provider` ·
`cloudflare_native_zero_card_hosted_runtime` · `live_vector_memory_search` ·
`hosted_observability_endpoint` · **`live_agent_tool_writes`** · **`live_mcp_writes`**

**🔴 zu (3):** `production_auth_identity` (O1, Owner) · `docker_registry_publish` (O3, Owner,
zuletzt) · `phase6_scale_runtime` (Zahlung, echte Wand)

## 1.3 🧮 DIE WICHTIGSTE RECHENREGEL — sonst sucht man ewig an der falschen Stelle
`scripts/verify_project_progress_manifest.py` erzwingt hart:
```
overall_percent == round( Σ horizontale Phasen / Anzahl Phasen )
```
**Vertikale Layer gehen NICHT in `overall` ein.** Deshalb blieb `overall` bei 86, obwohl L3 von 69
auf 100 und L6 von 90 auf 100 stieg — das ist korrekte Arithmetik, kein Beschönigen.
**Wer die 86 % bewegen will, muss P3, P5 oder P6 bewegen** — und alle drei sind Owner-/Zahlungs-Gates.

## 1.4 ⛔ L4 (55) UND L5 (56) SIND BEWUSST NULL-KREDITIERT — NICHT VERGESSEN
Die Versuchung ist groß, hier „vergessene" Prozente zu sehen. Die **Fähigkeiten sind bewiesen**:
- **L4:** Hosted-Produktbeweis zeigt `gateway_mode=cloudflare_workers_ai_live`, `live_calls=true`,
  `direct_provider_calls=false`, persistiert und auditiert — das Gate ist offen.
- **L5:** O4-Beweis zeigt bounded, auditierten MCP-Write mit Readback und Rollback.

**Trotzdem ist der Prozent-Credit ausdrücklich null, und das ist maschinell erzwungen:**

| Quelle | Feld | Wert |
|---|---|---|
| `actions[O4].percentage_credit_breakdown` | `layer_3` | **31** (das erklärt 69→100) |
| " | `layer_5` | **0** |
| " | `phase_6` | **0** |
| `actions[O6].percentage_credit` | — | **0** |

`actions[O6].codex_boundary` sagt wörtlich: *„does not hand-set live_verified, make Layer 4 equal 100,
authorize direct provider calls, or grant percentage credit."*

**Beide Nullen werden hart geprüft** — `verify-market-ready.ps1` **und** `verify-o4-live-writes.ps1`
enthalten je `[int]$o4Action.percentage_credit_breakdown.layer_5 -eq 0`.

> **REGEL R-NEU-4: L4 und L5 nicht hochsetzen. Ein offenes Gate ist kein Prozent-Credit.
> Die Erhöhung bricht zwei Verifier und ist per Definition Fake-Vollständigkeit.**

## 1.3 Was hosted echt bewiesen ist
- **Produktabnahme + 22-Seiten-Matrix:** `dev_only=false`, `proof_scope=hosted_https`,
  22/22 Routen · 29/29 Familien · 161/161 Aktionen · 0 tote · 0 unregistrierte · 0 Console-Fehler.
- **Cloudflare-Worker:** D1 + Durable Objects + Queues, zero-card, source-gebunden.
- **Semantische Vektorsuche (O5, neu):** siehe §2.

---

# 2 · WAS IN SESSION 13 PASSIERTE

## 2.1 🔴 HEAD war rot — Ursache und Lehre
Session 12 hat `53e4d242` und `0a982c2a` gepusht, **ohne danach `npm run verify` zu fahren**, obwohl
`0a982c2a` `verify-phase1.ps1` anfasste. Zwei unabhängige Regressionen:

1. **Verifier-Widerspruch.** `verify-market-ready.ps1` verlangte `product_acceptance_hosted_proof=true`
   und `workspace_22_page_hosted_proof=true`; `verify-phase1.ps1` verlangte für dieselben Felder
   `false`. Der pauschale Verbots-Guard ist jetzt **evidenzgebunden** (Artefakt + SHA-256 +
   Commit-Ancestry + Deployment-ID). Negativtest: ein verändertes Hex-Zeichen ⇒ Ablehnung.
2. **Gelöschter Wahrheits-Marker.** `53e4d242` ersetzte statt ergänzte den von
   `verify-retired-hosted-boundary.ps1` gepinnten Satz in `AI_HANDOFF.md`. Wiederhergestellt.

> **REGEL R-NEU-1: Nach JEDEM Commit, der einen Verifier oder eine Wahrheitsdatei anfasst, den
> Gesamtlauf `npm run verify` fahren — nicht nur den Fokustest.**

## 2.2 ✅ Branch Protection — die Frage aus Session 12 ist beantwortet
Session 12 endete mit `GATE: BP anwenden? JA/NEIN`. **Antwort: NEIN — es gibt nichts anzuwenden.**
Zwei Illusionsschichten lagen übereinander:
1. Das Skript hatte **keinen Apply-Codepfad** (Session 12 korrekt gefixt).
2. Darunter: `DEFAULT_BRANCH_NAME = "main"` — **`main` existiert in diesem Repo nicht.**

**Der Default-Branch heißt `chore/repo-bootstrap` und ist bereits korrekt geschützt:**
`status: verified`, **0 Abweichungen**, Force-Push aus, Löschen aus, 1 Review. Read-only belegt.

> **REGEL R-NEU-2: „niemals `main`" bleibt inhaltlich richtig, meint faktisch aber
> `chore/repo-bootstrap`. Es gibt keinen `main`-Branch.**

## 2.3 ✅ Externes Gate geschlossen — von 2 auf 1
`verify-external-gates.ps1` hatte `[string]$Branch = $env:BRANCH_NAME` mit Fallback **`""`** und
fragte damit `…/branches/` **ohne Branch** ab. `Resolve-DefaultBranchName()` löst ihn jetzt anonym
über die öffentliche Repo-API auf (tokenfreier Bootstrap bleibt erhalten, fail-closed bei
Nichtauflösung). Kopplung im selben Slice mitgezogen — siehe §4.2.

## 2.4 🟢 O5 ERLEDIGT — semantische Vektorsuche hosted bewiesen
Owner-Freigabe für Index-Anlage erteilt. **Vectorize brauchte kein Zahlungsmittel**
(Workers-Free-Plan, 30 Mio. abgefragte / 5 Mio. gespeicherte Dimensionen) — **die R2-Analogie war
falsch**. Index `cloud-superbrain-memory-v1`, 768 Dim., cosine, passend zu `@cf/baai/bge-base-en-v1.5`.

**Der Beweis ist so gebaut, dass eine lexikalische Engine ihn nicht bestehen kann:**
Abfrage `"feline napping in sunshine"` — **null gemeinsame Inhaltswörter** mit dem Zielsatz
`"A tabby cat dozed on the warm windowsill through the quiet afternoon."`; ein thematisch fremder
Ablenker liegt daneben im Index.
**Ergebnis: Ziel Platz 1 mit `0.7428`, Ablenker `0.3850`, Überlappung `0`.**

**Gate ausschließlich vom Verifier geöffnet** (`-PromoteGateOnFullPass` wirft bei jedem Blocker).
`owner_granted` / `owner_scope_approved` / `architecture_approved` sind separat als **Owner-Fakten**
hinterlegt. Worker-Tests 19/19.

## 2.5 ✅ HOSTED-SOURCE-REBINDING GESCHLOSSEN
Die Remote-Settings zeigten `SOURCE_COMMIT_SHA` und `SOURCE_ARCHIVE_SHA256` als
`plain_text`, nicht als Secrets. `wrangler secret put` war deshalb der falsche Pfad und
scheiterte korrekt mit Cloudflare-Code `10053` (`Binding name already in use`); es war
kein Rate-Limit. Die Werte sind ohnehin über den öffentlichen Health-Vertrag sichtbar.

Der sichere Rebind erfolgte mit `--keep-vars` und den beiden `--var`-Werten:
```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\services\cloudflare-stateful-runtime'
$state = Get-Content '..\..\docs\runtime-state\cloudflare-native-hosted-current.json' -Raw |
  ConvertFrom-Json
$commit = [string]$state.source_commit_sha
$expectedSha = [string]$state.source_archive_sha256
$tmp='D:\_sb_tmp\a.tar'; git -C '..\..' archive --format=tar "--output=$tmp" $commit
$sha=(Get-FileHash $tmp -Algorithm SHA256).Hash.ToLowerInvariant(); Remove-Item $tmp
if ($sha -ne $expectedSha) { throw 'source archive mismatch' }
node node_modules/wrangler/bin/wrangler.js deploy --keep-vars --env "" `
  --var "SOURCE_COMMIT_SHA:$commit" --var "SOURCE_ARCHIVE_SHA256:$sha"
```

Neue Worker-Version: `757cf74c-7988-4790-ae03-ff51534ccea4`.
`/api/v1/health` meldet danach `healthy`,
Source `af61146e22d1a56e9d62232c159ea7b352405ba9` und Archiv
`1d85f2cd6c948a43e0f79fb17d1f02706687d5857d80f4096780692d094b63fc`.
R2 bleibt ungebunden; die Remote-Bindings und der O5-Hosted-Roundtrip wurden erneut grün geprüft.

---

## 2.6 ✅ O4 ABGESCHLOSSEN — bounded, auditierte Live-Writes bewiesen
`live_agent_tool_writes` und `live_mcp_writes` sind **vom Verifier** geöffnet
(`scripts/verify-o4-live-writes.ps1`, Evidenz `.phase1-artifacts/o4-live-writes/proof.json`).
Bewiesen: Audit **vor** und **nach** dem Write, Readback, **Rollback bei Audit-Fehler**,
Write-Scope auf `.phase1-artifacts/o4-live-write-workspace` begrenzt, `main_write=false`,
Kanäle `runtime` + `browser`. Agent Pool **69 → 100** mit itemisiertem Credit `31`.

## 2.7 🔧 KORREKTUR AN DIESER ÜBERGABE — meine frühere Diagnose war falsch
Eine ältere Fassung dieses Dokuments nannte als Ursache für das fehlgeschlagene Hosted-Rebinding
ein **Rate-Limit**. Das war falsch und hätte in eine Sackgasse geführt („später nochmal versuchen").

**Die echte Ursache:** `SOURCE_COMMIT_SHA` und `SOURCE_ARCHIVE_SHA256` sind remote **`plain_text`-Vars,
keine Secrets**. `wrangler secret put` scheitert deshalb korrekt mit Cloudflare-Code **`10053`
(`Binding name already in use`)** — reproduzierbar, kein Timing-Problem. Der richtige Weg ist
`deploy --keep-vars --var …` (siehe §2.5). **Nie erneut auf „Rate-Limit" tippen, wenn `secret put`
auf einem bestehenden `plain_text`-Binding scheitert — der Fehlercode sagt es exakt.**

---

# 3 · DER WEG BIS `MARKET_READY: true`

`MARKET_READY` wird **nur** wahr, wenn `npm run verify:market-ready` es real druckt. Bedingungen:
alle Matrix-Zellen evidenzbasiert auf 100 **und** externe Gates nicht mehr blockierend.

## Reihenfolge (bindend)

### Schritt 1 — ✅ Restarbeit aus §2.5 geschlossen
Source- und Archivbindung stimmen im gehosteten Health-Vertrag.

### Schritt 2 — ✅ L6 Memory 90 → 100 gutgeschrieben
Der Marker lautet `hosted_semantic_vector_search_cloudflare_vectorize_roundtrip_verified`.
Die lexikalische D1-Persistenz wurde nicht doppelt gezählt. Manifest- und O5-Fokustest sind grün;
der verpflichtende Gesamtlauf ist der Abschluss dieses Slices.

### Schritt 3 — ✅ O4 ABGESCHLOSSEN
Beide Gates verifier-geöffnet, Agent Pool 69 → 100. Details in §2.6.
**Achtung:** `layer_5` und `phase_6` haben aus O4 bewusst **0 Credit** — siehe §1.4.

### Schritt 4 — P3 44 → höher (`production_auth_identity`, O1) · **OWNER**
Konfiguration ist erledigt (Compose-Verdrahtung + `JWT_SIGNING_SECRET`), lokal `verified_dev_only`.
**Für das Gate fehlt ein hosted Nachweis.** Der interaktive GitHub-Zustimmungsklick ist eine
**echte Owner-Wand** — nicht umgehen. Prüfen, welcher Teil ohne diesen Klick hosted beweisbar ist
(Konfigurationspräsenz, Fail-closed-Verhalten) und nur diesen gutschreiben.

### Schritt 5 — P6 · **ZAHLUNG**
`phase6_scale_runtime` braucht Zahlung ⇒ **bleibt zu**. Local-Load-Test ist Overclaim.
Eine der vier Wände.

### Schritt 6 — P5 / O3 GHCR · **OWNER, ZULETZT**
Laut Owner-Matrix `codex_boundary` erst **nach** `MARKET_READY: true`. Owner-Aktion.

---

## 3.1 🛑 EHRLICHER GESAMTBEFUND: DIE AUTONOME FLÄCHE IST ERSCHÖPFT
Stand 2026-07-31 ist **jede** Zelle unter 100 aus genau einem von zwei Gründen offen:

| Zelle | Grund | autonom lösbar? |
|---|---|---|
| P3 44 | `production_auth_identity` — OAuth-Klick | ❌ Owner-Wand |
| P5 68 | `docker_registry_publish` — GHCR | ❌ Owner, erst nach MARKET_READY |
| P6 90 | `phase6_scale_runtime` — Zahlung | ❌ eine der vier Wände |
| L4 55 | O6 `percentage_credit = 0`, verifier-geprüft | ❌ bewusst null-kreditiert |
| L5 56 | O4 `credit.layer_5 = 0`, **zweifach** verifier-geprüft | ❌ bewusst null-kreditiert |

**Es existiert derzeit keine Zelle, die ein Agent ohne Owner-Handlung ehrlich anheben könnte.**
Wer trotzdem eine Zahl erhöht, fälscht — und bricht dabei nachweislich Verifier.
Die nächste echte Arbeit beginnt erst **nach einer Owner-Entscheidung zu O1 oder O3.**

---

# 4 · WISSEN, DAS FEHLER VERHINDERT

## 4.1 Fallen, die in Session 13 real zugeschlagen haben
| # | Falle | Richtig |
|---|---|---|
| 1 | `Authorization: Bearer` am Worker | Header heißt **`x-superbrain-agent-token`** |
| 2 | `wrangler secret put SOURCE_*` | Remote sind beide `plain_text`; Rebind per `deploy --keep-vars --var ...`, danach Health-Parität |
| 3 | `//`-Kommentar in `wrangler.jsonc` | `verify-cloudflare-stateful-runtime.ps1` parst mit **reinem `ConvertFrom-Json`** ohne Kommentar-Entfernung → **keine Kommentare**, trotz `.jsonc` |
| 4 | Substring-Check auf `semantic\|vectorize` | Traf `vectorize: "owner_gate_required"` und einen Non-Claim → **falsches Grün**. Auf **Verwendung** prüfen (`env.VECTORIZE` + `env.AI`) |
| 5 | `Set-Location` + `[IO.File]::ReadAllText` | .NET nutzt ein eigenes Arbeitsverzeichnis → **absolute Pfade** |
| 6 | `Set-Content` zum Restaurieren | Ändert Zeilenenden/BOM → **`git checkout -- <pfad>`** |
| 7 | Einbuchstabige Funktionsnamen in Secret-Skripten | `H` kollidiert mit `Get-History`; die Exception hat einen Token ausgegeben. **Nie 1–2-Zeichen-Namen** |
| 8 | `$ErrorActionPreference='Stop'` um Kindprozesse | stderr des Kindes wird zur Terminating Error → Test bricht vor der Assertion ab |

> **REGEL R-NEU-3: Verträge nie über Wortvorkommen prüfen, immer über tatsächliche Verwendung.**
> Ein Non-Claim enthält dieselben Wörter wie eine Implementierung — und behauptet das Gegenteil.

## 4.2 Gekoppelte Assertions — nie einzeln anfassen
Wer ein externes Gate schließt, **muss im selben Slice**:
- `verify-phase1.ps1` — bindet an `branch_protection_claim_allowed`, **beidseitig** fail-closed
- `verify-market-ready.ps1` — zwei Stellen (Summary **und** Owner-Manifest)
- `docs/runtime-state/owner-input-manifest.json` — `external_gate_truth.missing_or_failed_gates`
- `verify-go-live-readiness.ps1` — **braucht nichts**, ist bereits konditional

**Betriebs-Falle:** Jeder `verify-external-gates`-Lauf legt ein **neues zeitgestempeltes** Artefakt in
`.phase1-artifacts/` an. `verify-retired-hosted-boundary.ps1` verlangt, dass **`PROJECT_STATE.md`,
`AI_HANDOFF.md` UND `docs/verification-register.md`** auf das **neueste** zeigen — sonst rot.

## 4.3 Strukturelle Grenzen (kein Bug von heute, aber wissen)
- `verify-live-llm-evidence-chain.ps1` vergleicht **zwei untracked, gitignorierte** Artefakte und
  scheitert hart, wenn sie fehlen ⇒ **`npm run verify` kann auf einem frischen Clone nie grün werden.**
  Bei Drift: `.codex/tmp/stateful-browser-sync.ps1` resynchronisiert (Worker 8791 + Next 3018).
- `.phase1-artifacts/` ist ebenfalls gitignored — dieselbe Klasse.

## 4.4 Diagnose-Reflexe
- **Verifier plötzlich rot ohne Codeänderung?** Zuerst `Get-PSDrive C,D` — ein volles Laufwerk tarnt
  sich als Code-Fehler. Danach Docker-Health.
- **`session_missing` in der UI** = schlicht **nicht eingeloggt**, kein Defekt.
- **Fehlende Datei-Meldung bei Umlauten?** `git -c core.quotepath=false` verwenden.

---

# 5 · UNVERHANDELBARE REGELN (R0)

1. **Kein Fake-Done.** `live_verified` **nie** handsetzen — nur ein echter Verifier darf schreiben.
2. **Keine Doppelzählung.** Bereits gutgeschriebene Marker nicht erneut kreditieren.
3. **Free-Only.** Keine Kreditkarte, kein bezahlter Provider, kein Fly.io, **kein R2**.
   *(Vectorize ist frei und belegt — R2 nicht.)*
4. **Keine Secrets** in Chat, Dateien, Logs, Commits. Nur Pfad + Befundtyp nennen.
5. **Kein Push nach `main`** — existiert ohnehin nicht; gemeint ist `chore/repo-bootstrap`.
   Kein Force-Push, kein GHCR-Publish, keine Release-Promotion ohne Gate.
6. **Fremde dirty Dateien** nie stagen, nie revertieren. **Nie `git add -A`.**
7. **`$env:TEMP`/`$env:TMP` auf `D:\_sb_tmp`** vor jedem Verifier (sonst gitleaks-Selbstrekursion).
8. **Kein paralleler** Verify-/Playwright-/Docker-Build-Lauf.
9. **Localhost-Belege** immer als `DEV-ONLY` kennzeichnen.

## Die vier Wände (kein Agent, auch nicht mit Root)
**1.** Kreditkarte/Zahlung · **2.** Passwort-Accounts · **3.** CAPTCHA · **4.** Secrets ausgeben/committen

---

# 6 · VERIFIER-LANDKARTE

| Zweck | Befehl | Dauer |
|---|---|---|
| Statisches Gesamtgate | `npm run verify` | ~5 min |
| Runtime | `npm run verify:runtime` | lang |
| Browser | `npm run verify:browser` | sehr lang |
| Marktreife | `npm run verify:market-ready` | mittel |
| Externe Gates | `npm run verify:external-gates` | kurz |
| O5 semantisch | `scripts/verify-live-vector-memory-search.ps1 -AllowScopeProbe -AllowHostedRoundtrip` | ~2 min |
| Branchschutz (read-only) | `py -3 scripts/apply_github_branch_protection.py --verify-only` | Sekunden |

**Serielle Reihenfolge:** statisch → Runtime → Browser. Niemals parallel.

---

# 7 · ABSCHLUSSDEFINITION

Melde `MARKET_READY: true` **ausschließlich**, wenn der kanonische Verifier es real druckt.
Andernfalls gilt: **alles autonom Lösbare echt auf 100 + der Rest exakt als OWNER-BLOCKED benannt,
mit konkretem Owner-Action-Paket.** Nichts anderes zählt als fertig.

**Aktueller ehrlicher Stand: 86 %, `MARKET_READY: false`, 1 externes Gate offen (GHCR),
4 Capability-Gates zu — davon 1 echte Zahlungswand.**

---

## §4 OWNER-AKTIONSPAKET — die zwei verbleibenden Handlungen

Alles Autonome ist erledigt. Was fehlt, kann **nur der Owner** auslösen.

### O1 — GitHub-OAuth-Klick → hebt P3 (44)
- **Owner:** Autorisierungsdialog der OAuth-App einmalig bestätigen. Ein Klick.
- **Vorbereitet:** Compose-Config + `JWT_SIGNING_SECRET` liegen, lokal `verified_dev_only`.
- **Codex danach:** hosted Nachweis fahren, `production_auth_identity` ausschliesslich ueber den
  echten Verifier oeffnen, gekoppelte Assertions im **selben Slice** nachziehen
  (`verify-phase1.ps1` · `verify-market-ready.ps1` 2 Stellen · `owner-input-manifest.json`).
- **Verboten:** Gate ohne hosted Evidenz oeffnen; Klick simulieren/umgehen (Wand 2/3).

### O3 — GHCR → hebt P5 (68), ERST NACH `MARKET_READY: true`
- **Owner:** Publikation der sechs Images aus dem aktiven RC freigeben.
- **Sperre:** `codex_boundary` verbietet Registry-Publish davor — Reihenfolge ist bindend.
- **Codex danach:** `verify:release-candidate` + `verify:current-release-candidate`,
  dann `ghcr_image_digest_verify` (letztes externes Gate) schliessen.

### P6 (90) — bleibt zu
`phase6_scale_runtime` erfordert Zahlung. Wand 1. Ehrlich als OWNER-BLOCKED listen, nie umgehen.

### L4 (55) / L5 (56) — NICHT ANFASSEN
Faehigkeiten bewiesen, Credit bewusst **0** (`O4.percentage_credit_breakdown.layer_5 = 0`,
`O6.percentage_credit = 0`), geprueft von `verify-market-ready.ps1` **und**
`verify-o4-live-writes.ps1`. Hochsetzen bricht zwei Verifier = Fake-Completion.
**Ein offenes Gate ist kein Prozent-Credit.**

**Merksatz fuer Session 14:** Ohne O1- oder O3-Entscheidung existiert **keine** Zelle, die ein Agent
ehrlich anheben kann. Dann ist der korrekte Output ein Statusbericht — kein Zahlenanstieg.

---

## §5 DEEP-ANALYSE DER RESTBLOCKER (Session 13b) — zwei harte Korrekturen

Owner-Auftrag war: *"wir oeffnen jetzt eins nach dem anderen was blockiert ist, auch mit Bezahlung."*
Die Analyse ergibt: **Bezahlung oeffnet nichts, und die Ziellinie ist zirkulaer.** Beides mit
Datei- und Zeilenbeleg, nicht als Einschaetzung.

### 5.1 Korrektur A — Zahlung ist kein Blocker, sondern verifier-verboten

Frueher stand in dieser Uebergabe *"P6 braucht Zahlung, Wand 1"*. **Das war falsch.** Gemessen:

| Quelle | Feld | Wert |
|---|---|---|
| `owner-input-manifest.json` O1 | `payment_required` | `false` |
| `owner-input-manifest.json` O2 | `payment_required` / `zero_card_required` | `false` / `true` |
| `owner-input-manifest.json` O2 | `payment_forbidden` / `paid_fallback_forbidden` | `true` / `true` |
| `owner-input-manifest.json` O3 | `payment_required` | `false` |
| `capability-gates.json` (alle 3 zu) | `paid_provider` | `false` |

`scripts/verify-market-ready.ps1:298-305` **prueft aktiv** `payment_required -eq $false`,
`zero_card_required -eq $true`, `paid_fallback_allowed -eq $false`. Eine Zahlung, die im Manifest
abgebildet wuerde, macht `owner-input-matrix` rot und damit `MARKET_READY` **false**.
Repoweit stehen 61 Zero-Card-/Payment-Assertions in `scripts/`.

> **Regel R-NEU-5:** Zahlung ist in diesem Projekt kein Beschleuniger, sondern ein **Rueckschritt**.
> Wer P6 mit "Budget" erklaeren will, hat den Blocker nicht gelesen. Der echte Mangel ist ein
> **Scale-/Kapazitaetsbeweis bei Zero-Card**, und `scripts/verify-phase6-scale-runtime.ps1`
> **existiert nicht** (Gate-Feld `verifier` ist leer).

### 5.2 Korrektur B — die Ziellinie enthaelt einen Deadlock

Mechanik: `verify-market-ready.ps1:699` `MARKET_READY = ($requiredFails.Count -eq 0)`.
`:619` `Add-Result "manifest-all-100" $allHundred … $true` → **required**.
`:88` sammelt `horizontal.items` **und** `vertical.items` → hier zaehlen alle 14 Zellen
(anders als bei `overall_percent`, das nur horizontal rechnet — beide Regeln gelten parallel).

Daraus folgt zwingend:

```
MARKET_READY:true  ->  phase_5 = 100  ->  O3 (GHCR-Publikation)
O3.codex_boundary  ->  "No registry push ... before MARKET_READY:true"
                   ->  MARKET_READY:true
```

**Zirkel.** `owner-input-manifest.json:117` ist die Quelle der Ordnungsregel,
`:288` bestaetigt *"MARKET_READY remains false until every matrix cell is … 100"*.
Von innen nicht aufloesbar — auch nicht durch Owner-Klick, auch nicht durch Zahlung.

**Zweiter Widerspruch (P6):** `manifest-all-100` verlangt `phase_6 = 100`, waehrend
`verify-market-ready.ps1:204-217` verlangt, dass `phase6_scale_runtime.live_verified` **false**
bleibt (`$closedGateStateOk`). Beide Schritte sind `required`.

### 5.3 Was daraus folgt — und was Codex NICHT tun darf

- **Nicht** die Ziellinie umschreiben, um sie erreichbar zu machen. Das ist dieselbe Fehlklasse wie
  Prozente hochsetzen: man faelscht dann nicht die Zahl, sondern das Kriterium.
- **Nicht** ein Scale-Kriterium selbst erfinden. Eine selbstgewaehlte Messlatte ist eine
  gefaelschte Ziellinie.
- **Nicht** zahlen, nicht auf paid fallback ausweichen (siehe 5.1).

### 5.4 Owner-Entscheidungen E1–E3 (Reihenfolge ist die Antwort auf "eins nach dem anderen")

**E1 — O1 sofort.** Der einzige Blocker ohne Zahlung, ohne Deadlock, ohne Vorbedingung.
Owner: OAuth-App waehlen/anlegen, Hosted-Callback freigeben, Credential ueber den Secret-Kanal.
Codex danach: `scripts/verify-phase3-auth-fail-closed.ps1` (**existiert**) + `npm run verify:browser`,
Gate `production_auth_identity` **nur** ueber den Verifier oeffnen, gekoppelte Assertions im selben
Slice (`verify-phase1.ps1` · `verify-market-ready.ps1` 2 Stellen · `owner-input-manifest.json`).
**Achtung:** `:204-217` erwartet dieses Gate aktuell als *geschlossen* — beim Oeffnen muss
`$expectedClosedGateIds` im selben Commit mitgezogen werden, sonst kippt `owner-input-matrix`.

**E2 — P6-Kriterium definieren (Owner).** Messbare Definition von "Scale-Proof bei Zero-Card",
z. B. begrenzte Parallellast gegen den Hosted-Worker **innerhalb** des Free-Kontingents, ohne
Overage-Risiko. Erst danach darf `scripts/verify-phase6-scale-runtime.ps1` gebaut und das Gate
verifier-gebunden werden.

**E3 — Deadlock aufloesen (Owner waehlt genau eine Option).**
- **(a)** `phase_5 = 100` := *release-candidate-ready*; GHCR-Publikation wird **Post-Market-Schritt**.
  Vorteil: O3-Boundary bleibt unveraendert, `manifest-all-100` wird erfuellbar.
- **(b)** O3-`codex_boundary` aendern zu *"nach explizitem Owner-Gate, unabhaengig von MARKET_READY"*.
  Vorteil: Publikation zuerst; Nachteil: die Schutzreihenfolge faellt.

**Ohne E3 ist `MARKET_READY:true` strukturell unerreichbar** — unabhaengig von Arbeitsmenge, Tokens
oder Budget. Das ist der wichtigste Satz dieser Uebergabe.

---

## §6 E2 UND E3 AUSGEFUEHRT (Session 13c) — ein echtes Rot, kein geschoentes Gruen

### 6.1 E3 — Option (a) gewaehlt, mit einer Korrektur am eigenen Plan

**Warum (a) und nicht (b):** `docker_registry_publish` steht in `$expectedClosedGateIds`
(`verify-market-ready.ps1:204-217`). Eine GHCR-Publikation wuerde das Gate `live_verified` machen,
`$closedGateStateOk` auf false setzen und `MARKET_READY` **erneut** auf false druecken. Option (b)
loest den Deadlock also nicht, sie verschiebt ihn — und kostet dabei zwei Schutzmechanismen.
Option (a) aendert an den Verifiern **nichts**.

Inhaltlich ist (a) ebenfalls das Richtige: Phase 5 heisst *Release **Readiness***, und ihre eigenen
Marker (`production_candidate_no_release`, `no_release_decision_verified`,
`candidate_promotion_gate_refusal_verified`) schreiben Fortschritt ausdruecklich dem **Nicht**-
Veroeffentlichen gut. Publikation war als Readiness-Kriterium **fehlklassifiziert**.

> **Korrektur am eigenen Vorschlag:** Der zuvor genannte Schritt „O3 als `post_market`
> umklassifizieren" ist **nicht erlaubt**. `verify-market-ready.ps1:126` laesst fuer `status` nur
> `owner_required` oder `resolved_verified` zu; alles andere fuellt `$invalidActions` und macht die
> Matrix rot. **O3 bleibt `owner_required`, `affected_cells` bleiben unveraendert** — sonst bricht
> zusaetzlich die `$expectedOwnerActionCells`-Zuordnung (`:155-158`).

**Was (a) blockiert — und warum `phase_5` NICHT auf 100 gesetzt wurde:**
`scripts/verify_project_progress_manifest.py` prueft nur `0 <= percent <= 100` und einen nicht-leeren
`status`. **Es gibt keine maschinelle Evidenzbindung pro Zelle** — die Prozente sind handgepflegt.
Und fuer `phase_5` existiert **keine itemisierte Aufschluesselung** der fehlenden 32 Punkte
(anders als bei O4, das `percentage_credit_breakdown` traegt; Suche ueber `docs/` liefert fuer
`phase_5` nur die zwei `affected_cells`-Treffer in O1/O2/O3).

> **Daraus folgt hart:** Jede Zahl, die ich jetzt fuer `phase_5` schreibe, waere **erfunden** — der
> Verifier wuerde sie widerstandslos akzeptieren. Genau deshalb wurde sie **nicht** gesetzt.
> **R-NEU-6:** Fehlende Verifier-Pruefung ist kein Freibrief, sondern die Stelle, an der nur noch
> Disziplin schuetzt. Vor jeder `phase_5`-Anhebung muss eine Evidenz-Itemisierung existieren.

### 6.2 E2 — Kriterium zuerst, dann gemessen, dann ehrlich durchgefallen

Reihenfolge ist in der Git-Historie belegt, nicht behauptet:
`6c761aa2` committet **nur** `docs/runtime-state/phase6-scale-criterion.json` — der messende Code
existierte da noch nicht. Der Lauf konnte also scheitern. **Er ist gescheitert.**

| Stufe | n | 2xx | 429 | 5xx | p95 |
|---|---|---|---|---|---|
| c=1 | 60 | 60 | 0 | 0 | **271 ms** |
| c=10 | 240 | 240 | 0 | 0 | **3.140 ms** |
| c=50 | 500 | 500 | 0 | 0 | **21.180 ms** |

Zweiter Lauf reproduziert (22.226 ms bei c=50). Erfolgsquote 1.0, **null** 5xx, **null** 429 —
Korrektheit haelt, Latenz bricht ein. Kriterium `max_p95_ms = 1500` → **FAIL**, Exit 1.
`phase6_scale_runtime` bleibt **zu**. Artefakt: `.phase1-artifacts/phase6-scale/scale-evidence.json`.

> **Das Kriterium wurde nach dem Fehlschlag NICHT gelockert.** Eine Schwelle, die man senkt, weil sie
> gerissen wurde, ist keine Schwelle.

### 6.3 Methodik-Vorbehalt — der Befund ist NOCH KEIN Server-Befund

Jede Anfrage laeuft in einem eigenen PowerShell-Runspace mit frischem TLS-Handshake und ohne
Connection-Reuse. Bei c=50 ist die **Harness selbst** ein plausibler Hauptkostenfaktor. Das Artefakt
traegt deshalb `attribution_valid: false` und `measurement_scope: "end_to_end_client_observed"`.

**Wer aus diesen Zahlen „der Worker skaliert nicht" ableitet, zieht einen unbelegten Schluss.**
Vor einer Server-Aussage braucht es Connection-Reuse **oder** ein worker-seitiges Dauersignal.
Das ist ein Mangel **meiner Messung**, kein Grund, die Schwelle zu aendern.

### 6.4 Offen fuer den naechsten Lauf

1. **`AGENT_API_AUTH_TOKEN`** fehlt → die Write-Stufe (parallele D1-Writes mit Readback, der
   eigentliche Scale-Beweis) lief nie. Der Verifier meldet das als `BLOCKED` (Exit 2) und
   verweigert ausdruecklich ein Read-only-Gruen.
2. **Harness haerten** (Connection-Reuse / Server-Timing), damit p95 ueberhaupt zuordenbar wird.
3. **`phase_5`-Evidenz itemisieren**, bevor irgendjemand die 68 anfasst.

---

## §7 HARNESS GEHAERTET + PHASE_5 ITEMISIERT (Session 13d)

### 7.1 Der Fehlschlag aus §6.2 war zu ~98,6 % Messfehler

Alte Harness: ein Runspace **pro Request**, frischer TLS-Handshake, kein Connection-Reuse.
Neu (`6834ab61`): **ein** gepoolter `HttpClient` (`SocketsHttpHandler`, closed-loop Wellen) plus
**Edge-Kontrolle** gegen `/cdn-cgi/trace` — von der Cloudflare-Edge bedient, **ohne** den Worker zu
betreten. Gleicher Client, gleiches TLS, gleiche Edge, nur ohne unseren Code.

| c | alt | neu | Edge-Kontrolle | **Worker-Anteil** |
|---|---|---|---|---|
| 1 | 271 ms | **59,7 ms** | 30,4 ms | **29,3 ms** |
| 10 | 3.140 ms | **229,6 ms** | 49,3 ms | **180,3 ms** |
| 50 | 21.180 ms | **299,9 ms** | 60,7 ms | **239,2 ms** |

**Schwellen, Stufengroessen und Request-Budget blieben unveraendert** — nur die Messung wurde
korrigiert. Die Read-Stufe besteht das **urspruenglich** deklarierte 1.500-ms-Kriterium jetzt aus
eigener Kraft. Genau deshalb war es richtig, die Schwelle nach dem Fehlschlag **nicht** zu senken:
der Fehler lag im Messgeraet, nicht in der Messlatte.

Der Worker haelt bei 50-facher Parallelitaet: Eigenanteil waechst nur von 29 ms auf 239 ms,
Erfolgsquote 1,0, null 5xx, null 429.

> **R-NEU-7:** Vor jeder Latenz-Aussage die **Harness** kontrollieren. Ein Messaufbau ohne
> Connection-Reuse misst sich selbst. Die Kontrollgruppe (`/cdn-cgi/trace`) ist Pflicht, nicht Kuer.

**Gate bleibt trotzdem zu** (Exit 2, `BLOCKED`): die Write-Stufe — parallele D1-Writes mit Readback,
der eigentliche Scale-Beweis — lief mangels `AGENT_API_AUTH_TOKEN` nie. Read-Kapazitaet allein ist
kein Scale-Beweis, und der Verifier verweigert dafuer ausdruecklich ein Gruen.

### 7.2 `phase_5` itemisiert — `docs/runtime-state/phase5-credit-itemization.json`

**Marker-Zensus:** 71 gesamt · 60 `_verified` · 5 Zustandsmarker · **6 blockiert**.

**Ehrliche Grenze, die im Dokument steht:** 65 von 71 nicht-blockierten Markern sind ~92 %, die Zelle
steht aber auf **68**. **Es existiert kein Artefakt, das die Herleitung der 68 festhaelt.** Damit laesst
sich der *Inhalt* der Luecke benennen, aber die *Arithmetik* nicht rueckrechnen. Eine Umrechnung der
Bloecke in Prozentpunkte braucht eine **Owner-Gewichtung** — sie hier zu erfinden waere exakt der
Fehler, den das Dokument verhindern soll.

**Block A — GHCR/Release (O3).** Owner-gated. `ghcr_image_digest_verify` ist der einzige verbliebene
Eintrag in `missing_or_failed_gates`. Per E3(a) **Post-Market** — darf `phase_5` nach Uebernahme der
Readiness-Definition nicht mehr unter 100 halten.

**Block B — 6 blockierte Marker, gebunden an eine stillgelegte Hosting-Grenze.** ⭐ Der eigentliche
Fund: Diese Release-Candidate-Browser- und Sweep-Beweise haengen an der **retired sslip.io/Hetzner**-
Bruecke (`Status: superseded`, `retired_boundary: sslip_io_hetzner`, gepinnt von
`verify-retired-hosted-boundary.ps1`). **Es gibt aber eine aktuelle Hosted-Flaeche mit frischer
Browser-Evidenz** (`dev_only=false`, `proof_scope=hosted_https`, 22/22 Routen, 161/161 Aktionen).
→ **Kein Owner-Gate, keine Zahlung noetig.** Damit ist Block B der erste seit langem wieder
**autonom bearbeitbare** Kandidat.

> ⚠️ **Vor der Arbeit pruefen, nicht behaupten:** ob Candidate-Artefakte und aktuelle Hosted-URLs
> zusammenpassen. Und: **die sechs superseded-Artefakte bleiben superseded.** Altevidenz an eine neue
> Grenze umzuhaengen waere Evidence-Laundering, kein Nachweis. Nur ein **frischer Lauf** zaehlt.

### 7.3 Naechster Schritt

**Block B auf Machbarkeit pruefen und, wenn tragfaehig, frisch ausfuehren.** Das ist die einzige
identifizierte Arbeit, die derzeit ohne Owner-Handlung echten Fortschritt erzeugen kann.

---

## §8 BLOCK-B-MACHBARKEIT GEPRUEFT: NEIN (Session 13e) — Selbstkorrektur

In §7.2 stand, Block B sei **wahrscheinlich autonom bearbeitbar**. Die Pruefung widerlegt das.
Die Einschaetzung wird **zurueckgezogen**.

**Belege:**

| Befund | Konsequenz |
|---|---|
| Die 6 Marker gehoeren zu `prod-candidate-2026-05-05-rc1` | Die Kandidatenlinie steht bei `prod-candidate-2026-07-24-local-rc10`. **Es gibt keine rc1-Flaeche mehr zum Nachmessen.** |
| `browser-proof.md`: `Status: superseded`, `current_candidate_evidence: false`, `historical_base_url: https://188-34-191-140.sslip.io` | Host existiert nicht mehr |
| `verify-retired-hosted-boundary.ps1` pinnt die Records mit **34 Assertions** | **Bewusst eingefrorene Historie**, kein offener Arbeitsposten |
| Entsperrbedingung im Artefakt: `current_hosted_gate_status: blocked_pending_vercel_fly` | Nennt **Fly** — dauerhaft ausgeschlossen (Free-Only) |

**Entscheidend:** `phase_5` traegt separat `phase5_current_candidate_requalified_source_bound_browser_verified`.
Der **aktuelle** Kandidat hat also source-gebundene Browser-Evidenz. Die rc1-Luecke ist eine
**historische Buchungsluecke, kein Evidenzmangel am Produkt.**

> **R-NEU-8:** „Blockiert" heisst hier zweierlei — *noch nicht erledigt* oder *dauerhaft eingefroren*.
> Nur das erste ist Arbeit. Vor jedem Aufwand: gehoert der Marker zur **aktiven** Kandidatenlinie?
> Bei rc1-Markern lautet die Antwort immer **nein**.

**Damit ist die autonome Flaeche erneut leer.** Die echte offene Frage ist keine Arbeit, sondern eine
**Owner-Gewichtung:** Sollen sechs dauerhaft eingefrorene rc1-Historienmarker `phase_5` weiterhin
unter 100 halten? Niemand kann sie je wieder ausfuehren. Antwortet der Owner „nein", faellt Block B
aus der Luecke — dann bleibt fuer `phase_5` **nur noch Block A (GHCR/O3)**, und der ist per E3(a)
ohnehin als Post-Market klassifiziert.
