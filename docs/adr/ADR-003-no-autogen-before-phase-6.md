# ADR-003 No AutoGen Before Phase 6

Status: Accepted for MVP planning
Date: 2026-04-23

## Context

Das Projekt will schnell ein kontrollierbares MVP mit Multi-Agent-Squads liefern, ohne frueh zu viele Orchestrierungsparadigmen zu mischen. Zusätzliche Agentenframeworks in der Fruehphase erhoehen Architekturkomplexitaet, Debug-Aufwand und Integrationsrisiko.

## Decision

AutoGen wird vor `PHASE 6` nicht als Kernbestandteil der Plattform eingefuehrt.

## Rationale

1. Das Ultimatum schliesst AutoGen vor Phase 6 explizit aus.
2. Ein Orchestrator reicht fuer den MVP; ein zweites Framework wuerde Entscheidungs- und Debugpfade verwischen.
3. Budget, Teamfokus und Verifikationsaufwand bleiben besser kontrollierbar.

## Alternatives Considered

1. AutoGen parallel zu LangGraph im MVP
Verworfen wegen unnötiger Komplexitaet und Konflikten bei Rollen- und State-Modellen.

2. AutoGen statt LangGraph
Verworfen, weil der Goal-Lock und die definierte ADR-Route zuerst LangGraph priorisieren.

3. Hybrid-Ansatz mit optionalen AutoGen-Experimenten
Verworfen fuer den Produktkern; hoechstens spaeter als klar isolierter Forschungszweig denkbar.

## Consequences

1. MVP-Arbeit fokussiert auf ein klares Orchestrierungsmodell.
2. Experimentelle AutoGen-Pfade duerfen nicht heimlich in Kernmodule einziehen.
3. Jede fruehere Abweichung waere ein expliziter Architekturwechsel und damit stop-gate-pflichtig.
