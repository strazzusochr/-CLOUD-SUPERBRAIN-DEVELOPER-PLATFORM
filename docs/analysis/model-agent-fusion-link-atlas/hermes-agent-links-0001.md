# Hermes Agent Links 0001

Contract: `model-agent-fusion-link-atlas-v1`
Evidence: `model_agent_fusion_link_atlas_visible`
Source: `hermes-agent`
Import mode: `github_metadata_and_architecture_reference`
Auth env: `GITHUB_TOKEN`
Item count: `2`

Generated from `services/agent-api/app/link_atlas.py`.
Rows are metadata links only and do not authorize live calls or model downloads.

| canonical_id | source | kind | name | url | api_url | category | tags | license | gated/private | dedupe_group | last_seen |
|---|---|---|---|---|---|---|---|---|---:|---|---|
| `hermes-agent-github-repo` | hermes-agent | architecture_source | NousResearch Hermes Agent Repository | [link](https://github.com/NousResearch/hermes-agent) | [link](https://api.github.com/repos/NousResearch/hermes-agent) | agent_architecture | agent, self-improving, memory, skills | repo-license-to-verify | false | `github:NousResearch/hermes-agent` | 2026-05-15 |
| `hermes-agent-github-api` | hermes-agent | architecture_source | NousResearch Hermes Agent GitHub API | [link](https://github.com/NousResearch/hermes-agent) | [link](https://api.github.com/repos/NousResearch/hermes-agent) | github_api | github, repo-metadata, agent | repo-license-to-verify | false | `github:NousResearch/hermes-agent:api` | 2026-05-15 |

## Source Policy

- Target scope: agent architecture links, repo metadata, and integration candidates
- Non-claim: The repo is referenced as an architecture source; runtime vendoring is not part of this gate.
