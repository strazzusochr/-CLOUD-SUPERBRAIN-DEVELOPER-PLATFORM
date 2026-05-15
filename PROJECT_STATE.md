# CLOUD SUPERBRAIN — AKTUELLER PROJEKTSTAND (Auto-Loaded by Codex)

Letzte Aktualisierung: 2026-05-15 04:19 Uhr
══════════════════════════════════════════════════════════════════

## AKTUELLER PROJEKTANKER

- **Anchor ID:** `project-anchor-2026-04-30T00-49-26+02-00`
- **Anchor-Datei:** `PROJECT_ANCHOR.md`
- **Checkpoint:** `docs/project-checkpoint-2026-04-30.json`
- **Live-Snapshot:** `2026-04-30 00:49:26 +02:00`
- **Kernstand:** Localhost `8081` bleibt Dev-Control-Plane; Gesamtfortschritt laut bindendem Manifest `81%`; Phase 1 Foundation Runtime ist manifestseitig `100%`; Phase 2 Core Runtime steht durch die Autonomous-Team-Dispatch-Provenance, die Autonomous-Roster/Master-Plan-Proofs und den Phase-2-Runtime-Dual-Surface-Proof auf `88%`; Phase 3 Product Surface & Security steht weiterhin auf `95%`; Phase 5 steht jetzt auf `81%`; Agent Pool steht bei `75%`; LLM Gateway steht bei `65%`; Memory steht bei `73%`; MCP Gateway steht bei `65%`; Frontend / Next.js steht bei `99%`; Project Progress Integrity `verified`; echtes Hosted HTTPS Staging auf `<hosted-staging-url>` ist verifiziert. Der aktive Candidate ist als immutable Staging-Selector `0065a5e0254dd530b1c3a49f8ce602b8952eafa4` plus Active LLM Operations Bundle, Active Agent Operations Bundle, Active Memory Operations Bundle, Active Gateway Execution Bundle, Active Runtime Selector Truth Rebaseline, Active Full-Suite Rebaseline, Active Verifier Sweep Bundle Rebaseline, Active Runtime Guard Matrix Bundle, Active Gateway Policy Bundle, Runtime Evidence Bundle, Security Evidence Bundle, Vercel/GitHub-Status, Autonomous Roster Master Plan und Phase 2 Runtime Dual Surface verifiziert; Production bleibt weiterhin nicht ausgerollt.

## PROJEKT-IDENTITÄT

- **Name:** -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
- **Ziel:** Cloud-native, multi-agent AI-Entwicklerplattform, 3D-Webgame-fähig, prompt-gesteuert
- **Repo-Pfade:**
  - Hauptprojekt: `<repo-root>`
  - Fresh Build: `<workspace-root>\cloud-superbrain-fresh`
- **Architektur-Wahrheit:** `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`

## HARTE CONSTRAINTS (NIEMALS BRECHEN)

1. **Budget:** Max €20/Monat Infrastruktur (Hetzner CX21 + Cloudflare)
2. **Kein Localhost in Produktion:** Alles muss Cloud-fähig sein
3. **Orchestrierung:** LangGraph als Haupt-Orchestrator mit PostgreSQL-Checkpointer
4. **Open-Source-First:** LangGraph, LiteLLM, Langfuse, pgvector
5. **Kein Qdrant:** Nur pgvector in Phase 1-5
6. **Kein E2B-Sandbox:** Docker Desktop für lokale Tests
7. **7-Schichten-Architektur** laut Ultimatum Finale

## AKTUELLER FORTSCHRITT: 81%

### Horizontal (nach Priorität)

| Prio | Status |
|------|--------|
| P0   | 100%   |
| P1   | 100%   |
| P2   | 88%    |
| P3   | 95%    |
| P4   | 100%   |
| P5   | 81%    |
| P6   | 0%     |

### Vertikal (nach Modul)

| Modul         | Status |
|---------------|--------|
| Frontend      | 99%    |
| Orchestrator  | 99%    |
| Agent Pool    | 75%    |
| LLM Gateway   | 65%    |
| MCP Gateway   | 65%    |
| Memory        | 73%    |
| Observability | 99%    |

## LAUFENDE DOCKER-CONTAINER (cloud-superbrain-phase1-dev)

- nginx (healthy)
- agent-api (healthy)
- redis (healthy)
- frontend (healthy)
- mcp-gateway (healthy)
- llm-gateway (healthy)
- agent-worker (healthy)
- memory-worker (healthy)
- postgres (healthy)

## NÄCHSTER KONKRETER ARBEITSSCHRITT

- **Naechster grosser Fortschrittshebel: Phase 5 Release Readiness** — der aktive RC1 ist als immutable Staging-Selector `0065a5e0254dd530b1c3a49f8ce602b8952eafa4` verifiziert und bindet jetzt das Active LLM Operations Bundle, Active Agent Operations Bundle, Active Memory Operations Bundle, Active Gateway Execution Bundle, Active Full-Suite Rebaseline, den Active Verifier Sweep Rebaseline, die Runtime-Guard-Surfaces im Active Runtime Guard Matrix Bundle, die LLM-/MCP-Gateway-Policy-Surfaces im Active Gateway Policy Bundle, die Runtime-Flaechen im Active Runtime Evidence Bundle, die wichtigsten Security-Exportflaechen im Active Security Evidence Bundle sowie den GitHub/Vercel Deployment-Status.
- danach folgen P3-Auth/Security- und LLM/MCP-Layer-Slices, kein Production-Rollout ohne separates Gate
- lokal und hosted bleiben weiterhin deterministische Proofs ohne Live-Provider und ohne Live-MCP-Writes; `production_deploy_claim_allowed=true` ist kein Deployment-Nachweis

## ZULETZT ABGESCHLOSSEN

**Active LLM Operations Bundle Proof** — der aktive RC1 laeuft jetzt als neuer immutable Staging-Selector `0065a5e0254dd530b1c3a49f8ce602b8952eafa4` und bindet reale LLM-Gateway-Operations-Pfade:

- `scripts\verify-phase5-active-llm-operations-bundle.ps1` prueft LLM Health, Model Catalog, Runtime Guard Parity, Streaming Contract, Agent-LLM-Streaming-Contract, LLM Audit Contract/Feed/Export, Live-Provider-Guard und Evidence-Artifact-Safety.
- Nachgewiesen sind hosted `overall=81`, Phase 5 `81%`, LLM Gateway `65%`, `IMAGE_TAG=0065a5e0254dd530b1c3a49f8ce602b8952eafa4`, GHCR `linux/arm64` fuer alle sechs Services und immutable Hetzner `-UseImageFilesystem`.
- Fortschritt steigt `overall=81`, `phase_5=81` und `llm_gateway=65`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, kein lokaler Model-Download und keine Secret-Offenlegung.

**Active Agent Operations Bundle Proof** — der aktive RC1 laeuft jetzt als immutable Staging-Selector `0065a5e0254dd530b1c3a49f8ce602b8952eafa4` und bindet reale Agent-Operations-Pfade:

- `scripts\verify-phase5-active-agent-operations-bundle.ps1` prueft Agent Status, Recent-Tasks-Contract, Autonomous Coding Team, Autonomous Roster/Master-Plan, Phase 2 Runtime Dual Surface, Live-Agent-Steering, Live-Agent-History und Evidence-Artifact-Safety.
- Nachgewiesen sind hosted `overall=80`, Phase 5 `80%`, Agent Pool `75%`, `IMAGE_TAG=0065a5e0254dd530b1c3a49f8ce602b8952eafa4`, GHCR `linux/arm64` fuer alle sechs Services und immutable Hetzner `-UseImageFilesystem`.
- Fortschritt steigt `phase_5=80` und `agent_pool=75`; Gesamt bleibt `80`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, kein lokaler Model-Download und keine Secret-Offenlegung.

**Active Memory Operations Bundle Proof** — der aktive RC1 laeuft jetzt als immutable Staging-Selector `0065a5e0254dd530b1c3a49f8ce602b8952eafa4` und bindet reale Memory-Operations-Pfade:

- `scripts\verify-phase5-active-memory-operations-bundle.ps1` prueft Memory Search, Memory Purge Job Status, Memory Contracts, Hosted Session-Memory-Parity, Hosted Embedding-Consistency-Parity, Hosted Smoke und Evidence-Artifact-Safety.
- Nachgewiesen sind hosted `overall=80`, Phase 5 `79%`, Memory `73%`, `IMAGE_TAG=0065a5e0254dd530b1c3a49f8ce602b8952eafa4`, GHCR `linux/arm64` fuer alle sechs Services und immutable Hetzner `-UseImageFilesystem`.
- Fortschritt steigt `phase_5=79` und `memory=73`; Gesamt bleibt `80`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, kein Live-Embedding-Provider-Call, kein lokaler Model-Download und keine Secret-Offenlegung.

**Active Gateway Execution Bundle Proof** — der aktive RC1 laeuft jetzt als immutable Staging-Selector `0065a5e0254dd530b1c3a49f8ce602b8952eafa4` und bindet reale nicht-mutierende Ausfuehrungspfade:

- `scripts\verify-phase5-active-gateway-execution-bundle.ps1` prueft Phase-2 Runtime Dual Surface, Agent-LLM-Streaming, MCP DevOps Safe Envelope, Gateway Correlation Snapshot/Risk/Timeline, Hosted Smoke und Evidence-Artifact-Safety.
- Nachgewiesen sind hosted `overall=80`, Phase 5 `79%`, `IMAGE_TAG=0065a5e0254dd530b1c3a49f8ce602b8952eafa4`, GHCR `linux/arm64` fuer alle sechs Services und immutable Hetzner `-UseImageFilesystem`.
- Fortschritt steigt in diesem Schritt auf `phase_5=78`; aktueller Manifeststand nach Agent-Operations-Rebaseline ist `phase_5=80`; Gesamt bleibt `80`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, kein lokaler Model-Download und keine Secret-Offenlegung.

**Active Verifier Sweep Bundle Rebaseline Proof** — der aktive RC1 bindet jetzt elf nicht-mutierende Safety-Gates an den aktuellen Hosted-Candidate:

- `scripts\verify-phase5-active-verifier-sweep-bundle.ps1` prueft current-release-candidate, active-release-candidate bundle, hosted staging smoke, Active Gateway Policy Bundle, Active Runtime Guard Matrix Bundle, Active Gateway Execution Bundle, Active Memory Operations Bundle, LLM Model Catalog, MCP Capability Catalog, Security Scan und Evidence-Artifact-Safety.
- Nachgewiesen sind `production_rollout_claimed=false`, `verifier_gate_count=11`, hosted progress `80%`, Phase 5 `79%` und Memory `73%`.
- Fortschritt bleibt unveraendert; Gesamt bleibt `80`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, kein lokaler Model-Download und keine Secret-Offenlegung.

**Vorheriger Abschluss — Active Runtime Guard Matrix Bundle Proof** — der aktive RC1 bindet jetzt Live-Agent-, LLM- und MCP-Runtime-Guards an lokale und gehostete Beweise:

- `scripts\verify-phase5-active-runtime-guard-matrix-bundle.ps1` prueft Live-Agent-Steering, Live-Agent-History, LLM Live-Provider Guard, MCP Security Guard, Browser-Contract und Evidence-Artifact-Safety lokal und hosted.
- Nachgewiesen sind `live_agent_metadata_guard_enforced`, `llm_runtime_guard_parity_visible`, `mcp_unsupported_toolset_guard` und `mcp_secret_redaction_guard` bei hosted progress `80%`, `phase_3=95`, `phase_5=80`, `agent_pool=75`, `llm_gateway=64` und `mcp_gateway=65`.
- Fortschritt bleibt unveraendert; Gesamt bleibt `80`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, kein lokaler Model-Download und keine Secret-Offenlegung.

**Vorheriger Abschluss — Active Full-Suite Rebaseline Proof** — der aktive RC1 bindet jetzt den Phase-5-Suite-Plan und die aktuellen Active-Candidate-Gates an denselben Hosted-Candidate:

- `scripts\verify-phase5-full-verifier-sweep.ps1` prueft fuer den aktiven RC1 Manifest, Phase-5-Suite-Plan, current-release-candidate, active-release-candidate bundle, hosted staging smoke, Active Runtime Evidence Bundle, Active Security Evidence Bundle, Active Verifier Sweep Bundle, Vercel/GitHub Deployment Status und Evidence-Artifact-Safety.
- Nachgewiesen sind `active_gate_count=10`, `phase5_suite_plan_status=passed`, hosted progress `80%`, Phase 5 aktuell `79%`, immutable selector `0065a5e0254dd530b1c3a49f8ce602b8952eafa4` und `production_rollout_claimed=false`.
- Fortschritt stieg in diesem Schritt auf `phase_5=76`; aktueller Manifeststand nach Selector-, Gateway-Execution-, Memory-Operations- und Agent-Operations-Rebaseline ist `phase_5=80`, Gesamt bleibt `80`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, kein lokaler Model-Download und keine Secret-Offenlegung.

**Vorheriger Abschluss — Active Verifier Sweep Bundle Proof** — der aktive RC1 bindet jetzt die wichtigsten nicht-mutierenden Verifier-Gates an den aktuellen Hosted-Candidate:

- `scripts\verify-phase5-active-verifier-sweep-bundle.ps1` prueft current-release-candidate, active-release-candidate bundle, hosted staging smoke, Active Gateway Policy Bundle, LLM Model Catalog, MCP Capability Catalog, Security Scan und Evidence-Artifact-Safety.
- Nachgewiesen sind `production_rollout_claimed=false`, active bundle `status=passed`, hosted progress `80%`, Phase 5 im damaligen Verifier-Sweep `75%` und aktueller Manifeststand `78%`, LLM/MCP catalog proof, Security Scan ohne neue Findings und evidence-artifact-safety `safe`.
- Fortschritt steigt `phase_5=75`; Gesamt bleibt `80`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, kein lokaler Model-Download und keine Secret-Offenlegung.

**Vorheriger Abschluss — Active Gateway Policy Bundle Proof** — der aktive RC1 bindet jetzt LLM-/MCP-Gateway-Policy-Flaechen an lokale und gehostete Beweise:

- `scripts\verify-phase3-active-gateway-policy-bundle.ps1` prueft LLM Health, LLM Model Catalog, LLM Audit Contract/Feed/Snapshot, MCP Health, MCP Capability Catalog, MCP Audit Contract/Feed/Snapshot sowie Gateway-Correlation Contract/Snapshot/Risk-Rollup/Timeline lokal und hosted.
- Nachgewiesen sind `llm-model-catalog-v1`, `mcp-capability-catalog-v1`, `llm-audit-feed-v1`, `read_only_llm_audit_redaction_snapshot`, `llm_audit_snapshot_visible`, `mcp-audit-feed-v1`, `read_only_mcp_audit_redaction_snapshot`, `mcp_audit_snapshot_visible`, `gateway-correlation-snapshot-v1`, `gateway-correlation-risk-rollup-v1`, `gateway-correlation-timeline-v1`, `open_source_first=true`, `api_inference_only=true`, `model_downloads=false`, `local_model_downloads_allowed=false`, `live_provider_calls=false` und `live_mcp_writes=false`.
- Fortschritt steigt `overall=80`, `phase_3=95`, `llm_gateway=64`, `mcp_gateway=65`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, kein lokaler Model-Download und keine Secret-Offenlegung.

**Vorheriger Abschluss — Active Runtime Evidence Bundle Proof** — der aktive RC1 bindet jetzt read-only Runtime-Flaechen an lokale und gehostete Beweise:

- `scripts\verify-phase5-active-runtime-evidence-bundle.ps1` prueft Project Progress, Progress Integrity, Phase-2-Runtime-Contract/Runs, Orchestrator Manifest, Agent Status, Agent Activity, Master Plan, Roster und Team Status lokal sowie hosted.
- Nachgewiesen sind `phase2-runtime-v1`, `audit_log_backed_phase2_runtime_runs`, `agent-profiles-v1`, `autonomous-master-plan-v1`, `autonomous-agent-roster-v1`, `langgraph`, `postgres`, completed deterministische Rollen und die Non-Claims fuer Live-Provider, Live-MCP-Writes, Production Deploy, lokale Model-Downloads und Secrets.
- Fortschritt ist auf aktuellem Stand `overall=80`, `phase_5=80`, `agent_pool=75`, `memory=73`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, kein lokaler Model-Download und keine Secret-Offenlegung.

**Vorheriger Abschluss — Phase 2 Runtime Dual Surface Proof** — der aktive RC1 bindet jetzt die Phase-2-Runtime-Contracts, Start-Ausfuehrung und Runs-Feed an lokale und gehostete Beweise:

- `scripts\verify-phase2-runtime-dual-surface.ps1` prueft `GET /api/v1/phase2/runtime/contract`, `GET /api/v1/phase2/runtime/start/contract`, `POST /api/v1/phase2/runtime/start`, `GET /api/v1/phase2/runtime/runs/contract`, `GET /api/v1/phase2/runtime/runs?limit=10` und Homepage-Marker lokal sowie hosted.
- Nachgewiesen sind `phase2-runtime-v1`, `phase2-runtime-start-surface-v1`, `phase2-runtime-runs-surface-v1`, `deterministic_local_runtime`, `audit_log_backed_phase2_runtime_runs`, `langgraph`, `postgres`, vier completed Rollen und die Evidence-Refs `phase2_runtime_graph_started`, `task_assignment_completed`, `memory_update_persisted` und `agent_result_aggregation_complete`.
- Fortschritt bleibt `overall=79`, `phase_2=88`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, kein lokaler Model-Download und keine Secret-Offenlegung.

**Vorheriger Abschluss — Autonomous Roster Master Plan Proof** — der aktive RC1 bindet jetzt die Agenten-Roster- und Master-Plan-Runtime an lokale und gehostete Beweise:

- `scripts\verify-autonomous-roster-master-plan-bundle.ps1` prueft Master-Plan-Contract, Roster-Contract, Team-Status, Recent-Dispatch-Provenance und Homepage-Marker lokal sowie hosted.
- Nachgewiesen sind `autonomous-master-plan-v1`, `autonomous-agent-roster-v1`, `autonomous_master_plan_runtime_visible`, `autonomous_agent_roster_runtime_visible`, alle fuenf logischen Rollen, mindestens 14 persistierte Roster-Rollen, LangGraph-Binding und ein completed Dispatch mit `autonomous_team_dispatch_task_provenance`.
- Fortschritt bleibt `overall=79`, `phase_2=88`, `agent_pool=74`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write, keine External-Agent-Uptime-Garantie und keine Secret-Offenlegung.

**Vorheriger Abschluss — Vercel GitHub Deployment Status Proof** — der aktive RC1 bindet jetzt GitHub-Commitstatus, Vercel-Git-Link-Readiness, die oeffentliche Vercel-Frontend-URL und Hosted Staging:

- `scripts\verify-phase5-vercel-github-deployment-status.ps1` prueft GitHub combined status `Vercel=success`, Vercel-Ziel-URL-Prefix, lokalen Vercel-Git-Link, public Vercel Frontend HTTP `200`, Hosted Staging HTTP `200`, RC1-Artefakt und Non-Claim-Policy.
- Das Runtime-Selector-Paritaetsartefakt enthaelt jetzt die Metadaten, die `scripts\verify-current-runtime-selector-truth.ps1` erwartet.
- Fortschritt bleibt `overall=79`, `phase_5=74`; kein Production-Rollout, keine Vercel-Mutation, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — Active Security Evidence Bundle Proof** — der aktive RC1 bindet jetzt die wichtigsten redacted Security-Exportflaechen an den immutable Staging-Selector:

- `scripts\verify-phase5-active-security-evidence-bundle.ps1` prueft lokal und hosted die Export-Contracts/CSV-Responses fuer LLM Audit, MCP Audit, Gateway Correlation, Auth Audit und Security Review Queue.
- Jeder Export ist read-only, audit-persisted, redaction-guarded und wird mit Trace-/Request-ID in `audit_log` nachgewiesen.
- Lokal verifiziert: `scripts\verify-phase5-active-security-evidence-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`.
- Hosted verifiziert: `scripts\verify-phase5-active-security-evidence-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`.
- Fortschritt bleibt `overall=79`, `phase_5=74`; kein Production-Rollout, keine Release-Promotion, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Security Review Queue Export Proof** — die Security-Review-Operator-Oberflaeche hat jetzt einen read-only CSV-Export ueber sichere Review-Queue-Eintraege:

- `GET /api/v1/security/review-queue/export/contract` liefert `security-review-queue-export-v1`, `security_review_queue_export_visible`, `security_review_queue_export_audit_persisted`, `security_review_redaction_enforced` und `security_review_mutation_blocked`.
- `GET /api/v1/security/review-queue/export?format=csv&limit=80` liest nur dieselbe sichere `audit_log`-Projektion wie Security Review Queue, Snapshot und Gate und gibt ausschliesslich allowlisted CSV-Spalten aus.
- Export und Export-Audit geben keine raw details, Prompt-Bodies, Cookies, Authorization-Header, Provider-Credentials, Screenshots, Raw-Files, Live-Provider-Claims, Live-MCP-Write-Claims, Production-Rollout-Claims oder Promotion-Claims zurueck.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm --prefix apps/frontend run build`, `docker info --format '{{.ServerVersion}}'`, `docker compose -f docker-compose.dev.yml up -d --force-recreate agent-api nginx`, `scripts\verify-phase3-security-review-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost` und `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach GHCR-Build/Push und immutable Image-Deploy mit `IMAGE_TAG=0065a5e0254dd530b1c3a49f8ce602b8952eafa4`: Active Memory Operations Bundle, Active Gateway Execution Bundle, Security-Review-Export, Browser-Contract und Hosted-Staging sind gruen.
- Fortschritt: `overall=79`, `phase_3=94`; kein Production-Rollout, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Gateway Correlation Export Proof** — die Gateway-Korrelationsansicht hat jetzt einen read-only CSV-Export ueber sichere Agent-/LLM-/MCP-Korrelationsgruppen:

- `GET /api/v1/security/gateway-correlation/export/contract` liefert `gateway-correlation-export-v1`, `gateway_correlation_export_visible`, `gateway_correlation_export_audit_persisted`, `gateway_correlation_redaction_enforced` und `gateway_correlation_no_live_write_guard`.
- `GET /api/v1/security/gateway-correlation/export?format=csv&limit=80` liest nur dieselbe sichere `audit_log`-Projektion wie Gateway Correlation Snapshot, Risk Rollup und Timeline und gibt ausschliesslich allowlisted CSV-Spalten aus.
- Export und Export-Audit geben keine raw details, Prompt-Bodies, MCP-Input-Refs, Cookies, Authorization-Header, Provider-Credentials, Live-Provider-Claims, Live-MCP-Write-Claims, Production-Rollout-Claims oder Promotion-Claims zurueck.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `docker info --format '{{.ServerVersion}}'`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, `scripts\verify-phase3-gateway-correlation-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation`, Gateway Correlation Risk Rollup/Timeline, Browser-Contract, Security, Evidence-Artifact-Safety und Manifest-Validierung.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach GHCR-Build/Push und immutable Image-Deploy mit `IMAGE_TAG=819ec616b79059ab727567e5be82edba99b59045`: Gateway-Correlation-Export, Gateway-Correlation-Snapshot/Risk-Rollup/Timeline, Browser-Contract, Hosted-Staging und `scripts\verify.ps1 -Suite phase3` sind gruen.
- Fortschritt: `overall=79`, `phase_3=92`, `agent_pool=74`, `llm_gateway=63`, `mcp_gateway=64`; kein Production-Rollout, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — MCP Audit Export Proof** — die MCP-Operator-Ansicht hat jetzt einen read-only CSV-Export ueber sichere MCP-Gateway-Audit-Ereignisse:

- `GET /api/v1/audit/mcp/export/contract` liefert `mcp-audit-export-v1`, `mcp_audit_export_visible`, `mcp_audit_export_audit_persisted`, `mcp_audit_redaction_enforced` und `mcp_audit_no_live_write_guard`.
- `GET /api/v1/audit/mcp/export?format=csv&limit=80` liest nur dieselbe sichere `audit_log`-Projektion wie MCP Audit Feed und Snapshot und gibt ausschliesslich allowlisted CSV-Spalten aus.
- Export und Export-Audit geben keine Tool-Input-Refs, Prompt-Bodies, Cookies, Authorization-Header, Provider-Credentials, raw details, Live-MCP-Write-Claims, Production-Rollout-Claims oder Promotion-Claims zurueck.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `docker info --format '{{.ServerVersion}}'`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, `scripts\verify-phase3-mcp-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireSeed`, `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, Browser-Contract, Security und Evidence-Artifact-Safety.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach GHCR-Build/Push und immutable Image-Deploy mit `IMAGE_TAG=21145b89634b330231b6fd66c8aa2654c55a047e`: MCP-Audit-Export, MCP-Audit-Snapshot, Browser-Contract, Hosted-Staging und `scripts\verify.ps1 -Suite phase3` sind gruen.
- Fortschritt: `overall=79`, `phase_3=90`, `mcp_gateway=63`; kein Production-Rollout, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — LLM Audit Export Proof** — die LLM-Operator-Ansicht hat jetzt einen read-only CSV-Export ueber sichere LLM-Gateway-Audit-Ereignisse:

- `GET /api/v1/audit/llm/export/contract` liefert `llm-audit-export-v1`, `llm_audit_export_visible`, `llm_audit_export_audit_persisted`, `llm_audit_redaction_enforced` und `llm_audit_no_live_provider_guard`.
- `GET /api/v1/audit/llm/export?format=csv&limit=80` liest nur dieselbe sichere `audit_log`-Projektion wie LLM Audit Feed und Snapshot und gibt ausschliesslich allowlisted CSV-Spalten aus.
- Export und Export-Audit geben keine Prompt-Bodies, Tokens, Cookies, Authorization-Header, Provider-Credentials, raw details, Live-Provider-Claims, Production-Rollout-Claims oder Promotion-Claims zurueck.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `docker info --format '{{.ServerVersion}}'`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, `scripts\verify-phase3-llm-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireSeed`, `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, Browser-Contract, Security und Evidence-Artifact-Safety.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach GHCR-Build/Push und immutable Image-Deploy mit `IMAGE_TAG=13d02661c5cfbc2e4a881f1a16f303002affca06`: LLM-Audit-Export, LLM-Audit-Feed, Browser-Contract, Hosted-Staging und `scripts\verify.ps1 -Suite phase3` sind gruen.
- Fortschritt: `overall=79`, `phase_3=88`, `llm_gateway=62`; kein Production-Rollout, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — Auth Audit Export Proof** — die Auth-Operator-Ansicht hat jetzt einen read-only CSV-Export ueber sichere Auth-Lifecycle-Ereignisse:

- `GET /api/v1/audit/auth/export/contract` liefert `auth-audit-export-v1`, `auth_audit_export_visible`, `auth_audit_export_audit_persisted`, `auth_audit_redaction_enforced` und `auth_no_live_oauth_guard`.
- `GET /api/v1/audit/auth/export?format=csv&limit=80` liest nur dieselbe sichere `audit_log`-Projektion wie Snapshot, Risk-Rollup und Timeline und gibt ausschliesslich allowlisted CSV-Spalten aus.
- Export und Export-Audit geben keine Tokens, Cookies, Authorization-Header, OAuth-Code/State-Werte, Redis-Blacklist-Keys, raw details, Live-OAuth-Claims, Production-Rollout-Claims oder Promotion-Claims zurueck.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `docker info --format '{{.ServerVersion}}'`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, `scripts\verify-phase3-auth-audit-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`, Auth-Audit-Snapshot/Risk-Rollup/Timeline, Browser-Contract, Security, Evidence-Artifact-Safety und Manifest-Validierung.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach GHCR-Build/Push und immutable Image-Deploy mit `IMAGE_TAG=efa2035e565a500b4c530fffdbab5016853a910e`: Auth-Lifecycle, Auth-Audit-Export, Auth-Audit-Snapshot, Auth-Audit-Risk-Rollup, Auth-Audit-Timeline, Browser-Contract, Hosted-Staging und `scripts\verify.ps1 -Suite phase3` sind gruen.
- Fortschritt: `overall=78`, `phase_3=86`; kein Production-Rollout, kein Live-GitHub-OAuth-Claim, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Auth Audit Timeline Proof** — die Auth-Operator-Ansicht hat jetzt eine read-only Timeline ueber sichere Auth-Lifecycle-Ereignisse:

- `GET /api/v1/audit/auth/contract` liefert zusaetzlich `timeline_endpoint=GET /api/v1/audit/auth/timeline`, `timeline_contract_version=auth-audit-timeline-v1` und `auth_audit_timeline_visible`.
- `GET /api/v1/audit/auth/timeline` liest nur dieselbe sichere `audit_log`-Projektion wie Snapshot und Risk-Rollup, ordnet Callback/Refresh-Reuse/Refresh-Rotation/Logout-Ereignisse und setzt `production_rollout_claimed=false` sowie `promotion_allowed=false`.
- Audit-Ausgaben werden fuer Auth-Details oeffentlich redacted: OAuth `state`, `code`, Tokens, Cookies, Authorization-Header und Redis-Blacklist-Keys werden nicht zurueckgegeben; Trace-IDs werden vor Timeline-Ausgabe nochmals public-sanitized.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `docker info --format '{{.ServerVersion}}'`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`, `scripts\verify-phase3-auth-audit-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`, `scripts\verify-phase3-auth-audit-timeline.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`, `scripts\verify-security.ps1` und `scripts\verify-evidence-artifact-safety.ps1`.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach GHCR-Build/Push und immutable Image-Deploy mit `IMAGE_TAG=9c38c59238043dbda2d02ee4fcd0c59d44bac812`: Auth-Lifecycle, Auth-Audit-Snapshot, Auth-Audit-Risk-Rollup, Auth-Audit-Timeline mit adversarial Redaction-Canaries, Browser-Contract, Hosted-Staging und `scripts\verify.ps1 -Suite phase3` sind gruen.
- Fortschritt: `overall=78`, `phase_3=84`; kein Production-Rollout, kein Live-GitHub-OAuth-Claim, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — Auth Audit Risk Rollup Proof** — die Auth-Operator-Ansicht hat jetzt einen read-only Risiko-Rollup ueber sichere Auth-Lifecycle-Ereignisse:

- `GET /api/v1/audit/auth/contract` liefert zusaetzlich `risk_rollup_endpoint=GET /api/v1/audit/auth/risk-rollup`, `risk_rollup_contract_version=auth-audit-risk-rollup-v1` und `auth_audit_risk_rollup_visible`.
- `GET /api/v1/audit/auth/risk-rollup` liest nur dieselbe sichere `audit_log`-Projektion wie der Snapshot, zaehlt Callback/Refresh-Reuse/Refresh-Rotation/Logout-Ereignisse, Risk-Badges, Blocker/Reviews, Redaction-Hits und Live-OAuth-Hits und setzt `production_rollout_claimed=false` sowie `promotion_allowed=false`.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `docker info --format '{{.ServerVersion}}'`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`, `scripts\verify-phase3-auth-audit-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-security.ps1` und `scripts\verify-evidence-artifact-safety.ps1`.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach GHCR-Build/Push und immutable Image-Deploy mit `IMAGE_TAG=4a59571c77d46728b8c11320e6dc65433b7eeff0`: Auth-Lifecycle, Auth-Audit-Snapshot, Auth-Audit-Risk-Rollup, Browser-Contract, Hosted-Smoke und `scripts\verify.ps1 -Suite phase3` sind gruen.
- Fortschritt: `overall=78`, `phase_3=82`; kein Production-Rollout, kein Live-GitHub-OAuth-Claim, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — Auth Audit Snapshot Proof** — die Auth-Operator-Ansicht hat jetzt einen read-only Audit-Snapshot ueber Auth-Lifecycle-Ereignisse:

- `GET /api/v1/audit/auth/contract` liefert `auth-audit-snapshot-v1`, `parent_contract_version=auth-github-jwt-refresh-v1`, `read_only=true`, `auth_audit_snapshot_visible`, `auth_audit_redaction_enforced` und `auth_no_live_oauth_guard`.
- `GET /api/v1/audit/auth/snapshot` liest nur `audit_log`, zeigt sichere Auth-Lifecycle-Felder, zaehlt Callback/Refresh-Reuse/Refresh-Rotation/Logout-Ereignisse und gibt keine Tokens, Cookies, Authorization-Header, OAuth-Code/State-Werte, Redis-Blacklist-Keys oder raw details zurueck.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, `scripts\verify-phase3-auth-audit-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireLifecycle`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-security.ps1` und `scripts\verify-evidence-artifact-safety.ps1`.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach GHCR-Build/Push und immutable Image-Deploy mit `IMAGE_TAG=7a849155a7b6c3f2dd3ba93ff9fa306ad87b9296`: Auth-Lifecycle, Auth-Audit-Snapshot, Browser-Contract, Hosted-Smoke und `scripts\verify.ps1 -Suite phase3` sind gruen.
- Fortschritt: `overall=77`, `phase_3=80`; kein Production-Rollout, kein Live-GitHub-OAuth-Claim, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — Gateway Correlation Timeline Proof** — die Operator-Ansicht hat jetzt eine read-only Ereignis-Timeline ueber Agent-/LLM-/MCP-Korrelationen:

- `GET /api/v1/security/gateway-correlation/timeline` liefert `gateway-correlation-timeline-v1`, `gateway_correlation_timeline_visible`, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, `live_provider_calls_claimed=false` und `live_mcp_writes_claimed=false`.
- Die Timeline ordnet sichere `audit_log`-Projektionen nach Zeit und zeigt nur Sequence, Event-Typ, Timeline-Leg, Trace/Request/Session, Status, Severity und Evidence-Refs; raw details, Prompt-Bodies, MCP-Input-Refs, Credentials, Cookies und Auth-Header bleiben ausgeschlossen.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation`, `scripts\verify-phase3-gateway-correlation-timeline.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-security.ps1` und `scripts\verify-evidence-artifact-safety.ps1`.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach GHCR-Build/Push und immutable Image-Deploy mit `IMAGE_TAG=d2c8b9c52785955b698da151edb666c884ac888f`: Gateway-Correlation-Snapshot, Risk-Rollup, Timeline, Browser-Contract, Hosted-Smoke und `scripts\verify.ps1 -Suite phase3` sind gruen.
- Fortschritt: `overall=77`, `phase_3=78`; kein Production-Rollout, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — Gateway Correlation Risk Rollup Proof** — die Operator-Ansicht hat jetzt einen read-only Risiko-Rollup ueber Agent-/LLM-/MCP-Korrelationen:

- `GET /api/v1/security/gateway-correlation/risk-rollup` liefert `gateway-correlation-risk-rollup-v1`, `gateway_correlation_risk_rollup_visible`, `read_only=true`, `promotion_allowed=false`, `production_rollout_claimed=false`, `live_provider_calls_claimed=false` und `live_mcp_writes_claimed=false`.
- Der Rollup zaehlt Full-/Partial-/Gateway-Pair-Korrelationen, Missing-Leg-Counts, Risk-Badges, Blocker und Review-Gruppen aus derselben sicheren `audit_log`-Projektion wie der Snapshot.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-phase3-gateway-correlation-risk-rollup.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost -RequireFullCorrelation`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `py -3 scripts\verify_project_progress_manifest.py`.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach GHCR-Build/Push und immutable Image-Deploy mit `IMAGE_TAG=5a67227c12bbfb1c9da956158ed2cec6d7b6d8a0`: Gateway-Correlation-Snapshot-Verifier, Gateway-Correlation-Risk-Rollup-Verifier, Browser-Contract und Hosted-Smoke sind gruen.
- Fortschritt: `overall=77`, `phase_3=76`; kein Production-Rollout, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — Gateway Correlation Snapshot Proof** — die Operator-Ansicht korreliert Agent-Task-, LLM-Gateway- und MCP-Gateway-Audit-Evidence jetzt read-only unter gemeinsamen Trace-/Request-/Session-Keys:

- `GET /api/v1/security/gateway-correlation/contract` liefert `gateway-correlation-snapshot-v1`, `read_only=true`, `live_provider_calls_claimed=false`, `live_mcp_writes_claimed=false`, `gateway_correlation_snapshot_visible`, `gateway_correlation_redaction_enforced` und `gateway_correlation_no_live_write_guard`.
- `GET /api/v1/security/gateway-correlation/snapshot` liest nur `audit_log`, gibt nur sichere Korrelationsfelder aus und setzt `prompt_bodies_returned=false`, `tool_input_refs_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`.
- Der Verifier seedet eine deterministische Agent-Task, einen LLM-Dry-Run und einen denied MCP-Call unter demselben Trace und verlangt `agent_llm_mcp_correlated` mit `live_provider_call_count=0` und `live_mcp_write_count=0`.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `scripts\verify-phase3-gateway-correlation-snapshot.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `py -3 scripts\verify_project_progress_manifest.py`.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach immutable Image-Deploy mit `IMAGE_TAG=10df3ea48627e6f11787587e3c984b72107e78f5`: Gateway-Correlation-Verifier, Browser-Contract und Hosted-Smoke sind gruen.
- Fortschritt: `overall=77`, `phase_3=74`, `agent_pool=73`, `llm_gateway=61`, `mcp_gateway=61`; kein Production-Rollout, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — MCP Audit Redaction Snapshot Proof** — die MCP-Gateway-Operator-Ansicht hat jetzt einen read-only Snapshot fuer Redaction, Deny-Korrelation und No-Live-MCP-Write-Nachweise:

- `GET /api/v1/audit/mcp/contract` liefert weiter `mcp-audit-feed-v1`, jetzt zusaetzlich mit `snapshot_endpoint=GET /api/v1/audit/mcp/snapshot`, `mcp_audit_snapshot_visible`, `mcp_audit_redaction_enforced` und `live_mcp_writes_claimed=false`.
- `GET /api/v1/audit/mcp` gibt MCP-Audit-Events mit `input_ref_stored=false` und `redaction_evidence_ref=mcp_audit_redaction_enforced` aus; `GET /api/v1/audit/mcp/snapshot` aggregiert Status-, Toolset-, Capability-, Error-Class- und Agent-Role-Counts und setzt `input_refs_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`.
- Frontend rendert `MCP Audit Snapshot`, Snapshot-Endpunkt, Snapshot-Evidence, Redaction-Evidence, Forbidden-Hit-Status, Blocked-/Denied-/Session-Bound-Zaehler und Input-Ref-Non-Claim im MCP Audit Panel.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `scripts\verify-phase3-mcp-deny-audit-correlation.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach immutable Image-Deploy mit `IMAGE_TAG=0a7ca2bed583f2e01af39a73e095e91cee642365`: MCP-Audit-Snapshot-Verifier, Browser-Contract und Hosted-Smoke sind gruen.
- Fortschritt: `overall=76`, `phase_3=72`, `mcp_gateway=60`; kein Production-Rollout, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — LLM Audit Feed Redaction Snapshot Proof** — die LLM-Gateway-Operator-Ansicht hat jetzt einen read-only Snapshot fuer Redaction, Dry-Run-Zaehler und No-Live-Provider-Nachweise:

- `GET /api/v1/audit/llm/contract` liefert weiter `llm-audit-feed-v1`, jetzt zusaetzlich mit `snapshot_endpoint=GET /api/v1/audit/llm/snapshot`, `llm_audit_snapshot_visible` und `llm_audit_redaction_enforced`.
- `GET /api/v1/audit/llm` gibt LLM-Audit-Events mit `prompt_body_stored=false` und `redaction_evidence_ref=llm_audit_redaction_enforced` aus; `GET /api/v1/audit/llm/snapshot` aggregiert Status-, Provider-, Agent- und Model-Counts und setzt `prompt_bodies_returned=false`, `provider_credentials_returned=false`, `forbidden_pattern_hits=0`.
- Frontend rendert `LLM Audit Snapshot`, Snapshot-Endpunkt, Snapshot-Evidence, Redaction-Evidence, Forbidden-Hit-Status und Prompt-Body-Non-Claim im LLM Audit Feed Panel.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py services\agent-api\app\security.py`, `npm run build`, `scripts\verify-phase3-llm-audit-feed.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach immutable Image-Deploy mit `IMAGE_TAG=f5fb7d221d403b966b38d240bd5b936755ecc245`: LLM-Audit-Feed-Verifier, Browser-Contract und Hosted-Smoke sind gruen.
- Fortschritt: `overall=76`, `phase_3=70`, `llm_gateway=60`; kein Production-Rollout, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Security Review Gate Summary Proof** — die Operator-Oberflaeche hat jetzt eine read-only Security Review Queue mit Snapshot-, Filter-, Risk-Badge-, Decision-History-, Gate-Summary-, Redaction- und Mutation-Block-Nachweis:

- `GET /api/v1/security/review-queue/contract` liefert `security-review-queue-v1`, `read_only=true` und die Evidence-Refs `security_review_queue_visible`, `security_review_item_visible`, `security_review_filter_state_visible`, `security_review_decision_history_visible`, `security_review_evidence_snapshot_visible`, `security_review_redaction_enforced` und `security_review_mutation_blocked`.
- `GET /api/v1/security/review-queue` aggregiert Security-Audit-Findings redacted; `GET /api/v1/security/review-queue/snapshot` liefert Filter-State, Status-/Kategorie-Counts, Risk-Badges, Decision-History und Evidence-Snapshots; `GET /api/v1/security/review-queue/gate` liefert den read-only Security Review Gate Summary mit blocker_count, production_rollout_claimed=false und promotion_allowed=false; `POST/PUT/PATCH/DELETE /api/v1/security/review-queue` blocken mit HTTP `403`.
- Frontend rendert `Security Review Queue`, Security Review Gate Summary, Endpoint, Snapshot-Evidence, Filter-State, Risk-Badges, Decision-History, Status-/Severity-Zaehler und redacted Item Cards.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `scripts\verify-phase3-security-review-gate.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach immutable Image-Deploy mit `IMAGE_TAG=9f1e52266b3d9f9ddbdfc226d68bd2379ead9fad`: Security-Review-Gate-Verifier, Browser-Contract und Hosted-Smoke sind gruen.
- Fortschritt: `overall=76`, `phase_3=67`; kein Production-Rollout, kein Live-Provider-Call, kein Live-MCP-Write und keine Secret-Offenlegung.

**Vorheriger Abschluss — Phase 3 Security Audit Surface** — die Product-Surface-&-Security-Schicht hat jetzt eine read-only Operator-Ansicht ueber sicherheitsrelevante Audit-Events:

- `GET /api/v1/security/events/contract` liefert `security-audit-surface-v1`, `security_audit_surface_visible`, `security_audit_event_visible`, `read_only=true`, Eventtypen fuer CSP/Auth/MCP/LLM und klare Non-Claims.
- `GET /api/v1/security/events` liest nur `audit_log`, zeigt Request-/Trace-Korrelation, MCP-Deny-Evidence und LLM-Dry-Run-Status, ohne Tools oder Provider aufzurufen.
- Frontend rendert `Security Audit Surface`; `scripts\verify-phase3-security-audit-surface-hosted.ps1` seedet CSP, LLM-Dry-Run und MCP-Deny-Events und prueft Redaction.
- Lokal verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `npm run build`, `scripts\verify-phase3-security-audit-surface-hosted.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`, `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`.
- Hosted verifiziert auf `https://188-34-191-140.sslip.io` nach immutable Image-Deploy mit `IMAGE_TAG=54bb064c8a5650f9a5c811179d3b4d0e1f38cfbf`: Security-Audit-Verifier, Browser-Contract und Hosted-Smoke sind gruen.
- Fortschritt: `overall=73`, `phase_3=50`, `llm_gateway=57`, `mcp_gateway=57`; kein Production-Rollout, kein Live-Provider-Call und kein Live-MCP-Write.

**Vorheriger Abschluss — Phase 5 Immutable Staging Parity** — der aktive RC1 ist wirklich als immutable Image-Filesystem-Selector auf Hetzner-Staging verifiziert:

- GitHub Actions `main-deploy` Run `25833000061` baute `agent-api`, `agent-worker`, `memory-worker`, `mcp-gateway` und `llm-gateway` fuer `031c95c3e5af1101caf282eee463256285803495`; der unveraenderte Frontend-Manifest wurde vom vorher verifizierten Tag `97c7ea04b5180862ea9862cc18b9c5bac994f794` auf `031c95c3e5af1101caf282eee463256285803495` retagged, nachdem der Frontend-Build-Job hing.
- `scripts\deploy-to-staging.ps1 -UseImageFilesystem -ImageTag 031c95c3e5af1101caf282eee463256285803495` deployte die Images auf Hetzner und entfernte die service-code Hot-Mounts.
- Remote `.env` zeigt `IMAGE_TAG=031c95c3e5af1101caf282eee463256285803495`; die laufenden Service-Images tragen denselben SHA-Tag.
- `scripts\verify-current-immutable-staging-parity.ps1 -RequireVerified` und `scripts\verify-current-runtime-selector-truth.ps1 -RequireRemoteProof` sind gruen.
- Fortschritt: `overall=72`, `phase_5=74`, `frontend=99`; kein Production-Rollout, keine Production-Tag-Promotion, kein Live-Provider-Call und kein Live-MCP-Write.

**Vorheriger Abschluss — Phase 5 Active Runtime Selector Truth** — der aktive RC1 wurde ehrlich an den damaligen Hosted-Selector gebunden:

- `docs/release-artifacts/prod-candidate-2026-05-11-rc1.md` fuehrt jetzt `hosted_selector_observed=IMAGE_TAG=staging`, `frontend_runtime_image_observed=cloud-superbrain-frontend:source-staging` und `immutable_staging_parity_status=blocked_after_frontend_source_build`
- `docs/release-artifacts/prod-candidate-2026-05-11-rc1-runtime-selector-truth.md` dokumentiert die aktuelle Runtime-Truth ohne Production- oder Immutable-Parity-Claim
- `scripts\verify-current-runtime-selector-truth.ps1` prueft aktiven Candidate, Proof-Artefakt, Hosted-Root, Hosted-Progress und optional den SSH-Beweis fuer `.env`, Frontend-Image und `pull_policy: never`
- `scripts\verify-current-immutable-staging-parity.ps1` akzeptiert diese Lage nur als `blocked`; echte Paritaet verlangt weiter `-RequireVerified`
- Fortschritt: `overall=71`, `phase_5=69`, `frontend=99`; kein Production-Rollout, kein GHCR-Push, keine immutable Candidate-Paritaet

**Vorheriger Abschluss — Phase 5 Frontend Source Build Path** — Hetzner ist jetzt ohne GHCR-Frontend-Push auf die aktuelle Frontend-UI nachgezogen:

- `scripts/deploy-to-staging.ps1 -FrontendSourceBuild -ImageTag staging` kopiert nicht-geheime Frontend-Quellen nach `/app/apps/frontend`, legt `docker-compose.frontend-source.yml` an, baut `cloud-superbrain-frontend:source-staging` und erzwingt `pull_policy: never`
- der erste falsche Versuch mit `staging-src-dba8cb012e8a` ist fail-closed in den Restore gelaufen; danach wurde korrekt mit Backend-Selector `IMAGE_TAG=staging` deployed
- gehosteter Root zeigt jetzt `Live Agent Control` und `Runtime Guard`; `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io` ist gruen
- `scripts\verify-phase5-frontend-source-build-path.ps1` bindet Artefakt, PlanOnly-Guards, Hosted-Root, Hosted-Progress und Remote-Compose-Beweis zusammen
- Fortschritt: `overall=71`, `phase_5=68`, `frontend=99`; kein Production-Rollout, kein GHCR-Push, keine immutable Candidate-Paritaet

**Vorheriger Abschluss — Phase 5 Active Candidate Gate Rerun** — der aktive `prod-candidate-2026-05-11-rc1` ist jetzt mit einem eigenen Gate-Rerun-Proof gegen die reale Hosted-Surface und die aktuelle Vercel-/Git-Bindung nachgezogen:

- `docs/release-artifacts/prod-candidate-2026-05-11-rc1-active-candidate-gate-rerun.md` bindet `current-release-candidate.json`, den aktiven Candidate, `https://188-34-191-140.sslip.io`, Vercel Git Link, Project Git Readiness und das Active-Release-Candidate-Bundle zusammen
- `scripts/verify-phase5-active-candidate-gate-rerun.ps1` prueft den Proof, parst das JSON aus `scripts\verify-active-release-candidate-bundle.ps1 -ReportOnly -JsonOnly` und ruft danach `scripts\verify-current-release-candidate.ps1` erneut auf
- die Proof-Kette bestaetigt `bundle_status=passed`, `bundle_gate_count=3`, `active_release_id=prod-candidate-2026-05-11-rc1`, `production_rollout_claimed=false` und fail-closed Policy-Flags fuer Produktion, Rollout und Secrets
- dies ist nur ein aktiver Release-Candidate-Gate-Rerun; kein Production-Rollout, kein Production-Deploy, kein Live-Provider-Call und keine Secret-Offenlegung
- Fortschritt bleibt repo-ehrlich unveraendert: `overall=70`, `phase_5=67`

**Vorheriger Abschluss — Phase 5 Integration Smoke Plan Rerun** — der aktuelle `RC1`-Truth ist jetzt nochmals gegen den gehosteten Integration-/Smoke-Pfad auf `overall=70`, `phase_5=67` nachgezogen:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-smoke-plan-rerun.md` dokumentiert einen frischen candidate-scoped Hosted-Smoke-Lauf gegen Root, API-, MCP- und LLM-Health, Project Progress, Integrity, Completion, External Gates, External-Gates-Mirror und Deployment-Preflight
- `scripts/verify-phase5-integration-smoke-plan-rerun.ps1` bindet denselben Proof an die aktuelle Manifest-Truth, den aktiven Candidate und die reale Hosted-Surface auf `https://188-34-191-140.sslip.io`
- der Rerun fuehrt weiter `IMAGE_TAG=staging` als aktuellen Selector und `IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` als immutable Rollback-Selector
- Hosted Truth bleibt nach Hetzner-Sync deckungsgleich: `overall=70`, `phase4=100`, `phase5=67`, `integrity=verified`
- dies ist ein weiterer Release-Readiness-/Smoke-Rerun-Batch, kein Rollout-Claim und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Executed Rollback + Post-Rollback Requalification + Release Readiness Rerun** — der aktuelle `RC1`-Truth ist jetzt nochmals gegen den Rollback-Lane- und Release-Readiness-Pfad auf `overall=70`, `phase_5=66` nachgezogen:

- `.phase1-artifacts/phase5-executed-rollback-rerun-20260507.md` bindet den bereits ausgefuehrten immutable Rollback-Pfad erneut an den heutigen Truth `overall=70`, `phase_5=66`, bestaetigt `IMAGE_TAG=staging` als wiederhergestellten Hosted-Selector und prueft die vier hosted Health-Endpunkte erneut
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification-rerun.md` bestaetigt denselben Hosted-Selector, dieselbe aktuelle Progress-/Integrity-Truth, fail-closed `completion=false` und weiter `external_gates=verified`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-release-readiness-rerun.md` zieht den aktiven Candidate, die Runbooks, die Hosted-Truth und die aktive Browser-Evidence nochmals in einen frischen Candidate-scoped Release-Readiness-Rerun zusammen
- `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md`, `.phase1-artifacts/phase5-rollback-readiness-20260505.md` und `.phase1-artifacts/phase5-release-baseline-refresh-20260507.md` sind im selben Batch vom alten Truth auf den aktuellen Stand repariert
- Hosted Truth bleibt nach Hetzner-Sync deckungsgleich: `overall=70`, `phase4=100`, `phase5=66`, `integrity=verified`
- dies ist ein weiterer Release-Readiness-/Truth-Repair-Batch, kein Rollout-Claim und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Final Browser E2E + Full Verifier Sweep + Truth Mirror Rebaseline** — der aktuelle `RC1`-Truth ist jetzt auf `overall=70`, `phase_5=63` sauber geschlossen:

- `.phase1-artifacts/phase5-final-browser-e2e-recheck-20260507.md` belegt einen frischen lokalen und gehosteten AI-Browser-Lauf mit sichtbaren Markern `Cloud Superbrain`, `Project Progress`, `External Gates`, `Phase 5 - Release Readiness`, `Progress Integrity`, `Error Response Contract` und `System Unavailable Fallback`
- `.phase1-artifacts/phase5-full-verifier-sweep-20260507.md` belegt den kompletten grünen Sweep aus `py -3 scripts\verify_project_progress_manifest.py`, dem vollen `verify-phase5*.ps1`-Lauf, `verify-phase1.ps1` und `gitleaks`
- `.phase1-artifacts/phase5-truth-mirror-rebaseline-20260507.md` belegt den synchronen Truth-Mirror-Zustand fuer `docs/project-progress.manifest.json`, `docs/verification-register.md`, `PROJECT_STATE.md`, `AI_HANDOFF.md` und den aktiven Candidate
- Hosted Truth ist nach Hetzner-Sync wieder deckungsgleich: `overall=70`, `phase4=100`, `phase5=63`, `integrity=verified`
- dies ist ein Verifier-/Mirror-Abschlussbatch, kein Rollout-Claim und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Browser Evidence Reactivation** — die aktuelle Browser-Evidence-Kette fuer `RC1` ist wieder live und verifiziert:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` ist wieder `verified` statt `superseded`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md` ist wieder `verified` statt `superseded`
- neuer Reaktivierungsbeleg: `.phase1-artifacts/phase5-browser-evidence-reactivation-20260507.md`
- `scripts/verify-phase5-browser-proof.ps1` und `scripts/verify-phase5-post-rollback-browser-revalidation.ps1` pruefen jetzt Live-HTML-Marker plus Candidate-Links statt den alten fail-closed Blockerzustand
- `scripts/verify-phase5-candidate.ps1` verlangt die aktive Browser-Evidence-Kette wieder
- der Candidate fuehrt wieder aktuelle Browser-Felder statt der alten Blocker-Notiz

**Vorheriger Abschluss — Phase 5 Full Verifier Rebaseline Sweep** — die komplette `verify-phase5*.ps1`-Kette ist gegen den damaligen fail-closed Candidate-Truth `overall=69`, `phase_5=57` neu ausgerichtet und einmal voll gruen durchgelaufen:

- `verify-phase5-auth-gate-recheck.ps1`, `verify-phase5-budget-review.ps1`, `verify-phase5-checklist-conformance.ps1`, `verify-phase5-integration-plan-rebaseline.ps1`, `verify-phase5-open-questions-acceptance.ps1`, `verify-phase5-observability-recheck.ps1`, `verify-phase5-risk-review-recheck.ps1`, `verify-phase5-runbook-applicability.ps1` und `verify-phase5-smoke-recheck.ps1` lesen den erwarteten Hosted-Truth jetzt manifest-dynamisch statt aus alten Pins `65/66/67`
- `verify-phase5-executed-smoke.ps1`, `verify-phase5-handoff-packet.ps1`, `verify-phase5-memory-recovery-drill.ps1`, `verify-phase5-post-handoff-stability-watch.ps1`, `verify-phase5-post-phase4-rebaseline.ps1`, `verify-phase5-post-rollback-stability-watch.ps1`, `verify-phase5-promotion-gate-refusal.ps1`, `verify-phase5-provider-failover-drill.ps1` und `verify-phase5-secret-rotation-drill.ps1` sind ebenfalls auf denselben damaligen Truth gezogen
- die zugehoerigen RC1-Artefakte in `docs/release-artifacts/` und `.phase1-artifacts/` tragen seitdem konsistent dieselbe Hosted-Wahrheit statt historischer Zwischenstaende
- Vollsweep belegt: **alle** `verify-phase5*.ps1` liefen gruen, `verify-phase1.ps1` blieb gruen, `verify_project_progress_manifest.py` blieb gruen, `gitleaks` fand keine Leaks
- dieser Batch schloss Drift und Verifier-Repair, ohne einen Rollout-Claim oder Production-Deploy einzufuehren

**Vorheriger Abschluss — Phase 5 Browser Claims Fail-Closed Repair** — die aktiven Candidate-Browser-Claims sind aus dem aktuellen Truth entfernt, weil frische Live-Evidence im In-App-Browser derzeit extern blockiert ist:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` und `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md` sind jetzt explizit als historische, superseded Artefakte markiert
- `scripts/verify-phase5-browser-proof.ps1` und `scripts/verify-phase5-post-rollback-browser-revalidation.ps1` pruefen jetzt fail-closed den aktuellen Blockerzustand statt einen nicht reproduzierbaren Live-Browser-Claim weiter als aktuell zu behandeln
- `scripts/verify-phase5-candidate.ps1` und `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehren die beiden Browser-Proofs nicht mehr als aktuelle Candidate-Evidence; stattdessen ist der Browser-Rerun-Blocker explizit dokumentiert
- die harte Blocker-Evidence lautet:
  - `node_repl` + `iab`: `failed to start codex app-server ... (os error 3)`
  - `chrome_devtools`: `Target.setDiscoverTargets): Target closed`
  - Playwright: Launcher `exit code 13`
- Fortschritt bleibt repo-ehrlich: Gesamt bleibt `69%`, Phase 5 sinkt auf `57%`; das beseitigt zwei unbelegte aktuelle Claims und fuehrt keinen Rollout- oder Production-Deploy-Claim ein

**Vorheriger Abschluss — Phase 5 Post-Rollback Provenance + Incident + Rollback Drill Rerun** — drei weitere zentrale Release-Readiness-Beweise sind jetzt auf die aktuelle Hosted-Truth und den aktuellen immutable Candidate-SHA gezogen:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md` bindet den Candidate jetzt an `overall=69`, `phase_5=59`, den aktuellen Workflow-Run `25392582005`, den immutable GHCR-SHA `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` und weiter `owner_decision=no-release`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md` prueft Deployment-Preflight jetzt korrekt ueber die Runtime-Surface `GET /api/v1/clouds/deployment-preflight` und nennt denselben aktuellen immutable Rollback-SHA statt des alten `5464...`-Pfads
- `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md` und `scripts/verify-phase5-rollback-drill.ps1` sind jetzt auf Workflow `25392582005` und SHA `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` rebasiert; `scripts/verify-phase5-candidate.ps1` leitet den erwarteten Rollback-Drill-SHA jetzt direkt aus dem Candidate-Artefakt ab statt aus einem alten Pin
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md` und `scripts/verify-phase5-integration-plan.ps1` sind im selben Zug vom alten Contract-/Rollback-Drift befreit
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-provenance-revalidation.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-incident-drill.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-integration-plan.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `69%`, Phase 5 steigt auf `59%`; dies schliesst drei weitere Release-Readiness-Proofs, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Risk + Observability + Smoke Rerun** — drei weitere Legacy-Beweise sind jetzt auf die aktuelle Hosted-Truth gehoben und erneut verifiziert:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md` bindet den Candidate jetzt an `overall=69`, `phase_5=56`, `integrity=verified`, fail-closed `completion`, `external_gates=verified` und weiter `owner_decision=no-release`
- `scripts/verify-phase5-risk-review.ps1` liest den erwarteten Hosted-Truth jetzt manifest-dynamisch statt aus hart verdrahtetem Altstand `53/18`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md` bindet Health, Progress, Integrity, Metrics, Audit, Escalations und External Gates jetzt an denselben aktuellen Candidate-Truth
- `scripts/verify-phase5-observability-review.ps1` liest den erwarteten Hosted-Truth jetzt manifest-dynamisch statt aus hart verdrahtetem Altstand `52/11`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md` bindet den Legacy-Smoke-Proof jetzt an `overall=69`, `phase_4=100`, `phase_5=56`; der Verifier prueft Deployment-Preflight dabei korrekt ueber die Runtime-Surface statt ueber den Contract-Endpunkt
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-risk-review.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-observability-review.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-smoke.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `69%`, Phase 5 steigt auf `56%`; dies sind drei weitere Release-Readiness-Proofs, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Candidate Checklist Conformance Review** — der aktuelle Production-Candidate ist jetzt nochmals direkt an die aktive Release-Checklist und die aktuelle Hosted-Truth gebunden:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-checklist-conformance.md` dokumentiert die aktuelle Candidate-Konformitaet gegen die vier Pflichtsektionen `Code Readiness`, `Infrastructure Readiness`, `Observability Readiness` und `Operations Readiness`
- `scripts/verify-phase5-checklist-conformance.ps1` prueft Artefaktstruktur, Candidate-Linking, die verpflichtenden `[x]`-Checklist-Items, Candidate-Pflichtfelder, Hosted `GET /api/v1/health`, Hosted `GET /api/v1/project/progress`, Hosted `GET /api/v1/project/progress/integrity`, Hosted `GET /api/v1/project/progress/completion` und Hosted `GET /api/v1/external-gates`
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-checklist-conformance.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `65%`, Phase 5 steigt auf `31%`; dies ist ein neuer Release-Readiness-/Checklist-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Candidate Runbook Applicability Review** — der aktuelle Production-Candidate ist jetzt nochmals direkt an die aktiven Operations-Runbooks und die aktuelle Hosted-Truth gebunden:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-runbook-applicability.md` dokumentiert die aktuelle Anwendbarkeit von `rollback-deploy`, `incident-response`, `secret-rotation`, `provider-failover` und `memory-recovery` gegen den laufenden Candidate-Stand
- `scripts/verify-phase5-runbook-applicability.ps1` prueft Artefaktstruktur, Candidate-Linking, verpflichtende Runbook-Sektionen, Hosted `GET /api/v1/health`, Hosted `GET /api/v1/project/progress`, Hosted `GET /api/v1/project/progress/integrity`, Hosted `GET /api/v1/project/progress/completion` und Hosted `GET /api/v1/external-gates`
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-runbook-applicability.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `65%`, Phase 5 steigt auf `30%`; dies ist ein neuer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 5 Post-Phase4 Candidate Rebaseline** — der aktuelle Production-Candidate ist jetzt nochmals direkt gegen den kompletten gehosteten `P4=100`-Truth revalidiert:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-phase4-rebaseline.md` bindet den Candidate an die aktuelle hosted Runtime-Truth mit `overall=65`, `phase_4=100`, `phase_5=29`, `integrity=verified`, `external_gates=verified`, weiter fail-closed `completion_can_set_all_to_100=false` und unveraendertem `owner_decision=no-release`
- `scripts/verify-phase5-post-phase4-rebaseline.ps1` prueft Artefaktstruktur, Candidate-Linking, Hosted `GET /api/v1/health`, Hosted `GET /api/v1/project/progress`, Hosted `GET /api/v1/project/progress/integrity`, Hosted `GET /api/v1/project/progress/completion` und Hosted `GET /api/v1/external-gates`
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-phase4-rebaseline.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `65%`, Phase 5 steigt auf `29%`; dies ist ein neuer Release-Readiness-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted System Fallback Contract Runtime Parity** — der letzte offene Public-Runtime-Slice ist jetzt gehostet direkt an echte Health- und Frontend-Projektion gebunden:

- `scripts/verify-phase4-system-fallback-contract-runtime-hosted.ps1` bindet den sichtbaren Fallback-Contract an die echte hosted Frontend-Surface `GET /` und die echte hosted Health-Surface `GET /api/v1/health`
- der Proof bestaetigt `contract_version=system-unavailable-fallback-v1`, `ui_state=System Unavailable`, `health_endpoint=GET /api/v1/health`, sichtbare `no_fake_healthy_claim`-/`failed_service_visible`-Policies, sichtbare Retry-Action und zugleich eine gesunde aktuelle hosted Runtime mit allen erforderlichen Services auf `healthy`
- `.phase1-artifacts/phase4-system-fallback-contract-runtime-hosted-proof-20260507.md` dokumentiert den erfolgreichen Hosted-Proof
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-system-fallback-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `65%`, Phase 4 steigt auf `100%`; dies schliesst Phase 4 fachlich und bleibt weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Memory Embedding Consistency Parity** — die bestehende Embedding-Consistency-Surface ist jetzt nicht mehr nur lokal/statisch sichtbar, sondern gehostet gegen echte Runtime- und Search-Projektion gebunden:

- `scripts/verify-phase4-memory-embedding-consistency-hosted.ps1` prueft `GET /api/v1/memory/embedding-consistency/contract` gegen die echte Hosted-Runtime auf Hetzner
- der Proof bestaetigt `contract_version=memory-embedding-consistency-v1`, `status=verified`, Schema-Paritaet fuer `memory_entries.content_embedding vector(1536)`, `embedding_model_version`, `metadata` und `status`, null Schema-Drift, `search_mode=lexical_fallback`, `generation_mode=disabled_until_live_embedding_gate` und `live_embedding_provider_calls=false`
- derselbe Proof bindet den Contract an eine echte Hosted-Search-Projektion: `GET /api/v1/memory/search/contract`, frischer `POST /api/v1/prompt` und anschliessendes `GET /api/v1/memory/search` unter derselben fail-closed lexical-fallback-Policy
- `.phase1-artifacts/phase4-memory-embedding-consistency-hosted-proof-20260507.md` dokumentiert den erfolgreichen Hosted-Proof
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-memory-embedding-consistency-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `62%`, Phase 4 steigt auf `80%`, Memory auf `72%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 4 Hosted Layer Interfaces + Phase 2 Runtime Contract Parity** — zwei weitere oeffentliche Runtime-Surfaces sind jetzt gehostet direkt an echte Hetzner-Runtime-Projektion gebunden:

- `scripts/verify-phase4-layer-interfaces-contract-runtime-hosted.ps1` bindet `GET /api/v1/layer-interfaces/contract` gehostet an die reale Verfuegbarkeit der referenzierten Runtime-Surfaces `prompt`, `phase2/runtime`, `tasks/policy`, `mcp health`, `memory/search` und `metrics`
- `scripts/verify-phase4-phase2-runtime-contract-hosted.ps1` bindet `GET /api/v1/phase2/runtime/contract` gehostet an `GET /api/v1/phase2/runtime/runs` und prueft echte Hosted-Run-Status-Projektion inklusive `engine=langgraph`, `checkpointing=postgres`, `live_provider_calls=false`, `live_mcp_writes=false`, `production_deploy=false`, `role_summary_count>=4` und `agent_result_aggregation_complete`
- `.phase1-artifacts/phase4-layer-interfaces-contract-runtime-hosted-proof-20260507.md` und `.phase1-artifacts/phase4-phase2-runtime-contract-hosted-proof-20260507.md` dokumentieren die erfolgreichen Hosted-Proofs
- beim Layer-Interfaces-Slice waren die einzigen Fehler reine Verifier-Drifts auf exakte Contract-Namen:
  - `task-policy-contract-v1`
  - `memory-search-runtime-v1`
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-layer-interfaces-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-phase2-runtime-contract-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `62%`, Phase 4 steigt auf `79%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Cloud Render Offload + Cloud Deployment Preflight Runtime Surfaces** — die bisherigen Cloud-Contracts sind jetzt auch als eigene gehostete Runtime-Surfaces fail-closed an die echte Hetzner-Runtime gebunden:

- `services/agent-api/app/main.py` exponiert jetzt `GET /api/v1/clouds/render-offload` plus `GET /api/v1/clouds/render-offload/contract` sowie `GET /api/v1/clouds/deployment-preflight` plus `GET /api/v1/clouds/deployment-preflight/contract`
- der sichtbare Render-Offload-Contract deklariert `contract_version=cloud-render-offload-surface-v1`, den Runtime-Endpunkt `GET /api/v1/clouds/render-offload`, die erforderlichen Gate-/Workload-Felder und die unterstuetzten Statuswerte `cloud_runtime_ready|action_required`
- der sichtbare Deployment-Preflight-Contract deklariert `contract_version=cloud-deployment-preflight-surface-v1`, den Runtime-Endpunkt `GET /api/v1/clouds/deployment-preflight`, die erforderlichen Gate-Felder und die unterstuetzten Statuswerte `verified|ready_for_external_execution|action_required`
- `scripts/verify-phase4-cloud-render-offload-runtime-hosted.ps1` und `scripts/verify-phase4-cloud-deployment-preflight-runtime-hosted.ps1` binden die sichtbaren Contracts gehostet an die echte Runtime auf Hetzner
- `.phase1-artifacts/phase4-cloud-render-offload-runtime-hosted-proof-20260507.md` und `.phase1-artifacts/phase4-cloud-deployment-preflight-runtime-hosted-proof-20260507.md` dokumentieren die erfolgreichen Hosted-Proofs
- beim Render-Offload-Slice war der einzige echte Fehler ein zu strenger Feldcheck im Verifier: `control_plane.blocker` ist absichtlich `null`, deshalb prueft der Verifier jetzt Feld-Praesenz statt Nicht-Null
- Verifiziert mit `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-cloud-render-offload-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-cloud-deployment-preflight-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt geht auf `62%`, Phase 4 steigt auf `77%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Cloud Inventory + Cloud Layers Contract Runtime Parity** — die oeffentlichen `clouds`- und `clouds/layers`-Surfaces haben jetzt je einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` exponiert jetzt `GET /api/v1/clouds/contract` ueber `cloud_inventory_contract_payload()` und `GET /api/v1/clouds/layers/contract` ueber `cloud_layers_contract_payload()`
- der sichtbare Inventory-Contract deklariert `contract_version=cloud-provider-surface-v1`, die erforderlichen Top-Level-Felder, die erforderlichen Provider-Felder, die Provider-ID-Menge und die Layer-Mapping-ID-Menge
- der sichtbare Layers-Contract deklariert `contract_version=cloud-layer-surface-v1`, die erforderlichen Top-Level-Felder, die erforderlichen Layer-Felder, die Layer-ID-Menge und die unterstuetzten Layer-Statuswerte
- `scripts/verify-phase4-cloud-inventory-contract-runtime-hosted.ps1` und `scripts/verify-phase4-cloud-layers-contract-runtime-hosted.ps1` binden die sichtbaren Contracts gehostet an `GET /api/v1/clouds` und `GET /api/v1/clouds/layers` auf dem echten Hetzner-Stack
- `.phase1-artifacts/phase4-cloud-inventory-contract-runtime-hosted-proof-20260507.md` und `.phase1-artifacts/phase4-cloud-layers-contract-runtime-hosted-proof-20260507.md` dokumentieren die erfolgreichen Hosted-Proofs
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-cloud-inventory-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-cloud-layers-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `61%`, Phase 4 steigt auf `75%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted External Gates Contract Runtime Parity** — die oeffentliche External-Gates-Surface ist jetzt nicht mehr nur implizit ueber Gate-State-, Mirror- und Preflight-Beweise abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` exponiert jetzt `GET /api/v1/external-gates/contract` ueber `external_gates_surface_contract_payload()`
- der sichtbare Contract deklariert `contract_version=external-gates-surface-v1`, die erforderlichen Top-Level-Felder, die Pflicht-Gate-Felder sowie die erforderlichen Gate-ID- und Preflight-Gate-ID-Mengen
- `scripts/verify-phase4-external-gates-contract-runtime-hosted.ps1` bindet den sichtbaren Contract gehostet an `GET /api/v1/external-gates` auf dem echten Hetzner-Stack
- `.phase1-artifacts/phase4-external-gates-contract-runtime-hosted-proof-20260507.md` dokumentiert den erfolgreichen Hosted-Proof
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-external-gates-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `61%`, Phase 4 steigt auf `73%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Health Contract Runtime Parity** — die oeffentliche Health-Surface ist jetzt nicht mehr nur implizit ueber Fallback-, Budget- und External-Gate-Beweise abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` exponiert jetzt `GET /api/v1/health/contract` ueber `health_contract_payload()`
- der sichtbare Contract deklariert `contract_version=health-surface-v1`, die erforderlichen Top-Level-Felder, die Pflicht-Service-Keys, die eingebetteten Budget-/Infra-Budget-/External-Gate-Feldmengen und die unterstuetzten Statuswerte
- `scripts/verify-phase4-health-contract-runtime-hosted.ps1` bindet den sichtbaren Contract gehostet an `GET /api/v1/health` auf dem echten Hetzner-Stack
- `.phase1-artifacts/phase4-health-contract-runtime-hosted-proof-20260507.md` dokumentiert den erfolgreichen Hosted-Proof
- Verifiziert mit `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-health-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py` und `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `61%`, Phase 4 steigt auf `72%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Costs Contract Runtime Parity** — die oeffentliche Costs-Surface ist jetzt nicht mehr nur implizit ueber Budget-, Metrics- und Export-Beweise abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `costs_contract_payload()` plus `GET /api/v1/costs/contract` ein
- der neue sichtbare Costs-Contract deklariert:
  - `contract_version=costs-surface-v1`
  - die bindenden Runtime-Felder der Costs-Surface
  - die bindenden `breakdown[]`-Felder
  - die unterstuetzten Budget-Level `ok|warning|critical`
- `scripts/verify-phase4-costs-contract-runtime-hosted.ps1` prueft gehostet `GET /api/v1/costs/contract` und `GET /api/v1/costs` und bindet den sichtbaren Contract an die echte Hosted-Runtime
- der erste Verifier-Fehler lag nur im direkten Post-Recreate-Startfenster; nach Abschluss des Stack-Recreate lieferte die neue Hosted-Contract-Route `200` und der robuste Verifier lief gruen
- `.phase1-artifacts/phase4-costs-contract-runtime-hosted-proof-20260507.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-costs-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `61%`, Phase 4 steigt auf `71%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Budget Contracts Runtime Parity** — die oeffentlichen Budget-Surfaces sind jetzt nicht mehr nur implizit ueber Metrics-, Budget-Guard- und Infra-Budget-Beweise abgesichert, sondern haben eigene sichtbare Contracts, die gehostet gegen die echte Runtime verifiziert sind:

- `services/agent-api/app/main.py` fuehrt jetzt `budget_contract_payload()` plus `GET /api/v1/budget/contract` und `infra_budget_contract_payload()` plus `GET /api/v1/infra/budget/contract` ein
- die neuen sichtbaren Budget-Contracts deklarieren:
  - `contract_version=budget-surface-v1`
  - `contract_version=infra-budget-surface-v1`
  - die bindenden Runtime-Felder fuer beide Budget-Surfaces
  - die unterstuetzten Budget-Level `ok|warning|critical`
  - fuer Infra zusaetzlich die erlaubten Sources `projection|hetzner_api_readonly` und die bindenden `items[]`-Felder
- `scripts/verify-phase4-budget-contracts-runtime-hosted.ps1` prueft gehostet `GET /api/v1/budget/contract`, `GET /api/v1/budget`, `GET /api/v1/infra/budget/contract` und `GET /api/v1/infra/budget` und bindet beide sichtbaren Contracts an die echte Hosted-Runtime
- der erste 404 auf `/api/v1/budget/contract` lag nur im direkten Post-Recreate-Startfenster; nach Abschluss des Stack-Recreate liefen beide neuen Hosted-Contract-Routen ohne Codeaenderung gruen
- `.phase1-artifacts/phase4-budget-contracts-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-budget-contracts-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt geht auf `61%`, Phase 4 steigt auf `70%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 4 Hosted MCP Audit Feed Contract Runtime Parity** — der oeffentliche MCP-Audit-Feed ist jetzt nicht mehr nur implizit ueber allgemeine Audit- oder MCP-Safe-Envelope-Proofs abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `mcp_audit_feed_contract_payload()` plus `GET /api/v1/audit/mcp/contract` ein
- der neue sichtbare MCP-Audit-Feed-Contract deklariert:
  - `contract_version=mcp-audit-feed-v1`
  - die bindenden Event-Top-Level-Felder
  - die bindenden Detail-Felder eines `mcp_tool_executed`-Runtime-Events
  - die unterstuetzten Status `success|blocked|timeout|degraded`
- `scripts/verify-phase4-mcp-audit-feed-contract-runtime-hosted.ps1` prueft gehostet `GET /api/v1/audit/mcp/contract`, erzeugt ein echtes Hosted-`mcp_tool_executed`-Event via `POST /internal/audit/mcp-tool-events` und bindet den Contract an `GET /api/v1/audit/mcp`
- derselbe Schritt haertet den Deploy-Pfad in `scripts/deploy-to-staging.ps1`, indem die Remote-Hot-Mount-Verzeichnisse vor dem rekursiven Copy gezielt zurueckgesetzt werden; damit wird der echte Host-Drift `app/app` beseitigt, der neue Runtime-Routen vorher shadowen konnte
- `.phase1-artifacts/phase4-mcp-audit-feed-contract-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-mcp-audit-feed-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `60%`, Phase 4 steigt auf `68%`, MCP Gateway steigt auf `55%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 4 Hosted Session History Contract Runtime Parity** — `sessions/{session_id}/history` ist jetzt nicht mehr nur implizit ueber Session-Stream- und Failure-History-Proofs abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `session_history_contract_payload()` plus `GET /api/v1/sessions/history/contract` ein
- der neue sichtbare Session-History-Contract deklariert:
  - `contract_version=session-history-v1`
  - die top-level Sektionen des History-Response
  - die bindenden Session-/Task-/Audit-Event-Felder
  - die unterstuetzten Status sowie Request-/Trace-/Correlation-/Audit-Feed-Sichtbarkeit
- `scripts/verify-phase4-session-history-contract-runtime-hosted.ps1` erstellt auf dem echten Hetzner-Staging eine echte Prompt-Session via `POST /api/v1/prompt`, wartet auf Abschluss und prueft danach `GET /api/v1/sessions/history/contract`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/sessions/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/agent-activity/recent` und `GET /api/v1/audit/recent`
- `.phase1-artifacts/phase4-session-history-contract-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Session-History-Contract-zu-Runtime-Paritaet
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-history-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `59%`, Phase 4 steigt auf `57%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Recent Sessions Contract Runtime Parity** — `sessions/recent` ist jetzt nicht mehr nur ueber Session-Stream-/Failure-/Cross-Surface-Beweise indirekt abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `recent_sessions_contract_payload()` plus `GET /api/v1/sessions/recent/contract` ein
- der neue sichtbare Recent-Sessions-Contract deklariert:
  - `contract_version=recent-sessions-feed-v1`
  - die top-level Runtime-Felder von `GET /api/v1/sessions/recent`
  - die unterstuetzten Session-/Failure-Zustaende
  - die bindenden Request-/Trace-/Correlation-/Audit-Feed-Felder
- `scripts/verify-phase4-recent-sessions-contract-runtime-hosted.ps1` erstellt auf dem echten Hetzner-Staging eine echte Prompt-Session via `POST /api/v1/prompt`, wartet auf Abschluss und prueft danach `GET /api/v1/sessions/recent/contract`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/tasks/recent`, `GET /api/v1/agent-activity/recent` und `GET /api/v1/audit/recent`
- `.phase1-artifacts/phase4-recent-sessions-contract-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Recent-Sessions-Contract-zu-Runtime-Paritaet
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-recent-sessions-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `59%`, Phase 4 steigt auf `56%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Recent Tasks Contract Runtime Parity** — `tasks/recent` ist jetzt nicht mehr nur ueber Worker-/Cross-Surface-Beweise indirekt abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `recent_tasks_contract_payload()` plus `GET /api/v1/tasks/recent/contract` ein
- der neue sichtbare Recent-Tasks-Contract deklariert:
  - `contract_version=recent-tasks-feed-v1`
  - die top-level Runtime-Felder von `GET /api/v1/tasks/recent`
  - Queue-Felder und unterstuetzte Status
  - die bindenden Request-/Trace-/Correlation-/Audit-Feed-Felder
- zusaetzlich wurde eine echte Runtime-Luecke korrigiert:
  - `POST /api/v1/internal/tasks` schreibt jetzt Trace-/Request-/Correlation-Metadaten in `agent_sessions`
  - `GET /api/v1/tasks/recent` faellt jetzt auch auf Session-Projektion zurueck, wenn frische Audit-Korrelation fuer den Task selbst noch nicht vorliegt
- `scripts/verify-phase4-recent-tasks-contract-runtime-hosted.ps1` erstellt auf dem echten Hetzner-Staging einen echten `planner`-Task via `POST /api/v1/internal/tasks`, wartet auf Abschluss und prueft danach `GET /api/v1/tasks/recent/contract`, `GET /api/v1/tasks/recent`, `GET /api/v1/internal/tasks/{task_id}` und `GET /api/v1/audit/recent`
- `.phase1-artifacts/phase4-recent-tasks-contract-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Recent-Tasks-Contract-zu-Runtime-Paritaet
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-recent-tasks-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `58%`, Phase 4 steigt auf `55%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Escalation Contract Runtime Parity** — die Escalation-Surface ist jetzt nicht mehr nur ueber Request-/Audit-Paritaet indirekt abgesichert, sondern hat einen eigenen sichtbaren Contract, der gehostet gegen die echte Runtime verifiziert ist:

- `services/agent-api/app/main.py` fuehrt jetzt `escalation_contract_payload()` plus `GET /api/v1/escalations/contract` ein
- der neue sichtbare Escalation-Contract deklariert die top-level Runtime-Felder von `GET /api/v1/escalations/recent`, `supported_statuses=["escalated"]` und die bindenden Request-/Trace-/Correlation-/Audit-Feed-Felder
- `scripts/verify-phase4-escalation-contract-runtime-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad mit gemeinsamer `request_id`, `trace_id`, `correlation_evidence_ref=request_id_audit_correlation` und `audit_feed_evidence_ref=request_id_audit_feed_visible`
- derselbe Hosted-Proof prueft danach `GET /api/v1/escalations/contract`, `GET /api/v1/escalations/recent` und `GET /api/v1/audit/recent` und bestaetigt, dass Contract und Runtime fuer dieselbe Escalation-Surface auf denselben top-level Feldern und denselben Request-/Trace-Beweisen bleiben
- `.phase1-artifacts/phase4-escalation-contract-runtime-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Escalation-Contract-zu-Runtime-Paritaet
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-escalation-contract-runtime-hosted.ps1 -BaseUrl https://188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `58%`, Phase 4 steigt auf `54%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Audit Feed Evidence Cross-Surface Parity** — derselbe eskalierte Worker-Pfad bleibt jetzt gehostet nicht nur auf Task-, Session-, Activity-, Audit-, Agent-Status- und Escalation-Surfaces sichtbar, sondern traegt ueber alle diese Public-Surfaces auch dieselbe top-level `audit_feed_evidence_ref`:

- `scripts/verify-phase4-audit-feed-evidence-cross-surface-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad mit gemeinsamer `trace_id`, gemeinsamer `request_id`, `correlation_evidence_ref=request_id_audit_correlation` und `audit_feed_evidence_ref=request_id_audit_feed_visible`, prueft danach `GET /api/v1/escalations/recent`, `GET /api/v1/agents/status`, `GET /api/v1/agent-activity/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history` und `GET /api/v1/audit/recent`
- derselbe Hosted-Proof bestaetigt fuer den eskalierten Pfad identische top-level `request_id`-, `trace_id`-, `correlation_evidence_ref`- und `audit_feed_evidence_ref`-Werte ueber alle sieben Public Surfaces
- `.phase1-artifacts/phase4-audit-feed-evidence-cross-surface-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Audit-Feed-Evidence-Cross-Surface-Paritaet
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-audit-feed-evidence-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `58%`, Phase 4 steigt auf `49%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Escalation Request Correlation Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur auf Task-, Session-, Activity-, Audit- und Agent-Status-Surfaces, sondern auch auf `GET /api/v1/escalations/recent` mit identischer top-level Request-/Trace-Korrelation sichtbar:

- `services/agent-api/app/main.py` projiziert Korrelation jetzt auch auf die Escalation-Surface und liefert `request_id`, `trace_id`, `correlation_evidence_ref` und `audit_feed_evidence_ref` direkt auf `GET /api/v1/escalations/recent`
- `scripts/verify-phase4-escalation-request-correlation-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad mit gemeinsamer `trace_id`, gemeinsamer `request_id` und `correlation_evidence_ref=request_id_audit_correlation`, prueft danach `GET /api/v1/escalations/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history` und `GET /api/v1/audit/recent`
- derselbe Hosted-Proof bestaetigt fuer den eskalierten Pfad identische top-level `trace_id`-, `request_id`- und `correlation_evidence_ref`-Werte jetzt auch auf der Escalation-Surface
- `.phase1-artifacts/phase4-escalation-request-correlation-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Escalation-Request-Correlation-Paritaet
- Verifiziert: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-escalation-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `48%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Status Request Correlation Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur auf Task-, Session-, Activity- und Audit-Surfaces, sondern auch auf `GET /api/v1/agents/status` mit identischer top-level Request-/Trace-Korrelation sichtbar:

- `services/agent-api/app/main.py` projiziert Korrelation jetzt auch auf die Agent-Status-Surface und liefert `latest_trace_id`, `latest_request_id`, `latest_correlation_evidence_ref` und `latest_audit_feed_evidence_ref` direkt auf `GET /api/v1/agents/status`
- `scripts/verify-phase4-agent-status-request-correlation-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad mit gemeinsamer `trace_id`, gemeinsamer `request_id` und `correlation_evidence_ref=request_id_audit_correlation`, prueft danach `GET /api/v1/agents/status`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history` und `GET /api/v1/audit/recent`
- derselbe Hosted-Proof bestaetigt fuer beide negativen Pfade identische top-level `trace_id`-, `request_id`- und `correlation_evidence_ref`-Werte jetzt auch auf der Agent-Status-Surface
- `.phase1-artifacts/phase4-agent-status-request-correlation-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Agent-Status-Request-Correlation-Paritaet
- Verifiziert: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-status-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `47%`, Agent Pool steigt auf `66%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Request Correlation Cross-Surface Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur in Agent Activity und Audit sichtbar, sondern mit identischer `trace_id`-, `request_id`- und `correlation_evidence_ref`-Korrelation top-level quer ueber die oeffentlichen Task-, Session- und History-Surfaces bestaetigt:

- `services/agent-api/app/main.py` projiziert Korrelation jetzt direkt aus dem Audit Feed auf `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history` und zusaetzlich top-level auf `GET /api/v1/agent-activity/recent`, statt `request_id`/`trace_id` nur indirekt in nested audit details sichtbar zu lassen
- `scripts/verify-phase4-request-correlation-cross-surface-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad mit gemeinsamer `trace_id`, gemeinsamer `request_id` und `correlation_evidence_ref=request_id_audit_correlation`, prueft danach `GET /api/v1/agent-activity/recent?trace_id=...`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent`, `GET /api/v1/sessions/{session_id}/history` und `GET /api/v1/audit/recent`
- derselbe Hosted-Proof bestaetigt fuer beide negativen Pfade identische top-level `trace_id`-, `request_id`- und `correlation_evidence_ref`-Werte ueber alle fuenf Public Surfaces
- `.phase1-artifacts/phase4-request-correlation-cross-surface-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Cross-Surface-Request-Correlation-Paritaet
- Verifiziert: `py -3 -m py_compile services/agent-api/app/main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-request-correlation-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase1.ps1`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `46%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Activity Filter Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur sichtbar, sondern ueber die oeffentliche Agent-Activity-Surface auch reproduzierbar per `trace_id`, `agent_type`, `event_type` und `severity` isolierbar:

- `scripts/verify-phase4-agent-activity-filter-parity-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad mit gemeinsamer `trace_id`, prueft danach `GET /api/v1/agent-activity/recent?trace_id=...`, dann die beiden engeren Multi-Filter-Kombinationen fuer `coder/task_escalated/warning` und `tester/task_abandoned_after_queue_drain/warning`, und spiegelt die Ergebnisse gegen `GET /api/v1/audit/recent`
- derselbe Hosted-Proof bestaetigt, dass jede Multi-Filter-Kombination genau das erwartete Failure-Ereignis isoliert und dabei `task_id`, `trace_id` und Retry-Metadaten mit dem Audit Feed synchron bleiben
- `.phase1-artifacts/phase4-agent-activity-filter-parity-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer die Filter-Paritaet der oeffentlichen Agent-Activity-Surface
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-activity-filter-parity-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `45%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Trace + Request Correlation Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur als Failure-Surfaces sichtbar, sondern auch mit identischer `trace_id`- und `request_id`-Korrelation quer ueber Agent Activity, Audit Feed und Session-History-Audit belegt:

- `scripts/verify-phase4-trace-request-correlation-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad mit gemeinsamer `trace_id`, gemeinsamer `request_id` und expliziter `correlation_evidence_ref=request_id_audit_correlation`, prueft danach `GET /api/v1/agent-activity/recent?trace_id=...`, `GET /api/v1/audit/recent`, `GET /api/v1/sessions/{session_id}/history` und `GET /api/v1/request/contract`
- derselbe Hosted-Proof bestaetigt fuer beide negativen Pfade identische `trace_id`- und `request_id`-Werte zwischen Agent Activity, Audit Feed und Session-History sowie die sichtbaren Evidence-Refs `request_id_audit_correlation` und `request_id_audit_feed_visible`
- `.phase1-artifacts/phase4-trace-request-correlation-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Trace-/Request-Correlation-Paritaet
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-trace-request-correlation-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `44%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Failure Audit + Escalation Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur ueber Runtime-Surfaces, sondern auch quer ueber Audit Feed, Escalation Feed und Session-History-Audit feldgenau synchron bestaetigt:

- `scripts/verify-phase4-failure-audit-escalation-parity-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad und prueft danach `GET /api/v1/audit/recent`, `GET /api/v1/escalations/recent` und `GET /api/v1/sessions/{session_id}/history`
- dabei wurden zwei echte Verifier-Contractfehler bereinigt: die Feeds liefern `events` statt `entries`, und `escalations/recent` fuehrt `trace_id` nur in `details`; ausserdem wurde der Proof auf das echte Feed-Verhalten korrigiert, dass `escalations/recent` den eskalierten Pfad fuehrt, nicht den Queue-Drain-Abandon-Pfad
- `.phase1-artifacts/phase4-failure-audit-escalation-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Audit-/Escalation-Paritaet von `escalated` und Audit-/History-Paritaet von `abandoned_after_queue_drain`
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-failure-audit-escalation-parity-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `57%`, Phase 4 steigt auf `43%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Status Cross-Surface Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur ueber `agents/status` einzeln sichtbar, sondern auch quer ueber Agent Status, Recent Tasks, Recent Sessions und Session-History feldgenau synchron bestaetigt:

- `scripts/verify-phase4-agent-status-cross-surface-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad und prueft danach `GET /api/v1/agents/status`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent` und `GET /api/v1/sessions/{session_id}/history`
- derselbe Hosted-Proof bestaetigt ueber alle vier Public Surfaces dieselben `latest_task_id`-, `latest_status`-, Retry-, Fehler- und `current_session_id`-Fakten fuer die beiden negativen Worker-Endzustaende
- `.phase1-artifacts/phase4-agent-status-cross-surface-hosted-proof-20260506.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Cross-Surface-Paritaet von `escalated` und `abandoned_after_queue_drain` aus Sicht der Agent-Status-Surface
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-status-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `57%`, Phase 4 steigt auf `42%`, Agent Pool steigt auf `65%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Failure Cross-Surface Parity** — dieselben negativen Worker-Endzustaende sind jetzt gehostet nicht nur je Surface einzeln, sondern auch quer ueber Agent Activity, Recent Tasks, Recent Sessions und Session-History feldgenau synchron bestaetigt:

- `scripts/verify-phase4-failure-cross-surface-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Pfad und einen `abandoned_after_queue_drain`-`tester`-Pfad mit gemeinsamem `trace_id`, prueft danach `GET /api/v1/agent-activity/recent`, `GET /api/v1/tasks/recent`, `GET /api/v1/sessions/recent` und `GET /api/v1/sessions/{session_id}/history`, und bestaetigt dieselben `task_id`-, `task_status`-, Retry- und Fehlerfelder ueber alle vier oeffentlichen Surfaces
- der neue Verifier hatte zuerst einen echten Seed-Parser-Bug: der Remote-Seed lieferte zwei JSON-Zeilen und damit ein doppelt zusammengeklebtes `trace_id`; `scripts/verify-phase4-failure-cross-surface-hosted.ps1` parst jetzt nur noch die letzte JSON-Zeile und prueft danach sauber gegen die echte Hosted-Runtime
- `.phase1-artifacts/phase4-failure-cross-surface-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Cross-Surface-Paritaet von `escalated` und `abandoned_after_queue_drain`
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-failure-cross-surface-hosted.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `56%`, Phase 4 steigt auf `41%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Activity Contract Parity** — die oeffentliche Agent-Activity-Surface benennt dieselben Failure-Felder jetzt auch im sichtbaren Contract und bleibt zur gehosteten Runtime feldgenau synchron:

- `services/agent-api/app/main.py` erklaert in `agent_activity_contract_payload()` jetzt explizit `task_id`, `task_status`, `retry_count`, `max_retries` und `error` als oeffentliche Trace-Felder und fuehrt dazu `failure_surface_visible` plus `agent_activity_failure_surface_visible` im Contract
- `scripts/verify-phase4-agent-activity-contract-hosted.ps1` prueft auf dem echten Hetzner-Staging zuerst `GET /api/v1/agent-activity/contract`, dann seedet es denselben `coder`/`tester`-Fehlerpfad in die Hosted-Audit-Quelle und bestaetigt anschliessend ueber `GET /api/v1/agent-activity/recent?trace_id=...`, dass Contract und Runtime dieselben top-level Failure-Felder liefern
- `.phase1-artifacts/phase4-agent-activity-contract-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Contract-/Runtime-Paritaet auf der oeffentlichen Agent-Activity-Surface

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Activity Failure Surface Parity** — dieselben negativen Worker-Endzustaende sind jetzt auch ueber die oeffentliche Agent-Activity-Surface konsistent und feldgenau sichtbar:

- `services/agent-api/app/main.py` surfacet in `agent_activity_row_to_event()` jetzt top-level `task_id`, `task_status`, `retry_count`, `max_retries` und `error` statt dieselben Failure-Fakten nur in verschachtelten `details` zu belassen
- `scripts/verify-phase4-agent-activity-failure-hosted.ps1` seedet auf dem echten Hetzner-Staging einen `coder`-`task_escalated`-Auditpfad und einen `tester`-`task_abandoned_after_queue_drain`-Auditpfad mit gemeinsamem `trace_id`, liest danach `GET /api/v1/agent-activity/recent?trace_id=...` und bestaetigt dieselben `task_id`-Werte plus top-level `task_status`, Retry-Metadaten und Fehlertexte
- `.phase1-artifacts/phase4-agent-activity-failure-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer oeffentliche Failure-Surfacing-Paritaet auf der Agent-Activity-Surface

## Previous Latest Completed Proof

**Phase 4 Hosted Agent Status Failure Surface Parity** — dieselben negativen Worker-Endzustaende sind jetzt auch ueber die oeffentlichen Agent-/Task-Surfaces konsistent und feldgenau sichtbar:

- `services/agent-api/app/main.py` behandelt `escalated` und `abandoned_after_queue_drain` in `GET /api/v1/agents/status` jetzt als sichtbare `error`-Zustaende und surfacet zusaetzlich `retries`, `latest_retry_count` und `latest_max_retries` aus dem echten letzten Task statt eines konstanten Nullwerts
- `scripts/verify-phase4-agent-status-failure-hosted.ps1` seedet auf dem echten Hetzner-Staging einen eskalierten `coder`-Task und einen `abandoned_after_queue_drain`-`tester`-Task direkt im echten Runtime-Store, prueft danach `GET /api/v1/agents/status`, `GET /api/v1/tasks/recent`, `GET /api/v1/audit/recent` und `GET /api/v1/health`, und bestaetigt `status=error`, `latest_status=escalated`, `latest_status=abandoned_after_queue_drain`, Retry-Zaehler sowie sichtbare Fehlertexte auf den oeffentlichen Surfaces
- `.phase1-artifacts/phase4-agent-status-failure-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer oeffentliche Failure-Surfacing-Paritaet zwischen Agent-Status, Task-Recent und Audit
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-agent-status-failure-hosted.ps1`, `py -3 -m py_compile services\agent-api\app\main.py`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `56%`, Phase 4 steigt auf `38%`, Agent Pool steigt auf `64%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Session Failure History Parity** — dieselben negativen Worker-Zustaende sind jetzt auch ueber die oeffentlichen Session-Surfaces konsistent und feldgenau sichtbar:

- `services/agent-api/app/main.py` erweitert `GET /api/v1/sessions/recent` um `latest_task_status`, `latest_error`, `latest_retry_count` und `latest_max_retries`, sodass negative Worker-Endzustaende nicht nur ueber Task-/Audit-Interna, sondern auch ueber die oeffentliche Recent-Session-Surface sichtbar werden
- `scripts/verify-phase4-session-failure-history-hosted.ps1` seedet auf dem echten Hetzner-Staging gezielt zwei Session-basierte stale queued Pfade: einen Rehydrate-Pfad mit passendem `task_completed`-Audit und einen Abandon-Pfad ohne Queue-Match; danach prueft der Verifier `GET /api/v1/sessions/{session_id}/history`, `GET /api/v1/sessions/recent` und `GET /api/v1/audit/recent` inklusive `latest_task_status=completed`, `latest_task_status=abandoned_after_queue_drain`, sichtbarem `latest_error` und `latest_retry_count=0`
- `scripts/deploy-to-staging.ps1` erzwingt jetzt bei geaenderten bind mounts ein `--force-recreate` der gehosteten App-Services, damit kopierter Python-Code nicht mehr mit alten laufenden Prozessen verifiziert wird
- `.phase1-artifacts/phase4-session-failure-history-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer `status=completed` via `task_status_rehydrated_from_audit`, `status=abandoned_after_queue_drain`, `worker_status_rehydrated_from_completed_audit`, `worker_stale_queued_finalized` und die neuen Recent-Session-Felder
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-failure-history-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `56%`, Phase 4 steigt auf `37%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Worker Failure / Stale Queue Parity** — der gehostete Worker-Runtime-Pfad belegt jetzt auch echte Retry-/Escalation-/Stale-Queue-Transitionen statt nur den Happy Path:

- `scripts/verify-phase4-worker-failure-parity-hosted.ps1` seedet auf dem echten Hetzner-Staging gezielt Redis-/Postgres-Status fuer einen eskalierenden Worker-Task mit fehlender Session, einen stale queued Rehydrate-Pfad mit passendem Completed-Audit und einen stale queued Abandon-Pfad ohne Queue-Match; danach prueft der Verifier `GET /api/v1/internal/tasks/{task_id}`, `GET /api/v1/tasks/recent`, `GET /api/v1/audit/recent`, `GET /api/v1/escalations/recent`, `GET /api/v1/metrics` und `GET /api/v1/health`
- `.phase1-artifacts/phase4-worker-failure-parity-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer `task_retry`, `task_failed`, `task_escalated`, `task_status_rehydrated_from_audit`, `task_abandoned_after_queue_drain`, `worker_status_rehydrated_from_completed_audit` und `worker_stale_queued_finalized`
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-worker-failure-parity-hosted.ps1`, `py -3 -m py_compile services\agent-api\app\main.py`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `56%`, Phase 4 steigt auf `35%`, Agent Pool steigt auf `63%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Orchestrator Stream / Checkpoint Replay Parity** — der gehostete LangGraph-Runtime-Pfad belegt jetzt auch die echte Orchestrator-Stream-/Replay-/Checkpoint-Integration statt nur Dry-Run-JSON:

**Vorheriger Abschluss — Phase 4 Hosted Session History / SSE Replay Parity** — der gehostete Runtime-Pfad belegt jetzt auch die echte Session-History-/Stream-/Replay-Integration statt nur Contracts:

- `scripts/verify-phase4-session-stream-history-hosted.ps1` erzeugt eine echte gehostete Prompt-Session ueber `POST /api/v1/prompt`, wartet auf die abgeschlossene deterministische Worker-Antwort ueber `GET /api/v1/sessions/{session_id}/history`, prueft dann den Live-Stream `GET /api/v1/session/{session_id}/stream` auf `heartbeat`, `agent_status`, `token` und `done` und prueft denselben Pfad erneut mit `Last-Event-ID: 0` auf sichtbares Replay mit `replay=true`
- `.phase1-artifacts/phase4-session-stream-history-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Session-History, Recent-Sessions, Live-SSE, Replay-SSE und die dazu passenden Audit-Eintraege
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-stream-history-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `55%`, Phase 4 steigt auf `33%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Session / Memory Worker Runtime Parity** — der gehostete Runtime-Pfad belegt jetzt auch die echte Session-/History-/Memory-Integration statt nur Contracts:

- `scripts/verify-phase4-session-memory-parity-hosted.ps1` erzeugt eine echte gehostete Prompt-Session ueber `POST /api/v1/prompt`, wartet auf die abgeschlossene deterministische Worker-Antwort ueber `GET /api/v1/sessions/{session_id}/history`, prueft `GET /api/v1/sessions/recent`, seedet danach per SSH einen echten `memory:working:*`-Eintrag auf dem Hetzner-Host, laesst `memory-worker --once` laufen und prueft schliesslich `GET /api/v1/memory/search`, `GET /api/v1/memory/consolidation/recent` und `GET /api/v1/metrics`
- `.phase1-artifacts/phase4-session-memory-parity-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Session-History, Recent-Sessions, echte Redis-zu-Postgres-Consolidation, oeffentliche Memory-Suche, Consolidation-Audit und Memory-Metriken
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-session-memory-parity-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `55%`, Phase 4 steigt auf `32%`, Memory steigt auf `71%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Vorheriger Abschluss — Phase 4 Hosted Worker / Priority Queue Runtime Parity** — der gehostete Runtime-Pfad belegt jetzt auch die echte Worker-/Queue-Integration statt nur Contracts:

- `scripts/verify-phase4-worker-priority-runtime-hosted.ps1` legt vier echte gehostete interne Aufgaben fuer `planner`, `coder`, `tester` und `devops` mit Prioritaeten `9`, `5`, `2` und `8` an, prueft `GET /api/v1/tasks/assignment-contract`, `POST /api/v1/internal/tasks`, `GET /api/v1/internal/tasks/{task_id}`, `GET /api/v1/tasks/recent`, `GET /api/v1/agents/status`, `GET /api/v1/sessions/recent`, `GET /api/v1/metrics` und `GET /api/v1/audit/recent`
- dabei wurde ein echter Runtime-Bug behoben: `POST /api/v1/internal/tasks` erzeugte vorher keine `agent_sessions`-Zeile, wodurch der Worker in `ForeignKeyViolation` und `status=escalated` lief; `services/agent-api/app/main.py` initialisiert jetzt die Session vor dem Queue-Intake und schreibt `latest_task_id/latest_task_type` in die Session-Metadaten
- `.phase1-artifacts/phase4-worker-priority-queue-hosted-proof-20260505.md` dokumentiert den erfolgreich wiederholbaren Hosted-Proof fuer Queue-Prioritaet, Worker-Lifecycle, Session-Sichtbarkeit, Audit und Metrics
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-worker-priority-runtime-hosted.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 -m py_compile services\agent-api\app\main.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `55%`, Phase 4 steigt auf `31%`, Agent Pool steigt auf `62%`; dies ist ein echter gehosteter Integrations-/Hardening-Beweis, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Post-Rollback Provenance + Completion Gate Freeze** — der aktuelle Production-Candidate ist jetzt nach rollback/restore nicht nur requalifiziert und browser-/observability-seitig frisch bestätigt, sondern auch nochmals explizit an Workflow/GHCR-Herkunft und an die weiterhin fail-closed Completion-Grenze gebunden:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-provenance-revalidation.md` bindet den Candidate an die weiterhin erfolgreiche GitHub-Workflow-Herkunft `25392582005`, an denselben Commit `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`, an die weiter verfuegbaren immutable GHCR-Tag-Saetze fuer alle sechs Services und an die bestätigte Multi-Arch-Verwendbarkeit fuer Hetzner `arm64`; der Proof bestaetigt dazu Hosted Root/API/MCP/LLM weiter gruen sowie `overall=55`, `phase5=28`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-completion-gate-freeze.md` bindet denselben Candidate an den nach Rollback/Restore weiter fail-closed bleibenden Completion-Contract: External Gates bleiben `verified`, `blocked_release_gates=[]`, aber `can_set_all_to_100=false` und `owner_decision=no-release` bleiben hart aktiv
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt jetzt `post_rollback_provenance_revalidation_proof` und `post_rollback_completion_gate_freeze_proof` explizit als weitere Candidate-Evidence
- `scripts/verify-phase5-post-rollback-provenance-revalidation.ps1` und `scripts/verify-phase5-post-rollback-completion-gate-freeze.ps1` pruefen Artefaktstruktur, Candidate-Links, GitHub-Workflow-Herkunft, GHCR-Manifest-Architekturen, Hosted-Endpunkte, External Gates und Completion fail-closed
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-provenance-revalidation.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-completion-gate-freeze.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `55%`, Phase 5 steigt auf `28%`; dies sind zwei weitere Release-Readiness-/Operations-Proofs, aber weiterhin kein Rollout und kein Production-Deploy

**Historischer, jetzt superseded Browser-Abschnitt — Phase 5 Post-Rollback Observability + Browser Revalidation** — der Browser-Teil dieses alten Claims ist nicht mehr Teil des aktuellen Candidate-Truth:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-observability-revalidation.md` bindet den Candidate an eine neue gehostete Nachpruefung von `health`, `project/progress`, `project/progress/integrity`, `metrics`, `audit/recent`, `escalations/recent` und `external-gates`; der Proof bestaetigt `overall=55`, `phase5=26`, `status=verified` und weiter `no-release`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-browser-revalidation.md` ist jetzt als historisches, superseded Artefakt markiert; ein frischer Browser-Rerun ist aktuell extern blockiert und wird nicht mehr als aktuelle Candidate-Evidence gefuehrt
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt nur noch `post_rollback_observability_revalidation_proof` als aktive Candidate-Evidence; der Browser-Teil ist explizit aus dem aktuellen Truth entfernt
- `scripts/verify-phase5-post-rollback-observability-revalidation.ps1` bleibt auf aktueller Hosted-Truth, `scripts/verify-phase5-post-rollback-browser-revalidation.ps1` prueft jetzt fail-closed den historischen Blockerzustand
- der Browser-Blocker ist durch `failed to start codex app-server`, `Target.setDiscoverTargets): Target closed` und Playwright `exit code 13` konkret belegt
- die historische Fortschrittslinie dieses alten Abschnitts bleibt nur Dokumentationskontext und ist nicht der aktuelle Manifest-Truth

**Phase 5 Post-Rollback Stability + Refusal Proofs** — der aktuelle Production-Candidate ist jetzt nach rollback/restore nicht nur unmittelbar requalifiziert, sondern auch im Nachlauf stabil gehalten und erneut hart auf `no-release` fixiert:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-stability-watch.md` bindet den Candidate an einen kurzen gehosteten Nachlauf nach dem echten immutable rollback/restore Lauf; zwei aufeinanderfolgende Progress-/Integrity-Reads bleiben bei `overall=54`, `phase5=24` und `status=verified`, Completion bleibt fail-closed und External Gates bleiben `verified`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-promotion-gate-refusal.md` fixiert denselben neuesten Zustand nochmals explizit als nicht promotable: `owner_decision=no-release`, kein `prod-release-*` Artefakt, Completion weiter `can_set_all_to_100=false`, Hosted Progress `overall=54`, `phase5=24`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt jetzt `post_rollback_stability_watch_proof` und `post_rollback_promotion_gate_refusal_proof` explizit als Candidate-Evidence
- `scripts/verify-phase5-post-rollback-stability-watch.ps1` und `scripts/verify-phase5-post-rollback-promotion-gate-refusal.ps1` pruefen Artefaktstruktur, Candidate-Links, Hosted-Endpunkte, Hosted-Progress/Integrity/Completion sowie die weiter harte `no-release`-/No-Production-Truth
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-stability-watch.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-promotion-gate-refusal.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `54%`, Phase 5 steigt auf `24%`; dies sind zwei weitere Release-Readiness-/Operations-Proofs, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Post-Rollback Requalification Proof** — der aktuelle Production-Candidate ist jetzt nach dem echten immutable rollback/restore Lauf nochmals hosted requalifiziert:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-post-rollback-requalification.md` bindet den Candidate an den gehosteten Requalifikationslauf nach dem executed rollback proof
- der Proof bestaetigt `IMAGE_TAG=staging` nach Restore, Hosted Root/API/MCP/LLM `200`, hosted Progress weiterhin manifest-backed, Integrity `verified`, External Gates `verified` und Completion weiter fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `post_rollback_requalification_proof`-Eintrag jetzt explizit als Candidate-Evidence
- `scripts/verify-phase5-post-rollback-requalification.ps1` prueft Artefaktstruktur, Candidate-Link, remote `.env`, Hosted-Endpunkte, Hosted-Progress `overall=54`, `phase5=22`, Integrity `verified` und External Gates fail-closed
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-post-rollback-requalification.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\deploy-to-staging.ps1 -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`, `py -3 scripts\verify_project_progress_manifest.py`
- Historischer Fortschrittspunkt: dieser Proof hob Phase 5 zuvor auf `22%`; current verified progress remains defined by the manifest-backed totals above

**Phase 5 Executed Candidate Risk Review** — der aktuelle Production-Candidate hat jetzt auch den expliziten Risk-/Open-Questions-Review als eigenen Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-risk-review.md` bindet den Candidate an einen ausgefuehrten Risk-Review fuer offene Fragen, erklaerte Blocker, Completion-Guard, External-Gate-Wahrheit sowie Audit-/Escalation-Sichtbarkeit bei weiter bindendem `no-release`
- `scripts/verify-phase5-risk-review.ps1` prueft Artefaktstruktur, Candidate-Link, Hosted-Progress `overall=53`, `phase5=18`, Hosted-Integrity `verified`, Completion `can_set_all_to_100=false`, External Gates `verified` sowie Audit-/Escalation-Feeds fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `risk_review_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-risk-review.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `53%`, Phase 5 steigt auf `18%`; dies ist ein weiterer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Candidate Handoff Packet** — der aktuelle Production-Candidate hat jetzt auch den Release-Communication-/Operator-Handoff-Satz als eigenen Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-handoff-packet.md` bindet den Candidate an einen ausgefuehrten Packet-Satz aus `AI_HANDOFF.md`, `PROJECT_STATE.md`, `docs/verification-register.md`, `docs/project-progress.manifest.json`, Candidate-Artefakt, Rollback-Drill und `no-release`-Owner-Decision
- `scripts/verify-phase5-handoff-packet.ps1` prueft Artefaktstruktur, Candidate-Link, die Spiegel `AI_HANDOFF.md` und `PROJECT_STATE.md`, den Verification Register, gehostete Runtime-Truth `overall=53`, `phase5=17` und Integrity `verified` fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `handoff_packet_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-handoff-packet.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `53%`, Phase 5 steigt auf `17%`; dies ist ein weiterer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Candidate Memory Recovery Drill** — der aktuelle Production-Candidate hat jetzt auch den Memory-Recovery-Entscheidungspfad als eigenen Operations-Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-memory-recovery-drill.md` bindet den Candidate an einen ausgefuehrten candidate-spezifischen Memory-Recovery-Drill fuer Search-, Purge-, Job-Status- und Consolidation-Surfaces bei weiter gueltigem `no-release`
- `scripts/verify-phase5-memory-recovery-drill.ps1` prueft Artefaktstruktur, Candidate-Link, `api/v1/health`, gehostete Runtime-Truth `overall=53`, `phase5=16`, Integrity `verified`, `memory/embedding-consistency/contract`, `memory/purge/contract`, `memory/purge/jobs/{job_id}`, `memory/consolidation/recent` und Audit-Feed fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `memory_recovery_drill_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-memory-recovery-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `53%`, Phase 5 steigt auf `16%`; dies ist ein weiterer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Candidate Provider Failover Drill** — der aktuelle Production-Candidate hat jetzt auch den Provider-Failover-Entscheidungspfad als eigenen Operations-Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-provider-failover-drill.md` bindet den Candidate an einen ausgefuehrten candidate-spezifischen Failover-Drill fuer den LLM-Gateway-Routing-Scope, ohne Live-Provider-Umschaltung und bei weiter gueltigem `no-release`
- `scripts/verify-phase5-provider-failover-drill.ps1` prueft Artefaktstruktur, Candidate-Link, `llm/api/v1/health`, `api/v1/health`, gehostete Runtime-Truth `overall=53`, `phase5=15`, Integrity `verified`, External Gates `verified`, Deployment Preflight `verified` und Audit-Feed `200` fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `provider_failover_drill_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-provider-failover-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `53%`, Phase 5 steigt auf `15%`; dies ist ein weiterer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Candidate Secret Rotation Drill** — der aktuelle Production-Candidate hat jetzt auch den Secret-Rotation-Pfad als eigenen Operations-Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-secret-rotation-drill.md` bindet den Candidate an einen ausgefuehrten candidate-spezifischen Secret-Rotation-Drill mit klarer Trennung zwischen Secret-Store und Git, weiter gueltigem `no-release` und hosted Re-Checks fuer Health, Progress, Integrity, External Gates und Deployment Preflight
- `scripts/verify-phase5-secret-rotation-drill.ps1` prueft Artefaktstruktur, Candidate-Link, gehostete Runtime-Truth `overall=53`, `phase5=14`, Integrity `verified`, External Gates `verified` und Deployment Preflight `verified` fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `secret_rotation_drill_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-secret-rotation-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `53%`, Phase 5 steigt auf `14%`; dies ist ein weiterer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Historischer, jetzt superseded Browser-Abschnitt — Phase 5 Executed Hosted Candidate Browser Proof** — dieser Browser-Claim ist nicht mehr Teil des aktuellen Candidate-Truth:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` ist jetzt als historisches, superseded Artefakt markiert; frische In-App-Browser-Evidence ist aktuell extern blockiert
- `scripts/verify-phase5-browser-proof.ps1` prueft jetzt fail-closed den historischen Blockerzustand statt einen nicht reproduzierbaren aktuellen Browser-Claim
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt keinen aktiven `browser_proof`-Eintrag mehr als Candidate-Evidence
- die aktuelle harte Blocker-Evidence lautet `failed to start codex app-server`, `Target.setDiscoverTargets): Target closed` und Playwright `exit code 13`
- die historische Fortschrittslinie dieses alten Abschnitts bleibt nur Dokumentationskontext und ist nicht der aktuelle Manifest-Truth

**Phase 5 Candidate Observability Review Proof** — der aktuelle Production-Candidate hat jetzt auch die gehostete Observability-Sichtung als eigenen Release-Readiness-Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-observability-review.md` bindet den Candidate an die wirklich ausgefuehrte Sichtung von Hosted-Health, Progress, Progress-Integrity, Metrics, Audit-Feed, Escalation-Feed und External Gates
- `scripts/verify-phase5-observability-review.ps1` prueft Artefaktstruktur, Candidate-Link und die live gehosteten Observability-Endpunkte fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `observability_review_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-observability-review.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt steigt auf `53%`, Phase 5 steigt auf `12%`; dies ist ein weiterer Release-Readiness-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Candidate Incident Drill** — der aktuelle Production-Candidate hat jetzt auch den dokumentierten Stoerungs- und Eskalationspfad als eigenen Operations-Proof:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-incident-drill.md` bindet den Candidate an einen ausgefuehrten Incident-/Escalation-Drill fuer den Fall eines unhealthy production-candidate, inklusive Incident-Klassifikation `runtime`, Evidence-Capture, Rollback-Entscheidungspfad und weiter gueltigem `no-release`
- `scripts/verify-phase5-incident-drill.ps1` prueft Artefaktstruktur, Candidate-Link, Hosted-Health, Progress-Integrity, Metrics, Audit-Feed, Escalation-Feed, External Gates und Deployment Preflight fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `incident_drill_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-incident-drill.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `52%`, Phase 5 steigt auf `11%`; dies ist ein neuer Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 5 Executed Hosted Candidate Smoke Proof** — der aktuelle Production-Candidate hat jetzt nicht nur Plan und Rollback-Drill, sondern auch einen ausgefuehrten, dokumentierten Hosted-Smoke-Run:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-smoke-proof.md` bindet den aktuellen Candidate an den wirklich ausgefuehrten Hosted-Smoke-Pfad fuer `/`, `/api/v1/health`, `/mcp/api/v1/health`, `/llm/api/v1/health`, `/api/v1/project/progress`, `/api/v1/project/progress/integrity`, `/api/v1/project/progress/completion`, `/api/v1/external-gates`, `/api/v1/external-gates/mirror` und `/api/v1/clouds/deployment-preflight/contract`
- `scripts/verify-phase5-executed-smoke.ps1` prueft Artefaktstruktur, Candidate-Link, Hosted-Root-Titel `Cloud Superbrain`, alle vier Hosted-Health-Pfade, Progress `overall=52`, `phase4=30`, `phase5=10`, Integrity `verified`, External Gates `verified`, External Gate Mirror `verified`, Deployment Preflight `verified` und Completion `can_set_all_to_100=false`
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `executed_smoke_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-smoke.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `52%`, Phase 5 steigt auf `10%`; dies ist ein neuer Release-Readiness-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 4 Hosted Cloud Surface + Gate Mirror Parity Proof** — die gehosteten Cloud-/Gate-Oberflaechen sind jetzt ebenfalls als eigener HTTPS-Hardening-Slice wiederholbar belegt:

- `scripts/verify-phase4-cloud-surfaces-hosted.ps1` prueft auf echtem Hosted HTTPS Staging die sichtbaren Root-Panels `Cloud Inventory`, `Cloud 7-Layer Readiness`, `Cloud Render Offload`, `Cloud Deployment Preflight` und `External Gate Mirror` sowie `GET /api/v1/clouds`, `GET /api/v1/clouds/layers`, `GET /api/v1/clouds/render-offload/contract`, `GET /api/v1/clouds/deployment-preflight/contract`, `GET /api/v1/external-gates`, `GET /api/v1/external-gates/mirror` und `GET /api/v1/project/progress/completion`
- der Proof deckt `cloud-provider-inventory-v1`, `cloud_layer_readiness_visible`, `cloud_render_offload_contract_visible`, `cloud_deployment_preflight_visible`, `external_gate_mirror_proof`, die freigeschalteten claim flags sowie die weiterhin lokale Blockade von `can_set_all_to_100=false` trotz geschlossener externer Gates ab
- Artefakt `.phase1-artifacts/phase4-cloud-surfaces-hosted-proof-20260505.md` bindet den wiederholbaren HTTPS-Proof an den exakten Verifier-Befehl
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-cloud-surfaces-hosted.ps1 -BaseUrl <hosted-staging-url>`, `py -3 scripts\verify_project_progress_manifest.py`, direkte Hosted-Progress-/Integrity-Pruefung nach dem Sync
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `52%`, Phase 4 steigt auf `30%`; dies ist ein neuer dedizierter Hosted-Integration-&-Hardening-Proof, aber weiterhin kein Production-Deploy

**Phase 5 Candidate Integration Plan Proof** — der aktuelle Production-Candidate hat jetzt auch den zuvor offenen candidate-spezifischen Integrations-/Smoke-Plan als eigenes Release-Artefakt:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-integration-plan.md` beschreibt die geordnete Hosted-Smoke-Sequenz, die erwarteten Outcomes, Failure-Handling und Non-Claims fuer den aktuellen Candidate
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt `Integration plan documented` jetzt explizit als geschlossen und verlinkt den Integrationsplan
- `scripts/verify-phase5-integration-plan.ps1` prueft den neuen Candidate-Plan fail-closed gegen Artefaktstruktur und Link im Candidate-Artefakt
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-integration-plan.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `52%`, Phase 5 steigt auf `9%`; dies ist ein weiterer Release-Readiness-Proof, aber weiterhin kein Rollout und kein Production-Deploy

**Phase 4 Hosted Public Dashboard + Observability Truth Proofs** — die gehosteten oeffentlichen Dashboard-/Session-Stream-Surfaces und die gehostete Runtime-/Telemetrie-Wahrheit sind jetzt ebenfalls als eigene HTTPS-Hardening-Slices wiederholbar belegt:

- `scripts/verify-phase4-public-dashboard-hosted.ps1` prueft auf echtem Hosted HTTPS Staging die sichtbare Root-Oberflaeche, `GET /api/v1/project/progress`, `GET /api/v1/project/progress/integrity`, `GET /api/v1/project/progress/completion`, `GET /api/v1/layer-interfaces/contract`, `GET /api/v1/tasks/assignment-contract`, `GET /api/v1/agents/llm-streaming-contract`, den echten `POST /api/v1/prompt`-Pfad, `GET /api/v1/tasks/recent`, `GET|POST /api/v1/tasks/policy*`, `GET /api/v1/agents/status`, `GET /api/v1/agents/profiles`, `GET /api/v1/sessions/recent`, `GET /api/v1/audit/recent`, `GET /api/v1/escalations/recent` sowie Session-SSE und Replay
- `scripts/verify-phase4-observability-hosted.ps1` prueft auf echtem Hosted HTTPS Staging `GET /api/v1/project/progress/integrity`, `GET /api/v1/agent-activity/contract`, `GET /api/v1/agent-activity/recent`, `GET /api/v1/audit/recent` und `GET /api/v1/metrics` als eigenen Observability-/Runtime-Truth-Block
- die Proofs decken manifestgebundene Progress-Wahrheit, fail-closed Completion-Guards, oeffentliche Task-/Policy-/Profile-/Session-Paritaet, deterministische Session-SSE-Replays, Agent-Activity-Filtered-Feed, Audit-/Request-Korrelation und die hosted Prometheus-Metriken fuer Budget, Progress, Queue, Services, MCP-Ereignisse, Memory-Consolidation und Checkpoint-Tabellen ab
- Artefakte `.phase1-artifacts/phase4-public-dashboard-hosted-proof-20260505.md` und `.phase1-artifacts/phase4-observability-hosted-proof-20260505.md` binden die wiederholbaren HTTPS-Proofs an die exakten Verifier-Befehle
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-public-dashboard-hosted.ps1 -BaseUrl <hosted-staging-url>`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-observability-hosted.ps1 -BaseUrl <hosted-staging-url>`, `py -3 scripts\verify_project_progress_manifest.py`, direkte Hosted-Progress-/Integrity-Pruefung nach dem Sync
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `52%`, Phase 4 steigt auf `29%`; dies sind zwei neue dedizierte Hosted-Integration-&-Hardening-Proofs, aber weiterhin kein Production-Deploy

**Phase 4 Hosted MCP Safe Envelope + DevOps Dispatch Proof** — die gehosteten MCP-Werkzeuggrenzen und das fail-closed DevOps-Dispatch-Gate sind jetzt ebenfalls als eigener HTTPS-Hardening-Slice wiederholbar belegt:

- `scripts/verify-phase4-mcp-devops-hosted.ps1` extrahiert den MCP-Safe-Envelope- und DevOps-Dispatch-Abschnitt aus dem Monolith-Verifier und prueft auf echtem Hosted HTTPS Staging `GET /mcp/api/v1/health`, die sichtbaren MCP-Contracts fuer GitHub/PostgreSQL/Filesystem/Playwright/E2B/Version-Pinning, die dry-run/blocked/degraded Pfade von `POST /mcp/api/v1/tools/execute`, `GET /api/v1/audit/mcp`, `GET /api/v1/devops/workflow-dispatch/plan`, `POST /api/v1/devops/workflow-dispatch/validate` und die korrespondierenden Audit-Ereignisse in `GET /api/v1/audit/recent`
- der Proof deckt `status=timeout`, `status=blocked`, `status=degraded`, GitHub-Branch/PR-Dry-Run, PostgreSQL-Readonly-Plan, Filesystem-Workspace-Plan, Playwright-Browser-Proof-Plan, E2B-Lifecycle-Plan, deren jeweilige Policy-Blocks, persistierte Audit-Spuren sowie das fail-closed Dispatch-Gate fuer `production workflow dispatch requires human_review_approved=true` ab
- Artefakt `.phase1-artifacts/phase4-mcp-devops-hosted-proof-20260505.md` bindet den wiederholbaren HTTPS-Proof an den exakten Verifier-Befehl
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-mcp-devops-hosted.ps1 -BaseUrl <hosted-staging-url>`, `py -3 scripts\verify_project_progress_manifest.py`, direkte Hosted-Progress-/Integrity-Pruefung nach dem Sync
- Fortschritt steigt evidenzbasiert: Gesamt geht auf `52%`, Phase 4 steigt auf `27%`, MCP Gateway auf `54%`; dies ist ein neuer dedizierter Hosted-Integration-&-Hardening-Proof, aber weiterhin kein Production-Deploy

**Phase 4 Hosted Orchestrator Fail-Closed + SSE Replay Proof** — die negativen LangGraph-/SSE-Pfade sind jetzt ebenfalls als eigener gehosteter HTTPS-Hardening-Slice wiederholbar belegt:

- `scripts/verify-phase4-orchestrator-failclosed-hosted.ps1` extrahiert den Hard-Stop-/Retry-/Replay-Abschnitt aus dem Monolith-Verifier und prueft auf echtem Hosted HTTPS Staging Policy/Budget-Hard-Stops, den globalen Retry-Cap, node-bounded failures fuer `intent_parser`, `budget_guard`, `task_router`, `agent_executor`, `result_aggregator` und `memory_updater`, den LLM-Routing-Policy-Deny-Pfad sowie den SSE-/Replay-/Error-Contract
- der Proof deckt `hard_stop_reason=policy_or_budget_guard_rejected`, `global_retry_limit_reached`, `${node}_retry_limit_reached`, `llm_routing_policy_rejected`, `phase2-sse-event-contract-v1`, `phase2_sse_event_contract_proof`, `replay=true`, den terminalen Error-Probe `force_phase2_sse_error_event` und `live_provider_calls=false` auf Hosted HTTPS ab
- Artefakt `.phase1-artifacts/phase4-orchestrator-failclosed-hosted-proof-20260505.md` bindet den wiederholbaren HTTPS-Proof an den exakten Verifier-Befehl
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-orchestrator-failclosed-hosted.ps1 -BaseUrl <hosted-staging-url>`, `py -3 scripts\verify_project_progress_manifest.py`, direkte Hosted-Progress-/Integrity-Pruefung nach dem Sync
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `51%`, Phase 4 steigt auf `26%`; dies ist ein neuer dedizierter Hosted-Integration-&-Hardening-Proof, aber weiterhin kein Production-Deploy

**Phase 4 Hosted Orchestrator Runtime Parity Proof** — der LangGraph-/Phase-2-Runtime-Pfad ist jetzt auch als eigener gehosteter HTTPS-Hardening-Slice wiederholbar belegt:

- `scripts/verify-phase4-orchestrator-runtime-hosted.ps1` extrahiert den orchestrierten Runtime-Parity-Pfad aus dem Monolith-Verifier und prueft auf echtem Hosted HTTPS Staging `GET /api/v1/orchestrator/manifest`, `POST /api/v1/orchestrator/dry-run`, `GET /api/v1/orchestrator/checkpoints/{thread_id}`, `GET /api/v1/audit/recent`, `GET /api/v1/audit/mcp`, `GET /api/v1/memory/search`, `GET /api/v1/tasks/recent`, `GET /api/v1/phase2/runtime/contract`, `POST /api/v1/phase2/runtime/start`, `GET /api/v1/phase2/runtime/runs` und `GET /api/v1/agent-activity/recent?event_type=phase2_runtime_graph_started`
- der Proof deckt LangGraph `engine=langgraph`, `checkpointing=postgres`, `live_provider_calls=false`, den vier-Rollen-Agentenlauf mit high-priority Planner/DevOps, MCP-Readonly-Plan fuer PostgreSQL, `stream_done_seen=true`, `allow_primary`-Routing, Audit-/MCP-Audit-Korrelation, Memory-Update-Persistenz sowie die gehostete Phase-2-Runtime-Paritaet mit `live_mcp_writes=false`, `production_deploy=false`, per-role Aggregation und Run-Status-Sichtbarkeit ab
- Artefakt `.phase1-artifacts/phase4-orchestrator-runtime-hosted-proof-20260505.md` bindet den wiederholbaren HTTPS-Proof an den exakten Verifier-Befehl
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase4-orchestrator-runtime-hosted.ps1 -BaseUrl <hosted-staging-url>`, `py -3 scripts\verify_project_progress_manifest.py`, direkte Hosted-Progress-/Integrity-Pruefung nach dem Sync
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `51%`, Phase 4 steigt auf `25%`; dies ist ein neuer dedizierter Hosted-Integration-&-Hardening-Proof, aber weiterhin kein Production-Deploy

**Phase 3 Repeatable Browser Surface Proof** — der vorhandene Product-Surface-&-Security-Satz ist jetzt nicht nur runtime-/hosted-seitig, sondern auch lokal als wiederholbarer Browser-/API-Harness sichtbar:

- `scripts/verify-browser-contract.ps1` deckt jetzt lokal die bereits ausgelieferten P3-Panels und Contract-Endpunkte fuer `Memory Purge Contract`, `Cost Monitor CSV Export`, `Rate Limit Guard`, `Session Limit Guard`, `Error Response Contract`, `Security Headers Contract`, `Trace ID Contract`, `Cache Control Contract`, `Request ID Contract` und `Agent Activity` mit ab
- `.phase1-artifacts/phase3-browser-surface-proof-20260505.md` bindet den wiederholbaren lokalen Browser-Proof an den exakten Verifier-Befehl
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt minimal evidenzbasiert: Gesamt bleibt `50%`, Phase 3 steigt auf `34%`; dies ist lokaler Browser-/API-Repeatability-Proof fuer vorhandene P3-Surfaces, aber kein neuer Hosted-/Production-Claim

**Phase 5 Owner Decision + P3 Browser Proof Hardening** — der erste Candidate ist jetzt explizit auf `no-release` gestellt, und die bereits sichtbaren P3-Vertraege werden nun auch vom lokalen Browser-Harness fail-closed mitbelegt:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt `owner_decision_proof`, `review_gate=reviewed` und `owner_decision=no-release`; `.phase1-artifacts/phase5-owner-decision-no-release-20260505.md` dokumentiert die Begruendung bei unveraendertem `overall=50%` und weiter offenem `can_set_all_to_100=false`
- `scripts/verify-phase5-candidate.ps1` prueft den Candidate jetzt fail-closed inklusive `no-release`-Artefakt statt nur gegen einen `pending`-Reviewzustand
- `scripts/verify-browser-contract.ps1` deckt jetzt die bereits vorhandenen Frontend-/API-Marker fuer `Auth Contract` und `System Unavailable Fallback` mit ab; damit werden zwei P3-Vertraege nicht nur hosted, sondern auch lokal wiederholbar browserseitig bewiesen
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt minimal evidenzbasiert: Gesamt bleibt `50%`, Phase 5 steigt auf `8%`; dies ist eine dokumentierte `no-release`-Entscheidung plus lokales P3-Verifier-Hardening, aber weiterhin kein Production-Deploy

**Phase 5 Candidate Pipeline + Rollback Drill Proof** — Phase 5 ist nicht mehr nur beim ersten RC-Artefaktschritt, sondern hat jetzt einen workflow-gebundenen Candidate und einen dokumentierten Good-Tag-Ruecksprung:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` bindet den ersten Production-Candidate jetzt an den erfolgreichen GitHub-Run `25318349068`, Commit `5464c922f8871e4ff36e620ff53026fb1a2a05b3`, GHCR-Candidate-Tags, einen immutable Good-Tag-Satz, Rollback-Runbook, Review-Gate und Owner-Decision im Zustand `pending`
- `.phase1-artifacts/phase5-rollback-readiness-20260505.md` bleibt der Readiness-Beleg fuer Hosted-Root, Agent API, MCP Gateway und LLM Gateway; `.phase1-artifacts/phase5-rollback-drill-prod-candidate-20260505-rc1.md` dokumentiert jetzt zusaetzlich den candidate-spezifischen Good-Tag-Rollback-Drill gegen den immutable Tag-Satz `:5464c922f8871e4ff36e620ff53026fb1a2a05b3`
- `scripts/verify-phase5-candidate.ps1` und `scripts/verify-phase5-rollback-drill.ps1` pruefen den Candidate fail-closed gegen Release-Artefakt, Workflow-Run, Rollback-Readiness, Rollback-Drill, Hosted-Endpoints, GHCR-`staging`-Tags, GHCR-Commit-Tags und die gehostete Runtime-Wahrheit
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-readiness.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-rollback-drill.ps1`, `gh run view 25318349068 --json conclusion,status,headSha,url,name`, `docker manifest inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:staging`, `docker manifest inspect ghcr.io/strazzusochr/cloud-superbrain-developer-platform/<service>:5464c922f8871e4ff36e620ff53026fb1a2a05b3`, `GET <hosted-staging-url>/`, `GET /api/v1/health`, `GET /mcp/api/v1/health`, `GET /llm/api/v1/health`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `50%`, Phase 5 steigt auf `7%`; dies ist ein verifizierter Candidate-Pipeline-/Good-Tag-Rollback-Drill-Schritt, aber weiterhin kein Production-Deploy

**Phase 5 Release Readiness Baseline Proof** — der Release-Pfad hat jetzt einen belastbaren Basissatz aus Checkliste, Artefakt-Template, Runbooks und eigenem Verifier:

- `docs/release-checklist.md` ist nicht mehr nur Phase-0-Draft, sondern definiert jetzt den aktiven Phase-5-Standard mit vier Sektionen `Code Readiness`, `Infrastructure Readiness`, `Observability Readiness` und `Operations Readiness`, ausschliesslich `JA/NEIN`-Items, Git-Artefakt-Pfad `docs/release-artifacts/<release_id>.md`, Stop-Gates und Non-Claims
- `docs/release-artifacts/README.md` und `docs/release-artifacts/TEMPLATE.md` definieren jetzt den Git-Artefakt-Pfad und das auszufuellende Release-Candidate-Format mit `release_id`, `pipeline_status`, `review_gate`, `owner_decision` und den vier Pflichtsektionen
- `docs/runbooks/rollback-deploy.md`, `docs/runbooks/incident-response.md`, `docs/runbooks/secret-rotation.md`, `docs/runbooks/provider-failover.md` und `docs/runbooks/memory-recovery.md` bilden jetzt die produktionsnahen Pflicht-Runbooks mit Trigger, Verifikation, Eskalation und Non-Claims; `docs/runbooks/README.md` wurde auf Phase-5-Baseline hochgezogen
- `scripts/verify-phase5-release-readiness.ps1` prueft den neuen Release-Basissatz fail-closed gegen Checkliste, Artefakt-Template, Runbooks, Hosted-Proof-Artefakt und Deploy-Workflow-Guard
- Verifiziert: `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-release-readiness.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Der Basissatz allein erhoehte den Fortschritt noch nicht; die Prozent-Erhoehung erfolgte erst mit dem konkreten Production-Candidate-Artefakt und dem nachgezogenen Candidate-Verifier

**Hosted Runtime Truth Alignment Proof** — die gehosteten Gate-Panels sprechen jetzt dieselbe Wahrheit wie Audit und Manifest:

- `services/agent-api/app/main.py` liest die evidenzbasierten Gate-Schliessungen jetzt aus dem bindenden Progress-Manifest statt nur aus der aktuellen Env-Praesenz; `GET /api/v1/external-gates`, `GET /api/v1/external-gates/mirror`, `GET /api/v1/clouds/deployment-preflight/contract` und `GET /api/v1/project/progress/completion` laufen damit fail-closed, aber ohne alte Runtime-Drift
- nach Remote-Sync und gezieltem `docker compose --env-file .env -f docker-compose.cloud.yml up -d --force-recreate agent-api` auf Hetzner liefert Hosted jetzt `external-gates status=verified`, `verified_count=6`, `deployment-preflight status=verified`, `missing_or_blocked_gates=[]`, `cloud_deploy_claim_allowed=true` und `production_deploy_claim_allowed=true`
- `GET <hosted-staging-url>/api/v1/external-gates/mirror` liefert jetzt ebenfalls `status=verified`, `hosted_staging_claim_allowed=true`, `branch_protection_claim_allowed=true` und `production_deploy_claim_allowed=true`
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `scripts/deploy-to-staging.ps1`, `scripts/verify-cloud-only-staging.ps1 -BaseUrl <hosted-staging-url>`, `scripts/verify-external-gates.ps1 -HostedBaseUrl <hosted-staging-url> -LocalBaseUrl <local-control-plane-url>`, direkte Hosted-API-Pruefung von `/api/v1/external-gates`, `/api/v1/external-gates/mirror`, `/api/v1/clouds/deployment-preflight/contract` und `/api/v1/project/progress/completion`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `49%`, Phase 4 steigt auf `24%`; dies ist die abgeschlossene Runtime-Truth-Angleichung nach der Gate-Schliessung, aber weiterhin kein ausgerollter Production-Stack

**External Gate Audit Closure Proof** — der komplette externe Gate-Satz ist jetzt evidenzbasiert geschlossen:

- `scripts/verify-external-gates.ps1 -HostedBaseUrl <hosted-staging-url> -LocalBaseUrl <local-control-plane-url>` erzeugte `.phase1-artifacts\external-gate-audit-20260504-212633.json` mit `status=verified`, `frontend_preview_claim_allowed=True`, `hosted_staging_claim_allowed=True` und `production_deploy_claim_allowed=True`
- der Verifier prueft jetzt GHCR-Digests ohne unnoetigen lokalen Token-Zwang, hosted Backend Origins ueber echte non-local HTTPS-Probes, Hetzner Live Budget ueber den gehosteten Health-Contract und Branch Protection ueber einen Remote-Fallback, der `scripts/apply_github_branch_protection.py --verify-only` mit dem vorhandenen Remote-`.env` auf dem Hetzner-Host ausfuehrt
- Live-Beweise: `docker manifest inspect` fuer alle sechs GHCR-Images, Hosted-Health-Probes gegen `/api/v1/health`, `/mcp/api/v1/health`, `/llm/api/v1/health`, gehosteter `infra_budget.live_verified=true`, und Remote-GitHub-Verify-Only-Output fuer Branch Protection auf `chore/repo-bootstrap`
- Verifiziert: `scripts/verify-phase1.ps1`, `scripts/verify-cloud-only-staging.ps1 -BaseUrl <hosted-staging-url>`, `scripts/verify-external-gates.ps1 -HostedBaseUrl <hosted-staging-url> -LocalBaseUrl <local-control-plane-url>`, Remote `python3 /tmp/apply_github_branch_protection.py --verify-only --repo strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM --branch chore/repo-bootstrap`, GHCR manifest probes und canonical `gitleaks`
- Fortschritt steigt evidenzbasiert: Gesamt geht auf `49%`, Phase 4 auf `23%`; dies ist Gate-Schliessung und Release-Readiness-Hardening, aber weiterhin kein ausgerollter Production-Stack

**Hosted HTTPS Staging Proof** — echtes non-local HTTPS Staging ist jetzt auf Hetzner live und fail-closed nachgewiesen:

- Deploy-Skript `scripts/deploy-to-staging.ps1` kopiert nur nicht-geheime Artefakte, verlangt ein bestehendes Remote-`.env`, setzt `STAGING_HOSTNAME=<hosted-staging-hostname>`, `STAGING_BASE_URL=<hosted-staging-url>` sowie die drei non-local Backend-Origins und deployed den Pull-basierten Cloud-Stack nach `/app`
- `docker-compose.cloud.yml` enthaelt jetzt den TLS-Proxy `caddy`, `infrastructure/caddy/Caddyfile` terminiert HTTPS vor `nginx`, und `infrastructure/nginx/cloud.conf` bewahrt `X-Forwarded-Proto`/`X-Forwarded-Host` aus der aeusseren TLS-Schicht
- Live-Host-Beweis: `<hosted-staging-url>/` liefert `200`, `<hosted-staging-url>/api/v1/health` liefert `status=healthy`, `<hosted-staging-url>/api/v1/project/progress` liefert `overall_percent=48`, und der Remote-Compose-Status meldet `caddy`, `nginx`, `agent-api`, `mcp-gateway`, `llm-gateway`, `frontend`, `postgres`, `redis`, `agent-worker` und `memory-worker` als gesund
- Verifiziert: `scripts/verify-phase1.ps1`, `scripts/verify-cloud-only-staging.ps1 -BaseUrl <hosted-staging-url>`, `scripts/verify-external-gates.ps1 -HostedBaseUrl <hosted-staging-url> -LocalBaseUrl <local-control-plane-url>`, Python/OpenSSL-GET-Probes gegen Hosted Root/API und Remote-`curl -k` via SSH gegen Root, Agent API, MCP Gateway und LLM Gateway
- Browser-Live-Beweis: Puppeteer navigierte zu `<hosted-staging-url>/` und bestaetigte `Cloud Superbrain`, `Project Progress`, `External Gates`, sichtbares `48%` und die echte Hosted-URL. Playwright/Chrome-DevTools Screenshot-Proof blieb lokal durch fehlende Chrome-Installation blockiert.
- Fortschritt steigt minimal evidenzbasiert: Gesamt bleibt `48%`, Phase 4 steigt auf `16%`; dies schliesst `hosted_staging_claim_allowed=true`, aber nicht GHCR, Branch Protection, Vercel Backend Origins oder Production

**External Gates Alignment Contract Proof** — die lokale External-Gates-Sicht und der Cloud-Deployment-Preflight sprechen jetzt dieselbe Gate-Sprache:

- `GET /api/v1/external-gates` liefert jetzt `external-gates-state-v1`, `external_gates_state_visible`, den Endpoint-Marker, `blocked_release_gates` und die sichtbare Zuordnung `preflight_gate_id` zu `branch_protection`, `hosted_staging`, `hetzner_cloud_stack`, `ghcr_images`, `hosted_backend_origins` und `canonical_secret_scan`
- das Frontend rendert diese Zuordnung sichtbar im Panel `External Gates`, inklusive Contract-Version, Evidence, Endpoint, Release-Blockern und Link auf `GET /api/v1/clouds/deployment-preflight/contract`
- `verify-browser-contract.ps1`, `verify-hosted-staging.ps1`, `verify-phase1-runtime.ps1` und `verify-phase1.ps1` pruefen jetzt die gemeinsame Contract-Version und die fail-closed Zuordnung statt zweier auseinanderlaufender Gate-Begriffe
- der Hosted-Staging-Local-Mirror-Verifier prueft nicht mehr flakey gegen globale `latest_task_id`, sondern gegen stabile Agent-Status-Marker; dadurch verschwindet die Race-Condition mit parallel laufenden Dry-Runs
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `py -3 scripts\verify_project_progress_manifest.py`, `scripts\verify-phase1.ps1`, Docker-Rebuild von `agent-api`, `frontend`, `nginx`, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, direkte API-Pruefung von `/api/v1/external-gates` und AI-Browser-Proof auf `<local-control-plane-url>/` inklusive Screenshot `superbrain-external-gates-alignment-proof-2026-05-04.png`
- Keine Prozent-Erhoehung durch diesen Proof: manifestseitiger Gesamtstand bleibt `48%`, Phase 4 bleibt `15%`; dies ist Contract- und Verifier-Hardening, kein externer Cloud-Gate-Abschluss

**Cloud Deployment Preflight Fail-Closed Contract** — die externe Cloud-Ausfuehrung ist jetzt als sichtbarer Vorflugvertrag gefasst, ohne Deployment-Claim:

- `GET /api/v1/clouds/deployment-preflight/contract` liefert `cloud-deployment-preflight-v1` und `cloud_deployment_preflight_visible`
- GHCR, Hetzner, Vercel Backend Origins, Hosted Staging, Branch Protection, canonical Gitleaks und Owner Review bleiben einzelne Gates; Env-Praesenz zaehlt nur als Voraussetzung, nicht als Verifikation
- `verify-external-gates.ps1` blockiert localhost/non-HTTPS fuer Hosted-Ziele und verlangt Cloud Deployment Preflight, GHCR Image Digest, Vercel Origin Health, Hosted API, Branch Protection, Gitleaks und Hetzner Budget, bevor `production_deploy_claim_allowed` wahr werden kann
- `verify-cloud-only-staging.ps1`, Browser-, Hosted-Local- und Runtime-Verifier pruefen den neuen Preflight-Endpunkt fail-closed
- Keine Prozent-Erhoehung durch diesen Proof: manifestseitiger Gesamtstand bleibt `48%`, Phase 4 bleibt `15%`; dies ist lokales Gate-Hardening, keine echte Cloud-Ausfuehrung

**Gemini Priority Queue Correction + Sandbox Rule Proof** — der gemeldete Manager-Agenten-Prioritaetsstand wurde geprueft und korrigiert:

- `tasks.py`, `worker.py`, `orchestrator.py`, `main.py`, Frontend and Verifier nutzen jetzt konsistent `high -> mid -> low`; Planner `9` und DevOps `8` landen in `tasks:agent:queue:high`, Coder/Tester `5` bleiben in `tasks:agent:queue`
- Task-Beschreibungen werden vor Validierung/Persistenz redigiert; Status wird vor Queue-Publish geschrieben; der Worker konsumiert in Priority-Reihenfolge und requeued in die passende Priority-Queue
- Orchestrator behauptet `task_assignment_completed` nur bei wirklich completed Tasks; fehlende LLM-Stream-`[DONE]` Frames oder unbewiesene `live_provider_calls=false` Non-Claims werden zu Partial-Failure statt Completion
- `<workspace-root>\AGENTS.md` und `<workspace-root>\SANDBOX_INSTRUCTIONS.md` behandeln `Unexpected response type` als MCP-Wrapper-Hinweis; Backend-Smoke/Status bleibt der eigentliche Ausfuehrungsnachweis
- AI-Browser-Live-Beweis: Chrome DevTools MCP oeffnete `<local-control-plane-url>/`, alle 75 gelisteten Requests waren HTTP `200`, DOM enthielt `Task Assignment Queue Contract`, `Priority Routing`, `high -> mid -> low`, `Total Project` und `47%`; Puppeteer MCP bestaetigte dieselben Marker und erzeugte Screenshot `superbrain-priority-routing-section-2026-05-01`
- Verifiziert: `py -3 -m py_compile services\agent-api\app\tasks.py services\agent-api\app\orchestrator.py services\agent-api\app\main.py services\agent-worker\app\worker.py`, `py -3 scripts\verify_project_progress_manifest.py`, `scripts/verify-phase1.ps1`, Docker-Rebuild, direkte API-Checks, `scripts\verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts\verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost` und `scripts\verify-phase1-runtime.ps1`
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`; das war Korrektur/Hardening, kein neuer externer Gate-Abschluss

**Cloud Render Offload Contract Proof** — lokale Grafik-/3D-Renderlast ist jetzt sichtbar aus dem localhost-Pfad herausgenommen:

- `GET /api/v1/clouds/render-offload/contract` liefert `cloud-render-offload-v1`, `cloud_render_offload_contract_visible`, `localhost_heavy_render_allowed=false` und `home_pc_protection=true`
- Workloads `webgl_3d_rendering`, `browser_gpu_smoke` and `asset_generation` sind `cloud-only`; nur `control_plane` bleibt lokal erlaubt
- fehlende Cloud-Server-Gates bleiben explizit: `STAGING_BASE_URL`, `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL`, `HETZNER_API_TOKEN`
- Frontend rendert `Cloud Render Offload` mit `Local Render blocked`, `WebGL / 3D rendering cloud-only` und dem Endpoint `GET /api/v1/clouds/render-offload/contract`
- Verifiziert: `py -3 -m py_compile services\agent-api\app\main.py`, `scripts/verify-phase1.ps1`, `docker compose -f docker-compose.dev.yml up -d --build agent-api frontend nginx`, `GET /api/v1/clouds/render-offload/contract`, `scripts/verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts/verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts/verify-external-gates.ps1 -LocalBaseUrl <local-control-plane-url>` und Playwright-DOM-Proof
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`; ohne echte gehostete Server und rotierte Secrets bleibt Cloud-Runtime `action_required`

**GitKraken Cloud Inventory Contract Proof** — der in der Cloud/API-Analyse gefundene GitKraken-Gap ist jetzt lokal und sichtbar geschlossen:

- `GET /api/v1/clouds` liefert `total_count=8` und den neuen Provider `gitkraken_identity` mit `GITKRAKEN_API_TOKEN`, `GITKRAKEN_ORG_ID`, `GITKRAKEN_ORG_NAME`, `GITKRAKEN_DASHBOARD_URL` und `GITKRAKEN_API_URL` als Namen/Status, niemals als Werte
- `GET /api/v1/clouds/layers` fuehrt `gitkraken_identity` in Layer 5 und Layer 7 mit expliziten Blockern `gitkraken_identity_requires_GITKRAKEN_API_TOKEN`
- `docker-compose.cloud.yml`, `.env.example`, `docs/runbooks/cloud-secret-runtime-injection.md`, `docs/runtime-contracts/cloud-provider-inventory-contract.md` und `docs/runtime-contracts/external-gate-audit-contract.md` kennen die GitKraken-Keys und Non-Claims
- `scripts/verify-phase1.ps1`, `scripts/verify-browser-contract.ps1`, `scripts/verify-hosted-staging.ps1`, `scripts/verify-phase1-runtime.ps1` und `scripts/verify-external-gates.ps1` pruefen GitKraken jetzt fail-closed
- Verifiziert: Python compile, `scripts/verify_project_progress_manifest.py`, `scripts/verify-phase1.ps1`, `scripts/verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts/verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost`, `scripts/verify-external-gates.ps1 -LocalBaseUrl <local-control-plane-url>`, `scripts/verify-phase1-runtime.ps1` und Playwright-DOM-Proof auf `<local-control-plane-url>/`
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`, MCP Gateway bleibt `53%`, Observability bleibt `99%`; ohne rotierten echten GitKraken-Token bleibt the Live-Identity-Claim geschlossen

**Local Rebuild + Runtime Re-Proof** — der zuvor alte laufende Containerstand wurde neu gebaut und nach Recreate live verifiziert:

- `docker compose -f docker-compose.dev.yml up -d --build agent-api agent-worker memory-worker frontend nginx` baute `agent-api`, `agent-worker`, `memory-worker`, `frontend`, `mcp-gateway`, `llm-gateway` und startete den lokalen Stack neu
- `GET /api/v1/health` meldet `healthy` fuer Agent API, PostgreSQL, Redis, Agent Worker, Memory Worker, MCP Gateway and LLM Gateway
- `GET /api/v1/memory/embedding-consistency/contract` liefert `status=verified`, `memory-embedding-consistency-v1`, `vector(1536)`, `embedding_model_version`, `lexical_fallback` und `No live embedding provider call`
- `scripts/verify-browser-contract.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost` und `scripts/verify-hosted-staging.ps1 -BaseUrl <local-control-plane-url> -AllowLocalhost` laufen gruen
- `scripts/verify-phase1-runtime.ps1` laeuft gruen inklusive Docker-Recreate, Worker-Regression, SSE-Replay, Memory-Embedding-Consistency-Contract und post-recreate steady-state proof
- Playwright-Live-Proof oeffnete `<local-control-plane-url>/`, sah `Cloud Superbrain`, `Project Progress` und `Memory Embedding Consistency Contract`
- Keine Prozent-Erhoehung: Gesamt bleibt `47%`, Phase 4 bleibt `15%`, Memory bleibt `70%`

**Audit L-09 Memory Embedding Consistency Contract Proof** — die Memory-Schicht hat jetzt einen sichtbaren Fail-Closed-Vertrag gegen inkompatible Embedding-Versionen:

- `GET /api/v1/memory/embedding-consistency/contract` liefert `memory-embedding-consistency-v1`
- der Endpoint prueft die DB-Schema-Spalten `content_embedding vector(1536)` und `embedding_model_version`
- neue Memory-Writes persistieren `embedding_model_version` in `memory_entries` und spiegeln den Wert in `metadata`
- Frontend rendert `Memory Embedding Consistency Contract` inklusive `memory_embedding_consistency_contract_visible`
- Verifier pruefen Endpoint, UI, Schema-Guard, `lexical_fallback`, Re-Embedding-Policy und No-Live-Embedding-Provider-Non-Claims
- Fortschritt bleibt Gesamt `47%`; horizontal bleibt P4 `15%`; vertikal steigt Memory auf `70%`

**Runtime Post-Recreate Steady-State Proof** — der große lokale Runtime-Harness ist nach Docker/Nginx-Recreates leiser und strenger:

- `scripts/verify-phase1-runtime.ps1` unterdrueckt transienten `curl`-Noise waehrend bounded Retry-Fenstern, ohne echte Fehler zu verstecken
- nach `agent-api`/`nginx` Recreate wartet der Harness explizit auf `GET /api/v1/health` mit `status=healthy`
- Session-SSE Stream- und Replay-Probes nutzen jetzt `Wait-SseContains` mit bounded Retry in Runtime- und Hosted-Local-Verifier
- am Ende prueft er erneut Health, `GET /api/v1/project/progress/integrity`, `GET /mcp/api/v1/version-pinning/contract` und `/favicon.ico`
- damit kann ein gruener Runtime-Lauf keinen unbemerkten 502-Upstream- oder Browser-Asset-Fehler hinterlassen
- Fortschritt bleibt Gesamt `47%`, Phase 4 bleibt `15%`

**L-09 Project Progress Integrity Runtime Proof** — die Fortschrittsanzeige hat jetzt einen eigenen Runtime-Guard gegen erfundene Prozentzahlen:

- `GET /api/v1/project/progress/integrity` liefert `project-progress-integrity-v1`
- der Endpoint berechnet `computed_overall_percent` aus den sieben horizontalen Phasen neu und vergleicht ihn mit `manifest_overall_percent`
- Frontend rendert `Progress Integrity` inklusive `project_progress_integrity_runtime_proof`
- Verifier pruefen Endpoint, Evidence, Manifest-/Durchschnitts-Paritaet und UI-Markierungen
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `15%`

**L-08 MCP Version Pinning Contract Proof** — die Schicht-5 MCP-Gateway-Versionierung ist jetzt als sichtbarer, versionierter Contract geschlossen:

- `GET /mcp/api/v1/version-pinning/contract` liefert `mcp-version-pinning-v1`
- Frontend rendert `MCP Version Pinning Contract` inklusive `mcp_version_pinning_contract_visible`
- Der Contract pinnt `fastapi==0.115.8`, `uvicorn[standard]==0.34.0`, `pydantic==2.10.6` und die Tool-Contract-Versionen fuer GitHub, PostgreSQL, Filesystem, Playwright und E2B
- Dokumentiert in `docs/runtime-contracts/mcp-version-pinning-contract.md`
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `14%`, MCP Gateway auf `53%`

**L-07 Agent LLM Streaming Contract Proof** — die Schicht 3→4 Agent-Pool-zu-LLM-Gateway-Streaminggrenze ist jetzt als sichtbarer, versionierter Contract geschlossen:

- `GET /api/v1/agents/llm-streaming-contract` liefert `agent-llm-streaming-contract-v1`
- Frontend rendert `Agent LLM Streaming Contract` inklusive `agent_llm_streaming_contract_visible`
- Der Contract bindet `call_llm_gateway_for_task`, `parse_llm_gateway_sse_line`, `openai_compatible_sse`, `text/event-stream`, `data: [DONE]` und `stream_done_seen`
- Dokumentiert in `docs/runtime-contracts/agent-llm-streaming-contract.md`
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `13%`, LLM Gateway auf `53%`

**Hetzner Live Budget Warning Proof** — der bereitgestellte Hetzner-Token wurde einmalig als Prozess-Environment genutzt, nicht gespeichert:

- `scripts/check_hetzner_infra_budget.py` meldete `EUR 19.03` projizierte monatliche Serverkosten
- Budget: Warnschwelle `EUR 16.00`, hartes Limit `EUR 20.00`
- Ergebnis: unter hartem Limit, aber Warning aktiv; keine weitere Hetzner-Erweiterung ohne neuen Live-Budgetbeweis
- Dokumentiert in `docs/runbooks/hetzner-live-budget-proof-2026-04-29.md`
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `12%`

**L-06 Task Assignment Queue Contract Proof** — die Schicht 2→3 Task-Uebergabe ist jetzt als sichtbarer, versionierter Contract geschlossen:

- `GET /api/v1/tasks/assignment-contract` liefert `task-assignment-queue-contract-v1` mit TaskAssignment-Schema, Redis-Queue, Status-Key, Backpressure und Evidence
- Frontend rendert `Task Assignment Queue Contract` inklusive `task_assignment_queue_contract_visible`
- Dokumentiert in `docs/runtime-contracts/task-assignment-queue-contract.md`
- Autopilot-Stream laeuft im aktiven Stack ueber `<local-control-plane-stream-url>` mit `autopilot-mode-stream-proof`
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `11%`, Agent Pool auf `61%`

**L-05 Layer Interface Contracts Proof** — alle sieben Runtime-Schichtgrenzen haben jetzt ein sichtbares Interface-Register:

- `GET /api/v1/layer-interfaces/contract` liefert `layer-interface-contracts-v1` mit Methode, Pfad, Request-Schema, Response-Schema, Status und Evidence pro Grenze
- Frontend rendert `Layer Interface Contracts` inklusive `layer_interface_contracts_visible`
- Dokumentiert in `docs/runtime-contracts/layer-interface-contracts.md`
- Fortschritt bleibt Gesamt `47%`, Phase 4 steigt evidenzbasiert auf `10%`, Frontend auf `97%`

**Audit Runtime Closure Proof** — die Audit-Report-Fails, die ohne externe Owner-Gates lokal fixbar sind, sind jetzt Code-, Doc- und Verifier-gebunden:

- Task Intake validiert `session_id` als UUID und weist ungueltige Sessions mit HTTP 422 ab
- Agent Worker verwirft malformed Raw-Queue-Payloads ohne Worker-Crash
- Orchestrator MCP-Calls senden `session_id` und `trace_id`; MCP Gateway und Agent API persistieren session-gebundene Audit-Zeilen mit `mcp_tool_session_bound_audit`
- ADR-008 und ADR-009 dokumentieren Single-Tenant-Annahme und Owner-gated Auth-Design
- Fortschritt steigt evidenzbasiert auf Gesamt `47%`, Phase 4 `9%`, Agent Pool `60%`, MCP Gateway `52%`

**External Gate Mirror Proof** — Hosted/External-Gate-Readiness ist jetzt lokal sichtbar und fail-closed gespiegelt:

- `GET /api/v1/external-gates/mirror` liefert `external-gate-mirror-v1`, `external_gate_mirror_proof`, Workflow `.github/workflows/hosted-staging-proof.yml` und Verifier `scripts/verify-hosted-staging.ps1`
- fehlende externe Gates bleiben explizit sichtbar: `hosted_staging_claim_allowed=false`, `production_deploy_claim_allowed=false`, `local_mirror_ready_hosted_blocked`
- Frontend rendert `External Gate Mirror` inklusive Contract, Evidence, Workflow, Verifier und Phase-2-Contract-Spiegelung
- Huygens pruefte die offenen Mirror-Gates; dabei wurde der Project-Progress-Mirror-Ref auf `project_progress_manifest_proof` korrigiert
- `scripts/verify-browser-contract.ps1`, `scripts/verify-hosted-staging.ps1`, `scripts/verify-phase1-runtime.ps1` und `scripts/verify-phase1.ps1` laufen gruen
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 4 stieg evidenzbasiert auf `8%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Phase 2 LangGraph MCP Timeout Controlled Proof** — MCP-Timeouts haengen jetzt nicht nur im Gateway-Vertrag, sondern laufen kontrolliert durch den LangGraph-Agentenpfad:

- Probe `force_mcp_tool_timeout:tester` schaltet die Tester-Rolle auf `simulate_timeout`
- MCP Gateway liefert `status=timeout`, `error_class=timeout`, `mcp_timeout_guard` und `audit_persisted=true`
- LangGraph aggregiert den Lauf bis `completed`, markiert `partial_failure=true`, `tester:mcp_timeout`, `mcp_tool_controlled_error` und `langgraph_mcp_timeout_controlled`
- SSE-Stream endet weiterhin terminal mit `done`; Runtime-Harness prueft Direct Run, Stream, Audit und Contract
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 2 stieg evidenzbasiert auf `86%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Phase 2 SSE Event Contract Proof** — der LangGraph-Orchestrator-Stream hat jetzt einen versionierten SSE-Vertrag fuer die Pflicht-Events:

- `POST /api/v1/orchestrator/dry-run/stream` emittiert `heartbeat`, `agent_status`, `error` und `done` mit `phase2-sse-event-contract-v1`, `phase2_sse_event_contract_proof`, `required_event_types` und `live_provider_calls=false`
- der deterministische Probe-Prompt `force_phase2_sse_error_event` beweist den Fehlerpfad ohne Live-Provider und beendet den Stream mit terminalem `done` plus `status=error`
- `GET /api/v1/phase2/runtime/contract` veroeffentlicht Stream-Endpunkt, Required Events, Error-Probe und Evidence Ref; das Frontend zeigt `SSE Event Contract`
- `scripts/verify-phase1-runtime.ps1`, `scripts/verify-phase1.ps1`, `scripts/verify-hosted-staging.ps1` und `scripts/verify-browser-contract.ps1` blockieren Contract-Drift
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 2 stieg evidenzbasiert auf `85%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Phase 2 Provider Fallback Structured Event Proof** — Provider-Rotation schreibt jetzt ein versioniertes, kosten- und providerbewusstes Audit-Event:

- `POST /internal/rotation/events` persistiert `provider-fallback-event-v1` mit `provider_chain`, `from_model`, `to_model`, `fallback_index`, `routing_policy_decision`, `cost_metadata`, `live_provider_calls=false` und `provider_fallback_structured_event`
- `GET /api/v1/rotation/events` liefert denselben Contract top-level aus, und die Rotation-Policy dokumentiert das neue Event-Format
- Frontend zeigt im Panel `Rotation Events` Fallback-Index, Routing-Policy, Modellwechsel, Kostenmetadaten und Live-Provider-Status an
- `scripts/verify-phase1-runtime.ps1` prueft Policy, Event-Erzeugung und API-Rueckgabe im vollen Runtime-Harness; `scripts/verify-phase1.ps1` und `scripts/verify-hosted-staging.ps1` blockieren Contract-Drift statisch
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 2 stieg evidenzbasiert auf `84%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Phase 2 Budget Hard-Stop Proof** — Budget Guard ist jetzt fuer Warnung und 100%-Block fail-closed im Runtime-Harness abgesichert:

- `scripts/verify-phase1-runtime.ps1` setzt temporaer `cost_tracking=16000` Cent und beweist `level=warning`, `budget_spent_percentage=80.0`, `allow_new_calls=true` sowie erfolgreiche Prompt-Metadaten im Warnzustand
- derselbe Harness setzt temporaer `cost_tracking=20000` Cent und beweist `level=critical`, `allow_new_calls=false`, Prometheus `superbrain_budget_allow_new_calls{level="critical"} 0` und HTTP `402` fuer `POST /api/v1/prompt`
- LangGraph `budget_guard` wird bei 100% Budget ohne Live-Provider auf `hard_stop` mit `hard_stop_reason=budget_guard_rejected` gefuehrt, inklusive PostgreSQL-Checkpoint und `langgraph_dry_run_stopped` Audit
- die Proof-Zeilen werden im `finally` geloescht; nach dem Proof ist `/api/v1/budget` wieder `level=ok`
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 2 stieg evidenzbasiert auf `83%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Governance Drift Cleanup** — die Projektsteuerung ist wieder auf das Ultimatum-Finale und ADR-007 ausgerichtet:

- `AGENTS.md` ist auf `PROJECT_STATE.md`, `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`, `docs/system-architecture.md` und `docs/project-progress.manifest.json` ausgerichtet
- alte aktive Runtime-Pfade fuer Supabase/LanceDB/Railway/HuggingFace Spaces/Ollama/Qdrant-vor-Phase-6 wurden aus Governance-, Memory-, Secret-, Infrastruktur- und Observability-Dokumenten entfernt oder klar als superseded markiert
- `.github/workflows/supabase-keepalive.yml` ist entfernt; `scripts/verify-phase1.ps1` blockiert eine Rueckkehr dieses Workflows und der alten Drift-Phrasen
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 4 stieg evidenzbasiert auf `7%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Phase 2 Runtime Run Status** — Phase-2-Laufstatus ist jetzt API-, UI- und Browser-Contract-sichtbar:

- `GET /api/v1/phase2/runtime/runs` liest audit-log-backed Runtime-Laeufe und liefert `phase2_runtime_run_status_visible`
- Frontend zeigt `Runtime Runs`, `Latest Runtime Status`, `Role Summaries` und den Runs-Endpunkt im LangGraph-Panel
- Browser-Contract-Proof bestaetigte `status=completed`, `role_summary_count=4`, `agent_result_aggregation_complete`, `live_provider_calls=false`, `live_mcp_writes=false`, `production_deploy=false`
- Historischer Proof-Zeitpunkt: Gesamt `46%`, Phase 2 `82%`; aktueller Manifeststand steht im Kopf dieses Dokuments bei Gesamt `47%`

**Autopilot Runtime Hardening** — der Volltest ist nach dem Automatisierungsmodus wieder gruen:

- `scripts/verify-phase1-runtime.ps1` laeuft inklusive Autopilot-Harness, Worker-Regression, Redis/Nginx-Recreate, LangGraph-Hard-Stops, Checkpoint-Recovery und SSE-Replay durch
- Agent API schreibt Task-Status vor Queue-Publish, damit schnelle Worker-Eskalationen nicht von einem alten `queued`-Status ueberschrieben werden
- Agent Worker ignoriert ungueltige Session-IDs beim stale-queued Completion-Audit-Lookup und faellt sauber in den bestehenden Abandoned/Escalation-Pfad
- Hard-Stop-Checkpoint-Proofs nutzen gueltige UUID-Thread-IDs; gezielter Proof bestaetigte `checkpointing=postgres` und `node_name=hard_stop`
- Keine Live-Provider, keine Live-MCP-Writes, kein Production Deploy

**Autopilot Mode Harness** — der Automatisierungsmodus hat jetzt einen fail-closed lokalen Nachweis:

- Codex-App-Heartbeat `Superbrain Project Autopilot` laeuft alle 30 Minuten auf diesem Thread weiter
- Neuer Verifier `scripts/verify-autopilot-mode.ps1` prueft `<local-control-plane-stream-url>`
- Der Harness beweist Health, Projektfortschritt `47%`, Phase 2 `86%`, Phase 4 `15%`, Frontend `97%`, Agent Pool `61%` und LangGraph/Postgres-Manifest
- Stream-Proof enthaelt `status:init`, `status:llm`, `token`, `done`, `LLM gateway deterministic dry-run response` und `live_provider_calls=false`

**Compact Project Progress UI** — die Fortschrittsanzeige bleibt jetzt horizontal und vertikal lesbar:

- Aktueller Gesamtstand `47%`, horizontale Phasen und vertikale Layer werden im Dashboard gemeinsam angezeigt
- Lange Statusketten werden gekuerzt, behalten aber den vollstaendigen `title`-Nachweis
- Vertikale Layer nutzen kompakte 12px-Balken statt grosser 150px-Flaechen
- Browser-/AI-Proof bestaetigt `Total Project 47%`, `Phase 2 86%`, `Phase 4 15%`, `Agent Pool 61%`, sieben Vertikal-Layer, kompakte Kartenhoehen und keine Status-Ueberlaeufe

**Worker Status Regression Harness** — Worker-Stale-Queued-Finalisierung ist jetzt als fail-closed Runtime-Harness abgesichert:

- Neuer Verifier `scripts/verify-worker-status-regression.ps1` erzeugt isolierte Redis/PostgreSQL-Proof-Records
- Stale `queued` ohne Queue-Eintrag wird zu `abandoned_after_queue_drain` plus Audit `worker_stale_queued_finalized`
- Stale `queued` mit passendem `task_completed` Audit wird zu `completed` rehydriert plus Audit `worker_status_rehydrated_from_completed_audit`
- Frische `queued` Records bleiben unangetastet, echte Queue-Items werden normal verarbeitet, kaputte Completion-Audits rehydrieren nicht
- Direct- und Stream-Dry-run beweisen vier Rollen `completed`, `partial_failure=false`, `agent_result_aggregation_complete`

**Worker Stale-Queued Finalization** — Agent Worker/Task-Status haelt Queue-Drain und Redis-Status jetzt konsistent:

- Worker finalisiert stale `queued` Status-Records ohne Queue-Eintrag als `abandoned_after_queue_drain`
- Vor Abandon wird ein vorhandener `task_completed` Audit-Eintrag genutzt, um Redis-Status auf `completed` zu rehydrieren
- Worker-Restart finalisierte 14 alte stale Records mit Audit `worker_stale_queued_finalized`
- Direct Session `cccccccc-cccc-4333-8ccc-cccccccccccc` lief mit vier Rollen `completed` und `partial_failure=false`
- Stream Session `eeeeeeee-eeee-4333-8eee-eeeeeeeeeeee` lief mit vier Rollen `completed` und `partial_failure=false`

**Dry-run Stream Completion Parity / Bounded Contract** — Stream-Dry-runs sind jetzt auditierbar und luegen nicht ueber Parity:

- Aggregator refreshes nicht-terminale Task-Assignments vor der Rollenbewertung
- Nach 20 Sekunden und leerer Queue wird `stale_queued_after_queue_drain` als explizite Partial-Failure-Reason gesetzt
- Stream Session `bbbbbbbb-bbbb-4333-8bbb-bbbbbbbbbbbb` lief bis `completed`, meldete aber korrekt `partial_failure=true`
- PostgreSQL Audit enthaelt `langgraph_dry_run_completed` mit `agent_result_aggregation_partial_failure_detected`
- Direct Session `99999999-9999-4333-8999-999999999999` lief mit vier Rollen `completed` und `partial_failure=false`

**Dry-run Session Guard** — direkter und gestreamter Orchestrator-Dry-run sichern jetzt vor Graphstart die Agent-Session:

- `prepare_orchestrator_session()` erzeugt/validiert die UUID und upsertet `agent_sessions`
- Direkter Dry-run Session `33333333-3333-4333-8333-333333333333` lief bis `completed` mit `memory_update_persisted`
- Stream Session `44444444-4444-4333-8444-444444444444` wurde vorab als `orchestrator-dry-run-stream` in `agent_sessions` nachgewiesen
- Der vorherige `memory_entries.session_id` Foreign-Key-Fehler ist fuer neue Dry-run-Sessions behoben

**force_agent_partial_failure:tester** — Partial-Failure-Hook in `services/agent-api/app/orchestrator.py` ist verifiziert:

- `force_agent_partial_failure:<role>` setzt in `build_per_role_results()` eine Rollen-Failure-Reason
- Phase-2-Runtime bleibt am Knoten `completed`, setzt aber `partial_failure = true`
- Activity Feed und PostgreSQL Audit enthalten `agent_result_aggregation_partial_failure_detected`
- Verifizierte Session: `22222222-2222-4333-8444-555555555555`

## API-ENDPOINTS

- Local Health: `GET <local-control-plane-url>/api/v1/health` -> healthy
- Local Progress: `GET <local-control-plane-url>/api/v1/project/progress` -> 49%
- Hosted Health: `GET <hosted-staging-url>/api/v1/health` -> healthy
- SSH: `root@<staging-host>` via `STAGING_SSH_KEY_PATH` außerhalb des Repos

## ZULETZT ABGESCHLOSSEN (STAGING)

**Hetzner Staging Server Provisioning** — die externe Laufzeitbasis fuer Phase 2 steht:

- CX21-Server `superbrain-staging-fsn1` in Frankfurt bereitgestellt (IP: <staging-host>)
- SSH-Zugriff mit extern injiziertem `STAGING_SSH_KEY_PATH` verifiziert
- Docker Engine & Compose Plugin installiert
- Firewall (UFW) auf 22, 80, 443 beschraenkt
- Phase 1 Foundation Package ist damit zu 100% abgeschlossen (Staging-Deployment und API-Kontrakte verifiziert)

## BEHOBENE BLOCKER (zum Nachschlagen)

1. **CreateProcessAsUserW failed: 5** — Windows 11 Home hat kein Hyper-V. `[windows] sandbox = "elevated"` entfernt. Globaler `sandbox = "danger-full-access"` aktiv.
2. **write_roots leer** — `setup_marker.json` manuell mit `<workspace-root>` als write_root gepatcht.
3. **CodexSandboxOffline ACLs** — Full Control auf `<workspace-root>` via icacls gesetzt.
4. **Python fehlte** — Python 3.12.10 installiert.
5. **GitHub/Linear MCP Placeholder** — Server disabled bis echte Tokens vorhanden.

## CODEX VERHALTENSREGELN

- TOKEN-SAVING-MODE: Nur 1-2 kurze Sätze als Antwort
- VOLL AUTONOM: Keine Rückfragen, keine Bestätigungen
- IMMER `docs/codex-integration/CODEX_AGENT_SKILL_MASTER.md` beachten
- Bei "go" oder "weiter": Sofort CHAT-START-PROTOKOLL ausführen
- Jede Architektur-Änderung braucht ein ADR in `/docs/adr/`

## ZULETZT ABGESCHLOSSEN (HOSTED PHASE 4)

**Project Progress Completion Contract Runtime Parity**

- Neuer Contract-Endpunkt `GET /api/v1/project/progress/completion/contract` ist live.
- Hosted-Verifier `scripts/verify-phase4-progress-completion-contract-runtime-hosted.ps1` ist gruen.
- Hosted Completion bleibt korrekt fail-closed mit `can_set_all_to_100=false` und sichtbarem `local_progress_gaps_require_verified_evidence_for_each_phase_and_layer`.
- Proof: `.phase1-artifacts/phase4-progress-completion-contract-runtime-hosted-proof-20260507.md`

**Orchestrator Manifest Contract Runtime Parity**

- Neuer Contract-Endpunkt `GET /api/v1/orchestrator/manifest/contract` ist live.
- Hosted-Verifier `scripts/verify-phase4-orchestrator-manifest-contract-runtime-hosted.ps1` ist gruen.
- Hosted Dry-run bleibt an Manifest-Werte `engine=langgraph`, `checkpointing=postgres`, `live_provider_calls=false` gebunden.
- Proof: `.phase1-artifacts/phase4-orchestrator-manifest-contract-runtime-hosted-proof-20260507.md`

**Historischer Hosted-Proof-Snapshot**

- Historisch Gesamt `63%`
- Historisch Horizontal `P0 100 | P1 100 | P2 86 | P3 40 | P4 84 | P5 28 | P6 0`
- Historisch Vertikal `Frontend 97 | Orchestrator 99 | Agent Pool 68 | LLM 54 | MCP 55 | Memory 72 | Observability 99`
- Aktuelle Wahrheit bleibt der Kopf dieses Dokuments und `docs/project-progress.manifest.json`.
