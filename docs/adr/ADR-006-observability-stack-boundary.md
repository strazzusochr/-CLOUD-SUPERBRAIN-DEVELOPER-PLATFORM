# ADR-006 Observability Stack Boundary

Status: proposed
Date: 2026-04-23

## Context

Das Projekt fordert Observability ab Tag `1`, gleichzeitig aber auch eine klare Trennung: Observability ist ein separates System und nicht Teil der Main-App.

Das `PHASE 1`-Design fuehrt derzeit `langfuse-server` und `langfuse-worker` innerhalb einer festen `8`-Service-Huelle des App-Stacks. Die offizielle Langfuse-v3-Self-Hosting-Architektur erwartet jedoch zusaetzliche Storage-Abhaengigkeiten wie `ClickHouse`, `Redis/Valkey`, `Postgres` und `S3/Blob`.

Ohne neue Entscheidung fuehrt das zu einem von zwei schlechten Zustaenden:

1. unehrlicher Runtime-Claim trotz fehlender Backing-Services
2. stiller Architekturdrift durch versteckte Service-Ausweitung im Hauptstack

## Decision

Wenn dieser ADR akzeptiert wird, wird Observability fuer MVP und fruehe Implementierungsphasen als eigener Stack behandelt.

Das bedeutet:

1. Die Hauptplattform behaelt ihre eigene Service-Grenze und wird nicht still fuer Observability aufgeweicht.
2. Langfuse und seine benoetigten Begleitdienste werden ausserhalb des Main-App-Stacks geplant und betrieben.
3. Die Hauptplattform liefert Traces, Metriken und Logs ueber definierte Schnittstellen an den Observability-Stack.
4. Budget- und Security-Gates gelten weiterhin fuer beide Stacks zusammen.

## Rationale

1. Die Trennung folgt der bestehenden Design-Baseline statt sie zu unterlaufen.
2. Langfuse-v3 bekommt damit einen ehrlichen Platz fuer seine reale Architektur.
3. Die Hauptplattform bleibt kleiner, reviewbarer und leichter zu haerten.
4. Observability kann separat skaliert, abgesichert und spaeter ersetzt werden, ohne die Kernplattform still umzubauen.

## Alternatives Considered

1. Langfuse innerhalb der `8`-Service-Huelle des Hauptstacks erzwingen
Verworfen, weil die Langfuse-v3-Abhaengigkeiten sonst kaschiert oder unvollstaendig betrieben wuerden.

2. Die gesamte Hauptplattform-Huelle sofort erweitern
Vorlaeufig verworfen, weil dies ein groesserer Architekturwechsel waere und die bisherige Trennungsregel aufweicht.

3. Langfuse komplett verschieben und nur Basis-Metriken behalten
Nur als temporaerer Zwischenzustand fuer interne Aufbauarbeit denkbar, aber nicht als sauberes Zielbild fuer Release-nahe Phasen.

## Consequences

1. `PHASE 2` braucht getrennte Infrastruktur-Artefakte fuer App-Stack und Observability-Stack.
2. Das Budget muss fuer beide Stacks gemeinsam nachgewiesen werden.
3. Die aktuelle `PHASE 1`-Compose-Dokumentation muss nach Annahme dieses ADR an die neue Stack-Grenze angepasst werden.
4. Ohne Annahme dieses ADR bleibt Langfuse ein offenes Architektur-Gate.
