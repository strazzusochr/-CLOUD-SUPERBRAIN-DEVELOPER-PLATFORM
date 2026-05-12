# Current Cloud Handoff - 2026-05-12

Generated at: `2026-05-12T18:44:11Z`

Repository: `strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

Local repo path: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

## Purpose

This document is the current external-review handoff for the cloud/runtime state after PR #6 through PR #10. It separates verified facts from non-claims. No secret values are included.

## Current Repository State

- Base branch: `chore/repo-bootstrap`
- Final handoff documentation branch: `codex-current-cloud-handoff-final-20260512`
- Current post-merge head: `0b54ede8f234e48f097e9d498951f50a48729d02`
- PR #6: merged, immutable candidate/staging parity correction.
- PR #7: merged, production image tag publishing is now gated before `build-and-push`.
- PR #8: merged, current cloud handoff and review/runbook truth-state reconciliation.
- PR #9: merged, GitHub checkout/setup/Gitleaks flow moved off Node.js 20 actions.
- PR #10: merged, Docker build/push actions moved off Node.js 20 actions.
- PR #7 URL: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/pull/7`
- PR #7 merge commit: `73f5825afe6c6ce052841ae2e96ab2bb406eb70e`
- PR #8 URL: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/pull/8`
- PR #8 merge commit: `52b6d4dcc3c1420dd33df2afe3b052fd9f49f1cd`
- PR #9 URL: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/pull/9`
- PR #9 merge commit: `7a5a77cc00a5a9d69dedc85a5c0f5422d79461ea`
- PR #10 URL: `https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/pull/10`
- PR #10 merge commit: `0b54ede8f234e48f097e9d498951f50a48729d02`
- Local worktree status before this document edit: clean and in sync with `origin/chore/repo-bootstrap`.

## Active Release Boundary

- Active release candidate: `prod-candidate-2026-05-11-rc1`
- Candidate source commit: `fc00a787b54399133a90158bb63f6228859b5c96`
- Candidate immutable image commit: `b0c2773b1d122745947315a8d39734d5a6c96d6b`
- Current merged repository head: `0b54ede8f234e48f097e9d498951f50a48729d02`
- Runtime image boundary remains the immutable `b0c2773b1d122745947315a8d39734d5a6c96d6b` service image set.
- PR #7 changed CI release safety. PR #8 through PR #10 changed documentation and CI workflow maintenance. They do not claim a new production runtime rollout.

## Active Cloud Surfaces

- Hetzner hosted platform: `https://188-34-191-140.sslip.io/`
- Agent API health: `https://188-34-191-140.sslip.io/api/v1/health`
- MCP gateway health: `https://188-34-191-140.sslip.io/mcp/api/v1/health`
- LLM gateway health: `https://188-34-191-140.sslip.io/llm/api/v1/health`
- Project progress integrity: `https://188-34-191-140.sslip.io/api/v1/project/progress/integrity`
- Vercel frontend preview: `https://frontend-seven-psi-78.vercel.app/`

## CI Evidence

Main deploy run:

```text
run_id=25753246471
workflow=main-deploy
url=https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/actions/runs/25753246471
head_sha=0b54ede8f234e48f097e9d498951f50a48729d02
conclusion=success
```

Job results:

```text
verify=success
build-and-push mcp-gateway=success
build-and-push memory-worker=success
build-and-push frontend=success
build-and-push agent-api=success
build-and-push agent-worker=success
build-and-push llm-gateway=success
production-gate=skipped
```

`production-gate=skipped` is expected for the staging push. For `workflow_dispatch deploy_environment=production`, `build-and-push` now waits for `production-gate` before production tags can be published.

CI maintenance proof:

```text
checkout/setup actions use node24-capable major versions
Gitleaks scan uses official Gitleaks CLI v8.30.1 with checksum verification
Docker actions use node24-capable major versions
No old Node20 action references remain in .github/workflows
main-deploy run 25753246471 completed successfully after the migration
```

## Post-Merge Verification Evidence

Full release-candidate suite:

```text
scripts\verify.ps1 -Suite release-candidate -BaseUrl https://188-34-191-140.sslip.io -ReportOnly -MaxWaitSeconds 1
result: suite=release-candidate scripts=51 failed=0
```

Security excerpt from the same suite:

```text
gitleaks findings: 0
detect-secrets files: 23
detect-secrets findings: 33
secret-scan: no secret patterns found
```

The 33 detect-secrets findings are baseline hotspots, not newly printed secret values. They remain tracked as review hotspots and are not reproduced in this handoff.

External gate audit artifact:

```text
.phase1-artifacts\external-gate-audit-20260512-191344.json
status=verified
hosted_staging_claim_allowed=True
production_deploy_claim_allowed=True
gitlab_identity_claim_allowed=False
huggingface_identity_claim_allowed=True
gitkraken_identity_claim_allowed=False
missing_or_failed_gates=[]
```

Immutable staging parity:

```text
scripts\manual\verify-phase5-staging-immutable-parity.ps1 -RequireVerified -ReleaseId prod-candidate-2026-05-11-rc1 -CandidateSha b0c2773b1d122745947315a8d39734d5a6c96d6b -BaseUrl https://188-34-191-140.sslip.io -KeyPath <local-private-key>
result: [phase5-staging-immutable-parity] verified
```

Direct live HTTP probe using Python/OpenSSL with certificate verification disabled for status-code-only validation:

```text
HTTP 200 https://188-34-191-140.sslip.io/
HTTP 200 https://188-34-191-140.sslip.io/api/v1/health
HTTP 200 https://188-34-191-140.sslip.io/mcp/api/v1/health
HTTP 200 https://188-34-191-140.sslip.io/llm/api/v1/health
HTTP 200 https://188-34-191-140.sslip.io/api/v1/project/progress/integrity
```

PowerShell `Invoke-WebRequest` and Windows `curl.exe` both failed local TLS handling in this session. The hosted verifier suite and Python/OpenSSL probe succeeded against the same URLs.

## Production Safety State

Production rollout is not claimed.

Current verified safety property:

```text
production-gate runs before build-and-push for production dispatches
build-and-push requires verify success
build-and-push requires production-gate success or skipped
staging pushes continue when production-gate is skipped
```

This prevents production image tags from being pushed before the GitHub production environment approval gate.

## Explicit Non-Claims

- No production deployment was triggered from this handoff.
- No production runtime rollout is claimed.
- No new Hetzner runtime image rollout from merge commit `0b54ede8f234e48f097e9d498951f50a48729d02` is claimed.
- GitLab identity remains not claimable in the current external gate audit.
- GitKraken identity remains not claimable in the current external gate audit.
- Docker Desktop local readiness was not part of this post-merge verification pass.
- Secret values were not copied into this document.

## Next Valid Actions

1. Keep `prod-candidate-2026-05-11-rc1` as the active candidate until an explicit production promotion decision is made.
2. If production promotion is requested, dispatch `main-deploy` with `deploy_environment=production` and wait for the GitHub `production` environment approval before any production tag publish.
3. If Docker-dependent local gates are required, use `docker info --format '{{.ServerVersion}}'` as the only Docker readiness proof before running Docker gates.
4. Recheck baseline secret hotspots before any public release packet is exported outside the private repo context.
