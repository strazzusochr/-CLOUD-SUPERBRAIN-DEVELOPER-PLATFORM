from __future__ import annotations

import json
from pathlib import Path
from typing import Any

MANIFEST_PATH = Path("docs/project-progress.manifest.json")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"[project-progress] {message}")


def validate_items(items: list[dict[str, Any]], expected_count: int, prefix: str) -> None:
    require(len(items) == expected_count, f"{prefix} must contain exactly {expected_count} items")
    seen: set[str] = set()
    for item in items:
        item_id = str(item.get("id", ""))
        require(item_id, f"{prefix} item missing id")
        require(item_id not in seen, f"{prefix} contains duplicate id {item_id}")
        seen.add(item_id)
        require(str(item.get("label", "")), f"{item_id} missing label")
        require(str(item.get("status", "")), f"{item_id} missing status")
        percent = item.get("percent")
        require(isinstance(percent, int), f"{item_id} percent must be an integer")
        require(0 <= percent <= 100, f"{item_id} percent must be between 0 and 100")


def main() -> int:
    require(MANIFEST_PATH.exists(), f"missing {MANIFEST_PATH}")
    payload = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    phases = payload.get("horizontal", {}).get("items", [])
    layers = payload.get("vertical", {}).get("items", [])
    validate_items(phases, 7, "horizontal phase progress")
    validate_items(layers, 7, "vertical layer progress")
    expected_overall = round(sum(item["percent"] for item in phases) / len(phases))
    require(payload.get("overall_percent") == expected_overall, "overall_percent must equal rounded phase average")
    require(payload.get("progress_source") == "docs/project-progress.manifest.json", "progress_source must point to manifest")
    require(payload.get("binding_document") == "docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md", "binding document mismatch")
    require("Evidence-based only" in str(payload.get("truth_policy", "")), "truth policy must be explicit")
    require(payload.get("non_claims"), "non_claims must not be empty")
    print(f"[project-progress] manifest valid: overall={payload['overall_percent']}%")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
