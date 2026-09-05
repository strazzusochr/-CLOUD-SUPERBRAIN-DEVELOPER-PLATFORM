> **UEBERHOLT — NICHT ALS ZIEL- ODER UEBERGABEDATEI VERWENDEN.**
> Massgeblich sind ausschliesslich `CODEX_ZIEL_MASTER_2026-08-29.md` (was zu tun ist) und
> `CODEX_UEBERGABE_MASTER_2026-08-29.md` (was los ist). Diese Datei bleibt nur als
> historische Provenienz erhalten; ihre Koordinaten, Prozentwerte und Anweisungen sind
> nicht mehr gueltig. Stand der Markierung: 2026-08-30.

# ⚡ CODEX — MASTER GOAL AUTONOM VERFOLGEN (bis Vollendung + fehlerfreier Beweis)

Lies zuerst: `CODEX_MASTER_GOAL_FINALE.md` — das ist dein Ziel-Dokument mit der aktuellen
verifizierten Baseline (Phase 1+2 ✔, alle External Gates verified, Phase 3 ~80 % deployt).

## DEIN AUFTRAG
Arbeite **vollständig autonom** weiter, ohne Rückfragen, ohne Pausen, ohne vorzeitigen Stop —
bis jeder Punkt der Checkliste aus `CODEX_MASTER_GOAL_FINALE.md` mit Beweis grün ist:

- [ ] 3.5 Frontend-Politur (S7 Sprache, S9 Marketplace-Icons, Organism-Chip)
- [ ] 3.7 Media-Bibliothek (Store-Galerie)
- [ ] 3.8 Dokument-Bibliothek (Store-Liste)
- [ ] 3.9 /games-Galerie (Store-Builds)
- [ ] 4.1 22-Seiten-Endproof 2.0 — FAIL=0, PNG+HAR
- [ ] 4.2 Verifier-Suite grün (phase1/browser/lint/build/e2e/gitleaks)
- [ ] 4.3 Manifest + Truth-Spiegel aktualisiert (contract-konform)
- [ ] 4.4 END_ZIEL_GESAMTSPEC §4 aktualisiert
- [ ] 4.5 master-goal-final.md geschrieben

## ARBEITSSCHLEIFE (bei jedem Start / nach jeder Unterbrechung)
1. `.codex/runs/CURRENT/master-goal/status.md` lesen → ersten NICHT-grünen Punkt finden.
2. Genau dort weitermachen. Nichts überspringen, nichts doppelt bauen.
3. Umsetzen → lokal `lint`+`build` → committen (KEIN push) → deployen
   (`vercel deploy --prod --yes` aus Repo-Root) → Hosted-Beweis (Playwright, HTTPS).
4. PASS nur mit Artefakt (MD+JSON+PNG+HAR unter `.codex/runs/CURRENT/master-goal/`).
5. Bei FAIL: Ursache analysieren → fixen → denselben Punkt erneut beweisen. So oft wie nötig.
6. Punkt grün → Haken + Evidence-Pfad in `status.md` → nächster.
7. Stuck >3 Versuche am selben Fehler: Ansatz wechseln, im Status begründen — weiterarbeiten.

## HARTE REGELN (immer)
- **No-Fake-Done / No-Fake-Live**: nur echte Beweise; ehrliche Labels (`frontend-projection`,
  `live:false`) NIE zurückdrehen — Tests erweitern statt Labels fälschen.
- **No Secrets**: Tokens nur transient aus der Secrets-Env, presence-only, nie Werte loggen.
- **Free-Only**: kein Fly, nichts Bezahltes, KEIN `git push`.
- **Localhost = DEV-ONLY**; Hosted-Beweis = HTTPS non-localhost.
- **Proof-Tool aus PowerShell** starten (Git-Bash zerstört `/routen`-Args).
- **Kein Deploy während ein Hosted-Proof läuft.**
- Sichtbare Marker prüfen (`<Panel title>` ist nicht in innerText); GH-Store filtert `project_id`.

## STOP-BEDINGUNG (genau zwei erlaubte Endzustände)
1. **Alle Haken grün** → `master-goal-final.md` schreiben, fertig melden.
2. Alles Erreichbare grün, Rest nachweislich owner-only → in `master-goal-final.md` exakt
   auflisten, welcher Punkt an welcher Owner-Vorbedingung hängt (Stand jetzt: alle External
   Gates verified — offen ist nur die bewusste Production-Release-Promotion als Owner-Wahl,
   kein Bug). Nichts anderes zählt als Ende.
