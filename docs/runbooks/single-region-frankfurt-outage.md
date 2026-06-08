# Single-Region Frankfurt Outage Runbook

Stand: 2026-05-09
Status: Active baseline
Scope: Legacy Phase 1-5 single-region Hetzner runtime risk
Status: retired; active cloud target is Vercel/Fly.io/GHCR/Grafana

## Purpose

This runbook covers the explicit `F21` risk from the Cloud Superbrain analysis:
the retired Phase 1-5 runtime was single-region on Hetzner `fsn1`
Frankfurt to stay inside the 20 EUR/month infrastructure budget.

It does not claim automatic multi-region failover. It defines the manual
legacy operator path when Frankfurt or the historical primary Hetzner host is unavailable.

## Trigger

Use this runbook when one or more of these conditions is true:

1. Hetzner `fsn1` reports a regional incident.
2. The hosted runtime host is unreachable from two independent networks.
3. `GET /api/v1/health`, `/mcp/api/v1/health`, `/llm/api/v1/health`, or the
   root URL are unavailable for more than 5 minutes and host-level recovery
   is not possible.
4. Caddy or nginx cannot serve the public hostname because the primary host
   is unreachable.

## Constraints

1. Do not claim production recovery before hosted health is re-proven.
2. Do not create a larger server class without a budget note.
3. Do not move secrets through git, screenshots, or chat logs.
4. Do not mutate DNS until the fallback target has a passing health proof.
5. Do not promote staging to temporary production unless the owner explicitly
   approves the change.

## Decision Tree

1. Classify the incident:
   - provider regional outage
   - single host outage
   - ingress-only outage
   - deploy regression
   - database or Redis corruption
2. If it is a deploy regression, use `rollback-deploy.md`.
3. If it is a data issue, use `memory-recovery.md`.
4. If it is a provider/runtime outage, continue with this runbook.

## Manual Failover Procedure

1. Freeze releases:
   - pause promotion
   - stop non-essential deployment jobs
   - record current `IMAGE_TAG`
2. Capture evidence:
   - public root URL response
   - `GET /api/v1/health`
   - `/mcp/api/v1/health`
   - `/llm/api/v1/health`
   - Hetzner status or dashboard evidence without secrets
3. Select fallback target:
   - preferred: existing staging host if already healthy
   - alternative: smallest budget-compliant CX-class replacement in another
     available Hetzner location
4. Recreate runtime from the known-good immutable image tag:
   - use `docker-compose.cloud.yml`
   - use the existing remote `.env`
   - use the last verified immutable GHCR tag when available
5. Verify before traffic shift:
   - root URL returns success
   - Agent API health returns healthy
   - MCP Gateway health returns healthy
   - LLM Gateway health returns healthy
   - project progress integrity returns verified
6. Shift traffic only after health proof:
   - update Cloudflare DNS if Cloudflare manages the hostname
   - otherwise update the public hostname target or operator-facing URL
7. Record the event:
   - incident start time
   - cause classification
   - old target
   - fallback target
   - image tag
   - health proof timestamps
   - owner approval if staging was promoted

## Verification Requirements

The outage response is not complete until all of these are true:

1. fallback target is documented
2. immutable image tag or current `IMAGE_TAG` is documented
3. hosted root health is captured
4. Agent API, MCP Gateway, and LLM Gateway health are captured
5. DNS or URL target change is recorded, if changed
6. rollback path back to the normal primary host is documented

## Rollback To Normal Primary

1. Wait until Hetzner `fsn1` or the primary host is healthy again.
2. Recreate the primary stack from the same known-good image tag.
3. Run the same hosted health checks.
4. Shift DNS or operator URL back only after health proof.
5. Keep the fallback target until one additional verification window passes.

## Non-Claims

1. This runbook is not automatic failover.
2. This runbook is not proof that multi-region architecture exists.
3. This runbook does not approve a production promotion.
4. This runbook does not bypass the 20 EUR/month infrastructure budget.
