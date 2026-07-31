from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services/llm-gateway"))

from app import main as gateway  # noqa: E402


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"[llm-health-mode] {message}")


def main() -> int:
    calls: list[int] = []

    def forbidden_hf_probe(*_args: Any, **_kwargs: Any) -> dict[str, object]:
        calls.append(1)
        raise AssertionError("inactive Hugging Face provider probe was invoked")

    gateway.GATEWAY_MODE = gateway.CF_WORKERS_AI_MODE
    gateway.hf_router_model_snapshot = forbidden_hf_probe
    gateway.cloudflare_workers_ai_available = lambda: True

    payload = gateway.health()
    require(not calls, "Cloudflare mode invoked the inactive Hugging Face provider")
    require(payload["status"] == "healthy", "Cloudflare mode health is not healthy")
    require(payload["provider"] == "cloudflare-workers-ai", "Cloudflare provider identity is wrong")
    require(payload["provider_status"] == "configured", "Cloudflare provider is not configured")
    require(payload["provider_live_verified"] is False, "health incorrectly claims a live provider read")

    def active_hf_probe(*_args: Any, **_kwargs: Any) -> dict[str, object]:
        calls.append(1)
        return {
            "status": "live_verified",
            "live_verified": True,
            "model_count_visible": 1,
            "models": ["test/model"],
        }

    calls.clear()
    gateway.GATEWAY_MODE = "deterministic_dry_run"
    gateway.hf_router_model_snapshot = active_hf_probe
    gateway.hf_router_token = lambda: "configured-without-output"

    payload = gateway.health()
    require(len(calls) == 1, "active Hugging Face mode did not invoke exactly one provider probe")
    require(payload["provider_live_verified"] is True, "active Hugging Face result was not reflected")

    print("[llm-health-mode] active-provider-only health checks verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
