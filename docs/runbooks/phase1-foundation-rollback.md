# Phase 1 Foundation Rollback

Stand: 2026-04-25
Status: Draft, applies before production deployment

## Scope

This rollback note applies to the Phase 1 local foundation scaffold:

- `docker-compose.dev.yml`
- `services/agent-api`
- `services/mcp-gateway`
- `apps/frontend`
- `infrastructure/nginx`
- `infrastructure/postgres/init`

## Rollback Before Deployment

Because no production deployment exists yet, rollback is a Git working-tree operation:

1. Stop any local containers if they were started.
2. Preserve logs or command output needed for debugging.
3. Revert the specific Phase 1 scaffold files through normal Git review tooling.
4. Re-run `scripts/verify-phase1.ps1` after any partial rollback.

## Rollback After First Staging Deployment

Once staging exists:

1. Pin images by immutable tag.
2. Keep the previous image tag in the deployment record.
3. Restore the previous tag and rerun health checks.
4. If PostgreSQL init changed, restore from the pre-deploy snapshot instead of attempting unsafe down migrations.

## Non-Claims

This runbook does not claim production readiness. It is the minimum rollback note required before the first Phase 1 runtime experiments.
