from __future__ import annotations

import hashlib
import json
import os
import time
from typing import Any
from uuid import uuid4

import httpx
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

app = FastAPI(title="Cloud Superbrain LLM Gateway", version="0.1.0")

LIVE_PROVIDER_CALLS = False
GATEWAY_MODE = "deterministic_dry_run"
ROTATION_BACKOFF_SECONDS = [30, 60, 120, 300]
PROVIDER_RESET_AFTER_SECONDS = 900
STREAMING_PROTOCOL = "openai_compatible_sse"
ROUTING_POLICY_CONTRACT_VERSION = "llm-routing-policy-v1"
MAX_FALLBACKS_PER_REQUEST = 2
MAX_RETRY_CYCLES_PER_RUN = 5

MODEL_ROUTES = [
    {
        "agent_type": "planner",
        "primary": "claude-sonnet-4-6",
        "fallbacks": ["gpt-4o", "gpt-4o-mini"],
        "max_output_tokens": 4096,
        "supports_streaming": True,
        "configured_only": True,
    },
    {
        "agent_type": "coder",
        "primary": "deepseek-chat",
        "fallbacks": ["claude-haiku-4-5", "groq-llama-3.3-70b"],
        "max_output_tokens": 8192,
        "supports_streaming": True,
        "configured_only": True,
    },
    {
        "agent_type": "tester",
        "primary": "gpt-4o-mini",
        "fallbacks": ["groq-llama-3.3-70b", "deepseek-chat"],
        "max_output_tokens": 4096,
        "supports_streaming": True,
        "configured_only": True,
    },
    {
        "agent_type": "devops",
        "primary": "gpt-4o-mini",
        "fallbacks": ["claude-haiku-4-5", "gemini-flash"],
        "max_output_tokens": 4096,
        "supports_streaming": True,
        "configured_only": True,
    },
    {
        "agent_type": "research",
        "primary": "gemini-flash",
        "fallbacks": ["mistral-large", "gpt-4o-mini"],
        "max_output_tokens": 4096,
        "supports_streaming": True,
        "configured_only": True,
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
    return sorted(set(values))


def provider_for_model(model: str) -> str:
    if model.startswith("claude"):
        return "anthropic"
    if model.startswith("gpt"):
        return "openai"
    if model.startswith("deepseek"):
        return "deepseek"
    if model.startswith("groq"):
        return "groq"
    if model.startswith("gemini"):
        return "google"
    if model.startswith("mistral"):
        return "mistral"
    return "unknown"


def provider_status_snapshot() -> dict[str, object]:
    providers: dict[str, set[str]] = {}
    for model_id in model_ids():
        providers.setdefault(provider_for_model(model_id), set()).add(model_id)

    return {
        "mode": GATEWAY_MODE,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "live_verified": False,
        "policy": {
            "rotation_backoff_seconds": ROTATION_BACKOFF_SECONDS,
            "reset_after_seconds": PROVIDER_RESET_AFTER_SECONDS,
            "never_break_budget": True,
            "external_provider_calls_disabled": not LIVE_PROVIDER_CALLS,
        },
        "providers": [
            {
                "provider": provider,
                "status": "configured_only",
                "live_verified": False,
                "live_provider_calls": False,
                "models": sorted(models),
                "backoff_seconds": ROTATION_BACKOFF_SECONDS,
                "reset_after_seconds": PROVIDER_RESET_AFTER_SECONDS,
                "non_claim": "Provider is configured in routing policy; no external health check was made.",
            }
            for provider, models in sorted(providers.items())
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

    return {
        "mode": GATEWAY_MODE,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "agent_type": request.agent_type,
        "task_type": request.task_type,
        "selected_model": selected,
        "selected_provider": selected_provider,
        "reason": reason,
        "fallback_chain": candidates,
        "provider_chain": [provider_for_model(candidate) for candidate in candidates],
        "max_output_tokens": route["max_output_tokens"],
        "supports_streaming": route["supports_streaming"],
        "configured_only": True,
        "live_verified": False,
        "budget_level": request.budget_level,
        "provider_health": {
            "provider": selected_provider,
            "status": "configured_only",
            "live_verified": False,
            "live_provider_calls": False,
            "non_claim": "No external provider health check was made in deterministic dry-run mode.",
        },
        "policy": {
            "rotation_backoff_seconds": ROTATION_BACKOFF_SECONDS,
            "reset_after_seconds": PROVIDER_RESET_AFTER_SECONDS,
            "never_break_budget": True,
            "external_provider_calls_disabled": not LIVE_PROVIDER_CALLS,
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


def openai_usage(request: ChatCompletionRequest, content: str) -> dict[str, int]:
    prompt_tokens = count_text_tokens(request.messages)
    completion_tokens = len(content.split())
    return {
        "prompt_tokens": prompt_tokens,
        "completion_tokens": completion_tokens,
        "total_tokens": prompt_tokens + completion_tokens,
    }


def audit_event(request: ChatCompletionRequest, content: str, usage: dict[str, int]) -> bool:
    base_url = os.getenv("AGENT_API_INTERNAL_URL", "").rstrip("/")
    if not base_url:
        return False
    trace_id = str(request.metadata.get("trace_id") or f"llm-dry-run-{uuid4()}")
    payload = {
        "trace_id": trace_id,
        "model_name": request.model,
        "provider_name": "deterministic-dry-run",
        "agent_type": str(request.metadata.get("agent_type") or "unknown"),
        "status": "dry_run",
        "input_tokens": usage["prompt_tokens"],
        "output_tokens": usage["completion_tokens"],
        "cost_cents": 0,
        "live_provider_calls": False,
        "summary": content,
    }
    try:
        with httpx.Client(timeout=3) as client:
            response = client.post(f"{base_url}/internal/audit/llm-events", json=payload)
            response.raise_for_status()
        return True
    except Exception:
        return False


@app.get("/api/v1/health")
def health() -> dict[str, object]:
    return {
        "status": "healthy",
        "service": "llm-gateway",
        "mode": GATEWAY_MODE,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "openai_compatible": True,
        "routing_resolver": True,
        "routing_policy": True,
        "provider_health": True,
        "streaming_sse": True,
        "streaming_protocol": STREAMING_PROTOCOL,
        "models_configured": len(model_ids()),
        "non_claims": [
            "No external provider request is made in this local Phase-2 gateway.",
            "configured_only=true until provider secrets and live checks are explicitly configured.",
        ],
    }


@app.get("/v1/models")
def models() -> dict[str, object]:
    return {
        "object": "list",
        "data": [
            {
                "id": model_id,
                "object": "model",
                "owned_by": "configured-route",
                "configured_only": True,
                "live_verified": False,
            }
            for model_id in model_ids()
        ],
        "live_provider_calls": LIVE_PROVIDER_CALLS,
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
    content = deterministic_content(request)
    usage = openai_usage(request, content)
    audit_persisted = audit_event(request, content, usage)
    completion_id = f"chatcmpl-dryrun-{uuid4()}"

    if request.stream:
        def events():
            chunk = {
                "id": completion_id,
                "object": "chat.completion.chunk",
                "created": created,
                "model": request.model,
                "choices": [{"index": 0, "delta": {"content": content}, "finish_reason": None}],
                "live_provider_calls": LIVE_PROVIDER_CALLS,
                "audit_persisted": audit_persisted,
            }
            yield f"data: {json.dumps(chunk, separators=(',', ':'))}\n\n"
            done = {
                "id": completion_id,
                "object": "chat.completion.chunk",
                "created": created,
                "model": request.model,
                "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
            }
            yield f"data: {json.dumps(done, separators=(',', ':'))}\n\n"
            yield "data: [DONE]\n\n"

        return StreamingResponse(events(), media_type="text/event-stream")

    return {
        "id": completion_id,
        "object": "chat.completion",
        "created": created,
        "model": request.model,
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": content},
                "finish_reason": "stop",
            }
        ],
        "usage": usage,
        "live_provider_calls": LIVE_PROVIDER_CALLS,
        "audit_persisted": audit_persisted,
        "cost_cents": 0,
    }
