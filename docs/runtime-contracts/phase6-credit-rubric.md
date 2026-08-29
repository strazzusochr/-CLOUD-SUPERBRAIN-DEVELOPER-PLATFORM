# Phase-6-Credit-Rubrik — OWNER-ENTWURF

Status: `DRAFT_OWNER_APPROVAL_REQUIRED`
Version: `phase6-credit-rubric-draft-v1`
Erstellt: `2026-08-29`
Zelle: `phase_6`
Aktueller evidenzbasierter Credit: `90`
Offener Hosted-Scale-Credit: `10`
Summe: `100`
Credit-Anwendung erlaubt: `false`

Dieser Entwurf strukturiert den bestehenden P6-Stand und den einzigen offenen Block. Er
aendert weder P6 `90` noch Overall `89`, das Gate `phase6_scale_runtime`, Hosted State,
`live_verified` oder eine Release-Aussage.

## Bewertungsregeln

- Der historische 90-Punkte-Stand wird nur rekonstruiert, nicht neu vergeben. Der erste
  32-Punkte-Block bleibt gemeinsam, weil die vorhandenen Anker keine sichere getrennte
  Acht-Punkte-Bewertung seiner vier Teilfaehigkeiten tragen.
- Die vier Hosted-Zeilen `P6-H01` bis `P6-H04` sind Gewichtungsbestandteile eines einzigen
  atomaren Scale-Beweises. Schlaegt eine Zeile fehl, bleibt der gesamte offene Credit `0/10`.
- `DEV-ONLY`, localhost, synthetische Fixtures, statische Contracts, alte Hosted Evidence,
  handeditierte Gate-Booleans und Teillaeufe erhalten fuer den offenen Block null Punkte.
- Ein bestandener begrenzter Lauf ist kein unbegrenzter Benchmark-, Capacity-, Production-
  oder Release-Claim.

## Kriterien

| ID | Kriterium | Punkte | Heutiger Stand |
|---|---|---:|---|
| P6-B01 | Historischer gemeinsamer Frontend-Block: Client-Runtime, Interaktion, Scene-State und Performance-Budget | 32 | bereits kreditierter Gesamtblock |
| P6-B02 | Kamera- und Lichtsteuerung | 8 | bereits kreditiert; DEV-ONLY Beweis |
| P6-B03 | Gameplay-Zustandsmaschine | 8 | bereits kreditiert; DEV-ONLY Beweis |
| P6-B04 | Asset-Policy und fail-closed Asset-Grenzen | 8 | bereits kreditiert; DEV-ONLY Beweis |
| P6-B05 | Volatiler Save-/Load-Roundtrip | 8 | bereits kreditiert; DEV-ONLY Beweis |
| P6-B06 | Accessibility-Steuerung und sichtbare Zustandswirkung | 8 | bereits kreditiert; DEV-ONLY Beweis |
| P6-B07 | Browser-Loopback-Netcode ohne Remote-/Server-Claim | 8 | bereits kreditiert; DEV-ONLY Beweis |
| P6-B08 | Lokale Scoreboard-/Performance-Klassifikation | 10 | bereits kreditiert; DEV-ONLY Beweis |
| P6-H01 | Exakt 800 Hosted Reads in drei Stufen (`60@1`, `240@10`, `500@50`) | 3 | offen |
| P6-H02 | Exakt 50 authentisierte D1-Creates bei Concurrency `10`, ohne Verlust/Duplikat und mit vollstaendigem Readback | 3 | offen |
| P6-H03 | Exakt 50 auditierte Deletes mit `soft_delete_then_active_row_absence_and_audit_readback` und vollstaendigem Cleanup | 2 | offen |
| P6-H04 | Exakte Requestzahl, Erfolgsquote, p95- und 5xx-Auswertung gegen die festgelegten Grenzwerte | 2 | offen |
| **Summe** |  | **100** | **Entwurf; kein neuer Credit** |

## Feste Hosted-Scale-Grenzen

- Vertrag: `phase6-scale-criterion-v2`; kanonischer SHA-256
  `edeeac95fac6fefe1dcde5b77a5d8b236685f28adf66f357706aed26971ed85f`.
- Ziel: `https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev`.
- Zero-card only; Payment und Paid-Fallback sind verboten.
- Worker-Hardcap: exakt `900` Requests = `800` Reads + `50` Creates + `50` Deletes.
- Die getrennte `/cdn-cgi/trace`-Kontrolle umfasst exakt `244` Edge-Requests
  (`4x1 + 4x10 + 4x50`) unter einem separaten Cap `500`. Damit entstehen exakt `1.144`
  ausgehende HTTP-Requests, davon `900` Worker-aufrufend und `244` reine Edge-Kontrollen.
- Offener Contract-/Runtime-Widerspruch vor jeder Rubrikfreigabe: das Criterion nennt die
  Edge-Kontrolle `not_a_pass_criterion`, waehrend der aktuelle Runtime-Verifier
  `edge_control_failure` in die passentscheidende Failure-Liste aufnimmt und der
  Evidence-Verifier eine leere Liste verlangt. Diese Semantik muss vor Aktivierung
  vereinheitlicht und Red-first abgesichert werden; der Entwurf entscheidet sie nicht.
- Mindest-Erfolgsquote `0.99`, schlechtester p95 hoechstens `1500 ms`, eigene Worker-5xx
  exakt `0`.
- HTTP `429` ist nur in Read-Tiers beobachtbar und zaehlt nie als Erfolg; Create-/Delete-
  `429` macht den Lauf rot.
- Fehlende Authentisierung, Owner-Freigabe, Source-/Deployment-Paritaet oder expliziter
  Write-Schalter muss vor dem ersten HTTP-Aufruf mit null Requests abbrechen.
- Ausfuehrung nur per `workflow_dispatch`, exakter Execution-HEAD-/Source-Bindung und
  geschuetztem Environment `phase6-scale-hosted-writes`.
- Evidence bleibt immutable und SHA-gebunden; GitHub Run, Artifact und anonymer API-
  Readback muessen denselben Lauf bestaetigen.
- Read-only Evidence-Verifikation muss weiterhin `gate_may_open=false`,
  `gate_promotion_performed=false` und `percentage_credit_awarded=0` melden.

## Absichtliche Nichtziele

Die folgende geordnete 22-Eintraege-Multimenge bleibt unveraendert. Die beiden Duplikate
sind absichtlich Teil des bestehenden Contracts und duerfen nicht dedupliziert werden:

1. `binary_asset_upload_blocked`
2. `benchmark_claim_blocked`
3. `shader_hotload_blocked`
4. `remote_multiplayer_netcode_blocked`
5. `server_authoritative_sync_blocked`
6. `physics_engine_blocked`
7. `external_asset_fetch_blocked`
8. `binary_asset_upload_blocked`
9. `remote_cdn_fetch_blocked`
10. `asset_pipeline_service_blocked`
11. `load_without_snapshot_blocked`
12. `persistent_browser_storage_blocked`
13. `cloud_save_sync_blocked`
14. `binary_snapshot_upload_blocked`
15. `server_snapshot_write_blocked`
16. `websocket_transport_blocked`
17. `webrtc_transport_blocked`
18. `matchmaking_blocked`
19. `public_lobby_blocked`
20. `server_authoritative_sync_blocked`
21. `phase6_leaderboard_sync_blocked`
22. `phase6_capacity_claim_blocked`

Ein begrenzter Hosted-Lauf entfernt insbesondere weder `benchmark_claim_blocked` noch
`phase6_capacity_claim_blocked`.

## Evidence- und Owner-Kette

1. Owner genehmigt die exakte Rubrik-Commit-SHA; der Entwurf selbst ist nicht bindend.
2. Separat wird ein aktueller source-gleicher Hosted-Deploy genehmigt. Der vorhandene
   Hosted-Stand ist fuer diese Rubrik nicht aktuell genug.
3. Separat werden das geschuetzte Environment, das Secret `AGENT_API_AUTH_TOKEN` (nur sein
   Wert bleibt unausgegeben), `owner_granted=true` mit Grant-Referenz und genau ein Dispatch
   mit `source_sha=<CURRENT_DEPLOYED_SOURCE_SHA>` sowie `allow_hosted_writes=true`
   genehmigt; der Workflow uebergibt daraus `-AllowHostedWrites`.
4. `scripts/verify-phase6-scale-evidence.ps1` validiert Evidence und GitHub-Readback
   standardmaessig read-only. Eine Promotion ist ein weiterer eigener Owner-Schritt.
5. Ein noch zu genehmigender P6-Credit-Scorer berechnet den atomaren `+10`-Block aus den
   unveraenderten Rohbeweisen. Der A1-Replay hat aktuell keinen P6-Scorer freigeschaltet.
6. Erst danach darf ein source-gebundener Delta-Ledger-Eintrag P6 von `90` auf `100`
   bewegen. Die Wahrheitstransition umfasst gemeinsam `PROJECT_STATE.md`,
   `apps/frontend/lib/endpoint-snapshot.json`, `apps/frontend/lib/platform.ts` und
   `docs/project-progress.manifest.json`; niemals nur eine Datei.

Bis dahin gilt: `P6=90`, `Overall=89`, `phase6_scale_runtime` bleibt fuer Credit
ungeschlossen, `MARKET_READY:false`, null Hosted Writes durch diesen Entwurf.
