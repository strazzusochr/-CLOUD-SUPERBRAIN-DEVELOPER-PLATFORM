# Executed Candidate Post-Rollback Provenance Revalidation

Status: `verified`
release_id: `prod-candidate-2026-05-05-rc1`
environment: `production-candidate`
base_url: `https://188-34-191-140.sslip.io`
revalidation_scope: `post_rollback_workflow_ghcr_and_runtime_provenance`
executed_at_utc: `2026-05-07T08:13:20Z`

## Goal

Record the executed candidate-scoped provenance revalidation after rollback and restore, tying the successful GitHub workflow and immutable multi-arch GHCR tag set back to the candidate without claiming rollout and without claiming that mutable hosted staging currently equals the immutable candidate tag set.

## Provenance Scope

1. GitHub Actions workflow `25392582005` remains `completed/success`
2. Workflow head SHA remains `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
3. Immutable GHCR tag set for the candidate remains available
4. Candidate image set remains multi-arch and valid for Hetzner arm64 staging
5. Candidate still carries explicit staging-parity-blocked proof after rollback restore
6. Hosted root and health stay reachable after the executed rollback/restore cycle

## Decision State

- Candidate status: `no-release`
- Provenance classification: `candidate_post_rollback_provenance_revalidation`
- Current progress carried in revalidation: `overall=70`, `phase5=67`
- Workflow source remained authoritative: `yes`
- Immutable tag set remained usable: `yes`
- Production claim: `forbidden`

## Verification

- GitHub Actions run `25392582005` remained `completed` with `conclusion=success`
- Workflow `head_sha` remained `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`
- Immutable GHCR tags for `agent-api`, `mcp-gateway`, `frontend`, `llm-gateway`, `agent-worker`, and `memory-worker` remained resolvable
- GHCR manifest indexes for the candidate remained multi-arch with `amd64` and `arm64`
- Candidate artifact still carried `staging_tag_parity_blocked_proof`
- Hosted root, Agent API, MCP, and LLM health remained reachable

## Results

- Candidate provenance remained revalidated after rollback restore: `yes`
- Workflow and immutable artifact remained authoritative: `yes`
- Staging parity block remained visible after rollback restore: `yes`
- Candidate remained usable for further release-readiness evidence: `yes`

## Non-Claims

- This is not a production rollout proof.
- This is not a live provider claim.
- This does not claim hosted staging currently equals the immutable candidate tag set.
- This does not override the current `no-release` decision.
