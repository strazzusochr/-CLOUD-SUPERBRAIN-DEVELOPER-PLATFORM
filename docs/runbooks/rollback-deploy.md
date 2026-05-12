# Rollback Deploy Runbook

Stand: 2026-05-05
Status: Active baseline for Phase 5

## Trigger

- Hosted staging or production-candidate rollout is unhealthy
- critical regression after deploy
- rollback ordered by owner

## Ziel

- Rueckkehr auf den letzten bekannten guten Candidate
- Zielzeit: unter 5 Minuten pro Service

## Voraussetzungen

1. Vorheriger bekannter guter Image-Tag ist dokumentiert.
2. Release-Artefakt nennt den Ruecksetzpfad.
3. Hosted health endpoints sind bekannt.

## Schritte

1. Betroffenen Release-Kandidaten und letzten guten Tag identifizieren.
2. Nur auf den letzten guten GHCR-Tag zuruecksetzen.
3. Pull-basierten Stack mit dem bekannten guten Tag neu starten.
4. `GET /api/v1/health`, `/mcp/api/v1/health`, `/llm/api/v1/health` und Root-URL pruefen.
5. Rollback-Ereignis im Incident-/Release-Artefakt vermerken.

## Verifikation

- Hosted root antwortet
- Agent API antwortet healthy
- MCP Gateway antwortet healthy
- LLM Gateway antwortet healthy
- Release-Artefakt enthaelt Rollback-Notiz

## Eskalation

- Wenn Health nach Rollback nicht zurueckkommt: Owner + Incident-Response-Runbook
- Wenn Datenmigration betroffen ist: nur Forward-Fix oder Snapshot-Restore, keine unsafe down-migration

## Non-Claims

- Dieses Runbook fuehrt keinen Rollback automatisch aus.
- Dieses Runbook behauptet keinen Production-Rollout.
