# 🎯 ZIEL-VERFOLGUNG (KURZ) — Stand 2026-07-31 (Session 13)
> **Reihenfolge in JEDER Session:** (1) diese Datei → (2) `CODEX_UEBERGABE_2026-07-31-SESSION13.md`
> → (3) Preflight → (4) arbeiten. Die Session-12-Übergabe ist **historisch**.

## ENDZIEL
Beide Matrizen **100 %**, jede Zelle mit echtem Artefakt.
**Finish-Line:** `npm run verify:market-ready` druckt real `MARKET_READY: true`.
Owner-gewallte Reste ehrlich als **OWNER-BLOCKED** listen — **nie faken** (R0).

---

## ✅ STAND (gemessen, nicht geschätzt)
Branch `claude/cloud-superbrain-analysis-127d2e` · HEAD = `origin` · Overall **86 %** · `MARKET_READY:false`
`P0 100 · P1 100 · P2 100 · P3 44 · P4 100 · P5 68 · P6 90`
`FE 100 · ORC 100 · AP 100 · LLM 55 · MCP 56 · MEM 100 · OBS 100`

**Capability-Gates: 7 offen / 3 zu** · **Externe Gates: nur noch `ghcr_image_digest_verify`**

| offen ✅ | zu 🔴 |
|---|---|
| `live_llm_provider_calls` | `production_auth_identity` (O1 — OAuth-Klick = Owner-Wand) |
| `live_memory_provider` | `docker_registry_publish` (O3 — Deadlock, Aufloesung = E3 Option (a)) |
| `cloudflare_native_zero_card_hosted_runtime` | `phase6_scale_runtime` (**NICHT Zahlung** — Read-Stufe gruen, Write-Stufe fehlt) |
| `live_vector_memory_search` | |
| `hosted_observability_endpoint` | |
| `live_agent_tool_writes` **(O4, neu)** | |
| `live_mcp_writes` **(O4, neu)** | |

## 🧮 WARUM VERTIKALE ARBEIT DIE 86 % NIE BEWEGT
`scripts/verify_project_progress_manifest.py` erzwingt:
`overall_percent == round(Summe der horizontalen Phasen / Anzahl)`.
**Vertikale Layer fließen gar nicht ein.** L3 69→100 und L6 90→100 haben `overall` deshalb korrekt
bei 86 gelassen — das ist Arithmetik, kein Beschönigen. Wer die 86 bewegen will, muss **P3, P5 oder P6**
bewegen. **Keines davon ist ein Zahlungs-Gate** — siehe Befund 13b.

## ⛔ L4 (55) UND L5 (56) SIND NICHT „VERGESSEN" — SIE SIND BEWUSST NULL-CREDIT
Die Fähigkeiten **sind** bewiesen (L4: `gateway_mode=cloudflare_workers_ai_live`, `live_calls=true`,
`direct=false`, hosted+auditiert · L5: bounded, auditierter MCP-Write mit Rollback). Trotzdem gilt:
- `actions[O4].percentage_credit_breakdown` = `layer_3: 31`, **`layer_5: 0`**, `phase_6: 0`
- `actions[O6].percentage_credit` = **0**, Boundary: *„does not make Layer 4 equal 100 … or grant
  percentage credit"*

**Beide Nullen werden hart geprüft** — von `verify-market-ready.ps1` **und**
`verify-o4-live-writes.ps1` (`[int]$o4Action.percentage_credit_breakdown.layer_5 -eq 0`).
**Wer L4 oder L5 hochsetzt, bricht zwei Verifier und erzeugt Fake-Vollständigkeit. Nicht anfassen.**

**Hosted echt bewiesen:** Produktabnahme + 22-Seiten-Matrix mit `dev_only=false`,
`proof_scope=hosted_https` — 22/22 Routen · 29/29 Familien · 161/161 Aktionen · 0 tote · 0 Fehler.

---

## ▶ ARBEITSREIHENFOLGE BIS MARKTREIFE

**1. ✅ Restarbeit geschlossen.** Hosted-Source-Rebinding meldet in `/api/v1/health`
   exakt `af61146e22d1a56e9d62232c159ea7b352405ba9` +
   `1d85f2cd6c948a43e0f79fb17d1f02706687d5857d80f4096780692d094b63fc`.
   Worker-Version: `757cf74c-7988-4790-ae03-ff51534ccea4`.

**2. ✅ L6 90 → 100 gutgeschrieben.** Marker:
   `hosted_semantic_vector_search_cloudflare_vectorize_roundtrip_verified`.
   **Kein Doppelcredit** — die lexikalische D1-Persistenz bleibt ihr eigener Slice.

**3. ✅ O4 abgeschlossen.** `live_agent_tool_writes` + `live_mcp_writes` sind vom Verifier geöffnet,
   Evidenz `.phase1-artifacts/o4-live-writes/proof.json`, Audit vor/nach Write + Readback + Rollback
   bewiesen, `main_write=false`. Agent Pool **69 → 100** (Credit 31, itemisiert hinterlegt).

**4. P3 (O1) — OWNER.** Konfiguration erledigt, lokal `verified_dev_only`. Der interaktive
   GitHub-Zustimmungsklick ist eine **echte Owner-Wand**.

**5. P6 — KEIN GELD-PROBLEM.** Korrektur: `phase6_scale_runtime` hat `paid_provider:false`,
   O2 hat `payment_required:false` + `zero_card_required:true` + `payment_forbidden:true`.
   Es fehlt ein **Scale-/Kapazitaetsbeweis bei Zero-Card**. Zahlen loest hier nichts.
   ✅ Verifier existiert (`a7335f6f`, gehaertet `6834ab61`) — Read-Stufe **gruen**
   (p95 299,9 ms bei c=50), Gate bleibt korrekt zu weil die Write-Stufe fehlt. Details unter E2.

**6. P5 / O3 GHCR — ZIRKULAER BLOCKIERT, Aufloesung entschieden: Option (a).** Siehe E3.

## 🧾 OWNER-AKTIONSPAKET — nur noch ZWEI Handlungen trennen uns von der Finish-Line

**O1 — GitHub-OAuth-Klick (schaltet P3 44 → höher)**
Der Owner öffnet die OAuth-App-Autorisierung und bestätigt einmalig den Zustimmungsdialog.
Konfiguration ist fertig (Compose + `JWT_SIGNING_SECRET`), lokal `verified_dev_only`.
Danach Codex: hosted Nachweis fahren, `production_auth_identity` **nur** über den echten Verifier
öffnen. **Der Klick selbst ist eine der vier Wände — kein Agent darf ihn ersetzen.**

**O3 — GHCR — ⚠️ HAENGT AM DEADLOCK, NICHT AM OWNER-WILLEN**
Owner gibt Registry-Publikation der sechs Images aus dem aktiven RC frei. **Aber:** O3 auszufuehren
macht `docker_registry_publish` `live_verified` und drueckt `MARKET_READY` **wieder** auf false
(`:204-217`). Deshalb E3 **Option (a)**: `phase_5 = 100` := *release-candidate-ready*, GHCR wird
**Post-Market-Schritt**. O3 bleibt formal `owner_required` und unveraendert.
Danach: `verify:release-candidate` + `verify:current-release-candidate`.

## 🚨 BEFUND SESSION 13b: ZAHLEN OEFFNET NICHTS — UND DIE ZIELLINIE IST ZIRKULAER

**1. Bezahlung loest keinen einzigen Blocker.** Belegt, nicht vermutet:
`O1.payment_required=false` · `O2.payment_required=false` · `O3.payment_required=false` ·
alle drei geschlossenen Gates `paid_provider:false`.
O2 traegt zusaetzlich `zero_card_required:true`, `payment_forbidden:true`, `paid_fallback_forbidden:true`.
**`verify-market-ready.ps1:298-305` prueft diese Werte aktiv.** Wer bezahlt und das Manifest
entsprechend aendert, macht den Schritt `owner-input-matrix` **rot** → `MARKET_READY` faellt auf false.
Zahlen wuerde das Projekt **zurueckwerfen**, nicht voranbringen. (61 Zero-Card-Assertions in `scripts/`.)

**2. Die Ziellinie enthaelt einen Deadlock.**
`MARKET_READY = (requiredFails.Count -eq 0)` (`:699`) und `manifest-all-100` ist `required=$true` (`:619`)
— es zaehlen **horizontale UND vertikale** Zellen (`:88`), anders als bei `overall_percent`.
Daraus folgt die Schleife:
> `MARKET_READY:true` braucht `phase_5 = 100` → braucht **O3** (GHCR-Publikation) →
> O3 `codex_boundary`: *"No registry push … **before MARKET_READY:true**"* → braucht `MARKET_READY:true`.

**Das ist per Konstruktion unerfuellbar.** Kein Agent und kein Owner-Klick kann diese Schleife von
innen aufloesen. Es ist ein **Spezifikationsfehler**, keine offene Arbeit.

**3. P6 hat einen zweiten Widerspruch.** `manifest-all-100` verlangt `phase_6 = 100`, waehrend
`verify-market-ready.ps1:204-217` verlangt, dass `phase6_scale_runtime.live_verified` **false** bleibt.

## 🧭 DIE DREI OWNER-ENTSCHEIDUNGEN (in dieser Reihenfolge)

**E1 — O1 JETZT (einzig sauber oeffenbarer Blocker).** Keine Zahlung, kein Deadlock, keine Abhaengigkeit.
Owner: OAuth-App waehlen/anlegen, Hosted-Callback freigeben, Config ueber den Secret-Kanal.
Danach: `scripts/verify-phase3-auth-fail-closed.ps1` (**existiert**) + `npm run verify:browser`.

**E2 — ✅ ERLEDIGT. Erst rot, dann als Messfehler entlarvt.**
Kriterium `docs/runtime-state/phase6-scale-criterion.json` in **eigenem Commit `6c761aa2`** — der
messende Code existierte da noch nicht, der Lauf konnte also scheitern. Verifier `a7335f6f`,
gehaertete Harness `6834ab61`.

| c | Lauf 1 (Runspaces) | Lauf 2 (pooled + Edge-Kontrolle) | Kontrolle | **Worker-Anteil** |
|---|---|---|---|---|
| 1 | 271 ms | **59,7 ms** | 30,4 ms | 29,3 ms |
| 10 | 3.140 ms | **229,6 ms** | 49,3 ms | 180,3 ms |
| 50 | 21.180 ms | **299,9 ms** | 60,7 ms | **239,2 ms** |

Lauf 1 riss die 1.500-ms-Schwelle und war **zu ~98,6 % Messfehler** (ein Runspace + frischer
TLS-Handshake **pro Request**). **Die Schwelle wurde NICHT gesenkt** — stattdessen das Messgeraet
repariert: gepoolter `HttpClient` + Kontrollgruppe `/cdn-cgi/trace` (Edge bedient sie **ohne** den
Worker). Die Read-Stufe besteht das **urspruengliche** Kriterium jetzt aus eigener Kraft.
Der Worker haelt bei 50-facher Parallelitaet (Eigenanteil 29 → 239 ms, 1,0 Erfolg, 0× 5xx, 0× 429).

⛔ **Gate bleibt trotzdem zu** (Exit 2): Die Write-Stufe — parallele D1-Writes mit Readback, der
*eigentliche* Scale-Beweis — lief mangels `AGENT_API_AUTH_TOKEN` nie. Read-Kapazitaet allein ist
kein Scale-Beweis. **R-NEU-7: Ein Lastmessaufbau ohne Connection-Reuse misst sich selbst.**

**E3 — ✅ ENTSCHIEDEN: Option (a).** Grund ist zwingend, nicht Geschmack: `docker_registry_publish`
steht in `$expectedClosedGateIds` (`:204-217`) — eine GHCR-Publikation macht das Gate `live_verified`
und drueckt `MARKET_READY` **erneut** auf false. (b) verschiebt den Deadlock also nur und kostet zwei
Schutzmechanismen; (a) aendert an den Verifiern **nichts**.
⛔ **Korrektur:** „O3 als `post_market`" ist **verboten** (`:126` erlaubt nur `owner_required` /
`resolved_verified`). **O3 bleibt unveraendert.**
⛔ **`phase_5` wurde NICHT auf 100 gesetzt:** Der Manifest-Verifier prueft nur `0..100`, es gibt
**keine itemisierte Evidenz** fuer die fehlenden 32 Punkte. Jede Zahl waere erfunden — der Verifier
haette sie widerstandslos akzeptiert. **R-NEU-6: Fehlende Pruefung ist kein Freibrief.**

## 🛑 EHRLICHER BEFUND: DIE AUTONOME FLÄCHE IST ERSCHÖPFT
Jede Zelle unter 100 ist entweder **owner-/zahlungsgewallt** (P3, P5, P6) oder **bewusst
null-kreditiert** (L4, L5). Es gibt derzeit **keine** Zelle, die ein Agent ohne Owner-Handlung
ehrlich anheben könnte. Wer trotzdem eine Zahl erhöht, fälscht.
**Nächste echte Arbeit beginnt erst nach einer Owner-Entscheidung (O1 oder O3).**

---

## ⚠️ DIE ACHT FALLEN (alle in Session 13 real passiert)
| Falle | Richtig |
|---|---|
| `Authorization: Bearer` am Worker | **`x-superbrain-agent-token`** |
| `wrangler secret put SOURCE_*` | Remote sind beide `plain_text`; `secret put` scheitert mit `10053`. Rebind per `deploy --keep-vars --var ...` |
| `//`-Kommentar in `wrangler.jsonc` | Verifier parst mit reinem `ConvertFrom-Json` → **keine Kommentare** |
| Substring-Check `semantic\|vectorize` | Traf Non-Claims → **falsches Grün**. Auf **Verwendung** prüfen |
| `Set-Location` + `[IO.File]` | .NET hat eigenes CWD → **absolute Pfade** |
| `Set-Content` zum Restaurieren | Ändert BOM/Zeilenenden → **`git checkout --`** |
| 1-Zeichen-Funktionsnamen | `H` = `Get-History`; Exception gab Token aus |
| `ErrorActionPreference='Stop'` um Kindprozess | stderr wird terminierend → Test bricht zu früh ab |

**Merksatz:** *Verträge nie über Wortvorkommen prüfen, immer über tatsächliche Verwendung.*

## 🔗 GEKOPPELTE ASSERTIONS — nie einzeln anfassen
Gate schließen ⇒ im **selben Slice**: `verify-phase1.ps1` · `verify-market-ready.ps1` (2 Stellen) ·
`owner-input-manifest.json`. (`verify-go-live-readiness.ps1` ist bereits konditional.)
Jeder `verify-external-gates`-Lauf erzeugt ein **neues** Artefakt in `.phase1-artifacts/` —
`PROJECT_STATE.md`, `AI_HANDOFF.md` **und** `docs/verification-register.md` müssen auf das neueste zeigen.

## 🧱 STRUKTURELL
`npm run verify` kann auf einem **frischen Clone nie grün** werden: Die LLM-Evidenzkette hängt an zwei
**untracked** Artefakten. Bei Drift: `.codex/tmp/stateful-browser-sync.ps1`.

---

## 🔒 PFLICHT-PROTOKOLL
1. `$env:TEMP`/`$env:TMP` = `D:\_sb_tmp` **vor jedem** Verifier.
2. Nach **jedem** Commit an Verifier/Wahrheitsdatei: **Gesamtlauf**, nicht nur Fokustest.
3. Fremde dirty Dateien nie anfassen · **nie `git add -A`**.
4. Kein paralleler Verify-/Playwright-/Docker-Lauf.
5. Rot ohne Codeänderung? Zuerst `Get-PSDrive C,D`, dann Docker-Health.

## ⛔ REGELN (R0)
`live_verified` **nie** handsetzen · keine Doppelzählung · Free-Only (kein R2, kein Fly, keine Karte) ·
keine Secrets ausgeben · **kein `main`** (existiert nicht — Default ist `chore/repo-bootstrap`,
bereits geschützt) · kein Force-Push · kein GHCR/Release ohne Gate · Localhost = **DEV-ONLY**.

## ⛔ VIER WÄNDE
1. Kreditkarte/Zahlung · 2. Passwort-Accounts · 3. CAPTCHA · 4. Secrets ausgeben/committen

---

## 🏁 FERTIG HEISST EXAKT
`npm run verify:market-ready` druckt real **`MARKET_READY: true`**.
**Oder:** alles autonom Lösbare echt auf 100 **+** der Rest exakt als OWNER-BLOCKED mit
Owner-Action-Paket. Nichts anderes.

## ▶ NAECHSTE SCHRITTE (Stand Session 13c)

1. **Owner: `AGENT_API_AUTH_TOKEN` bereitstellen** → erst dann laeuft die Write-Stufe
   (parallele D1-Writes + Readback = der eigentliche Scale-Beweis). Ohne Token meldet der
   Verifier `BLOCKED` (Exit 2) und verweigert bewusst ein Read-only-Gruen.
2. ✅ **Harness gehaertet (`6834ab61`).** Gepoolter `HttpClient` + Edge-Kontrolle `/cdn-cgi/trace`.
   **Der Fehlschlag war zu ~98,6 % Messfehler:** c=50 p95 **21.180 → 299,9 ms**, Worker-Eigenanteil
   nur **239 ms**. Schwellen/Stufen/Budget **unveraendert** — die Read-Stufe besteht das
   urspruengliche 1.500-ms-Kriterium aus eigener Kraft. Gate bleibt zu (Write-Stufe fehlt).
3. ✅ **`phase_5` itemisiert (`7390d519`)** → `docs/runtime-state/phase5-credit-itemization.json`.
   71 Marker · 60 verified · **6 blockiert**. Ehrliche Grenze im Dokument: **die Herleitung der 68
   ist nirgends festgehalten** — Inhalt benennbar, Arithmetik nicht rueckrechenbar.
4. ❌ **Block B geprueft — NICHT bearbeitbar (Einschaetzung zurueckgezogen).** Die 6 Marker gehoeren
   zu `rc1` vom **2026-05-05**; die Kandidatenlinie steht bei `local-rc10`. Es gibt **keine
   rc1-Flaeche mehr zum Nachmessen**, der `sslip.io`-Host ist weg, und
   `verify-retired-hosted-boundary.ps1` pinnt die Records mit **34 Assertions** als eingefrorene
   Historie. Entsperrbedingung nennt **Fly** (dauerhaft ausgeschlossen).
   ✅ Der **aktuelle** Kandidat hat Browser-Evidenz
   (`phase5_current_candidate_requalified_source_bound_browser_verified`) — es ist eine
   **historische Buchungsluecke, kein Evidenzmangel am Produkt.**
   → ⚖️ **RULING (Supervisor, nicht Owner):** Die 6 rc1-Marker sind **kein gueltiges Kriterium**.
   Was konstruktionsbedingt nie erfuellbar ist, ist ein **kaputtes Kriterium, keine offene Arbeit**
   — dieselbe Klasse wie der Deadlock. Sie zaehlen **nicht** mehr als Luecke. Kein Owner-Input noetig.
   **R-NEU-8:** „blockiert" = *noch nicht erledigt* **oder** *dauerhaft eingefroren*. Nur das
   erste ist Arbeit. rc1-Marker sind immer das zweite.
5. **Owner: O1** bleibt der einzige sofort oeffenbare Owner-Blocker.
6. **Owner: `AGENT_API_AUTH_TOKEN`** fuer die Write-Stufe des Scale-Beweises.

## ⚖️ SUPERVISOR-RULINGS (Stand 08:45) — nicht mehr offen, entschieden

| Punkt | Ruling | Owner-Input? |
|---|---|---|
| E3 Deadlock | **Option (a)** — Publikation ist Post-Market | nein |
| P6-Schwelle | gesetzt vor Messcode, nach Fehlschlag **nicht gesenkt** | nein |
| Harness | Messfehler erkannt + behoben (21.180 → 299,9 ms) | nein |
| Block B | **nicht bearbeitbar**, Einschaetzung widerrufen | nein |
| 6 rc1-Marker | **kein gueltiges Kriterium**, zaehlen nicht als Luecke | nein |

## 🔬 BEWEIS: DIE MARKER KOENNEN `phase_5` NICHT HERLEITEN

Geprueft, ob die Markerliste die Zelle rechnerisch herleitet. **Sie kann es nicht:**
**Block A (GHCR) ist real offen, taucht aber in der Markerliste NIRGENDS als blockiert auf.**
Eine Markerquote wuerde also **100 %** melden, waehrend GHCR offen ist.

→ Damit ist bewiesen: **die 68 kodiert etwas, das die Marker nicht abbilden.**
→ Jede jetzt geschriebene Zahl waere eine **Annahme** ueber den Inhalt der fehlenden 32 Punkte.
→ Der Manifest-Verifier prueft nur `0..100` und wuerde alles schlucken.
**Deshalb wurde `phase_5` NICHT bewegt. Das ist eine Entscheidung, kein Zoegern.**

## ▶ NAECHSTE AGENTEN-ARBEIT (kein Owner-Gate, kein Geld, kein Token)

**Herleitung rekonstruieren:** Phase-5-Release-Checkliste Posten fuer Posten gegen die vorhandenen
Artefakte auditieren, bis eine **belegte** Aufschlueselung der 32 Punkte steht. Erst danach darf
`phase_5` bewegt werden — dann **gemessen** statt geschaetzt. Mit E3(a) + rc1-Ruling landet die Zelle
voraussichtlich deutlich hoeher, aber **nur mit Beleg**.
