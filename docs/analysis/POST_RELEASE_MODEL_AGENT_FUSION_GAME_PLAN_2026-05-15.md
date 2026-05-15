# Post-Release Model, Agent, and Fusion Game Plan

Status: `planned-post-release-bonus`
Created: `2026-05-15`
Owner: `codex`
Gate: start only after current platform reaches verified `100%` and release is complete.

## Scope

Build a post-release "Model/Agent/Fusion Atlas" that can ingest, dedupe, score, and route thousands of model, agent, and fusion candidates without downloading local model weights, exposing secrets, or claiming production rollout.

This is a bonus track after the release gate, not part of the current Phase 5 completion claim.

## Source Inventory

| Source | Current finding | Import path |
|---|---:|---|
| OpenRouter API and model pages | API probe returned `441` models for `GET /api/v1/models?output_modalities=all`; direct `GET /api/v1/models` returned `364` model rows and is now imported into the generated atlas shard. Docs describe OpenAI-like chat schema, model metadata, output modality filters, supported-parameter filters, routing, plugins, and OpenAPI specs. | API-first metadata import; no scraping needed for canonical model list. |
| OpenRouter coding apps | Coding category exposes ranked coding agents such as Cline, OpenHands, Qwen Code, GDevelop, Aider, Goose, and others. | Agent registry import by app rank, token volume, homepage, license/status where available. |
| Hugging Face models | Public page reports `2,877,435` models; API probe to `/api/models?limit=50` returns cursor-paginated model metadata. | Cursor crawler using Hub API or `huggingface_hub.HfApi.list_models()`. |
| Hugging Face collections | API probe to `/api/collections?limit=50` returns cursor-paginated collections with 50 rows per page and first-page slugs such as Gemma, Jina embeddings, Qwen, DeepSeek. User target mentions about `20,461` pages; verify by resumable crawl before claiming final count. | Collection crawler stores collection metadata plus visible item refs; expand individual collection pages only after rate-limit budget is known. |
| SiliconFlow models | Docs expose `GET https://api.siliconflow.com/v1/models` with bearer auth and filters `type=text/image/audio/video` plus `sub_type=chat/embedding/reranker/text-to-image/image-to-image/speech-to-text/text-to-video`. | Provider connector behind env-only API token; never commit token. |
| NousResearch/hermes-agent | GitHub repo describes self-improving agent loops, skill creation, memory/search, scheduled automation, subagents, terminal backends, and support for multiple providers including OpenRouter and Hugging Face. | Treat as agent architecture reference and optional integration candidate, not vendored runtime code. |
| LLM Explorer | Page reports `165` AI agents, `53,701` total LLMs, `12,599` quantized, `9,022` merged, `993` finetuned, `11,520` instruction-based, `1,614` codegen, DB update `2026-05-14`. | Seed taxonomy and cross-check counts; API key request needed for bulk import. |

## Hard Rules

- API-only metadata import first; no local model downloads.
- No secret values in files, logs, docs, screenshots, or commits.
- No production rollout claim from catalog import.
- No duplicate model/agent rows after normalization.
- Gated, private, unsafe, or unclear-license entries stay blocked until manually approved.
- Full Hugging Face universe is millions of repos; the first product slice is a curated `5,000+` high-value atlas, then background expansion.

## Target Architecture

1. `catalog-ingestor` service
   - Pulls source pages and APIs with cursor checkpoints.
   - Stores raw source snapshots compressed, plus normalized rows.
   - Uses polite rate limits, retry budget, ETag/Last-Modified where available, and resumable jobs.

2. `model-agent-registry` database schema
   - `catalog_source`: source name, URL, auth mode, last_seen, crawl_cursor.
   - `model_entry`: canonical id, source id, provider id, HF repo id, task, modalities, context length, pricing, license, tags, gated/private flags, updated_at.
   - `agent_entry`: name, source, category, repo/homepage, license, stars/forks/rank, tool surfaces, runtime type.
   - `fusion_recipe`: metadata-only recipe for routing, ensemble, fallback, debate, specialist handoff, or future weight-merge references.
   - `dedupe_identity`: normalized slugs, aliases, provider ids, HF ids, repo URLs, and model-family fingerprints.

3. `fusion-router` layer
   - Does not merge weights locally.
   - Builds runtime recipes: fallback chains, judge-worker pairs, coder-reviewer loops, multimodal splits, retrieval/rerank pairs, cheap-fast/deep-slow cascades.
   - Enforces budget, provider allowlist, task fit, and no-live-call dry-run mode.

4. Atlas UI
   - Search, compare, filter, score, and route models/agents.
   - Views: Models, Agents, Collections, Providers, Fusions, Risks, Licenses, Benchmarks.
   - Shows provenance and non-claims per row.

## Dedupe Strategy

- Primary keys: exact provider model id, HF `modelId`, GitHub `owner/repo`, OpenRouter `id`, SiliconFlow `id`.
- Alias keys: normalized slug, lowercase repo name, family prefix, quant suffix, parameter count, instruct/base/chat suffix.
- Fusion-aware grouping: base model, finetune, quant, merge, LoRA/adapters, GGUF/GPTQ/EXL2 variants.
- Keep variants but collapse duplicates in search by default.
- Store provenance for every alias decision so a bad merge can be reversed.

## Scoring Rubric

Score every entry from `0-100`:

- `task_fit`: coding, planning, reasoning, memory, vision, audio, image, video, embeddings, rerank.
- `operability`: API availability, streaming, tools/function calling, structured output, context length, latency class.
- `economics`: prompt/completion price, free tier, provider reliability, expected monthly impact.
- `safety`: license clarity, gated/private status, moderation, known risk tags, no-secret handling.
- `freshness`: updated_at, trending score, downloads, stars, DB last update, provider availability.
- `platform_fit`: works with current LangGraph, LiteLLM/OpenRouter-style routing, MCP/audit/cost surfaces.

## Milestones

### M0 - Release Boundary

- Wait for verified platform `100%` and release completion.
- Freeze this plan as post-release bonus scope.
- Do not mix catalog work into current Phase 5 rollout proofs.

### M1 - Source Manifests

- Add source config for OpenRouter, Hugging Face models, Hugging Face collections, SiliconFlow, LLM Explorer, OpenRouter coding apps, Hermes Agent.
- Store auth requirements as env var names only.
- Verification: parser + secret scan + source config schema test.

### M2 - API-Only Harvesters

- OpenRouter: import `/api/v1/models`, `/api/v1/models?output_modalities=all`; optional `/models/count`.
- Hugging Face models: cursor crawl `/api/models?limit=50`, then filters for text-generation, image-text-to-text, embeddings, code, GGUF, MLX, ONNX.
- Hugging Face collections: cursor crawl `/api/collections?limit=50`; store collection slugs and item refs.
- SiliconFlow: import `/v1/models` by `type` and `sub_type` when token is configured.
- LLM Explorer: import summary counts and agent/model category pages; request API key before bulk.
- Verification: resumable crawl can stop/restart without duplicate rows.

### M3 - Curated 5,000+ Atlas

- Select top candidates by task fit and score:
  - 1,000 coding/reasoning LLMs.
  - 1,000 instruction/chat LLMs.
  - 750 multimodal/vision/audio/video models.
  - 750 embeddings/rerank/retrieval models.
  - 500 quantized/local-reference entries as metadata only.
  - 500 agents/tools/frameworks/apps.
  - 500 fusion recipes.
- Verification: no duplicate canonical ids, no local weights, no secrets.

### M4 - Fusion Recipes

- Build metadata-only recipes:
  - Coder + reviewer + test generator.
  - Planner + critic + verifier.
  - Cheap triage + premium escalation.
  - Multimodal intake + text reasoner + structured-output finalizer.
  - Embedding retriever + reranker + answerer.
  - Agent swarm: planner, coder, tester, security, devops, researcher, supervisor.
- Verification: recipes dry-run through existing no-live-provider guard.

### M5 - Runtime Integration

- Add read-only catalog endpoints.
- Add admin-only route preview.
- Add task-to-model recommendation without making provider calls.
- Add audit events for every selected model/agent/fusion.
- Verification: LangGraph dry-run, LLM Gateway guard, MCP Gateway guard, budget guard, audit correlation.

### M6 - Safety And License Gate

- Block entries with unclear license, gated access, private status, unsafe tags, or missing provenance.
- Add manual review queue.
- Add exportable evidence snapshots.
- Verification: security queue mutation guard, redaction guard, no secret-bearing payloads.

### M7 - UI

- Add Atlas tabs: Models, Agents, Collections, Providers, Fusions, Risks.
- Add filters for source, task, modality, license, price, context, tool support, availability, update recency.
- Add compare view and route preview.
- Verification: browser contract, mobile/desktop screenshots, accessibility scan.

## First API Calls To Implement

```text
GET https://openrouter.ai/api/v1/models
GET https://openrouter.ai/api/v1/models?output_modalities=all
GET https://openrouter.ai/api/v1/models/count?output_modalities=all
GET https://huggingface.co/api/models?limit=50
GET https://huggingface.co/api/collections?limit=50
GET https://api.siliconflow.com/v1/models?type=text
GET https://api.github.com/repos/NousResearch/hermes-agent
GET https://llm-explorer.com/
```

Auth env names:

```text
OPENROUTER_API_KEY
HF_TOKEN
SILICONFLOW_API_KEY
LLM_EXPLORER_API_KEY
GITHUB_TOKEN
```

## Verification Gates

- `catalog-source-config` validates source config and auth env names only.
- `catalog-harvest-openrouter` proves count and sample rows.
- `catalog-harvest-hf-models` proves cursor persistence and no duplicate ids.
- `catalog-harvest-hf-collections` proves collection cursor persistence.
- `catalog-dedupe` proves canonical ids and alias groups.
- `catalog-no-local-downloads` proves no model files were fetched.
- `catalog-secret-scan` proves no API tokens or bearer headers in artifacts.
- `fusion-dry-run` proves route recipes do not call live providers.
- `atlas-ui-contract` proves read-only UI and filters.

## Vollstaendiger Link-Atlas

The post-release atlas now has a saved source-of-truth seed and generated shard plan:

- Source module: `services/agent-api/app/link_atlas.py`
- OpenRouter generated module: `services/agent-api/app/openrouter_model_links.py`
- Index: `docs/analysis/model-agent-fusion-link-atlas/README.md`
- Generator: `scripts/generate_model_agent_fusion_link_atlas.py`
- OpenRouter importer: `scripts/import_openrouter_models_to_link_atlas.py`
- Verifier: `scripts/verify-model-agent-fusion-link-atlas.ps1`
- Contract: `model-agent-fusion-link-atlas-v1`
- Evidence: `model_agent_fusion_link_atlas_visible`

Read-only API surfaces:

```text
GET /catalog/link-atlas/sources
GET /catalog/link-atlas/items?source=&kind=&cursor=&limit=
GET /catalog/link-atlas/items/{canonical_id}
GET /catalog/link-atlas/shards
GET /catalog/link-atlas/export.jsonl
GET /catalog/link-atlas/export.csv
GET /api/v1/catalog/link-atlas/sources
GET /api/v1/catalog/link-atlas/items?source=&kind=&cursor=&limit=
GET /api/v1/catalog/link-atlas/items/{canonical_id}
GET /api/v1/catalog/link-atlas/shards
GET /api/v1/catalog/link-atlas/export.jsonl
GET /api/v1/catalog/link-atlas/export.csv
```

Generated first shards:

- `openrouter-models-0001.md`
- `openrouter-api-models-0001.md`
- `openrouter-apps-0001.md`
- `huggingface-models-0001.md`
- `huggingface-collections-0001.md`
- `siliconflow-models-0001.md`
- `llm-explorer-models-0001.md`
- `hermes-agent-links-0001.md`
- `fusion-recipes-0001.md`

The seed lists every prompt-required source/API URL now. Current generated atlas state is `409` metadata rows across `9` shards, including `364` OpenRouter `/api/v1/models` rows. The post-release crawler appends every collected model, agent, collection, and fusion URL into additional numbered shards and the API exports, without model downloads, secrets, or rollout claims.

## Source Links

- OpenRouter API overview: https://openrouter.ai/docs/api/reference/overview
- OpenRouter direct models API: https://openrouter.ai/api/v1/models
- OpenRouter models API: https://openrouter.ai/docs/api/api-reference/models/get-models
- OpenRouter models guide: https://openrouter.ai/docs/guides/overview/models
- OpenRouter models: https://openrouter.ai/models
- OpenRouter inactive models view: https://openrouter.ai/models?active=false
- OpenRouter top weekly models: https://openrouter.ai/models?order=top-weekly
- OpenRouter coding apps: https://openrouter.ai/apps/category/coding
- Hugging Face models: https://huggingface.co/models?sort=trending
- Hugging Face Hub API: https://huggingface.co/docs/hub/main/api
- Hugging Face collections: https://huggingface.co/collections
- Hugging Face collection API probe: https://huggingface.co/api/collections?limit=50
- SiliconFlow models API: https://docs.siliconflow.com/en/api-reference/models/get-model-list
- SiliconFlow models page: https://www.siliconflow.com/models
- NousResearch Hermes Agent: https://github.com/NousResearch/hermes-agent
- LLM Explorer: https://llm-explorer.com/
