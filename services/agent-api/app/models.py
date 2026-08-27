from __future__ import annotations

from dataclasses import asdict, dataclass


MODEL_STUDIO_CODER_MODEL = "qwen3.7-plus"


@dataclass(frozen=True)
class ModelRoute:
    agent_type: str
    primary: str
    fallbacks: tuple[str, ...]
    max_output_tokens: int
    context_budget_policy: str
    memory_injection_budget_percent: int
    cost_tier: str
    supports_streaming: bool
    configured_only: bool = True


@dataclass(frozen=True)
class AgentProfile:
    agent_type: str
    role: str
    primary_model: str
    fallbacks: tuple[str, ...]
    max_output_tokens: int
    max_execution_seconds: int
    max_retries: int
    allowed_tools: tuple[str, ...]
    blocked_actions: tuple[str, ...]
    escalation_triggers: tuple[str, ...]
    human_review_required_actions: tuple[str, ...]
    graceful_degradation: str
    done_validation: tuple[str, ...] = (
        "implemented",
        "tested",
        "integrated",
        "reported",
        "logged",
    )


MODEL_ROUTES: tuple[ModelRoute, ...] = (
    ModelRoute(
        agent_type="planner",
        primary="deepseek-ai/DeepSeek-V4-Pro:fastest",
        fallbacks=("Qwen/Qwen3.6-35B-A3B:fastest", "moonshotai/Kimi-K2.6:fastest"),
        max_output_tokens=4096,
        context_budget_policy="memory_context_must_not_exceed_30_percent",
        memory_injection_budget_percent=30,
        cost_tier="standard",
        supports_streaming=True,
        configured_only=False,
    ),
    ModelRoute(
        agent_type="coder",
        primary=MODEL_STUDIO_CODER_MODEL,
        fallbacks=("deepseek-ai/DeepSeek-V4-Flash:fastest", "google/gemma-4-31B-it:fastest"),
        max_output_tokens=8192,
        context_budget_policy="memory_context_must_not_exceed_30_percent",
        memory_injection_budget_percent=30,
        cost_tier="standard",
        supports_streaming=True,
        configured_only=True,
    ),
    ModelRoute(
        agent_type="tester",
        primary="google/gemma-4-26B-A4B-it:cheapest",
        fallbacks=("Qwen/Qwen3.5-9B:cheapest", "meta-llama/Llama-3.1-8B-Instruct:cheapest"),
        max_output_tokens=4096,
        context_budget_policy="memory_context_must_not_exceed_30_percent",
        memory_injection_budget_percent=30,
        cost_tier="low",
        supports_streaming=True,
        configured_only=False,
    ),
    ModelRoute(
        agent_type="devops",
        primary="deepseek-ai/DeepSeek-V4-Flash:fastest",
        fallbacks=("Qwen/Qwen3.6-35B-A3B:fastest", "google/gemma-4-31B-it:fastest"),
        max_output_tokens=4096,
        context_budget_policy="memory_context_must_not_exceed_30_percent",
        memory_injection_budget_percent=30,
        cost_tier="low",
        supports_streaming=True,
        configured_only=False,
    ),
    ModelRoute(
        agent_type="research",
        primary="zai-org/GLM-5.1:fastest",
        fallbacks=("deepseek-ai/DeepSeek-V4-Pro:fastest", "inclusionAI/Ling-2.6-1T:fastest"),
        max_output_tokens=4096,
        context_budget_policy="memory_context_must_not_exceed_30_percent",
        memory_injection_budget_percent=30,
        cost_tier="low",
        supports_streaming=True,
        configured_only=False,
    ),
)

REQUIRED_BLOCKED_ACTIONS: tuple[str, ...] = (
    "force_push",
    "live_provider_call",
    "prod_deploy",
    "production_db_write",
    "push_main",
    "secret_change",
)

AGENT_PROFILES: tuple[AgentProfile, ...] = (
    AgentProfile(
        agent_type="planner",
        role="Task decomposition, intent classification, and safe route planning.",
        primary_model="deepseek-ai/DeepSeek-V4-Pro:fastest",
        fallbacks=("Qwen/Qwen3.6-35B-A3B:fastest", "moonshotai/Kimi-K2.6:fastest"),
        max_output_tokens=4096,
        max_execution_seconds=60,
        max_retries=5,
        allowed_tools=("memory_read", "task_router", "langgraph"),
        blocked_actions=REQUIRED_BLOCKED_ACTIONS,
        escalation_triggers=("architecture_decision_required", "budget_guard_rejected", "forbidden_intent_detected"),
        human_review_required_actions=("architecture_change", "budget_limit_change"),
        graceful_degradation="If planner routing is uncertain, stop with explicit uncertainty and request human review.",
    ),
    AgentProfile(
        agent_type="coder",
        role="Feature implementation on scoped branches with no direct main writes.",
        primary_model=MODEL_STUDIO_CODER_MODEL,
        fallbacks=("deepseek-ai/DeepSeek-V4-Flash:fastest", "google/gemma-4-31B-it:fastest"),
        max_output_tokens=8192,
        max_execution_seconds=300,
        max_retries=5,
        allowed_tools=("memory_read", "github_mcp", "filesystem_mcp", "mcp_gateway"),
        blocked_actions=REQUIRED_BLOCKED_ACTIONS,
        escalation_triggers=("write_scope_missing", "branch_policy_violation", "three_same_failures"),
        human_review_required_actions=("merge_main", "production_deploy", "schema_change"),
        graceful_degradation="If GitHub or filesystem scope is unavailable, return a patch plan and do not claim implementation.",
    ),
    AgentProfile(
        agent_type="tester",
        role="Verification, deterministic runtime checks, and E2B-gated sandbox proof when available.",
        primary_model="google/gemma-4-26B-A4B-it:cheapest",
        fallbacks=("Qwen/Qwen3.5-9B:cheapest", "meta-llama/Llama-3.1-8B-Instruct:cheapest"),
        max_output_tokens=4096,
        max_execution_seconds=600,
        max_retries=5,
        allowed_tools=("memory_read", "e2b_mcp", "playwright_mcp", "filesystem_mcp", "mcp_gateway"),
        blocked_actions=REQUIRED_BLOCKED_ACTIONS,
        escalation_triggers=("test_failed_after_retry", "e2b_unavailable_for_required_sandbox", "missing_runtime_evidence"),
        human_review_required_actions=("release_approval", "security_exception"),
        graceful_degradation="If E2B is unavailable, disable sandbox-only tests, emit user warning, and continue deterministic Docker/browser checks.",
    ),
    AgentProfile(
        agent_type="devops",
        role="CI/CD, Docker, deployment runbooks, and GitHub Actions dispatch without direct production SSH.",
        primary_model="deepseek-ai/DeepSeek-V4-Flash:fastest",
        fallbacks=("Qwen/Qwen3.6-35B-A3B:fastest", "google/gemma-4-31B-it:fastest"),
        max_output_tokens=4096,
        max_execution_seconds=120,
        max_retries=5,
        allowed_tools=("memory_read", "github_mcp", "mcp_gateway"),
        blocked_actions=REQUIRED_BLOCKED_ACTIONS,
        escalation_triggers=("production_deploy_requested", "missing_branch_protection_token", "rollback_not_tested"),
        human_review_required_actions=("workflow_dispatch_production", "rollback_production", "resource_limit_increase"),
        graceful_degradation="If GitHub Actions dispatch is unavailable, emit the exact workflow payload and keep deployment blocked.",
    ),
)

ROTATION_POLICY = {
    "principle": "never_blocked_always_rotating_without_budget_break",
    "backoff_seconds": [30, 60, 120, 300],
    "reset_after_seconds": 900,
    "budget_guard_required_before_rotation": True,
    "rotation_log_format": {
        "contract_version": "provider-fallback-event-v1",
        "event_kind": "provider_fallback",
        "timestamp": "ISO8601",
        "from_provider": "string",
        "to_provider": "string",
        "provider_chain": ["from_provider", "to_provider"],
        "from_model": "string",
        "to_model": "string",
        "fallback_index": "integer",
        "routing_policy_decision": "allow_fallback",
        "cost_metadata": {
            "input_tokens": "integer",
            "output_tokens": "integer",
            "estimated_cost_cents": "integer",
            "budget_level": "ok|warning|critical",
            "live_billing": False,
        },
        "reason": "rate_limited|provider_down|timeout|budget_guard",
        "agent": "planner|coder|tester|devops|research",
        "session_id": "uuid",
        "trace_id": "string",
        "live_provider_calls": False,
        "evidence_ref": "provider_fallback_structured_event",
    },
}


def model_capability_matrix() -> dict[str, object]:
    return {
        "memory_injection_budget_percent_max": 30,
        "routes": [asdict(route) for route in MODEL_ROUTES],
        "agent_profiles": [asdict(profile) for profile in AGENT_PROFILES],
        "provider_bindings": {
            MODEL_STUDIO_CODER_MODEL: {
                "provider": "alibaba_model_studio",
                "model_slot": "coder_primary",
                "gateway_only": True,
                "auth_env": "DASHSCOPE_API_KEY",
                "live_provider_calls": False,
                "secret_output": False,
            }
        },
        "note": "The qwen3.7-plus coder route uses Alibaba Model Studio through the LLM Gateway; every live generation remains credential-, mode-, budget-, policy-, and audit-gated.",
    }


def rotation_policy() -> dict[str, object]:
    return ROTATION_POLICY


def agent_profile_registry() -> dict[str, object]:
    return {
        "profile_contract_version": "agent-profiles-v1",
        "max_retry_global": 5,
        "done_validation_required": ["implemented", "tested", "integrated", "reported", "logged"],
        "profiles": [asdict(profile) for profile in AGENT_PROFILES],
        "non_claims": [
            "Profiles are deterministic runtime contracts; they do not imply live provider credentials are configured.",
            "The qwen3.7-plus coder profile never calls the Model Studio endpoint directly.",
            "Production deployment actions remain human-review gated.",
        ],
    }
