# Model Agent Fusion Link Atlas

Contract: `model-agent-fusion-link-atlas-v1`
Evidence: `model_agent_fusion_link_atlas_visible`
Status: `generated-static-seed-pending-post-release-full-crawl`
Gate: `post_release_after_verified_100_percent`

This atlas is generated from `services/agent-api/app/link_atlas.py`.
It stores metadata links only: no model downloads, no provider secrets, no production rollout claim.

## API Surfaces

- `GET /catalog/link-atlas/sources`
- `GET /catalog/link-atlas/items?source=&kind=&cursor=&limit=`
- `GET /catalog/link-atlas/items/{canonical_id}`
- `GET /catalog/link-atlas/shards`
- `GET /catalog/link-atlas/export.jsonl`
- `GET /catalog/link-atlas/export.csv`
- `GET /api/v1/catalog/link-atlas/sources`
- `GET /api/v1/catalog/link-atlas/items?source=&kind=&cursor=&limit=`
- `GET /api/v1/catalog/link-atlas/items/{canonical_id}`
- `GET /api/v1/catalog/link-atlas/shards`
- `GET /api/v1/catalog/link-atlas/export.jsonl`
- `GET /api/v1/catalog/link-atlas/export.csv`

## Required Prompt Links

- https://openrouter.ai/docs/api/reference/overview
- https://openrouter.ai/api/v1/models
- https://openrouter.ai/models
- https://openrouter.ai/models?active=false
- https://openrouter.ai/models?order=top-weekly
- https://openrouter.ai/apps/category/coding
- https://huggingface.co/models?sort=trending
- https://huggingface.co/collections
- https://www.siliconflow.com/models?utm_source=capgo&utm_medium=organic_ugcblog&utm_campaign=202509_series&utm_id=000003&utm_term=Ultimativer%20Leitfaden%20%E2%80%93%20Das%20beste%20Open-Source-LLM%20f%C3%BCr%20Agenten-Workflows%20im%20Jahr%202026&utm_content=guide_banner
- https://github.com/NousResearch/hermes-agent
- https://llm-explorer.com/

## Sources

| source | import_mode | auth_env | source_urls | api_urls | shards |
|---|---|---|---|---|---|
| `openrouter` | api_first_metadata_only | `OPENROUTER_API_KEY` | https://openrouter.ai/docs/api/reference/overview<br>https://openrouter.ai/docs/api/api-reference/models/get-models<br>https://openrouter.ai/docs/guides/overview/models<br>https://openrouter.ai/api/v1/models<br>https://openrouter.ai/models<br>https://openrouter.ai/models?active=false<br>https://openrouter.ai/models?order=top-weekly<br>https://openrouter.ai/apps/category/coding | https://openrouter.ai/api/v1/models<br>https://openrouter.ai/api/v1/models?output_modalities=all<br>https://openrouter.ai/api/v1/models/count?output_modalities=all | openrouter-models-0001.md<br>openrouter-api-models-0001.md<br>openrouter-apps-0001.md |
| `huggingface` | cursor_api_metadata_only | `HF_TOKEN` | https://huggingface.co/models?sort=trending<br>https://huggingface.co/collections<br>https://huggingface.co/docs/hub/main/api | https://huggingface.co/api/models?limit=50<br>https://huggingface.co/api/models?limit=50&sort=trendingScore<br>https://huggingface.co/api/collections?limit=50<br>https://huggingface.co/api/collections?limit=50&sort=trending&expand=true | huggingface-models-0001.md<br>huggingface-collections-0001.md |
| `siliconflow` | provider_api_metadata_only_when_token_configured | `SILICONFLOW_API_KEY` | https://www.siliconflow.com/models<br>https://www.siliconflow.com/models?utm_source=capgo&utm_medium=organic_ugcblog&utm_campaign=202509_series&utm_id=000003&utm_term=Ultimativer%20Leitfaden%20%E2%80%93%20Das%20beste%20Open-Source-LLM%20f%C3%BCr%20Agenten-Workflows%20im%20Jahr%202026&utm_content=guide_banner<br>https://docs.siliconflow.com/en/api-reference/models/get-model-list | https://api.siliconflow.com/v1/models<br>https://api.siliconflow.com/v1/models?type=text<br>https://api.siliconflow.com/v1/models?type=image<br>https://api.siliconflow.com/v1/models?type=audio<br>https://api.siliconflow.com/v1/models?type=video<br>https://api.siliconflow.com/v1/models?type=text&sub_type=chat<br>https://api.siliconflow.com/v1/models?type=text&sub_type=embedding<br>https://api.siliconflow.com/v1/models?type=text&sub_type=reranker<br>https://api.siliconflow.com/v1/models?type=image&sub_type=text-to-image<br>https://api.siliconflow.com/v1/models?type=image&sub_type=image-to-image<br>https://api.siliconflow.com/v1/models?type=audio&sub_type=speech-to-text<br>https://api.siliconflow.com/v1/models?type=video&sub_type=text-to-video | siliconflow-models-0001.md |
| `llm-explorer` | summary_seed_then_bulk_export_or_api_when_available | `LLM_EXPLORER_API_KEY` | https://llm-explorer.com/ | none | llm-explorer-models-0001.md |
| `hermes-agent` | github_metadata_and_architecture_reference | `GITHUB_TOKEN` | https://github.com/NousResearch/hermes-agent | https://api.github.com/repos/NousResearch/hermes-agent | hermes-agent-links-0001.md |
| `fusion-recipes` | metadata_only_recipe_generation | `none` | https://github.com/NousResearch/hermes-agent | /api/v1/catalog/link-atlas/items?kind=fusion_recipe | fusion-recipes-0001.md |

## Shards

| shard | source | kinds | item_count | path |
|---|---|---|---:|---|
| `openrouter-models-0001` | openrouter | api_doc, model_source | 8 | [openrouter-models-0001.md](openrouter-models-0001.md) |
| `openrouter-apps-0001` | openrouter | agent_source | 1 | [openrouter-apps-0001.md](openrouter-apps-0001.md) |
| `openrouter-api-models-0001` | openrouter | model_entry | 364 | [openrouter-api-models-0001.md](openrouter-api-models-0001.md) |
| `huggingface-models-0001` | huggingface | api_doc, model_source | 4 | [huggingface-models-0001.md](huggingface-models-0001.md) |
| `huggingface-collections-0001` | huggingface | collection_source | 2 | [huggingface-collections-0001.md](huggingface-collections-0001.md) |
| `siliconflow-models-0001` | siliconflow | api_doc, model_source, provider_api | 14 | [siliconflow-models-0001.md](siliconflow-models-0001.md) |
| `llm-explorer-models-0001` | llm-explorer | model_source, agent_source | 8 | [llm-explorer-models-0001.md](llm-explorer-models-0001.md) |
| `hermes-agent-links-0001` | hermes-agent | architecture_source | 2 | [hermes-agent-links-0001.md](hermes-agent-links-0001.md) |
| `fusion-recipes-0001` | fusion-recipes | fusion_recipe | 6 | [fusion-recipes-0001.md](fusion-recipes-0001.md) |

## Contract Summary

- Source count: `6`
- Seed item count: `409`
- Shard count: `9`
- Required fields: `canonical_id, source, kind, name, url, api_url, category, tags, license, gated_private, dedupe_group, last_seen`

## Non-Claims

- This seed proves the source-of-truth shape and required links; it is not the completed 100000+ crawl.
- The post-release crawler must append every collected model, agent, collection, and fusion URL into shards.
- No production rollout, live provider call, local model download, or secret exposure is claimed.
