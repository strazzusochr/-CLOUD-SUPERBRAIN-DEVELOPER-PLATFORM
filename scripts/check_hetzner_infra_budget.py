from __future__ import annotations

import json
import os
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from typing import Any
from urllib.request import Request, urlopen


HETZNER_API_URL = "https://api.hetzner.cloud/v1"
WARNING_LIMIT_CENTS = 1600
BUDGET_LIMIT_CENTS = 2000


@dataclass(frozen=True)
class BudgetResult:
    projected_cost_cents: int
    warning_limit_cents: int
    budget_limit_cents: int
    level: str
    allow_new_infra: bool
    live_verified: bool
    source: str
    items: list[dict[str, object]]
    observed_server_types: list[str]


def _cents_to_eur_string(cents: int) -> str:
    eur = (Decimal(cents) / Decimal(100)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    return f"EUR {eur}"


def _price_table_monthly_cents() -> dict[str, int]:
    return {
        "cx21": 639,
        "cx22": 920,
        "cx23": 1350,
        "cax21": 499,
        "cax31": 1903,
        "cax41": 2990,
    }


def _http_get_json(url: str, token: str) -> dict[str, Any]:
    request = Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
        method="GET",
    )
    with urlopen(request, timeout=10) as response:
        payload = response.read().decode("utf-8", errors="replace")
    return json.loads(payload)


def _compute_budget_from_servers(servers: list[dict[str, Any]]) -> BudgetResult:
    price_table = _price_table_monthly_cents()
    items: list[dict[str, object]] = []
    projected = 0
    observed: list[str] = []
    for server in servers:
        server_type = (server.get("server_type") or {}).get("name") or "unknown"
        observed.append(str(server_type))
        monthly = price_table.get(str(server_type))
        if monthly is None:
            monthly = 0
            items.append({"name": f"hetzner_server_type:{server_type}", "monthly_cost_cents": monthly})
        else:
            items.append({"name": f"hetzner_server_type:{server_type}", "monthly_cost_cents": monthly})
        projected += int(monthly)

    if projected >= BUDGET_LIMIT_CENTS:
        level = "critical"
        allow_new = False
    elif projected >= WARNING_LIMIT_CENTS:
        level = "warning"
        allow_new = True
    else:
        level = "ok"
        allow_new = True

    return BudgetResult(
        projected_cost_cents=projected,
        warning_limit_cents=WARNING_LIMIT_CENTS,
        budget_limit_cents=BUDGET_LIMIT_CENTS,
        level=level,
        allow_new_infra=allow_new,
        live_verified=True,
        source="hetzner_api_readonly",
        items=items,
        observed_server_types=observed[:5],
    )


def main() -> int:
    token = os.getenv("HETZNER_API_TOKEN", "").strip()
    if not token:
        print("Missing required environment variable: HETZNER_API_TOKEN")
        return 2

    payload = _http_get_json(f"{HETZNER_API_URL}/servers", token)
    servers = payload.get("servers") or []
    if not isinstance(servers, list):
        servers = []

    result = _compute_budget_from_servers(servers)

    print(f"Projected Hetzner monthly server cost: {_cents_to_eur_string(result.projected_cost_cents)}")
    print(f"Infra warning threshold: {_cents_to_eur_string(result.warning_limit_cents)}")
    print(f"Hard infrastructure budget: {_cents_to_eur_string(result.budget_limit_cents)}")
    if result.observed_server_types:
        print(f"Running server type observed: {result.observed_server_types[0]}")
    if result.level == "critical":
        print("Result: over hard budget")
        return 3
    if result.level == "warning":
        print("Result: under hard budget, above warning threshold")
    else:
        print("Result: under warning threshold")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
