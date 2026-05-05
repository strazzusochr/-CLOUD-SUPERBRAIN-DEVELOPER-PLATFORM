# CLOUD SUPERBRAIN — AKTUELLER PROJEKTSTAND (Auto-Loaded by Codex)

Letzte Aktualisierung: 2026-05-05 00:00 Uhr
══════════════════════════════════════════════════════════════════

## AKTUELLER PROJEKTANKER

- **Anchor ID:** `project-anchor-2026-04-30T00-49-26+02-00`
- **Anchor-Datei:** `PROJECT_ANCHOR.md`
- **Checkpoint:** `docs/project-checkpoint-2026-04-30.json`
- **Live-Snapshot:** `2026-04-30 00:49:26 +02:00`
- **Kernstand:** Localhost `8081` bleibt Dev-Control-Plane; Gesamtfortschritt laut bindendem Manifest `54%`; Phase 1 Foundation Runtime ist manifestseitig `100%`; Project Progress Integrity `verified`; Task-Assignment nutzt echte high/mid/low-Priority-Queues; Cloud Inventory umfasst Vercel, Hetzner, Cloudflare, GitHub, GHCR, Hugging Face, GitLab und GitKraken als nicht-geheime Provider-Oberflaechen; Cloud Render Offload und Cloud Deployment Preflight sind sichtbar; echtes Hosted HTTPS Staging auf `<hosted-staging-url>` ist verifiziert; External-Gate-Audit, GHCR-Digest, Branch-Protection, Hosted Backend Origins, canonical Gitleaks und Hetzner-Live-Budget sind jetzt evidenzbasiert geschlossen. Phase 4 enthaelt jetzt zusaetzlich dedizierte hosted Proofs fuer Orchestrator-Runtime-Paritaet, Fail-Closed-/SSE-Hardening, MCP-Safe-Envelope-/DevOps-Dispatch, Public-Dashboard-/Session-Stream-Paritaet sowie Observability-/Runtime-Truth-Paritaet. Phase 5 hat den ersten workflow-gebundenen Production-Candidate, einen dokumentierten immutable Good-Tag-Rollback-Drill, eine explizite `no-release`-Entscheidung, den candidate-gebundenen Handoff-Packet-Proof, den candidate-gebundenen Risk-Review-Proof und jetzt auch den candidate-gebundenen Post-Handoff-Stability-Watch- sowie Promotion-Gate-Refusal-Proof; Production bleibt weiterhin nicht ausgerollt.

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

## AKTUELLER FORTSCHRITT: 54%

### Horizontal (nach Priorität)

| Prio | Status |
|------|--------|
| P0   | 100%   |
| P1   | 100%   |
| P2   | 86%    |
| P3   | 40%    |
| P4   | 30%    |
| P5   | 21%    |
| P6   | 0%     |

### Vertikal (nach Modul)

| Modul         | Status |
|---------------|--------|
| Frontend      | 97%    |
| Orchestrator  | 99%    |
| Agent Pool    | 61%    |
| LLM Gateway   | 53%    |
| MCP Gateway   | 54%    |
| Memory        | 70%    |
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

- **Release Readiness weiterziehen** — nach dem jetzt echten hosted executed rollback proof ist der naechste kleine evidenzbasierte Slice ein weiterer Phase-5-Candidate-/Operations-Beweis oberhalb des Rollback-Pfads
- danach folgen weitere `P4`-Slices statt eines Rollouts
- lokal und hosted bleiben weiterhin deterministische Proofs ohne Live-Provider und ohne Live-MCP-Writes; `production_deploy_claim_allowed=true` ist kein Deployment-Nachweis

## ZULETZT ABGESCHLOSSEN

**Phase 5 Executed Hosted Rollback Proof** — der aktuelle Production-Candidate hat jetzt einen echten rollback/restore Lauf gegen Hosted Staging:

- `.phase1-artifacts/phase5-executed-rollback-prod-candidate-20260505-rc1.md` bindet den Candidate an die real ausgefuehrte Selector-Umschaltung `IMAGE_TAG=staging -> IMAGE_TAG=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5 -> IMAGE_TAG=staging`
- `scripts/execute-phase5-executed-rollback.ps1` prueft zuerst die Remote-Architektur, validiert `arm64` in allen sechs GHCR-Manifests, schaltet dann den Host auf das immutable Tagset um, verifiziert Hosted Root/API/MCP/LLM Health und stellt danach den Candidate-Track wieder her
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `executed_rollback_proof`-Eintrag jetzt explizit als Candidate-Evidence und zeigt auf Workflow-Run `25392582005` fuer das echte Multi-Arch-Tagset
- `scripts/verify-phase5-executed-rollback.ps1` prueft Artefaktstruktur, immutable Selector, restore auf `IMAGE_TAG=staging`, remote `.env`, Hosted-Progress `overall=54`, `phase5=21` und Integrity `verified` fail-closed
- Verifiziert: `gh run watch 25392582005`, `powershell -ExecutionPolicy Bypass -File scripts\execute-phase5-executed-rollback.ps1 -ExpectedSha ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-executed-rollback.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `54%`, Phase 5 steigt auf `21%`; dies ist ein echter Release-Readiness-/Operations-Proof, aber weiterhin kein Rollout und kein Production-Deploy

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

**Phase 5 Executed Hosted Candidate Browser Proof** — der aktuelle Production-Candidate hat jetzt auch einen echten Live-Browser-Proof gegen die gehostete HTTPS-Zielseite:

- `docs/release-artifacts/prod-candidate-2026-05-05-rc1-browser-proof.md` bindet den Candidate an den live ausgefuehrten Browser-Proof mit Titel `Cloud Superbrain`, URL `https://188-34-191-140.sslip.io/`, sichtbaren Markern `Cloud Superbrain`, `Project Progress`, `External Gates`, `Error Response Contract` und `System Unavailable Fallback` sowie Screenshot-Handle `phase5-hosted-browser-proof-20260505`
- `scripts/verify-phase5-browser-proof.ps1` prueft Artefaktstruktur und Candidate-Link fail-closed
- `docs/release-artifacts/prod-candidate-2026-05-05-rc1.md` fuehrt den neuen `browser_proof` jetzt explizit als Candidate-Evidence
- Verifiziert: Live-Puppeteer-DOM-Proof, Screenshot `phase5-hosted-browser-proof-20260505`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-browser-proof.ps1`, `powershell -ExecutionPolicy Bypass -File scripts\verify-phase5-candidate.ps1`, `py -3 scripts\verify_project_progress_manifest.py`
- Fortschritt steigt evidenzbasiert: Gesamt bleibt `53%`, Phase 5 steigt auf `13%`; dies ist ein weiterer Release-Readiness-Proof, aber weiterhin kein Rollout und kein Production-Deploy

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
