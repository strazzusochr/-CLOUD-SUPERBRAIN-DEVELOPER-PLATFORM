# Hugging Face Collection Links 0001

Contract: `model-agent-fusion-link-atlas-v1`
Evidence: `model_agent_fusion_link_atlas_visible`
Source: `huggingface`
Import mode: `cursor_api_metadata_only`
Auth env: `HF_TOKEN`
Item count: `2`

Generated from `services/agent-api/app/link_atlas.py`.
Rows are metadata links only and do not authorize live calls or model downloads.

| canonical_id | source | kind | name | url | api_url | category | tags | license | gated/private | dedupe_group | last_seen |
|---|---|---|---|---|---|---|---|---|---:|---|---|
| `huggingface-collections-public` | huggingface | collection_source | Hugging Face Collections | [link](https://huggingface.co/collections) | [link](https://huggingface.co/api/collections?limit=50) | collection_directory | collections, models, agents | source-policy | false | `huggingface:collections` | 2026-05-15 |
| `huggingface-collections-api-cursor` | huggingface | collection_source | Hugging Face Collections API Cursor | [link](https://huggingface.co/collections) | [link](https://huggingface.co/api/collections?limit=50&sort=trending&expand=true) | collection_api | collections, api, cursor, expand | source-policy | false | `huggingface:collections-api` | 2026-05-15 |

## Source Policy

- Target scope: all public model and collection metadata reachable by cursor pagination
- Non-claim: The atlas stores metadata and links only; it does not download model files.
