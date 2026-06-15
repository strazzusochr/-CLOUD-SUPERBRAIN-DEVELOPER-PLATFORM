## Projektstatus (evidence-based; DEV-ONLY bis Hosted-Gates offen)

Quelle der Prozentwerte: `docs/project-progress.manifest.json` (overall: `70%`).

### Checks

- ✅ LINT: `npm --prefix apps/frontend run lint` → Exit 0
- ✅ TYPE/BUILD: `npm --prefix apps/frontend run build` → Exit 0 (Types valid)
- ✅ E2E: `npm --prefix apps/frontend test -- --reporter=line` → `8 passed` (Exit 0)
- ✅ BROWSER (DEV-ONLY): `npm run verify:browser` → Exit 0
- ✅ HOSTED-LOCAL (DEV-ONLY): `npm run verify:hosted-local` → Exit 0
- ✅ BASELINE: `npm run verify` → Exit 0
- ✅ RUNTIME: `npm run verify:runtime` → Exit 0

### External Gates (BLOCKED; keine Fake-Credentials)

Aktueller Audit-Run (DEV-ONLY): `.phase1-artifacts/external-gate-audit-20260607-213309.json`

- ❌ `hosted_agent_api_contracts` → BLOCKED: `STAGING_BASE_URL` fehlt (echte HTTPS Hosted-Staging-Base-URL)
- ❌ `github_branch_protection_current_verify` → BLOCKED: `BRANCH_PROTECTION_TOKEN` fehlt (oder SSH-Fallback nicht konfiguriert)
- ❌ `vercel_backend_origin_health` → BLOCKED: `AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL` fehlen (echte HTTPS Origins)
- ❌ `fly_live_budget_check` → BLOCKED: `FLY_API_TOKEN` fehlt

Setup: `docs/external-gates-setup.md`

### Layer (L1–L7)

- ✅ L1 Daten & Speicher (DEV-ONLY verifiziert): Postgres/pgvector + Redis + Backup/Restore/Persistence Proofs via `verify:runtime`
- ✅ L2 Modelle & LLM-Gateway (DEV-ONLY verifiziert): deterministic dry-run, SSE + Routing Policy Proofs via `verify:runtime`
- ✅ L3 Agenten & Worker (DEV-ONLY verifiziert): LangGraph dry-run, agent-worker/memory-worker Proofs via `verify:runtime`
- ✅ L4 API & Gateways (DEV-ONLY verifiziert): agent-api + mcp-gateway Contracts/Surfaces via `verify:runtime` + `verify:browser`
- ✅ L5 Frontend & UI (DEV-ONLY verifiziert): Next.js Surfaces + Organism + Workbench via `verify:browser` + E2E
- ⚠️ L6 Cloud & Infrastruktur (teilweise): Compose/Nginx Guards verifiziert, Hosted Deploy Proof bleibt gated (External Gates)
- ⚠️ L7 Integration & Verification (teilweise): lokale Verifier grün, Hosted/Production Gate Claims bleiben blocked (External Gates)

### Status

Nicht `100% COMPLETE`: External Gates sind aktuell BLOCKED, weil echte HTTPS URLs/Tokens fehlen.

### Nächste Schritte (Owner/Operator notwendig)

- `STAGING_BASE_URL` setzen (echte Hosted Staging URL) und danach `npm run verify:external-gates` erneut.
- Vercel Origins setzen (`AGENT_API_BASE_URL`, `MCP_GATEWAY_BASE_URL`, `LLM_GATEWAY_BASE_URL`) und danach `npm run verify:external-gates` erneut.
- `BRANCH_PROTECTION_TOKEN` setzen und danach `npm run verify:external-gates` erneut.
- `FLY_API_TOKEN` setzen und danach `npm run verify:external-gates` erneut.
