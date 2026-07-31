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
