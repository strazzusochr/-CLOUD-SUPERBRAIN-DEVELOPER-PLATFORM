# 🔎 CODEX-ÜBERPRÜFUNG — RC5 / Auth-Requalification (2026-07-22)

Reviewer: Claude (Opus 4.8) · Branch: `claude/codex-rc3-review-ronef1`
Prüfmethode: Git-Ground-Truth (dieser Clone **und** der echte Arbeits-Branch) + Codex-Session-Logs (Session 2–4).
Es wurde **nichts zitiert, alles gemessen.** Wo ich nur die Logs habe, ist es ausdrücklich als „berichtet" markiert.
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
| Aktive RC | `dev-candidate-2026-06-15-rc1` | `prod-candidate-2026-07-22-local-rc5` (source `255e328a`) |
| Cloudflare D1 / LLM-Worker | **nicht vorhanden** | vorhanden (per Log deployt) |

**Zellen-Delta (Juni-Klon → echter Juli-Stand), git-verifiziert aus beiden Manifesten:**

- Horizontal: P0 100→100 · P1 100→100 · **P2 86→100** · **P3 40→44** · **P4 99→100** · **P5 67→68** · **P6 0→90**
- Vertikal: **L1 97→100** · **L2 99→100** · **L3 68→69** · **L4 54→55** · **L5 55→56** · **L6 72→90** · **L7 (neu) 100**

> Konsequenz: Die Aussagen aus den Codex-Logs (86 %, P2 100, RC5, Auth-Requalifizierung, `sharp`-Patch) sind **1:1 durch das committete Manifest auf dem Arbeits-Branch belegt**. Codex war ehrlich; der Review-Branch ist nur stale.

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
3. **Verifier-Wartung frisst mehr Zeit als Produkt.** Ein Großteil der Session-Zeit floss in Verifier-Drift, nicht Produktbugs: hartcodierte Stale-%-Asserts, PowerShell-5.1-Eigenheiten, gitleaks-Rekursion, Docker-OOM, Resource-Saver-Crash, Node-Version-Pinning. Die Verifikations-Apparatur ist zur Last geworden.
4. **Hosted-Config brüchig.** Der 503 war eine **echte Regression** (Env/Token-Drift nach Redeploy). Gut gefangen — aber signalisiert, dass die Hosted-Konfiguration nicht reproduzierbar gepinnt ist.
5. **Truth-Mirror-Sprawl.** `PROJECT_STATE.md` (183 KB) + `AI_HANDOFF.md` (131 KB) + Checkpoint + Anchor + Memory-Protokoll + Register + RELEASE + Master-Goal müssen bei **jeder** %-Änderung von Hand synchron gehalten werden. Riesige Fake-Done-Angriffsfläche, bremst jedes Inkrement. (AGENTS.md §156 rät ausdrücklich von unnötigen Meta-Dokumenten ab.)
6. **Chrome-Native-Host wiederholt nicht verfügbar** → der „signierte Chrome-Plugin-Proof" ist nie geschlossen worden; alle Browser-Beweise bleiben Playwright-Chromium (`DEV-ONLY`). Das ist okay, muss aber explizit bleiben.

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

**E. Verifier-Budget deckeln.** Stale-%-Asserts nie hartcodieren — immer aus dem Manifest lesen (Codex hat das teils schon getan). Node/Docker/Temp-Umgebung einmal fixieren (`$env:TEMP='D:\_sb_tmp'`, Node-24-Pin, Resource-Saver aus) und als Preflight-Skript verankern.

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
