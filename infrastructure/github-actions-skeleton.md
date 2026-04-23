# GitHub Actions Skeleton

Stand: 2026-04-23
Status: Phase-1 design only

## Ziel

Dieses Dokument definiert die minimale CI/CD-Struktur fuer das Projekt.
Es beschreibt bewusst Workflows, Umgebungen und Gates, ohne bereits lauffaehige YAML-Dateien als fertig auszugeben.

## Workflow 1: `pr-checks`

Trigger:

- Pull Requests gegen `main`
- optional manuell via `workflow_dispatch`

Pflichtschritte:

1. Repo-Struktur- und Dokument-Checks
2. Linting und statische Pruefungen fuer geaenderte Module
3. Unit-Tests und schnelle Integrationschecks
4. Security-Checks ohne Secret-Leaks
5. Erzeugung eines kurzen PR-Verifikationsartefakts

Muss blockieren bei:

- fehlgeschlagenen Tests
- Secret-Fund
- fehlender Release- oder Observability-Anbindung in betroffenem Feature

## Workflow 2: `main-deploy`

Trigger:

- Merge auf `main`

Reihenfolge:

1. `pr-checks` muss bestanden haben
2. volles Testpaket erneut auf dem Merge-Commit
3. Build-Artefakte erzeugen
4. Deploy nur nach `staging`
5. Smoke- und Health-Checks auf `staging`
6. manuelles Approval-Gate fuer `production`
7. Production-Deploy
8. Health-Checks fuer maximal `5` Minuten beobachten
9. bei Fehlschlag automatischer Rollback auf letztes gesundes Release
10. Release-Checkliste als Git-Artefakt ablegen

Pflichtumgebungen:

- `staging`
- `production`

Pflichtschutz:

- `production` braucht manuelle Freigabe
- kein direkter Agent-Deploy nach `production`
- kein Deploy, wenn Observability-Hooks fehlen

## Workflow 3: `hotfix-deploy`

Trigger:

- `workflow_dispatch`
- optional auf Branch-Namensmuster `hotfix/*`

Pflichtlogik:

1. nur enges Delta erlauben
2. Security- und Smoke-Tests nicht ueberspringen
3. staging-first trotz Hotfix
4. explizites Approval vor `production`
5. Rollback-Pfad identisch zu `main-deploy`

## Release-Checkliste als Git-Artefakt

Jeder Produktionsversuch erzeugt ein Artefakt `release-checklist.json` mit mindestens:

- Commit-SHA
- Workflow-Run-ID
- betroffene Module
- Teststatus
- Staging-URL und Staging-Ergebnis
- Production-Approval-Metadaten
- Rollback-Ziel
- finaler Deploy-Status

## Rollback-Design

- letzter gesunder Release-Tag oder letzter gesunder Deploy-Commit als Rueckfallziel
- Rollback wird durch fehlgeschlagenen Health-Check nach dem Production-Deploy ausgeloest
- Rollback-Ereignis muss in Audit-Log und Release-Artefakt landen
- Rollback muss vor echtem Production-Einsatz mindestens einmal auf `staging` geprobt werden

## Minimale Job-Grenzen

- globale Workflow-Timeouts, damit keine unkontrollierten Loops laufen
- Job-Concurrency pro Environment auf `1`
- Abbruch alter `staging`-Runs bei neuem Commit erlaubt
- `production` darf nie parallel deployen

## Definition of Done fuer dieses Artefakt

Dieses Dokument ist fertig, wenn:

- drei Workflows klar beschrieben sind
- `staging` vor `production` erzwungen wird
- Rollback und Approval nicht implizit bleiben
- die Release-Checkliste als Git-Artefakt definiert ist
