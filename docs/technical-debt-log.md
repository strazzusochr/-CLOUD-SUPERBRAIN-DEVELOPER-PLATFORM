# Technical Debt Log

Stand: 2026-04-23
Status: Active

## Zweck

Dieses Register erfasst bewusst akzeptierte Unsauberkeiten, damit sie nicht unsichtbar Teil der Architektur werden.

## Eintraege

| Datum | Debt | Warum aktuell akzeptiert | Risiko | Ziel zur Rueckfuehrung |
| --- | --- | --- | --- | --- |
| 2026-04-23 | `docs/codex-integration/CODEX_AGENT_SKILL_MASTER.md` bleibt vorerst ein kontrollierter Mirror-Hinweis statt echter Spiegelung | Phase-0-Zielpfad wird sofort verankert, ohne grosse Duplikation; manuelle Sync-Policy existiert | spaetere Automatisierung oder Spiegelung fehlt noch | automatisierten Synchronisationsmechanismus oder echte Spiegelung spaeter definieren |
| 2026-04-23 | Secrets-Source-of-Truth basiert vorerst auf GitHub Environments statt dediziertem Vault | minimiert Startkomplexitaet und Zusatzkosten | Governance-/Compliance-Grenzen spaeter | Vault-Entscheidung und Migrationsplan vorbereiten |
| 2026-04-23 | Kostenklassen sind Policy-Deckel, noch nicht live gegen Providerpreise oder Telemetrie verdrahtet | Phase 0 soll Regeln vor Runtime schaffen | spaetere Budgetabweichungen werden erst nach Instrumentierung sichtbar | Kostenmessung in Observability integrieren |
