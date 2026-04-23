# ADR-002 LiteLLM As LLM Gateway

Status: Accepted for MVP planning
Date: 2026-04-23

## Context

Die Plattform soll `50+` Modelle per API ansprechbar machen, ohne lokale Downloads, mit Kostenkontrolle, Routing und Provider-Flexibilitaet. Direktanbindungen pro Anbieter im App-Code wuerden das System teuer, inkonsistent und schwer kontrollierbar machen.

## Decision

LiteLLM wird als zentrale Gateway-Schicht fuer Modellzugriffe im MVP festgelegt.

## Rationale

1. Einheitliche API reduziert Integrationsaufwand im Backend.
2. Provider-Wechsel und Kostensteuerung lassen sich zentralisieren.
3. Modell-Routing, Limits und Fallbacks koennen an einer Stelle verwaltet werden.
4. Die Entscheidung passt zur Open-Source-First-Strategie besser als rein proprietaere Vermittlerschichten.

## Alternatives Considered

1. Direkte Provider-SDKs im Backend
Verworfen wegen hoher Wartungskosten, uneinheitlicher Fehlerbilder und schwacher Kostenkontrolle.

2. Proprietaerer Aggregator als Kernabhaengigkeit
Verworfen, solange eine OSS-nahe Alternative den MVP abdeckt.

3. Lokale Modell-Inferenz
Verworfen durch harten Goal-Lock: keine lokalen Modell-Downloads.

## Consequences

1. Alle Modellaufrufe muessen ueber die Gateway-Policy laufen.
2. Kosten- und Ratenlimits koennen zentral erzwungen werden.
3. Gateway-Ausfall ist kritisch und braucht spaeter Fallback-Strategien.
4. Provider-spezifische Sonderfaelle duerfen nicht unkontrolliert am Gateway vorbei eingebaut werden.
