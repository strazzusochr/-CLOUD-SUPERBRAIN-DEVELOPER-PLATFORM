# Release Checklist

Stand: 2026-04-23
Status: Draft fuer Phase 0
Bezug: `TEIL 0`, Release-Standard

## 1. Zweck

Diese Checkliste ist die verbindliche Mindestpruefung vor jedem Release. Sie ist als Git-Artefakt zu fuehren und darf nicht still uebersprungen werden.

## 2. Pflichtpunkte vor Release

1. CI/CD-Pipeline fuer den Zielstand ist erfolgreich durchgelaufen.
2. Observability-Anbindung fuer das betroffene Feature oder System ist vorhanden.
3. Smoke-Test ist definiert und erfolgreich.
4. Integration-Test-Plan fuer den Releaseumfang ist dokumentiert.
5. Relevante ADRs und Register sind aktuell oder bewusst unveraendert.
6. Keine offenen Secret-, Auth- oder Produktions-Gates ohne Owner-Freigabe.
7. Rollback-Hinweis ist dokumentiert.
8. Kosten- und Limit-Auswirkung wurde bewertet.
9. Release-relevante offene Fragen sind geklaert oder explizit akzeptiert.

## 3. Mindestformat fuer das Git-Artefakt

| Feld | Inhalt |
| --- | --- |
| `release_id` | eindeutige Build- oder Tag-Referenz |
| `scope` | betroffene Komponenten oder Features |
| `pipeline_status` | Link oder Nachweis des erfolgreichen Laufs |
| `smoke_result` | bestanden / blockiert |
| `observability_check` | vorhanden / fehlt |
| `rollback_note` | kurzer Ruecksetzpfad |
| `review_gate` | bestaetigt / ausstehend |

## 4. Stop-Gates

Ein Release ist blockiert, wenn:

1. die Pipeline rot oder unvollstaendig ist,
2. kein Observability-Nachweis existiert,
3. Smoke-Test oder Integrationsplan fehlen,
4. Main-Merge ohne Human-Review erfolgen soll,
5. Production- oder Secret-Themen nicht freigegeben sind.

## 5. Verifikation

Diese Checkliste gilt fuer Phase 0 als ausreichend, wenn:

1. die Pflichtpunkte den Release-Standard aus `TEIL 0` abdecken,
2. ein Mindestformat fuer das Git-Artefakt definiert ist,
3. Stop-Gates explizit genannt sind.
