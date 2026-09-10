from __future__ import annotations

import copy
import hashlib
import json
import os
import re
import time
from collections import OrderedDict
from threading import Lock
from typing import Any
from urllib.parse import urlsplit
from uuid import UUID, uuid4

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

app = FastAPI(title="Cloud Superbrain LLM Gateway", version="0.1.0")

GATEWAY_MODE = os.getenv("LLM_GATEWAY_MODE", "deterministic_dry_run").strip() or "deterministic_dry_run"
LIVE_PROVIDER_CALLS = False
HF_ROUTER_BASE_URL = os.getenv("HF_ROUTER_BASE_URL", "https://router.huggingface.co/v1").rstrip("/")
HF_DEFAULT_CHAT_MODEL = os.getenv("HF_DEFAULT_CHAT_MODEL", "deepseek-ai/DeepSeek-V4-Flash:fastest")
HF_ROUTER_TIMEOUT_SECONDS = float(os.getenv("HF_ROUTER_TIMEOUT_SECONDS", "90"))
CF_WORKERS_AI_BASE_URL = os.getenv(
    "CF_WORKERS_AI_BASE_URL",
    "https://api.cloudflare.com/client/v4",
).rstrip("/")
CF_WORKERS_AI_TIMEOUT_SECONDS = float(os.getenv("CF_WORKERS_AI_TIMEOUT_SECONDS", "90"))
# qwen2.5-coder-32b-instruct carries a 32,768 token context window, so a 2048 ceiling
# silently truncated every generation to roughly 6% of what the model can emit. The
# ceiling stays a real guard against runaway callers; it is simply set to a value that
# fits one complete single-file application alongside its prompt.
CF_WORKERS_AI_MAX_TOKENS = int(os.getenv("CF_WORKERS_AI_MAX_TOKENS", "8192") or "8192")
CF_WORKERS_AI_MODE = "cloudflare_workers_ai_live"
CF_WORKERS_AI_MODELS = {
    "@cf/qwen/qwen2.5-coder-32b-instruct",
    "@cf/meta/llama-3.1-8b-instruct-fast",
}
MODEL_STUDIO_MODE = "alibaba_model_studio_live"
MODEL_STUDIO_BASE_URL = os.getenv("ALIBABA_MODEL_STUDIO_BASE_URL", "").strip().rstrip("/")
MODEL_STUDIO_CODER_MODEL = (
    os.getenv("ALIBABA_MODEL_STUDIO_CODER_MODEL", "qwen3.7-plus").strip() or "qwen3.7-plus"
)
MODEL_STUDIO_TIMEOUT_SECONDS = float(os.getenv("ALIBABA_MODEL_STUDIO_TIMEOUT_SECONDS", "90"))
MODEL_STUDIO_MODELS = {MODEL_STUDIO_CODER_MODEL}
LOCAL_LLM_BASE_URL = os.getenv("LOCAL_LLM_BASE_URL", "http://local-llm:8080/v1").rstrip("/")
LOCAL_LLM_MODEL = os.getenv("LOCAL_LLM_MODEL", "gemma-3-1b-it").strip() or "gemma-3-1b-it"
LOCAL_LLM_TIMEOUT_SECONDS = float(os.getenv("LOCAL_LLM_TIMEOUT_SECONDS", "180"))
# Bound local CPU generation so an unbounded request cannot run away (and time out callers).
LOCAL_LLM_MAX_TOKENS_DEFAULT = int(os.getenv("LOCAL_LLM_MAX_TOKENS_DEFAULT", "256") or "256")
LLM_LIVE_PROVIDER_DEFAULT = os.getenv("LLM_LIVE_PROVIDER_DEFAULT", "false").strip().lower() in {
    "1",
    "true",
    "yes",
}
ROTATION_BACKOFF_SECONDS = [30, 60, 120, 300]
PROVIDER_RESET_AFTER_SECONDS = 900
STREAMING_PROTOCOL = "openai_compatible_sse"
RESPONSES_STREAMING_PROTOCOL = "openai-responses-sse-v1"
ROUTING_POLICY_CONTRACT_VERSION = "llm-routing-policy-v1"
LLM_RESPONSES_ADAPTER_CONTRACT_VERSION = "llm-responses-adapter-contract-v2"
LLM_RESPONSES_ADAPTER_EVIDENCE_REF = "llm_responses_adapter_contract_visible"
MAX_RESPONSES_INPUT_CHARS = 32_768
MAX_RESPONSES_OUTPUT_CHARS = 32_768
MAX_RESPONSES_OUTPUT_TOKENS = 8_192
MAX_RESPONSES_METADATA_BYTES = 8_192
MAX_RESPONSES_PAYLOAD_BYTES = 65_536
MAX_RESPONSES_INSTRUCTIONS_CHARS = 8_192
MAX_RESPONSES_STORED_CONTEXT_CHARS = 65_536
MAX_RESPONSES_STORED_CONTEXTS = 64
RESPONSES_CONTEXT_TTL_SECONDS = 1_800
RESPONSES_STREAM_CHUNK_CHARS = 64
MAX_FALLBACKS_PER_REQUEST = 2
MAX_RETRY_CYCLES_PER_RUN = 5
MAX_CHAT_OUTPUT_TOKENS = 8_192
MAX_CHAT_TOOLS = 128
MAX_CHAT_TOOLS_BYTES = 131_072

LEGACY_MODEL_ALIASES = {
    "deepseek-chat": "deepseek-ai/DeepSeek-V4-Flash:fastest",
    "qwen-coder": MODEL_STUDIO_CODER_MODEL,
    "gemma-chat": "google/gemma-4-31B-it:fastest",
    "llama-chat": "meta-llama/Llama-3.1-8B-Instruct:fastest",
}

MODEL_ROUTES = [
    {
        "agent_type": "planner",
        "primary": "deepseek-ai/DeepSeek-V4-Pro:fastest",
        "fallbacks": ["Qwen/Qwen3.6-35B-A3B:fastest", "moonshotai/Kimi-K2.6:fastest"],
        "max_output_tokens": 4096,
        "supports_streaming": True,
        "configured_only": False,
        "open_source_first": True,
    },
    {
        "agent_type": "coder",
        "primary": MODEL_STUDIO_CODER_MODEL,
        "fallbacks": ["deepseek-ai/DeepSeek-V4-Flash:fastest", "google/gemma-4-31B-it:fastest"],
        "max_output_tokens": 8192,
        "supports_streaming": True,
        "configured_only": True,
        "open_source_first": True,
    },
    {
        "agent_type": "tester",
        "primary": "google/gemma-4-26B-A4B-it:cheapest",
        "fallbacks": ["Qwen/Qwen3.5-9B:cheapest", "meta-llama/Llama-3.1-8B-Instruct:cheapest"],
        "max_output_tokens": 4096,
        "supports_streaming": True,
        "configured_only": False,
        "open_source_first": True,
    },
    {
        "agent_type": "devops",
        "primary": "deepseek-ai/DeepSeek-V4-Flash:fastest",
        "fallbacks": ["Qwen/Qwen3.6-35B-A3B:fastest", "google/gemma-4-31B-it:fastest"],
        "max_output_tokens": 4096,
        "supports_streaming": True,
        "configured_only": False,
        "open_source_first": True,
    },
    {
        "agent_type": "research",
        "primary": "zai-org/GLM-5.1:fastest",
        "fallbacks": ["deepseek-ai/DeepSeek-V4-Pro:fastest", "inclusionAI/Ling-2.6-1T:fastest"],
        "max_output_tokens": 4096,
        "supports_streaming": True,
        "configured_only": False,
        "open_source_first": True,
    },
]


class ChatMessage(BaseModel):
    role: str
    content: str | list[dict[str, Any]] | None = None
    name: str | None = Field(default=None, max_length=128)
    tool_call_id: str | None = Field(default=None, max_length=256)
    tool_calls: list[dict[str, Any]] | None = Field(default=None, max_length=MAX_CHAT_TOOLS)


class ChatCompletionRequest(BaseModel):
    model: str = Field(..., min_length=1)
    messages: list[ChatMessage] = Field(default_factory=list)
    stream: bool = False
    temperature: float | None = None
    max_tokens: int | None = Field(default=None, ge=1, le=MAX_CHAT_OUTPUT_TOKENS)
    tools: list[dict[str, Any]] | None = Field(default=None, max_length=MAX_CHAT_TOOLS)
    tool_choice: str | dict[str, Any] | None = None
    parallel_tool_calls: bool | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


_RESPONSES_CONTEXT_STORE: OrderedDict[str, tuple[float, list[dict[str, str]]]] = OrderedDict()
_RESPONSES_CONTEXT_LOCK = Lock()


def clear_responses_context_store() -> None:
    with _RESPONSES_CONTEXT_LOCK:
        _RESPONSES_CONTEXT_STORE.clear()


def _prune_responses_context_store(now: float) -> None:
    expired = [
        response_id
        for response_id, (created_at, _) in _RESPONSES_CONTEXT_STORE.items()
        if now - created_at > RESPONSES_CONTEXT_TTL_SECONDS
    ]
    for response_id in expired:
        _RESPONSES_CONTEXT_STORE.pop(response_id, None)


def store_responses_context(response_id: str, messages: list[ChatMessage]) -> None:
    bounded_reversed: list[dict[str, str]] = []
    total_chars = 0
    for message in reversed(messages):
        if message.role not in {"user", "assistant"} or not isinstance(message.content, str):
            continue
        content = message.content
        if total_chars + len(content) > MAX_RESPONSES_STORED_CONTEXT_CHARS:
            break
        bounded_reversed.append({"role": message.role, "content": content})
        total_chars += len(content)
    bounded = list(reversed(bounded_reversed))
    if not bounded:
        return
    now = time.monotonic()
    with _RESPONSES_CONTEXT_LOCK:
        _prune_responses_context_store(now)
        _RESPONSES_CONTEXT_STORE.pop(response_id, None)
        while len(_RESPONSES_CONTEXT_STORE) >= MAX_RESPONSES_STORED_CONTEXTS:
            _RESPONSES_CONTEXT_STORE.popitem(last=False)
        _RESPONSES_CONTEXT_STORE[response_id] = (now, bounded)


def load_responses_context(response_id: str) -> list[ChatMessage]:
    now = time.monotonic()
    with _RESPONSES_CONTEXT_LOCK:
        _prune_responses_context_store(now)
        stored = _RESPONSES_CONTEXT_STORE.get(response_id)
        if stored is None:
            raise HTTPException(status_code=404, detail="previous_response_id is unknown or expired")
        _RESPONSES_CONTEXT_STORE.move_to_end(response_id)
        values = [dict(item) for item in stored[1]]
    return [ChatMessage(role=item["role"], content=item["content"]) for item in values]


class RoutingResolveRequest(BaseModel):
    agent_type: str = Field(..., min_length=1)
    task_type: str = "general"
    requires_streaming: bool = True
    budget_level: str = "ok"
    preferred_model: str | None = None


class RoutingPolicyRequest(BaseModel):
    run_id: str = Field(..., min_length=1)
    agent_slot: str = Field(..., min_length=1)
    model_slot: str = Field(..., min_length=1)
    task_class: str = Field(..., min_length=1)
    sensitivity: str = Field(default="internal", pattern="^(public|internal|sensitive)$")
    max_output_tokens: int = Field(default=4096, ge=1)
    retry_index: int = Field(default=0, ge=0)
    fallback_index: int = Field(default=0, ge=0)
    trace_correlation_id: str = Field(..., min_length=1)
    requested_cost_tier: str | None = Field(default=None, pattern="^Tier-[ESP]$")
    cache_requested: bool = False
    budget_allow_new_calls: bool = True
    direct_provider_url: str | None = None
    direct_provider_key_ref: str | None = None
    blocker_ref: str | None = None


def hf_router_token() -> str | None:
    value = (os.getenv("HF_TOKEN") or os.getenv("HUGGINGFACE_HUB_TOKEN") or "").strip()
    return value or None


def hf_router_available() -> bool:
    return hf_router_token() is not None


def cloudflare_workers_ai_token() -> str | None:
    value = (os.getenv("CF_WORKERS_AI_TOKEN") or "").strip()
    return value or None


def cloudflare_workers_ai_account_id() -> str | None:
    value = (os.getenv("CLOUDFLARE_ACCOUNT_ID") or "").strip()
    return value or None


def cloudflare_workers_ai_mode_enabled() -> bool:
    return GATEWAY_MODE == CF_WORKERS_AI_MODE


def cloudflare_workers_ai_available() -> bool:
    return bool(cloudflare_workers_ai_token() and cloudflare_workers_ai_account_id())


def model_studio_api_key() -> str | None:
    value = (os.getenv("DASHSCOPE_API_KEY") or "").strip()
    return value or None


def model_studio_mode_enabled() -> bool:
    return GATEWAY_MODE == MODEL_STUDIO_MODE


def model_studio_base_url_valid() -> bool:
    if not MODEL_STUDIO_BASE_URL:
        return False
    parsed = urlsplit(MODEL_STUDIO_BASE_URL)
    hostname = (parsed.hostname or "").lower()
    return bool(
        parsed.scheme == "https"
        and hostname.endswith(".maas.aliyuncs.com")
        and parsed.path.rstrip("/") == "/compatible-mode/v1"
        and not parsed.username
        and not parsed.password
        and not parsed.query
        and not parsed.fragment
    )


def model_studio_available() -> bool:
    return bool(model_studio_base_url_valid() and model_studio_api_key())


def model_studio_capability_snapshot() -> dict[str, object]:
    return {
        "provider": "alibaba_model_studio",
        "mode": MODEL_STUDIO_MODE,
        "mode_enabled": model_studio_mode_enabled(),
        "available": model_studio_available(),
        "base_url": MODEL_STUDIO_BASE_URL,
        "chat_endpoint": "/chat/completions",
        "model": MODEL_STUDIO_CODER_MODEL,
        "auth_env": "DASHSCOPE_API_KEY",
        "api_key_configured": model_studio_api_key() is not None,
        "endpoint_valid": model_studio_base_url_valid(),
        "owner_live_gate_enabled": LLM_LIVE_PROVIDER_DEFAULT,
        "max_output_tokens": MAX_CHAT_OUTPUT_TOKENS,
        "tool_calling": True,
        "max_tools": MAX_CHAT_TOOLS,
        "gateway_only": True,
        "direct_provider_calls": False,
        "live_provider_calls": False,
        "model_downloads": False,
        "secret_output": False,
        "non_claim": (
            "The endpoint and model are configured through the LLM Gateway; no live call is "
            "claimed until the dedicated key, gateway mode, per-request approval, and audit all pass."
        ),
    }


def huggingface_router_capability_snapshot() -> dict[str, object]:
    return {
        "available": hf_router_available(),
        "provider": "huggingface_inference_router",
        "chat_endpoint": "/v1/chat/completions",
        "responses_adapter_endpoint": "/v1/responses",
        "upstream_base_url": HF_ROUTER_BASE_URL,
        "default_model": HF_DEFAULT_CHAT_MODEL,
        "auth_env": "HF_TOKEN",
        "stateful_sessions_supported": True,
        "stream_passthrough": False,
        "model_downloads": False,
        "open_source_first": True,
        "live_provider_calls_default": LLM_LIVE_PROVIDER_DEFAULT,
        "non_claim": "Responses requests are adapted to the Hugging Face OpenAI-compatible chat endpoint; no OpenAI key is required.",
    }


SLOT_POLICIES: dict[str, dict[str, object]] = {
    "planner_primary": {
        "agent_slot": "planner",
        "allowed_cost_tier": "Tier-S",
        "provider_class": "standard_coding",
        "fallback_allowed": True,
        "cache_allowed": True,
    },
    "coder_primary": {
        "agent_slot": "coder",
        "allowed_cost_tier": "Tier-S",
        "provider_class": "standard_coding",
        "fallback_allowed": True,
        "cache_allowed": True,
    },
    "tester_primary": {
        "agent_slot": "tester",
        "allowed_cost_tier": "Tier-E",
        "provider_class": "economy_verify",
        "fallback_allowed": True,
        "cache_allowed": True,
    },
    "devops_primary": {
        "agent_slot": "devops",
        "allowed_cost_tier": "Tier-E",
        "provider_class": "economy_verify",
        "fallback_allowed": True,
        "cache_allowed": True,
    },
    "memory_compactor": {
        "agent_slot": "memory",
        "allowed_cost_tier": "Tier-E",
        "provider_class": "economy_verify",
        "fallback_allowed": True,
        "cache_allowed": False,
    },
    "review_gate": {
        "agent_slot": "reviewer",
        "allowed_cost_tier": "Tier-S",
        "provider_class": "standard_coding",
        "fallback_allowed": True,
        "cache_allowed": False,
    },
}


def model_ids() -> list[str]:
    values: list[str] = []
    for route in MODEL_ROUTES:
        values.append(str(route["primary"]))
        values.extend(str(item) for item in route["fallbacks"])
    values.extend(LEGACY_MODEL_ALIASES.values())
    return sorted(set(values))


def normalize_model_id(model: str | None) -> str:
    if not model:
        return LOCAL_LLM_MODEL if GATEWAY_MODE == "local_openai_live" else HF_DEFAULT_CHAT_MODEL
    return LEGACY_MODEL_ALIASES.get(model, model)


def local_llm_enabled() -> bool:
    return GATEWAY_MODE == "local_openai_live"


def local_llm_health() -> bool:
    try:
        with httpx.Client(timeout=3) as client:
            response = client.get(f"{LOCAL_LLM_BASE_URL.removesuffix('/v1')}/health")
            response.raise_for_status()
        return True
    except Exception:
        return False


def model_family(model: str) -> str:
    base = normalize_model_id(model).split(":", 1)[0]
    if base in MODEL_STUDIO_MODELS or base.startswith("qwen"):
        return "qwen"
    if base.startswith("deepseek-ai/"):
        return "deepseek"
    if base.startswith("Qwen/"):
        return "qwen"
    if base.startswith("google/gemma"):
        return "gemma"
    if base.startswith("meta-llama/"):
        return "llama"
    if base.startswith("mistralai/"):
        return "mistral"
    if base.startswith("moonshotai/"):
        return "kimi"
    if base.startswith("zai-org/"):
        return "glm"
    if base.startswith("inclusionai/"):
        return "ling"
    return "open-weight"


def provider_for_model(model: str) -> str:
    if normalize_model_id(model) in MODEL_STUDIO_MODELS:
        return "alibaba_model_studio"
    if local_llm_enabled():
        return "local_llama_cpp"
    return "huggingface_inference_router"


def hf_router_model_snapshot(limit: int = 20) -> dict[str, object]:
    if not hf_router_available():
        return {
            "status": "missing_token",
            "live_verified": False,
            "model_count_visible": 0,
            "models": [],
        }

    headers = {"Authorization": f"Bearer {hf_router_token()}"}
    try:
        with httpx.Client(timeout=10) as client:
            response = client.get(f"{HF_ROUTER_BASE_URL}/models", headers=headers)
            response.raise_for_status()
        payload = response.json()
    except httpx.HTTPStatusError as exc:
        return {
            "status": "http_error",
            "http_status": exc.response.status_code,
            "live_verified": False,
            "model_count_visible": 0,
            "models": [],
        }
    except httpx.HTTPError as exc:
        return {
            "status": "network_error",
            "error": type(exc).__name__,
            "live_verified": False,
            "model_count_visible": 0,
            "models": [],
        }

    items = payload.get("data", []) if isinstance(payload, dict) else []
    models = [
        str(item.get("id"))
        for item in items
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    ]
    return {
        "status": "live_verified",
        "live_verified": True,
        "model_count_visible": len(models),
        "models": models[:limit],
    }


def provider_router_snapshot_for_gateway_mode(limit: int = 20) -> dict[str, object]:
    if cloudflare_workers_ai_mode_enabled() or model_studio_mode_enabled():
        return {
            "status": "not_active_provider",
            "live_verified": False,
            "model_count_visible": 0,
            "models": [],
        }
    return hf_router_model_snapshot(limit=limit)


def provider_status_snapshot() -> dict[str, object]:
    router = provider_router_snapshot_for_gateway_mode()
    local_status = (
        "healthy"
        if local_llm_enabled() and local_llm_health()
        else "starting_or_unavailable"
        if local_llm_enabled()
        else "not_enabled"
    )
    model_studio = model_studio_capability_snapshot()
    if model_studio["available"]:
        model_studio_status = "configured_gate_closed"
    elif not model_studio["endpoint_valid"]:
        model_studio_status = "missing_or_invalid_endpoint"
    else:
        model_studio_status = "missing_api_key"

    return {
        "mode": GATEWAY_MODE,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "live_provider_calls_available": (
            model_studio_available() if model_studio_mode_enabled() else hf_router_available()
        ),
        "live_verified": False,
        "policy": {
            "rotation_backoff_seconds": ROTATION_BACKOFF_SECONDS,
            "reset_after_seconds": PROVIDER_RESET_AFTER_SECONDS,
            "never_break_budget": True,
            "external_provider_calls_disabled_by_default": not LLM_LIVE_PROVIDER_DEFAULT,
            "requires_request_metadata": "metadata.live_provider_calls_allowed=true",
            "requires_owner_environment_gate": "LLM_LIVE_PROVIDER_DEFAULT=true",
        },
        "providers": [
            {
                "provider": "alibaba_model_studio",
                "status": model_studio_status,
                "live_verified": False,
                "live_provider_calls": False,
                "live_provider_calls_available": model_studio_available(),
                "model_count_visible": 1,
                "configured_models": [MODEL_STUDIO_CODER_MODEL],
                "visible_models_sample": [MODEL_STUDIO_CODER_MODEL],
                "backoff_seconds": ROTATION_BACKOFF_SECONDS,
                "reset_after_seconds": PROVIDER_RESET_AFTER_SECONDS,
                "model_downloads": False,
                "open_source_first": False,
                "gateway_only": True,
                "direct_provider_calls": False,
                "secret_output": False,
                "endpoint_valid": model_studio["endpoint_valid"],
                "api_key_configured": model_studio["api_key_configured"],
                "non_claim": model_studio["non_claim"],
            },
            {
                "provider": "local_llama_cpp",
                "status": local_status,
                "live_verified": local_llm_enabled() and local_llm_health(),
                "live_provider_calls": False,
                "live_provider_calls_available": local_llm_enabled(),
                "model_count_visible": 1 if local_llm_enabled() else 0,
                "configured_models": [LOCAL_LLM_MODEL],
                "visible_models_sample": [LOCAL_LLM_MODEL] if local_llm_enabled() else [],
                "backoff_seconds": [],
                "reset_after_seconds": None,
                "model_downloads": True,
                "open_source_first": True,
                "non_claim": "Local CPU model path; no external provider token is required.",
            },
            {
                "provider": "huggingface_inference_router",
                "status": router["status"],
                "live_verified": bool(router["live_verified"]),
                "live_provider_calls": LIVE_PROVIDER_CALLS,
                "live_provider_calls_available": hf_router_available(),
                "model_count_visible": router["model_count_visible"],
                "configured_models": model_ids(),
                "visible_models_sample": router["models"],
                "backoff_seconds": ROTATION_BACKOFF_SECONDS,
                "reset_after_seconds": PROVIDER_RESET_AFTER_SECONDS,
                "model_downloads": False,
                "open_source_first": True,
                "non_claim": "HF router model listing is verified when token is present; generation still requires policy/metadata approval per request.",
            },
        ],
    }


def streaming_contract_snapshot() -> dict[str, object]:
    return {
        "mode": GATEWAY_MODE,
        "protocol": STREAMING_PROTOCOL,
        "endpoint": "/v1/chat/completions",
        "request_flag": {"stream": True},
        "content_type": "text/event-stream",
        "frames": [
            "data: {chat.completion.chunk}",
            "data: {chat.completion.chunk finish_reason=stop}",
            "data: [DONE]",
        ],
        "event_id_replay": False,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "audit_persisted": "same as non-streaming dry-run request",
        "non_claim": "This is a deterministic local dry-run SSE contract; no external provider stream is opened.",
    }


def routing_policy_contract_snapshot() -> dict[str, object]:
    return {
        "contract_version": ROUTING_POLICY_CONTRACT_VERSION,
        "mode": GATEWAY_MODE,
        "endpoint": "POST /api/v1/routing/policy/evaluate",
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "max_fallbacks": MAX_FALLBACKS_PER_REQUEST,
        "max_retry_cycles": MAX_RETRY_CYCLES_PER_RUN,
        "slot_policies": SLOT_POLICIES,
        "decisions": [
            "allow_primary",
            "allow_fallback",
            "deny_slot_disabled",
            "deny_budget_or_rate",
            "deny_cost_tier",
            "deny_fallback_limit",
            "deny_retry_limit",
            "deny_sensitive_cache",
            "deny_direct_provider",
        ],
        "required_fields": [
            "run_id",
            "agent_slot",
            "model_slot",
            "task_class",
            "sensitivity",
            "max_output_tokens",
            "retry_index",
            "fallback_index",
            "trace_correlation_id",
        ],
        "evidence_refs": {
            "contract_visible": "llm_routing_policy_contract_visible",
            "direct_provider_blocked": "llm_routing_policy_direct_provider_blocked",
            "fallback_limit_blocked": "llm_routing_policy_fallback_limit_blocked",
            "retry_limit_blocked": "llm_routing_policy_retry_limit_blocked",
            "sensitive_cache_blocked": "llm_routing_policy_sensitive_cache_blocked",
            "budget_blocked": "llm_routing_policy_budget_blocked",
            "primary_allowed": "llm_routing_policy_primary_allowed",
        },
        "non_claims": [
            "This contract evaluates local routing policy only.",
            "No external provider is called by this policy evaluator.",
            "No provider credential, direct provider URL, or live billing path is accepted.",
        ],
    }


def evaluate_routing_policy(request: RoutingPolicyRequest) -> dict[str, object]:
    policy = SLOT_POLICIES.get(request.model_slot)
    requested_cost_tier = request.requested_cost_tier or str(
        policy.get("allowed_cost_tier") if policy else "Tier-E"
    )
    reason = "primary_route_allowed"
    decision = "allow_primary"
    evidence_ref = "llm_routing_policy_primary_allowed"

    if request.direct_provider_url or request.direct_provider_key_ref:
        decision = "deny_direct_provider"
        reason = "direct_provider_bypass_attempt"
        evidence_ref = "llm_routing_policy_direct_provider_blocked"
    elif policy is None or policy.get("agent_slot") != request.agent_slot:
        decision = "deny_slot_disabled"
        reason = "model_slot_disabled_or_agent_mismatch"
        evidence_ref = "llm_routing_policy_slot_disabled"
    elif not request.budget_allow_new_calls:
        decision = "deny_budget_or_rate"
        reason = "budget_contract_denied"
        evidence_ref = "llm_routing_policy_budget_blocked"
    elif requested_cost_tier == "Tier-P" and not request.blocker_ref:
        decision = "deny_cost_tier"
        reason = "premium_tier_requires_documented_blocker"
        evidence_ref = "llm_routing_policy_cost_tier_blocked"
    elif request.fallback_index > MAX_FALLBACKS_PER_REQUEST:
        decision = "deny_fallback_limit"
        reason = "fallback_limit_exceeded"
        evidence_ref = "llm_routing_policy_fallback_limit_blocked"
    elif request.retry_index >= MAX_RETRY_CYCLES_PER_RUN:
        decision = "deny_retry_limit"
        reason = "retry_limit_reached"
        evidence_ref = "llm_routing_policy_retry_limit_blocked"
    elif request.sensitivity == "sensitive" and request.cache_requested:
        decision = "deny_sensitive_cache"
        reason = "sensitive_requests_must_bypass_cache"
        evidence_ref = "llm_routing_policy_sensitive_cache_blocked"
    elif request.fallback_index > 0:
        decision = "allow_fallback"
        reason = "fallback_within_policy_limits"
        evidence_ref = "llm_routing_policy_fallback_allowed"

    return {
        "contract_version": ROUTING_POLICY_CONTRACT_VERSION,
        "mode": GATEWAY_MODE,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "run_id": request.run_id,
        "agent_slot": request.agent_slot,
        "model_slot": request.model_slot,
        "task_class": request.task_class,
        "sensitivity": request.sensitivity,
        "provider_class": str(policy.get("provider_class") if policy else "none"),
        "allowed_cost_tier": str(policy.get("allowed_cost_tier") if policy else "none"),
        "requested_cost_tier": requested_cost_tier,
        "decision": decision,
        "reason": reason,
        "fallback_index": request.fallback_index,
        "retry_index": request.retry_index,
        "trace_correlation_id": request.trace_correlation_id,
        "cache_requested": request.cache_requested,
        "budget_allow_new_calls": request.budget_allow_new_calls,
        "max_fallbacks": MAX_FALLBACKS_PER_REQUEST,
        "max_retry_cycles": MAX_RETRY_CYCLES_PER_RUN,
        "evidence_ref": evidence_ref,
        "policy_snapshot": {
            "slot_enabled": policy is not None,
            "fallback_allowed": bool(policy.get("fallback_allowed")) if policy else False,
            "cache_allowed": bool(policy.get("cache_allowed")) if policy else False,
            "direct_provider_bypass_blocked": True,
            "external_provider_calls_disabled": not LIVE_PROVIDER_CALLS,
        },
    }


def resolve_route(request: RoutingResolveRequest) -> dict[str, object]:
    route = next((item for item in MODEL_ROUTES if item["agent_type"] == request.agent_type), None)
    if route is None:
        route = next(item for item in MODEL_ROUTES if item["agent_type"] == "planner")

    candidates = [str(route["primary"]), *[str(item) for item in route["fallbacks"]]]
    selected = str(route["primary"])
    reason = "primary_route_selected"

    if request.preferred_model and request.preferred_model in candidates:
        selected = request.preferred_model
        reason = "preferred_model_within_route"
    elif request.budget_level in {"warning", "critical"}:
        selected = candidates[-1]
        reason = "budget_guard_prefers_lowest_configured_fallback"
    elif request.requires_streaming and not bool(route["supports_streaming"]):
        selected = candidates[-1]
        reason = "streaming_required_primary_not_supported"
    selected_provider = provider_for_model(selected)
    router = provider_router_snapshot_for_gateway_mode(limit=5)
    selected_provider_available = (
        model_studio_available()
        if selected_provider == "alibaba_model_studio"
        else local_llm_health()
        if selected_provider == "local_llama_cpp" and local_llm_enabled()
        else hf_router_available()
    )
    selected_provider_status = (
        "configured_gate_closed"
        if selected_provider == "alibaba_model_studio" and selected_provider_available
        else "missing_api_key_or_endpoint"
        if selected_provider == "alibaba_model_studio"
        else str(router["status"])
    )

    return {
        "mode": GATEWAY_MODE,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "live_provider_calls_available": selected_provider_available,
        "agent_type": request.agent_type,
        "task_type": request.task_type,
        "selected_model": selected,
        "selected_provider": selected_provider,
        "selected_model_family": model_family(selected),
        "reason": reason,
        "fallback_chain": candidates,
        "provider_chain": [provider_for_model(candidate) for candidate in candidates],
        "max_output_tokens": route["max_output_tokens"],
        "supports_streaming": route["supports_streaming"],
        "configured_only": bool(route["configured_only"]),
        "live_verified": False if selected_provider == "alibaba_model_studio" else bool(router["live_verified"]),
        "budget_level": request.budget_level,
        "provider_health": {
            "provider": selected_provider,
            "status": selected_provider_status,
            "live_verified": False if selected_provider == "alibaba_model_studio" else bool(router["live_verified"]),
            "live_provider_calls": False,
            "live_provider_calls_available": selected_provider_available,
            "model_downloads": False,
            "non_claim": (
                "Model Studio configuration is visible but generation remains key-, mode-, policy-, and audit-gated."
                if selected_provider == "alibaba_model_studio"
                else "Router availability is verified through HF /v1/models; generation is still policy-gated."
            ),
        },
        "policy": {
            "rotation_backoff_seconds": ROTATION_BACKOFF_SECONDS,
            "reset_after_seconds": PROVIDER_RESET_AFTER_SECONDS,
            "never_break_budget": True,
            "external_provider_calls_disabled_by_default": not LLM_LIVE_PROVIDER_DEFAULT,
            "requires_request_metadata": "metadata.live_provider_calls_allowed=true",
            "requires_owner_environment_gate": "LLM_LIVE_PROVIDER_DEFAULT=true",
        },
    }


def count_text_tokens(messages: list[ChatMessage]) -> int:
    text = " ".join(str(message.content) for message in messages)
    return len(text.split())


def deterministic_content(request: ChatCompletionRequest) -> str:
    digest = hashlib.sha256(
        ("|".join(str(message.content) for message in request.messages) + request.model).encode("utf-8")
    ).hexdigest()[:12]
    return (
        "LLM gateway deterministic dry-run response. "
        f"model={request.model}; live_provider_calls=false; evidence_ref=llm-dry-run:{digest}"
    )


def request_requests_live_provider(metadata: dict[str, Any] | None) -> bool:
    metadata = metadata or {}
    value = metadata.get("live_provider_calls_allowed")
    return value is True or (isinstance(value, str) and value.strip().lower() in {"1", "true", "yes"})


def request_allows_live_provider(metadata: dict[str, Any] | None) -> bool:
    return LLM_LIVE_PROVIDER_DEFAULT and request_requests_live_provider(metadata)


def chat_message_payloads(messages: list[ChatMessage]) -> list[dict[str, Any]]:
    payloads: list[dict[str, Any]] = []
    for message in messages:
        payload: dict[str, Any] = {"role": message.role, "content": message.content}
        if message.name is not None:
            payload["name"] = message.name
        if message.tool_call_id is not None:
            payload["tool_call_id"] = message.tool_call_id
        if message.tool_calls is not None:
            payload["tool_calls"] = message.tool_calls
        payloads.append(payload)
    return payloads


def first_chat_choice(response_payload: dict[str, Any]) -> dict[str, Any] | None:
    choices = response_payload.get("choices")
    if not isinstance(choices, list) or not choices:
        return None
    first = choices[0]
    return first if isinstance(first, dict) else None


def extract_chat_content(response_payload: dict[str, Any]) -> str:
    first = first_chat_choice(response_payload)
    if first is None:
        return ""
    message = first.get("message")
    if isinstance(message, dict) and message.get("content"):
        return str(message["content"])
    delta = first.get("delta")
    if isinstance(delta, dict) and delta.get("content"):
        return str(delta["content"])
    return ""


def extract_chat_tool_calls(response_payload: dict[str, Any]) -> list[dict[str, Any]]:
    first = first_chat_choice(response_payload)
    if first is None:
        return []
    message = first.get("message")
    if not isinstance(message, dict):
        return []
    tool_calls = message.get("tool_calls")
    if not isinstance(tool_calls, list):
        return []
    return [item for item in tool_calls if isinstance(item, dict)]


def extract_chat_finish_reason(response_payload: dict[str, Any]) -> str | None:
    first = first_chat_choice(response_payload)
    if first is None:
        return None
    finish_reason = first.get("finish_reason")
    return str(finish_reason) if finish_reason else None


def chat_audit_summary(response_payload: dict[str, Any]) -> str:
    content = extract_chat_content(response_payload).strip()
    if content:
        return content
    if extract_chat_tool_calls(response_payload):
        return "OpenAI-compatible tool-call response returned through the LLM Gateway."
    return "OpenAI-compatible response returned without auditable text."


def usage_from_chat_payload(request: ChatCompletionRequest, response_payload: dict[str, Any], content: str) -> dict[str, int]:
    usage = response_payload.get("usage")
    if isinstance(usage, dict):
        prompt_tokens = int(usage.get("prompt_tokens") or usage.get("input_tokens") or 0)
        completion_tokens = int(usage.get("completion_tokens") or usage.get("output_tokens") or 0)
        total_tokens = int(usage.get("total_tokens") or prompt_tokens + completion_tokens)
        return {
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "total_tokens": total_tokens,
        }
    return chat_usage(request, content)


def call_hf_chat_completion(request: ChatCompletionRequest) -> dict[str, Any]:
    token = hf_router_token()
    if not token:
        raise HTTPException(status_code=503, detail="HF_TOKEN is not configured for Hugging Face router calls")

    upstream_payload: dict[str, Any] = {
        "model": normalize_model_id(request.model),
        "messages": chat_message_payloads(request.messages),
        "stream": False,
    }
    if request.temperature is not None:
        upstream_payload["temperature"] = request.temperature
    if request.max_tokens is not None:
        upstream_payload["max_tokens"] = request.max_tokens

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    try:
        with httpx.Client(timeout=HF_ROUTER_TIMEOUT_SECONDS) as client:
            response = client.post(f"{HF_ROUTER_BASE_URL}/chat/completions", headers=headers, json=upstream_payload)
            response.raise_for_status()
        response_payload = response.json()
    except httpx.HTTPStatusError as exc:
        try:
            detail: object = exc.response.json()
        except ValueError:
            detail = exc.response.text or "Hugging Face router request failed"
        raise HTTPException(status_code=exc.response.status_code, detail=detail) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Hugging Face router request failed: {type(exc).__name__}") from exc

    if not isinstance(response_payload, dict):
        raise HTTPException(status_code=502, detail="Hugging Face router returned an invalid payload")
    return response_payload


def call_model_studio_chat_completion(request: ChatCompletionRequest) -> dict[str, Any]:
    token = model_studio_api_key()
    if not token or not model_studio_base_url_valid():
        raise HTTPException(
            status_code=503,
            detail="Alibaba Model Studio gateway configuration is incomplete",
        )
    model = normalize_model_id(request.model)
    if model not in MODEL_STUDIO_MODELS:
        raise HTTPException(status_code=400, detail="Model Studio model is outside the approved allowlist")

    upstream_payload: dict[str, Any] = {
        "model": model,
        "messages": chat_message_payloads(request.messages),
        "stream": False,
    }
    if request.temperature is not None:
        upstream_payload["temperature"] = request.temperature
    if request.max_tokens is not None:
        upstream_payload["max_tokens"] = request.max_tokens
    if request.tools is not None:
        try:
            tool_bytes = len(
                json.dumps(request.tools, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
            )
        except (TypeError, ValueError) as exc:
            raise HTTPException(status_code=422, detail="Model Studio tools must be JSON-serializable") from exc
        if tool_bytes > MAX_CHAT_TOOLS_BYTES:
            raise HTTPException(status_code=422, detail="Model Studio tools exceed the bounded payload limit")
        upstream_payload["tools"] = request.tools
    if request.tool_choice is not None:
        upstream_payload["tool_choice"] = request.tool_choice
    if request.parallel_tool_calls is not None:
        upstream_payload["parallel_tool_calls"] = request.parallel_tool_calls

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    try:
        with httpx.Client(timeout=MODEL_STUDIO_TIMEOUT_SECONDS) as client:
            response = client.post(
                f"{MODEL_STUDIO_BASE_URL}/chat/completions",
                headers=headers,
                json=upstream_payload,
            )
            response.raise_for_status()
        response_payload = response.json()
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=exc.response.status_code,
            detail="Alibaba Model Studio rejected the gateway request",
        ) from exc
    except (httpx.HTTPError, ValueError) as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Alibaba Model Studio gateway request failed: {type(exc).__name__}",
        ) from exc

    if not isinstance(response_payload, dict) or not (
        extract_chat_content(response_payload).strip() or extract_chat_tool_calls(response_payload)
    ):
        raise HTTPException(status_code=502, detail="Alibaba Model Studio returned an invalid payload")
    return response_payload


def call_cloudflare_workers_ai_chat_completion(request: ChatCompletionRequest) -> dict[str, Any]:
    token = cloudflare_workers_ai_token()
    account_id = cloudflare_workers_ai_account_id()
    if not token or not account_id:
        raise HTTPException(
            status_code=503,
            detail="Cloudflare Workers AI credentials are not configured for the approved gateway call",
        )
    if request.model not in CF_WORKERS_AI_MODELS:
        raise HTTPException(status_code=400, detail="Cloudflare Workers AI model is outside the approved allowlist")

    upstream_payload: dict[str, Any] = {
        "messages": chat_message_payloads(request.messages),
        "stream": False,
        "max_tokens": max(
            1,
            min(request.max_tokens or CF_WORKERS_AI_MAX_TOKENS, CF_WORKERS_AI_MAX_TOKENS),
        ),
    }
    if request.temperature is not None:
        upstream_payload["temperature"] = max(0.0, min(request.temperature, 1.0))

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    endpoint = f"{CF_WORKERS_AI_BASE_URL}/accounts/{account_id}/ai/run/{request.model}"
    upstream_response: object | None = None
    for connect_attempt in range(2):
        try:
            with httpx.Client(timeout=CF_WORKERS_AI_TIMEOUT_SECONDS) as client:
                response = client.post(endpoint, headers=headers, json=upstream_payload)
                response.raise_for_status()
            upstream_response = response.json()
            break
        except httpx.HTTPStatusError as exc:
            raise HTTPException(
                status_code=exc.response.status_code,
                detail="Cloudflare Workers AI rejected the gateway request",
            ) from exc
        except (httpx.ConnectError, httpx.ConnectTimeout) as exc:
            # Retry only failures that occur while establishing the connection. Once a
            # request can have reached the provider, retrying could duplicate inference.
            if connect_attempt == 0:
                continue
            raise HTTPException(
                status_code=502,
                detail=f"Cloudflare Workers AI gateway request failed: {type(exc).__name__}",
            ) from exc
        except (httpx.HTTPError, ValueError) as exc:
            raise HTTPException(
                status_code=502,
                detail=f"Cloudflare Workers AI gateway request failed: {type(exc).__name__}",
            ) from exc

    result = upstream_response.get("result") if isinstance(upstream_response, dict) else None
    content = result.get("response") if isinstance(result, dict) else None
    if not isinstance(content, str) or not content.strip():
        raise HTTPException(status_code=502, detail="Cloudflare Workers AI returned no text content")
    usage = result.get("usage") if isinstance(result.get("usage"), dict) else {}
    prompt_tokens = int(usage.get("prompt_tokens") or 0)
    completion_tokens = int(usage.get("completion_tokens") or 0)
    return {
        "id": f"chatcmpl-cf-{uuid4()}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": request.model,
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": content.strip()},
                "finish_reason": "stop",
            }
        ],
        "usage": {
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "total_tokens": int(usage.get("total_tokens") or prompt_tokens + completion_tokens),
        },
    }


def call_local_chat_completion(request: ChatCompletionRequest) -> dict[str, Any]:
    upstream_payload: dict[str, Any] = {
        "model": normalize_model_id(request.model) or LOCAL_LLM_MODEL,
        "messages": chat_message_payloads(request.messages),
        "stream": False,
    }
    if request.temperature is not None:
        upstream_payload["temperature"] = request.temperature
    upstream_payload["max_tokens"] = (
        request.max_tokens if request.max_tokens is not None else LOCAL_LLM_MAX_TOKENS_DEFAULT
    )

    try:
        with httpx.Client(timeout=LOCAL_LLM_TIMEOUT_SECONDS) as client:
            response = client.post(f"{LOCAL_LLM_BASE_URL}/chat/completions", json=upstream_payload)
            response.raise_for_status()
        response_payload = response.json()
    except httpx.HTTPStatusError as exc:
        try:
            detail: object = exc.response.json()
        except ValueError:
            detail = exc.response.text or "local llama.cpp request failed"
        raise HTTPException(status_code=exc.response.status_code, detail=detail) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"local llama.cpp request failed: {type(exc).__name__}") from exc

    if not isinstance(response_payload, dict):
        raise HTTPException(status_code=502, detail="local llama.cpp returned an invalid payload")
    return response_payload


def chat_usage(request: ChatCompletionRequest, content: str) -> dict[str, int]:
    prompt_tokens = count_text_tokens(request.messages)
    completion_tokens = len(content.split())
    return {
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "total_tokens": prompt_tokens + completion_tokens,
    }


def extract_response_output_text(response_payload: dict[str, Any]) -> str:
    output_text = response_payload.get("output_text")
    if isinstance(output_text, str) and output_text.strip():
        return output_text.strip()

    texts: list[str] = []
    for item in response_payload.get("output", []):
        if not isinstance(item, dict) or item.get("type") != "message":
            continue
        for part in item.get("content", []):
            if isinstance(part, dict) and part.get("type") == "output_text" and part.get("text"):
                texts.append(str(part["text"]).strip())
    return "\n".join(text for text in texts if text).strip()


def response_usage_totals(response_payload: dict[str, Any]) -> dict[str, int]:
    usage = response_payload.get("usage")
    if not isinstance(usage, dict):
        return {"input_tokens": 0, "output_tokens": 0, "total_tokens": 0}
    return {
        "input_tokens": int(usage.get("input_tokens") or 0),
        "output_tokens": int(usage.get("output_tokens") or 0),
        "total_tokens": int(usage.get("total_tokens") or 0),
    }


def audit_event(
    request: ChatCompletionRequest,
    content: str,
    usage: dict[str, int],
    *,
    provider_name: str = "deterministic-dry-run",
    status: str = "dry_run",
    live_provider_calls: bool = False,
    cost_cents: int | None = 0,
    cost_status: str = "measured",
) -> bool:
    base_url = os.getenv("AGENT_API_INTERNAL_URL", "").rstrip("/")
    if not base_url:
        return False
    trace_id = str(request.metadata.get("trace_id") or f"llm-dry-run-{uuid4()}")
    payload = {
        "trace_id": trace_id,
        "model_name": request.model,
        "provider_name": provider_name,
        "agent_type": str(request.metadata.get("agent_type") or "unknown"),
        "status": status,
        "input_tokens": usage["prompt_tokens"],
        "output_tokens": usage["completion_tokens"],
        "cost_cents": cost_cents,
        "cost_status": cost_status,
        "live_provider_calls": live_provider_calls,
        "summary": content,
    }
    try:
        with httpx.Client(timeout=3) as client:
            response = client.post(f"{base_url}/internal/audit/llm-events", json=payload)
            response.raise_for_status()
        return True
    except Exception:
        return False


def audit_responses_event(request_payload: dict[str, Any], response_payload: dict[str, Any]) -> bool:
    base_url = os.getenv("AGENT_API_INTERNAL_URL", "").rstrip("/")
    if not base_url:
        return False

    metadata = request_payload.get("metadata")
    metadata_map = metadata if isinstance(metadata, dict) else {}
    usage = response_usage_totals(response_payload)
    summary = extract_response_output_text(response_payload) or "Responses API call completed without text output."
    payload = {
        "trace_id": str(metadata_map.get("trace_id") or f"llm-responses-{uuid4()}"),
        "model_name": str(response_payload.get("model") or request_payload.get("model") or HF_DEFAULT_CHAT_MODEL),
        "provider_name": str(response_payload.get("provider_name") or "responses_adapter"),
        "agent_type": str(metadata_map.get("agent_type") or "unknown"),
        "status": "success" if response_payload.get("status") == "completed" else "error",
        "input_tokens": usage["input_tokens"],
        "output_tokens": usage["output_tokens"],
        "cost_cents": response_payload.get("cost_cents"),
        "cost_status": str(response_payload.get("cost_status") or "unverified"),
        "live_provider_calls": bool(response_payload.get("live_provider_calls")),
        "summary": summary[:500],
    }
    try:
        with httpx.Client(timeout=3) as client:
            response = client.post(f"{base_url}/internal/audit/llm-events", json=payload)
            response.raise_for_status()
        return True
    except Exception:
        return False


def compact_json_byte_count(value: object) -> int:
    return len(json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8"))


def responses_input_char_count(payload: dict[str, Any]) -> int:
    if "input" in payload:
        value = payload.get("input")
        if isinstance(value, str):
            if not value.strip():
                raise HTTPException(status_code=422, detail="input must not be empty")
            return len(value)
        if not isinstance(value, list):
            raise HTTPException(status_code=422, detail="input must be a string or Responses-style message array")

        texts: list[str] = []
        for item in value:
            if not isinstance(item, dict):
                raise HTTPException(status_code=422, detail="input message entries must be objects")
            content = item.get("content")
            if isinstance(content, str):
                texts.append(content)
                continue
            if not isinstance(content, list):
                raise HTTPException(status_code=422, detail="input message content must be text or a text-part array")
            for part in content:
                if not isinstance(part, dict):
                    raise HTTPException(status_code=422, detail="input content parts must be objects")
                if part.get("type") not in {"input_text", "output_text"} or not isinstance(part.get("text"), str):
                    raise HTTPException(status_code=422, detail="only input_text and output_text content parts are supported")
                texts.append(str(part["text"]))
        if not any(text.strip() for text in texts):
            raise HTTPException(status_code=422, detail="input must not be empty")
        return sum(len(text) for text in texts)

    prompt = payload.get("prompt")
    if not isinstance(prompt, dict) or not isinstance(prompt.get("id"), str) or not str(prompt["id"]).strip():
        raise HTTPException(status_code=422, detail="input or a non-empty prompt.id is required")
    return len(str(prompt["id"]))


def normalize_responses_request(payload: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(payload)
    if compact_json_byte_count(normalized) > MAX_RESPONSES_PAYLOAD_BYTES:
        raise HTTPException(status_code=422, detail="Responses request exceeds the payload byte limit")
    if "stream" in normalized and type(normalized.get("stream")) is not bool:
        raise HTTPException(status_code=422, detail="stream must be a boolean")
    normalized.setdefault("stream", False)
    if "max_output_tokens" in normalized:
        max_output_tokens = normalized.get("max_output_tokens")
        if (
            type(max_output_tokens) is not int
            or max_output_tokens < 1
            or max_output_tokens > MAX_RESPONSES_OUTPUT_TOKENS
        ):
            raise HTTPException(
                status_code=422,
                detail=f"max_output_tokens must be an integer between 1 and {MAX_RESPONSES_OUTPUT_TOKENS}",
            )
    if "input" not in normalized and "prompt" not in normalized:
        raise HTTPException(status_code=422, detail="input or prompt is required")
    if responses_input_char_count(normalized) > MAX_RESPONSES_INPUT_CHARS:
        raise HTTPException(status_code=422, detail="Responses input exceeds the character limit")
    instructions = normalized.get("instructions")
    if instructions is not None:
        if not isinstance(instructions, str):
            raise HTTPException(status_code=422, detail="instructions must be a string")
        if not instructions.strip():
            raise HTTPException(status_code=422, detail="instructions must not be empty")
        if len(instructions) > MAX_RESPONSES_INSTRUCTIONS_CHARS:
            raise HTTPException(status_code=422, detail="instructions exceeds the character limit")
    previous_response_id = normalized.get("previous_response_id")
    if previous_response_id is not None:
        if not isinstance(previous_response_id, str):
            raise HTTPException(status_code=422, detail="previous_response_id must be a string")
        match = re.fullmatch(r"resp_(?:dryrun|local|hf)_([0-9a-fA-F-]{36})", previous_response_id)
        if match is None:
            raise HTTPException(status_code=422, detail="previous_response_id format is invalid")
        try:
            if str(UUID(match.group(1))) != match.group(1).lower():
                raise ValueError("non-canonical UUID")
        except ValueError as exc:
            raise HTTPException(status_code=422, detail="previous_response_id format is invalid") from exc
    if "store" in normalized and type(normalized.get("store")) is not bool:
        raise HTTPException(status_code=422, detail="store must be a boolean")
    model = normalized.get("model")
    if model is not None and (not isinstance(model, str) or not model.strip() or len(model) > 120):
        raise HTTPException(status_code=422, detail="model must be a non-empty string no longer than 120 characters")
    if not model:
        normalized["model"] = normalize_model_id(None)
    normalized.setdefault("store", True)
    metadata = normalized.get("metadata")
    if metadata is None:
        metadata = {}
    if not isinstance(metadata, dict):
        raise HTTPException(status_code=422, detail="metadata must be an object")
    if compact_json_byte_count(metadata) > MAX_RESPONSES_METADATA_BYTES:
        raise HTTPException(status_code=422, detail="Responses metadata exceeds the byte limit")
    trace_id = metadata.get("trace_id")
    if trace_id is not None and (not isinstance(trace_id, str) or not trace_id.strip() or len(trace_id) > 255):
        raise HTTPException(status_code=422, detail="metadata.trace_id must be a non-empty string no longer than 255 characters")
    agent_type = metadata.get("agent_type")
    if agent_type is not None and (not isinstance(agent_type, str) or len(agent_type) > 50):
        raise HTTPException(status_code=422, detail="metadata.agent_type must be a string no longer than 50 characters")
    explicit_live_value = metadata.get("live_provider_calls_allowed")
    explicit_live_request = explicit_live_value is True or (
        isinstance(explicit_live_value, str)
        and explicit_live_value.strip().lower() in {"1", "true", "yes"}
    )
    if normalized["stream"] and explicit_live_request:
        raise HTTPException(
            status_code=403,
            detail="Responses streaming is deterministic-only; live provider calls are not allowed",
        )
    normalized["metadata"] = {"gateway_path": "responses_proxy", **metadata}
    return normalized


def responses_input_to_messages(payload: dict[str, Any]) -> list[ChatMessage]:
    messages: list[ChatMessage] = []
    instructions = payload.get("instructions")
    if isinstance(instructions, str):
        messages.append(ChatMessage(role="system", content=instructions))
    previous_response_id = payload.get("previous_response_id")
    if isinstance(previous_response_id, str):
        messages.extend(load_responses_context(previous_response_id))
    value = payload.get("input")
    if isinstance(value, str):
        messages.append(ChatMessage(role="user", content=value))
        return messages
    if isinstance(value, list):
        current_messages: list[ChatMessage] = []
        for item in value:
            if not isinstance(item, dict):
                continue
            role = str(item.get("role") or "user")
            content = item.get("content")
            if isinstance(content, str):
                current_messages.append(ChatMessage(role=role, content=content))
            elif isinstance(content, list):
                texts: list[str] = []
                for part in content:
                    if isinstance(part, dict) and part.get("type") in {"input_text", "output_text"} and part.get("text"):
                        texts.append(str(part["text"]))
                current_messages.append(ChatMessage(role=role, content="\n".join(texts)))
        if current_messages:
            return [*messages, *current_messages]
    prompt = payload.get("prompt")
    if isinstance(prompt, dict) and prompt.get("id"):
        messages.append(ChatMessage(role="user", content=f"Prompt template request: {prompt['id']}"))
        return messages
    messages.append(ChatMessage(role="user", content=""))
    return messages


def responses_adapter_payload(
    normalized: dict[str, Any],
    content: str,
    live_call: bool,
    usage: dict[str, int],
    *,
    local_call: bool = False,
    live_provider_name: str | None = None,
) -> dict[str, Any]:
    created = int(time.time())
    metadata = normalized.get("metadata") if isinstance(normalized.get("metadata"), dict) else {}
    provider_slug = (
        "ms"
        if live_call and live_provider_name == "alibaba_model_studio"
        else "hf"
        if live_call
        else "local"
        if local_call
        else "dryrun"
    )
    return {
        "id": f"resp_{provider_slug}_{uuid4()}",
        "object": "response",
        "created_at": created,
        "status": "completed",
        "error": None,
        "incomplete_details": None,
        "contract_version": LLM_RESPONSES_ADAPTER_CONTRACT_VERSION,
        "evidence_ref": LLM_RESPONSES_ADAPTER_EVIDENCE_REF,
        "trace_id": str(metadata.get("trace_id") or ""),
        "model": normalize_model_id(str(normalized.get("model") or HF_DEFAULT_CHAT_MODEL)),
        "output": [
            {
                "id": f"msg_{provider_slug}_{uuid4()}",
                "type": "message",
                "status": "completed",
                "role": "assistant",
                "content": [{"type": "output_text", "text": content, "annotations": []}],
            }
        ],
        "output_text": content,
        "gateway_mode": GATEWAY_MODE,
        "provider_name": (
            live_provider_name or "huggingface_inference_router"
            if live_call
            else "local_llama_cpp"
            if local_call
            else "deterministic-dry-run"
        ),
        "live_provider_calls": live_call,
        "local_model_calls": local_call,
        "model_downloads": False,
        "secret_output": False,
        "cost_cents": None if live_call else 0,
        "cost_status": "provider_invoice_unverified" if live_call else "zero_cost_non_provider",
        "usage": {
            "input_tokens": usage.get("prompt_tokens", 0),
            "output_tokens": usage.get("completion_tokens", 0),
            "total_tokens": usage.get("total_tokens", 0),
        },
    }


def validate_responses_output_text(content: str) -> None:
    if not content:
        raise HTTPException(status_code=502, detail="Responses adapter produced empty output text")
    if len(content) > MAX_RESPONSES_OUTPUT_CHARS:
        raise HTTPException(status_code=502, detail="Responses adapter output exceeds the character limit")


def responses_stream_text_deltas(text: str) -> list[str]:
    if not text:
        return []
    chunks = [text[index : index + RESPONSES_STREAM_CHUNK_CHARS] for index in range(0, len(text), RESPONSES_STREAM_CHUNK_CHARS)]
    if len(chunks) == 1 and len(text) > 1:
        midpoint = max(1, len(text) // 2)
        chunks = [text[:midpoint], text[midpoint:]]
    return [chunk for chunk in chunks if chunk]


def responses_stream_events(response_payload: dict[str, Any]) -> list[dict[str, Any]]:
    output = response_payload.get("output")
    if not isinstance(output, list) or len(output) != 1 or not isinstance(output[0], dict):
        raise ValueError("Responses streaming requires exactly one message output item")
    item = copy.deepcopy(output[0])
    item_id = str(item.get("id") or "")
    content_parts = item.get("content")
    if not item_id or not isinstance(content_parts, list) or len(content_parts) != 1 or not isinstance(content_parts[0], dict):
        raise ValueError("Responses streaming requires exactly one output text content part")
    part = copy.deepcopy(content_parts[0])
    text = part.get("text")
    if not isinstance(text, str) or text != response_payload.get("output_text"):
        raise ValueError("Responses streaming output text must match the terminal response")

    pending_response = copy.deepcopy(response_payload)
    pending_response["status"] = "in_progress"
    pending_response["output"] = []
    pending_response["output_text"] = ""
    pending_item = copy.deepcopy(item)
    pending_item["status"] = "in_progress"
    pending_item["content"] = []
    pending_part = {"type": "output_text", "text": "", "annotations": []}

    events: list[dict[str, Any]] = []

    def append(event: dict[str, Any]) -> None:
        event["sequence_number"] = len(events)
        events.append(event)

    append({"type": "response.created", "response": copy.deepcopy(pending_response)})
    append({"type": "response.in_progress", "response": copy.deepcopy(pending_response)})
    append({"type": "response.output_item.added", "output_index": 0, "item": pending_item})
    append(
        {
            "type": "response.content_part.added",
            "item_id": item_id,
            "output_index": 0,
            "content_index": 0,
            "part": pending_part,
        }
    )
    for delta in responses_stream_text_deltas(text):
        append(
            {
                "type": "response.output_text.delta",
                "item_id": item_id,
                "output_index": 0,
                "content_index": 0,
                "delta": delta,
            }
        )
    append(
        {
            "type": "response.output_text.done",
            "item_id": item_id,
            "output_index": 0,
            "content_index": 0,
            "text": text,
        }
    )
    append(
        {
            "type": "response.content_part.done",
            "item_id": item_id,
            "output_index": 0,
            "content_index": 0,
            "part": part,
        }
    )
    append({"type": "response.output_item.done", "output_index": 0, "item": item})
    append({"type": "response.completed", "response": copy.deepcopy(response_payload)})
    return events


def responses_adapter_contract_snapshot() -> dict[str, object]:
    return {
        "contract_version": LLM_RESPONSES_ADAPTER_CONTRACT_VERSION,
        "evidence_ref": LLM_RESPONSES_ADAPTER_EVIDENCE_REF,
        "status": "verified_local_dry_run_contract",
        "mode": "openai_responses_compatible_gateway_adapter",
        "endpoint": "GET /llm/api/v1/responses/contract",
        "runtime_endpoint": "POST /llm/v1/responses",
        "service_route": "GET /api/v1/responses/contract",
        "service_runtime_route": "POST /v1/responses",
        "covered_boundary": "L3 live-agent steering to L4 LLM Gateway Responses adapter",
        "adapter": {
            "upstream_provider": "gateway_mode_selected_openai_compatible_provider",
            "supported_live_providers": ["alibaba_model_studio", "huggingface_inference_router"],
            "upstream_chat_endpoint": "/v1/chat/completions",
            "dry_run_provider": "deterministic-dry-run",
            "stream_passthrough": False,
            "streaming_protocol": RESPONSES_STREAMING_PROTOCOL,
            "stateful_sessions_supported": True,
            "stateful_session_scope": "bounded_process_local_context_store",
            "model_downloads": False,
            "openai_key_required": False,
        },
        "request_schema": {
            "model": "string model id or gateway default",
            "input": "string or Responses-style message array",
            "instructions": f"optional string, maximum {MAX_RESPONSES_INSTRUCTIONS_CHARS} characters; prepended as system context",
            "store": "boolean, default true",
            "previous_response_id": "optional adapter response id for bounded process-local continuity",
            "metadata.trace_id": "required for audited agent path",
            "metadata.agent_type": "planner|coder|tester|devops|unknown",
            "metadata.live_provider_calls_allowed": "must be explicitly true before live gateway attempt",
            "stream": "boolean, default false; true emits deterministic Responses-native SSE",
            "max_output_tokens": f"optional integer from 1 through {MAX_RESPONSES_OUTPUT_TOKENS}",
        },
        "response_schema": {
            "id": "resp_dryrun_*, resp_local_*, resp_ms_*, or resp_hf_*",
            "object": "response",
            "status": "completed",
            "contract_version": LLM_RESPONSES_ADAPTER_CONTRACT_VERSION,
            "evidence_ref": LLM_RESPONSES_ADAPTER_EVIDENCE_REF,
            "trace_id": "metadata.trace_id echo when supplied",
            "output": "Responses-style message array",
            "output_text": "flattened assistant text",
            "gateway_mode": GATEWAY_MODE,
            "provider_name": "deterministic-dry-run unless the active gateway provider passes all live gates",
            "live_provider_calls": "false in default local and hosted gate-closed mode",
            "local_model_calls": "true only when the local runtime handled the request",
            "model_downloads": False,
            "audit_persisted": "true when Agent API audit sink is reachable",
            "secret_output": False,
            "usage": "input_tokens, output_tokens, total_tokens",
        },
        "streaming_schema": {
            "protocol": RESPONSES_STREAMING_PROTOCOL,
            "media_type": "text/event-stream",
            "provider_passthrough": False,
            "deterministic_only": True,
            "audit_before_emit": True,
            "event_order": [
                "response.created",
                "response.in_progress",
                "response.output_item.added",
                "response.content_part.added",
                "response.output_text.delta",
                "response.output_text.done",
                "response.content_part.done",
                "response.output_item.done",
                "response.completed",
            ],
            "sequence_number": "monotonic integer starting at zero",
            "done_sentinel": False,
            "limits": {
                "input_chars": MAX_RESPONSES_INPUT_CHARS,
                "output_chars": MAX_RESPONSES_OUTPUT_CHARS,
                "output_tokens": MAX_RESPONSES_OUTPUT_TOKENS,
                "metadata_bytes": MAX_RESPONSES_METADATA_BYTES,
                "payload_bytes": MAX_RESPONSES_PAYLOAD_BYTES,
                "instructions_chars": MAX_RESPONSES_INSTRUCTIONS_CHARS,
                "stored_context_chars": MAX_RESPONSES_STORED_CONTEXT_CHARS,
                "stored_contexts": MAX_RESPONSES_STORED_CONTEXTS,
                "context_ttl_seconds": RESPONSES_CONTEXT_TTL_SECONDS,
                "delta_chars": RESPONSES_STREAM_CHUNK_CHARS,
            },
        },
        "negative_cases": [
            {"request": {"stream": "true"}, "expected_status": 422, "reason": "stream must remain a boolean"},
            {
                "request": {"stream": True, "metadata": {"live_provider_calls_allowed": True}},
                "expected_status": 403,
                "reason": "Responses streaming is deterministic-only and never activates a provider",
            },
            {"request": {"metadata": "not-an-object"}, "expected_status": 422, "reason": "metadata must stay structured for trace/audit policy"},
            {
                "request": {"max_output_tokens": MAX_RESPONSES_OUTPUT_TOKENS + 1},
                "expected_status": 422,
                "reason": "requested output tokens must stay within the bounded adapter limit",
            },
        ],
        "failure_cases": [
            {
                "condition": "stream audit persistence unavailable or rejected",
                "expected_status": 503,
                "terminal_event_emitted": False,
                "reason": "no successful Responses stream is emitted without a persisted audit",
            },
            {
                "condition": "previous_response_id unknown or expired",
                "expected_status": 404,
                "reason": "bounded process-local continuity fails closed on a context miss",
            },
        ],
        "policy_checks": [
            "Agent API calls POST /llm/v1/responses through the LLM Gateway only.",
            "The adapter never uses an OpenAI API key or direct provider URL.",
            "Live provider calls require the matching credential, approved gateway mode, owner environment gate, explicit request approval, and persisted preflight/completion audits.",
            "Default local and gate-closed hosted proofs keep live_provider_calls=false and cost_cents=0.",
            "Responses streaming buffers one deterministic result, audits it, and then emits Responses-native SSE without provider passthrough.",
            "Audit payloads are redacted by the Agent API sink before persistence.",
        ],
        "evidence_refs": [
            LLM_RESPONSES_ADAPTER_EVIDENCE_REF,
            "llm_gateway_dry_run",
            "llm_gateway_responses_audit_persisted",
            "live_agent_steering_contract_visible",
        ],
        "non_claims": [
            "This contract does not open a live LLM provider call.",
            "This contract does not expose provider credentials or secrets.",
            "This contract does not download local models.",
            "This contract does not claim production deployment or hosted staging completion.",
        ],
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "model_downloads": False,
        "production_deploy": False,
        "secret_output": False,
    }


@app.get("/api/v1/health")
def health() -> dict[str, object]:
    cloudflare_mode = cloudflare_workers_ai_mode_enabled()
    model_studio_mode = model_studio_mode_enabled()
    # Health must describe the active gateway without performing an unrelated
    # Hugging Face provider read. In Cloudflare mode that network probe can
    # exceed the Agent API's three-second dependency timeout and make an
    # otherwise healthy local stack flap to degraded.
    router = provider_router_snapshot_for_gateway_mode(limit=5)
    provider_available = (
        cloudflare_workers_ai_available()
        if cloudflare_mode
        else model_studio_available()
        if model_studio_mode
        else hf_router_available()
    )
    return {
        "status": "healthy",
        "service": "llm-gateway",
        "mode": GATEWAY_MODE,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "live_provider_calls_available": provider_available,
        "openai_compatible": True,
        "open_source_first": True,
        "model_downloads": False,
        "provider": (
            "local_llama_cpp"
            if local_llm_enabled()
            else "cloudflare-workers-ai"
            if cloudflare_mode
            else "alibaba_model_studio"
            if model_studio_mode
            else "huggingface_inference_router"
        ),
        "routing_resolver": True,
        "routing_policy": True,
        "provider_health": True,
        "provider_live_verified": bool(router["live_verified"]),
        "provider_status": (
            "configured"
            if cloudflare_mode and provider_available
            else "configured_gate_closed"
            if model_studio_mode and provider_available
            else "missing_api_key_or_endpoint"
            if model_studio_mode
            else router["status"]
        ),
        "provider_model_count_visible": (
            len(CF_WORKERS_AI_MODELS)
            if cloudflare_mode
            else len(MODEL_STUDIO_MODELS)
            if model_studio_mode
            else router["model_count_visible"]
        ),
        "local_llm": {
            "enabled": local_llm_enabled(),
            # Only probe the optional local provider when it is actually enabled. In cloud /
            # deterministic_dry_run mode there is no local-llm host, and an unconditional probe
            # blocks on the connect timeout (~3s) and fails the container healthcheck.
            "healthy": local_llm_health() if local_llm_enabled() else False,
            "base_url": LOCAL_LLM_BASE_URL,
            "model": LOCAL_LLM_MODEL,
        },
        "streaming_sse": True,
        "streaming_protocol": STREAMING_PROTOCOL,
        "models_configured": len(model_ids()),
        "hf_router": huggingface_router_capability_snapshot(),
        "model_studio": model_studio_capability_snapshot(),
        "responses_api": (
            model_studio_capability_snapshot()
            if model_studio_mode
            else huggingface_router_capability_snapshot()
        ),
        "non_claims": [
            "No model files are downloaded by this gateway.",
            "Generation calls require the active provider credential plus request policy/metadata approval.",
            "OpenAI-compatible means wire protocol compatibility, not OpenAI provider dependency.",
        ],
    }


@app.get("/v1/models")
def models() -> dict[str, object]:
    if local_llm_enabled():
        merged = [LOCAL_LLM_MODEL]
        return {
            "object": "list",
            "data": [
                {
                    "id": LOCAL_LLM_MODEL,
                    "object": "model",
                    "owned_by": "local_llama_cpp",
                    "configured_route": True,
                    "open_source_first": True,
                    "live_verified": local_llm_health(),
                }
            ],
            "live_provider_calls": False,
            "live_provider_calls_available": True,
            "provider": "local_llama_cpp",
            "router_status": "not_applicable_local_mode",
            "model_downloads": True,
        }
    if model_studio_mode_enabled():
        return {
            "object": "list",
            "data": [
                {
                    "id": model_id,
                    "object": "model",
                    "owned_by": "alibaba_model_studio",
                    "configured_route": True,
                    "open_source_first": False,
                    "live_verified": False,
                    "gateway_only": True,
                }
                for model_id in sorted(MODEL_STUDIO_MODELS)
            ],
            "live_provider_calls": False,
            "live_provider_calls_available": model_studio_available(),
            "provider": "alibaba_model_studio",
            "router_status": (
                "configured_gate_closed" if model_studio_available() else "missing_api_key_or_endpoint"
            ),
            "model_downloads": False,
            "secret_output": False,
        }
    router = hf_router_model_snapshot(limit=200)
    route_models = set(model_ids())
    visible = router["models"] if router["live_verified"] else []
    merged = sorted(route_models.union(str(item) for item in visible))
    return {
        "object": "list",
        "data": [
            {
                "id": model_id,
                "object": "model",
                "owned_by": provider_for_model(model_id),
                "configured_route": model_id in route_models,
                "open_source_first": provider_for_model(model_id) != "alibaba_model_studio",
                "live_verified": (
                    bool(router["live_verified"])
                    if provider_for_model(model_id) == "huggingface_inference_router"
                    else False
                ),
            }
            for model_id in merged
        ],
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "live_provider_calls_available": hf_router_available(),
        "provider": "huggingface_inference_router",
        "router_status": router["status"],
        "model_downloads": False,
    }


@app.get("/api/v1/routes")
def routes() -> dict[str, object]:
    return {
        "mode": GATEWAY_MODE,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "routes": MODEL_ROUTES,
    }


@app.get("/api/v1/providers/status")
def providers_status() -> dict[str, object]:
    return provider_status_snapshot()


@app.get("/api/v1/streaming/contract")
def streaming_contract() -> dict[str, object]:
    return streaming_contract_snapshot()


@app.get("/api/v1/responses/contract")
def responses_adapter_contract() -> dict[str, object]:
    return responses_adapter_contract_snapshot()


@app.get("/api/v1/routing/policy/contract")
def routing_policy_contract() -> dict[str, object]:
    return routing_policy_contract_snapshot()


@app.post("/api/v1/routing/policy/evaluate")
def routing_policy_evaluate(request: RoutingPolicyRequest) -> dict[str, object]:
    return evaluate_routing_policy(request)


@app.post("/api/v1/routing/resolve")
def routing_resolve(request: RoutingResolveRequest) -> dict[str, object]:
    return resolve_route(request)


@app.post("/v1/chat/completions")
def chat_completions(request: ChatCompletionRequest):
    created = int(time.time())
    requested_provider = provider_for_model(request.model)
    # Local llama.cpp is an optional, open-source, local-CPU provider. When it is enabled but
    # unavailable/unhealthy (still loading model, saturated, or down), degrade gracefully to the
    # deterministic dry-run path instead of hard-failing — a missing optional local provider must
    # not turn a Phase-2 orchestration run into a 500.
    # A caller (e.g. the Phase-2 LangGraph orchestrator) can demand the deterministic dry-run path
    # explicitly; it must not be routed through the slow local model or any live provider.
    deterministic_only = isinstance(request.metadata, dict) and request.metadata.get("deterministic_dry_run") is True
    live_requested = request_requests_live_provider(request.metadata)
    if live_requested and not LLM_LIVE_PROVIDER_DEFAULT and not local_llm_enabled() and not deterministic_only:
        raise HTTPException(status_code=403, detail="External live-provider owner gate is closed")
    live_allowed = request_allows_live_provider(request.metadata)
    local_live_call = local_llm_enabled() and local_llm_health() and not deterministic_only
    model_studio_live_call = (
        model_studio_mode_enabled()
        and requested_provider == "alibaba_model_studio"
        and live_allowed
        and model_studio_available()
        and not deterministic_only
    )
    cloudflare_live_call = (
        cloudflare_workers_ai_mode_enabled()
        and live_allowed
        and cloudflare_workers_ai_available()
        and not deterministic_only
    )
    hf_live_call = (
        not cloudflare_workers_ai_mode_enabled()
        and not model_studio_mode_enabled()
        and requested_provider != "alibaba_model_studio"
        and live_allowed
        and hf_router_available()
        and not deterministic_only
    )
    live_call = model_studio_live_call or cloudflare_live_call or hf_live_call
    completion_id = f"chatcmpl-{'local' if local_live_call else 'ms' if model_studio_live_call else 'cf' if cloudflare_live_call else 'hf' if hf_live_call else 'dryrun'}-{uuid4()}"

    if local_live_call:
        response_payload = call_local_chat_completion(request)
        content = extract_chat_content(response_payload)
        usage = usage_from_chat_payload(request, response_payload, content)
        audit_persisted = audit_event(
            request,
            content,
            usage,
            provider_name="local_llama_cpp",
            status="success",
            live_provider_calls=False,
        )
        response_payload["gateway_mode"] = GATEWAY_MODE
        response_payload["provider_name"] = "local_llama_cpp"
        response_payload["requested_model"] = request.model
        response_payload["model"] = response_payload.get("model") or normalize_model_id(request.model)
        response_payload["live_provider_calls"] = False
        response_payload["local_model_calls"] = True
        response_payload["audit_persisted"] = audit_persisted
        response_payload["cost_cents"] = 0
        response_payload["model_downloads"] = False
    elif model_studio_live_call:
        preflight_usage = {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}
        preflight_persisted = audit_event(
            request,
            "Model Studio live request authorized; upstream call pending.",
            preflight_usage,
            provider_name="alibaba_model_studio",
            status="authorized",
            live_provider_calls=False,
            cost_cents=None,
            cost_status="provider_invoice_unverified",
        )
        if not preflight_persisted:
            raise HTTPException(status_code=503, detail="Live-provider audit preflight persistence failed")
        response_payload = call_model_studio_chat_completion(request)
        content = extract_chat_content(response_payload)
        usage = usage_from_chat_payload(request, response_payload, content)
        audit_persisted = audit_event(
            request,
            chat_audit_summary(response_payload),
            usage,
            provider_name="alibaba_model_studio",
            status="success",
            live_provider_calls=True,
            cost_cents=None,
            cost_status="provider_invoice_unverified",
        )
        if not audit_persisted:
            raise HTTPException(status_code=503, detail="Live-provider completion audit persistence failed")
        response_payload["gateway_mode"] = GATEWAY_MODE
        response_payload["provider"] = "alibaba_model_studio"
        response_payload["provider_name"] = "alibaba_model_studio"
        response_payload["requested_model"] = request.model
        response_payload["model"] = response_payload.get("model") or normalize_model_id(request.model)
        response_payload["live_provider_calls"] = True
        response_payload["local_model_calls"] = False
        response_payload["audit_persisted"] = audit_persisted
        response_payload["cost_cents"] = None
        response_payload["cost_status"] = "provider_invoice_unverified"
        response_payload["model_downloads"] = False
        response_payload["secret_output"] = False
    elif cloudflare_live_call:
        response_payload = call_cloudflare_workers_ai_chat_completion(request)
        content = extract_chat_content(response_payload)
        usage = usage_from_chat_payload(request, response_payload, content)
        audit_persisted = audit_event(
            request,
            content,
            usage,
            provider_name="cloudflare-workers-ai",
            status="success",
            live_provider_calls=True,
        )
        response_payload["gateway_mode"] = GATEWAY_MODE
        response_payload["provider"] = "cloudflare-workers-ai"
        response_payload["provider_name"] = "cloudflare-workers-ai"
        response_payload["requested_model"] = request.model
        response_payload["live_provider_calls"] = True
        response_payload["local_model_calls"] = False
        response_payload["audit_persisted"] = audit_persisted
        response_payload["cost_cents"] = 0
        response_payload["model_downloads"] = False
    elif hf_live_call:
        response_payload = call_hf_chat_completion(request)
        content = extract_chat_content(response_payload)
        usage = usage_from_chat_payload(request, response_payload, content)
        audit_persisted = audit_event(
            request,
            content,
            usage,
            provider_name="huggingface_inference_router",
            status="success",
            live_provider_calls=True,
        )
        response_payload["gateway_mode"] = GATEWAY_MODE
        response_payload["provider_name"] = "huggingface_inference_router"
        response_payload["requested_model"] = request.model
        response_payload["model"] = response_payload.get("model") or normalize_model_id(request.model)
        response_payload["live_provider_calls"] = True
        response_payload["local_model_calls"] = False
        response_payload["audit_persisted"] = audit_persisted
        response_payload["cost_cents"] = 0
        response_payload["model_downloads"] = False
    else:
        if (
            live_allowed
            and requested_provider == "alibaba_model_studio"
            and not model_studio_mode_enabled()
            and not deterministic_only
        ):
            raise HTTPException(
                status_code=503,
                detail="Alibaba Model Studio requires the approved LLM Gateway mode",
            )
        if (
            live_allowed
            and model_studio_mode_enabled()
            and requested_provider != "alibaba_model_studio"
            and not deterministic_only
        ):
            raise HTTPException(
                status_code=400,
                detail="Requested model is outside the active Model Studio allowlist",
            )
        if (
            live_allowed
            and model_studio_mode_enabled()
            and not model_studio_available()
            and not deterministic_only
        ):
            raise HTTPException(
                status_code=503,
                detail="Alibaba Model Studio gateway configuration is incomplete",
            )
        if (
            live_allowed
            and cloudflare_workers_ai_mode_enabled()
            and not cloudflare_workers_ai_available()
            and not deterministic_only
        ):
            raise HTTPException(
                status_code=503,
                detail="Cloudflare Workers AI credentials are required for the approved gateway call",
            )
        if live_allowed and not hf_router_available() and not local_live_call and not deterministic_only:
            raise HTTPException(status_code=503, detail="HF_TOKEN is required for live Hugging Face router calls")
        content = deterministic_content(request)
        usage = chat_usage(request, content)
        audit_persisted = audit_event(request, content, usage)
        response_payload = {
            "id": completion_id,
            "object": "chat.completion",
            "created": created,
            "model": normalize_model_id(request.model),
            "choices": [
                {
                    "index": 0,
                    "message": {"role": "assistant", "content": content},
                    "finish_reason": "stop",
                }
            ],
            "usage": usage,
            "live_provider_calls": LIVE_PROVIDER_CALLS,
            "local_model_calls": False,
            "live_provider_calls_available": hf_router_available(),
            "audit_persisted": audit_persisted,
            "cost_cents": 0,
            "provider_name": "deterministic-dry-run",
            "model_downloads": False,
            "secret_output": False,
        }

    if request.stream:
        def events():
            response_tool_calls = extract_chat_tool_calls(response_payload)
            delta = (
                {"role": "assistant", "tool_calls": response_tool_calls}
                if response_tool_calls
                else {"content": content}
            )
            finish_reason = extract_chat_finish_reason(response_payload) or (
                "tool_calls" if response_tool_calls else "stop"
            )
            chunk = {
                "id": completion_id,
                "object": "chat.completion.chunk",
                "created": created,
                "model": response_payload.get("model") or normalize_model_id(request.model),
                "choices": [{"index": 0, "delta": delta, "finish_reason": None}],
                "live_provider_calls": live_call,
                "audit_persisted": audit_persisted,
                "provider_name": response_payload.get("provider_name"),
                "model_downloads": False,
            }
            yield f"data: {json.dumps(chunk, separators=(',', ':'))}\n\n"
            done = {
                "id": completion_id,
                "object": "chat.completion.chunk",
                "created": created,
                "model": response_payload.get("model") or normalize_model_id(request.model),
                "choices": [{"index": 0, "delta": {}, "finish_reason": finish_reason}],
            }
            yield f"data: {json.dumps(done, separators=(',', ':'))}\n\n"
            yield "data: [DONE]\n\n"

        return StreamingResponse(events(), media_type="text/event-stream")

    return response_payload


@app.post("/v1/responses")
def create_response(payload: dict[str, Any]):
    normalized = normalize_responses_request(payload)
    chat_request = ChatCompletionRequest(
        model=str(normalized.get("model") or normalize_model_id(None)),
        messages=responses_input_to_messages(normalized),
        stream=False,
        temperature=normalized.get("temperature") if isinstance(normalized.get("temperature"), (int, float)) else None,
        max_tokens=normalized.get("max_output_tokens") if isinstance(normalized.get("max_output_tokens"), int) else None,
        metadata=normalized.get("metadata") if isinstance(normalized.get("metadata"), dict) else {},
    )
    stream_requested = normalized.get("stream") is True
    deterministic_only = stream_requested or chat_request.metadata.get("deterministic_dry_run") is True
    live_requested = request_requests_live_provider(chat_request.metadata)
    if live_requested and not LLM_LIVE_PROVIDER_DEFAULT and not local_llm_enabled() and not deterministic_only:
        raise HTTPException(status_code=403, detail="External live-provider owner gate is closed")
    live_allowed = request_allows_live_provider(chat_request.metadata)
    requested_provider = provider_for_model(chat_request.model)
    local_call = False
    live_call = False
    live_provider_name: str | None = None
    if deterministic_only:
        content = deterministic_content(chat_request)
        usage = chat_usage(chat_request, content)
    elif local_llm_enabled() and local_llm_health():
        chat_payload = call_local_chat_completion(chat_request)
        content = extract_chat_content(chat_payload)
        usage = usage_from_chat_payload(chat_request, chat_payload, content)
        local_call = True
    elif (
        live_allowed
        and requested_provider == "alibaba_model_studio"
        and not model_studio_mode_enabled()
    ):
        raise HTTPException(
            status_code=503,
            detail="Alibaba Model Studio requires the approved LLM Gateway mode",
        )
    elif live_allowed and model_studio_mode_enabled() and requested_provider != "alibaba_model_studio":
        raise HTTPException(status_code=400, detail="Requested model is outside the active Model Studio allowlist")
    elif live_allowed and model_studio_mode_enabled() and not model_studio_available():
        raise HTTPException(
            status_code=503,
            detail="Alibaba Model Studio gateway configuration is incomplete",
        )
    elif live_allowed and model_studio_mode_enabled():
        preflight_usage = {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0}
        preflight_persisted = audit_event(
            chat_request,
            "Model Studio live Responses request authorized; upstream call pending.",
            preflight_usage,
            provider_name="alibaba_model_studio",
            status="authorized",
            live_provider_calls=False,
            cost_cents=None,
            cost_status="provider_invoice_unverified",
        )
        if not preflight_persisted:
            raise HTTPException(status_code=503, detail="Live-provider audit preflight persistence failed")
        chat_payload = call_model_studio_chat_completion(chat_request)
        content = extract_chat_content(chat_payload)
        usage = usage_from_chat_payload(chat_request, chat_payload, content)
        live_call = True
        live_provider_name = "alibaba_model_studio"
    elif live_allowed and not hf_router_available():
        raise HTTPException(status_code=503, detail="HF_TOKEN is required for live Hugging Face router calls")
    elif live_allowed:
        chat_payload = call_hf_chat_completion(chat_request)
        content = extract_chat_content(chat_payload)
        usage = usage_from_chat_payload(chat_request, chat_payload, content)
        live_call = True
    else:
        content = deterministic_content(chat_request)
        usage = chat_usage(chat_request, content)

    validate_responses_output_text(content)
    response_payload = responses_adapter_payload(
        normalized,
        content,
        live_call,
        usage,
        local_call=local_call,
        live_provider_name=live_provider_name,
    )
    audit_persisted = audit_responses_event(normalized, response_payload)
    response_payload["audit_persisted"] = audit_persisted
    if live_call and not audit_persisted:
        raise HTTPException(status_code=503, detail="Live-provider completion audit persistence failed")
    if stream_requested and not audit_persisted:
        raise HTTPException(status_code=503, detail="Responses stream audit persistence failed before emission")
    if audit_persisted and normalized.get("store") is True:
        store_responses_context(
            str(response_payload["id"]),
            [*chat_request.messages, ChatMessage(role="assistant", content=content)],
        )
    if stream_requested:
        event_payloads = responses_stream_events(response_payload)

        def events():
            for event in event_payloads:
                event_type = str(event["type"])
                yield f"event: {event_type}\ndata: {json.dumps(event, separators=(',', ':'))}\n\n"

        return StreamingResponse(
            events(),
            media_type="text/event-stream",
            headers={"Cache-Control": "no-store", "X-Accel-Buffering": "no"},
        )
    return response_payload
