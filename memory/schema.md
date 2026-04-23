# Memory and Session Schema

Stand: 2026-04-23
Status: Phase-1 design only

## Ziel

Dieses Schema deckt die in `PHASE 1` geforderten Tabellen fuer Projekte, Sessions, Agentenkommunikation, Memory und Kosten ab.

## Architekturregel

- Relationale Quelle der Wahrheit ist ein PostgreSQL-kompatibles Schema.
- Fuer den MVP bleibt `ADR-004` aktiv: Supabase ist die freigegebene Startdatenbank.
- Das gleiche Schema bleibt fuer spaeteres Self-Hosted PostgreSQL auf Hetzner portabel.
- `Qdrant` ist kein Source of Truth, sondern ein Retrieval-Beschleuniger fuer Embeddings und semantische Suche.

## Tabellenuebersicht

### `projects`

Zweck:

- Projekt-Metadaten
- Betriebsstatus
- Budget- und Routing-Kontext

Kernfelder:

| Feld | Typ | Zweck |
| --- | --- | --- |
| `id` | `uuid` | Primaerschluessel |
| `slug` | `text` | stabile Projektkennung |
| `name` | `text` | Anzeigename |
| `status` | `text` | z. B. `active`, `paused`, `archived` |
| `owner_user_id` | `uuid` | Referenz auf kuenftige Auth-Schicht |
| `default_model_profile` | `text` | Routing-Profil |
| `monthly_budget_limit_eur` | `numeric(10,2)` | Budgetgrenze auf Projektebene |
| `created_at` | `timestamptz` | Anlagezeit |
| `updated_at` | `timestamptz` | letzte Aenderung |

Indizes:

- unique auf `slug`
- index auf `status`

### `agent_sessions`

Zweck:

- zusammenhaengende Arbeitslaeufe pro Projekt
- Nachvollziehbarkeit von Squad-, Modell- und Statusdaten

Kernfelder:

| Feld | Typ | Zweck |
| --- | --- | --- |
| `id` | `uuid` | Primaerschluessel |
| `project_id` | `uuid` | FK auf `projects.id` |
| `session_kind` | `text` | z. B. `planning`, `execution`, `review` |
| `squad_size` | `integer` | z. B. `4`, `8`, `12` |
| `requested_by` | `text` | Nutzer- oder Systemausloeser |
| `status` | `text` | `queued`, `running`, `blocked`, `completed`, `failed` |
| `trace_id` | `text` | durchgaengige Korrelations-ID |
| `started_at` | `timestamptz` | Start |
| `ended_at` | `timestamptz` | Ende |
| `created_at` | `timestamptz` | Anlage |

Indizes:

- index auf `project_id, created_at desc`
- index auf `status`
- unique auf `trace_id`

### `agent_messages`

Zweck:

- einzelne Nachrichten, Tool-Aufrufe und Systemereignisse je Session
- Evidence- und Audit-Nachvollziehbarkeit

Kernfelder:

| Feld | Typ | Zweck |
| --- | --- | --- |
| `id` | `uuid` | Primaerschluessel |
| `session_id` | `uuid` | FK auf `agent_sessions.id` |
| `agent_role` | `text` | z. B. `planner`, `coder`, `reviewer` |
| `message_type` | `text` | `user`, `assistant`, `tool`, `system` |
| `sequence_no` | `bigint` | stabile Reihenfolge pro Session |
| `content` | `text` | Nachricht oder verdichteter Inhalt |
| `tool_name` | `text` | optionaler Tool-Name |
| `tool_status` | `text` | `started`, `succeeded`, `failed` |
| `token_input` | `integer` | Input-Tokens |
| `token_output` | `integer` | Output-Tokens |
| `cost_eur` | `numeric(10,4)` | Kostenanteil der Nachricht |
| `created_at` | `timestamptz` | Zeitstempel |

Indizes:

- unique auf `session_id, sequence_no`
- index auf `agent_role`
- index auf `message_type`

### `memory_entries`

Zweck:

- langzeitrelevante Fakten, Entscheidungen und Retrieval-Metadaten
- Bruecke zwischen relationalem Kontext und Vektorindex

Kernfelder:

| Feld | Typ | Zweck |
| --- | --- | --- |
| `id` | `uuid` | Primaerschluessel |
| `project_id` | `uuid` | FK auf `projects.id` |
| `session_id` | `uuid` | optionaler FK auf `agent_sessions.id` |
| `memory_layer` | `text` | `working`, `episodic`, `semantic` |
| `entry_type` | `text` | `decision`, `summary`, `fact`, `artifact`, `risk` |
| `title` | `text` | kurzer Retrieval-Titel |
| `content` | `text` | kanonischer Inhalt |
| `summary` | `text` | kurze Retrieval-Zusammenfassung |
| `embedding_provider` | `text` | Quelle des Embeddings |
| `embedding_model` | `text` | Modellkennung |
| `qdrant_point_id` | `text` | Referenz auf den Qdrant-Punkt |
| `source_uri` | `text` | Pfad oder Referenz zum Ursprungsartefakt |
| `importance_score` | `numeric(5,2)` | Priorisierung |
| `expires_at` | `timestamptz` | optionale Lebensdauer |
| `created_at` | `timestamptz` | Anlage |
| `updated_at` | `timestamptz` | letzte Aenderung |

Indizes:

- index auf `project_id, memory_layer`
- index auf `entry_type`
- index auf `qdrant_point_id`
- optional spaeter `GIN`/`tsvector` fuer Volltext

### `cost_tracking`

Zweck:

- Kosten je Projekt, Session, Modell und Provider nachhalten
- Budget-Grenzen und Alerts ermoeglichen

Kernfelder:

| Feld | Typ | Zweck |
| --- | --- | --- |
| `id` | `uuid` | Primaerschluessel |
| `project_id` | `uuid` | FK auf `projects.id` |
| `session_id` | `uuid` | optionaler FK auf `agent_sessions.id` |
| `provider` | `text` | z. B. `openai`, `anthropic` |
| `model` | `text` | exakte Modellkennung |
| `operation_type` | `text` | `chat`, `embed`, `tool`, `eval` |
| `token_input` | `integer` | Input-Tokens |
| `token_output` | `integer` | Output-Tokens |
| `cost_eur` | `numeric(10,4)` | Kosten |
| `recorded_at` | `timestamptz` | Zeitstempel |

Indizes:

- index auf `project_id, recorded_at desc`
- index auf `session_id`
- index auf `provider, model`

## Beziehungen

- ein `project` hat viele `agent_sessions`
- eine `agent_session` hat viele `agent_messages`
- ein `project` hat viele `memory_entries`
- ein `project` hat viele `cost_tracking`-Eintraege
- `memory_entries` koennen optional auf die erzeugende Session zeigen
- `cost_tracking` kann auf Session-Ebene oder projektweit aggregiert werden

## Retrieval- und Synchronisationsregel

1. Schreiben:
   - kanonischer Eintrag zuerst in PostgreSQL-kompatibler Datenbank
   - danach Embedding erzeugen
   - danach Punkt in Qdrant schreiben
2. Lesen:
   - semantische Kandidaten zuerst aus Qdrant
   - kanonischer Volltext und Metadaten danach aus `memory_entries`
3. Wiederherstellung:
   - Qdrant darf aus `memory_entries` neu aufgebaut werden
   - PostgreSQL-kompatible Datenbank darf nicht aus Qdrant rekonstruiert werden

## Beispielabfragen, die das Schema tragen muss

### Was kostet Projekt `X`?

- Summe aus `cost_tracking.cost_eur` gefiltert nach `project_id`

### Welche Agenten waren an Session `Y` beteiligt?

- distinct `agent_role` aus `agent_messages` gefiltert nach `session_id`

### Welche Memory-Eintraege gehoeren zu Projekt `Z`?

- `memory_entries` gefiltert nach `project_id`, optional sortiert nach `importance_score` und `created_at`

## Retention-Hinweise

- `agent_messages` koennen spaeter in warme und kalte Aufbewahrung getrennt werden
- `memory_entries` bleiben laenger erhalten als Debug-Logs
- `cost_tracking` sollte fuer Budget- und Audit-Zwecke langfristig erhalten bleiben

## Gate-Hinweis

Dieses Schema ist migrationsfreundlich absichtlich PostgreSQL-kompatibel gehalten.
Es loest nicht still den Widerspruch zwischen `ADR-004` und einer fruehen Self-Hosted-Postgres-Aktivierung.

## Definition of Done fuer dieses Artefakt

Dieses Dokument ist fertig, wenn:

- alle `5` Pflichttabellen beschrieben sind
- Projekt-, Session-, Memory- und Kostenbeziehungen klar sind
- Qdrant sauber als Beschleuniger und nicht als Source of Truth markiert ist
