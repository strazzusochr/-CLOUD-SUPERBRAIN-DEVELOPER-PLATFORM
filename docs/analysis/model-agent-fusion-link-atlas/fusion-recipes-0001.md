# Fusion Recipe Links 0001

Contract: `model-agent-fusion-link-atlas-v1`
Evidence: `model_agent_fusion_link_atlas_visible`
Source: `fusion-recipes`
Import mode: `metadata_only_recipe_generation`
Auth env: `none`
Item count: `6`

Generated from `services/agent-api/app/link_atlas.py`.
Rows are metadata links only and do not authorize live calls or model downloads.

| canonical_id | source | kind | name | url | api_url | category | tags | license | gated/private | dedupe_group | last_seen |
|---|---|---|---|---|---|---|---|---|---:|---|---|
| `fusion-coder-reviewer-test-generator` | fusion-recipes | fusion_recipe | Coder + Reviewer + Test Generator | [link](https://github.com/NousResearch/hermes-agent) | `/api/v1/catalog/link-atlas/items/fusion-coder-reviewer-test-generator` | metadata_only_fusion | coding, review, tests | internal-recipe | false | `fusion:coder-reviewer-test-generator` | 2026-05-15 |
| `fusion-planner-critic-verifier` | fusion-recipes | fusion_recipe | Planner + Critic + Verifier | [link](https://github.com/NousResearch/hermes-agent) | `/api/v1/catalog/link-atlas/items/fusion-planner-critic-verifier` | metadata_only_fusion | planning, critique, verification | internal-recipe | false | `fusion:planner-critic-verifier` | 2026-05-15 |
| `fusion-cheap-triage-premium-escalation` | fusion-recipes | fusion_recipe | Cheap Triage + Premium Escalation | [link](https://github.com/NousResearch/hermes-agent) | `/api/v1/catalog/link-atlas/items/fusion-cheap-triage-premium-escalation` | metadata_only_fusion | routing, budget, fallback | internal-recipe | false | `fusion:cheap-triage-premium-escalation` | 2026-05-15 |
| `fusion-multimodal-text-structured-finalizer` | fusion-recipes | fusion_recipe | Multimodal Intake + Text Reasoner + Structured Finalizer | [link](https://github.com/NousResearch/hermes-agent) | `/api/v1/catalog/link-atlas/items/fusion-multimodal-text-structured-finalizer` | metadata_only_fusion | multimodal, structured-output | internal-recipe | false | `fusion:multimodal-text-structured-finalizer` | 2026-05-15 |
| `fusion-embedding-rerank-answerer` | fusion-recipes | fusion_recipe | Embedding Retriever + Reranker + Answerer | [link](https://github.com/NousResearch/hermes-agent) | `/api/v1/catalog/link-atlas/items/fusion-embedding-rerank-answerer` | metadata_only_fusion | retrieval, rerank, answer | internal-recipe | false | `fusion:embedding-rerank-answerer` | 2026-05-15 |
| `fusion-agent-swarm-core` | fusion-recipes | fusion_recipe | Planner/Coder/Tester/Security/DevOps/Researcher/Supervisor Swarm | [link](https://github.com/NousResearch/hermes-agent) | `/api/v1/catalog/link-atlas/items/fusion-agent-swarm-core` | metadata_only_fusion | agents, swarm, supervision | internal-recipe | false | `fusion:agent-swarm-core` | 2026-05-15 |

## Source Policy

- Target scope: metadata-only route, swarm, fallback, judge, and specialist recipes
- Non-claim: Fusion recipes do not merge model weights and do not call live providers.
