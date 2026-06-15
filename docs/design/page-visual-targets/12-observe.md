# 12 Observe - Visual Target

Route: `/observe`

Goal: monitoring/observability page for real read-only runtime values and clearly labelled spec-only surfaces. No fake live charts.

Required layout:
- Header shows whether `GET /api/v1/metrics` is live or spec-only.
- Runtime-service health and metric cards use real read-only metrics when available.
- Observability endpoint inventory is read-only.
- Traffic chart is explicitly `spec-only` until OTel is wired.

Element rules:
- Metrics contract button must call `GET /api/v1/metrics/contract` and show `PASS observe_readonly_probe`.
- Static traffic bars are allowed only when labelled spec-only.
- Budget metric remains hidden unless paid/metered capability is selected.
- No provider write, no live LLM call, no production claim.
