## L7 — Integration & Verification (Verifier, Contracts, Gates)

### Implementierung (Ist-Stand)

- Browser Contract Verifier: `scripts/verify-browser-contract.ps1`
- Runtime Contract Verifier: `scripts/verify-phase1-runtime.ps1`
- Repo/Governance Verifier: `scripts/verify-phase1.ps1`
- External Gate Audit: `scripts/verify-external-gates.ps1` (keine Fake-Credentials; blocked wenn env fehlt)

### Wiring (L7 ↔ L1–L6)

- Verifier laufen gegen nginx (`http://localhost:8081`) fuer DEV-ONLY Proofs.
- Hosted Proofs erfordern echte HTTPS URLs + Tokens, sonst bleiben Gates blocked.

### Nachweise/Artefakte

- External Gate Audit Artefakte: `.phase1-artifacts/external-gate-audit-*.json`
- Weitere Proof Artefakte: `.phase1-artifacts/` (keine Secrets).

Referenzen:
- `docs/runtime-contracts/verification-harness.md`
- `docs/runtime-contracts/external-gate-audit-contract.md`
