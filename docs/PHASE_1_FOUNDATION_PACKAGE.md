# Phase 1 Foundation Package

Stand: 2026-04-23
Status: Prepared for review

## Zweck

Dieses Paket buendelt die vollstaendige Design-Arbeit fuer `PHASE 1`.
Es ist kein Implementierungs- oder Release-Claim.

## Enthaltene Artefakte

- `infrastructure/hetzner-server-setup.md`
- `infrastructure/docker-compose.design.md`
- `infrastructure/github-actions-skeleton.md`
- `infrastructure/staging-environment.md`
- `memory/schema.md`
- `observability/strategy.md`

## Was Phase 1 hier leistet

1. Hetzner-Basis fuer `production` und `staging` ist definiert
2. die `8`-Service-Compose-Topologie ist benannt, versioniert und mit Health-Checks und Limits beschrieben
3. CI/CD-Gates fuer PR, Main-Deploy und Hotfix sind definiert
4. das relationale Memory- und Cost-Schema ist beschrieben
5. die Observability-Strategie mit Traces, Metriken, Alerts und Retention ist festgelegt
6. Staging ist als Pflicht-Gate fest verdrahtet

## Was bewusst nicht behauptet wird

- dass bereits ein lauffaehiges `docker-compose.yml` existiert
- dass GitHub Actions bereits implementiert sind
- dass Langfuse in der aktuellen `8`-Service-Grenze schon nachweislich lauffaehig ist
- dass ein Self-Hosted-Postgres-Cutover fuer den MVP schon freigegeben ist

## Definition of Done Check

| Kriterium | Ergebnis | Hinweis |
| --- | --- | --- |
| Server-Baseline dokumentiert | yes | Hetzner-Setup und Portregeln vorhanden |
| Compose-Design fuer `8` Services dokumentiert | yes | inklusive Limits und Health Checks |
| keine `latest`-Tags im Zielbild | yes | alle Services explizit benannt |
| CI/CD-Skelett mit Rollback und Approval beschrieben | yes | `staging` vor `production` erzwungen |
| Schema fuer `5` Tabellen dokumentiert | yes | inklusive Beziehungen und Query-Zielen |
| Observability von Tag `1` definiert | yes | Toolchain, Alerts und Retention festgelegt |
| Staging als Pflichtumgebung dokumentiert | yes | eigenes Dokument vorhanden |
| Langfuse-Backing-Modell final geklaert | no | echtes Gate offen |
| MVP-DB-Aktivierung zwischen Supabase und Self-Hosted Postgres final geklaert | no | echtes Gate offen |

## Echte Stop-Gates nach Phase 1

1. Kein Compose-Implementierungsclaim vor Klaerung der Langfuse-Backing-Services
2. Kein stiller Wechsel von `ADR-004` auf Self-Hosted PostgreSQL ohne Owner-Gate oder neues ADR
3. Kein Deployment ohne reale Workflows, Tests und Staging-Rollback-Nachweis
4. Kein Production-Schritt ohne Human-Review

## Verifikationslage

Geprueft in dieser Phase:

- Artefakte erstellt
- Struktur gegen North Star und `TEIL 1` abgeglichen
- offene Konflikte explizit markiert
- keine lokalen Laufzeitannahmen eingefuehrt

Noch nicht verifiziert:

- lauffaehige Infrastruktur
- echte Workflow-Ausfuehrung
- reale Health-Check- und Rollback-Proben

## Naechster kontrollierter Schritt

Der naechste sinnvolle Schritt ist `PHASE 1.5` als gezielte Klaerung der zwei offenen Architektur-Gates:

1. Langfuse innerhalb oder ausserhalb des `8`-Service-Rahmens
2. Aktivierungsstrategie fuer PostgreSQL-kompatible Persistenz in MVP und Staging

Erst danach sollte `PHASE 2` mit echten Implementierungsartefakten starten.
