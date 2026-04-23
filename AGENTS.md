# Repository Constitution

Dieses Repository übernimmt [docs/CODEX_AGENT_SKILL_MASTER.md](docs/CODEX_AGENT_SKILL_MASTER.md) als verbindliche Arbeitsverfassung.
Der höchste inhaltliche Projektanker ist [docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md](docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md), insbesondere `TEIL 0 — PROJECT GOAL LOCK (ABSOLUT UNVERÄNDERLICH)` und `TEIL 1 — DIE 11 ABSOLUTEN SYSTEM-REGELN`.
Die kanonische Repository-Identität ist der Git-Slug `-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`; `D:\PLATTFORM` ist nur der lokale Workspace-Pfad und kein Projektname.
Die verbindliche Namensreferenz liegt in [docs/repository-identity.md](docs/repository-identity.md).

Geltung:
- Diese Repo-Regeln sind für die laufende Arbeit verbindlich.
- Übergeordnete System- und Entwickleranweisungen bleiben weiterhin maßgeblich.
- Jede Planung, Orchestrierung, Umsetzung, Verifikation und jedes Reporting muss gegen `TEIL 0` und `TEIL 1` des Ultimatum-Dokuments geprüft werden.
- Keine Aufgabe gilt als fertig ohne Verifikation.
- Keine stillen Architekturwechsel, keine direkten Schreibzugriffe auf `main`, keine unkontrollierten Loops, keine Secrets in Code oder Logs.

Projektanker aus `TEIL 0`:
- North Star: cloud-native, prompt-gesteuerte, multi-agentische Entwicklerplattform ohne Localhost-Abhängigkeit.
- Harte Constraints: kein Localhost, keine lokalen Modell-Downloads, kein direkter Agent-Commit nach `main`, keine unkontrollierten Loops, keine Secrets im Code, kein "fertig" ohne Verifikation.
- Budget und Policy: `20 EUR/Monat` Infrastruktur-Limit und `open-source-first`.
- MVP-Ziel: 4-Agenten-Squad, Prompt-Interface, Streaming, Vector-Memory, GitHub-Integration, Production-Deploy im Budget.
- Release-Standard: kein Deployment ohne CI/CD, kein Feature ohne Observability-Integration, kein Release ohne Release-Checkliste als Git-Artefakt.

Absolute System-Regeln aus `TEIL 1`:
- `R1` Keine Lügen: keine Behauptung ohne Evidenz.
- `R2` Kein Fake-Done: nichts ist fertig ohne Integration, Verifikation, Logging und Recovery-Pfade.
- `R3` Kein Zielverlust: Entscheidungen müssen aktiv auf den North Star einzahlen.
- `R4` Keine Architekturdrift: Strukturänderungen brauchen ADRs.
- `R5` Keine losen Fragmente: jede Komponente muss im Gesamtsystem verortet und betreibbar sein.
- `R6` Keine unmarkierte Unsicherheit: Annahmen und Unsicherheiten werden explizit markiert.
- `R7` Kein One-Shot-Chaos: Arbeit erfolgt phasenweise in kontrollierten Übergabepaketen.
- `R8` Keine Blocker-Ausreden: Blocker werden klar klassifiziert und in nächste Schritte übersetzt.
- `R9` Kein Release-Betrug: release-ready nur bei erfüllten realen Release-Kriterien.
- `R10` Budgetgrenze ist hart: `20 EUR/Monat` sind verbindlich.
- `R11` Open-Source ist Standard: proprietär nur als begründete Ausnahme mit Owner-Freigabe.

Standardarbeitsweise:
- Für qualifizierte Aufgaben wird die minimal nötige interne Rollen-Zusammenarbeit automatisch gestartet.
- Es wird an echten Review-Gates angehalten, insbesondere bei Production-Deployment, Merge nach `main`, Architekturwechseln, Datenlöschung, Secrets/Auth, Rechteausweitungen und destruktiven Aktionen.
- Reporting folgt standardmäßig dem 6-Punkte-Format aus der Verfassung: Ziel, aktivierte Rollen, Änderungen, Verifikation, Risiken/offene Punkte, nächster bester Schritt.

## 3D Web Game Cloud Platform Requests

Wenn der Nutzer eine 3D-Web-Game-Plattform per Multi-Agent-Ausführung anfordert, gilt zusätzlich:
- Lade und befolge `$3d-web-game-swarm` unter `C:\Users\immer\.codex\skills\3d-web-game-swarm\SKILL.md`.
- Nutze den Bootstrap-Befehl `gh repo clone strazzusochr/CoronaProjektschonwieder`, falls ein Repo-Bootstrap angefordert ist.
- Instanziiere 11 Rollen: 9 Fach-Builders plus 2 Supervisoren.
- Für UI- und Gameplay-Änderungen gilt die Folge Build/Run -> Chrome DevTools MCP -> Puppeteer MCP -> Evidence-Log.
- Supervisoren dürfen unterbrechen und Korrekturen erzwingen, bevor weitergearbeitet wird.

Zusätzliche Durchsetzungsregeln:
- Verwende die Templates unter `C:\Users\immer\.codex\skills\3d-web-game-swarm\templates\`.
- Für UI- und Gameplay-Themen ist Runtime-Proof via Chrome DevTools MCP und Puppeteer MCP Pflicht.
- Abschlussclaims brauchen Evidence-Artefakte, eine Pass/Fail-Testzusammenfassung und einen Rollback-Hinweis.
