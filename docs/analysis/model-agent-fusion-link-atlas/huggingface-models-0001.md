# Hugging Face Model Links 0001

Contract: `model-agent-fusion-link-atlas-v1`
Evidence: `model_agent_fusion_link_atlas_visible`
Source: `huggingface`
Import mode: `cursor_api_metadata_only`
Auth env: `HF_TOKEN`
Item count: `4`

Generated from `services/agent-api/app/link_atlas.py`.
Rows are metadata links only and do not authorize live calls or model downloads.

| canonical_id | source | kind | name | url | api_url | category | tags | license | gated/private | dedupe_group | last_seen |
|---|---|---|---|---|---|---|---|---|---:|---|---|
| `huggingface-models-trending` | huggingface | model_source | Hugging Face Trending Models | [link](https://huggingface.co/models?sort=trending) | [link](https://huggingface.co/api/models?limit=50&sort=trendingScore) | model_directory | models, trending, cursor | source-policy | false | `huggingface:models-trending` | 2026-05-15 |
| `huggingface-models-api-cursor` | huggingface | model_source | Hugging Face Models API Cursor | [link](https://huggingface.co/models?sort=trending) | [link](https://huggingface.co/api/models?limit=50) | model_api | models, api, cursor | source-policy | false | `huggingface:models-api` | 2026-05-15 |
| `huggingface-models-api-trending-score` | huggingface | model_source | Hugging Face Models API Trending Score | [link](https://huggingface.co/models?sort=trending) | [link](https://huggingface.co/api/models?limit=50&sort=trendingScore) | model_api | models, api, trendingScore | source-policy | false | `huggingface:models-api-trending-score` | 2026-05-15 |
| `huggingface-hub-api-docs` | huggingface | api_doc | Hugging Face Hub API | [link](https://huggingface.co/docs/hub/main/api) | [link](https://huggingface.co/api/models?limit=50) | api_reference | api, hub, models, collections | source-policy | false | `huggingface:hub-api-docs` | 2026-05-15 |

## Source Policy

- Target scope: all public model and collection metadata reachable by cursor pagination
- Non-claim: The atlas stores metadata and links only; it does not download model files.
