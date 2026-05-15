# Phase 5 Frontend Source Build Path Proof

Status: `verified`
release_id: `prod-candidate-2026-05-11-rc1`
overall_percent: `71`
phase_5_percent: `69`
frontend_percent: `99`
staging_only: `true`
production_rollout_claimed: `false`
ghcr_push_claimed: `false`
immutable_candidate_parity_claimed: `false`
frontend_container_image: `cloud-superbrain-frontend:source-staging`
frontend_pull_policy: `never`
backend_image_selector: `IMAGE_TAG=staging`
rollback_observed_after_invalid_selector_attempt: `yes`

## Scope

This proof closes the stale hosted-frontend gap without claiming production rollout or immutable candidate parity. The staging stack now has an explicit frontend source-build lane in `scripts/deploy-to-staging.ps1 -FrontendSourceBuild`, while backend/runtime services continue to use the existing `IMAGE_TAG=staging` selector.

## Evidence

- Local frontend production build passed: `npm run build --prefix apps/frontend`.
- Remote Docker readiness was proven with `docker info --format '{{.ServerVersion}}'` returning `29.4.2`.
- First invalid selector attempt used a non-existent backend image tag `staging-src-dba8cb012e8a`; the deploy script failed closed and restored the prior `IMAGE_TAG=staging` selector.
- Correct staging-only sync passed with `scripts\deploy-to-staging.ps1 -FrontendSourceBuild -ImageTag staging -KeyPath C:\Users\immer\.ssh\oracle_key -StagingBaseUrl https://188-34-191-140.sslip.io -StagingHostname 188-34-191-140.sslip.io`.
- Hosted browser contract passed on `https://188-34-191-140.sslip.io`.
- Hosted root now exposes `Cloud Superbrain`, `Project Progress`, `Live Agent Control`, and `Runtime Guard`.
- Remote compose proof shows `cloud-superbrain-frontend:source-staging` and `pull_policy: never` in `/app/docker-compose.frontend-source.yml`.

## Non-Claims

- No production deploy was executed.
- No Vercel production promotion was executed.
- No GHCR image was pushed.
- No live LLM provider call was introduced.
- No immutable candidate parity is claimed for this mutable staging source-build lane.
