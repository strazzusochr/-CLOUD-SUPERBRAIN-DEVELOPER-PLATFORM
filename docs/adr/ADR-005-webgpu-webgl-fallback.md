# ADR-005 WebGPU With WebGL Fallback

Status: Accepted for MVP planning
Date: 2026-04-23

## Context

Die Plattform soll 3D-Webgame-Rendering unter Cloud-Betrieb ermoeglichen, ohne fruehe GPU-Server und ohne lokale Runtime-Annahmen. Gleichzeitig muss die Browser-Kompatibilitaet hoch genug bleiben, damit der MVP praktisch nutzbar ist.

## Decision

Der 3D-Client wird clientseitig mit WebGPU als bevorzugtem Renderpfad und WebGL als verpflichtendem Fallback geplant.

## Rationale

1. WebGPU gibt Zukunftsfaehigkeit fuer komplexere Renderpfade.
2. WebGL-Fallback erhoeht Reichweite und Robustheit im MVP.
3. Clientseitiges Rendering vermeidet fruehe GPU-Serverkosten und passt zum Budget.

## Alternatives Considered

1. Nur WebGPU
Verworfen, weil Browser- und Geraeteabdeckung fuer den MVP zu riskant ist.

2. Nur WebGL
Verworfen, weil das Projekt explizit WebGPU mit Fallback-Ziel verfolgt.

3. Serverseitiges GPU-Rendering vor Phase 6
Verworfen durch Non-Goals und Budgetgrenze.

## Consequences

1. Frontend-Architektur braucht klaren Capability-Check und Render-Adapter.
2. QA muss beide Renderpfade pruefen.
3. Performance-Claims duerfen nur mit Browser-Evidence gemacht werden.
