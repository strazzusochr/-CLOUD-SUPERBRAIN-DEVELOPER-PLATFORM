# prod-candidate-2026-05-11-rc1 Security Review Queue Export Immutable Staging Proof

Date: 2026-05-14
Candidate: `prod-candidate-2026-05-11-rc1`
Image tag: `4364d31d7f1e6d0dec1f4d9f686715fec41d3b35`
Hosted base: `https://188-34-191-140.sslip.io`
Production rollout claimed: `false`

## Scope

This proof binds the active staging candidate to the Phase 3 Security Review Queue Export slice. It is a staging parity proof only and does not promote production.

## Runtime Contract

- `GET /api/v1/security/review-queue/export/contract` exposes `security-review-queue-export-v1`.
- `GET /api/v1/security/review-queue/export?format=csv&limit=80` returns read-only CSV from the safe Security Review Queue projection.
- Evidence refs: `security_review_queue_export_visible`, `security_review_queue_export_audit_persisted`, `security_review_redaction_enforced`, and `security_review_mutation_blocked`.
- Export audit rows persist redacted `security_review_queue_export_generated` metadata.

## Guards

- CSV columns are allowlisted.
- Raw details, prompt bodies, cookies, authorization headers, provider credentials, screenshots, raw files, live provider call claims, live MCP write claims, production rollout claims, and promotion claims are not returned.
- The Security Review Queue remains read-only; mutation attempts stay blocked.

## Local Verification

- `py -3 -m py_compile services\agent-api\app\main.py`
- `npm --prefix apps\frontend run build`
- `docker info --format '{{.ServerVersion}}'`
- `docker compose -f docker-compose.dev.yml up -d --force-recreate agent-api nginx`
- `scripts\verify-phase3-security-review-export.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-phase3-security-review-queue.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- `scripts\verify-browser-contract.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`

## Build And Deploy

- GHCR image tag: `4364d31d7f1e6d0dec1f4d9f686715fec41d3b35`
- Services inspected as published for `linux/arm64`: `agent-api`, `agent-worker`, `memory-worker`, `llm-gateway`, `mcp-gateway`, and `frontend`.
- Staging deploy: `scripts\deploy-to-staging.ps1 -ImageTag 4364d31d7f1e6d0dec1f4d9f686715fec41d3b35 -UseImageFilesystem`

## Hosted Verification

- `scripts\verify-phase3-security-review-export.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-browser-contract.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- `scripts\verify-hosted-staging.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Progress

- Overall remains `79%`.
- Phase 3 rises to `94%`.

## Non-Claims

No production rollout, release promotion, live provider call, live MCP write, provider billing proof, SOC/SIEM completeness proof, or secret exposure is claimed.
