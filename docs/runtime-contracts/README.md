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
| [memory-consolidation-job.md](memory-consolidation-job.md) | Phase 2 / WP-05 | `prepared` | Memory-Konsolidierung, Quellenpflicht, Write-Vertrag und Retention-Gates |
| [mcp-toolsets.md](mcp-toolsets.md) | Phase 2 / WP-06 | `prepared` | Toolset-Grenzen, Request-Envelope, Timeouts, Audit und Stop-Gates fuer GitHub, E2B, Playwright und Filesystem |
| [verification-harness.md](verification-harness.md) | Phase 2 / WP-07 | `prepared` | Evidence Envelope, Pass/Fail-Semantik, Harness-Regeln und Stop-Gates fuer Phase-2-Claims |
| [layer-interface-contracts.md](layer-interface-contracts.md) | Phase 4 / L-05 | `implemented-local` | HTTP-/SSE-/Gateway-Grenzen aller sieben Runtime-Schichten mit Request-/Response-Schema und Evidence |
| [task-assignment-queue-contract.md](task-assignment-queue-contract.md) | Phase 4 / L-06 | `implemented-local` | TaskAssignment-Schema, Redis-Queue, Status-Sichtbarkeit und Backpressure fuer Schicht 2 zu Schicht 3 |
| [agent-llm-streaming-contract.md](agent-llm-streaming-contract.md) | Phase 4 / L-07 | `implemented-local` | Agent-Pool-zu-LLM-Gateway OpenAI-kompatibles SSE-Protokoll, Parser-State und Live-Provider-Stop-Gates |
| [mcp-version-pinning-contract.md](mcp-version-pinning-contract.md) | Phase 4 / L-08 | `implemented-local` | MCP-Gateway Dependency-Pins, Tool-Contract-Versionen und Drift-Policy |
| [memory-embedding-consistency-contract.md](memory-embedding-consistency-contract.md) | Phase 4 / Audit L-09 | `implemented-local` | Memory Embedding-Version, pgvector-Dimension, Re-Embedding-Policy und Fail-Closed-Suchmodus |
| [project-progress-integrity-contract.md](project-progress-integrity-contract.md) | Phase 4 / L-09 | `implemented-local` | Runtime-Guard gegen erfundene Fortschrittszahlen, mit Manifest-/Durchschnitts-Pruefung und Evidence |
| [project-progress-completion-contract.md](project-progress-completion-contract.md) | Phase 4 / External gates | `implemented-local` | 100-Prozent-Fail-Closed-Vertrag mit fehlenden External-Gate-Blockern |
| [external-gate-audit-contract.md](external-gate-audit-contract.md) | Phase 4 / External gates | `implemented-local` | Nicht-geheimer Audit fuer Vercel-Frontend, Hosted `/api/v1`, Branch Protection, Gitleaks und Fly.io |
| [cloud-provider-inventory-contract.md](cloud-provider-inventory-contract.md) | Phase 4 / External gates | `implemented-local` | Nicht-geheimes Cloud-Inventar und Cloud-Readiness-Matrix ueber sieben Provider und die sieben Architektur-Schichten |
| [cloud-render-offload-contract.md](cloud-render-offload-contract.md) | Phase 4 / Cloud runtime | `implemented-local` | Localhost bleibt Dev-Control-Plane; schwere Grafik-/3D-/GPU-Browserlast bleibt cloud-only |
| [cloud-deployment-preflight-contract.md](cloud-deployment-preflight-contract.md) | Phase 4 / External gates | `implemented-local` | Fail-closed Vorflug fuer GHCR, Fly.io, Vercel origins, Hosted Staging, Branch Protection, Secret Scan und Owner Review |

Ergaenzendes Schema-Artefakt:

- `docs/memory/schema.md` beschreibt den logischen MVP-Memory-Schema-Vertrag. Es ist keine Migration, keine DB-Aktivierung und kein Runtime-Nachweis.

## Regeln

1. Kein produktiver LLM-Call ohne passenden Budget-/Rate-Vertrag.
2. Kein Vertrag gilt als implementiert, solange kein Testnachweis im Verifikationsregister steht.
3. Jede Abweichung von `TEIL 2`, `docs/cost-policy.md` oder `docs/provider-rotation-register.md` braucht ADR oder Owner-Freigabe.
4. Vertragsbeispiele duerfen keine Secrets, Tokens oder echten Provider-Credentials enthalten.
5. Docker Desktop mit WSL2 ist nur lokale Entwicklungs-Ausfuehrung und kein Cloud-, Production- oder No-Localhost-Nachweis.
