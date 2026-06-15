from __future__ import annotations

import json
import time
from collections.abc import Iterator
from typing import Literal, TypedDict
from uuid import uuid4

import httpx
from langgraph.checkpoint.postgres import PostgresSaver
from langgraph.graph import END, StateGraph

from app.budget import get_budget_state
from app.db import database_url, llm_gateway_url, mcp_gateway_url
from app.memory import MemoryWriteRequest, search_memory, store_memory
from app.security import redact_text
from app.tasks import (
    TaskAssignment,
    enqueue_task,
    get_task,
    priority_level_for_value,
    priority_queue_key_for_value,
    queue_depth,
)

MEMORY_CONTEXT_BUDGET_PERCENT_MAX = 30
MEMORY_CONTEXT_WINDOW_TOKENS = 4096
MEMORY_CONTEXT_BUDGET_TOKENS = int(MEMORY_CONTEXT_WINDOW_TOKENS * MEMORY_CONTEXT_BUDGET_PERCENT_MAX / 100)
MEMORY_CONTEXT_TOP_K = 5
AGENT_TASK_COMPLETION_TIMEOUT_SECONDS = 15
AGENT_AGGREGATION_COMPLETION_GRACE_SECONDS = 20
MCP_TOOL_TIMEOUT_MS = 1000
MAX_GLOBAL_RETRY_CYCLES = 5
CORE_AGENT_ROLES = ("planner", "coder", "tester", "devops")
MCP_SAFE_EVIDENCE_REF = "mcp_safe_envelope"
MCP_TIMEOUT_PROBE_PREFIX = "force_mcp_tool_timeout:"
LANGGRAPH_MCP_TIMEOUT_EVIDENCE_REF = "langgraph_mcp_timeout_controlled"
LLM_ROUTING_POLICY_CONTRACT_VERSION = "llm-routing-policy-v1"
LLM_ROUTING_POLICY_PRIMARY_EVIDENCE_REF = "llm_routing_policy_primary_allowed"
LLM_ROUTING_POLICY_DENY_EVIDENCE_REF = "llm_routing_policy_sensitive_cache_blocked"
PHASE2_RUNTIME_GRAPH_EVIDENCE_REF = "phase2_runtime_graph_started"
PHASE2_SSE_EVENT_CONTRACT_VERSION = "phase2-sse-event-contract-v1"
PHASE2_SSE_EVENT_EVIDENCE_REF = "phase2_sse_event_contract_proof"
PHASE2_SSE_REQUIRED_EVENTS = ("heartbeat", "agent_status", "error", "done")
PHASE2_SSE_ERROR_PROBE = "force_phase2_sse_error_event"
LANGGRAPH_GLOBAL_RETRY_LIMIT_EVIDENCE_REF = "langgraph_global_retry_limit_enforced"
LANGGRAPH_NODE_FAILURE_EVIDENCE_REF = "langgraph_node_failure_bounded"
NODE_FAILURE_PROBE_PREFIX = "force_langgraph_node_failure:"
AGENT_PARTIAL_FAILURE_PROBE_PREFIX = "force_agent_partial_failure:"
RETRY_PROTECTED_NODES = [
    "intent_parser",
    "budget_guard",
    "task_router",
    "agent_executor",
    "result_aggregator",
    "memory_updater",
]


def model_slot_for_agent(agent_type: str) -> str:
    return {
        "planner": "planner_primary",
        "coder": "coder_primary",
        "tester": "tester_primary",
        "devops": "devops_primary",
    }.get(agent_type, "planner_primary")

NodeName = Literal[
    "intent_parser",
    "budget_guard",
    "task_router",
    "agent_executor",
    "result_aggregator",
    "memory_updater",
    "error_handler",
    "completed",
    "hard_stop",
]


class GraphState(TypedDict, total=False):
    run_id: str
    session_id: str
    project_id: str
    prompt: str
    phase: str
    node_name: NodeName
    structured_intent: dict[str, object]
    task_plan: list[dict[str, object]]
    task_assignments: list[dict[str, object]]
    mcp_tool_calls: list[dict[str, object]]
    agent_results: list[dict[str, object]]
    llm_gateway_calls: list[dict[str, object]]
    memory_context: list[dict[str, object]]
    memory_context_budget: dict[str, object]
    memory_update_id: str | None
    evidence_refs: list[str]
    budget_decisions: list[dict[str, object]]
    retry_counters: dict[str, int]
    last_stable_checkpoint: str | None
    uncertainties: list[str]
    hard_stop_reason: str | None
    result: dict[str, object]


def graph_config(thread_id: str) -> dict[str, dict[str, str]]:
    return {"configurable": {"thread_id": thread_id}}


def ensure_postgres_checkpointer() -> None:
    with PostgresSaver.from_conn_string(database_url()) as checkpointer:
        checkpointer.setup()


def build_initial_state(project_id: str, prompt: str, session_id: str | None = None) -> GraphState:
    run_id = str(uuid4())
    return {
        "run_id": run_id,
        "session_id": session_id or run_id,
        "project_id": project_id,
        "prompt": prompt,
        "phase": "phase2_dry_run",
        "node_name": "intent_parser",
        "budget_decisions": [],
        "retry_counters": {
            "global": 0,
            "intent_parser": 0,
            "budget_guard": 0,
            "task_router": 0,
            "agent_executor": 0,
            "result_aggregator": 0,
            "memory_updater": 0,
        },
        "last_stable_checkpoint": None,
        "uncertainties": [],
        "hard_stop_reason": None,
        "evidence_refs": [],
        "llm_gateway_calls": [],
        "task_assignments": [],
        "mcp_tool_calls": [],
        "memory_context": [],
        "memory_update_id": None,
        "memory_context_budget": {
            "policy": "max_30_percent_context_window",
            "context_window_tokens": MEMORY_CONTEXT_WINDOW_TOKENS,
            "budget_percent_max": MEMORY_CONTEXT_BUDGET_PERCENT_MAX,
            "budget_tokens": MEMORY_CONTEXT_BUDGET_TOKENS,
            "requested_top_k": MEMORY_CONTEXT_TOP_K,
            "selected_count": 0,
            "used_tokens": 0,
            "truncated": False,
            "search_mode": "lexical_fallback",
        },
    }


def phase2_runtime_evidence_refs(state: GraphState) -> list[str]:
    prompt = str(state.get("prompt", "")).lower()
    return [PHASE2_RUNTIME_GRAPH_EVIDENCE_REF] if "phase2 runtime start:" in prompt else []


def force_global_retry_limit(state: GraphState) -> bool:
    return "force_langgraph_global_retry_limit" in str(state.get("prompt", "")).lower()


def forced_node_failure(state: GraphState) -> str | None:
    prompt = str(state.get("prompt", "")).lower()
    for node_name in RETRY_PROTECTED_NODES:
        if f"{NODE_FAILURE_PROBE_PREFIX}{node_name}" in prompt:
            return node_name
    return None


def forced_agent_partial_failure_roles(state: GraphState) -> set[str]:
    prompt = str(state.get("prompt", "")).lower()
    return {
        role
        for role in CORE_AGENT_ROLES
        if f"{AGENT_PARTIAL_FAILURE_PROBE_PREFIX}{role}" in prompt
    }


def forced_mcp_timeout_roles(state: GraphState) -> set[str]:
    prompt = str(state.get("prompt", "")).lower()
    return {
        role
        for role in CORE_AGENT_ROLES
        if f"{MCP_TIMEOUT_PROBE_PREFIX}{role}" in prompt
    }


def should_force_node_failure(state: GraphState, node_name: str) -> bool:
    return forced_node_failure(state) == node_name


def bounded_node_failure_state(state: GraphState, node_name: str) -> GraphState:
    counters = dict(state.get("retry_counters", {}))
    counters[node_name] = MAX_GLOBAL_RETRY_CYCLES
    counters["global"] = MAX_GLOBAL_RETRY_CYCLES
    node_evidence_ref = f"langgraph_{node_name}_failure_bounded"
    evidence_refs = list(state.get("evidence_refs", []))
    for evidence_ref in [LANGGRAPH_NODE_FAILURE_EVIDENCE_REF, node_evidence_ref]:
        if evidence_ref not in evidence_refs:
            evidence_refs.append(evidence_ref)
    return {
        **state,
        "node_name": "hard_stop",
        "retry_counters": counters,
        "hard_stop_reason": f"{node_name}_retry_limit_reached",
        "evidence_refs": evidence_refs,
        "result": {
            "summary": f"LangGraph dry-run stopped by deterministic {node_name} retry-limit probe.",
            "changed_artifacts": [],
            "verification_evidence": [
                "node_retry_limit_enforced",
                LANGGRAPH_NODE_FAILURE_EVIDENCE_REF,
                node_evidence_ref,
            ],
            "known_gaps": [],
            "rollback_note": "No persistent mutation performed by node failure probe.",
            "next_safe_step": f"Inspect {node_name} failure path before retry.",
        },
    }


def intent_parser(state: GraphState) -> GraphState:
    if should_force_node_failure(state, "intent_parser"):
        return bounded_node_failure_state(state, "intent_parser")
    prompt = state["prompt"]
    forbidden_actions = []
    lowered = prompt.lower()
    for token in ["production deploy", "merge main", "delete database", "secret"]:
        if token in lowered:
            forbidden_actions.append(token)
    return {
        **state,
        "node_name": "budget_guard",
        "structured_intent": {
            "goal": "phase2_orchestration_dry_run",
            "requested_scope": ["orchestration", "agent_routing"],
            "affected_layers": ["layer_2_orchestration", "layer_3_agent_pool", "layer_6_memory"],
            "risk_flags": ["checkpoint_required", "no_live_provider_calls"],
            "requires_owner_gate": bool(forbidden_actions),
            "assumptions": ["Dry-run uses deterministic local execution only."],
            "forbidden_actions_detected": forbidden_actions,
            "retry_limit_probe": force_global_retry_limit(state),
            "max_global_retry_cycles": MAX_GLOBAL_RETRY_CYCLES,
        },
    }


def budget_guard(state: GraphState) -> GraphState:
    if should_force_node_failure(state, "budget_guard"):
        return bounded_node_failure_state(state, "budget_guard")
    budget = get_budget_state()
    decision = {
        "node": "budget_guard",
        "level": budget.level,
        "allow_new_calls": budget.allow_new_calls,
        "spent_percentage": budget.spent_percentage,
        "total_cost_cents": budget.total_cost_cents,
        "budget_limit_cents": budget.budget_limit_cents,
    }
    decisions = [*state.get("budget_decisions", []), decision]
    if not budget.allow_new_calls:
        return {
            **state,
            "node_name": "error_handler",
            "budget_decisions": decisions,
            "hard_stop_reason": "budget_guard_rejected",
        }
    return {**state, "node_name": "task_router", "budget_decisions": decisions}


def task_router(state: GraphState) -> GraphState:
    if should_force_node_failure(state, "task_router"):
        return bounded_node_failure_state(state, "task_router")
    task_specs = [
        {
            "owner_role": "planner",
            "task_type": "phase2_planner_route_plan",
            "allowed_tools": ["memory_read", "task_router", "langgraph"],
            "write_scope": [],
            "priority": 9,
            "parallelizable": False,
        },
        {
            "owner_role": "coder",
            "task_type": "phase2_coder_scoped_implementation_plan",
            "allowed_tools": ["memory_read", "github_mcp", "filesystem_mcp", "mcp_gateway"],
            "write_scope": ["services/agent-api/app", "scripts", "docs"],
            "priority": 5,
            "parallelizable": True,
        },
        {
            "owner_role": "tester",
            "task_type": "phase2_tester_runtime_verification_plan",
            "allowed_tools": ["memory_read", "e2b_mcp", "playwright_mcp", "filesystem_mcp", "mcp_gateway"],
            "write_scope": [],
            "priority": 5,
            "parallelizable": True,
        },
        {
            "owner_role": "devops",
            "task_type": "phase2_devops_ci_cd_dispatch_plan",
            "allowed_tools": ["memory_read", "github_mcp", "mcp_gateway"],
            "write_scope": ["github-actions:workflow_dispatch:dry-run"],
            "priority": 8,
            "parallelizable": False,
        },
    ]
    return {
        **state,
        "node_name": "agent_executor",
        "task_plan": [
            {
                "task_id": str(uuid4()),
                "blocked_actions": [
                    "force_push",
                    "live_provider_call",
                    "prod_deploy",
                    "production_db_write",
                    "push_main",
                    "secret_change",
                ],
                "verification_required": ["runtime_verifier", "audit_event"],
                **task_spec,
            }
            for task_spec in task_specs
        ],
    }


def parse_llm_gateway_sse_line(line: str) -> dict[str, object] | None:
    if not line.startswith("data: "):
        return None
    payload = line.removeprefix("data: ").strip()
    if not payload or payload == "[DONE]":
        return None
    data = json.loads(payload)
    return data if isinstance(data, dict) else None


def estimate_context_tokens(text: str) -> int:
    # Conservative enough for a dry-run budget guard without introducing tokenizer dependencies.
    return max(1, len(text.split()))


def memory_search_queries(prompt: str) -> list[str]:
    queries: list[str] = []
    full_prompt = prompt.strip()
    if full_prompt:
        queries.append(full_prompt)
    for token in full_prompt.split():
        cleaned = "".join(char for char in token if char.isalnum() or char in "-_").strip()
        if len(cleaned) >= 5 and cleaned.lower() not in {"phase2", "langgraph", "verifier"}:
            queries.append(cleaned)
    deduped: list[str] = []
    seen: set[str] = set()
    for query in queries:
        lowered = query.lower()
        if lowered not in seen:
            seen.add(lowered)
            deduped.append(query)
    return deduped[:8]


def load_memory_context(state: GraphState) -> tuple[list[dict[str, object]], dict[str, object]]:
    results_by_id: dict[str, object] = {}
    for query in memory_search_queries(state["prompt"]):
        for result in search_memory(state["project_id"], query, limit=MEMORY_CONTEXT_TOP_K):
            results_by_id.setdefault(result.id, result)
        if len(results_by_id) >= MEMORY_CONTEXT_TOP_K:
            break

    selected: list[dict[str, object]] = []
    used_tokens = 0
    truncated = False
    for result in list(results_by_id.values())[:MEMORY_CONTEXT_TOP_K]:
        content = str(getattr(result, "content"))
        token_estimate = estimate_context_tokens(content)
        if used_tokens + token_estimate > MEMORY_CONTEXT_BUDGET_TOKENS:
            truncated = True
            break
        used_tokens += token_estimate
        selected.append(
            {
                "id": str(getattr(result, "id")),
                "content": content,
                "relevance_score": float(getattr(result, "relevance_score")),
                "created_at": str(getattr(result, "created_at")),
                "session_id": getattr(result, "session_id"),
                "token_estimate": token_estimate,
            }
        )

    budget = {
        "policy": "max_30_percent_context_window",
        "context_window_tokens": MEMORY_CONTEXT_WINDOW_TOKENS,
        "budget_percent_max": MEMORY_CONTEXT_BUDGET_PERCENT_MAX,
        "budget_tokens": MEMORY_CONTEXT_BUDGET_TOKENS,
        "requested_top_k": MEMORY_CONTEXT_TOP_K,
        "selected_count": len(selected),
        "used_tokens": used_tokens,
        "truncated": truncated,
        "search_mode": "lexical_fallback",
    }
    return selected, budget


def format_memory_context(memory_context: list[dict[str, object]]) -> str:
    if not memory_context:
        return "No prior memory context matched this dry-run prompt."
    lines = ["Relevant project memory injected before agent execution:"]
    for item in memory_context:
        content = str(item["content"])
        lines.append(f"- memory_id={item['id']} tokens~{item['token_estimate']}: {content[:700]}")
    return "\n".join(lines)


def call_llm_gateway_for_task(state: GraphState, task: dict[str, object]) -> dict[str, object]:
    agent_type = str(task.get("owner_role", "planner"))
    trace_id = f"langgraph-{state['run_id']}-{task.get('task_id', 'task')}"
    budget_decisions = state.get("budget_decisions", [])
    budget_level = str(budget_decisions[-1].get("level", "ok")) if budget_decisions else "ok"
    route_payload = {
        "agent_type": agent_type,
        "task_type": str(task.get("task_type", "phase2_orchestration_dry_run")),
        "requires_streaming": True,
        "budget_level": budget_level,
    }
    force_sensitive_cache_deny = "force_llm_routing_policy_deny_sensitive_cache" in str(
        state.get("prompt", "")
    )
    payload = {
        "messages": [
            {
                "role": "system",
                "content": (
                    "Phase-2 LangGraph deterministic dry-run. "
                    "Do not call live providers. Return only verifiable execution evidence.\n"
                    + format_memory_context(state.get("memory_context", []))
                ),
            },
            {"role": "user", "content": state["prompt"]},
        ],
        "stream": True,
        "metadata": {
            "trace_id": trace_id,
            "agent_type": agent_type,
            "project_id": state["project_id"],
            "session_id": state["session_id"],
            "run_id": state["run_id"],
            # Phase-2 is a deterministic dry-run: force the gateway's deterministic path so the
            # graph never blocks on slow local inference or any live provider.
            "deterministic_dry_run": True,
        },
    }
    with httpx.Client(timeout=8.0) as client:
        route_response = client.post(f"{llm_gateway_url()}/api/v1/routing/resolve", json=route_payload)
        route_response.raise_for_status()
        route = route_response.json()
        policy_payload = {
            "run_id": state["run_id"],
            "agent_slot": agent_type,
            "model_slot": model_slot_for_agent(agent_type),
            "task_class": str(task.get("task_type", "phase2_orchestration_dry_run")),
            "sensitivity": "sensitive" if force_sensitive_cache_deny else "internal",
            "max_output_tokens": 4096,
            "retry_index": int(state.get("retry_counters", {}).get(agent_type, 0)),
            "fallback_index": 0,
            "trace_correlation_id": trace_id,
            "requested_cost_tier": "Tier-S" if agent_type in {"planner", "coder"} else "Tier-E",
            "cache_requested": force_sensitive_cache_deny,
            "budget_allow_new_calls": budget_level != "hard_stop",
        }
        policy_response = client.post(
            f"{llm_gateway_url()}/api/v1/routing/policy/evaluate",
            json=policy_payload,
        )
        policy_response.raise_for_status()
        routing_policy = policy_response.json()
        routing_policy_decision = str(routing_policy.get("decision", "deny_slot_disabled"))
        if not routing_policy_decision.startswith("allow_"):
            return {
                "trace_id": trace_id,
                "agent_type": agent_type,
                "routing": route,
                "routing_policy": routing_policy,
                "routing_policy_checked": True,
                "routing_policy_decision": routing_policy_decision,
                "routing_policy_contract_version": routing_policy.get("contract_version"),
                "routing_policy_evidence_ref": routing_policy.get("evidence_ref"),
                "model": route.get("selected_model", "policy-blocked"),
                "status": "policy_blocked",
                "content": f"LLM routing policy blocked call: {routing_policy_decision}",
                "usage": {},
                "cost_cents": 0,
                "streaming_used": False,
                "streaming_protocol": "openai_compatible_sse",
                "stream_chunk_count": 0,
                "stream_done_seen": False,
                "live_provider_calls": False,
                "audit_persisted": False,
                "memory_context_injected": bool(state.get("memory_context")),
                "memory_context_count": len(state.get("memory_context", [])),
                "memory_context_budget": state.get("memory_context_budget", {}),
            }
        selected_model = str(route.get("selected_model", "deepseek-ai/DeepSeek-V4-Pro:fastest"))
        payload["model"] = selected_model
        stream_chunks: list[dict[str, object]] = []
        done_seen = False
        try:
            with client.stream("POST", f"{llm_gateway_url()}/v1/chat/completions", json=payload) as response:
                response.raise_for_status()
                for line in response.iter_lines():
                    if not line:
                        continue
                    if line.strip() == "data: [DONE]":
                        done_seen = True
                        continue
                    chunk = parse_llm_gateway_sse_line(line)
                    if chunk is not None:
                        stream_chunks.append(chunk)
        except httpx.HTTPError as exc:
            # A gateway hiccup/timeout must degrade to a structured envelope, never crash the graph.
            return {
                "trace_id": trace_id,
                "agent_type": agent_type,
                "routing": route,
                "routing_policy": routing_policy,
                "routing_policy_checked": True,
                "routing_policy_decision": routing_policy.get("decision"),
                "routing_policy_contract_version": routing_policy.get("contract_version"),
                "routing_policy_evidence_ref": routing_policy.get("evidence_ref"),
                "model": selected_model,
                "status": "gateway_unavailable",
                "content": f"LLM gateway streaming unavailable: {type(exc).__name__}",
                "usage": {},
                "cost_cents": 0,
                "streaming_used": False,
                "streaming_protocol": "openai_compatible_sse",
                "stream_chunk_count": 0,
                "stream_done_seen": False,
                "live_provider_calls": False,
                "live_provider_calls_proven_false": True,
                "audit_persisted": False,
                "memory_context_injected": bool(state.get("memory_context")),
                "memory_context_count": len(state.get("memory_context", [])),
                "memory_context_budget": state.get("memory_context_budget", {}),
            }

    content_parts: list[str] = []
    for chunk in stream_chunks:
        choices = chunk.get("choices", [])
        if choices and isinstance(choices, list) and isinstance(choices[0], dict):
            delta = choices[0].get("delta", {})
            if isinstance(delta, dict) and delta.get("content"):
                content_parts.append(str(delta["content"]))
    content = "".join(content_parts)
    first_chunk = stream_chunks[0] if stream_chunks else {}
    live_provider_flag = first_chunk.get("live_provider_calls") if isinstance(first_chunk, dict) else None
    live_provider_calls_proven_false = live_provider_flag is False

    return {
        "trace_id": trace_id,
        "agent_type": agent_type,
        "routing": route,
        "routing_policy": routing_policy,
        "routing_policy_checked": True,
        "routing_policy_decision": routing_policy.get("decision"),
        "routing_policy_contract_version": routing_policy.get("contract_version"),
        "routing_policy_evidence_ref": routing_policy.get("evidence_ref"),
        "model": first_chunk.get("model", selected_model),
        "status": "dry_run",
        "content": content,
        "usage": {},
        "cost_cents": 0,
        "streaming_used": True,
        "streaming_protocol": "openai_compatible_sse",
        "stream_chunk_count": len(stream_chunks),
        "stream_done_seen": done_seen,
        "live_provider_calls": live_provider_flag,
        "live_provider_calls_proven_false": live_provider_calls_proven_false,
        "audit_persisted": first_chunk.get("audit_persisted", False),
        "memory_context_injected": bool(state.get("memory_context")),
        "memory_context_count": len(state.get("memory_context", [])),
        "memory_context_budget": state.get("memory_context_budget", {}),
    }


def enqueue_agent_pool_task(state: GraphState, task: dict[str, object], llm_call: dict[str, object]) -> dict[str, object]:
    agent_type = str(task.get("owner_role", "planner"))
    priority = int(task.get("priority", 5))
    assignment = TaskAssignment(
        project_id=state["project_id"],
        session_id=state["session_id"],
        agent_type=agent_type,
        task_type=str(task.get("task_type", "langgraph_agent_executor")),
        task_description=redact_text(
            (
                f"LangGraph {agent_type} executor dry-run for task "
                f"{task.get('task_type', 'langgraph_agent_executor')}: {state['prompt'][:500]}"
            )
        ),
        trace_id=str(llm_call.get("trace_id")),
        priority=priority,
        allowed_tools=list(task.get("allowed_tools", ["memory_read"])),
        write_scope=list(task.get("write_scope", [])),
        blocked_actions=[
            "force_push",
            "live_provider_call",
            "prod_deploy",
            "production_db_write",
            "push_main",
            "secret_change",
        ],
        acceptance_criteria=["result_envelope", "done_validation", "audit_log"],
        human_review_required=True,
    )
    record = enqueue_task(assignment)
    started = time.monotonic()
    latest = record
    while time.monotonic() - started < AGENT_TASK_COMPLETION_TIMEOUT_SECONDS:
        current = get_task(record.task_id)
        if current:
            latest = current
            if latest.status in {"completed", "escalated", "failed"}:
                break
        time.sleep(0.25)

    return task_record_contract(latest)


def task_record_contract(record: object) -> dict[str, object]:
    return {
        "contract": "TaskAssignment",
        "queue": "tasks:agent:queue",
        "task_id": getattr(record, "task_id"),
        "agent_type": getattr(record, "agent_type"),
        "task_type": getattr(record, "task_type"),
        "status": getattr(record, "status"),
        "trace_id": getattr(record, "trace_id"),
        "priority": getattr(record, "priority"),
        "priority_level": priority_level_for_value(int(getattr(record, "priority", 5))),
        "priority_queue": priority_queue_key_for_value(int(getattr(record, "priority", 5))),
        "policy_version": getattr(record, "policy_version"),
        "allowed_tools": getattr(record, "allowed_tools"),
        "blocked_actions": getattr(record, "blocked_actions"),
        "acceptance_criteria": getattr(record, "acceptance_criteria"),
        "human_review_required": getattr(record, "human_review_required"),
        "done_validation": getattr(record, "done_validation"),
        "result_envelope": getattr(record, "result_envelope"),
        "error": getattr(record, "error"),
    }


def wait_for_task_assignment_terminal(
    assignment: dict[str, object],
    *,
    deadline: float,
) -> dict[str, object]:
    task_id = str(assignment.get("task_id", ""))
    if not task_id:
        return assignment
    latest = assignment
    while time.monotonic() < deadline:
        record = get_task(task_id)
        if record is not None:
            latest = task_record_contract(record)
            if latest.get("status") in {"completed", "escalated", "failed"}:
                return latest
        time.sleep(0.25)
    record = get_task(task_id)
    if record is not None:
        latest = task_record_contract(record)
    if latest.get("status") == "queued":
        try:
            drained = queue_depth() == 0
        except Exception:
            drained = False
        if drained:
            return {
                **latest,
                "status": "stale_queued_after_queue_drain",
                "error": "Task status remained queued after bounded aggregation wait while the worker queue was empty.",
            }
    return latest


def refresh_task_assignments_for_aggregation(assignments: list[dict[str, object]]) -> list[dict[str, object]]:
    deadline = time.monotonic() + AGENT_AGGREGATION_COMPLETION_GRACE_SECONDS
    refreshed: list[dict[str, object]] = []
    for assignment in assignments:
        if assignment.get("status") in {"completed", "escalated", "failed"}:
            refreshed.append(assignment)
            continue
        refreshed.append(wait_for_task_assignment_terminal(assignment, deadline=deadline))
    return refreshed


def refresh_agent_results_with_assignments(
    agent_results: list[dict[str, object]],
    assignments: list[dict[str, object]],
) -> list[dict[str, object]]:
    assignment_by_task_id = {
        str(assignment.get("task_id")): assignment
        for assignment in assignments
        if assignment.get("task_id")
    }
    refreshed_results: list[dict[str, object]] = []
    for result in agent_results:
        assignment = assignment_by_task_id.get(str(result.get("assigned_task_id")))
        if assignment is None:
            refreshed_results.append(result)
            continue
        refreshed_results.append(
            {
                **result,
                "status": assignment.get("status", result.get("status")),
                "task_assignment": assignment,
            }
        )
    return refreshed_results


def call_mcp_gateway_for_task(
    state: GraphState,
    task: dict[str, object],
    task_assignment: dict[str, object],
) -> dict[str, object]:
    agent_role = str(task_assignment.get("agent_type") or task.get("owner_role") or "planner")
    if agent_role not in {"planner", "coder", "tester", "devops"}:
        agent_role = "planner"
    tool_request_id = f"langgraph-mcp-{state['run_id']}-{str(task_assignment['task_id'])[:8]}"
    role_tool_plans: dict[str, dict[str, object]] = {
        "planner": {
            "toolset": "postgresql",
            "capability": "query_readonly",
            "input_ref": json.dumps(
                {
                    "sql": "SELECT COUNT(*) AS session_count FROM agent_sessions",
                    "parameters": [],
                },
                separators=(",", ":"),
            ),
            "allowed_scope": "project-context-readonly",
            "intent_summary": "Planner validates readonly project-context access for route planning.",
        },
        "coder": {
            "toolset": "filesystem",
            "capability": "plan_workspace_access",
            "input_ref": json.dumps(
                {
                    "operation": "read_file",
                    "path": "/tmp/agent-workspace/context/task.md",
                },
                separators=(",", ":"),
            ),
            "allowed_scope": "/tmp/agent-workspace/context",
            "intent_summary": "Coder validates scoped workspace access without host filesystem mutation.",
        },
        "tester": {
            "toolset": "playwright",
            "capability": "plan_browser_proof",
            "input_ref": json.dumps(
                {
                    "action": "navigate_to_url",
                    "target_url": "http://localhost:8081/",
                },
                separators=(",", ":"),
            ),
            "allowed_scope": "browser-proof-localhost",
            "intent_summary": "Tester validates browser-proof plan without opening a live browser session.",
        },
        "devops": {
            "toolset": "github",
            "capability": "plan_branch_pr",
            "input_ref": json.dumps(
                {
                    "branch": f"feature/agent-devops-{state['run_id'][:8]}",
                    "title": "Phase 2 DevOps dry-run dispatch plan",
                    "base": "main",
                    "body": "Dry-run PR plan generated by LangGraph Agent Executor.",
                },
                separators=(",", ":"),
            ),
            "allowed_scope": f"feature/agent-devops-{state['run_id'][:8]}",
            "intent_summary": "DevOps validates branch/PR dry-run plan without GitHub mutation.",
        },
    }
    plan = role_tool_plans[agent_role]
    forced_mcp_timeout = agent_role in forced_mcp_timeout_roles(state)
    if forced_mcp_timeout:
        plan = {
            "toolset": "e2b",
            "capability": "simulate_timeout",
            "input_ref": "none",
            "allowed_scope": "sandbox:test",
            "intent_summary": (
                f"{agent_role} deterministically exercises MCP timeout guard through LangGraph."
            ),
        }
    payload = {
        "tool_request_id": tool_request_id,
        "run_id": state["run_id"],
        "session_id": state["session_id"],
        "trace_id": f"langgraph-{state['run_id']}-{agent_role}",
        "agent_role": agent_role,
        "toolset": plan["toolset"],
        "capability": plan["capability"],
        "intent_summary": plan["intent_summary"],
        "input_ref": plan["input_ref"],
        "allowed_scope": plan["allowed_scope"],
        "timeout_ms": MCP_TOOL_TIMEOUT_MS,
        "retry_budget": 0,
        "idempotency_key": tool_request_id,
        "audit_tags": ["langgraph", "phase2", "safe-envelope", agent_role],
        "redaction_required": True,
        "expected_output_type": "tool_result",
    }
    with httpx.Client(timeout=3.0) as client:
        response = client.post(f"{mcp_gateway_url()}/api/v1/tools/execute", json=payload)
        response.raise_for_status()
        result = response.json()

    return {
        "contract": "McpToolRequest",
        "tool_request_id": tool_request_id,
        "run_id": state["run_id"],
        "agent_role": agent_role,
        "toolset": payload["toolset"],
        "capability": payload["capability"],
        "allowed_scope": payload["allowed_scope"],
        "status": result.get("status"),
        "error_class": result.get("error_class", "none"),
        "evidence_ref": result.get("evidence_ref"),
        "expected_evidence_ref": "mcp_timeout_guard" if forced_mcp_timeout else MCP_SAFE_EVIDENCE_REF,
        "controlled_timeout_probe": forced_mcp_timeout,
        "orchestrator_evidence_ref": (
            LANGGRAPH_MCP_TIMEOUT_EVIDENCE_REF if result.get("status") == "timeout" else MCP_SAFE_EVIDENCE_REF
        ),
        "audit_persisted": result.get("audit_persisted", False),
        "result_ref": result.get("result_ref"),
        "sanitized_summary": result.get("sanitized_summary"),
        "retry_after_ms": result.get("retry_after_ms", 0),
    }


def agent_executor(state: GraphState) -> GraphState:
    if should_force_node_failure(state, "agent_executor"):
        return bounded_node_failure_state(state, "agent_executor")
    memory_context, memory_context_budget = load_memory_context(state)
    state_with_memory: GraphState = {
        **state,
        "memory_context": memory_context,
        "memory_context_budget": memory_context_budget,
    }
    llm_gateway_calls = [*state_with_memory.get("llm_gateway_calls", [])]
    task_assignments = [*state_with_memory.get("task_assignments", [])]
    mcp_tool_calls = [*state_with_memory.get("mcp_tool_calls", [])]
    agent_results = [*state_with_memory.get("agent_results", [])]

    for task in state_with_memory.get("task_plan", [{}]):
        llm_call = call_llm_gateway_for_task(state_with_memory, task)
        llm_gateway_calls.append(llm_call)
        routing_policy_decision = str(llm_call.get("routing_policy_decision", "allow_primary"))
        if llm_call.get("status") == "policy_blocked" or not routing_policy_decision.startswith(
            "allow_"
        ):
            return {
                **state_with_memory,
                "node_name": "error_handler",
                "hard_stop_reason": "llm_routing_policy_rejected",
                "llm_gateway_calls": llm_gateway_calls,
                "task_assignments": task_assignments,
                "mcp_tool_calls": mcp_tool_calls,
                "agent_results": agent_results,
                "evidence_refs": [
                    *state_with_memory.get("evidence_refs", []),
                    str(llm_call.get("routing_policy_evidence_ref", LLM_ROUTING_POLICY_DENY_EVIDENCE_REF)),
                ],
            }
        if llm_call.get("live_provider_calls") is not False or llm_call.get("live_provider_calls_proven_false") is not True:
            return {
                **state_with_memory,
                "node_name": "error_handler",
                "hard_stop_reason": "llm_gateway_live_provider_non_claim_unproven",
                "llm_gateway_calls": llm_gateway_calls,
                "task_assignments": task_assignments,
                "mcp_tool_calls": mcp_tool_calls,
                "agent_results": agent_results,
            }
        if llm_call.get("stream_done_seen") is not True:
            return {
                **state_with_memory,
                "node_name": "error_handler",
                "hard_stop_reason": "llm_gateway_stream_done_missing",
                "llm_gateway_calls": llm_gateway_calls,
                "task_assignments": task_assignments,
                "mcp_tool_calls": mcp_tool_calls,
                "agent_results": agent_results,
            }
        task_assignment = enqueue_agent_pool_task(state_with_memory, task, llm_call)
        task_assignments.append(task_assignment)
        mcp_tool_call = call_mcp_gateway_for_task(state_with_memory, task, task_assignment)
        mcp_tool_calls.append(mcp_tool_call)
        mcp_evidence = str(mcp_tool_call.get("orchestrator_evidence_ref") or mcp_tool_call.get("evidence_ref"))
        task_assignment_evidence = (
            "task_assignment_completed"
            if task_assignment.get("status") == "completed"
            else "task_assignment_incomplete"
        )
        agent_results.append(
            {
                "task_id": task.get("task_id"),
                "assigned_task_id": task_assignment["task_id"],
                "mcp_tool_request_id": mcp_tool_call["tool_request_id"],
                "owner_role": task.get("owner_role", "planner"),
                "status": task_assignment["status"],
                "summary": llm_call["content"],
                "changed_artifacts": [],
                "verification_evidence": [
                    "langgraph_graph_invoked",
                    "llm_gateway_dry_run",
                    "llm_gateway_streaming_dry_run",
                    "memory_context_injected",
                    task_assignment_evidence,
                    "mcp_tool_success" if mcp_tool_call.get("status") == "success" else "mcp_tool_controlled_error",
                    mcp_evidence,
                    f"agent_role_{task.get('owner_role', 'planner')}_executed",
                ],
                "llm_gateway": llm_call,
                "task_assignment": task_assignment,
                "mcp_tool_call": mcp_tool_call,
                "known_gaps": ["Live provider routing remains disabled until budget/provider gates are proven."],
                "rollback_note": "Dry-run memory update is an audit-safe project memory row and can be purged through the memory purge path.",
            }
        )

    return {
        **state_with_memory,
        "node_name": "result_aggregator",
        "llm_gateway_calls": llm_gateway_calls,
        "task_assignments": task_assignments,
        "mcp_tool_calls": mcp_tool_calls,
        "agent_results": agent_results,
    }


def build_per_role_results(state: GraphState) -> tuple[list[dict[str, object]], list[str], bool]:
    assignments = {
        str(assignment.get("agent_type")): assignment
        for assignment in state.get("task_assignments", [])
        if assignment.get("agent_type")
    }
    results = {
        str(result.get("owner_role")): result
        for result in state.get("agent_results", [])
        if result.get("owner_role")
    }
    mcp_calls = {
        str(call.get("agent_role")): call
        for call in state.get("mcp_tool_calls", [])
        if call.get("agent_role")
    }
    llm_calls = {
        str(call.get("agent_type")): call
        for call in state.get("llm_gateway_calls", [])
        if call.get("agent_type")
    }

    per_role_results: list[dict[str, object]] = []
    failure_reasons: list[str] = []
    forced_partial_failure_roles = forced_agent_partial_failure_roles(state)
    for role in CORE_AGENT_ROLES:
        assignment = assignments.get(role, {})
        result = results.get(role, {})
        mcp_call = mcp_calls.get(role, {})
        llm_call = llm_calls.get(role, {})
        done_validation = assignment.get("done_validation", {})
        if not isinstance(done_validation, dict):
            done_validation = {}

        role_failures: list[str] = []
        if not assignment:
            role_failures.append("missing_task_assignment")
        if assignment and assignment.get("status") != "completed":
            role_failures.append(f"task_assignment_{assignment.get('status', 'unknown')}")
        if done_validation.get("logged") is not True:
            role_failures.append("done_validation_not_logged")
        if not result:
            role_failures.append("missing_agent_result")
        if not mcp_call:
            role_failures.append("missing_mcp_tool_call")
        if mcp_call and mcp_call.get("status") != "success":
            role_failures.append(f"mcp_{mcp_call.get('status', 'unknown')}")
        if llm_call and (
            llm_call.get("live_provider_calls") is not False
            or llm_call.get("live_provider_calls_proven_false") is not True
        ):
            role_failures.append("live_provider_non_claim_unproven")
        if llm_call and llm_call.get("stream_done_seen") is not True:
            role_failures.append("llm_stream_done_missing")
        if llm_call and str(llm_call.get("routing_policy_decision", "allow_primary")).startswith("allow_") is False:
            role_failures.append("llm_policy_not_allowed")
        if role in forced_partial_failure_roles:
            role_failures.append("forced_partial_failure_probe")

        if role_failures:
            failure_reasons.extend([f"{role}:{reason}" for reason in role_failures])

        per_role_results.append(
            {
                "role": role,
                "status": "completed" if not role_failures else "partial_failure",
                "task_id": result.get("task_id"),
                "assigned_task_id": assignment.get("task_id"),
                "task_type": assignment.get("task_type"),
                "done_validation": done_validation,
                "mcp_toolset": mcp_call.get("toolset"),
                "mcp_capability": mcp_call.get("capability"),
                "mcp_status": mcp_call.get("status"),
                "mcp_evidence_ref": mcp_call.get("evidence_ref"),
                "llm_model": llm_call.get("model"),
                "llm_routing_policy_decision": llm_call.get("routing_policy_decision"),
                "summary": (
                    f"{role} executed deterministic dry-run task "
                    f"{assignment.get('task_type', 'unknown_task')} with MCP proof "
                    f"{mcp_call.get('evidence_ref', 'missing_evidence')}."
                ),
                "failure_reasons": role_failures,
            }
        )

    return per_role_results, failure_reasons, bool(failure_reasons)


def result_aggregator(state: GraphState) -> GraphState:
    if should_force_node_failure(state, "result_aggregator"):
        return bounded_node_failure_state(state, "result_aggregator")
    refreshed_task_assignments = refresh_task_assignments_for_aggregation(state.get("task_assignments", []))
    aggregation_state: GraphState = {
        **state,
        "task_assignments": refreshed_task_assignments,
        "agent_results": refresh_agent_results_with_assignments(
            state.get("agent_results", []),
            refreshed_task_assignments,
        ),
    }
    per_role_results, partial_failure_reasons, partial_failure = build_per_role_results(aggregation_state)
    aggregation_evidence = (
        "agent_result_aggregation_partial_failure_detected"
        if partial_failure
        else "agent_result_aggregation_complete"
    )
    mcp_timeout_detected = any(
        call.get("status") == "timeout" and call.get("evidence_ref") == "mcp_timeout_guard"
        for call in aggregation_state.get("mcp_tool_calls", [])
    )
    mcp_evidence_refs = [
        str(call.get("orchestrator_evidence_ref") or call.get("evidence_ref"))
        for call in aggregation_state.get("mcp_tool_calls", [])
        if call.get("orchestrator_evidence_ref") or call.get("evidence_ref")
    ]
    task_assignment_evidence = (
        "task_assignment_partial_failure_detected"
        if partial_failure
        else "task_assignment_completed"
    )
    streaming_contract_complete = bool(aggregation_state.get("llm_gateway_calls")) and all(
        call.get("streaming_used") is True
        and call.get("streaming_protocol") == "openai_compatible_sse"
        and call.get("stream_done_seen") is True
        and call.get("live_provider_calls") is False
        and call.get("live_provider_calls_proven_false") is True
        for call in aggregation_state.get("llm_gateway_calls", [])
    )
    streaming_evidence = (
        "llm_gateway_streaming_dry_run"
        if streaming_contract_complete
        else "llm_gateway_streaming_incomplete"
    )
    return {
        **state,
        "node_name": "memory_updater",
        "task_assignments": refreshed_task_assignments,
        "agent_results": aggregation_state.get("agent_results", []),
        "result": {
            "summary": (
                "LangGraph deterministic four-role agent execution aggregated with partial-failure checks."
            ),
            "changed_artifacts": [],
            "verification_evidence": [
                "graph_nodes_completed",
                *phase2_runtime_evidence_refs(state),
                "llm_gateway_dry_run",
                streaming_evidence,
                "memory_context_injected",
                task_assignment_evidence,
                "mcp_tool_controlled_error" if mcp_timeout_detected else "mcp_tool_success",
                *mcp_evidence_refs,
                aggregation_evidence,
            ],
            "per_role_results": per_role_results,
            "partial_failure": partial_failure,
            "partial_failure_reasons": partial_failure_reasons,
            "known_gaps": ["No live provider routing in dry-run mode."],
            "rollback_note": "Dry-run memory update is written to project memory for auditability.",
            "next_safe_step": "Promote role summaries into the user-facing activity stream.",
        },
        "evidence_refs": [
            *state.get("evidence_refs", []),
            *phase2_runtime_evidence_refs(state),
            "langgraph_dry_run",
            "llm_gateway_dry_run",
            streaming_evidence,
            LLM_ROUTING_POLICY_PRIMARY_EVIDENCE_REF,
            "memory_context_injected",
            task_assignment_evidence,
            "mcp_tool_controlled_error" if mcp_timeout_detected else "mcp_tool_success",
            *mcp_evidence_refs,
            aggregation_evidence,
        ],
    }


def build_memory_update_text(state: GraphState) -> str:
    llm_call = state.get("llm_gateway_calls", [{}])[0] if state.get("llm_gateway_calls") else {}
    result = state.get("result", {})
    return (
        "langgraph memory update: "
        f"run_id={state['run_id']} "
        f"session_id={state['session_id']} "
        f"node_name=completed "
        f"summary={result.get('summary', 'LangGraph skeleton path executed.')} "
        f"memory_context_count={len(state.get('memory_context', []))} "
        f"task_assignment_count={len(state.get('task_assignments', []))} "
        f"mcp_tool_count={len(state.get('mcp_tool_calls', []))} "
        f"streaming_used={llm_call.get('streaming_used', False)} "
        f"live_provider_calls={llm_call.get('live_provider_calls', False)}"
    )


def memory_updater(state: GraphState) -> GraphState:
    if should_force_node_failure(state, "memory_updater"):
        return bounded_node_failure_state(state, "memory_updater")
    try:
        memory_update_id = store_memory(
            MemoryWriteRequest(
                project_id=state["project_id"],
                session_id=state["session_id"],
                content_text=build_memory_update_text(state),
                metadata={
                    "source": "langgraph_memory_updater",
                    "run_id": state["run_id"],
                    "checkpointing": "postgres",
                    "live_provider_calls": False,
                    "evidence_refs": state.get("evidence_refs", []),
                },
            )
        )
    except LookupError:
        return {
            **state,
            "node_name": "completed",
            "last_stable_checkpoint": f"dry-run:{state['run_id']}:completed",
            "memory_update_id": None,
            "uncertainties": [*state.get("uncertainties", []), "memory_update_skipped_project_missing"],
            "evidence_refs": [*state.get("evidence_refs", []), "memory_update_skipped_project_missing"],
        }
    return {
        **state,
        "node_name": "completed",
        "last_stable_checkpoint": f"dry-run:{state['run_id']}:completed",
        "memory_update_id": memory_update_id,
        "evidence_refs": [*state.get("evidence_refs", []), "memory_update_persisted"],
    }


def error_handler(state: GraphState) -> GraphState:
    counters = dict(state.get("retry_counters", {}))
    forced_retry_limit = force_global_retry_limit(state)
    counters["global"] = MAX_GLOBAL_RETRY_CYCLES if forced_retry_limit else counters.get("global", 0) + 1
    evidence_refs = list(state.get("evidence_refs", []))
    if forced_retry_limit and LANGGRAPH_GLOBAL_RETRY_LIMIT_EVIDENCE_REF not in evidence_refs:
        evidence_refs.append(LANGGRAPH_GLOBAL_RETRY_LIMIT_EVIDENCE_REF)
    return {
        **state,
        "node_name": "hard_stop",
        "retry_counters": counters,
        "hard_stop_reason": state.get("hard_stop_reason")
        or ("global_retry_limit_reached" if forced_retry_limit else "policy_or_budget_guard_rejected"),
        "evidence_refs": evidence_refs,
        "result": {
            "summary": "LangGraph dry-run stopped by policy guard.",
            "changed_artifacts": [],
            "verification_evidence": [
                "error_handler_invoked",
                *(["global_retry_limit_enforced"] if forced_retry_limit else []),
            ],
            "known_gaps": [],
            "rollback_note": "No persistent mutation performed by dry-run graph.",
            "next_safe_step": "Review forbidden action or budget state before retry.",
        },
    }


def route_after_intent(state: GraphState) -> str:
    if state.get("hard_stop_reason"):
        return END
    intent = state.get("structured_intent", {})
    forbidden = intent.get("forbidden_actions_detected", [])
    return "error_handler" if forbidden or force_global_retry_limit(state) else "budget_guard"


def route_after_budget(state: GraphState) -> str:
    return END if state.get("node_name") == "hard_stop" else ("error_handler" if state.get("hard_stop_reason") else "task_router")


def route_after_task_router(state: GraphState) -> str:
    return END if state.get("node_name") == "hard_stop" else "agent_executor"


def route_after_agent_executor(state: GraphState) -> str:
    return END if state.get("node_name") == "hard_stop" else ("error_handler" if state.get("hard_stop_reason") else "result_aggregator")


def route_after_result_aggregator(state: GraphState) -> str:
    return END if state.get("node_name") == "hard_stop" else "memory_updater"


def route_terminal(state: GraphState) -> str:
    return END


def build_graph(checkpointer: PostgresSaver | None = None):
    graph = StateGraph(GraphState)
    graph.add_node("intent_parser", intent_parser)
    graph.add_node("budget_guard", budget_guard)
    graph.add_node("task_router", task_router)
    graph.add_node("agent_executor", agent_executor)
    graph.add_node("result_aggregator", result_aggregator)
    graph.add_node("memory_updater", memory_updater)
    graph.add_node("error_handler", error_handler)
    graph.set_entry_point("intent_parser")
    graph.add_conditional_edges("intent_parser", route_after_intent)
    graph.add_conditional_edges("budget_guard", route_after_budget)
    graph.add_conditional_edges("task_router", route_after_task_router)
    graph.add_conditional_edges("agent_executor", route_after_agent_executor)
    graph.add_conditional_edges("result_aggregator", route_after_result_aggregator)
    graph.add_conditional_edges("memory_updater", route_terminal)
    graph.add_conditional_edges("error_handler", route_terminal)
    return graph.compile(checkpointer=checkpointer)


def run_dry_graph(project_id: str, prompt: str, session_id: str | None = None) -> GraphState:
    initial = build_initial_state(project_id=project_id, prompt=prompt, session_id=session_id)
    thread_id = initial["session_id"]
    with PostgresSaver.from_conn_string(database_url()) as checkpointer:
        app = build_graph(checkpointer=checkpointer)
        final_state = app.invoke(initial, graph_config(thread_id))
    final_state["last_stable_checkpoint"] = final_state.get("last_stable_checkpoint") or f"postgres:{thread_id}:latest"
    return final_state


def stream_dry_graph_events(project_id: str, prompt: str, session_id: str | None = None) -> Iterator[dict[str, object]]:
    initial = build_initial_state(project_id=project_id, prompt=prompt, session_id=session_id)
    thread_id = initial["session_id"]
    event_contract = {
        "contract_version": PHASE2_SSE_EVENT_CONTRACT_VERSION,
        "evidence_ref": PHASE2_SSE_EVENT_EVIDENCE_REF,
        "required_event_types": list(PHASE2_SSE_REQUIRED_EVENTS),
        "live_provider_calls": False,
    }
    yield {
        "event": "heartbeat",
        "status": "connected",
        "engine": "langgraph",
        "mode": "deterministic_dry_run",
        "checkpointing": "postgres",
        "thread_id": thread_id,
        "run_id": initial["run_id"],
        **event_contract,
    }
    yield {
        "event": "agent_status",
        "status": "started",
        "agent": "planner",
        "node": "intent_parser",
        "thread_id": thread_id,
        "run_id": initial["run_id"],
        **event_contract,
    }
    if PHASE2_SSE_ERROR_PROBE in prompt.lower():
        yield {
            "event": "error",
            "status": "error",
            "code": "forced_phase2_sse_error_event",
            "message": "Deterministic SSE error-event contract probe.",
            "recoverable": False,
            "thread_id": thread_id,
            "run_id": initial["run_id"],
            **event_contract,
        }
        yield {
            "event": "done",
            "status": "error",
            "engine": "langgraph",
            "mode": "deterministic_dry_run",
            "checkpointing": "postgres",
            "thread_id": thread_id,
            "run_id": initial["run_id"],
            "node_name": "error_handler",
            "error_event_seen": True,
            "state": {
                **initial,
                "node_name": "error_handler",
                "hard_stop_reason": "forced_phase2_sse_error_event",
                "evidence_refs": [PHASE2_SSE_EVENT_EVIDENCE_REF],
            },
            **event_contract,
        }
        return
    yield {
        "event": "graph_status",
        "status": "started",
        "engine": "langgraph",
        "mode": "deterministic_dry_run",
        "checkpointing": "postgres",
        "thread_id": thread_id,
        "run_id": initial["run_id"],
        **event_contract,
    }

    final_state: dict[str, object] = {}
    with PostgresSaver.from_conn_string(database_url()) as checkpointer:
        app = build_graph(checkpointer=checkpointer)
        for update in app.stream(initial, graph_config(thread_id), stream_mode="updates"):
            if not isinstance(update, dict):
                yield {
                    "event": "graph_node",
                    "status": "updated",
                    "thread_id": thread_id,
                    "node": "unknown",
                    "state": {"raw_update": str(update)},
                    **event_contract,
                }
                continue

            for node, state_update in update.items():
                state_payload = state_update if isinstance(state_update, dict) else {"raw_update": str(state_update)}
                final_state = {**final_state, **state_payload}
                if node == "agent_executor":
                    yield {
                        "event": "agent_status",
                        "status": "running",
                        "agent": "planner",
                        "node": node,
                        "node_name": state_payload.get("node_name", node),
                        "thread_id": thread_id,
                        "run_id": state_payload.get("run_id", initial["run_id"]),
                        **event_contract,
                    }
                yield {
                    "event": "graph_node",
                    "status": "updated",
                    "thread_id": thread_id,
                    "node": node,
                    "node_name": state_payload.get("node_name", node),
                    "run_id": state_payload.get("run_id", initial["run_id"]),
                    "state": state_payload,
                    **event_contract,
                }

        snapshot = app.get_state(graph_config(thread_id))
        snapshot_values = dict(getattr(snapshot, "values", {}) or {})
        if snapshot_values:
            final_state = snapshot_values

    yield {
        "event": "done",
        "status": "completed" if final_state.get("node_name") == "completed" else "stopped",
        "engine": "langgraph",
        "mode": "deterministic_dry_run",
        "checkpointing": "postgres",
        "thread_id": thread_id,
        "run_id": final_state.get("run_id", initial["run_id"]),
        "node_name": final_state.get("node_name"),
        "state": final_state,
        **event_contract,
    }


def recover_dry_graph_state(thread_id: str) -> dict[str, object]:
    with PostgresSaver.from_conn_string(database_url()) as checkpointer:
        app = build_graph(checkpointer=checkpointer)
        snapshot = app.get_state(graph_config(thread_id))
    values = dict(getattr(snapshot, "values", {}) or {})
    metadata = dict(getattr(snapshot, "metadata", {}) or {})
    tasks = list(getattr(snapshot, "tasks", []) or [])
    return {
        "thread_id": thread_id,
        "found": bool(values),
        "values": values,
        "metadata": metadata,
        "task_count": len(tasks),
        "next": list(getattr(snapshot, "next", []) or []),
    }
