# Provider Rotation Register

Stand: 2026-04-23
Status: Draft fuer Phase 0
Bezug: `docs/cost-policy.md`, `docs/secrets-strategy.md`

## 1. Zweck

Dieses Register dokumentiert, welche Providerklassen im System vorgesehen sind, unter welchen Bedingungen rotiert werden darf und wo die Governance-Grenzen liegen.

## 2. Register

| Bereich | Primaer | Fallback | Rotations-Trigger | Gate |
| --- | --- | --- | --- | --- |
| Premium Reasoning | genehmigter `Tier-P` Provider | kein automatischer Fallback ohne Kostencheck | Qualitaets- oder Verfuegbarkeitsproblem | Owner bei Kosten- oder Architekturfolge |
| Standard Coding | genehmigter `Tier-S` Provider | zweiter `Tier-S` oder `Tier-E` bei degradierter Qualitaet | Rate-Limit, Ausfall, unzulaessige Latenz | Review bei Verhaltenseinfluss |
| Economy Verify | genehmigter `Tier-E` Provider | zweiter guenstiger Verify-Provider | Kosten- oder Verfuegbarkeitsproblem | kein Main-Gate, aber Nachweis im Register |
| Vector / Memory Provider | MVP-Backend gemaess Architekturentscheidung | alternatives Backend erst mit Migrationsplan | Kosten, Datenhaltungs- oder Zuverlaessigkeitsproblem | ADR / Security-Review |
| Tooling / Browser Provider | definierter MCP-Pfad | alternative kontrollierte Ausfuehrung | Instabilitaet oder fehlende Evidence | Runtime-Review |

## 3. Regeln

1. Kein stiller Providerwechsel mit Auswirkungen auf Kosten, Datenhaltung oder Ergebnisverhalten.
2. Secret- und Konfigurationswechsel folgen der Secrets-Strategie.
3. Jede echte Rotation erzeugt einen Eintrag im Limit-History- oder Verification-Umfeld.

## 4. Verifikation

Dieses Register gilt fuer Phase 0 als ausreichend, wenn:

1. die wesentlichen Providerklassen sichtbar sind,
2. Rotations-Trigger benannt sind,
3. Architektur- und Sicherheitsgates klar bleiben.
