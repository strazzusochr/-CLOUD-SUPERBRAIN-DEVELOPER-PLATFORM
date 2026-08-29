# Phase-3-Credit-Rubrik — OWNER-ENTWURF

Status: `DRAFT_OWNER_APPROVAL_REQUIRED`
Version: `phase3-credit-rubric-draft-v1`
Erstellt: `2026-08-29`
Zelle: `phase_3`
Aktueller evidenzbasierter Credit: `44`
Offener Hosted-OAuth-Credit: `56`
Summe: `100`
Credit-Anwendung erlaubt: `false`

Dieser Entwurf definiert nur eine entscheidbare Messlatte. Er aendert weder P3 `44` noch
Overall `89`, ein Capability-Gate, `live_verified`, eine Hosted-Konfiguration oder eine
Release-Aussage. Die bereits kreditierte P3-Basis `44` bleibt als historischer Gesamtblock
fest; dieser Entwurf zerlegt oder vergibt sie nicht neu.

## Bewertungsregeln

- Die acht offenen Zeilen sind binaer. Nur eine vollstaendig verifizierte Zeile erhaelt ihre
  Punkte; Teilcredit, Rundung innerhalb einer Zeile und Doppelcredit sind ausgeschlossen.
- Nach einer spaeteren exakten Owner-Freigabe lautet die Rechenregel
  `44 + Summe(vollstaendig verifizierter offener Zeilen)`.
- `DEV-ONLY`, localhost, Quelltextmarker, ein sichtbarer Vertrag, vorhandene Secret-Namen,
  HTTP `200` oder eine leere Identity-Projektion erhalten fuer die offenen Zeilen null Punkte.
- Hosted Evidence muss von einem nicht-lokalen HTTPS-Lauf mit realem Browser, echter GitHub-
  Identity, exakter Candidate-Source, immutablem Deployment-Readback, Audit-Readback und
  secret-redigierten Rohartefakten stammen.
- Ein allgemeines `ja`, ein bestehender Browser-Login oder eine vorhandene Provider-
  Konfiguration ist keine Rubrik-, Deploy-, Consent-, Gate- oder Credit-Freigabe.

## Kriterien

| ID | Kriterium | Punkte | Heutiger Stand |
|---|---|---:|---|
| P3-B00 | Bereits kreditierter historischer Phase-3-Gesamtblock; keine Neuberechnung in diesem Entwurf | 44 | bestehender Manifestwert |
| P3-01 | Hosted OAuth-Start liefert die echte freigegebene `client_id`, exakt Scope `read:user` und einen kryptographischen One-Time-State | 8 | offen |
| P3-02 | Hosted Callback tauscht einen echten Code gegen die verifizierte numerische GitHub-Identitaet und stellt erst danach die Session bereit | 12 | offen |
| P3-03 | Die Owner-Allowlist bindet die numerische GitHub-Identitaet fail-closed; fremde oder fehlende Identity erhaelt keine Credentials | 8 | offen |
| P3-04 | OAuth-State-Cookie: `__Host-`, `Secure`, `HttpOnly`, `SameSite=Lax`, `Path=/`, kein `Domain`; Access-/Refresh-Cookies: `__Host-`, `Secure`, `HttpOnly`, `SameSite=Strict`, `Path=/`, kein `Domain`, freigegebene TTL | 6 | offen |
| P3-05 | Refresh rotiert atomar; Replay des alten Tokens liefert exakt HTTP `401`, widerruft die komplette Tokenfamilie und stellt keine neuen Credentials aus | 8 | offen |
| P3-06 | Logout widerruft nur einen aktiven registrierten Refresh-Token, loescht beide Auth-Cookies, persistiert den korrelierten Audit-Eintrag und Post-Logout-Refresh liefert `401` | 6 | offen |
| P3-07 | Callback-Replay und Wiederverwendung des OAuth-State werden fail-closed abgewiesen | 4 | offen |
| P3-08 | Die Auditkette ist Request-/Session-ID-korreliert, vor Credential-Ausgabe persistiert und enthaelt keine Codes, OAuth-State-Werte, Tokens, Cookie-Werte oder Secrets | 4 | offen |
| **Summe** |  | **100** | **Entwurf; kein neuer Credit** |

Die acht offenen Gewichte ergeben exakt `56` (`8 + 12 + 8 + 6 + 8 + 6 + 4 + 4`).

## Erforderliche Evidence-Kette nach Freigabe

1. Exakte, Owner-freigegebene Rubrik-Commit-SHA und OAuth-Architektur-ADR.
2. Kanonische Browser-/Callback-Origin, OAuth-App, numerische Owner-Allowlist und
   Runtime-Ownership der Variablennamen; Secret-Werte werden nie dokumentiert.
3. Source-gleicher Hosted-Deploy mit immutablem Frontend- und Auth-Runtime-Readback.
4. Reale Browserfolge: erster Start und Cancel/Deny ohne Credentials bei konsumiertem State;
   zweiter Start mit Owner-Authorize; Callback, `/auth/me`, Reload, Refresh, altes
   Refresh-Replay, Callback-Replay, Logout und Post-Logout-Refresh.
5. Getracktes, sauberes Evidence-Envelope, exakt validiert mit
   `pwsh -NoProfile -File scripts/verify-production-auth-identity-evidence.ps1 -EvidencePath <TRACKED_JSON> -ExpectedCandidateSha <40_HEX_SHA> -ValidateOnly`.
   Der heutige Verifier validiert Envelope, Booleans und Source-Bindung; er berechnet keine
   P3-Punkte und recomputiert keine Rohartefakt-Hashes.
6. Ein noch zu implementierender read-only Scorer
   `scripts/verify_phase3_credit_itemization.py`, der jede Rubrikzeile aus den gebundenen
   SHA-256-Rohbeweisen neu berechnet. Gate-Booleans, Envelope-Selbstclaims oder handeditierte
   Summen duerfen nicht genuegen. Globale Pass-Vorbedingungen sind unauthentisiertes
   `/auth/me` exakt `401`, Rollback-Beweis, Branch Protection und Secret Scan.
7. Separater Owner-genehmigter Gate-Promoter; Evidence-Verifikation selbst bleibt
   nicht-mutierend.
8. Erst danach ein source-gebundener Delta-Ledger-Eintrag. Der A1-Replay hat aktuell keinen
   P3-Scorer freigeschaltet und muss jeden P3-Eintrag bis dahin ablehnen.

## Owner-Entscheidungen

Separat und explizit erforderlich sind:

1. Freigabe der exakten Kriterien, Gewichte und Rubrik-Commit-SHA.
2. Wahl des OAuth-Executors und der kanonischen Browser-/Callback-Origin.
3. OAuth-App-/Credential-/Allowlist-Konfiguration ueber den freigegebenen Secret-Kanal.
4. Freigabe eines source-gleichen Preview-/Staging-Deploys ohne Production-Alias.
5. Getrennte Freigabe des realen Live-Consent-/Provider-Laufs. Authorize, Passwort, 2FA und
   CAPTCHA bleiben ausschliesslich Owner-Handlungen.
6. Freigabe des Scorers; Gate-Promotion erst nach PASS des Envelope-Verifiers und des
   kuenftigen Scorers sowie eigener Promoter-Freigabe.
7. Getrennte Wahrheits-/Prozenttransition ueber Delta-Ledger, Manifest und alle Mirrors.

Bis dahin gilt: `P3=44`, `Overall=89`, `production_auth_identity` bleibt ungeschlossen,
`MARKET_READY:false`, keine Production-Promotion und kein Secret-Output.
