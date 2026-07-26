# 22-page action matrix

Date: 2026-07-26
Contract: `workspace-action-matrix-v2`
Registry: `apps/frontend/lib/actionMatrix.ts`
Verifier: `scripts/verify-22-page-actions.ps1`
Evidence: `.codex/runs/CURRENT/22-page-actions/report.json`

## Result

`PASS` — real Chromium, no mocks or route interception:

- 22/22 canonical routes visited
- 28/28 enabled page-local action families effect-verified
- 184/184 enabled member actions audited
- 183 direct effect proofs plus 1 exact, source-bound P0 proof
- 0 dead, unregistered, click-only, or non-direct passes
- 2/2 allowed build requests returned live provider responses
- 0 unexpected provider requests
- 0 unexpected console errors; 0 page errors
- 2 expected and request-correlated HTTP 403 console errors from the guarded
  Games and Apps DELETE paths
- DEV-ONLY; hosted proof still blocked

The registry contains 30 page-local families and 195 members in total.
Availability is explicit: 184 `enabled`, 5 `spec_only`, 2 `contract_only`,
0 `provider_gated`, and 4 `conditional`. `/technology` and `/open-source`
intentionally have no page-local actions. Global AppShell navigation is
separate and is not counted here.

Static `PASS`/`GAP` labels name pre-existing evidence sources. The current
22-page Chromium report is authoritative for the enabled acceptance scope:
28 families and 184 members are verified. It does not promote gated,
conditional-without-precondition, specification-only, or contract-only
members.

## Route inventory

| Route | Enabled families | Total members | Enabled | Non-enabled | Excluded gates |
| --- | ---: | ---: | ---: | ---: | ---: |
| `/home` | 3 | 19 | 18 | 1 conditional | 0 |
| `/login` | 1 | 6 | 6 | 0 | 1 |
| `/workbench` | 3 | 10 | 10 | 0 | 0 |
| `/organism` | 4 | 30 | 30 | 0 | 0 |
| `/organism/replay` | 1 | 34 | 33 | 1 contract | 0 |
| `/organism/map` | 1 | 33 | 33 | 0 | 0 |
| `/agents` | 1 | 3 | 2 | 1 conditional | 0 |
| `/files` | 1 | 2 | 2 | 0 | 0 |
| `/files/local` | 0 | 5 | 0 | 5 spec | 1 |
| `/tools` | 1 | 4 | 4 | 0 | 1 |
| `/marketplace` | 1 | 3 | 3 | 0 | 1 |
| `/observe` | 1 | 5 | 5 | 0 | 0 |
| `/games` | 4 | 16 | 14 | 2 conditional | 0 |
| `/apps` | 1 | 4 | 4 | 0 | 0 |
| `/media` | 1 | 4 | 4 | 0 | 0 |
| `/docs-output` | 1 | 4 | 4 | 0 | 0 |
| `/evidence` | 1 | 4 | 4 | 0 | 1 |
| `/diagnostics` | 1 | 5 | 5 | 0 | 0 |
| `/design-system` | 1 | 3 | 3 | 0 | 0 |
| `/technology` | 0 | 0 | 0 | 0 | 0 |
| `/settings` | 0 | 1 | 0 | 1 contract | 1 |
| `/open-source` | 0 | 0 | 0 | 0 | 0 |

## Acceptance rules

- Every enabled member must mount and be audited.
- Every enabled family must show at least one real state, data, navigation,
  download, error, or exact-current-evidence effect.
- The two allowed visible build controls may make one build each. Their
  gateway-only live provider responses must be recorded; any additional
  provider request fails the verifier.
- The exact persisted P0 Workbench build proof may cover only the registered
  `workbench-build` control and only while its source binding remains current.
- Shared Organism and LiveConsole controls require a passing canonical action
  plus a mounted route-local control/effect.
- LiveConsole loads require the selected endpoint request and the exact
  response body to become visible.
- Conditional controls are excluded only when their documented runtime
  precondition is absent.
- Historical GET payloads never count as current provider calls.
- Expected HTTP 403 browser-console entries count only when correlated to the
  guarded Games or Apps DELETE request. Any other console error fails.

## Corrections found by acceptance

- Example chips select prompts without silently starting a provider request.
- `BuildsGallery` removes cards only after a successful DELETE. HTTP 403,
  other server errors, and network failures retain the card and show a
  `role="alert"` message.
- Build status reads use a bounded timeout and surface an unavailable backend
  truthfully instead of reporting a false not-found result.
- The Workbench retries one read-only status request on a transient server
  error and keeps the visible error when the retry fails.
- Marketplace catalog cards are informational; the nonexistent card button
  action was removed.
- RealGame full-power and emergency-stop controls are conditional on an active
  GPU warning.
- The Agents goal control is registered as an `input`, not a `textarea`.
- Native Organism hub links, Media tab switching, Games result controls,
  generated-game popup/download paths, and LiveConsole routes have causal
  action contracts.
- Hydration sentinels prevent the verifier from interacting with server HTML
  before React controls are ready.

## Excluded gates

1. external OAuth activation
2. live host filesystem read/write
3. write-capable MCP execution
4. live marketplace provider installation
5. verifier-script execution from the Evidence UI
6. Settings Apply

## Verification

- Frontend TypeScript: PASS
- Frontend focused ESLint: PASS
- PowerShell verifier parse: PASS
- `verify-22-page-actions.ps1`: PASS
- Runtime evidence: 22 routes, 28 families, 184 actions, zero dead actions
- Source binding:
  `98189cefcd24224e9e573ba62e1c2d8af5b06d23c9f39f19474b878d666ea534`

DEV-ONLY; hosted proof still blocked.
