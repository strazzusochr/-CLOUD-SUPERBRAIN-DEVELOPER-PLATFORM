# Phase 1.5 Gate Decision Package

Stand: 2026-04-23
Status: Prepared for owner review

## Zweck

Dieses Paket uebersetzt die zwei echten `PHASE 1`-Blocker in kontrollierte Entscheidungswege.
Es trifft keine stille Architekturentscheidung.

## Gate A: Langfuse und Observability-Grenze

### Gesicherte Fakten

1. `TEIL 0` verlangt Observability ab Tag `1`.
2. Die Design-Baseline sagt: Observability ist ein separates System und nicht Teil der Main-App.
3. Das aktuelle `PHASE 1`-Compose-Design fuehrt `langfuse-server` und `langfuse-worker` innerhalb eines festen `8`-Service-Zielbilds.
4. Die offizielle Langfuse-v3-Self-Hosting-Architektur erwartet neben Web und Worker weitere Storage-Abhaengigkeiten wie `Postgres`, `ClickHouse`, `Redis/Valkey` und `S3/Blob`.

### Konflikt

Die feste `8`-Service-Huelle und die Regel "Observability separat vom Main-System" sind mit einer vollstaendig self-hosted Langfuse-v3-Laufzeit im gleichen App-Compose nicht sauber vereinbar.

### Optionen

1. Observability bleibt separat, und Langfuse wird als eigener Stack mit eigener Service-Grenze gefuehrt.
Konsequenz: sauberste Trennung, aber braucht klares ADR und eigenes Betriebsbudget innerhalb des Gesamtlimits.

2. Die `8`-Service-Grenze wird projektweit erweitert, damit Langfuse komplett im Haupt-Compose laufen darf.
Konsequenz: widerspricht der bisherigen Trennung und braucht einen expliziten Architekturwechsel.

3. Langfuse wird fuer die fruehe Implementierung nicht als Runtime-Stack aktiviert, waehrend Metriken, Dashboards und strukturierte Logs zuerst ueber den restlichen OSS-Stack laufen.
Konsequenz: nur als Zwischenzustand fuer interne Aufbauarbeit vertretbar, aber kein sauberer Zielzustand fuer Releases mit voller LLM-Trace-Observability.

### Empfohlene Route

Option `1`.

Begruendung:

- respektiert die Design-Baseline "Observability separat"
- vermeidet stille Aufweichung der `8`-Service-Huelle der Hauptplattform
- schafft einen ehrlichen Platz fuer Langfuse-v3-Abhaengigkeiten
- haelt die Haupt-App-Topologie schlanker und reviewbarer

### Benoetigte Owner-Entscheidung

Owner bestaetigt entweder:

1. separater Observability-Stack fuer Langfuse und Begleitdienste, oder
2. bewusste Aufweichung der bisherigen Systemgrenze per neuem ADR

## Gate B: Datenbank-Aktivierung vor Phase 4

### Gesicherte Fakten

1. `ADR-004` ist akzeptiert und setzt Supabase als MVP-Startdatenbank.
2. `PHASE 1` beschreibt bereits ein selbst gehostetes `Postgres + pgvector`-Zielbild auf Hetzner.
3. Das relationale Schema ist absichtlich PostgreSQL-kompatibel gehalten.
4. Ein frueher stiller Cutover waere Architekturdrift.

### Optionen

1. `ADR-004` bleibt aktiv: Supabase ist die einzige aktive relationale Datenbank fuer MVP und fruehe Implementierung; self-hosted PostgreSQL bleibt Zielbild und Migrationspfad.
2. Hybrider Pfad: Staging auf self-hosted PostgreSQL, waehrend Production oder MVP weiter auf Supabase bleibt.
3. Neuer ADR ersetzt `ADR-004` vorgezogen und aktiviert self-hosted PostgreSQL frueher fuer Staging und Production.

### Bewertung

Option `1` ist die kontrollierteste Route.

- kein Widerspruch zu bestehendem ADR
- kein Environment-Drift zwischen Staging und Production durch Mischbetrieb
- geringere Betriebs- und Backup-Last in der fruehen Implementierung

Option `2` wird nicht empfohlen.

- Staging und Production weichen genau dort auseinander, wo Persistenz am kritischsten ist
- Debugging und Rollback werden unehrlicher

Option `3` ist nur mit neuem ADR und Kosten-/Ops-Nachweis vertretbar.

- kann langfristig sinnvoll sein
- ist aber fuer die naechste Implementierungsstufe ein echter Architekturwechsel

### Empfohlene Route

Option `1`.

Das bedeutet:

- Supabase bleibt bis mindestens nach MVP bzw. bis zum Phase-4-Migrationsfenster die aktive relationale Runtime
- self-hosted PostgreSQL bleibt als portables Zielbild und Design-Artefakt erhalten
- kein frueher Cutover ohne explizite Owner-Freigabe und neuen ADR

## Entscheidungsmatrix

| Gate | Empfohlene Route | Warum | Stop-Gate bis zur Klaerung |
| --- | --- | --- | --- |
| Langfuse / Observability | separater Observability-Stack | ehrlichste Trennung, vermeidet versteckte Service-Ausweitung | keine Compose-Implementierung fuer Langfuse im Hauptstack |
| DB-Aktivierung | `ADR-004` beibehalten | kein Architekturdrift, geringeres MVP-Risiko | kein self-hosted Postgres als aktive Runtime |

## Was nach Zustimmung sofort folgen kann

1. `PHASE 2`-Implementierungsplan in kleine, reviewbare Arbeitspakete aufteilen
2. App-Stack und Observability-Stack sauber getrennt in Infrastruktur-Artefakte ueberfuehren
3. Datenzugriffsschicht explizit auf PostgreSQL-Portabilitaet testen, waehrend Supabase aktiv bleibt

## Was bewusst noch nicht behauptet wird

- dass Langfuse schon lauffaehig eingeplant ist
- dass self-hosted PostgreSQL schon freigegeben ist
- dass `PHASE 2` ohne diese Entscheidungen blockerfrei starten kann
