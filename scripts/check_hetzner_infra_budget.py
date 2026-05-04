#!/usr/bin/env python3
"""Hetzner projected monthly infrastructure budget check.

This script intentionally counts only infrastructure spend under the PATCHED plan:
Hetzner server monthly prices. LLM/API provider costs are separate.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.request
from decimal import Decimal, InvalidOperation

API_URL = "https://api.hetzner.cloud/v1/servers"


def money(value: str | int | float | None) -> Decimal:
    if value is None:
        return Decimal("0")
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError):
        return Decimal("0")


def server_monthly_gross(server: dict) -> Decimal:
    location = (server.get("datacenter") or {}).get("location") or {}
    location_name = location.get("name")
    prices = ((server.get("server_type") or {}).get("prices") or [])
    if not prices:
        return Decimal("0")

    selected = None
    for price in prices:
        if price.get("location") == location_name:
            selected = price
            break
    selected = selected or prices[0]
    gross = (selected.get("price_monthly") or {}).get("gross")
    return money(gross)


def main() -> int:
    token = os.environ.get("HETZNER_API_TOKEN")
    if not token:
        print("HETZNER_API_TOKEN is not configured; skipping infra cost check.")
        return 0

    budget = money(os.environ.get("INFRA_BUDGET_EUR", "20"))
    warning = money(os.environ.get("INFRA_WARN_EUR", "16"))

    request = urllib.request.Request(API_URL, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = json.loads(response.read().decode("utf-8"))

    servers = payload.get("servers", [])
    total = sum((server_monthly_gross(server) for server in servers), Decimal("0"))

    print(f"Projected Hetzner monthly server cost: EUR {total:.2f}")
    print(f"Infra warning threshold: EUR {warning:.2f}; hard budget: EUR {budget:.2f}")
    for server in servers:
        name = server.get("name", "unknown")
        status = server.get("status", "unknown")
        stype = (server.get("server_type") or {}).get("name", "unknown")
        print(f"- {name}: {stype}, {status}, EUR {server_monthly_gross(server):.2f}/month")

    if total >= budget:
        print("ERROR: projected Hetzner infrastructure cost reaches or exceeds hard budget.", file=sys.stderr)
        return 2
    if total >= warning:
        print("WARNING: projected Hetzner infrastructure cost reaches warning threshold.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())