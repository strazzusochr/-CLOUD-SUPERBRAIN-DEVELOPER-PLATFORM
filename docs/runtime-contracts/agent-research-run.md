# Agent Research Four-Role Run Contract

Status: DEV-ONLY gateway pipeline with bounded repository sources; hosted proof
still blocked.

## Runtime Surface

- Contract: `GET /api/v1/agent-run/contract`
- Runtime: `POST /api/v1/agent-run`
- Request: `{"goal":"string"}`
- Contract version: `agent-research-run-v3`
- Evidence ref: `agent_research_four_role_repo_sources_visible`
- Role contract: `agent-research-four-role-v1`
- Source contract: `agent-research-repo-source-v1`
- Source mode: `repo_allowlist_lexical`

## Fixed Source Boundary

The runtime can read only the three project-truth artifacts already baked or
read-only mounted into the Agent API:

1. `PROJECT_STATE.md`
2. `docs/project-progress.manifest.json`
3. `docs/codex-integration/autonomous-agent-roster.json`

The client supplies no path. All three configured artifacts must pass the fixed
layout, regular-file, symlink, encoding, and 512 KiB bounded-read guards before
the first Gateway call. A failure stops the run. Retrieval returns one to three
sources: lexical matches are ranked; a no-match run uses one explicitly marked
`baseline_fallback` instead of inventing a citation.

Only sanitized excerpts enter the model context. Source text is treated as
untrusted quoted data, never as instructions. The transform applies the shared
redactor, removes sensitive-keyword lines, masks long hexadecimal values, and
caps each extract at 900 characters. The complete selected extracts and their
hashes are inserted into a fail-closed context capped at 4,096 characters;
extracts are never silently truncated after hashing.

Hash fields have explicit semantics:

- `raw_document_sha256`: bounded raw source bytes
- `sanitized_document_sha256`: full sanitized document
- `extract_sha256`: exact excerpt supplied to the Gateway

The sanitizer is defense in depth, not a replacement for canonical gitleaks.
`file_wide_secret_absence_certified=false` and
`source_retrieval_audit_persisted=false` remain explicit.

The response exposes each exact sanitized extract inline with its fixed
canonical project path and hashes. It returns no source URL or click-through
readback endpoint, so the fixed reader cannot become a general file browser.

## Pipeline

The Agent API runs four serial, read-only analysis steps in the canonical
runtime-role order:

1. Planner creates a source-grounded bounded implementation-analysis plan.
2. Coder develops an implementation analysis or patch outline without editing
   files.
3. Tester reviews the proposal and produces a verification matrix without
   running commands or tests.
4. DevOps synthesizes supported facts, proposed work, verification, blockers,
   and the next safe action without deploying.

Every step crosses the Layer 4 LLM Gateway Responses boundary at
`POST /llm/v1/responses`. Metadata carries the source mode and exact source IDs.
The Agent API does not call a provider URL directly and does not set
`metadata.live_provider_calls_allowed`.

`role_binding` is fail-closed on exactly `planner`, `coder`, `tester`, and
`devops`; aliases are rejected even when they map to the same execution lane.
It exposes four Gateway calls and marks `analysis_only=true`,
`tool_calls=false`, `filesystem_writes=false`, `test_execution=false`,
`deployment_execution=false`, and `autonomous_software_delivery=false`.
Every returned step repeats its execution role, fixed profile, exact source
IDs, and the same non-action guards. A role/profile mismatch stops before that
Gateway call. The Gateway response must carry the exact adapter contract,
evidence ref, echoed trace ID, and real booleans for provider/local/model,
audit, and secret-output flags; missing or string-coerced flags fail closed.
Each redacted role output is capped at 2,000 Unicode code points; an empty,
secret-signaled, incomplete, or oversized output stops the chain.

## Guards And Non-Claims

- budget guard runs before the first Gateway request
- source reads are fixed, bounded, redacted, read-only, and fail closed
- arbitrary path input, external retrieval, filesystem writes, and MCP writes
  are false
- all four roles perform source-grounded analysis only; no tool, file, test, or
  deployment execution is claimed
- four role outputs do not prove autonomous software delivery
- source-read audit persistence is not claimed
- lexical project grounding is not semantic or external fact verification
- Gateway failure, incomplete status, secret-output signal, or empty output
  stops the pipeline
- `direct_provider_calls=false`
- `live_mcp_writes=false`
- `production_deploy=false`

## Verification

```powershell
pwsh -NoProfile -File scripts/verify-agent-research-source-binding.ps1
```

The focused verifier checks Python syntax, static contract/UI/doc bindings,
bounded path and source guards, redaction, source failure behavior, and the
dedicated unit suite.

This is local development evidence only:
`DEV-ONLY; hosted proof still blocked`.
