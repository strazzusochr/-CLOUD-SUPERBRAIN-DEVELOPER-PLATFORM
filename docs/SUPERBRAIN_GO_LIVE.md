# CLOUD SUPERBRAIN GO-LIVE RUNBOOK

Stand: 2026-07-26
Status: owner-gated, read-only prepared

Dieses Runbook beschreibt den sicheren Weg vom DEV-ONLY Runtime-Proof in den
echten Cloud-Betrieb. Es ersetzt keine Projekt-Gates und ueberschreibt nicht die
Projekt-AGENTS.md. Codex darf daraus keine Cloud-Mutation, keinen Deploy, keinen
Registry-Push, keine Live-Provider-Aktivierung, keinen MCP-Write und keinen
Production-Claim ableiten. Kurzform: keine Cloud-Mutation, keinen Deploy, keinen Registry-Push,
keine Live-Provider-Aktivierung, keinen MCP-Write, kein Production-Claim.

## Current Truth

- Aktiver Cloud-Pfad: Vercel Frontend, Cloudflare-native Runtime, GHCR Registry, Grafana Cloud Observability.
- Retired/historical only: Fly.io, Hetzner, GitKraken, Oracle; sslip.io hosted proofs.
- Localhost bleibt DEV-ONLY und kann keine Hosted-, External-, Budget- oder Release-Gates schliessen.
- Aktuelles External-Audit: `docs/runtime-state/external-gate-audit-v2.json`,
  contract `external-gate-audit-v2`, status `blocked`.
- Sanitized Runtime Mirror: `docs/runtime-state/external-gate-summary.json`,
  contract `external-gate-summary-v2`.
- Aktives Zielgate: `cloudflare_native_zero_card_hosted_runtime`.
- Runtime Readiness Endpoint: `GET /api/v1/clouds/go-live-readiness`.

Die folgenden v1-Probes bleiben als bestaetigte Unterbeweise sichtbar, sind aber
nicht das aktive fehlende Zielgate:

- `hosted_agent_api_contracts`
- `github_branch_protection_current_verify`
- `vercel_backend_origin_health`

## Repo Version Baseline

Diese Versionen sind aus `apps/frontend/package.json` gespiegelt. Das ist keine
Latest-Claim und kein Upgrade-Auftrag.

- `next: 16.2.11`
- `react: ^19.2.7`
- `react-dom: ^19.2.7`
- `three: ^0.184.0`
- `@react-three/fiber: ^9.6.1`
- `@react-three/drei: ^10.7.7`
- `@react-three/postprocessing: ^3.0.4`
- `@playwright/test: ^1.60.0`
- `typescript: ^6.0.3`

## Required Owner Inputs

Diese Werte duerfen nur in privaten Secret-/Provider-Systemen gesetzt werden,
nicht im Repo, nicht in Logs, nicht im Chat:

- `STAGING_BASE_URL`: echte Vercel HTTPS Staging-URL.
- `CLOUDFLARE_STATEFUL_BASE_URL`: echte Cloudflare HTTPS Runtime-URL.
- `CLOUDFLARE_ACCOUNT_ID`: freigegebenes Cloudflare-Konto.
- `CLOUDFLARE_API_TOKEN`: presence-only; Wert nie ausgeben.
- `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL`:
  echte HTTPS Origins ohne retired Provider-Ableitung.
- `BRANCH_PROTECTION_TOKEN`: nur fuer Branch-Protection-Read/Verify/Apply nach Owner-Freigabe.
- `VERCEL_TOKEN`, `GITHUB_TOKEN`, `GHCR_TOKEN`, `GRAFANA_CLOUD_API_KEY`: nur presence-only pruefen, Werte nie ausgeben.

O2' verlangt mindestens `Workers Scripts:Edit`, `D1:Edit`,
`Durable Objects:Edit`, `Queues:Edit` und den freigegebenen
Workers-AI-Read-Pfad. R2 bleibt aus, bis Zero-Card-Aktivierung exakt belegt ist.

O6 ist im begrenzten Gateway-Pfad `owner_granted=true` und
`live_verified=true`. Das gibt `0%` Credit und setzt Layer 4 nicht auf 100.

## Safe Activation Sequence

1. Read-only Diagnose:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-go-live-readiness.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\owner-cloud-gate-activation.ps1`
   - Erwartung: PlanOnly, `blocked_external_gates`, keine Cloud-Mutation.

2. Owner stellt private Cloud-Konfiguration bereit:
   - Vercel Env: `STAGING_REWRITES_ENABLED=1`
   - Vercel Env: `STAGING_BASE_URL`, `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL`
   - Owner-Shell: `CLOUDFLARE_STATEFUL_BASE_URL`,
     `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`
   - Private Tokens nur in Secret Stores.

3. Hosted Proof nach Owner-Freigabe:
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-cloudflare-stateful-runtime.ps1 -BaseUrl https://<cloudflare-runtime-domain> -AllowHostedWrites`
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-browser-contract.ps1 -BaseUrl https://<staging-domain>`
   - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-external-gates.ps1`
   - Erwartung: Hosted HTTPS, keine localhost evidence fuer Cloud-Gates.

4. Gate-Oeffnung nur mit expliziter Owner-Freigabe und Beweis je Schritt:
   - live LLM provider activation
   - live MCP write activation
   - provider writes
   - registry publication
   - release promotion
   - production deployment

Secret output bleibt dauerhaft geschlossen.

## Non-Claims

- Kein Produktionsdeploy ist ausgefuehrt.
- Keine Cloud-Gates sind durch localhost geschlossen.
- Keine Live-LLM-Provider sind aktiviert.
- Keine Live-MCP-Writes sind aktiviert.
- Keine Registry-Publikation ist ausgefuehrt.
- Keine Fortschrittsprozente steigen durch dieses Runbook.

## Verification

Dieses Runbook wird statisch durch `scripts\verify-superbrain-go-live-runbook.ps1`
geprueft und in `scripts\verify-phase1.ps1` eingebunden.

Zusaetzlicher aktueller DEV-ONLY Stand: `scripts\verify-organism-topology.ps1`
beweist die lokale Organism-Topologie mit `151` Nodes und `308` Edges, inklusive
22 Seiten, 7 Layern und geschlossenen Non-Claims. Das ist kein Hosted-Proof und
oeffnet keine External-, Budget- oder Release-Gates.

`scripts\verify-workspace-data-sources.ps1` beweist zusaetzlich die lokale
22-Seiten-Datenquellen-Integritaet mit `32` API-like Refs, korrigierter
`GET /api/v1/models/capabilities`-Route und read-only
`GET /api/v1/files/local/contract`. Das ist ebenfalls DEV-ONLY und ersetzt keine
Vercel-/Cloudflare-/GHCR-/Grafana-Gates.

`scripts\verify-platform-ui-status-boundary.ps1` beweist lokal, dass Home,
Workbench, Games, Apps, Media, Docs-Output und AppShell keine Projektstatuswand,
keine Gate-Matrix und keine Project-Progress-Fetches rendern. Projektstand und
Gates bleiben in Evidence, Diagnostics, Organism und read-only Wiring getrennt.

`scripts\verify-llm-responses-contract.ps1` beweist lokal den
Responses-kompatiblen LLM-Gateway-Adapter: `GET /llm/api/v1/responses/contract`
liefert `llm-responses-adapter-contract-v1`, `POST /llm/v1/responses` bleibt im
dry-run auf `live_provider_calls=false`, `model_downloads=false` und
`audit_persisted=true`, und die Negativfaelle `stream=true -> 501` sowie
ungueltige `metadata -> 422` sind fail-closed. Das ist DEV-ONLY und aktiviert
keinen Live-Provider.

`scripts\verify-live-agent-steering-contract.ps1` beweist lokal den
Live-Agent-Steering-Pfad: `GET /api/v1/live-agents/contract`,
`POST /api/v1/live-agents/steer`, `POST /api/steer-agent`,
`GET /api/v1/live-agents/status` und Reset bleiben an
`llm-responses-adapter-contract-v1` gebunden. Runtime-Antworten spiegeln
`live_provider_calls=false`, `model_downloads=false`, `audit_persisted=true`
und `secret_output=false`; `unknown agent -> 404` und `empty message -> 422`
sind fail-closed. Das ist DEV-ONLY und aktiviert keinen Live-Provider.
