# Budget and Rate Control Contract

Stand: 2026-04-23
Status: Prepared, not implemented
Phase: `PHASE 2 / WP-01`

## Zweck

Dieser Vertrag definiert den Schutzpfad fuer jeden produktiven LLM-Aufruf.
Er verhindert unkontrollierte Kosten, Provider-Spam, Endlosschleifen und nicht auditierbare Fallbacks.

Dieses Dokument ist kein Build-, Test-, Provider-Call- oder Release-Claim.

## Bindende Quellen

1. `TEIL 0`: hartes Infrastruktur-Limit `20 EUR/Monat`
2. `TEIL 1`: keine Luegen, kein Fake-Done, keine unkontrollierten Loops
3. `TEIL 2`: LLM-Gateway ueber LiteLLM, Rate-Limiting, Cost-Tracking, Fallback-Rotation
4. `docs/cost-policy.md`
5. `docs/provider-rotation-register.md`
6. `docs/limit-history-register.md`
7. `docs/PHASE_1_5_AUTONOMOUS_HANDOFF.md`

## Geltungsbereich

Der Vertrag gilt fuer:

1. Planner-Agent
2. Coder-Agent
3. Tester-Agent
4. DevOps-Agent
5. spaetere 4er-Squad-Erweiterungen
6. alle LLM-Aufrufe ueber das LiteLLM-Gateway

Nicht umfasst:

1. direkte Provider-Calls
2. lokale Modell-Downloads
3. GPU-Server
4. Production-Deployment
5. Secret-Rotation

Diese Punkte sind durch bestehende Stop-Gates gesperrt.

## Pflichtprinzipien

1. Fail closed: Ohne Budget-Konfiguration wird kein produktiver LLM-Call erlaubt.
2. Keine stillen Fallbacks: Jeder Providerwechsel erzeugt ein Event mit Fehlergrund.
3. Keine Endlosschleifen: Jeder Run hat ein globales Maximum von `5` Retry-Cycles.
4. Kein Kostenblindflug: Jeder Request erzeugt vor und nach Ausfuehrung ein Kostenereignis.
5. Kein Cache fuer Sensitive Data: Sensitive Prompts duerfen nicht gecacht werden.
6. Kein Infrastruktur-Overrun: Entscheidungen duerfen das `20 EUR/Monat` Infrastruktur-Limit nicht verletzen.

## Inputs

### `llm.request.proposed`

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `run_id` | string | ja | eindeutiger Run |
| `agent_slot` | enum | ja | `planner`, `coder`, `tester`, `devops` |
| `model_slot` | string | ja | logischer Modellslot, kein Secret |
| `estimated_input_tokens` | integer | ja | Token-Schaetzung vor Call |
| `estimated_output_tokens` | integer | ja | erwartete maximale Antwortlaenge |
| `sensitivity` | enum | ja | `public`, `internal`, `sensitive` |
| `retry_index` | integer | ja | aktueller Retry-Zaehler |
| `cache_key_hash` | string | nein | Hash fuer nicht-sensitive identische Anfragen |

### `budget.snapshot`

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `period` | string | ja | Monatsperiode |
| `configured_limit_eur` | decimal | ja | Owner-konfiguriertes API-Budget |
| `spent_eur` | decimal | ja | bisherige API-Kosten |
| `reserved_eur` | decimal | ja | bereits reservierte Kosten |
| `infra_limit_eur` | decimal | ja | hartes Infrastruktur-Limit, aktuell `20` |
| `alert_threshold_percent` | integer | ja | Standard `80` |

### `rate.snapshot`

| Feld | Typ | Pflicht | Beschreibung |
| --- | --- | --- | --- |
| `agent_slot` | string | ja | Agentenslot |
| `model_slot` | string | ja | Modellslot |
| `requests_in_window` | integer | ja | Requests im aktiven Fenster |
| `tokens_in_window` | integer | ja | Token im aktiven Fenster |
| `window_seconds` | integer | ja | Messfenster |
| `max_requests` | integer | ja | Grenze fuer Requests |
| `max_tokens` | integer | ja | Grenze fuer Tokens |

## Entscheidungen

### `budget.decision`

| Wert | Bedeutung |
| --- | --- |
| `allow` | Call darf ausgefuehrt werden |
| `allow_with_alert` | Call darf ausgefuehrt werden, Alert wird erzeugt |
| `deny_budget_missing` | keine Budgetquelle vorhanden |
| `deny_budget_exceeded` | Limit wuerde ueberschritten |
| `deny_sensitive_cache` | sensitive Anfrage wollte Cache nutzen |

### `rate.decision`

| Wert | Bedeutung |
| --- | --- |
| `allow` | Rate-Limit nicht erreicht |
| `delay` | kontrolliertes Warten innerhalb erlaubter Run-Grenzen |
| `deny_rate_limit` | Rate-Limit erreicht |
| `deny_retry_limit` | globales Retry-Limit erreicht |

## Output-Events

### `cost.reserved`

Wird vor einem erlaubten Call geschrieben.

```json
{
  "event": "cost.reserved",
  "run_id": "run_example",
  "agent_slot": "planner",
  "model_slot": "planner_primary",
  "estimated_cost_eur": 0.01,
  "budget_period": "2026-04",
  "created_at": "2026-04-23T00:00:00Z"
}
```

### `cost.finalized`

Wird nach einem Call oder kontrolliertem Abbruch geschrieben.

```json
{
  "event": "cost.finalized",
  "run_id": "run_example",
  "agent_slot": "planner",
  "model_slot": "planner_primary",
  "actual_cost_eur": 0.008,
  "status": "completed",
  "created_at": "2026-04-23T00:00:10Z"
}
```

### `budget.alert`

Wird ab `80 Prozent` des konfigurierten API-Budgets erzeugt.

```json
{
  "event": "budget.alert",
  "period": "2026-04",
  "threshold_percent": 80,
  "spent_plus_reserved_percent": 81,
  "action": "notify_and_continue_guarded"
}
```

### `rate.rejected`

Wird bei Rate- oder Retry-Abbruch erzeugt.

```json
{
  "event": "rate.rejected",
  "run_id": "run_example",
  "agent_slot": "coder",
  "reason": "deny_retry_limit",
  "retry_index": 5
}
```

## Cache-Regeln

1. Cache-TTL fuer erlaubte identische nicht-sensitive Prompt-Anfragen: `10 Minuten`.
2. Cache-Key wird nur als Hash gespeichert.
3. `sensitive` Anfragen duerfen nicht gecacht werden.
4. Cache-Hit muss als Event sichtbar sein.
5. Cache darf keine Budgetentscheidung ersetzen, sondern nur die erwarteten Zusatzkosten senken.

## Fallback-Regeln

Fallback ist erlaubt, wenn:

1. Primaerprovider fehlgeschlagen ist
2. Fehlergrund klassifiziert wurde
3. Budget erneut geprueft wurde
4. Rate-Limit erneut geprueft wurde
5. Providerwechsel als Event geschrieben wurde

Fallback ist verboten, wenn:

1. Budget fehlt
2. Retry-Limit erreicht ist
3. Anfrage ein Stop-Gate beruehrt
4. Fallback teurer waere und keine Owner-Regel dies erlaubt

## Akzeptanztests

| Test | Erwartung | Status |
| --- | --- | --- |
| fehlende Budget-Konfiguration | `deny_budget_missing` | `planned` |
| Budget nach Reservierung ueber Limit | `deny_budget_exceeded` | `planned` |
| Budget bei `80 Prozent` | `budget.alert` | `planned` |
| Rate-Limit erreicht | `deny_rate_limit` | `planned` |
| Retry `5` erreicht | `deny_retry_limit` | `planned` |
| sensitive Anfrage mit Cache-Key | `deny_sensitive_cache` | `planned` |
| identische nicht-sensitive Anfrage unter TTL | Cache-Hit-Event | `planned` |
| Provider-Fallback | Providerwechsel plus Kostenereignis | `planned` |

## Observability

Alle Events muessen an die separate Observability-Schicht geliefert werden.
Solange `ADR-006` nicht akzeptiert ist, bleibt dies ein Interface- und Testplan, keine Langfuse-Runtime-Aktivierung.

Pflichtfelder fuer Observability:

1. `run_id`
2. `agent_slot`
3. `model_slot`
4. `decision`
5. `cost_estimate`
6. `retry_index`
7. `created_at`
8. `trace_correlation_id`

## Stop-Gates

1. Kein produktiver LLM-Call ohne implementierte Budget- und Rate-Pruefung.
2. Kein Live-Test mit echten Provider-Keys im Repo oder in Logs.
3. Kein Langfuse-Runtime-Claim vor Observability-Gate.
4. Kein Deployment ohne CI/CD- und Release-Checkliste.
5. Kein Budget-Limit-Change ohne Owner-Freigabe.

## Nicht-Behauptungen

Dieses Dokument behauptet nicht:

1. dass LiteLLM bereits konfiguriert ist
2. dass Events persistiert werden
3. dass ein Provider-Call getestet wurde
4. dass ein Budget-Alarm live ausloest
5. dass Phase 2 runtime-ready ist
