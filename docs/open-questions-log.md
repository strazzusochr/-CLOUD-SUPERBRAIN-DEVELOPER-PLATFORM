# Open Questions Log

Stand: 2026-04-23
Status: Active

## Zweck

Dieses Register trennt echte offene Entscheidungen von Annahmen und technischem Debt. Offene Fragen duerfen nicht still beantwortet werden.

## Eintraege

| Datum | Offene Frage | Warum sie wichtig ist | Spaetester Klaerzeitpunkt |
| --- | --- | --- | --- |
| 2026-04-23 | Welche Auth-Topologie ergaenzt JWT am saubersten fuer den MVP? | Security-Baseline verlangt saubere Auth | vor erstem API-Design |
| 2026-04-23 | Wie wird der Mirror unter `docs/codex-integration/` spaeter automatisiert synchronisiert? | verhindert Governance-Drift ueber die manuelle Phase-0-Regel hinaus | vor spaeterer Repo-Automatisierung |
| 2026-04-23 | Wird `ADR-006` akzeptiert, sodass Langfuse und Begleitdienste als separater Observability-Stack statt als Teil des Haupt-Compose laufen? | entscheidet, ob Observability ehrlich von der Main-App getrennt und Langfuse-v3 sauber eingebettet werden kann | vor Compose-Implementierung |
| 2026-04-23 | Bleibt `ADR-004` mit Supabase als MVP-Startdatenbank aktiv, oder wird vorgezogen per neuem ADR auf self-hosted PostgreSQL umgestellt? | entscheidet ueber fruehen Persistenz-Cutover und verhindert Architekturdrift | vor Datenbank-Implementierung |
