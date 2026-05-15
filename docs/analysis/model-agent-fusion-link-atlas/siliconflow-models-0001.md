# SiliconFlow Model Links 0001

Contract: `model-agent-fusion-link-atlas-v1`
Evidence: `model_agent_fusion_link_atlas_visible`
Source: `siliconflow`
Import mode: `provider_api_metadata_only_when_token_configured`
Auth env: `SILICONFLOW_API_KEY`
Item count: `14`

Generated from `services/agent-api/app/link_atlas.py`.
Rows are metadata links only and do not authorize live calls or model downloads.

| canonical_id | source | kind | name | url | api_url | category | tags | license | gated/private | dedupe_group | last_seen |
|---|---|---|---|---|---|---|---|---|---:|---|---|
| `siliconflow-models-page-user-link` | siliconflow | model_source | SiliconFlow Models Page User Link | [link](https://www.siliconflow.com/models?utm_source=capgo&utm_medium=organic_ugcblog&utm_campaign=202509_series&utm_id=000003&utm_term=Ultimativer%20Leitfaden%20%E2%80%93%20Das%20beste%20Open-Source-LLM%20f%C3%BCr%20Agenten-Workflows%20im%20Jahr%202026&utm_content=guide_banner) | [link](https://api.siliconflow.com/v1/models) | provider_directory | models, provider, prompt-required-url | source-policy | false | `siliconflow:models-page` | 2026-05-15 |
| `siliconflow-models-page-clean` | siliconflow | model_source | SiliconFlow Models Page | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models) | provider_directory | models, provider | source-policy | false | `siliconflow:models-page` | 2026-05-15 |
| `siliconflow-models-api-doc` | siliconflow | api_doc | SiliconFlow Get Model List API | [link](https://docs.siliconflow.com/en/api-reference/models/get-model-list) | [link](https://api.siliconflow.com/v1/models) | api_reference | api, models, bearer-env-only | source-policy | false | `siliconflow:models-api-doc` | 2026-05-15 |
| `siliconflow-models-api-text` | siliconflow | provider_api | SiliconFlow Models API type=text | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models?type=text) | provider_api | api, models, text | source-policy | false | `siliconflow:models:text` | 2026-05-15 |
| `siliconflow-models-api-image` | siliconflow | provider_api | SiliconFlow Models API type=image | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models?type=image) | provider_api | api, models, image | source-policy | false | `siliconflow:models:image` | 2026-05-15 |
| `siliconflow-models-api-audio` | siliconflow | provider_api | SiliconFlow Models API type=audio | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models?type=audio) | provider_api | api, models, audio | source-policy | false | `siliconflow:models:audio` | 2026-05-15 |
| `siliconflow-models-api-video` | siliconflow | provider_api | SiliconFlow Models API type=video | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models?type=video) | provider_api | api, models, video | source-policy | false | `siliconflow:models:video` | 2026-05-15 |
| `siliconflow-models-api-text-chat` | siliconflow | provider_api | SiliconFlow Models API text/chat | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models?type=text&sub_type=chat) | provider_api | api, models, text, chat | source-policy | false | `siliconflow:models:text:chat` | 2026-05-15 |
| `siliconflow-models-api-text-embedding` | siliconflow | provider_api | SiliconFlow Models API text/embedding | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models?type=text&sub_type=embedding) | provider_api | api, models, text, embedding | source-policy | false | `siliconflow:models:text:embedding` | 2026-05-15 |
| `siliconflow-models-api-text-reranker` | siliconflow | provider_api | SiliconFlow Models API text/reranker | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models?type=text&sub_type=reranker) | provider_api | api, models, text, reranker | source-policy | false | `siliconflow:models:text:reranker` | 2026-05-15 |
| `siliconflow-models-api-image-text_to_image` | siliconflow | provider_api | SiliconFlow Models API image/text-to-image | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models?type=image&sub_type=text-to-image) | provider_api | api, models, image, text-to-image | source-policy | false | `siliconflow:models:image:text-to-image` | 2026-05-15 |
| `siliconflow-models-api-image-image_to_image` | siliconflow | provider_api | SiliconFlow Models API image/image-to-image | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models?type=image&sub_type=image-to-image) | provider_api | api, models, image, image-to-image | source-policy | false | `siliconflow:models:image:image-to-image` | 2026-05-15 |
| `siliconflow-models-api-audio-speech_to_text` | siliconflow | provider_api | SiliconFlow Models API audio/speech-to-text | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models?type=audio&sub_type=speech-to-text) | provider_api | api, models, audio, speech-to-text | source-policy | false | `siliconflow:models:audio:speech-to-text` | 2026-05-15 |
| `siliconflow-models-api-video-text_to_video` | siliconflow | provider_api | SiliconFlow Models API video/text-to-video | [link](https://www.siliconflow.com/models) | [link](https://api.siliconflow.com/v1/models?type=video&sub_type=text-to-video) | provider_api | api, models, video, text-to-video | source-policy | false | `siliconflow:models:video:text-to-video` | 2026-05-15 |

## Source Policy

- Target scope: all provider model metadata returned by type and subtype filters
- Non-claim: Bearer tokens are read from env only and never written to generated artifacts.
