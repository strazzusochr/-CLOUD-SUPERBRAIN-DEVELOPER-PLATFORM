> **UEBERHOLT — NICHT ALS ZIEL- ODER UEBERGABEDATEI VERWENDEN.**
> Massgeblich sind ausschliesslich `CODEX_ZIEL_MASTER_2026-08-29.md` (was zu tun ist) und
> `CODEX_UEBERGABE_MASTER_2026-08-29.md` (was los ist). Diese Datei bleibt nur als
> historische Provenienz erhalten; ihre Koordinaten, Prozentwerte und Anweisungen sind
> nicht mehr gueltig. Stand der Markierung: 2026-08-30.

# CLOUD SUPERBRAIN - UEBERGABE 2026-08-29, SESSION 16

Status: `CURRENT_HANDOFF`
Messfenster: 2026-08-29
Projekt: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
Branch: `codex/organism-visual-v2`

Diese Uebergabe ersetzt keine immutable RC21-Evidenz. Sie beschreibt den aktuellen
Entwicklungsstand nach RC21, die danach ausgefuehrten lokalen Beweise, den realen Hosted-Drift
und den noch Owner-gesteuerten Weg zu `MARKET_READY:true`.

## 1. Kurzfassung

- RC21 ist lokal qualifiziert und immutable gebunden.
- Der Follow-up-CI-Lauf auf `e98f68a6` ist vollstaendig gruen: `25/25`, `0 skipped`.
- Build, Runtime, DEV-LIVE und der komplette lokale Browserlauf sind auf lokalem HEAD
  `740bafe9` gruen. Der Browserlauf umfasst echte Cloudflare-Workers-AI-Ausfuehrung,
  `22/22` Routen, `29/29` Aktionsfamilien, `161/161` sichtbare UI-Effekte und O4.
- `npm run verify` ist nicht vollstaendig gruen. Der letzte reale Lauf endet fail-closed bei
  `current Cloudflare-native hosted Worker source parity`.
- Ursache: der Hosted Worker meldet noch Source `d0674bfc`, waehrend der aktuelle Tree in
  `services/cloudflare-stateful-runtime` die spaeteren Runnability-Fixes `0cf451d0` und
  `bbc2ad48` enthaelt.
- Hosted Vercel/Worker liefern weiterhin den alten Fortschritt `84`, das Repo `89`.
- Produktions-OAuth ist nicht implementiert/belegt: Konsoleneintraege und Secrets sind nur
  Vorbereitung. Der aktuelle Worker besitzt die benoetigten Auth-Routen nicht.
- Overall bleibt `89`; `MARKET_READY:false`; kein Production- oder Release-Claim.

## 2. Aktuelle Koordinaten

| Feld | Gemessener Stand |
|---|---|
| Lokaler HEAD vor diesem Dokumentensatz | `740bafe92314b36f047a07443567df403ea5a45d` |
| Remote-Branch vor diesem Dokumentensatz | `e98f68a6e5ce8544f8504f38a57c0e17672fe253` |
| Aktiver Kandidat | `prod-candidate-2026-08-28-local-rc21` |
| RC21 Source | `c1b022a884eb16939fe0542b2eb9056b60706b20` |
| RC21 Control | `9f2ee3838492079bd5c65b53a03cd4b29c9a6c49` |
| RC21 Qualifikations-CI | `33217980790` |
| RC21 Rollback | RC20 Source `c29c738b82e4e35cc1288bc603319cba60d167d2` |
| P5 Readiness | `17/19 = 89%`; blockiert: `I1`, `I5` |
| Letzter vollstaendiger Follow-up-CI | `33223542872`, Head `e98f68a6`, `25/25`, `0 skipped` |

Der lokale HEAD ist kein neuer Kandidat. RC21-Evidenz darf nicht nachtraeglich umgeschrieben
werden. Jede weitere Aenderung an `RUNTIME_SOURCE_PATHS`, insbesondere die geplante
Hosted-OAuth-Umsetzung, benoetigt einen neuen Source-Freeze und einen neuen Kandidaten.

## 3. Fortschritt

### Horizontal

| Phase | Prozent | Status |
|---|---:|---|
| P0 Reboot & Goal Lock | 100 | verified |
| P1 Foundation Runtime | 100 | completed |
| P2 Core Runtime | 100 | verified |
| P3 Product Surface & Security | 44 | production OAuth offen |
| P4 Integration & Hardening | 100 | verified |
| P5 Release Readiness | 89 | I1 und I5 offen |
| P6 Scale & 3D Platform | 90 | 900-Request-Scale-Beweis offen |

### Vertikal

| Layer | Prozent | Status |
|---|---:|---|
| L1 Frontend | 100 | verified |
| L2 Orchestrator | 100 | verified |
| L3 Agent Pool | 100 | verified |
| L4 LLM Gateway | 55 | Rubrik und Hosted-Abschlussbeweise offen |
| L5 MCP Gateway | 56 | Rubrik, Hosted-MCP und Registry-Beweise offen |
| L6 Memory | 100 | verified |
| L7 Observability | 100 | verified |

Overall: `89%`. Die Matrizen sind unterschiedliche Achsen; ihre Restpunkte duerfen weder
addiert noch doppelt kreditiert werden.

## 4. RC21-Wahrheit

RC21 besitzt die fuenf unabhaengigen lokalen Qualifikationsketten:

1. sechs Images aus dem committed Git-Archiv,
2. Runtime,
3. Real-Chromium-Browser,
4. Candidate-Runtime-Identitaet mit echter Auswahl und Klick,
5. Candidate-Archiv-Security mit npm-audit und gitleaks.

Der gebundene Evidenzsatz enthaelt 27 Dateien. `npm run verify:phase5-credit` meldet
`verified 17/19`, blockiert nur `I1 hosted_candidate_parity` und
`I5 production_auth_identity`. `npm run verify:current-release-candidate` meldet
`candidate_technical=true`, `runtime_source_parity=true`, `promotion_eligible=false` und
kanonisch `blocked`. Das ist der korrekte Nicht-Produktionszustand.

Die kanonische Readiness-JSON ist korrekt. Die begleitende immutable Narrative
`docs/release-artifacts/prod-candidate-2026-08-28-local-rc21.md` enthaelt dagegen noch
mehrere RC20-/RC19-Bezeichnungen. Dieser Copy-Drift wird hier offengelegt, aber nicht durch
eine nachtraegliche Mutation der RC21-Evidenz kaschiert.

## 5. Delta nach RC21

| Commit | Inhalt |
|---|---|
| `6b33d945` | RC21 Source-Paritaet nach einem unzulaessigen Solo-Update von `PROJECT_STATE.md` wiederhergestellt |
| `428d5a87` | Runtime-Verifier akzeptiert nur den aktiven Live-Provider |
| `e5854a42` | Phase-5-CI auf einen always-running Mode-Router umgestellt |
| `e98f68a6` | nicht kreditierender L4/L5-Rubrikentwurf |
| `740bafe9` | RC21-, Restlisten- und Konsolenwahrheit dokumentiert |

Der uncommittete Patch in `scripts/verify-phase1.ps1` ersetzt eine veraltete Annahme
(`bei Branch Protection darf nur GHCR fehlen`) durch die exakte, aus den Claim-Flags
abgeleitete Missing-Gate-Menge. Mit diesem Patch lief `npm run verify` ueber die vorherige
External-Gate-Stelle hinaus und stoppte spaeter an der echten Hosted-Worker-Paritaet. Der
Patch ist deshalb plausibel, bleibt aber bis zur vereinbarten vollstaendig gruenen Kette
uncommittet.

## 6. Verifikation nach RC21

### Gruen

| Pruefung | Ergebnis |
|---|---|
| `npm run build` | PASS, Next.js `21/21` Seiten |
| `npm run verify:runtime` | PASS, kompletter Runtime-Umbrella |
| `scripts/start-dev-live.ps1` | PASS, `10/10 healthy` |
| `npm run verify:browser` | PASS, komplette serielle Browser-/Produkt-/O4-Kette |
| `npm run verify:phase5-credit` | PASS, `17/19`, I1/I5 blockiert |
| `npm run verify:current-release-candidate` | PASS, technisch verifiziert, Promotion korrekt blockiert |
| GitHub Actions `33223542872` | PASS, ein Job, `25/25` Steps, `0 skipped` |

Lokaler Produktbeweis:

- Vertrag `product-acceptance-3d-game-v1`
- Build `dd3ff05e-7f6f-4902-9977-86a22f57af23`
- `gateway_mode=cloudflare_workers_ai_live`
- `live_provider_calls=true`, `direct_provider_calls=false`
- WebGL, Tastaturwirkung, Persistenz und Reload-Paritaet verifiziert
- Report `.codex/runs/CURRENT/product-acceptance/report.json`
- SHA-256 `0CBC1DDE789FD0170444DDCCC108B215392374EB87A31C01D60E2D5F125905FD`

Lokaler 22-Seiten-Aktionsbeweis:

- `22/22` registrierte/erreichte Routen
- `29/29` aktivierte Familien
- `161/161` aktivierte Aktionen
- `160` direkte Effekte plus genau ein gebundener P0-Beweis
- zwei erlaubte echte Provider-Buildantworten
- `0` unerwartete Konsolen- oder Page-Errors
- Report `.codex/runs/CURRENT/22-page-actions/report.json`
- SHA-256 `A21B5E329ABA48EC6B9D4D9916841A5C918D74676588CC024DB1CC2F77B3D6C6`

Responsive-Beweis:

- Vertrag `frontend-22-page-responsive-browser-v1`
- `22 x 2 = 44` Desktop-/Mobile-Pruefungen
- Overflow-, Overlay- und Console-Fehlerzaehler jeweils `0`
- Report `.codex/runs/CURRENT/frontend/responsive-22/report.json`
- SHA-256 `723D2DEF1E3B98C25885E2F6242342EB02D2238CAC46D510A5F7E103AEED8E5B`

O4:

- `live_agent_tool_writes=true`, `live_mcp_writes=true`
- Audit before/after/readback und Audit-Failure-Rollback verifiziert
- kein Main-, Force-, Provider-, Production- oder Secret-Write
- `.phase1-artifacts/o4-live-writes/proof.json`
- SHA-256 `8307EDB2783BC05A9849F0A85235162E802C34F656091759AA2AC10F74B4E1D0`

Diese Fresh-Proofs sind Worktree-/DEV-Laufbeweise, keine neue immutable Kandidatenkette:
`product-acceptance` und `22-page-actions` enthalten keinen `source_commit_sha`; der
Aktionsreport und O4 binden den damaligen Git-HEAD `740bafe9`. Sie duerfen daher weder als
RC21-Source-Evidenz noch als Hosted-I1-Credit wiederverwendet werden. Alle neuen
Laufzeitbeweise sind `DEV-ONLY; hosted proof still blocked`.

### Letzter roter Vollverifier

`npm run verify` endete mit Exit `1` bei:

```text
Verification failed: current Cloudflare-native hosted Worker source parity
```

Der Guard vergleicht den in `docs/runtime-state/cloudflare-native-hosted-current.json`
gebundenen Source-Commit `d0674bfc1367b04d95ca2bf745e89fabf12046ad` mit dem aktuellen
Tree von `services/cloudflare-stateful-runtime`. Seit diesem Hosted-Source-Stand kamen dort
hinzu:

- `0cf451d0 fix(build): reject unrunnable generated html`
- `bbc2ad48 fix(build): repair missing three.js core dependency`

Der rote Exit ist ein echter Hosted-Drift-Beweis, kein lokaler Produktfehler und kein Grund,
den Verifier abzuschwaechen.

## 7. Cloud- und Browser-Wahrheit

Die 11 bereits API-seitig messbaren Cloud-/Provider-Punkte sowie die zwei browser-only
Konsolenpunkte wurden geprueft bzw. vorbereitet. Danach wurden dokumentiert:

- GitHub-Environments `registry-publication` und `production` mit Required Reviewer
  `strazzusochr`,
- Worker-Secrets `AGENT_API_AUTH_TOKEN` und `GITHUB_OAUTH_CLIENT_SECRET` als verschluesselte
  Secrets,
- GitHub OAuth App mit festem Homepage-/Callback-Wert und ohne Wildcard,
- Vercel Production/Preview mit derselben konfigurierten Callback-URI.

Das ist Konfigurationsbeweis, kein Funktions-, Identity- oder Release-Beweis.

Der aktuelle DEV-ONLY Readback zaehlt `8/8` Provider konfiguriert und `7/8` live gelesen.
GitHub Actions und GitLab sind jetzt verifiziert; ausschliesslich GHCR bleibt mit
`status=api_error`, `live_verified=false`. Dadurch sind die Cloud-Layer `6/7`; L5 bleibt
`partial_live_verified` wegen `ghcr_registry_live_read_not_verified`. Das historische
`PROMPT_ANTIGRAVITY_CLOUD.md` mit `11/13`, GitLab-Alleinausfall und der alten
`read:packages`-Ursachenzuordnung ist `HISTORICAL_DO_NOT_EXECUTE`.

Aktuelle anonyme HTTPS-Readbacks:

| Surface | Probe | Ergebnis |
|---|---|---|
| Cloudflare stateful Worker | `/api/v1/health` | HTTP 200, Source `d0674bfc`, healthy |
| Cloudflare stateful Worker | `/api/v1/project/progress` | HTTP 200, Overall `84` |
| Cloudflare stateful Worker | `/api/v1/team/status` | HTTP 500 |
| Cloudflare stateful Worker | `/api/v1/auth/contract` | HTTP 200, `github_oauth_configured=false`, kein Live-OAuth |
| Cloudflare stateful Worker | `/api/v1/auth/me` | HTTP 404 |
| Vercel Frontend | `/api/v1/health` | HTTP 200, `degraded`, Backends nicht konfiguriert |
| Vercel Frontend | `/api/v1/project/progress` | HTTP 200, Overall `84` |
| Vercel Frontend | `/api/v1/team/status` | HTTP 200, ehrliche `frontend-projection` |
| Vercel Frontend | `/api/v1/auth/contract` | HTTP 200, Dry-run-Vertrag, kein Live-OAuth |
| Vercel Frontend | `/api/v1/auth/me` | HTTP 200, ehrliche leere Frontend-Projektion |

Die kanonische Repo-Wahrheit ist `89`; Hosted ist source-stale bei `84`. Ein HTTP 200 auf
einer Projektion schliesst kein Backend- oder Auth-Gate.

## 8. GitHub-Actions-Befund

`github_actions=api_error` war kein abgelaufener Owner-Token. Der lokale Secret-Store und
die `gh`-Keyring-Identitaet stimmten ueberein und die GitHub API war erreichbar. Nur der
laufende DEV-ONLY-Agent-API-Container hatte eine alte Environment-Kopie. Das gezielte
Recreate nur dieses Containers stellte `/api/v1/clouds` auf
`configured=true`, `live_verified=true`, `status=verified`, drei Ressourcen und keinen
Fehler. Kein Tokenwert wurde ausgegeben oder rotiert.

Der Follow-up-CI-Lauf `33223542872` beweist exakt Head `e98f68a6`, nicht automatisch den
spaeteren lokalen Head `740bafe9` oder diesen Dokumentensatz.

## 9. Bekannter Runtime-Contract-Drift fuer den naechsten Kandidaten

`services/agent-api/app/main.py:7455` und der Spiegel
`apps/frontend/lib/endpoint-snapshot.json` erwarten fuer den External-Audit noch hart
`cloudflare_native_zero_card_hosted_runtime`. Dieser Claim ist inzwischen wahr. Der aktuelle
sanitisierte Audit nennt stattdessen exakt:

- `hosted_agent_api_contracts`
- `ghcr_image_digest_verify`
- `vercel_backend_origin_health`

Das ist ein Runtime-Source-Defekt fuer den naechsten Kandidaten und wird nicht in diesem
reinen Dokumentationsslice nebenbei repariert. Ein Fix muss Red-first erfolgen, Snapshot und
Verifier gemeinsam aktualisieren und danach die komplette Kandidatenkette neu durchlaufen.

Zusaetzlicher Legacy-Drift: `docs/runtime-state/phase5-credit-itemization.json` bindet C3
noch an die Strings `Current RC20 Handoff` und
`Current RC20 Local Qualification Evidence`, obwohl der Pointer RC21 ist. Die beiden
aktuellen Dokumente tragen diese Strings nur als klar markierte historische
Kompatibilitaetsanker. Der Itemization-Schema-/Anchor-Fix gehoert in den naechsten Kandidaten,
nicht in eine Mutation der RC21-Wahrheit.

## 10. Produktions-OAuth: aktueller Architekturblocker

Die robuste OAuth-/JWT-/Refresh-Implementierung existiert in `services/agent-api/app/main.py`
mit PostgreSQL und Redis. Das Vercel-Frontend proxyt Browser-OAuth ausschliesslich zum
konfigurierten Agent-API-Boundary. `apps/frontend/lib/frontendBoundary.ts` akzeptiert den von
GitHub gelieferten `redirect_uri` nur, wenn dessen Origin dem sichtbaren Frontend-Origin
entspricht.

Der aktuelle Cloudflare-stateful Worker implementiert dagegen weder `/api/v1/auth/github`,
`/api/v1/auth/callback`, `/api/v1/auth/me`, `/api/v1/auth/refresh` noch
`/api/v1/auth/logout`. Ein direkter Worker-Callback ist damit sowohl funktional unvollstaendig
als auch mit der aktuellen Frontend-Origin-/Cookie-Grenze unvereinbar.

Wenn `AGENT_API_BASE_URL` heute auf diesen Worker zeigt, koennen unmatched GET-Auth-Routen
zwischen Worker und Vercel zurueckproxygen; unmatched POST fuer Refresh/Logout endet mit
HTTP 405. Der Fallback transportiert weder Browser-Cookies noch `Location`/`Set-Cookie`.
Das vorhandene GitHub-Client-Secret wird im Worker-Code nicht verwendet.

Die lokale FastAPI-Referenz besitzt 38 gruene Auth-Sicherheitstests, der Frontend-Proxy 22
gemockte Boundary-Tests und die Guest-/Name-Session 5 Tests. Keine davon beweist die
integrierte Hosted-GitHub-Kette. Zusaetzlich laedt `scripts/start-dev-live.ps1` heute nur vier
statt der benoetigten fuenf OAuth-Konfigurationsnamen; `GITHUB_OAUTH_OWNER_IDS` fehlt dort.
Das Frontend-Proxybudget ist kuerzer als der moegliche Callback-Upstream-Pfad und muss vor
einer Live-Abnahme monoton abgestimmt werden.

Die technische Empfehlung und die Red-first-Abnahme stehen in
`docs/runbooks/PRODUCTION_OAUTH_FIXPLAN_2026-08-29.md`. Vor Umsetzung ist eine explizite
Owner-ADR erforderlich: Cloudflare-native D1 + Durable Object im Zero-card-Pfad oder ein
freigegebener gehosteter FastAPI/PostgreSQL/Redis-Stack.

## 11. Offene Gates bis 100

| Gate | Aktueller Zustand | Was wirklich fehlt | Zustaendig |
|---|---|---|---|
| V0 L4/L5-Rubrik | Draft, kein Credit | exakte Commit-Freigabe und Ja zu beiden Tabellen/Verifiernamen | Owner |
| P3 / I5 Production Auth | blockiert | Architektur, Implementierung, aktueller Deploy, echter Session-/Replay-Beweis | Owner + Codex |
| I1 Hosted Candidate Parity | blockiert | aktueller kandidatgebundener non-local HTTPS-Stack und voller Hosted-Verifier | Owner + Codex |
| P6 Scale | blockiert | explizite Hosted-Write-Freigabe und exakt 900 Requests | Owner + Codex |
| GHCR / L5 | blockiert | einmalige private kandidatengebundene Publication mit Required Reviewer oder Rubrik-/Policy-Aenderung | Owner |
| Production/Promotion | blockiert | separate Freigabe erst nach Market-Ready | Owner |
| Organismus-/3-Sterne-Optik | bewusst zuletzt | eigener visueller Slice und visuelle Abnahme | Owner + Codex |

`docs/runtime-contracts/layer-credit-rubric.md` bleibt
`DRAFT_OWNER_APPROVAL_REQUIRED`, `credit_application_allowed=false`. L4 bleibt `55`, L5
bleibt `56`.

## 12. Arbeitsbaum und Eigentumsgrenzen

Eigene uncommittete Codeaenderung:

- `scripts/verify-phase1.ps1`

Generierte oder fremde Dirty-Dateien, nicht stagen, nicht resetten, nicht loeschen:

- `.codex/runs/CURRENT/product-acceptance/report.json`
- `.phase1-artifacts/o4-live-writes/proof.json`
- `.phase1-artifacts/o4-live-writes/runtime-proof.json`
- `.phase1-artifacts/o4-live-writes/browser-proof.json`
- `docs/runtime-state/capability-gates.json`
- `docs/runtime-state/external-gate-audit-v2.json`
- `docs/runtime-state/external-gate-summary.json`
- `docs/runtime-state/owner-input-manifest.json`
- gestaged: `docs/release-artifacts/prod-candidate-2026-08-02-local-rc12.md`
- alle bereits vorhandenen untracked Fremddateien

Regeln: kein `git add -A`, kein Stash, kein Reset fremder Dateien, kein Cleanup der
Evidence-Verzeichnisse, keine tracked Loeschung.

## 13. Naechster sicherer Ablauf

### Autonom und read-only/feature-branch-sicher

1. Diesen Dokumentensatz mit expliziten Pfaden validieren und committen.
2. `npm run verify:phase5-credit` und `npm run verify:current-release-candidate` ausfuehren.
3. `py -3 scripts/verify_project_progress_manifest.py` ausfuehren.
4. Feature-Branch pushen und den finalen `pr-check` auf exakt diesem Head auf
   `success` und `skipped=0` pruefen.
5. Den uncommitteten External-Gate-Set-Patch erst uebernehmen, wenn seine vereinbarte
   Akzeptanzbedingung erfuellt ist oder die Bedingung explizit neu entschieden wurde.

### Owner-Entscheidung vor jeder Ausfuehrung erforderlich

1. OAuth-ADR und Rubrikfreigabe.
2. Cloudflare/Vercel Candidate-Deploy oder anderer aktueller Hosted-Stack.
3. Hosted OAuth-Human-Flow und Scale-Write-Proof.
4. private GHCR-Publikation.
5. Production-Promotion/Rollout.

Jeder Source-Deploy muss die Source-SHA sichtbar binden; kein Deploy darf waehrend eines
Hosted-Proofs stattfinden.

## 14. Non-Claims

- Kein Push auf `main` oder den Default-Branch.
- Kein GHCR-Image wurde publiziert.
- Kein Production-Deploy, keine Release-Promotion und kein Rollout wurden ausgefuehrt.
- Kein Phase-6-Hosted-Write-Lauf wurde ausgefuehrt.
- Keine Produktion-OAuth-Session wurde bewiesen.
- Kein Secretwert, Passwort, 2FA- oder CAPTCHA-Inhalt wurde gelesen oder ausgegeben.
- Keine Zahlung oder kostenpflichtige Ressource wurde aktiviert.
- `MARKET_READY:false`.

Verweise:

- Kurzsteuerung: `CODEX_ZIELVERFOLGUNG_KURZ.md`
- 100%-Ziel: `CODEX_100_PROZENT_ZIEL_2026-08-29.md`
- OAuth-Fixplan: `docs/runbooks/PRODUCTION_OAUTH_FIXPLAN_2026-08-29.md`
- Optikregel: `REGELN_OPTIK_UND_FERTIG.md`
- RC21-Restliste: `AGENT_AUFTRAG_RC21_UND_RESTLISTE.md`
