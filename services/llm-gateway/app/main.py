from __future__ import annotations

import hashlib
import json
import os
import time
from typing import Any
from uuid import uuid4

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
CF_WORKERS_AI_MAX_TOKENS = int(os.getenv("CF_WORKERS_AI_MAX_TOKENS", "2048") or "2048")
CF_WORKERS_AI_MODE = "cloudflare_workers_ai_live"
CF_WORKERS_AI_MODELS = {
    "@cf/qwen/qwen2.5-coder-32b-instruct",
    "@cf/meta/llama-3.1-8b-instruct",
}
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
ROUTING_POLICY_CONTRACT_VERSION = "llm-routing-policy-v1"
LLM_RESPONSES_ADAPTER_CONTRACT_VERSION = "llm-responses-adapter-contract-v1"
LLM_RESPONSES_ADAPTER_EVIDENCE_REF = "llm_responses_adapter_contract_visible"
MAX_FALLBACKS_PER_REQUEST = 2
MAX_RETRY_CYCLES_PER_RUN = 5

LEGACY_MODEL_ALIASES = {
    "deepseek-chat": "deepseek-ai/DeepSeek-V4-Flash:fastest",
    "qwen-coder": "Qwen/Qwen3-Coder-Next:fastest",
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
        "primary": "Qwen/Qwen3-Coder-Next:fastest",
        "fallbacks": ["deepseek-ai/DeepSeek-V4-Flash:fastest", "google/gemma-4-31B-it:fastest"],
        "max_output_tokens": 8192,
        "supports_streaming": True,
        "configured_only": False,
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
    content: str | list[dict[str, Any]]


class ChatCompletionRequest(BaseModel):
    model: str = Field(..., min_length=1)
    messages: list[ChatMessage] = Field(default_factory=list)
    stream: bool = False
    temperature: float | None = None
    max_tokens: int | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


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


def provider_status_snapshot() -> dict[str, object]:
    router = hf_router_model_snapshot()
    local_status = "healthy" if local_llm_health() else "starting_or_unavailable"

    return {
        "mode": GATEWAY_MODE,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "live_provider_calls_available": hf_router_available(),
        "live_verified": False,
        "policy": {
            "rotation_backoff_seconds": ROTATION_BACKOFF_SECONDS,
            "reset_after_seconds": PROVIDER_RESET_AFTER_SECONDS,
            "never_break_budget": True,
            "external_provider_calls_disabled_by_default": not LLM_LIVE_PROVIDER_DEFAULT,
            "requires_request_metadata": "metadata.live_provider_calls_allowed=true",
        },
        "providers": [
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
    router = hf_router_model_snapshot(limit=5)

    return {
        "mode": GATEWAY_MODE,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "live_provider_calls_available": hf_router_available(),
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
        "configured_only": False,
        "live_verified": bool(router["live_verified"]),
        "budget_level": request.budget_level,
        "provider_health": {
            "provider": selected_provider,
            "status": router["status"],
            "live_verified": bool(router["live_verified"]),
            "live_provider_calls": False,
            "live_provider_calls_available": hf_router_available(),
            "model_downloads": False,
            "non_claim": "Router availability is verified through HF /v1/models; generation is still policy-gated.",
        },
        "policy": {
            "rotation_backoff_seconds": ROTATION_BACKOFF_SECONDS,
            "reset_after_seconds": PROVIDER_RESET_AFTER_SECONDS,
            "never_break_budget": True,
            "external_provider_calls_disabled_by_default": not LLM_LIVE_PROVIDER_DEFAULT,
            "requires_request_metadata": "metadata.live_provider_calls_allowed=true",
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


def request_allows_live_provider(metadata: dict[str, Any] | None) -> bool:
    metadata = metadata or {}
    value = metadata.get("live_provider_calls_allowed")
    if value is None:
        return LLM_LIVE_PROVIDER_DEFAULT
    return value is True or (isinstance(value, str) and value.strip().lower() in {"1", "true", "yes"})


def chat_message_payloads(messages: list[ChatMessage]) -> list[dict[str, Any]]:
    payloads: list[dict[str, Any]] = []
    for message in messages:
        payloads.append({"role": message.role, "content": message.content})
    return payloads


def extract_chat_content(response_payload: dict[str, Any]) -> str:
    choices = response_payload.get("choices")
    if not isinstance(choices, list) or not choices:
        return ""
    first = choices[0]
    if not isinstance(first, dict):
        return ""
    message = first.get("message")
    if isinstance(message, dict) and message.get("content"):
        return str(message["content"])
    delta = first.get("delta")
    if isinstance(delta, dict) and delta.get("content"):
        return str(delta["content"])
    return ""


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
    try:
        with httpx.Client(timeout=CF_WORKERS_AI_TIMEOUT_SECONDS) as client:
            response = client.post(endpoint, headers=headers, json=upstream_payload)
            response.raise_for_status()
        upstream_response = response.json()
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=exc.response.status_code,
            detail="Cloudflare Workers AI rejected the gateway request",
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
        "cost_cents": 0,
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
        "provider_name": "huggingface_router_responses_adapter",
        "agent_type": str(metadata_map.get("agent_type") or "unknown"),
        "status": "success" if response_payload.get("status") == "completed" else "error",
        "input_tokens": usage["input_tokens"],
        "output_tokens": usage["output_tokens"],
        "cost_cents": 0,
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


def normalize_responses_request(payload: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(payload)
    if normalized.get("stream") is True:
        raise HTTPException(status_code=501, detail="stream=true is not supported on this /v1/responses proxy")
    if "input" not in normalized and "prompt" not in normalized:
        raise HTTPException(status_code=422, detail="input or prompt is required")
    if not normalized.get("model"):
        normalized["model"] = normalize_model_id(None)
    normalized.setdefault("store", True)
    metadata = normalized.get("metadata")
    if metadata is None:
        metadata = {}
    if not isinstance(metadata, dict):
        raise HTTPException(status_code=422, detail="metadata must be an object")
    normalized["metadata"] = {"gateway_path": "responses_proxy", **metadata}
    return normalized


def responses_input_to_messages(payload: dict[str, Any]) -> list[ChatMessage]:
    value = payload.get("input")
    if isinstance(value, str):
        return [ChatMessage(role="user", content=value)]
    if isinstance(value, list):
        messages: list[ChatMessage] = []
        for item in value:
            if not isinstance(item, dict):
                continue
            role = str(item.get("role") or "user")
            content = item.get("content")
            if isinstance(content, str):
                messages.append(ChatMessage(role=role, content=content))
            elif isinstance(content, list):
                texts: list[str] = []
                for part in content:
                    if isinstance(part, dict) and part.get("type") in {"input_text", "output_text"} and part.get("text"):
                        texts.append(str(part["text"]))
                messages.append(ChatMessage(role=role, content="\n".join(texts)))
        if messages:
            return messages
    prompt = payload.get("prompt")
    if isinstance(prompt, dict) and prompt.get("id"):
        return [ChatMessage(role="user", content=f"Prompt template request: {prompt['id']}")]
    return [ChatMessage(role="user", content="")]


def responses_adapter_payload(normalized: dict[str, Any], content: str, live_call: bool, usage: dict[str, int]) -> dict[str, Any]:
    created = int(time.time())
    metadata = normalized.get("metadata") if isinstance(normalized.get("metadata"), dict) else {}
    local_call = local_llm_enabled() and not live_call
    return {
        "id": f"resp_{'local' if local_call else 'hf'}_{uuid4()}",
        "object": "response",
        "created_at": created,
        "status": "completed",
        "contract_version": LLM_RESPONSES_ADAPTER_CONTRACT_VERSION,
        "evidence_ref": LLM_RESPONSES_ADAPTER_EVIDENCE_REF,
        "trace_id": str(metadata.get("trace_id") or ""),
        "model": normalize_model_id(str(normalized.get("model") or HF_DEFAULT_CHAT_MODEL)),
        "output": [
            {
                "id": f"msg_hf_{uuid4()}",
                "type": "message",
                "status": "completed",
                "role": "assistant",
                "content": [{"type": "output_text", "text": content, "annotations": []}],
            }
        ],
        "output_text": content,
        "gateway_mode": GATEWAY_MODE,
        "provider_name": "huggingface_inference_router" if live_call else "local_llama_cpp" if local_call else "deterministic-dry-run",
        "live_provider_calls": live_call,
        "local_model_calls": local_call,
        "model_downloads": False,
        "usage": {
            "input_tokens": usage.get("prompt_tokens", 0),
            "output_tokens": usage.get("completion_tokens", 0),
            "total_tokens": usage.get("total_tokens", 0),
        },
    }


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
            "upstream_provider": "huggingface_inference_router",
            "upstream_chat_endpoint": "/v1/chat/completions",
            "dry_run_provider": "deterministic-dry-run",
            "stream_passthrough": False,
            "stateful_sessions_supported": True,
            "model_downloads": False,
            "openai_key_required": False,
        },
        "request_schema": {
            "model": "string model id or gateway default",
            "input": "string or Responses-style message array",
            "instructions": "optional string",
            "store": "boolean, default true",
            "previous_response_id": "optional response id for caller-managed continuity",
            "metadata.trace_id": "required for audited agent path",
            "metadata.agent_type": "planner|coder|tester|devops|unknown",
            "metadata.live_provider_calls_allowed": "must be explicitly true before live gateway attempt",
            "stream": "must be false; stream=true returns 501 on this adapter",
        },
        "response_schema": {
            "id": "resp_hf_*",
            "object": "response",
            "status": "completed",
            "contract_version": LLM_RESPONSES_ADAPTER_CONTRACT_VERSION,
            "evidence_ref": LLM_RESPONSES_ADAPTER_EVIDENCE_REF,
            "trace_id": "metadata.trace_id echo when supplied",
            "output": "Responses-style message array",
            "output_text": "flattened assistant text",
            "gateway_mode": GATEWAY_MODE,
            "provider_name": "deterministic-dry-run unless live gate and token allow HF router",
            "live_provider_calls": "false in default local and hosted gate-closed mode",
            "model_downloads": False,
            "audit_persisted": "true when Agent API audit sink is reachable",
            "usage": "input_tokens, output_tokens, total_tokens",
        },
        "negative_cases": [
            {"request": {"stream": True}, "expected_status": 501, "reason": "streaming is covered by /v1/chat/completions SSE contract"},
            {"request": {"metadata": "not-an-object"}, "expected_status": 422, "reason": "metadata must stay structured for trace/audit policy"},
        ],
        "policy_checks": [
            "Agent API calls POST /llm/v1/responses through the LLM Gateway only.",
            "The adapter never uses an OpenAI API key or direct provider URL.",
            "Live provider calls require both provider token availability and explicit metadata.live_provider_calls_allowed=true.",
            "Default local and gate-closed hosted proofs keep live_provider_calls=false and cost_cents=0.",
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
    router = hf_router_model_snapshot(limit=5)
    cloudflare_mode = cloudflare_workers_ai_mode_enabled()
    provider_available = cloudflare_workers_ai_available() if cloudflare_mode else hf_router_available()
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
            else "huggingface_inference_router"
        ),
        "routing_resolver": True,
        "routing_policy": True,
        "provider_health": True,
        "provider_live_verified": bool(router["live_verified"]),
        "provider_status": "configured" if cloudflare_mode and provider_available else router["status"],
        "provider_model_count_visible": len(CF_WORKERS_AI_MODELS) if cloudflare_mode else router["model_count_visible"],
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
        "responses_api": huggingface_router_capability_snapshot(),
        "non_claims": [
            "No model files are downloaded by this gateway.",
            "Generation calls require HF_TOKEN plus request policy/metadata approval.",
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
                "owned_by": "huggingface-router",
                "configured_route": model_id in route_models,
                "open_source_first": True,
                "live_verified": bool(router["live_verified"]),
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
    live_allowed = request_allows_live_provider(request.metadata)
    # Local llama.cpp is an optional, open-source, local-CPU provider. When it is enabled but
    # unavailable/unhealthy (still loading model, saturated, or down), degrade gracefully to the
    # deterministic dry-run path instead of hard-failing — a missing optional local provider must
    # not turn a Phase-2 orchestration run into a 500.
    # A caller (e.g. the Phase-2 LangGraph orchestrator) can demand the deterministic dry-run path
    # explicitly; it must not be routed through the slow local model or any live provider.
    deterministic_only = isinstance(request.metadata, dict) and request.metadata.get("deterministic_dry_run") is True
    local_live_call = local_llm_enabled() and local_llm_health() and not deterministic_only
    cloudflare_live_call = (
        cloudflare_workers_ai_mode_enabled()
        and live_allowed
        and cloudflare_workers_ai_available()
        and not deterministic_only
    )
    hf_live_call = (
        not cloudflare_workers_ai_mode_enabled()
        and live_allowed
        and hf_router_available()
        and not deterministic_only
    )
    live_call = cloudflare_live_call or hf_live_call
    completion_id = f"chatcmpl-{'local' if local_live_call else 'cf' if cloudflare_live_call else 'hf' if hf_live_call else 'dryrun'}-{uuid4()}"

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
        }

    if request.stream:
        def events():
            chunk = {
                "id": completion_id,
                "object": "chat.completion.chunk",
                "created": created,
                "model": response_payload.get("model") or normalize_model_id(request.model),
                "choices": [{"index": 0, "delta": {"content": content}, "finish_reason": None}],
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
                "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
            }
            yield f"data: {json.dumps(done, separators=(',', ':'))}\n\n"
            yield "data: [DONE]\n\n"

        return StreamingResponse(events(), media_type="text/event-stream")

    return response_payload


@app.post("/v1/responses")
def create_response(payload: dict[str, Any]) -> dict[str, Any]:
    normalized = normalize_responses_request(payload)
    chat_request = ChatCompletionRequest(
        model=str(normalized.get("model") or normalize_model_id(None)),
        messages=responses_input_to_messages(normalized),
        stream=False,
        temperature=normalized.get("temperature") if isinstance(normalized.get("temperature"), (int, float)) else None,
        max_tokens=normalized.get("max_output_tokens") if isinstance(normalized.get("max_output_tokens"), int) else None,
        metadata=normalized.get("metadata") if isinstance(normalized.get("metadata"), dict) else {},
    )
    live_allowed = request_allows_live_provider(chat_request.metadata)
    if local_llm_enabled() and local_llm_health():
        chat_payload = call_local_chat_completion(chat_request)
        content = extract_chat_content(chat_payload)
        usage = usage_from_chat_payload(chat_request, chat_payload, content)
        response_payload = responses_adapter_payload(normalized, content, False, usage)
    elif live_allowed and not hf_router_available():
        raise HTTPException(status_code=503, detail="HF_TOKEN is required for live Hugging Face router calls")
    elif live_allowed:
        chat_payload = call_hf_chat_completion(chat_request)
        content = extract_chat_content(chat_payload)
        usage = usage_from_chat_payload(chat_request, chat_payload, content)
        response_payload = responses_adapter_payload(normalized, content, True, usage)
    else:
        content = deterministic_content(chat_request)
        usage = chat_usage(chat_request, content)
        response_payload = responses_adapter_payload(normalized, content, False, usage)

    audit_persisted = audit_responses_event(normalized, response_payload)
    response_payload["audit_persisted"] = audit_persisted
    return response_payload
