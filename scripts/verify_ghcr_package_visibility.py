#!/usr/bin/env python3
"""Fail closed unless every existing candidate package is private.

The check is read-only. A missing package is allowed before its first publish;
an existing public or internal package is never silently reused.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request


SERVICES = (
    "agent-api",
    "mcp-gateway",
    "frontend",
    "llm-gateway",
    "agent-worker",
    "memory-worker",
)
API_ROOT = "https://api.github.com"


class VisibilityError(RuntimeError):
    pass


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise VisibilityError(message)


def verify_visibility(owner: str, namespace: str, token: str, *, opener=urllib.request.urlopen) -> tuple[int, int]:
    _require(re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})", owner) is not None, "owner is invalid")
    _require(re.fullmatch(r"[a-z0-9](?:[a-z0-9._-]{0,98}[a-z0-9])?", namespace) is not None, "namespace is invalid")
    _require(isinstance(token, str) and token != "", "package read token is unavailable")
    existing = 0
    absent = 0
    for service in SERVICES:
        package_name = f"{namespace}/{service}"
        encoded = urllib.parse.quote(package_name, safe="")
        request = urllib.request.Request(
            f"{API_ROOT}/users/{owner}/packages/container/{encoded}",
            headers={
                "Accept": "application/vnd.github+json",
                "Authorization": f"Bearer {token}",
                "X-GitHub-Api-Version": "2022-11-28",
                "User-Agent": "cloud-superbrain-private-package-verifier/1.0",
            },
            method="GET",
        )
        try:
            with opener(request, timeout=20) as response:
                _require(getattr(response, "status", 200) == 200, f"package visibility read failed for {service}")
                payload = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                absent += 1
                continue
            raise VisibilityError(f"package visibility read failed for {service} with HTTP {exc.code}") from exc
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise VisibilityError(f"package visibility response is invalid for {service}") from exc
        _require(isinstance(payload, dict), f"package visibility response is invalid for {service}")
        _require(payload.get("name") == package_name, f"package identity mismatch for {service}")
        _require(payload.get("package_type") == "container", f"package type mismatch for {service}")
        _require(payload.get("visibility") == "private", f"existing candidate package is not private: {service}")
        existing += 1
    _require(existing + absent == len(SERVICES), "package inventory count mismatch")
    return existing, absent


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner", required=True)
    parser.add_argument("--namespace", default="cloud-superbrain-developer-platform")
    parser.add_argument("--token-env", default="GITHUB_TOKEN")
    args = parser.parse_args()
    try:
        token = os.environ.get(args.token_env, "")
        existing, absent = verify_visibility(args.owner, args.namespace, token)
    except VisibilityError as exc:
        print(f"[ghcr-private-visibility] ERROR: {exc}", file=sys.stderr)
        return 1
    print(
        f"[ghcr-private-visibility] PASS existing_private={existing} absent={absent} "
        "provider_writes=false secret_output=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
