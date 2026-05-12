# Autonomous Agent Roster

Last updated: 2026-05-07
Project: `-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`

## Purpose

This file is the persistent roster for Codex autonomous multi-agent work in this repo.
It records every callable agent role, whether the role is launch-validated in this environment, and the fallback lane to use when native specialized launch is blocked.

## Persistent operating core

The standard autonomous team for this repo is a fixed five-slot operating core:

1. `manager` — Codex main thread, always active
2. `supervisor` — secondary supervision slot
3. `planner` — planning slot
4. `coder` — implementation slot
5. `tester` — verification slot
6. `devops` — deployment/runtime slot

Operational note:

- The logical core has five agent slots plus the Codex manager.
- In this desktop runtime, the observed stable child-thread ceiling is `4` concurrent subagents.
- Therefore the default live operating mode is:
  - Codex main thread as manager
  - live `supervisor`
  - live `coder`
  - live `tester`
  - live `devops`
  - persisted `planner` slot parked and reactivated when a live slot is freed or a planning-heavy task requires it

This avoids fake concurrency claims while preserving a fixed, repeatable team shape.

## Startup protocol

At every chat start:

1. Read `AGENTS.md`, `PROJECT_STATE.md`, `docs/project-progress.manifest.json`, `docs/verification-register.md`, and this file.
2. Use the smallest useful agent set that can advance the current task without leaving idle threads behind.
3. Prefer native specialized roles only when they are launch-validated in the current session.
4. If a specialized role is blocked by launcher/model drift, map the work onto a generic fallback lane:
   - `explorer` for scoped codebase inspection
   - `worker` for bounded execution work
   - `default` for planning, synthesis, and cross-cutting tasks
5. When local stack work is required, use the normal repo health flow first and treat localhost evidence as `DEV-ONLY`.
6. Never leave an agent waiting after the output has been consumed. Close completed or errored agents immediately.
7. If the same launcher failure repeats 3 times, mark the role blocked and continue with the documented fallback lane.
8. Default operating mode is the fixed five-slot core; if the child-thread ceiling blocks all five live subagents, keep `supervisor`, `coder`, `tester`, and `devops` live and keep `planner` persisted but parked.

## Agent hygiene rules

- Never keep completed agents open after their output is integrated.
- Never leave agents in `waiting for instructions` state between steps.
- Reuse `explorer` only for related narrow questions; otherwise close and respawn cleanly.
- Use at most the smallest batch that can advance work without creating idle threads.
- Record launcher failures here when they are structural rather than task-specific.

## Launch validation status

Validated in this session:

| Role | Status | Notes |
| --- | --- | --- |
| `default` | launch-validated | starts and completes normally |
| `explorer` | launch-validated | starts and completes normally |
| `worker` | launch-validated | starts and completes normally |

Attempted and currently blocked:

| Role | Status | Blocker |
| --- | --- | --- |
| `backend_platform` | launcher-blocked | specialized spawn path falls back to unsupported `gpt-4o` |
| `cloud_infra_devops` | launcher-blocked | specialized spawn path falls back to unsupported `gpt-4o` |
| `product_scope` | launcher-blocked | specialized launcher unstable; `gpt-4o` fallback and intermittent MCP handshake timeout |
| `qa_validation` | launcher-blocked | specialized launcher unstable; session init timeout observed |
| `security_anticheat` | launcher-blocked | specialized spawn path falls back to unsupported `gpt-4o` |
| `sentinel_runtime` | launcher-blocked | specialized spawn path falls back to unsupported `gpt-4o` |
| `game_design` | launcher-blocked | specialized spawn path falls back to unsupported `gpt-4o` |
| `gameplay_systems` | launcher-blocked | specialized spawn path falls back to unsupported `gpt-4o` |

Attempted and launcher-unstable:

- `sentinel_truth`
- `webgl_client`
- `multiplayer_netcode`

These roles remain part of the persistent roster. Until native launch validation succeeds, they should use the fallback lane documented below.

## Fallback lanes

| Intended role | Fallback lane | Why |
| --- | --- | --- |
| `backend_platform` | `worker` | bounded API / FastAPI / server implementation work |
| `cloud_infra_devops` | `worker` | deployment scripts and runtime operations |
| `product_scope` | `default` | planning, milestone shaping, doc synthesis |
| `qa_validation` | `explorer` + `worker` | proof gathering plus targeted fix execution |
| `security_anticheat` | `explorer` | review, abuse analysis, hardening checklists |
| `sentinel_runtime` | `explorer` | runtime failure analysis, metrics, failure mode review |
| `sentinel_truth` | `default` | claim verification, truth checks, contradiction checks |
| `webgl_client` | `worker` | frontend graphics code when needed |
| `game_design` | `default` | system / UX framing only when relevant |
| `gameplay_systems` | `worker` | interaction logic when relevant |
| `multiplayer_netcode` | `explorer` | protocol / synchronization review when relevant |

## Core team slots

### `supervisor`

- Preferred runtime type: `default`
- Purpose: second pair of eyes on plans, unsafe assumptions, missing proof, and completion gates
- Current live policy: keep live whenever autonomous work is active

### `planner`

- Preferred runtime type: `default`
- Purpose: task sequencing, risk tracking, and handoff shaping
- Current live policy: persisted by default; park this slot first when the runtime ceiling prevents all child threads from staying live together

### `coder`

- Preferred runtime type: `worker`
- Purpose: scoped code changes in a shared, non-destructive worktree
- Current live policy: keep live whenever execution work is active

### `tester`

- Preferred runtime type: `explorer`
- Purpose: verification, contradiction checks, proof collection, and regression spotting
- Current live policy: keep live whenever execution work is active

### `devops`

- Preferred runtime type: `worker`
- Purpose: deployment/runtime work, hosted verification, and health stabilization
- Current live policy: keep live whenever hosted/runtime work is active

## Role cards

### `backend_platform`

- Core strengths: APIs, FastAPI routes, service boundaries, runtime architecture, integration glue.
- Best uses in this repo: `agent-api`, orchestration contracts, task/session/audit surfaces, contract drift fixes.
- Constraints / not for: not the first choice for browser-only UI work or release gate evidence review.
- Inputs needed: target endpoint, affected files, runtime expectation, verifier surface.
- Evidence expected: changed server files, contract/runtime proof, green verifier output.
- Current activation: use `worker` fallback until native launcher is fixed.

### `cloud_infra_devops`

- Core strengths: deployment, CI/CD, cloud runtime, compose flows, environment wiring.
- Best uses in this repo: Hetzner staging sync, GHCR image flow, deploy scripts, runtime drift on hosted stack.
- Constraints / not for: not the first choice for app-only logic bugs.
- Inputs needed: target environment, deploy path, gate constraints, expected health/progress endpoints.
- Evidence expected: deploy logs, health checks, hosted verifier output, rollback note.
- Current activation: use `worker` fallback until native launcher is fixed.

### `product_scope`

- Core strengths: scope control, milestone framing, artifact structure, release narrative.
- Best uses in this repo: candidate artifact coherence, gate framing, release checklist coverage, next-step shaping.
- Constraints / not for: not the first choice for runtime debugging or API implementation.
- Inputs needed: current manifest truth, target phase, evidence set, unresolved gates.
- Evidence expected: updated decision doc, checklist coverage, no contradiction with manifest.
- Current activation: use `default` fallback until native launcher is fixed.

### `qa_validation`

- Core strengths: verifier strategy, regression hunting, runtime confirmation, failure reproduction.
- Best uses in this repo: proof scripts, runtime/API/browser verification, drift detection between docs and live state.
- Constraints / not for: not the first choice for large architecture refactors.
- Inputs needed: verifier target, reproduction steps, expected pass/fail condition, current truth.
- Evidence expected: failing and passing commands, concrete mismatch notes, updated proof artifacts.
- Current activation: use `explorer` plus `worker` fallback until native launcher is fixed.

### `security_anticheat`

- Core strengths: vulnerability review, abuse paths, permission minimization, misuse analysis.
- Best uses in this repo: secret handling, token scope review, unsafe write-path review, exposed debug surface checks.
- Constraints / not for: not the first choice for feature delivery.
- Inputs needed: auth path, secret boundary, write surface, risk hypothesis.
- Evidence expected: concrete risk statement, affected files/endpoints, mitigation path.
- Current activation: use `explorer` fallback until native launcher is fixed.

### `sentinel_runtime`

- Core strengths: runtime health, failure modes, recovery paths, performance and liveness checks.
- Best uses in this repo: stuck deploys, health/progress drift, queue/session/runtime failure surface audits.
- Constraints / not for: not the first choice for product or design tasks.
- Inputs needed: failing runtime path, metrics/log surface, expected steady-state behavior.
- Evidence expected: runtime symptom, root cause hypothesis, proof command, stabilized check.
- Current activation: use `explorer` fallback until native launcher is fixed.

### `sentinel_truth`

- Core strengths: claim validation, contradiction detection, source alignment, false-positive suppression.
- Best uses in this repo: progress truth, candidate truth, historical proof hygiene, non-claim enforcement.
- Constraints / not for: not the first choice for direct file implementation.
- Inputs needed: candidate claim, manifest truth, proof set, endpoints/files to compare.
- Evidence expected: contradiction list or explicit alignment statement with citations.
- Current activation: use `default` fallback until native launcher is stabilized.

### `webgl_client`

- Core strengths: frontend graphics, shaders, browser rendering, visual runtime behavior.
- Best uses in this repo: advanced frontend graphics only if the dashboard evolves beyond standard UI work.
- Constraints / not for: limited value for current API- and proof-heavy workload.
- Inputs needed: target scene/component, rendering bug, browser/runtime evidence.
- Evidence expected: visual change proof, browser behavior notes, no regressions.
- Current activation: use `worker` fallback until native launcher is stabilized.

### `game_design`

- Core strengths: mechanics design, player-facing system balance, interactive experience framing.
- Best uses in this repo: generally not primary; only relevant if the platform adds simulation or gameified flows.
- Constraints / not for: standard platform/API/deployment tasks.
- Inputs needed: interactive system brief, user goal, balance problem.
- Evidence expected: design rationale and interaction proposal.
- Current activation: use `default` fallback until native launcher is fixed.

### `gameplay_systems`

- Core strengths: mechanics implementation, interaction state machines, system rules.
- Best uses in this repo: only relevant if repo work adds interactive system logic beyond standard product UI.
- Constraints / not for: normal backend/cloud verification tasks.
- Inputs needed: system rules, state transitions, intended interaction behavior.
- Evidence expected: changed logic plus deterministic test/proof path.
- Current activation: use `worker` fallback until native launcher is fixed.

### `multiplayer_netcode`

- Core strengths: synchronization, state replication, protocol review, latency handling.
- Best uses in this repo: only relevant if real-time collaboration or multi-client sync becomes a current task.
- Constraints / not for: standard Phase 1-5 API and release-proof work.
- Inputs needed: concurrency model, sync path, transport/protocol assumptions.
- Evidence expected: protocol notes, failure mode analysis, test or simulation proof.
- Current activation: use `explorer` fallback until native launcher is stabilized.

### `default`

- Core strengths: planning, synthesis, cross-cutting reasoning, general delivery.
- Best uses in this repo: fallback orchestration, document consistency, contradiction cleanup, multi-surface coordination.
- Constraints / not for: use `explorer` or `worker` when the task is narrow and execution-focused.
- Inputs needed: task objective, file scope, expected proof.
- Evidence expected: integrated output, no unresolved contradictions, next safe step.
- Current activation: native and launch-validated.

### `explorer`

- Core strengths: fast codebase inspection, targeted questions, authoritative read-only findings.
- Best uses in this repo: trace drift, locate verifier mismatch, inspect contracts/routes/scripts before edits.
- Constraints / not for: do not assign blocking implementation work or overlapping write work.
- Inputs needed: exact question, narrow file/module scope, desired output shape.
- Evidence expected: concise findings with file references and risks.
- Current activation: native and launch-validated.

### `worker`

- Core strengths: bounded implementation, bug fixes, verifier updates, controlled execution work.
- Best uses in this repo: route fixes, script fixes, hosted proof updates, scoped documentation with a clear write set.
- Constraints / not for: avoid broad planning or fuzzy discovery tasks.
- Inputs needed: explicit ownership, target files, acceptance check, non-overlap rule.
- Evidence expected: changed files, commands run, pass/fail summary, rollback note if relevant.
- Current activation: native and launch-validated.
