# LLM Explorer Links 0001

Contract: `model-agent-fusion-link-atlas-v1`
Evidence: `model_agent_fusion_link_atlas_visible`
Source: `llm-explorer`
Import mode: `summary_seed_then_bulk_export_or_api_when_available`
Auth env: `LLM_EXPLORER_API_KEY`
Item count: `8`

Generated from `services/agent-api/app/link_atlas.py`.
Rows are metadata links only and do not authorize live calls or model downloads.

| canonical_id | source | kind | name | url | api_url | category | tags | license | gated/private | dedupe_group | last_seen |
|---|---|---|---|---|---|---|---|---|---:|---|---|
| `llm-explorer-homepage` | llm-explorer | model_source | LLM Explorer Homepage | [link](https://llm-explorer.com/) | [link](https://llm-explorer.com/) | llm_database | models, agents, quantized, merged, codegen | source-claimed | false | `llm-explorer:homepage` | 2026-05-15 |
| `llm-explorer-category-ai-agents` | llm-explorer | agent_source | LLM Explorer AI Agents | [link](https://llm-explorer.com/) | [link](https://llm-explorer.com/) | ai-agents | source-claimed-count, ai-agents | source-claimed | false | `llm-explorer:ai-agents` | 2026-05-15 |
| `llm-explorer-category-total-llms` | llm-explorer | model_source | LLM Explorer Total LLMs | [link](https://llm-explorer.com/) | [link](https://llm-explorer.com/) | total-llms | source-claimed-count, total-llms | source-claimed | false | `llm-explorer:total-llms` | 2026-05-15 |
| `llm-explorer-category-quantized-llms` | llm-explorer | model_source | LLM Explorer Quantized LLMs | [link](https://llm-explorer.com/) | [link](https://llm-explorer.com/) | quantized-llms | source-claimed-count, quantized-llms | source-claimed | false | `llm-explorer:quantized-llms` | 2026-05-15 |
| `llm-explorer-category-merged-llms` | llm-explorer | model_source | LLM Explorer Merged LLMs | [link](https://llm-explorer.com/) | [link](https://llm-explorer.com/) | merged-llms | source-claimed-count, merged-llms | source-claimed | false | `llm-explorer:merged-llms` | 2026-05-15 |
| `llm-explorer-category-finetuned-llms` | llm-explorer | model_source | LLM Explorer Finetuned LLMs | [link](https://llm-explorer.com/) | [link](https://llm-explorer.com/) | finetuned-llms | source-claimed-count, finetuned-llms | source-claimed | false | `llm-explorer:finetuned-llms` | 2026-05-15 |
| `llm-explorer-category-instruction-llms` | llm-explorer | model_source | LLM Explorer Instruction-Based LLMs | [link](https://llm-explorer.com/) | [link](https://llm-explorer.com/) | instruction-llms | source-claimed-count, instruction-llms | source-claimed | false | `llm-explorer:instruction-llms` | 2026-05-15 |
| `llm-explorer-category-codegen-llms` | llm-explorer | model_source | LLM Explorer Codegen LLMs | [link](https://llm-explorer.com/) | [link](https://llm-explorer.com/) | codegen-llms | source-claimed-count, codegen-llms | source-claimed | false | `llm-explorer:codegen-llms` | 2026-05-15 |

## Source Policy

- Target scope: AI agents, total LLMs, quantized, merged, finetuned, instruction, and codegen categories
- Non-claim: Bulk item import remains gated on API/export access; seed counts are source claims until verified.
