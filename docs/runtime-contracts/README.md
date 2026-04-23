# Runtime Contracts

Stand: 2026-04-23
Status: Active for Phase-2 preparation

## Zweck

Dieses Verzeichnis sammelt Runtime-Vertraege fuer Phase 2.
Ein Vertrag beschreibt Schnittstellen, Events, Stop-Gates und Verifikation, bevor Code oder Infrastruktur aktiviert wird.

Diese Dateien sind keine Runtime-Implementierung und kein Release-Claim.

## Aktive Vertraege

| Vertrag | Phase | Status | Zweck |
| --- | --- | --- | --- |
| [budget-rate-control.md](budget-rate-control.md) | Phase 2 / WP-01 | `prepared` | Budget-, Rate-, Cache- und Alert-Schutz vor LLM-Calls |
| [llm-gateway-routing.md](llm-gateway-routing.md) | Phase 2 / WP-02 | `prepared` | Gateway-only Modellrouting, Kostenklassen und Fallback-Grenzen |
| [langgraph-orchestrator.md](langgraph-orchestrator.md) | Phase 2 / WP-03 | `prepared` | Kontrollierter Multi-Agent-Graph, State-Vertrag, Retry-Limits und Recovery-Pfade |
| [core-agent-profiles.md](core-agent-profiles.md) | Phase 2 / WP-04 | `prepared` | Vier MVP-Agentenprofile, Toolrechte, Output-Envelope und Eskalationsregeln |

## Regeln

1. Kein produktiver LLM-Call ohne passenden Budget-/Rate-Vertrag.
2. Kein Vertrag gilt als implementiert, solange kein Testnachweis im Verifikationsregister steht.
3. Jede Abweichung von `TEIL 2`, `docs/cost-policy.md` oder `docs/provider-rotation-register.md` braucht ADR oder Owner-Freigabe.
4. Vertragsbeispiele duerfen keine Secrets, Tokens oder echten Provider-Credentials enthalten.
