# ADR-004 MVP Database Strategy

Status: Accepted for MVP planning
Date: 2026-04-23

## Context

Das MVP braucht schnell verfuegbare persistente Speicherung fuer Sessions, Memory-Metadaten, Nutzerkontext und Integrationszustand. Gleichzeitig gilt ein hartes Infrastruktur-Limit von `20 EUR/Monat`, und spaetere Migration auf eine guenstige, kontrollierbare Betriebsbasis muss moeglich bleiben.

## Decision

Fuer das MVP wird Supabase als Startdatenbank eingeplant. Ab Phase 4 ist eine geplante Migration auf Hetzner-hosted PostgreSQL vorzubereiten, sobald Kosten, Last oder Kontrollanforderungen das rechtfertigen.

## Rationale

1. Supabase beschleunigt MVP-Start und reduziert fruehe Betriebsarbeit.
2. PostgreSQL-Kompatibilitaet erleichtert spaetere Migration.
3. Die Entscheidung balanciert Startgeschwindigkeit gegen spaetere Kostenkontrolle.

## Alternatives Considered

1. Sofort selbst betriebenes PostgreSQL auf Hetzner
Verworfen fuer den MVP, weil Betriebsaufwand, Backup- und Sicherheitsverantwortung frueh zu hoch werden.

2. Reine Dateispeicherung
Verworfen wegen schwacher Querybarkeit, schlechter Mehrbenutzerfaehigkeit und unklarer Memory-Skalierung.

3. Proprietaere Spezialdatenbank ohne PostgreSQL-Migrationspfad
Verworfen wegen Lock-in-Risiko und Budgetunsicherheit.

## Consequences

1. Das Schema muss migrationsfreundlich bleiben.
2. Supabase-spezifische Features duerfen nicht unnoetig tief den Kern koppeln.
3. Phase 4 braucht ein eigenes Migrations-ADR oder einen Migrationsplan.
