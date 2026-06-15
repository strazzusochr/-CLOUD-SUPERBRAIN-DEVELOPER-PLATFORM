# 17 Evidence - Visual Target

Route: `/evidence`

Goal: proof and verifier surface for claim guards, runtime verification, closed gates, and evidence artifacts. It may show blocked gates, but must not claim pass without current evidence.

Required layout:
- Header explains evidence-first claim policy.
- Seven-layer claim guard remains visible.
- Read-only verifier probe fetches live platform/integrity status.
- Verifier script table is inventory unless a current runtime result is available.

Element rules:
- Verifier probe must call `GET /api/v1/platform/verify` and `GET /api/v1/project/progress/integrity`, then show `PASS evidence_verifier_probe`.
- Closed gates remain visible as non-claims.
- No verifier execution from UI unless explicitly implemented later.
- No provider write, no live LLM call, no production claim, no secret output.
