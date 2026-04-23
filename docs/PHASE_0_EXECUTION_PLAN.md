# PHASE 0 EXECUTION PLAN

Stand: 2026-04-23
Bezug: `TEIL 0`, `PHASE 0`, `TEIL 10` aus `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`

## 1. Ziel

Dieser Plan beschreibt die naechste kontrollierte Ausfuehrung fuer den Projektstart. In `PHASE 0` werden ausschliesslich Dokumentations-, Governance- und Vorbereitungsartefakte erstellt. Es werden keine Produktfeatures, keine Deployments und keine lokalen Laufzeitpfade eingefuehrt.

## 2. Arbeitsprinzipien

1. Jede Entscheidung wird gegen `TEIL 0 - PROJECT GOAL LOCK` geprueft.
2. Wir arbeiten dokumentenzentriert, nicht featuregetrieben.
3. Jede neue Festlegung muss budget-, cloud- und security-konform sein.
4. Unklare Punkte werden im `open-questions-log` festgehalten statt still entschieden.
5. Es gibt keine Abschlussmeldung ohne Verifikation.

## 3. Ausfuehrungsreihenfolge

### Welle A - Pflichtartefakte fuer PHASE 0

1. `docs/monorepo-structure.md`
2. `docs/adr/ADR-001-langgraph-orchestrator.md`
3. `docs/adr/ADR-002-litellm-gateway.md`
4. `docs/adr/ADR-003-no-autogen-before-phase-6.md`
5. `docs/adr/ADR-004-mvp-db-strategy.md`
6. `docs/adr/ADR-005-webgpu-webgl-fallback.md`
7. `docs/secrets-strategy.md`
8. `docs/cost-policy.md`
9. `docs/codex-integration/CODEX_AGENT_SKILL_MASTER.md`
10. `docs/codex-integration/CODEX_LOADER_PROMPT.txt`

### Welle B - Fruehe Governance-Artefakte aus TEIL 10

1. `docs/verification-register.md`
2. `docs/assumption-log.md`
3. `docs/open-questions-log.md`
4. `docs/technical-debt-log.md`
5. `docs/adr/README.md`

### Welle C - Danach erst Phase-1-Freigabe vorbereiten

1. Vollstaendigkeitscheck gegen `docs/PHASE_0_AUDIT.md`
2. Definition-of-Done-Check pro Pflichtartefakt
3. Owner-Review-Paket vorbereiten
4. Freigabe fuer `PHASE 1` erst nach expliziter Bestaetigung

## 4. Inhaltliche Leitplanken pro Artefakt

### Monorepo-Struktur

- Muss alle 7 Schichten abdecken.
- Muss Ownership und Schnittstellen auf hoher Ebene benennen.
- Darf keine lokale Ausfuehrung als Default voraussetzen.

### ADRs

- Muessen konkrete Entscheidungen festhalten, nicht nur Optionen sammeln.
- Muessen die verworfenen Alternativen nennen.
- Muessen Kosten-, Sicherheits- und Skalierungsfolgen sichtbar machen.

### Secrets-Strategie

- Jeder Secret-Typ genau ein primaerer Speicherort.
- Keine Demo-Secrets, keine Platzhalterwerte, keine echten Keys.
- Muss Rotation, Zugriff, Logging und Incident-Pfad nennen.

### Kostenrichtlinie

- Muss das harte Infrastruktur-Limit von `20 EUR/Monat` als nicht verhandelbar markieren.
- Muss Modell-Tiers, Token-Limits, Alert-Schwellen und Eskalationen definieren.
- Muss Open-Source-First praktisch operationalisieren.

### Codex-Integration

- Muss den Master Skill im Zielordner bereitstellen.
- Muss einen Loader Prompt enthalten, der Goal Lock, Stop-Gates, Verifikation und Reporting aktiviert.

## 5. Aktive Risiken

1. Artefaktanzahl im Ultimatum ist intern inkonsistent; deshalb wird gegen die explizite Liste statt gegen die Zahl gearbeitet.
2. Ohne fruehe Kostenrichtlinie besteht Over-Engineering-Risiko.
3. Ohne Secrets-Strategie besteht das Risiko, dass spaetere Infrastrukturentscheidungen unsauber werden.
4. Ohne ADRs besteht die Gefahr stiller Architekturwechsel.

## 6. Verifikation pro Welle

### Welle A

- Jeder Zielpfad existiert.
- Jeder Inhalt ist gegen `TEIL 0` gegengeprueft.
- Jede Datei hat einen klaren Zweck und keine Schein-Vollstaendigkeit.

### Welle B

- Jedes Register ist sofort nutzbar und nicht nur ein leerer Platzhalter.
- Offene Punkte, Annahmen und Schulden sind voneinander getrennt.

### Welle C

- `PHASE 0`-Checklist ist komplett gruen.
- Owner-Review kann mit einem einzigen Review-Durchgang erfolgen.

## 7. Nicht im Scope dieser Ausfuehrung

1. Feature-Implementierung
2. Deployments
3. Datenbanken aufsetzen
4. Runtime-Infrastruktur ausrollen
5. Produktive Secrets hinterlegen
6. Lokale Workflows als Standard etablieren

## 8. Naechste konkrete Aktion

Die naechste konkrete Aktion ist der kontrollierte Abschluss von `Welle C`, beginnend mit:

1. Owner-Review-Paket gegen `docs/PHASE_0_AUDIT.md` und `docs/verification-register.md` gegenlesen
2. Offene Fragen in kontrollierte Folgearbeit fuer `PHASE 1` oder ADRs ueberfuehren
3. Explizite `PHASE 0`-Freigabe durch den Owner einholen
