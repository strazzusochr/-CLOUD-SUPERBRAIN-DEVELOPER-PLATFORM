# Security CSP Report Contract

Status: implemented deterministic runtime contract
Date: 2026-05-13
Phase: Phase 3 - Product Surface & Security
Owner layer: Agent API / Frontend security surface

## Purpose

This contract makes Content-Security-Policy violation reports visible and audit-backed without adding a production incident-response claim or a third-party report collector.

## Runtime Endpoints

| Purpose | Method | Path | Evidence |
| --- | --- | --- | --- |
| CSP report contract | `GET` | `/api/v1/security/csp/contract` | `csp_report_contract_visible` |
| CSP report intake | `POST` | `/api/v1/security/csp/report` | `csp_report_audit_persisted` |

## Guarantees

- `Content-Security-Policy` includes `report-uri /api/v1/security/csp/report`.
- CSP reports are redacted before persistence through `redact_json`.
- Accepted reports create `event_type=security_csp_violation_reported` in `audit_log`.
- The frontend renders `CSP Report Contract`.
- No external CSP reporting service, browser session persistence, credential capture, or production incident workflow is claimed.

## Verification

- `scripts/verify-phase3-csp-report-contract.ps1`
- `scripts/verify-browser-contract.ps1`
