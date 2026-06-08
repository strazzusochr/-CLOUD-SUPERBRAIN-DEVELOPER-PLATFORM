## L1 — Daten & Speicher (Postgres/pgvector, Redis, Artifacts)

### Implementierung (Ist-Stand)

- PostgreSQL (pgvector) als App-DB + LangGraph Checkpoint-Store.
- Redis fuer Queue/Working Memory + Rate/Session Guards.
- Artifacts/Proofs werden in `.phase1-artifacts/` erzeugt (ohne Secrets).

### Wiring (L1 → L2/L3/L4)

- L1 → L3: Redis Task Queue + Postgres Checkpoints fuer Orchestrator/Worker.
- L1 → L4: agent-api Health/Contracts pruefen DB/Redis/Worker Status.
- L1 → L7: Runtime-Verifier erzeugt Backup/Restore/Persistence Proofs.

### Verifikation (DEV-ONLY)

- `npm run verify:runtime` prueft u.a.:
  - Postgres Backup/Restore Proof
  - Redis Persistence Proof
  - Non-root + Security hardening der Container

Referenz: `docs/runtime-contracts/verification-harness.md`
