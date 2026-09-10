# RETIRED_HISTORICAL_DO_NOT_EXECUTE

The former Fly.io deployment prompt is retired. It must not be copied or
executed.

Active target: Cloudflare-native zero-card hosted runtime under gate
`cloudflare_native_zero_card_hosted_runtime`.

Current safe preparation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\owner-cloud-gate-activation.ps1
```

This creates a review plan only. It does not authorize hosted writes,
deployment, GHCR publication, production promotion, main-branch changes,
permission expansion, payment, or secret output.

Canonical Owner truth:

- `docs/runtime-state/owner-input-manifest.json`
- `docs/runbooks/cloud-gate-owner-activation-2026-06-09.md`
- `docs/runtime-state/external-gate-audit-v2.json`
