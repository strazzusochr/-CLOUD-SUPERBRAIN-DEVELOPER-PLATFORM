# Mirror Sync Policy

Stand: 2026-04-23
Status: Active
Geltungsbereich: `docs/CODEX_AGENT_SKILL_MASTER.md` und `docs/codex-integration/CODEX_AGENT_SKILL_MASTER.md`

## Zweck

Diese Richtlinie verhindert Governance-Drift zwischen der kanonischen Projektverfassung und dem fuer `PHASE 0` geforderten Integrations-Mirror.

## Kanonische Quelle

1. Die kanonische Inhaltsquelle ist `docs/CODEX_AGENT_SKILL_MASTER.md`.
2. Der Pfad `docs/codex-integration/CODEX_AGENT_SKILL_MASTER.md` ist ein kontrollierter Mirror fuer Integrations- und Nachweiszwecke.
3. `AGENTS.md` und `docs/CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md` bleiben uebergeordnete Repo-Governance-Anker.

## Aenderungsregel

1. Inhaltliche Aenderungen an der Skill-Verfassung werden immer zuerst in `docs/CODEX_AGENT_SKILL_MASTER.md` vorgenommen.
2. Im selben Change-Set wird geprueft, ob `docs/codex-integration/CODEX_AGENT_SKILL_MASTER.md` aktualisiert werden muss.
3. Wenn der Mirror nur Kontrolltext enthaelt, muss mindestens der kanonische Pfad, das Stand-Datum und die Gueltigkeitsregel erneut geprueft werden.
4. Kein Review darf beide Dateien als unveraendert akzeptieren, wenn sich die Projektverfassung inhaltlich geaendert hat.

## Manuelle Verifikation

Vor Abschluss eines Aenderungspakets muessen alle folgenden Punkte positiv beantwortet sein:

1. Ist `docs/CODEX_AGENT_SKILL_MASTER.md` weiterhin die einzige kanonische Inhaltsquelle?
2. Verweist der Mirror korrekt auf die kanonische Quelle?
3. Ist das Stand-Datum in beiden Artefakten konsistent oder bewusst unterschiedlich erklaert?
4. Ist im `verification-register` festgehalten, dass die Mirror-Pruefung erfolgt ist?
5. Wurde verhindert, dass widerspruechliche Regeln nur an einem der beiden Orte stehen?

## Phase-0-Regel

Fuer `PHASE 0` reicht diese manuelle Synchronisationsregel aus, um Drift zu vermeiden. Eine spaetere Automatisierung darf erst eingefuehrt werden, wenn sie:

1. keinen direkten Schreibpfad nach `main` eroefnet,
2. eine nachvollziehbare Diff-Pruefung liefert,
3. innerhalb des Projektbudgets bleibt,
4. und in einem eigenen ADR oder Runbook dokumentiert wird.

## Folgearbeit

Die spaetere Automatisierung des Mirrors bleibt eine offene Verbesserungsaufgabe, blockiert aber `PHASE 0` nicht mehr, solange diese Richtlinie aktiv eingehalten und verifiziert wird.
