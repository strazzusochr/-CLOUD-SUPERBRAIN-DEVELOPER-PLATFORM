# 🔎 CODEX-ÜBERPRÜFUNG — RC5 / Auth-Requalification (2026-07-22)

Reviewer: Claude (Opus 4.8) · Branch: `claude/codex-rc3-review-ronef1`
Prüfmethode: Git-Ground-Truth (dieser Clone **und** der echte Arbeits-Branch, **commit-für-commit** verifiziert) + die echten Codex-Übergabe-Dokumente (Master-Goal-Finale, Session-4-Handover, Anchor, Ziel-Kurz, AI-Handoff — vom Owner bereitgestellt), nicht mehr nur Session-Logs.
Es wurde **nichts zitiert, alles gemessen.** Wo nur die Dokumente die Quelle sind (SHA-256-Evidenz-Hashes, Deployment-IDs), ist es als „dokumentiert" markiert; die %-Werte und die Commit-Kette sind git-verifiziert.
Ich habe für diese Prüfung **keine** Verifier / Docker / Browser-Suiten laufen lassen — kein Fake-Evidence, nur Audit.

---

## 0. VERDIKT (TL;DR)

1. **Codex hat NICHT gefälscht.** Die im Log behaupteten Prozentwerte (Overall 86 %, RC5) sind **committet und deckungsgleich** mit dem echten Arbeits-Branch. Die Anti-Fake-Grenze (`production_rollout_claimed=false`, alle Hosted/GHCR/Promotion/Owner-Gates `false`) ist **intakt**.
2. **Das eigentliche Problem ist NICHT Ehrlichkeit, sondern Branch-Fragmentierung.** Die gesamte Juli-Arbeit liegt auf `claude/cloud-superbrain-analysis-127d2e`. **Dieser Review-Branch (`codex-rc3-review-ronef1`) ist ein veralteter Juni-Klon (70 %).** Wer diesen Branch prüft, hält das Projekt fälschlich für 30 % schlechter, als es ist.
3. **Der autonome Fortschritt ist praktisch ausgeschöpft.** Alle offenen Restpunkte sind **Owner-Wände** (Zahlung, OAuth-Provider, Vectorize-Scope, Dry-Run-Lock, GHCR/Promotion). Weiter autonom loopen bringt fast nichts mehr — die ehrliche Handlung ist: **Owner-Action-Paket übergeben und STOPP** (genau die im Log definierte Stop-Regel).

---

## 1. GROUND TRUTH — verifiziert (zwei Branches, eine Wahrheit)

| | Review-Branch (hier) | Echter Arbeits-Branch |
|---|---|---|
| Ref | `claude/codex-rc3-review-ronef1` | `claude/cloud-superbrain-analysis-127d2e` |
| HEAD | `48e86ce` · 2026-06-20 · „tools real output ui" | `115a67d1` · 2026-07-22 06:54 · „requalify auth source as rc5" |
| `overall_percent` | **70** | **86** |
| Aktive RC | `dev-candidate-2026-06-15-rc1` | `prod-candidate-2026-07-22-local-rc5` (source `255e328a`, `production_rollout_claimed=false`) |
| Cloudflare Stateful-/LLM-Worker-Service | **nicht vorhanden** (git-verifiziert) | `services/cloudflare-stateful-runtime` + `services/cloudflare-llm-gateway` vorhanden (git-verifiziert) |

**Zellen-Delta (Juni-Klon → echter Juli-Stand), git-verifiziert aus beiden Manifesten:**

- Horizontal: P0 100→100 · P1 100→100 · **P2 86→100** · **P3 40→44** · **P4 99→100** · **P5 67→68** · **P6 0→90**
- Vertikal: **L1 97→100** · **L2 99→100** · **L3 68→69** · **L4 54→55** · **L5 55→56** · **L6 72→90** · **L7 (neu) 100**

> Konsequenz: Die Aussagen aus den Codex-Logs (86 %, P2 100, RC5, Auth-Requalifizierung, `sharp`-Patch) sind **1:1 durch das committete Manifest auf dem Arbeits-Branch belegt**. Codex war ehrlich; der Review-Branch ist nur stale.

### 1b. COMMIT-KETTE — jetzt commit-für-commit git-verifiziert (nicht nur Log)

Alle in den Übergabe-Dokumenten genannten Commits existieren im Repo mit **deckungsgleichem Subject**; keiner ist erfunden. `255e328a` ist nachweislich Vorfahre des Arbeits-Branch-HEAD `115a67d`.

| Commit | Subject (git) | Zeitpunkt | belegt |
|---|---|---|---|
| `76f4644` | verify(llm): bind hosted preview read-only parity | 21.07. 22:49 | LLM 54→55 |
| `0679f6f` | fix(frontend): stabilize browser fallback runtime | 21.07. 22:49 | WebGL-Fallback + Node-Metadaten |
| `a80c356` | verify(release): requalify runtime candidate rc4 | 21.07. 23:23 | RC4 |
| `255e328` | fix(security): enforce fail-closed auth issuance | 22.07. 04:02 | P3-Auth-Härtung |
| `115a67d` (HEAD) | verify(release): requalify auth source as rc5 | 22.07. 06:54 | RC5 |
| `985f577` | Close Observability layer to 100 percent with live ingestion proof | 21.07. 04:11 | L7/Obs 100 |

> Upgrade dieser Prüfung: nicht mehr „Log-konsistent", sondern **commit-verifiziert**. Die RC5-Artefaktdatei auf dem HEAD nennt exakt `prod-candidate-2026-07-22-local-rc5`, source `255e328a`, `production_rollout_claimed=false` — die Anti-Fake-Grenze ist im Artefakt selbst codiert.

### 1c. SMOKING GUN der Fragmentierung

Die Übergabe-Dokumente, die der Owner mir für diese Prüfung **von Hand hochladen musste** — `PROJECT_ANCHOR_CURRENT.md`, `CODEX_MASTER_GOAL_FINALE.md`, `CODEX_UEBERGABE_2026-07-21-SESSION4.md`, `CODEX_ZIELVERFOLGUNG_KURZ.md` — **existieren auf diesem Review-Branch überhaupt nicht** (`git cat-file` = ABSENT), sondern nur auf `claude/cloud-superbrain-analysis-127d2e`. Genau deshalb wirkt das Projekt hier 16 Prozentpunkte schlechter: der Review-Träger sieht die Juli-Wahrheit gar nicht. Das ist der direkte, git-belegte Beweis für Befund #1 (Branch-Fragmentierung).

---

## 2. WAS CODEX REAL GELIEFERT HAT (Session 2–4)

**Belegbar (committet auf Arbeits-Branch, Log-konsistent):**

| Ergebnis | Belegtyp |
|---|---|
| P2 Checkpoint-Restart-Recovery gutgeschrieben (86→100) | Manifest-Marker + Runtime-Log |
| L3 Agent-Pool: Hosted-D1-4-Rollen-Readback (68→69) | read-only Verifier, tokenfrei |
| L5 MCP: Hosted read-only Contract-Parity (55→56) | GET-only Verifier, source-gebunden |
| L4 LLM: Cloudflare Workers-AI Preview read-only source-parity | Verifier + Deployment-Metadaten |
| L6 Memory: Hosted D1 stateful backend live (73→90) | D1-Migration + 2 Verifier hosted grün |
| P5 RC3 → RC5: Clean-Archive-Requalifizierung, RC2-Rollback-Ziel | 6/6 content-addressed Images, Chromium-Klick |
| **503-Production-Fix** (LLM-Gateway Env/Token-Drift) | echte Root-Cause + Redeploy + 44-Klick-Proof |
| **P3 Auth Fail-Closed-Härtung** (Session 4) | 19/19 Unit-Tests + Redis-Race + HTTP-Negativpfade |
| `sharp` 0.35.3 Security-Override | npm audit 0 vulns |

**Qualität der Auth-Härtung (Session 4) — sachlich stark:** echte Sicherheitsfixe, keine Kosmetik:
- Cookie-Löschung auch bei Callback-Fehler; kein OAuth-State im JSON-Body.
- Refresh-Token wird bei JWT-Secret-Verlust **nicht** mehr aus Prozess-Fallback geminted (fail-closed vor atomarem Verbrauch).
- Positive Callback-/Refresh-Ausgabe **an erfolgreichen Audit-Write gebunden**; bei Audit-Ausfall werden Ersatz-Records entfernt und keine Cookies ausgegeben.
- Historische RC1-Aussagen korrekt als **superseded / security-invalidated** markiert statt rückwirkend umgedeutet.

---

## 3. EHRLICHKEITS-AUDIT (das eigentliche „ÜBERPRÜFEN")

### ✅ Was gehalten hat (R0-Disziplin intakt)
- `production_rollout_claimed=false`, `production_deploy_claim_allowed` nie geflippt.
- Hosted-Snapshot (84) vs. lokales Manifest (86) **ehrlich als „stale" gekennzeichnet**, nicht verwechselt.
- Keine Doppelzählung der bereits gutgeschriebenen P3-Security-Marker.
- L4 **nicht** mit „live provider" hochgesetzt (`verify-llm-responses-contract` erzwingt `live_provider_calls=false`).
- Clean-Archive-Builds nur aus `git archive` (kein dirty worktree in Images).
- Transiente Secrets: nie committet; temporärer Cloudflare-Deploy-Token nach Deploy **nachweislich widerrufen**.

### ⚠️ Reale Risiken / Schwächen (fair, nicht faul)
1. **Branch-Fragmentierung (schwerwiegend).** Origin trägt ≥10 Branches (`analysis-127d2e`, `gallant-liskov`, `hungry-ishizaka`, `codex-release-boundary`, `codex-vercel-git-link`, `codex/live-agent-steering`, `codex/phase5-active-rc-gate-bundle`, `fix/css`, `fly-cloud-redirect`, `ui/interactivity`). Es gibt **keine** kanonische Integrationslinie — dieser Review-Branch ist der lebende Beweis.
2. **Prozent-Mikro-Credits / Marker-Theater.** `status`-Felder sind hunderte Bindestrich-Marker. +1 %-Sprünge (L3 68→69, L5 55→56) sind formal „evidence-based", aber die Granularität macht Overall-% eher zu **Buchhaltung** als zu Marktreife.
3. **Verifier-Wartung frisst mehr Zeit als Produkt — jetzt mit Zahlen belegt.** Der committete Checkpoint (`docs/project-checkpoint-2026-07-21-session4.json`) misst: `verify` **576 s**, `verify:runtime` **629 s**, `verify:browser` **3071 s (≈51 Min)** — ein voller Grün-Zyklus ≈ **72 Min**, dominiert vom Browser-Lauf. Der Session-4-Transkript zeigt **vier** komplette Browser-Läufe (BR→BR4, je ~50 Min) wegen Zwischen-Fails/Timeout = **~3,5 h nur Browser** für einen einzigen Auth-Slice, plus die D1-Local-Kämpfe (Port-Konflikte, PID-Tree-Kills, `ConvertTo-Json`-Perf, Turbopack→Webpack-Fallback). Ein Großteil der Zeit floss in Verifier-/Umgebungs-Drift, nicht in Produktbugs. Die Verifikations-Apparatur ist zur Last geworden.
4. **Fortschritt ist während der Läufe blind — der Operator musste eingreifen.** Weil der 51-Min-Browser-Lauf nur „läuft" ohne Schritt/ETA/letzten-grünen-Marker meldet, tippte der Owner mitten im Lauf „WAS MACHSTEN DU" und „DU SOLLST KEIN CHAT OUTPUT GENERIEREN NUR ABKÜRZUNGEN". Das ist kein Ehrlichkeits-, sondern ein **Beobachtbarkeits-Defekt**: opake Langläufer zerstören das Vertrauen und provozieren manuelle Abbrüche, die Beweise invalidieren können.
5. **Hosted-Config brüchig.** Der 503 war eine **echte Regression** (Env/Token-Drift nach Redeploy). Gut gefangen — aber signalisiert, dass die Hosted-Konfiguration nicht reproduzierbar gepinnt ist.
6. **Truth-Mirror-Sprawl.** `PROJECT_STATE.md` (183 KB) + `AI_HANDOFF.md` (131 KB) + Checkpoint + Anchor + Memory-Protokoll + Register + RELEASE + Master-Goal müssen bei **jeder** %-Änderung von Hand synchron gehalten werden. Riesige Fake-Done-Angriffsfläche, bremst jedes Inkrement. (AGENTS.md §156 rät ausdrücklich von unnötigen Meta-Dokumenten ab.)
7. **Chrome-Native-Host wiederholt nicht verfügbar** → der „signierte Chrome-Plugin-Proof" ist nie geschlossen worden; alle Browser-Beweise bleiben Playwright-Chromium (`DEV-ONLY`). Das ist okay, muss aber explizit bleiben.

---

## 4. DIE VIER WÄNDE — Owner-Action-Paket (nie faken, Rest korrekt als OWNER-BLOCKED)

Diese schließen die offenen %-Punkte; keiner davon ist autonom lösbar:

| Wand | Betrifft | Owner-Aktion (exakt) |
|---|---|---|
| **1. Vectorize-Scope** (kostenlos, ~2 Min) | **L6 90→100** | CF-Dashboard → API-Token um `Account · Vectorize · Edit` erweitern. Danach: Vectorize-Index anlegen, bge-Embeddings (Workers AI) schreiben+abfragen, im `cloudflare-stateful-runtime` verdrahten, Verifier, Deploy. |
| **2. OAuth-Provider** | **P3 44→…** | GitHub-OAuth-App + gehostete Callback-URL bereitstellen (`production_auth_identity`). |
| **3. Zahlung / Kapazität** | **P6 90→100**, Scale | Cloudflare Workers Paid / Vercel Pro **oder** Scale-Gate durch Free-Tier-Budget-Gate ersetzen (ADR + Owner-Review). |
| **4. GHCR-Push + Release-Promotion** | **P5 68→…**, `production_deploy` | Owner-Freigabe: GHCR-Publikation + Alias-Promotion. Bleibt hartes Owner-Gate. |

**Nie faken (R0):** `live_verified` nur per Verifier · keine Doppelzählung · L4 nicht mit „live provider" · `production_deploy_claim_allowed` nicht flippen · `paid_provider=true` schließt immer.

---

## 5. KONKRETE VERBESSERUNGEN (das „verbessert")

**A. Reconciliation zuerst — bevor irgendein neuer Slice.** (siehe §7)
Die Juli-Arbeit muss in **eine** kanonische Linie. Ohne das ist jeder weitere Fortschritt auf einem von zehn Branches verloren.

**B. Prozent-Modell entrümpeln.** Pro Zelle **max. 3–5 benannte Akzeptanz-Gates** definieren (statt hunderter Marker). Overall-% aus diesen wenigen Gates berechnen. Das macht „fertig" wieder aussagekräftig und Doppelzählung strukturell unmöglich.

**C. Truth-Mirror generieren, nicht hand-editieren.** Manifest = **einzige** Quelle. `PROJECT_STATE`/`AI_HANDOFF`/`RELEASE`/Register aus dem Manifest **generieren** (ein Skript), nicht per Hand nachziehen. Halbiert die Fake-Done-Fläche und die Inkrement-Kosten.

**D. Hosted-Config als Code pinnen.** Env-Belegung (Worker-URL, Gateway-Token-Bindung) reproduzierbar in Repo/IaC festhalten, damit der 503-Env-Drift nicht wiederkehrt.

**E. Verifier-Budget deckeln — mit harter Regel.** Der 51-Min-Browser-Lauf ist der Flaschenhals (belegt: 3071 s im Checkpoint). Regel: pro Slice **zuerst nur den geänderten Oberflächen-Sub-Verifier** laufen lassen (Auth-Route, D1-Roundtrip …), die volle 22×2-Suite **höchstens einmal** am Slice-Ende — nicht 4×. Stale-%-Asserts nie hartcodieren, immer aus dem Manifest lesen (Codex hat das teils schon getan). Node/Docker/Temp einmal fixieren (`$env:TEMP='D:\_sb_tmp'`, Node-24-Pin, Resource-Saver aus) und als **Preflight-Skript** verankern, damit die D1-Local-/Turbopack-/Port-Kämpfe nicht pro Session neu auftreten.

**F. Fortschritts-Beobachtbarkeit statt „läuft".** Langläufer (Browser/Runtime) müssen strukturiert melden: Schritt `X/Y`, letzte grüne Marke, grobe ETA aus der Checkpoint-Dauer (`verify:browser≈51 Min`). Damit muss der Owner nie wieder „WAS MACHSTEN DU" mitten in einen 50-Min-Lauf tippen — und wird nicht zu einem Abbruch verleitet, der den Beweis invalidiert. Ein einzelner Herzschlag pro Minute mit `Schritt n/m` genügt.

---

## 6. DEFINITION OF DONE & STOP-REGEL

**FERTIG =** `MARKET_READY: true` (beide Matrizen 100 %, jede Zelle echtes Artefakt)
**ODER** alles autonom Belegbare ist echt 100 % **und** der Rest ist exakt als OWNER-BLOCKED belegt.

**STOPP nur bei:** `MARKET_READY: true` · nur noch Wand-Punkte offen · Pflicht-Protokoll-Verletzung.

**Ehrliche aktuelle Einordnung:** Der Stand ist nahe „nur noch Wände offen". Die sinnvollste nächste Handlung ist **nicht** ein weiterer Loop, sondern (1) Branch-Reconciliation und (2) das Owner-Action-Paket aus §4 dem Owner vorlegen.

---

## 7. RECONCILIATION-ANWEISUNG (verbindlich, zuerst)

Ziel: Eine kanonische Linie, kein verlorener Fortschritt, kein Force auf fremde Historie.

```
# 1. Wahrheit bestätigen
git fetch origin
git log -1 --format='%H %s' origin/claude/cloud-superbrain-analysis-127d2e   # muss 115a67d1 o. neuer sein
git show origin/claude/cloud-superbrain-analysis-127d2e:docs/project-progress.manifest.json | head -3   # overall 86

# 2. Kanon festlegen
#    -> claude/cloud-superbrain-analysis-127d2e IST die Wahrheit (86 %, RC5).
#    -> Dieser Review-Branch (codex-rc3-review-ronef1, 70 %) ist NUR Review-Träger.
#    NIEMALS den 70%-Stand über den 86%-Stand mergen/forcen.

# 3. Diese Überprüfung ablegen: nur diese Review-.md auf codex-rc3-review-ronef1 committen/pushen
#    (kein Produkt-Merge von hier).

# 4. Weiterarbeit ausschließlich auf claude/cloud-superbrain-analysis-127d2e.
#    Die ≥8 verwaisten Branches (gallant-liskov, hungry-ishizaka, codex/*, fix/css, fly-cloud-redirect,
#    ui/interactivity, codex-release-boundary, codex-vercel-git-link) prüfen: gemergt? sonst schließen/löschen.
```

**Warnung:** `git merge-base` von `48e86ce` und `115a67d1` prüfen, bevor irgendetwas kombiniert wird. Der Review-Branch darf den Arbeits-Branch **nie** überschreiben.

---

*DEV-ONLY-Kontext: Alle lokalen/Playwright-Beweise sind `DEV-ONLY; hosted proof still blocked`. Diese Überprüfung ändert keinen Produkt-Code, keinen Prozentwert und keine Gate-Freigabe.*
