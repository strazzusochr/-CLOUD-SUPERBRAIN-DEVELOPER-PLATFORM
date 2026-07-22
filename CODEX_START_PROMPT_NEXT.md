# ▶️ CODEX START-PROMPT — nächste Session (Reconciliation-First)

> Zum direkten Einfügen als erste Nachricht der nächsten Codex-Session.
> Grundlage: `CODEX_UEBERPRUEFUNG_RC5_2026-07-22.md` (Ground-Truth-geprüft).
> Kernbefund: Codex war ehrlich (86 % / RC5 committet). Das Problem ist **Branch-Fragmentierung**, nicht Fake. Autonomer Rest ist fast erschöpft — offen sind nur **Owner-Wände**.

---

## START-PROMPT (einfügen)

```
Du bist Codex auf der Cloud Superbrain Developer Platform.

WAHRHEIT ZUERST — nicht aus dem Gedächtnis arbeiten, sondern messen:
  git fetch origin
  git log -1 --format='%H %s' origin/claude/cloud-superbrain-analysis-127d2e
  git show origin/claude/cloud-superbrain-analysis-127d2e:docs/project-progress.manifest.json | head -3

KANON (nicht verhandelbar):
- Kanonischer Arbeits-Branch = claude/cloud-superbrain-analysis-127d2e (overall 86 %, RC5).
- Dieser Branch ist die EINZIGE Weiterarbeitslinie. Alle anderen Branches sind Review/verwaist.
- NIEMALS den 70%-Review-Branch (codex-rc3-review-ronef1) über den 86%-Stand mergen oder forcen.

AUFGABE 1 — RECONCILIATION (vor jedem neuen Slice):
- Bestätige, dass 86 %/RC5 auf dem Kanon-Branch liegt (Befehle oben).
- Für jeden verwaisten Branch (gallant-liskov, hungry-ishizaka, codex/live-agent-steering,
  codex/phase5-active-rc-gate-bundle, codex-release-boundary, codex-vercel-git-link,
  fix/css, fly-cloud-redirect, ui/interactivity): prüfe via merge-base, ob bereits im Kanon
  enthalten. Falls ja -> zum Löschen vormerken. Falls nein -> genau benennen, was fehlt.
- Ergebnis: EINE kanonische Linie, kein verlorener Fortschritt.

AUFGABE 2 — HYGIENE (nur wenn kostenlos & autonom):
- Truth-Mirror aus dem Manifest GENERIEREN statt handzupflegen (ein Skript, Manifest = Quelle).
- Stale-%-Asserts in Verifiern immer aus dem Manifest lesen, nie hartkodieren.
- Hosted-Env (Worker-URL, Gateway-Token-Bindung) reproduzierbar im Repo pinnen (503-Env-Drift-Schutz).
- Preflight fixieren: Node-24-Pin, TEMP-Dir gesetzt, Resource-Saver aus.

R0 — NIE FAKEN:
- live_verified nur nach echtem Verifier-Grün. Keine Doppelzählung von %-Markern.
- L4 nie mit "live provider" (verify-llm-responses-contract erzwingt live_provider_calls=false).
- production_deploy_claim_allowed / production_rollout_claimed NICHT flippen.
- paid_provider=true schließt immer. Lokale/Playwright-Beweise = "DEV-ONLY; hosted proof still blocked".
- Transiente Secrets nie committen; Deploy-Token nach Nutzung widerrufen.

STOP-REGEL (ehrlich anhalten statt leer loopen):
- STOPP, sobald nur noch die vier Owner-Wände offen sind. Dann Owner-Action-Paket vorlegen, nicht weiterloopen.
- Kein neuer Prozent-Credit ohne Code + Runtime-Proof + Verifier/Doc-Sync.
```

---

## ZIELVERFOLGUNG (Definition of Done)

**FERTIG =** `MARKET_READY: true` (beide Matrizen 100 %, jede Zelle echtes Artefakt)
**ODER** alles autonom Belegbare ist echt 100 % **und** der Rest exakt als OWNER-BLOCKED belegt.

**Aktuelle ehrliche Einordnung:** Nahe „nur noch Wände offen". Sinnvollste nächste Handlung = Reconciliation + Owner-Action-Paket, **kein** weiterer autonomer Loop.

---

## DIE VIER OWNER-WÄNDE (autonom nicht lösbar — genau so übergeben)

| # | Wand | Betrifft | Owner-Aktion (exakt) |
|---|---|---|---|
| 1 | Vectorize-Scope (kostenlos, ~2 Min) | L6 90→100 | CF-Token um `Account · Vectorize · Edit` erweitern; Index anlegen, bge-Embeddings schreiben/abfragen, im `cloudflare-stateful-runtime` verdrahten, Verifier, Deploy. |
| 2 | OAuth-Provider | P3 44→… | GitHub-OAuth-App + gehostete Callback-URL (`production_auth_identity`). |
| 3 | Zahlung / Kapazität | P6 90→100, Scale | Workers Paid / Vercel Pro **oder** Scale-Gate durch Free-Tier-Budget-Gate ersetzen (ADR + Owner-Review). |
| 4 | GHCR-Push + Release-Promotion | P5 68→…, `production_deploy` | Owner-Freigabe: GHCR-Publikation + Alias-Promotion. Hartes Owner-Gate. |

---

*Dieser Start-Prompt ändert keinen Produkt-Code, keinen Prozentwert und keine Gate-Freigabe. Er legt nur die nächste Session verbindlich auf Reconciliation-First + R0 fest.*
