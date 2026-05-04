# LLM Gateway and Model Routing Contract

Stand: 2026-04-28
Status: Runtime policy evaluator implemented locally; live provider activation remains gated
Phase: `PHASE 2 / WP-02`

## Zweck

Dieser Vertrag definiert, wie Agenten LLM-Requests ausschliesslich ueber das LiteLLM-Gateway stellen duerfen.
Er verhindert direkte Provider-Calls, stille Modellwechsel, Budgetdrift und unkontrollierte Fallback-Ketten.

Dieses Dokument ist kein Provider-Setup, kein Secret-Setup, kein Live-Test und kein Release-Claim.

## Bindende Quellen

1. `TEIL 0`: keine lokalen Modell-Downloads, API-Inferenz nur ueber kontrollierte Cloud-Wege
2. `TEIL 1`: keine Architekturdrift, keine unmarkierte Unsicherheit, keine unkontrollierten Loops
3. `TEIL 2`: LiteLLM als LLM-Gateway, Cloudflare AI Gateway nur als Cache-Ergaenzung
4. `docs/cost-policy.md`
5. `docs/provider-rotation-register.md`
6. `docs/runtime-contracts/budget-rate-control.md`
7. `docs/secrets-strategy.md`

## Geltungsbereich

Der Vertrag gilt fuer alle produktiven oder produktionsnahen LLM-Requests von:

1. Planner-Agent
2. Coder-Agent
3. Tester-Agent
4. DevOps-Agent
5. spaetere Squad-Erweiterungen
6. Memory- und Summary-Jobs

Nicht umfasst:

1. lokale Modell-Ausfuehrung
2. direkte Provider-SDK-Aufrufe aus Agent-Code
3. Secret-Rotation
4. Production-Deployment des Gateways
5. Provider-Vertrags- oder Billing-Aenderungen

Diese Punkte bleiben Stop-Gates.

## Pflichtprinzipien

1. Gateway first: Jeder LLM-Request geht ueber LiteLLM.
2. Slot statt Providername: Agenten fordern `model_slot`, nicht konkrete Credentials oder Provider-URLs.
3. Kostenklasse vor Modellname: Jeder Slot hat eine erlaubte Kostenklasse aus der Cost Policy.
4. Fallback ist begrenzt: Pro Request maximal `2` Providerwechsel und insgesamt maximal `5` Retry-Cycles pro Run.
5. Kein Premium als Default: `Tier-P` ist nur fuer Blocker, Architekturfragen oder finale Reviews erlaubt.
6. Kein Secret-Leak: Events duerfen keine API-Keys, Tokens, Raw Provider-Headers oder vollstaendige sensitive Prompts enthalten.
7. Fail closed: Wenn Slot, Budget, Rate oder Providerstatus unklar sind, wird kein Call ausgefuehrt.

## Modellslots

| Slot | Primaere Rolle | Standardklasse | Eskalation | Zweck |
| --- | --- | --- | --- | --- |
| `planner_primary` | Planner | `Tier-S` | `Tier-P` nur bei Architekturblocker | Task-Plan, Intent, Risikoanalyse |
| `coder_primary` | Coder | `Tier-S` | `Tier-P` nur bei festem Blocker | Implementierung und Refactor |
| `tester_primary` | Tester | `Tier-E` | `Tier-S` | Testauswertung, Fehlerklassifikation |
| `devops_primary` | DevOps | `Tier-E` | `Tier-S` | Health-, CI- und Rollback-Bewertung |
| `memory_compactor` | Memory Curator | `Tier-E` | `Tier-S` | Zusammenfassung und Kontextverdichtung |
| `review_gate` | Reviewer | `Tier-S` | `Tier-P` | Review-Gates und kritische Freigaben |

## Providerklassen

Provider werden nicht direkt im Agent-Code verdrahtet.
Die Runtime mappt Slots auf freigegebene Providerklassen:

| Providerklasse | Erlaubte Kostenklasse | Typischer Einsatz | Gate |
| --- | --- | --- | --- |
| `premium_reasoning` | `Tier-P` | harte Architektur- und Review-Fragen | Owner bei Kosten- oder Architekturfolge |
| `standard_coding` | `Tier-S` | Planung, Coding, normale Reviews | Review bei Verhaltenseinfluss |
| `economy_verify` | `Tier-E` | Tests, Monitoring, Memory | Nachweis im Verification-Umfeld |

Konkrete Provider duerfen erst in Umgebungskonfigurationen oder Secret-gebundenen Deployments aufgeloest werden.
Diese Aufloesung ist nicht Teil dieses Vertrags.

## Inputs

### `llm.gateway.request`

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `run_id` | string | ja | eindeutiger Run |
| `agent_slot` | enum | ja | `planner`, `coder`, `tester`, `devops`, `memory`, `reviewer` |
| `model_slot` | string | ja | logischer Modellslot |
| `task_class` | enum | ja | `plan`, `code`, `test`, `review`, `memory`, `ops` |
| `sensitivity` | enum | ja | `public`, `internal`, `sensitive` |
| `max_output_tokens` | integer | ja | durch Cost Policy begrenzt |
| `retry_index` | integer | ja | aktueller Retry-Zaehler |
| `fallback_index` | integer | ja | aktueller Providerwechsel-Zaehler |
| `trace_correlation_id` | string | ja | Verbindung zu Observability-Events |

### `llm.gateway.policy_snapshot`

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `allowed_cost_tier` | enum | ja | `Tier-E`, `Tier-S`, `Tier-P` |
| `slot_enabled` | boolean | ja | Slot ist freigegeben |
| `provider_class` | string | ja | abstrakte Providerklasse |
| `fallback_allowed` | boolean | ja | Fallback fuer Slot erlaubt |
| `max_fallbacks` | integer | ja | Standard `2` |
| `max_retry_cycles` | integer | ja | global `5` |
| `cache_allowed` | boolean | ja | nur fuer nicht-sensitive Requests |

## Entscheidungen

### `llm.gateway.decision`

| Wert | Bedeutung |
| --- | --- |
| `allow_primary` | Primaerroute ist erlaubt |
| `allow_fallback` | Fallbackroute ist erlaubt und dokumentiert |
| `deny_slot_disabled` | Modellslot ist nicht freigegeben |
| `deny_budget_or_rate` | Budget- oder Rate-Vertrag blockiert |
| `deny_cost_tier` | angeforderte Kostenklasse ist nicht erlaubt |
| `deny_fallback_limit` | Fallback-Limit erreicht |
| `deny_retry_limit` | Retry-Limit erreicht |
| `deny_sensitive_cache` | sensitive Anfrage wollte Cache nutzen |
| `deny_direct_provider` | Request versucht Gateway zu umgehen |

## Output-Events

### `llm.route.selected`

```json
{
  "event": "llm.route.selected",
  "run_id": "run_example",
  "agent_slot": "planner",
  "model_slot": "planner_primary",
  "provider_class": "standard_coding",
  "cost_tier": "Tier-S",
  "decision": "allow_primary",
  "created_at": "2026-04-23T00:00:00Z"
}
```

### `llm.route.fallback`

```json
{
  "event": "llm.route.fallback",
  "run_id": "run_example",
  "agent_slot": "coder",
  "model_slot": "coder_primary",
  "from_provider_class": "standard_coding",
  "to_provider_class": "standard_coding",
  "reason": "rate_limit",
  "fallback_index": 1,
  "created_at": "2026-04-23T00:00:08Z"
}
```

### `llm.route.rejected`

```json
{
  "event": "llm.route.rejected",
  "run_id": "run_example",
  "agent_slot": "tester",
  "model_slot": "tester_primary",
  "decision": "deny_budget_or_rate",
  "reason": "budget_contract_denied",
  "created_at": "2026-04-23T00:00:09Z"
}
```

## Routing-Regeln

1. `planner_primary` darf nicht automatisch auf `Tier-P` eskalieren.
2. `coder_primary` darf `Tier-P` nur nutzen, wenn ein dokumentierter Blocker existiert.
3. `tester_primary`, `devops_primary` und `memory_compactor` starten in `Tier-E`.
4. `review_gate` darf `Tier-P` nur bei echten Review-Gates nutzen.
5. Fallback innerhalb derselben Kostenklasse ist bevorzugt.
6. Fallback in eine hoehere Kostenklasse braucht dokumentierten Grund und Budgetfreigabe.
7. Jeder Fallback muss `budget-rate-control.md` erneut durchlaufen.
8. Direkte Provider-URLs oder Provider-Keys in Agent-Requests sind ein harter Reject.

## Akzeptanztests

| Test | Erwartung | Status |
| --- | --- | --- |
| direkter Provider-Call | `deny_direct_provider` | `verified-runtime-and-hosted` |
| deaktivierter Modellslot | `deny_slot_disabled` | `verified-runtime-and-hosted` |
| Planner fordert Premium ohne Blocker | `deny_cost_tier` | `verified-runtime-and-hosted` |
| Tester nutzt Economy-Slot | `allow_primary` | `verified-runtime-and-hosted` |
| Fallback nach Rate-Limit | `allow_fallback` plus Event | `verified-runtime-and-hosted` |
| dritter Fallback | `deny_fallback_limit` | `verified-runtime-and-hosted` |
| Retry `5` erreicht | `deny_retry_limit` | `verified-runtime-and-hosted` |
| Budget-Vertrag blockiert | `deny_budget_or_rate` | `verified-runtime-and-hosted` |
| sensitive Anfrage mit Cache | `deny_sensitive_cache` | `verified-runtime-and-hosted` |

## Observability

Jede Routing-Entscheidung erzeugt ein Event fuer die separate Observability-Schicht.
Solange `ADR-006` nicht akzeptiert ist, bleibt dies ein Interface- und Testplan, keine Langfuse-Runtime-Aktivierung.

Pflichtfelder:

1. `run_id`
2. `agent_slot`
3. `model_slot`
4. `provider_class`
5. `cost_tier`
6. `decision`
7. `fallback_index`
8. `retry_index`
9. `trace_correlation_id`
10. `created_at`

## Stop-Gates

1. Kein produktiver LLM-Call ohne Gateway-Route.
2. Kein direkter Provider-SDK-Pfad in Agenten.
3. Kein Premium-Default fuer alle Agenten.
4. Keine echte Provider-Konfiguration ohne Secret-Strategie und Budgetvertrag.
5. Kein Deployment des Gateways ohne CI/CD- und Observability-Nachweis.

## Nicht-Behauptungen

Dieses Dokument behauptet nicht:

1. dass LiteLLM bereits deployed ist
2. dass Provider-Credentials vorhanden sind
3. dass ein Modell live erreichbar ist
4. dass Fallbacks getestet wurden
5. dass Phase 2 runtime-ready ist
