from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPECTED_PINS = {
    "fastapi": "0.136.3",
    "httpx": "0.28.1",
    "langgraph": "1.2.4",
    "langgraph-checkpoint-postgres": "3.1.0",
    "psycopg[binary]": "3.3.4",
    "pydantic": "2.13.4",
    "redis": "8.0.0",
}
GET_CASES = [
    ("api.index", "/api/v1/health", "status", "degraded"),
    ("api.index", "/api/v1/clouds/layers", "contract_version", "cloud-layer-readiness-v1"),
    ("api.llm", "/llm/api/v1/responses/contract", "contract_version", "llm-responses-adapter-contract-v2"),
    ("api.mcp", "/mcp/api/v1/version-pinning/contract", "contract_version", "mcp-version-pinning-v1"),
]
POST_CASES = [
    ("api.index", "/api/v1/orchestrator/dry-run"),
    ("api.llm", "/llm/v1/chat/completions"),
    ("api.mcp", "/mcp/api/v1/tools/execute"),
]


def run_case(module: str, method: str, path: str) -> dict[str, object]:
    source = f"""
import json
from fastapi.testclient import TestClient
import {module} as target
with TestClient(target.app) as client:
    response = client.request({method!r}, {path!r}, json={{}} if {method!r} == 'POST' else None)
    try:
        payload = response.json()
    except Exception:
        payload = {{}}
    print(json.dumps({{'http_status': response.status_code, 'payload': payload}}))
"""
    completed = subprocess.run(
        [sys.executable, "-c", source],
        cwd=ROOT,
        capture_output=True,
        check=False,
        text=True,
        timeout=90,
    )
    if completed.returncode != 0:
        raise RuntimeError(f"{module} {method} {path} failed: {completed.stderr[-500:]}")
    return json.loads(completed.stdout.strip().splitlines()[-1])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    requirements = {}
    for line in (ROOT / "requirements.txt").read_text(encoding="utf-8").splitlines():
        if "==" in line:
            name, version = line.split("==", 1)
            requirements[name] = version
    if requirements != EXPECTED_PINS:
        raise RuntimeError(f"requirements pins differ: {requirements}")

    config = json.loads((ROOT / "vercel.json").read_text(encoding="utf-8"))
    destinations = {item["source"]: item["destination"] for item in config.get("rewrites", [])}
    expected_destinations = {
        "/api/v1/:path*": "/api/index",
        "/llm/:path*": "/api/llm",
        "/mcp/:path*": "/api/mcp",
        "/health": "/api/index",
    }
    if destinations != expected_destinations:
        raise RuntimeError(f"rewrites differ: {destinations}")

    results: list[dict[str, object]] = []
    for module, path, field, expected in GET_CASES:
        response = run_case(module, "GET", path)
        actual = response["payload"].get(field)
        passed = response["http_status"] == 200 and actual == expected
        results.append(
            {
                "module": module,
                "method": "GET",
                "path": path,
                "http_status": response["http_status"],
                "field": field,
                "actual": actual,
                "expected": expected,
                "passed": passed,
            }
        )

    for module, path in POST_CASES:
        response = run_case(module, "POST", path)
        payload = response["payload"]
        passed = response["http_status"] == 503 and payload.get("reason") == "stateless_contract_origin_read_only"
        results.append(
            {
                "module": module,
                "method": "POST",
                "path": path,
                "http_status": response["http_status"],
                "reason": payload.get("reason"),
                "passed": passed,
            }
        )

    report = {
        "contract_version": "vercel-backend-skeleton-proof-v1",
        "python": sys.version.split()[0],
        "all_passed": all(bool(item["passed"]) for item in results),
        "results": results,
    }
    rendered = json.dumps(report, indent=2)
    if args.output:
        output = args.output if args.output.is_absolute() else ROOT / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    return 0 if report["all_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
