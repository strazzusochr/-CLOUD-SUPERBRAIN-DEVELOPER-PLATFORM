# Active Security Evidence Bundle

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
source_commit_sha: `4a894c16d5f340b89ad1134da781d1c855d6ced5`
immutable_image_commit_sha: `4a894c16d5f340b89ad1134da781d1c855d6ced5`
production_rollout_claimed: `false`
bundle_status: `passed`
security_export_surface_count: `5`
overall_percent: `79`
phase_5_percent: `74`

## Scope

This proof binds the active RC1 immutable staging selector to a read-only security evidence bundle across these hosted export surfaces:

- `llm-audit` -> `llm-audit-export-v1`
- `mcp-audit` -> `mcp-audit-export-v1`
- `gateway-correlation` -> `gateway-correlation-export-v1`
- `auth-audit` -> `auth-audit-export-v1`
- `security-review` -> `security-review-queue-export-v1`

## Verification

- Local verifier syntax/load path: `scripts\verify.ps1 -Suite phase5 -Plan`
- Local proof: `scripts\verify-phase5-active-security-evidence-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost`
- Hosted proof: `scripts\verify-phase5-active-security-evidence-bundle.ps1 -BaseUrl https://188-34-191-140.sslip.io`
- Manifest proof: `py -3 scripts\verify_project_progress_manifest.py`
- Release-candidate proof: `scripts\verify-current-release-candidate.ps1 -BaseUrl https://188-34-191-140.sslip.io`

## Guarantees

- Each export contract is read-only and `audit_persisted=true`.
- Each export response carries its contract, evidence, export-audit, redaction, trace, and request headers.
- Each export access persists the matching redacted export audit event.
- The verifier scans contract, CSV, and recent-audit material for secret/raw-payload patterns.
- This proof does not claim a production rollout.
- This proof does not claim a release promotion.
- This proof does not claim live provider calls.
- This proof does not claim live MCP writes.
- This proof does not include secret values.
- This proof keeps the manifest percentages unchanged because the immutable runtime selector remains `4a894c16d5f340b89ad1134da781d1c855d6ced5`.
