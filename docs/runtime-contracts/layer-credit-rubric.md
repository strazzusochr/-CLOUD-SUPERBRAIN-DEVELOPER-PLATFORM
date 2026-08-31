# Layer-Credit-Rubrik fuer L4 und L5 — OWNER-FREIGEGEBEN

Status: `APPROVED`  
Version: `layer-credit-rubric-draft-v1`  
Erstellt: `2026-08-29`  
Credit-Anwendung erlaubt: `true`
Owner-Freigabe-Ref: `CODEX_UEBERGABE_MASTER_2026-08-29.md :: B1 Owner-Freigabe 2026-08-31 (Owner strazzusochr, an Claude delegiert)`

Diese Datei ist **freigegeben**. Die Freigabe legt ausschliesslich die Messlatte fest:
welche Kriterien zaehlen, mit welchen Punkten, und welcher Verifier sie beweisen muss.
Sie aendert **keinen** Prozentwert, **kein** Gate und **keinen** `live_verified`-Status —
L4 bleibt `55`, L5 bleibt `56`, bis die benannten Verifier gegen den gehosteten Stack
real gruen laufen. Jede als `offen` markierte Zeile bleibt offen, bis ihr Beweis vorliegt.

Beweisregeln:

- Jede Zeile misst genau eine Faehigkeit.
- `DEV-ONLY` kann keine Hosted-Zeile erfuellen.
- Ein vorhandener Vertrag oder Quelltextmarker ist kein Laufzeitbeweis.
- `erfuellt` beschreibt nur den heutigen Evidence-Stand innerhalb dieses Entwurfs;
  daraus folgt ohne Owner-Freigabe **kein Credit**.
- Hosted-Nachweise muessen HTTPS, nicht-localhost, source-gebunden und
  secret-redigiert sein.
- Die Summen sind mechanisch fest: L4 `100`, L5 `100`.

## L4 — LLM Gateway (Entwurf, 100 Punkte)

| Kriterium | Punkte | Beweisart | Verifier | Aktueller Stand |
|---|---:|---|---|---|
| OpenAI-kompatibles Chat-Completions-Schema | 6 | Unit + Runtime | `services/llm-gateway/tests/`; `scripts/verify-phase1-runtime.ps1` | erfuellt, DEV-ONLY |
| OpenAI-kompatibles Responses-Schema | 6 | Unit + Runtime | `scripts/verify-llm-responses-contract.ps1` | erfuellt, DEV-ONLY |
| SSE-Stream liefert dieselbe terminale Semantik wie Non-Stream | 12 | Runtime | `scripts/verify-llm-responses-contract.ps1`; `scripts/verify-phase1-runtime.ps1` | erfuellt, DEV-ONLY |
| Deterministischer Dry-Run ist fail-closed der Default | 6 | Unit + Runtime | `scripts/verify_llm_gateway_health_mode.py`; `scripts/verify-phase1-runtime.ps1` | erfuellt, DEV-ONLY |
| Providerzugriff ist ausschliesslich gateway-only | 8 | Unit + Runtime | `services/llm-gateway/tests/`; `scripts/verify-phase1-runtime.ps1` | erfuellt, DEV-ONLY |
| Token-, Kosten- und Zeitbudget werden lokal erzwungen | 7 | Unit + Runtime | `services/llm-gateway/tests/`; `scripts/verify-phase1-runtime.ps1` | erfuellt, DEV-ONLY |
| Lokale LLM-Aufrufe besitzen persistierte Auditkorrelation | 5 | Runtime | `scripts/verify-live-llm-evidence-chain.ps1`; `scripts/verify-phase1-runtime.ps1` | erfuellt, begrenzter Pfad |
| Lokale LLM-Aufrufe besitzen durchgaengige Tracekorrelation | 5 | Runtime | `scripts/verify-live-llm-evidence-chain.ps1`; `scripts/verify-phase1-runtime.ps1` | erfuellt, begrenzter Pfad |
| Aktueller Hosted-Gateway ist source-gebunden generativ erreichbar | 10 | Hosted | `scripts/verify-cloudflare-llm-gateway-hosted-readonly.ps1`; spaeterer generativer Hosted-Verifier erforderlich | offen; read-only reicht nicht |
| Hosted Stream und Non-Stream sind semantisch gleich | 10 | Hosted | spaeterer `scripts/verify-llm-hosted-stream-parity.ps1` erforderlich | offen |
| Hosted Routing haelt die freigegebene Provider-Allowlist ein | 4 | Hosted | `scripts/verify-live-llm-evidence-chain.ps1` nach aktuellem Source-Rebind | offen |
| Hosted Fallback ist begrenzt und auditiert | 3 | Hosted | spaeterer `scripts/verify-llm-hosted-fallback.ps1` erforderlich | offen |
| Hosted Budget-Guard stoppt vor dem Provideraufruf | 3 | Hosted | spaeterer `scripts/verify-llm-hosted-budget-guard.ps1` erforderlich | offen |
| Hosted Completion-Audit ist persistent und source-gebunden | 4 | Hosted | `scripts/verify-live-llm-evidence-chain.ps1` nach aktuellem Source-Rebind | offen |
| Hosted Trace-ID korreliert Gateway, Provider und Evidence | 4 | Hosted | spaeterer `scripts/verify-llm-hosted-trace-correlation.ps1` erforderlich | offen |
| Hosted fehlende/ungueltige Authentifizierung liefert 401/403 | 2 | Hosted | spaeterer `scripts/verify-llm-hosted-negative-guards.ps1` erforderlich | offen |
| Hosted Oversize-Request liefert fail-closed 422 | 2 | Hosted | spaeterer `scripts/verify-llm-hosted-negative-guards.ps1` erforderlich | offen |
| Hosted Schema-/Policy-Verstoss erreicht keinen Provider | 3 | Hosted | spaeterer `scripts/verify-llm-hosted-negative-guards.ps1` erforderlich | offen |
| **Summe L4** | **100** |  |  | **Entwurf; kein Credit** |

Der heutige Manifestwert L4 `55` bleibt unveraendert. Die letzten 45 Punkte
sind ausschliesslich der vorgeschlagene Hosted-Abschlussblock.

## L5 — MCP Gateway (Entwurf, 100 Punkte)

| Kriterium | Punkte | Beweisart | Verifier | Aktueller Stand |
|---|---:|---|---|---|
| Rollenbezogene MCP-Safe-Envelopes begrenzen Tool und Operation | 8 | Unit + Runtime | `scripts/verify-phase1-runtime.ps1`; `scripts/verify-phase4-mcp-devops-hosted.ps1` | erfuellt, begrenzte Pfade |
| PostgreSQL-Adapter bleibt read-only | 6 | Runtime | `scripts/verify-phase1-runtime.ps1` | erfuellt, DEV-ONLY |
| Filesystem-Adapter bleibt auf den festen Projektfortschritts-Read begrenzt | 8 | Runtime + Browser | `scripts/verify-mcp-filesystem-project-progress.ps1` | erfuellt, DEV-ONLY |
| Playwright-Adapter liefert einen gebundenen Browserbeweis | 6 | Runtime + Browser | `scripts/verify-phase1-runtime.ps1`; `scripts/verify-browser-contract.ps1` | erfuellt, DEV-ONLY |
| Sandbox-Lifecycle ist begrenzt und fail-closed | 4 | Runtime | `scripts/verify-phase1-runtime.ps1` | erfuellt, DEV-ONLY |
| MCP-Session ist an den autorisierten Aufrufer gebunden | 6 | Runtime | `scripts/verify-phase1-runtime.ps1` | erfuellt, DEV-ONLY |
| Lokaler Timeout stoppt den Toollauf kontrolliert | 3 | Runtime | `scripts/verify-orchestrator-completion-evidence.ps1` | erfuellt, DEV-ONLY |
| Lokale Idempotenz verhindert Replay-Doppelwirkungen | 3 | Runtime | `scripts/verify-o4-live-writes.ps1` | erfuellt, DEV-ONLY |
| MCP-Audit korreliert Request, Session und Ergebnis | 6 | Runtime | `scripts/verify-phase4-mcp-audit-feed-contract-runtime-hosted.ps1`; `scripts/verify-o4-live-writes.ps1` | erfuellt, begrenzte Pfade |
| MCP-/Workflow-Abhaengigkeiten sind versionsgepinnt | 6 | Static | `scripts/verify-supply-chain-pins.ps1` | erfuellt |
| Hosted MCP Write wird auf einem freigegebenen Ziel ausgefuehrt | 10 | Hosted | spaeterer `scripts/verify-mcp-hosted-write.ps1` erforderlich | offen; O4 ist nur DEV-ONLY |
| Hosted MCP Write verlangt gueltige Aufruferauthentifizierung | 3 | Hosted | spaeterer `scripts/verify-mcp-hosted-auth-scope.ps1` erforderlich | offen |
| Hosted MCP Write erzwingt den exakten Scope | 3 | Hosted | spaeterer `scripts/verify-mcp-hosted-auth-scope.ps1` erforderlich | offen |
| Hosted MCP Timeout stoppt ohne Nachwirkung | 2 | Hosted | spaeterer `scripts/verify-mcp-hosted-timeout-idempotency.ps1` erforderlich | offen |
| Hosted MCP Idempotenz blockiert Replay-Doppelwrites | 2 | Hosted | spaeterer `scripts/verify-mcp-hosted-timeout-idempotency.ps1` erforderlich | offen |
| Hosted MCP Audit wird vor und nach dem Write persistiert | 4 | Hosted | spaeterer `scripts/verify-mcp-hosted-audit-readback-rollback.ps1` erforderlich | offen |
| Hosted Write wird serverseitig zurueckgelesen | 3 | Hosted | spaeterer `scripts/verify-mcp-hosted-audit-readback-rollback.ps1` erforderlich | offen |
| Hosted Auditfehler erzwingt Rollback | 3 | Hosted | spaeterer `scripts/verify-mcp-hosted-audit-readback-rollback.ps1` erforderlich | offen |
| Registry-Referenzen besitzen unveraenderliche Remote-Digests | 3 | Hosted + Registry | `scripts/verify-supply-chain-pins.ps1`; Remote-Digest-Verifier erforderlich | offen; GHCR unveroeffentlicht |
| Kandidatenimages besitzen ein gebundenes SBOM | 3 | CI + Registry | spaeterer `scripts/verify-mcp-candidate-sbom.ps1` erforderlich | offen |
| Kandidatenimages bestehen den Remote-Secret-/Vulnerability-Scan | 2 | CI + Registry | `scripts/run-secret-scans.ps1`; Remote-Image-Scan erforderlich | offen |
| Geschuetzter Workflow verlangt Environment-Review vor Write/Publish | 6 | CI + Hosted | `scripts/verify-autonomous-release-workflow.ps1`; echter approvierter Lauf erforderlich | offen; Environments konfiguriert, kein Publish |
| **Summe L5** | **100** |  |  | **Entwurf; kein Credit** |

Der heutige Manifestwert L5 `56` bleibt unveraendert. Die letzten 44 Punkte
sind ausschliesslich der vorgeschlagene Hosted-/Registry-Abschlussblock.

## Owner-Entscheidung

Der Owner muss vor jeder Umsetzung der Punktevergabe explizit entscheiden:

1. Sind Kriterien und Gewichte fuer L4 akzeptiert?
2. Sind Kriterien und Gewichte fuer L5 akzeptiert?
3. Duerfen die noch fehlenden Hosted-Verifier unter genau diesen Namen gebaut werden?
4. Welcher Commit ist die freigegebene Rubrikversion?

Bis dahin gilt unveraendert:

`L4=55`, `L5=56`, `MARKET_READY:false`, keine Production-Promotion und kein
Registry-Push.
