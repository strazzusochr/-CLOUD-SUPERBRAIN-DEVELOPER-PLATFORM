from __future__ import annotations

import json
from pathlib import Path
from typing import Any

GATE_PATH = Path("docs/phase-transition-gate.json")
MANIFEST_PATH = Path("docs/project-progress.manifest.json")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"[phase-transition-gate] {message}")


def load_json(path: Path) -> dict[str, Any]:
    require(path.exists(), f"missing {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    gate = load_json(GATE_PATH)
    manifest = load_json(MANIFEST_PATH)

    require(gate.get("status") == "transition_ready_local", "gate status must be transition_ready_local")
    require(
        gate.get("binding_document") == "docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md",
        "binding document mismatch",
    )
    require(gate.get("source_manifest") == str(MANIFEST_PATH).replace("\\", "/"), "source manifest mismatch")

    phase_items = manifest.get("horizontal", {}).get("items", [])
    phase_1 = next((item for item in phase_items if item.get("id") == "phase_1"), None)
    phase_2 = next((item for item in phase_items if item.get("id") == "phase_2"), None)
    require(phase_1 is not None, "manifest missing phase_1")
    require(phase_2 is not None, "manifest missing phase_2")
    require(int(phase_1.get("percent", 0)) >= 98, "phase_1 must be at least 98 percent for local transition gate")
    require(int(phase_2.get("percent", 0)) >= 24, "phase_2 local scaffold must remain visible")

    required_verifiers = set(gate.get("required_verifiers", []))
    for verifier in {
        "scripts/verify-phase1.ps1",
        "scripts/verify-phase1-runtime.ps1",
        "scripts/verify-hosted-staging.ps1",
    }:
        require(verifier in required_verifiers, f"missing required verifier {verifier}")
        require(Path(verifier).exists(), f"required verifier file missing: {verifier}")

    closed_gate_ids = {item.get("id") for item in gate.get("closed_gates", [])}
    require({"gate_d", "gate_e"}.issubset(closed_gate_ids), "Gate D and Gate E must remain closed")

    forbidden_text = "\n".join(gate.get("forbidden_next_actions", []))
    for required_forbidden in ["pasted secrets", "live LLM", "Docker images", "main", "MCP write"]:
        require(required_forbidden.lower() in forbidden_text.lower(), f"missing forbidden action marker: {required_forbidden}")

    non_claims = "\n".join(gate.get("non_claims", []))
    for required_non_claim in ["Phase 2 full runtime", "Live providers", "Production deployment", "Hosted staging"]:
        require(required_non_claim.lower() in non_claims.lower(), f"missing non-claim: {required_non_claim}")

    print("[phase-transition-gate] local Phase 1 -> Phase 2 gate valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
