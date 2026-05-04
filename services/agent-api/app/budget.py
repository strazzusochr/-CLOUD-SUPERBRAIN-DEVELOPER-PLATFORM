from __future__ import annotations

import os
import time
from dataclasses import dataclass

import psycopg
import redis

from app.clouds import hetzner_live_budget_items
from app.db import database_url, redis_url


@dataclass(frozen=True)
class BudgetState:
    total_cost_cents: int
    budget_limit_cents: int
    spent_percentage: float
    level: str
    allow_new_calls: bool


@dataclass(frozen=True)
class InfraBudgetState:
    projected_cost_cents: int
    budget_limit_cents: int
    warning_limit_cents: int
    spent_percentage: float
    level: str
    allow_new_infra: bool
    live_verified: bool
    source: str
    items: list[dict[str, object]]


def llm_budget_limit_cents() -> int:
    return int(os.getenv("LLM_BUDGET_LIMIT_CENTS", "20000"))


def infra_budget_limit_cents() -> int:
    return int(os.getenv("INFRA_BUDGET_LIMIT_CENTS", "2000"))


def infra_budget_warning_cents() -> int:
    return int(os.getenv("INFRA_BUDGET_WARNING_CENTS", "1600"))


def planned_infra_items() -> list[dict[str, object]]:
    raw = os.getenv("INFRA_PLANNED_ITEMS")
    if raw:
        items: list[dict[str, object]] = []
        for chunk in raw.split(","):
            name, _, cents = chunk.partition(":")
            if name and cents.isdigit():
                items.append({"name": name.strip(), "monthly_cost_cents": int(cents), "source": "env"})
        if items:
            return items
    return [
        {"name": "hetzner-production-cx21", "monthly_cost_cents": 500, "source": "patched-phase1-plan"},
        {"name": "hetzner-minimal-staging-cx11", "monthly_cost_cents": 400, "source": "patched-phase1-plan"},
        {"name": "cloudflare-free-tier", "monthly_cost_cents": 0, "source": "patched-phase1-plan"},
        {"name": "ghcr-free-tier", "monthly_cost_cents": 0, "source": "patched-phase1-plan"},
    ]


def get_infra_budget_state() -> InfraBudgetState:
    limit = infra_budget_limit_cents()
    warning = infra_budget_warning_cents()
    live_items = hetzner_live_budget_items()
    if live_items is not None:
        planned_zero_cost_items = [
            item for item in planned_infra_items() if int(item.get("monthly_cost_cents") or 0) == 0
        ]
        live_verified = True
        source = "hetzner_api_readonly"
        items = [*live_items, *planned_zero_cost_items]
    else:
        live_verified = False
        source = (
            "configured_phase1_projection_hetzner_api_unavailable"
            if os.getenv("HETZNER_API_TOKEN")
            else "configured_phase1_projection"
        )
        items = planned_infra_items()
    projected = sum(int(item["monthly_cost_cents"]) for item in items)
    percentage = (projected / limit * 100) if limit > 0 else 100.0
    if projected >= limit:
        level = "critical"
        allow = False
    elif projected >= warning:
        level = "warning"
        allow = True
    else:
        level = "ok"
        allow = True
    return InfraBudgetState(
        projected_cost_cents=projected,
        budget_limit_cents=limit,
        warning_limit_cents=warning,
        spent_percentage=round(percentage, 2),
        level=level,
        allow_new_infra=allow,
        live_verified=live_verified,
        source=source,
        items=items,
    )


def llm_budget_warning_percentage() -> int:
    return int(os.getenv("LLM_BUDGET_WARNING_PERCENTAGE", "80"))


def session_llm_call_limit() -> int:
    return int(os.getenv("MAX_LLM_CALLS_PER_SESSION", "50"))


def prompt_rate_limit_capacity() -> int:
    return int(os.getenv("PROMPT_RATE_LIMIT_CAPACITY", "20"))


def prompt_rate_limit_window_seconds() -> int:
    return int(os.getenv("PROMPT_RATE_LIMIT_WINDOW_SECONDS", "3600"))


def prompt_rate_limit_key(project_id: str) -> str:
    window = prompt_rate_limit_window_seconds()
    current_window = int(time.time()) // window
    return f"rate_limit:prompt:{project_id}:{current_window}"


def get_prompt_rate_limit_status(project_id: str) -> dict[str, int | str]:
    client = redis.Redis.from_url(redis_url(), socket_timeout=2, socket_connect_timeout=2, decode_responses=True)
    capacity = prompt_rate_limit_capacity()
    window = prompt_rate_limit_window_seconds()
    key = prompt_rate_limit_key(project_id)
    raw_count = client.get(key)
    count = int(raw_count) if raw_count else 0
    ttl = int(client.ttl(key))
    reset_seconds = ttl if ttl > 0 else window
    return {
        "project_id": project_id,
        "key": key,
        "limit": capacity,
        "used": count,
        "remaining": max(capacity - count, 0),
        "window_seconds": window,
        "reset_seconds": reset_seconds,
    }


def session_llm_call_key(session_id: str) -> str:
    return f"session:{session_id}:llm_calls"


def get_session_llm_call_status(session_id: str) -> dict[str, int | str]:
    client = redis.Redis.from_url(redis_url(), socket_timeout=2, socket_connect_timeout=2, decode_responses=True)
    limit = session_llm_call_limit()
    key = session_llm_call_key(session_id)
    raw_count = client.get(key)
    count = int(raw_count) if raw_count else 0
    ttl = int(client.ttl(key))
    return {
        "session_id": session_id,
        "key": key,
        "limit": limit,
        "used": count,
        "remaining": max(limit - count, 0),
        "ttl_seconds": ttl if ttl > 0 else 60 * 60 * 24,
    }


def get_budget_state() -> BudgetState:
    limit = llm_budget_limit_cents()
    with psycopg.connect(database_url(), autocommit=True) as conn:
        total_row = conn.execute("SELECT COALESCE(SUM(cost_cents), 0) FROM cost_tracking").fetchone()
    total = int(total_row[0]) if total_row else 0
    percentage = (total / limit * 100) if limit > 0 else 100.0
    warning = llm_budget_warning_percentage()
    if percentage >= 100:
        level = "critical"
        allow = False
    elif percentage >= warning:
        level = "warning"
        allow = True
    else:
        level = "ok"
        allow = True
    return BudgetState(
        total_cost_cents=total,
        budget_limit_cents=limit,
        spent_percentage=round(percentage, 2),
        level=level,
        allow_new_calls=allow,
    )


def check_budget_guard() -> BudgetState:
    state = get_budget_state()
    if not state.allow_new_calls:
        raise RuntimeError("LLM budget hard limit reached")
    return state


def rate_limit_prompt(project_id: str) -> dict[str, int]:
    client = redis.Redis.from_url(redis_url(), socket_timeout=2, socket_connect_timeout=2, decode_responses=True)
    window = prompt_rate_limit_window_seconds()
    capacity = prompt_rate_limit_capacity()
    key = prompt_rate_limit_key(project_id)
    count = int(client.incr(key))
    if count == 1:
        client.expire(key, window + 60)
    remaining = max(capacity - count, 0)
    if count > capacity:
        raise RuntimeError("prompt rate limit exceeded")
    return {"limit": capacity, "remaining": remaining, "window_seconds": window}


def register_session_llm_call(session_id: str) -> int:
    client = redis.Redis.from_url(redis_url(), socket_timeout=2, socket_connect_timeout=2, decode_responses=True)
    key = session_llm_call_key(session_id)
    count = int(client.incr(key))
    if count == 1:
        client.expire(key, 60 * 60 * 24)
    limit = session_llm_call_limit()
    if count > limit:
        raise RuntimeError("session LLM call limit exceeded")
    return count
