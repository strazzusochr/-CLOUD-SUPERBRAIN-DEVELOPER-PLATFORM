# Production OAuth Fixplan - 2026-08-29

Status: `OWNER_ADR_REQUIRED`
Gate: `production_auth_identity`
Betroffene Credits: P3 und P5/I5
Aktueller Gate-Stand: `owner_granted=false`, `live_verified=false`
Secretwerte: nicht Bestandteil dieses Dokuments

## 1. Ergebnis der Analyse

Die Cloud-Konsolen sind vorbereitet, aber der produktive OAuth-Fluss existiert auf der
aktuellen Hosted-Architektur nicht.

Gemessener Hosted-Stand:

- Cloudflare Worker `/api/v1/auth/contract`: HTTP 200, aber nur read-only ueber den
  `CONTRACT_ORIGIN` gespiegelt; `github_oauth_configured=false` und
  `live_github_oauth_call=false`.
- Cloudflare Worker `/api/v1/auth/me`: HTTP 404.
- Vercel Frontend `/api/v1/auth/me`: HTTP 200 mit ehrlicher leerer
  `frontend-projection`, nicht mit einer Identity.
- Der Worker implementiert nativ nur die Service-Session-Routen
  `/api/v1/auth/sessions`, `/verify` und `/revoke`. Diese sind kein Browser-OAuth.
- Die vollstaendige GitHub-OAuth-/JWT-/Refresh-Implementierung liegt aktuell nur in
  `services/agent-api/app/main.py` und erwartet PostgreSQL plus Redis.

Diese FastAPI-Referenz besitzt 38 gruene lokale Auth-Sicherheitstests. Sie erzeugt heute
jedoch keine stabile opaque OAuth-Session-ID in `agent_sessions`; die Auditkette ist
hauptsaechlich trace-basiert. Der Hosted-Beweis benoetigt eine stabile, redigierte
Callback-/Refresh-/Logout-Korrelation.

Die Konsolenbelege - OAuth App, Callback-Konfiguration und gesetzte Secret-Namen - beweisen
weder lauffaehige Routes noch Cookie-, Replay-, Audit- oder Identity-Sicherheit.

## 2. Aktueller Request-Pfad

```text
Browser auf Vercel-Frontend-Origin
  -> /api/v1/auth/* Next.js Route Handler
  -> apps/frontend/lib/frontendBoundary.ts
  -> AGENT_API_BASE_URL
  -> heutiger Cloudflare Worker
  -> native Route, sonst read-only CONTRACT_ORIGIN proxy
```

Mit dem heutigen `AGENT_API_BASE_URL=Worker` ist dieser Pfad defekt: unmatched GET-Auth kann
Worker -> Vercel -> Worker zurueckproxygen, waehrend unmatched POST fuer Refresh/Logout mit
HTTP 405 endet. Der im Worker gespeicherte GitHub-Client-Secretwert wird vom Worker-Code
nicht gelesen. Der heutige Worker-Fallback leitet ausserdem Browser-Cookies nicht weiter und
entfernt `Location` sowie `Set-Cookie`; selbst ohne Rekursion kann er den OAuth-Lifecycle
nicht transportieren.

Die Frontend-Grenze erzwingt fuer den GitHub-Start:

- Zielhost exakt `https://github.com/login/oauth/authorize`,
- Querykeys exakt `client_id`, `redirect_uri`, `scope`, `state`,
- Scope exakt `read:user`,
- State im gebundenen Format,
- `redirect_uri.origin` exakt gleich dem vom Browser sichtbaren Frontend-Origin,
- Callbackpfad exakt `/api/v1/auth/callback`.

Ein GitHub-Callback direkt auf den Worker-Origin widerspricht diesem Vertrag. Ausserdem
wuerden `__Host-`-Cookies am Worker-Origin nicht fuer die Vercel-Frontend-Domain gelten.

## 3. Erforderliche Owner-ADR

Vor Codeaenderungen muss der Owner eine der beiden Architekturen explizit waehlen.

### Option A - Cloudflare-native Auth (empfohlen fuer Zero-card)

- Browseroeffentlicher Callback bleibt am Vercel-Frontend-Origin.
- Frontend proxyt die Callback-Anfrage zum Worker.
- Worker fuehrt GitHub-Code-Austausch, Owner-ID-Pruefung, Token-Issuance und Audit aus.
- D1 speichert State-/Refresh-/Auditdaten.
- Ein dedizierter `AuthCoordinator` Durable Object linearisiert One-Time-State,
  Refresh-Rotation und Replay-Sperre; der vorhandene `RuntimeCoordinator` bleibt getrennt.
- Der Worker antwortet ueber den Frontend-Proxy; die erlaubten `Set-Cookie`-Header werden am
  Frontend-Origin gesetzt.
- Keine neue bezahlte Infrastruktur.

### Option B - Hosted FastAPI + PostgreSQL + Redis

- Bestehende Implementierung in `services/agent-api/app/main.py` wird auf einen vom Owner
  freigegebenen stateful Hosted-Stack gebracht.
- `AGENT_API_BASE_URL` zeigt auf diesen aktuellen Stack.
- PostgreSQL-/Redis-Persistenz, Source-Binding, Budget und Rollback werden separat bewiesen.
- Diese Option ist ohne ausdrueckliche Hosted-Infrastruktur- und Budgetfreigabe blockiert.

Nicht erlaubt ist eine Mischform, bei der der Callback auf den Worker zeigt, die Cookies aber
am Vercel-Origin erwartet werden, oder bei der eine Frontend-Projektion als Identity gilt.

## 4. Oeffentlicher Callbackvertrag

Fuer Option A bleibt der browseroeffentliche Callback:

```text
https://frontend-seven-psi-78.vercel.app/api/v1/auth/callback
```

Die konkrete Production-/Preview-Domain muss bei der Owner-ADR bestaetigt werden. Keine
Wildcard. Der Backend-Origin bleibt separat. Falls der Owner eine neue canonical Frontend-
Domain waehlt, muessen GitHub App, Vercel Environment, Frontend-Origin-Guard und Hosted-
Verifier gemeinsam auf exakt diesen Ursprung umgestellt werden.

Der Callback-Origin darf nicht durch irgendeine syntaktisch gueltige HTTPS-URL ersetzt
werden. Der dedizierte Verifier bindet ihn ausschliesslich an die getrackte, saubere und
SHA-256-gepruefte kanonische Evidence
`docs/runtime-state/frontend-hosted-current.json` mit Contract
`frontend-hosted-current-proof-v1`. Deren Candidate-Source, Deployment-ID, Vercel-Scope
`strazzusochrs-projects`, Projekt-ID `prj_ZbSNRVz5ijLQ4tQR61liHFw1x5eY`, Projektname
`frontend`, immutable Deployment-Origin, Production-Alias, operativer Deploy-Status sowie
Metadata-/Alias-Paritaet muessen exakt passen. Das stateless read-only Backend-Projekt
`cloud-superbrain-developer-platform` oder eine alternative gleichartig aussehende JSON-Datei
kann diese Frontend-Origin-Evidence nicht ersetzen.

Eine wechselnde unique Preview-Origin kann dieselbe Production-Callback-URI nicht als
Same-Origin-Beweis verwenden. Es braucht eine kanonische Staging-Origin oder eine separat
registrierte OAuth App pro wirklich abzunehmender Origin.

Fuer den Gate-Credit `production_auth_identity` gilt strenger: eine Preview-/Staging-Probe
kann die Implementierung vorbereiten, aber nicht den Production-Target-Beweis ersetzen. Der
dedizierte Evidence-Verifier verlangt deshalb fuer diesen Credit `target=production` und den
Production-Alias der kanonischen Frontend-Evidence. Das ist kein stiller Deploy-Grant.

Die Owner-ADR wird nicht aus diesem Fixplan abgeleitet. Sie muss spaeter als getrackte,
saubere und SHA-256-gebundene JSON-Entscheidung unter
`docs/runtime-state/production-auth-architecture-decision.json` vorliegen. Erlaubt sind nur:

- `cloudflare_native` mit Evidence
  `docs/runtime-state/cloudflare-oauth-hosted-current.json` und dem noch zu implementierenden
  read-only Verifier `scripts/verify-cloudflare-oauth-hosted-current.ps1`; oder
- `hosted_fastapi` mit Evidence
  `docs/runtime-state/fastapi-oauth-hosted-current.json` und dem noch zu implementierenden
  read-only Verifier `scripts/verify-fastapi-oauth-hosted-current.ps1`.

Solange die Owner-ADR, die ausgewaehlte Runtime-Evidence und der passende dynamische Verifier
nicht existieren, bleibt die Production-Auth-Evidence absichtlich fail-closed. Freie IDs oder
selbst gesetzte JSON-Booleans koennen I5 nicht oeffnen.

## 5. Zu implementierende Worker-Oberflaeche

Option A benoetigt nativ, nicht nur ueber `CONTRACT_ORIGIN` gespiegelt:

| Methode | Route | Pflichtverhalten |
|---|---|---|
| GET | `/api/v1/auth/contract` | aktuelle Konfiguration ohne Secretwerte, fail-closed Gate-State |
| GET | `/api/v1/auth/github` | One-Time-State erzeugen, Lax State-Cookie, 303 zu GitHub, exakt `read:user` |
| GET | `/api/v1/auth/callback` | State konsumieren, Code tauschen, GitHub-ID pruefen, Audit, Cookies, safe redirect |
| GET | `/api/v1/auth/me` | Access-Cookie pruefen; 200 Identity oder 401 |
| POST | `/api/v1/auth/refresh` | Refresh atomar rotieren; Replay 401 und komplette Tokenfamilie widerrufen |
| POST | `/api/v1/auth/logout` | Refresh widerrufen, Cookies loeschen, Audit persistieren |

Die vorhandenen Service-Session-Routen bleiben getrennt. Ein
`AGENT_API_AUTH_TOKEN` ist kein Browser-Access-/Refresh-Token.

Frontend und bestehende Verifier erwarten derzeit `auth-github-jwt-refresh-v1` mit
Redis-Semantik. Die D1/DO-Portierung benoetigt deshalb eine explizite neue Contract-Version
oder einen nachweislich kompatiblen Adapter; ein stiller Backendtausch ist nicht erlaubt.

## 6. Zu portierende Sicherheitssemantik

Die FastAPI-Implementierung ist die semantische Referenz. Beim Portieren darf nichts still
vereinfacht werden.

Pflicht:

- GitHub-Scope exakt `read:user`;
- numerische Owner-ID-Allowlist;
- kryptografisch zufaelliger, kurzer, einmaliger State;
- State-Cookie `__Host-`, `Secure`, `HttpOnly`, `SameSite=Lax`, `Path=/`;
- Access-/Refresh-Cookies `__Host-`, `Secure`, `HttpOnly`, `SameSite=Strict`, `Path=/`;
- keine Domain-Angabe fuer `__Host-`-Cookies;
- Access- und Refresh-Audience/Issuer/TTL vertraglich gebunden;
- Refresh-Token nur gehasht persistent speichern;
- atomare Rotation und Replay-Sperre ueber Durable Object oder gleichwertige Serialisierung;
- bei Replay alte Tokenfamilie widerrufen;
- State-, Provider-Code-, Access-/Refresh-Token nie in Logs, Antworten oder Evidence;
- Audit muss vor Credential-Issuance erfolgreich persistiert sein;
- D1-/Durable-Object-/Audit-Ausfall stoppt fail-closed ohne Credentials;
- Redirects nur auf `/login` oder `/workbench` desselben Frontend-Origins;
- Rate-Limits fuer Start, Callback, Refresh und Logout;
- stabile, nicht geheime Sessionketten-Korrelation ueber Callback, Refresh und Logout;
- feste Response-Header: `cache-control: no-store`, `referrer-policy: no-referrer`,
  `x-content-type-options: nosniff`;
- CSRF-/Origin-/Fetch-Metadata-Guards fuer POST-Routen;
- kein Direct-Provider- oder MCP-Write ausserhalb des Auth-Vertrags.

## 7. Konfigurationsnamen

Nur Namen, keine Werte:

```text
GITHUB_OAUTH_CLIENT_ID
GITHUB_OAUTH_CLIENT_SECRET
GITHUB_OAUTH_REDIRECT_URI
GITHUB_OAUTH_OWNER_IDS
JWT_SIGNING_SECRET
```

Zusaetzlich verwendet Option A die bereits architekturgebundenen D1-/Durable-Object-
Bindings. Secret-Erzeugung, Rotation oder Ausgabe ist eine Owner-Aktion.

Bereinigter Startskript-Stand: `scripts/start-dev-live.ps1` laedt bereits alle fuenf Namen,
einschliesslich `GITHUB_OAUTH_OWNER_IDS`. Es gibt in diesem Punkt keinen offenen Code-Drift.
Die Templates spiegeln nur diese Variablennamen mit leeren Werten; weder Secret-Erzeugung
noch Secret-Uebernahme ist Bestandteil dieses Fixplans. Die alten Owner-Runbooks vom
2026-07-27 sind `HISTORICAL_DO_NOT_EXECUTE`.

## 8. Red-first Testplan

Vor der Implementierung werden negative Tests committed, die auf dem aktuellen Worker rot
sind.

### Route-/Boundary-Tests

1. `/auth/github` fehlt oder proxyt nur read-only -> rot.
2. `/auth/callback`, `/auth/me`, `/auth/refresh`, `/auth/logout` fehlen -> rot.
3. GitHub `redirect_uri` mit Worker-Origin statt Frontend-Origin -> blockiert.
4. Callback mit unbekanntem Querykey, Fragment, Credentials oder fremdem Origin -> blockiert.
5. Upstream versucht nicht erlaubte Cookies oder Location-Header zu setzen -> blockiert.
6. Reale Vercel-Proxyantwort transportiert mehrere erlaubte `Set-Cookie`-Header korrekt.
7. Worker und Vercel koennen keine Auth-Rekursion erzeugen.
8. Direkter Worker-Aufruf kann Origin-/CSRF-Grenzen nicht umgehen.
9. Frontend-Proxybudget ist laenger als der gesamte Callback-Upstream-Budgetpfad; kein
   Timeout darf nach State-/Token-Mutation einen mehrdeutigen Browserzustand hinterlassen.

### State-/Identity-Tests

1. fehlender, falscher, abgelaufener oder doppelt verwendeter State -> keine Credentials.
2. Cancel/deny -> 401 oder definierter safe redirect, keine Session.
3. Providerantwort ohne numerische ID -> blockiert.
4. GitHub-ID nicht in Owner-Allowlist -> 403, keine Session.
5. Scope-Ausweitung ueber `read:user` -> blockiert.
6. gueltiges `error+state` des Providers -> exakt definierter Cancel-Fehler ohne Credentials.
7. JWT-Signatur, Issuer, Audience, Ablauf und `/me`-Claims -> exakt verifiziert.

### Refresh-/Logout-Tests

1. Refresh rotiert Cookie und persistenten Hash genau einmal.
2. alter Refresh nach Rotation -> 401.
3. paralleler Replay -> maximal ein Erfolg.
4. Audit-Ausfall waehrend Rotation -> kein neues Credential.
5. Logout widerruft und loescht beide Cookies.
6. Refresh nach Logout -> 401.

### Failure-/Leak-Tests

1. D1 nicht gebunden -> 503, keine Cookies.
2. Durable Object nicht gebunden -> 503, keine Cookies.
3. Audit-Persistenz scheitert -> keine Credentials.
4. Provider-Timeout/Fehler -> redigierte Antwort, keine Rohdetails.
5. Logs/Evidence enthalten keine Codes, States oder Tokenwerte.

## 9. Implementierungsreihenfolge

1. Owner-ADR dokumentieren.
2. Callback-Origin-Vertrag festlegen.
3. Red-first Worker- und Frontend-Boundary-Tests committen.
4. D1-Schema und Durable-Object-Zustaende fuer OAuth-State/Refreshfamilie definieren.
5. `/auth/contract` nativ implementieren.
6. Start + Callback implementieren.
7. `/auth/me`, Rotation und Logout implementieren.
8. Audit-before-credential und Redaction-Guards integrieren.
9. Frontend-/Upstream-Timeoutbudgets monoton abstimmen und `start-dev-live.ps1` auf alle
   fuenf Konfigurationsnamen korrigieren.
10. Unit-/Contract-/Frontend-Boundary-Tests gruen fahren.
11. dedizierten nicht-mutierenden Hosted-Verifier und einen getrennten, Owner-genehmigten
    Gate-Promoter implementieren.
12. neuen Candidate-Source-SHA einfrieren; RC21 nicht mutieren.
13. Worker + Vercel Preview/Staging source-gleich deployen - nur nach Owner-Freigabe.
14. Hosted Human-Flow und Replay-Abnahme ausfuehren.
15. Verifier erzeugt source-gebundene Evidence; erst der getrennte Promoter darf nach
    Owner-Freigabe `production_auth_identity.live_verified=true` setzen.
16. P3/I5 Credit ausschliesslich verifierberechnet anwenden.

## 10. Hosted-Abnahme

Der Human-/Browser-Beweis muss source-gebunden und redigiert sein.

| Schritt | Erwartung |
|---|---|
| 1. privat/ohne Session `/login` | keine Identity, keine Projektion als Login-Erfolg |
| 2. GitHub-Start | 303 zu GitHub, Query exakt, Scope `read:user` |
| 3. Cancel | keine Credentials; State konsumiert/entwertet |
| 4. zweiter Start + Authorize | echte numerische GitHub-ID in Allowlist |
| 5. Callback | One-Time-State konsumiert; Audit vor Cookies |
| 6. `/auth/me` | 200 mit verifizierter Owner-Identity |
| 7. Reload | dieselbe gueltige Session |
| 8. Refresh | beide Credentials nach Vertrag rotiert |
| 9. alter Refresh | 401; Replay auditiert |
| 10. Callback-Replay | scheitert; keine neuen Credentials |
| 11. Logout | Widerruf + Cookie-Clear + Audit |
| 12. Refresh nach Logout | 401 |

Zusaetzliche Pflichtbeweise:

- unauthentifiziertes Worker-/Frontend-`/auth/me` ist 401, nicht 404 und nicht Projection-200;
- Frontend und Worker zeigen denselben freigegebenen Source-/Candidate-Stand;
- Audit-Readback korreliert Request-ID, Session-ID-Hash, Event und Ergebnis;
- keine Secret-, Code-, State- oder Tokenwerte im Report;
- Branch Protection und Secret-Scan gruen;
- Rollback auf Last-known-good dokumentiert und getestet.

## 11. Reserved Verifier

Der neue Hosted-Verifier muss mindestens pruefen:

- non-local HTTPS;
- immutable Frontend-/Worker-Deployment-Bindung;
- exakter Callback-Origin auf den Production-Alias des kanonischen Vercel-Projekts
  `frontend`, gebunden an den festen Pfad `docs/runtime-state/frontend-hosted-current.json`,
  dessen getrackte/saubere Bytes und SHA-256;
- exakte Candidate-Source- und Frontend-Deployment-ID-Paritaet der Origin-Evidence;
- den kanonischen Frontend-Verifier im vollstaendigen `-ValidateOnly`-Pfad: zwei
  authentifizierte Vercel-Metadaten-Reads, Alias-/Content-/Endpoint-Paritaet, kein Browser-
  Rerun und kein `verification.json`-Write;
- fail-closed Ablehnung eines Backend-Projekts, einer stale Source, eines fremden Alias oder
  einer veraenderten Origin-Evidence;
- getrackte/gehashte Owner-ADR, architecture-spezifische Runtime-Evidence und den exakt
  allowlisteten read-only Runtime-Verifier;
- alle positiven und negativen Schritte aus Abschnitt 10;
- Cookieattribute und erlaubte Cookie-Namen;
- atomare Rotation/Replay-Sperre;
- persistiertes Audit vor Issuance;
- Redaction/Secret-Safety;
- `live_github_oauth_call=true` nur beim echten Consent-/Providerpfad;
- `production_auth_identity.live_verified` bleibt bis zum finalen Pass false.

Der Verifier darf keinen Secretwert loggen und `live_verified` nie per Hand setzen.

Aktuelle Transition-Blocker sind bewusst hart: `scripts/verify-market-ready.ps1` fuegt
`auth_dedicated_non_mutating_verifier_unavailable` hinzu, und
`scripts/verify_phase5_credit_itemization.py` verlangt fuer den heutigen blockierten I5-Zustand
noch `owner_granted=false` sowie `live_verified=false`. Beide duerfen erst zusammen mit dem
dedizierten Verifier, dem Evidence-Schema und dem getrennten Promoter Red-first geaendert
werden.

## 12. Abbruchbedingungen

Sofort stoppen bei:

- unklarer Owner-ADR,
- fremdem oder wildcard Callback-Origin,
- zusaetzlichem GitHub-Scope,
- Secretwert in Log/Response/Evidence,
- D1-/Durable-Object-/Audit-Ausfall,
- mehr als einem erfolgreichen parallelen Refresh,
- Projection-200 als vermeintlichem Identity-Beweis,
- Source-Drift waehrend der Abnahme,
- erforderlichem bezahlten Plan oder neuer Zahlungsaktion.

## 13. Rollback

- Vor Deploy Last-known-good Worker-Version und Vercel-Deployment-ID notieren.
- Bei Fehler Worker und Preview/Staging auf diese Versionen zuruecksetzen.
- OAuth App/Secret nicht automatisch rotieren oder loeschen.
- Neue D1-Migrationen nur additiv und rueckwaertskompatibel; destructive Migration ist
  separat Owner-gated.
- Nach Rollback negative Auth-Probes und `/api/v1/health` erneut pruefen.

## 14. Non-Claims

- Konsolen-Screenshots oder gesetzte Secret-Namen schliessen das Gate nicht.
- Der aktuelle Worker besitzt keine vollstaendige native Browser-OAuth-Implementierung.
- Die heutige Vercel-Projektion ist keine authentifizierte Identity.
- Dieses Dokument autorisiert keinen Secret-, Env-, Deploy-, DB-, Production- oder
  Permission-Write.
- `production_auth_identity` bleibt blockiert.
