from __future__ import annotations

import csv
import io
import json
from datetime import date
from typing import Any

from app.openrouter_model_links import OPENROUTER_MODEL_LINK_ITEMS, OPENROUTER_MODEL_LINK_SOURCE

LINK_ATLAS_CONTRACT_VERSION = "model-agent-fusion-link-atlas-v1"
LINK_ATLAS_EVIDENCE_REF = "model_agent_fusion_link_atlas_visible"
LINK_ATLAS_CREATED = "2026-05-15"
LINK_ATLAS_GATE = "post_release_after_verified_100_percent"
SILICONFLOW_PROMPT_URL = "https://www.siliconflow.com/models?utm_source=capgo&utm_medium=organic_ugcblog&utm_campaign=202509_series&utm_id=000003&utm_term=Ultimativer%20Leitfaden%20%E2%80%93%20Das%20beste%20Open-Source-LLM%20f%C3%BCr%20Agenten-Workflows%20im%20Jahr%202026&utm_content=guide_banner"

CATALOG_FIELDS = [
    "canonical_id",
    "source",
    "kind",
    "name",
    "url",
    "api_url",
    "category",
    "tags",
    "license",
    "gated_private",
    "dedupe_group",
    "last_seen",
]

PROMPT_REQUIRED_URLS = [
    "https://openrouter.ai/docs/api/reference/overview",
    "https://openrouter.ai/api/v1/models",
    "https://openrouter.ai/models",
    "https://openrouter.ai/models?active=false",
    "https://openrouter.ai/models?order=top-weekly",
    "https://openrouter.ai/apps/category/coding",
    "https://huggingface.co/models?sort=trending",
    "https://huggingface.co/collections",
    SILICONFLOW_PROMPT_URL,
    "https://github.com/NousResearch/hermes-agent",
    "https://llm-explorer.com/",
]


def _item(
    *,
    canonical_id: str,
    source: str,
    kind: str,
    name: str,
    url: str,
    api_url: str,
    category: str,
    tags: list[str],
    license: str = "source-policy",
    gated_private: bool = False,
    dedupe_group: str,
    last_seen: str = LINK_ATLAS_CREATED,
) -> dict[str, Any]:
    return {
        "canonical_id": canonical_id,
        "source": source,
        "kind": kind,
        "name": name,
        "url": url,
        "api_url": api_url,
        "category": category,
        "tags": tags,
        "license": license,
        "gated_private": gated_private,
        "dedupe_group": dedupe_group,
        "last_seen": last_seen,
    }


SOURCE_DEFINITIONS: list[dict[str, Any]] = [
    {
        "source": "openrouter",
        "label": "OpenRouter",
        "homepage": "https://openrouter.ai/models",
        "auth_env": "OPENROUTER_API_KEY",
        "import_mode": "api_first_metadata_only",
        "shards": ["openrouter-models-0001.md", "openrouter-api-models-0001.md", "openrouter-apps-0001.md"],
        "source_urls": [
            "https://openrouter.ai/docs/api/reference/overview",
            "https://openrouter.ai/docs/api/api-reference/models/get-models",
            "https://openrouter.ai/docs/guides/overview/models",
            "https://openrouter.ai/api/v1/models",
            "https://openrouter.ai/models",
            "https://openrouter.ai/models?active=false",
            "https://openrouter.ai/models?order=top-weekly",
            "https://openrouter.ai/apps/category/coding",
        ],
        "api_urls": [
            "https://openrouter.ai/api/v1/models",
            "https://openrouter.ai/api/v1/models?output_modalities=all",
            "https://openrouter.ai/api/v1/models/count?output_modalities=all",
        ],
        "target_scope": "all public OpenRouter model and coding-app metadata reachable through API/pages",
        "non_claim": "No OpenRouter live generation call or credential use is required for the atlas seed.",
    },
    {
        "source": "huggingface",
        "label": "Hugging Face",
        "homepage": "https://huggingface.co/models?sort=trending",
        "auth_env": "HF_TOKEN",
        "import_mode": "cursor_api_metadata_only",
        "shards": ["huggingface-models-0001.md", "huggingface-collections-0001.md"],
        "source_urls": [
            "https://huggingface.co/models?sort=trending",
            "https://huggingface.co/collections",
            "https://huggingface.co/docs/hub/main/api",
        ],
        "api_urls": [
            "https://huggingface.co/api/models?limit=50",
            "https://huggingface.co/api/models?limit=50&sort=trendingScore",
            "https://huggingface.co/api/collections?limit=50",
            "https://huggingface.co/api/collections?limit=50&sort=trending&expand=true",
        ],
        "target_scope": "all public model and collection metadata reachable by cursor pagination",
        "non_claim": "The atlas stores metadata and links only; it does not download model files.",
    },
    {
        "source": "siliconflow",
        "label": "SiliconFlow",
        "homepage": "https://www.siliconflow.com/models",
        "auth_env": "SILICONFLOW_API_KEY",
        "import_mode": "provider_api_metadata_only_when_token_configured",
        "shards": ["siliconflow-models-0001.md"],
        "source_urls": [
            "https://www.siliconflow.com/models",
            SILICONFLOW_PROMPT_URL,
            "https://docs.siliconflow.com/en/api-reference/models/get-model-list",
        ],
        "api_urls": [
            "https://api.siliconflow.com/v1/models",
            "https://api.siliconflow.com/v1/models?type=text",
            "https://api.siliconflow.com/v1/models?type=image",
            "https://api.siliconflow.com/v1/models?type=audio",
            "https://api.siliconflow.com/v1/models?type=video",
            "https://api.siliconflow.com/v1/models?type=text&sub_type=chat",
            "https://api.siliconflow.com/v1/models?type=text&sub_type=embedding",
            "https://api.siliconflow.com/v1/models?type=text&sub_type=reranker",
            "https://api.siliconflow.com/v1/models?type=image&sub_type=text-to-image",
            "https://api.siliconflow.com/v1/models?type=image&sub_type=image-to-image",
            "https://api.siliconflow.com/v1/models?type=audio&sub_type=speech-to-text",
            "https://api.siliconflow.com/v1/models?type=video&sub_type=text-to-video",
        ],
        "target_scope": "all provider model metadata returned by type and subtype filters",
        "non_claim": "Bearer tokens are read from env only and never written to generated artifacts.",
    },
    {
        "source": "llm-explorer",
        "label": "LLM Explorer",
        "homepage": "https://llm-explorer.com/",
        "auth_env": "LLM_EXPLORER_API_KEY",
        "import_mode": "summary_seed_then_bulk_export_or_api_when_available",
        "shards": ["llm-explorer-models-0001.md"],
        "source_urls": ["https://llm-explorer.com/"],
        "api_urls": [],
        "target_scope": "AI agents, total LLMs, quantized, merged, finetuned, instruction, and codegen categories",
        "reported_counts": {
            "ai_agents": 165,
            "total_llms": 53701,
            "quantized_llms": 12599,
            "merged_llms": 9022,
            "finetuned_llms": 993,
            "instruction_llms": 11520,
            "codegen_llms": 1614,
            "db_last_update": "2026-05-14",
        },
        "non_claim": "Bulk item import remains gated on API/export access; seed counts are source claims until verified.",
    },
    {
        "source": "hermes-agent",
        "label": "NousResearch Hermes Agent",
        "homepage": "https://github.com/NousResearch/hermes-agent",
        "auth_env": "GITHUB_TOKEN",
        "import_mode": "github_metadata_and_architecture_reference",
        "shards": ["hermes-agent-links-0001.md"],
        "source_urls": ["https://github.com/NousResearch/hermes-agent"],
        "api_urls": ["https://api.github.com/repos/NousResearch/hermes-agent"],
        "target_scope": "agent architecture links, repo metadata, and integration candidates",
        "non_claim": "The repo is referenced as an architecture source; runtime vendoring is not part of this gate.",
    },
    {
        "source": "fusion-recipes",
        "label": "Fusion Recipes",
        "homepage": "https://github.com/NousResearch/hermes-agent",
        "auth_env": None,
        "import_mode": "metadata_only_recipe_generation",
        "shards": ["fusion-recipes-0001.md"],
        "source_urls": ["https://github.com/NousResearch/hermes-agent"],
        "api_urls": ["/api/v1/catalog/link-atlas/items?kind=fusion_recipe"],
        "target_scope": "metadata-only route, swarm, fallback, judge, and specialist recipes",
        "non_claim": "Fusion recipes do not merge model weights and do not call live providers.",
    },
]

CATALOG_ITEMS: list[dict[str, Any]] = [
    _item(
        canonical_id="openrouter-api-overview",
        source="openrouter",
        kind="api_doc",
        name="OpenRouter API Overview",
        url="https://openrouter.ai/docs/api/reference/overview",
        api_url="https://openrouter.ai/api/v1/models?output_modalities=all",
        category="api_reference",
        tags=["api", "openai-compatible", "routing"],
        dedupe_group="openrouter:api",
    ),
    _item(
        canonical_id="openrouter-models-api-doc",
        source="openrouter",
        kind="api_doc",
        name="OpenRouter Get Models API",
        url="https://openrouter.ai/docs/api/api-reference/models/get-models",
        api_url="https://openrouter.ai/api/v1/models?output_modalities=all",
        category="model_api",
        tags=["models", "metadata", "api"],
        dedupe_group="openrouter:models-api",
    ),
    _item(
        canonical_id="openrouter-models-guide",
        source="openrouter",
        kind="model_source",
        name="OpenRouter Models Guide",
        url="https://openrouter.ai/docs/guides/overview/models",
        api_url="https://openrouter.ai/api/v1/models?output_modalities=all",
        category="model_docs",
        tags=["models", "routing", "parameters"],
        dedupe_group="openrouter:models-guide",
    ),
    _item(
        canonical_id="openrouter-models-api-all-modalities",
        source="openrouter",
        kind="model_source",
        name="OpenRouter Models API All Modalities",
        url="https://openrouter.ai/models",
        api_url="https://openrouter.ai/api/v1/models?output_modalities=all",
        category="model_api",
        tags=["models", "all-modalities", "cursor-seed"],
        dedupe_group="openrouter:models",
    ),
    _item(
        canonical_id="openrouter-models-count-all-modalities",
        source="openrouter",
        kind="model_source",
        name="OpenRouter Models Count API",
        url="https://openrouter.ai/models",
        api_url="https://openrouter.ai/api/v1/models/count?output_modalities=all",
        category="model_count",
        tags=["models", "count", "all-modalities"],
        dedupe_group="openrouter:models-count",
    ),
    _item(
        canonical_id="openrouter-models-public",
        source="openrouter",
        kind="model_source",
        name="OpenRouter Public Models",
        url="https://openrouter.ai/models",
        api_url="https://openrouter.ai/api/v1/models?output_modalities=all",
        category="model_directory",
        tags=["models", "active", "public"],
        dedupe_group="openrouter:models-public",
    ),
    _item(
        canonical_id="openrouter-models-inactive",
        source="openrouter",
        kind="model_source",
        name="OpenRouter Inactive Models View",
        url="https://openrouter.ai/models?active=false",
        api_url="https://openrouter.ai/api/v1/models?output_modalities=all",
        category="model_directory",
        tags=["models", "inactive", "availability"],
        dedupe_group="openrouter:models-inactive",
    ),
    _item(
        canonical_id="openrouter-models-top-weekly",
        source="openrouter",
        kind="model_source",
        name="OpenRouter Top Weekly Models",
        url="https://openrouter.ai/models?order=top-weekly",
        api_url="https://openrouter.ai/api/v1/models?output_modalities=all",
        category="model_directory",
        tags=["models", "top-weekly", "ranking"],
        dedupe_group="openrouter:models-top-weekly",
    ),
    _item(
        canonical_id="openrouter-coding-apps",
        source="openrouter",
        kind="agent_source",
        name="OpenRouter Coding Apps",
        url="https://openrouter.ai/apps/category/coding",
        api_url="https://openrouter.ai/apps/category/coding",
        category="coding_agents",
        tags=["agents", "coding", "apps"],
        dedupe_group="openrouter:coding-apps",
    ),
    *OPENROUTER_MODEL_LINK_ITEMS,
    _item(
        canonical_id="huggingface-models-trending",
        source="huggingface",
        kind="model_source",
        name="Hugging Face Trending Models",
        url="https://huggingface.co/models?sort=trending",
        api_url="https://huggingface.co/api/models?limit=50&sort=trendingScore",
        category="model_directory",
        tags=["models", "trending", "cursor"],
        dedupe_group="huggingface:models-trending",
    ),
    _item(
        canonical_id="huggingface-models-api-cursor",
        source="huggingface",
        kind="model_source",
        name="Hugging Face Models API Cursor",
        url="https://huggingface.co/models?sort=trending",
        api_url="https://huggingface.co/api/models?limit=50",
        category="model_api",
        tags=["models", "api", "cursor"],
        dedupe_group="huggingface:models-api",
    ),
    _item(
        canonical_id="huggingface-models-api-trending-score",
        source="huggingface",
        kind="model_source",
        name="Hugging Face Models API Trending Score",
        url="https://huggingface.co/models?sort=trending",
        api_url="https://huggingface.co/api/models?limit=50&sort=trendingScore",
        category="model_api",
        tags=["models", "api", "trendingScore"],
        dedupe_group="huggingface:models-api-trending-score",
    ),
    _item(
        canonical_id="huggingface-hub-api-docs",
        source="huggingface",
        kind="api_doc",
        name="Hugging Face Hub API",
        url="https://huggingface.co/docs/hub/main/api",
        api_url="https://huggingface.co/api/models?limit=50",
        category="api_reference",
        tags=["api", "hub", "models", "collections"],
        dedupe_group="huggingface:hub-api-docs",
    ),
    _item(
        canonical_id="huggingface-collections-public",
        source="huggingface",
        kind="collection_source",
        name="Hugging Face Collections",
        url="https://huggingface.co/collections",
        api_url="https://huggingface.co/api/collections?limit=50",
        category="collection_directory",
        tags=["collections", "models", "agents"],
        dedupe_group="huggingface:collections",
    ),
    _item(
        canonical_id="huggingface-collections-api-cursor",
        source="huggingface",
        kind="collection_source",
        name="Hugging Face Collections API Cursor",
        url="https://huggingface.co/collections",
        api_url="https://huggingface.co/api/collections?limit=50&sort=trending&expand=true",
        category="collection_api",
        tags=["collections", "api", "cursor", "expand"],
        dedupe_group="huggingface:collections-api",
    ),
    _item(
        canonical_id="siliconflow-models-page-user-link",
        source="siliconflow",
        kind="model_source",
        name="SiliconFlow Models Page User Link",
        url=SILICONFLOW_PROMPT_URL,
        api_url="https://api.siliconflow.com/v1/models",
        category="provider_directory",
        tags=["models", "provider", "prompt-required-url"],
        dedupe_group="siliconflow:models-page",
    ),
    _item(
        canonical_id="siliconflow-models-page-clean",
        source="siliconflow",
        kind="model_source",
        name="SiliconFlow Models Page",
        url="https://www.siliconflow.com/models",
        api_url="https://api.siliconflow.com/v1/models",
        category="provider_directory",
        tags=["models", "provider"],
        dedupe_group="siliconflow:models-page",
    ),
    _item(
        canonical_id="siliconflow-models-api-doc",
        source="siliconflow",
        kind="api_doc",
        name="SiliconFlow Get Model List API",
        url="https://docs.siliconflow.com/en/api-reference/models/get-model-list",
        api_url="https://api.siliconflow.com/v1/models",
        category="api_reference",
        tags=["api", "models", "bearer-env-only"],
        dedupe_group="siliconflow:models-api-doc",
    ),
    *[
        _item(
            canonical_id=f"siliconflow-models-api-{model_type}",
            source="siliconflow",
            kind="provider_api",
            name=f"SiliconFlow Models API type={model_type}",
            url="https://www.siliconflow.com/models",
            api_url=f"https://api.siliconflow.com/v1/models?type={model_type}",
            category="provider_api",
            tags=["api", "models", model_type],
            dedupe_group=f"siliconflow:models:{model_type}",
        )
        for model_type in ["text", "image", "audio", "video"]
    ],
    *[
        _item(
            canonical_id=f"siliconflow-models-api-{model_type}-{sub_type.replace('-', '_')}",
            source="siliconflow",
            kind="provider_api",
            name=f"SiliconFlow Models API {model_type}/{sub_type}",
            url="https://www.siliconflow.com/models",
            api_url=f"https://api.siliconflow.com/v1/models?type={model_type}&sub_type={sub_type}",
            category="provider_api",
            tags=["api", "models", model_type, sub_type],
            dedupe_group=f"siliconflow:models:{model_type}:{sub_type}",
        )
        for model_type, sub_type in [
            ("text", "chat"),
            ("text", "embedding"),
            ("text", "reranker"),
            ("image", "text-to-image"),
            ("image", "image-to-image"),
            ("audio", "speech-to-text"),
            ("video", "text-to-video"),
        ]
    ],
    _item(
        canonical_id="llm-explorer-homepage",
        source="llm-explorer",
        kind="model_source",
        name="LLM Explorer Homepage",
        url="https://llm-explorer.com/",
        api_url="https://llm-explorer.com/",
        category="llm_database",
        tags=["models", "agents", "quantized", "merged", "codegen"],
        license="source-claimed",
        dedupe_group="llm-explorer:homepage",
    ),
    *[
        _item(
            canonical_id=f"llm-explorer-category-{category_id}",
            source="llm-explorer",
            kind="model_source" if category_id != "ai-agents" else "agent_source",
            name=f"LLM Explorer {label}",
            url="https://llm-explorer.com/",
            api_url="https://llm-explorer.com/",
            category=category_id,
            tags=["source-claimed-count", category_id],
            license="source-claimed",
            dedupe_group=f"llm-explorer:{category_id}",
        )
        for category_id, label in [
            ("ai-agents", "AI Agents"),
            ("total-llms", "Total LLMs"),
            ("quantized-llms", "Quantized LLMs"),
            ("merged-llms", "Merged LLMs"),
            ("finetuned-llms", "Finetuned LLMs"),
            ("instruction-llms", "Instruction-Based LLMs"),
            ("codegen-llms", "Codegen LLMs"),
        ]
    ],
    _item(
        canonical_id="hermes-agent-github-repo",
        source="hermes-agent",
        kind="architecture_source",
        name="NousResearch Hermes Agent Repository",
        url="https://github.com/NousResearch/hermes-agent",
        api_url="https://api.github.com/repos/NousResearch/hermes-agent",
        category="agent_architecture",
        tags=["agent", "self-improving", "memory", "skills"],
        license="repo-license-to-verify",
        dedupe_group="github:NousResearch/hermes-agent",
    ),
    _item(
        canonical_id="hermes-agent-github-api",
        source="hermes-agent",
        kind="architecture_source",
        name="NousResearch Hermes Agent GitHub API",
        url="https://github.com/NousResearch/hermes-agent",
        api_url="https://api.github.com/repos/NousResearch/hermes-agent",
        category="github_api",
        tags=["github", "repo-metadata", "agent"],
        license="repo-license-to-verify",
        dedupe_group="github:NousResearch/hermes-agent:api",
    ),
    *[
        _item(
            canonical_id=f"fusion-{recipe_id}",
            source="fusion-recipes",
            kind="fusion_recipe",
            name=name,
            url="https://github.com/NousResearch/hermes-agent",
            api_url=f"/api/v1/catalog/link-atlas/items/fusion-{recipe_id}",
            category="metadata_only_fusion",
            tags=tags,
            license="internal-recipe",
            dedupe_group=f"fusion:{recipe_id}",
        )
        for recipe_id, name, tags in [
            ("coder-reviewer-test-generator", "Coder + Reviewer + Test Generator", ["coding", "review", "tests"]),
            ("planner-critic-verifier", "Planner + Critic + Verifier", ["planning", "critique", "verification"]),
            ("cheap-triage-premium-escalation", "Cheap Triage + Premium Escalation", ["routing", "budget", "fallback"]),
            ("multimodal-text-structured-finalizer", "Multimodal Intake + Text Reasoner + Structured Finalizer", ["multimodal", "structured-output"]),
            ("embedding-rerank-answerer", "Embedding Retriever + Reranker + Answerer", ["retrieval", "rerank", "answer"]),
            ("agent-swarm-core", "Planner/Coder/Tester/Security/DevOps/Researcher/Supervisor Swarm", ["agents", "swarm", "supervision"]),
        ]
    ],
]

SHARD_DEFINITIONS: list[dict[str, Any]] = [
    {
        "shard_id": "openrouter-models-0001",
        "path": "docs/analysis/model-agent-fusion-link-atlas/openrouter-models-0001.md",
        "title": "OpenRouter Model Links 0001",
        "source": "openrouter",
        "include_kinds": ["api_doc", "model_source"],
    },
    {
        "shard_id": "openrouter-apps-0001",
        "path": "docs/analysis/model-agent-fusion-link-atlas/openrouter-apps-0001.md",
        "title": "OpenRouter Coding App Links 0001",
        "source": "openrouter",
        "include_kinds": ["agent_source"],
    },
    {
        "shard_id": "openrouter-api-models-0001",
        "path": "docs/analysis/model-agent-fusion-link-atlas/openrouter-api-models-0001.md",
        "title": "OpenRouter API Model Links 0001",
        "source": "openrouter",
        "include_kinds": ["model_entry"],
    },
    {
        "shard_id": "huggingface-models-0001",
        "path": "docs/analysis/model-agent-fusion-link-atlas/huggingface-models-0001.md",
        "title": "Hugging Face Model Links 0001",
        "source": "huggingface",
        "include_kinds": ["api_doc", "model_source"],
    },
    {
        "shard_id": "huggingface-collections-0001",
        "path": "docs/analysis/model-agent-fusion-link-atlas/huggingface-collections-0001.md",
        "title": "Hugging Face Collection Links 0001",
        "source": "huggingface",
        "include_kinds": ["collection_source"],
    },
    {
        "shard_id": "siliconflow-models-0001",
        "path": "docs/analysis/model-agent-fusion-link-atlas/siliconflow-models-0001.md",
        "title": "SiliconFlow Model Links 0001",
        "source": "siliconflow",
        "include_kinds": ["api_doc", "model_source", "provider_api"],
    },
    {
        "shard_id": "llm-explorer-models-0001",
        "path": "docs/analysis/model-agent-fusion-link-atlas/llm-explorer-models-0001.md",
        "title": "LLM Explorer Links 0001",
        "source": "llm-explorer",
        "include_kinds": ["model_source", "agent_source"],
    },
    {
        "shard_id": "hermes-agent-links-0001",
        "path": "docs/analysis/model-agent-fusion-link-atlas/hermes-agent-links-0001.md",
        "title": "Hermes Agent Links 0001",
        "source": "hermes-agent",
        "include_kinds": ["architecture_source"],
    },
    {
        "shard_id": "fusion-recipes-0001",
        "path": "docs/analysis/model-agent-fusion-link-atlas/fusion-recipes-0001.md",
        "title": "Fusion Recipe Links 0001",
        "source": "fusion-recipes",
        "include_kinds": ["fusion_recipe"],
    },
]


def source_ids() -> set[str]:
    return {str(source["source"]) for source in SOURCE_DEFINITIONS}


def item_ids() -> set[str]:
    return {str(item["canonical_id"]) for item in CATALOG_ITEMS}


def source_by_id(source_id: str) -> dict[str, Any] | None:
    return next((source for source in SOURCE_DEFINITIONS if source["source"] == source_id), None)


def link_atlas_sources_payload() -> dict[str, Any]:
    return {
        "contract_version": LINK_ATLAS_CONTRACT_VERSION,
        "status": "planned_post_release_metadata_only",
        "evidence_ref": LINK_ATLAS_EVIDENCE_REF,
        "gate": LINK_ATLAS_GATE,
        "source_count": len(SOURCE_DEFINITIONS),
        "sources": SOURCE_DEFINITIONS,
        "required_prompt_urls": PROMPT_REQUIRED_URLS,
        "non_claims": [
            "No model weights are downloaded by this catalog.",
            "No provider secret values are stored or emitted.",
            "No production rollout, release promotion, or live provider call is claimed.",
        ],
    }


def normalized_items() -> list[dict[str, Any]]:
    return [dict(item) for item in CATALOG_ITEMS]


def link_atlas_items_page(
    *,
    source: str | None = None,
    kind: str | None = None,
    cursor: str | None = None,
    limit: int = 50,
) -> dict[str, Any]:
    limit = max(1, min(int(limit), 500))
    offset = 0
    if cursor:
        try:
            offset = max(0, int(cursor))
        except ValueError:
            offset = 0

    rows = normalized_items()
    if source:
        rows = [item for item in rows if item["source"] == source]
    if kind:
        rows = [item for item in rows if item["kind"] == kind]

    page = rows[offset : offset + limit]
    next_offset = offset + limit
    next_cursor = str(next_offset) if next_offset < len(rows) else None
    return {
        "contract_version": LINK_ATLAS_CONTRACT_VERSION,
        "status": "metadata_only",
        "evidence_ref": LINK_ATLAS_EVIDENCE_REF,
        "source": source,
        "kind": kind,
        "cursor": str(offset),
        "next_cursor": next_cursor,
        "limit": limit,
        "total_count": len(rows),
        "item_count": len(page),
        "items": page,
        "fields": CATALOG_FIELDS,
        "non_claims": [
            "Returned rows are metadata links only.",
            "Provider credentials and model files are not exposed by this endpoint.",
        ],
    }


def link_atlas_get_item(canonical_id: str) -> dict[str, Any] | None:
    return next((dict(item) for item in CATALOG_ITEMS if item["canonical_id"] == canonical_id), None)


def shard_items(shard: dict[str, Any]) -> list[dict[str, Any]]:
    source = str(shard["source"])
    include_kinds = set(str(kind) for kind in shard["include_kinds"])
    return [
        dict(item)
        for item in CATALOG_ITEMS
        if item["source"] == source and item["kind"] in include_kinds
    ]


def link_atlas_shards_payload() -> dict[str, Any]:
    shards: list[dict[str, Any]] = []
    for shard in SHARD_DEFINITIONS:
        rows = shard_items(shard)
        shards.append(
            {
                **shard,
                "item_count": len(rows),
                "canonical_ids": [str(item["canonical_id"]) for item in rows],
            }
        )
    return {
        "contract_version": LINK_ATLAS_CONTRACT_VERSION,
        "status": "generated_from_catalog_source",
        "evidence_ref": LINK_ATLAS_EVIDENCE_REF,
        "shard_count": len(shards),
        "shards": shards,
    }


def link_atlas_export_jsonl_text() -> str:
    return "\n".join(json.dumps(item, sort_keys=True, separators=(",", ":")) for item in normalized_items()) + "\n"


def link_atlas_export_csv_text() -> str:
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=CATALOG_FIELDS, extrasaction="ignore", lineterminator="\n")
    writer.writeheader()
    for item in normalized_items():
        row = dict(item)
        row["tags"] = "|".join(str(tag) for tag in item.get("tags", []))
        writer.writerow(row)
    return output.getvalue()


def link_atlas_contract_payload() -> dict[str, Any]:
    return {
        "contract_version": LINK_ATLAS_CONTRACT_VERSION,
        "status": "verified_static_seed_pending_post_release_crawl",
        "endpoint": "GET /api/v1/catalog/link-atlas/items",
        "exact_plan_endpoints": [
            "GET /catalog/link-atlas/sources",
            "GET /catalog/link-atlas/items?source=&kind=&cursor=&limit=",
            "GET /catalog/link-atlas/items/{canonical_id}",
            "GET /catalog/link-atlas/shards",
            "GET /catalog/link-atlas/export.jsonl",
            "GET /catalog/link-atlas/export.csv",
        ],
        "versioned_api_endpoints": [
            "GET /api/v1/catalog/link-atlas/sources",
            "GET /api/v1/catalog/link-atlas/items?source=&kind=&cursor=&limit=",
            "GET /api/v1/catalog/link-atlas/items/{canonical_id}",
            "GET /api/v1/catalog/link-atlas/shards",
            "GET /api/v1/catalog/link-atlas/export.jsonl",
            "GET /api/v1/catalog/link-atlas/export.csv",
        ],
        "evidence_ref": LINK_ATLAS_EVIDENCE_REF,
        "source_count": len(SOURCE_DEFINITIONS),
        "item_count": len(CATALOG_ITEMS),
        "shard_count": len(SHARD_DEFINITIONS),
        "required_prompt_url_count": len(PROMPT_REQUIRED_URLS),
        "openrouter_import": OPENROUTER_MODEL_LINK_SOURCE,
        "required_fields": CATALOG_FIELDS,
        "docs_index": "docs/analysis/model-agent-fusion-link-atlas/README.md",
        "post_release_gate": LINK_ATLAS_GATE,
        "crawl_policy": {
            "model_downloads": False,
            "secret_values_allowed": False,
            "external_http_validation": "optional_verifier_flag",
            "large_lists": "generated_markdown_shards_plus_jsonl_csv_exports",
            "next_full_crawl_target": "100000_plus_entries_after_release_gate",
        },
        "generated_at": date.fromisoformat(LINK_ATLAS_CREATED).isoformat(),
        "non_claims": [
            "This seed proves the source-of-truth shape and required links; it is not the completed 100000+ crawl.",
            "The post-release crawler must append every collected model, agent, collection, and fusion URL into shards.",
            "No production rollout, live provider call, local model download, or secret exposure is claimed.",
        ],
    }


def validate_link_atlas() -> list[str]:
    errors: list[str] = []
    ids = [str(item["canonical_id"]) for item in CATALOG_ITEMS]
    if len(ids) != len(set(ids)):
        errors.append("duplicate canonical_id")

    allowed_sources = source_ids()
    for item in CATALOG_ITEMS:
        missing = [field for field in CATALOG_FIELDS if field not in item]
        if missing:
            errors.append(f"{item.get('canonical_id', '<unknown>')} missing fields: {','.join(missing)}")
        if item.get("source") not in allowed_sources:
            errors.append(f"{item.get('canonical_id', '<unknown>')} has unknown source {item.get('source')}")
        if not str(item.get("url") or "").startswith(("https://", "/")):
            errors.append(f"{item.get('canonical_id', '<unknown>')} has invalid url")
        if not str(item.get("api_url") or "").startswith(("https://", "/")):
            errors.append(f"{item.get('canonical_id', '<unknown>')} has invalid api_url")

    all_urls = set()
    for source in SOURCE_DEFINITIONS:
        all_urls.update(str(url) for url in source.get("source_urls", []))
        all_urls.update(str(url) for url in source.get("api_urls", []))
    for item in CATALOG_ITEMS:
        all_urls.add(str(item["url"]))
        all_urls.add(str(item["api_url"]))
    missing_prompt_urls = [url for url in PROMPT_REQUIRED_URLS if url not in all_urls]
    if missing_prompt_urls:
        errors.append(f"missing prompt urls: {missing_prompt_urls}")

    shard_ids = set()
    for shard in SHARD_DEFINITIONS:
        shard_ids.add(str(shard["shard_id"]))
        if not shard_items(shard):
            errors.append(f"{shard['shard_id']} has no items")
    if len(shard_ids) != len(SHARD_DEFINITIONS):
        errors.append("duplicate shard_id")
    return errors
