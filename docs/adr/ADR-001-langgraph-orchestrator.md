# ADR-001 LangGraph As Main Orchestrator

Status: Accepted for MVP planning
Date: 2026-04-23

## Context

Die Plattform braucht einen orchestrierbaren Multi-Agent-Backbone fuer `4 -> inf` Agenten, kontrollierte Schleifen, Supervisor-Gates, Streaming und zustandsbehaftete Workflows. Die Loesung muss API-first, cloud-tauglich und mit Tool- und Memory-Schichten kombinierbar sein.

## Decision

LangGraph wird als primärer Orchestrator fuer Agentenfluesse und Squad-Ausfuehrung im MVP festgelegt.

## Rationale

1. Graph-basierte Zustandsfluesse passen zu planbaren Review-Gates und Wiederanlaufpunkten.
2. Kontrollierte Iterationen und Supervisor-Unterbrechungen lassen sich sauber modellieren.
3. Die Loesung passt zu API-basierten LLM-Zugaengen und externen Tool-Schichten.
4. Sie ist leichter mit spaeteren Observability- und Memory-Anforderungen zu verbinden als ad-hoc Agentenverkettung.

## Alternatives Considered

1. Reiner Custom-Orchestrator ohne Framework
Verworfen fuer MVP, weil Time-to-Value sinkt und Sicherheits-/Retry-Logik zu viel Eigenbau erzeugt.

2. AutoGen vor Phase 6
Verworfen, weil das Ultimatum AutoGen vor Phase 6 explizit ausschliesst.

3. Einfache lineare Chains
Verworfen, weil sie Supervisor-Gates, Retry-Grenzen und Parallelisierung schlechter abbilden.

## Consequences

1. Workflow-Design wird graphzentriert statt prompt-chaotisch.
2. State-Management braucht klare Knoten- und Uebergangsdefinitionen.
3. Observability muss node- und run-basiert geplant werden.
4. Architekturwechsel weg von LangGraph waere spaeter ADR-pflichtig.
