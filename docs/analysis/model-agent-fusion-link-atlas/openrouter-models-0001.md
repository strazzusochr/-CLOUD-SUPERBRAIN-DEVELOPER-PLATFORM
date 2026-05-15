# OpenRouter Model Links 0001

Contract: `model-agent-fusion-link-atlas-v1`
Evidence: `model_agent_fusion_link_atlas_visible`
Source: `openrouter`
Import mode: `api_first_metadata_only`
Auth env: `OPENROUTER_API_KEY`
Item count: `8`

Generated from `services/agent-api/app/link_atlas.py`.
Rows are metadata links only and do not authorize live calls or model downloads.

| canonical_id | source | kind | name | url | api_url | category | tags | license | gated/private | dedupe_group | last_seen |
|---|---|---|---|---|---|---|---|---|---:|---|---|
| `openrouter-api-overview` | openrouter | api_doc | OpenRouter API Overview | [link](https://openrouter.ai/docs/api/reference/overview) | [link](https://openrouter.ai/api/v1/models?output_modalities=all) | api_reference | api, openai-compatible, routing | source-policy | false | `openrouter:api` | 2026-05-15 |
| `openrouter-models-api-doc` | openrouter | api_doc | OpenRouter Get Models API | [link](https://openrouter.ai/docs/api/api-reference/models/get-models) | [link](https://openrouter.ai/api/v1/models?output_modalities=all) | model_api | models, metadata, api | source-policy | false | `openrouter:models-api` | 2026-05-15 |
| `openrouter-models-guide` | openrouter | model_source | OpenRouter Models Guide | [link](https://openrouter.ai/docs/guides/overview/models) | [link](https://openrouter.ai/api/v1/models?output_modalities=all) | model_docs | models, routing, parameters | source-policy | false | `openrouter:models-guide` | 2026-05-15 |
| `openrouter-models-api-all-modalities` | openrouter | model_source | OpenRouter Models API All Modalities | [link](https://openrouter.ai/models) | [link](https://openrouter.ai/api/v1/models?output_modalities=all) | model_api | models, all-modalities, cursor-seed | source-policy | false | `openrouter:models` | 2026-05-15 |
| `openrouter-models-count-all-modalities` | openrouter | model_source | OpenRouter Models Count API | [link](https://openrouter.ai/models) | [link](https://openrouter.ai/api/v1/models/count?output_modalities=all) | model_count | models, count, all-modalities | source-policy | false | `openrouter:models-count` | 2026-05-15 |
| `openrouter-models-public` | openrouter | model_source | OpenRouter Public Models | [link](https://openrouter.ai/models) | [link](https://openrouter.ai/api/v1/models?output_modalities=all) | model_directory | models, active, public | source-policy | false | `openrouter:models-public` | 2026-05-15 |
| `openrouter-models-inactive` | openrouter | model_source | OpenRouter Inactive Models View | [link](https://openrouter.ai/models?active=false) | [link](https://openrouter.ai/api/v1/models?output_modalities=all) | model_directory | models, inactive, availability | source-policy | false | `openrouter:models-inactive` | 2026-05-15 |
| `openrouter-models-top-weekly` | openrouter | model_source | OpenRouter Top Weekly Models | [link](https://openrouter.ai/models?order=top-weekly) | [link](https://openrouter.ai/api/v1/models?output_modalities=all) | model_directory | models, top-weekly, ranking | source-policy | false | `openrouter:models-top-weekly` | 2026-05-15 |

## Source Policy

- Target scope: all public OpenRouter model and coding-app metadata reachable through API/pages
- Non-claim: No OpenRouter live generation call or credential use is required for the atlas seed.
