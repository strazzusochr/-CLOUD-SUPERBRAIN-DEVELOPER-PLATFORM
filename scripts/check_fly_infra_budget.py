from __future__ import annotations

import json
import os
from decimal import Decimal, ROUND_HALF_UP
from urllib.request import Request, urlopen


FLY_GRAPHQL_URL = "https://api.fly.io/graphql"
WARNING_LIMIT_CENTS = 1600
BUDGET_LIMIT_CENTS = 2000
PLANNED_ITEMS = [
    ("fly-production-shared-cpu-1x", 500),
    ("fly-staging-shared-cpu-1x", 400),
    ("cloudflare-free-tier", 0),
    ("ghcr-free-tier", 0),
]


def _cents_to_eur_string(cents: int) -> str:
    eur = (Decimal(cents) / Decimal(100)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return f"EUR {eur}"


def _probe_fly_token(token: str) -> bool:
    payload = json.dumps({"query": "{ viewer { email } }"}).encode("utf-8")
    request = Request(
        FLY_GRAPHQL_URL,
        data=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    with urlopen(request, timeout=10) as response:
        body = json.loads(response.read().decode("utf-8", errors="replace"))
    return bool(body.get("data", {}).get("viewer"))


def main() -> int:
    token = os.getenv("FLY_API_TOKEN", "").strip()
    if not token:
        print("Missing required environment variable: FLY_API_TOKEN")
        return 2

    if not _probe_fly_token(token):
        print("Fly.io GraphQL viewer probe failed")
        return 3

    projected = sum(cost for _, cost in PLANNED_ITEMS)
    print(f"Projected Fly.io monthly server cost: {_cents_to_eur_string(projected)}")
    print(f"Infra warning threshold: {_cents_to_eur_string(WARNING_LIMIT_CENTS)}")
    print(f"Hard infrastructure budget: {_cents_to_eur_string(BUDGET_LIMIT_CENTS)}")
    print("Live Fly.io token probe: verified")
    if projected >= BUDGET_LIMIT_CENTS:
        print("Result: over hard budget")
        return 4
    if projected >= WARNING_LIMIT_CENTS:
        print("Result: under hard budget, above warning threshold")
    else:
        print("Result: under warning threshold")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
