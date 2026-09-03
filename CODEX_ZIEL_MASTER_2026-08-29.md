# CODEX ZIEL-MASTER — MARKTREIFE-ZIELVERFOLGUNG

## AKTIVER CHECKPOINT 2026-09-03 — CI-PORTABILITAET / NEUBINDUNG

Dieser Abschnitt ersetzt die untenstehenden Prefreeze-WIP-Aussagen.
Matrixpunkte: **1264/1400 erfuellt, 136 offen**; neu kreditiert **0/136**;
Overall **89**, `MARKET_READY:false`.

- Produkt-Slice `8b29aca5c0e1feff6e49c63802610bfc081502fd` (114 Pfade) und
  Q `50b5ec9534b9188756a3b3bd4a154c0317223995` wurden auf den Feature-Branch
  gepusht. Alle sechs fremden Dirty-Dateien blieben bytegleich; nur O1/O3-Grant-Hunks
  der Capability-Datei wurden committed, keine Live-Verification oder Punkte.
- CI `33795228836` hat S/Q-, Ledger-, Rubrik-, P6- und Phase-5-Bindungspruefungen
  bestanden. Im neuen 106-Test-Block: 103 PASS, zwei Windows-Temppfad-Fehler und ein
  ErrorView-Zeilenumbruch im negativen Docker-Shadow-Test. Der Docker-Guard selbst
  wies korrekt ab. Der Gesamtlauf ist **failure**, keine CI-Freigabe.
- Die Korrektur nutzt das Betriebssystem-Tempverzeichnis (lokal weiterhin
  `TEMP/TMP=D:\_sb_tmp`), plattformneutrales `git` und die unverkuerzte Exception
  fuer den negativen Test. Keine Schutzpruefung wird entfernt; zwei neue
  Portabilitaetsregressionen kommen hinzu.
- Der vorige S/Q-Versuch ist nicht release-qualifiziert. Nach fokussierten Tests
  folgt ein neuer Produkt-Freeze, dann ein direkter Q-Kindcommit mit Source-/Archivhash;
  erst danach CI mit exakt ausgechecktem S. Q muss vor dieser Source-Prequalification
  existieren: der alte RC33-Full-Credit-Verifier darf neuen Produktcode nicht krediteren.
- Kein Cloud-/Registry-Deploy, kein P6-Live-Dispatch, kein Provideraufruf, keine
  Production-Promotion. Owner-Paket erst mit den neu gebundenen SHAs ausgeben.



Status: `ACTIVE_CURRENT_TRUTH`
Stand: **2026-09-03**
Branch: `codex/organism-visual-v2`
Qualification Truth-Control: **`d9dbf8b3`** (pushed; final-head CI `33597146482`, `31/31`, skipped `0`)
Hosted-Evidence-Control: **`532a3c8c`** (immutable RC30 Hosted-MCP evidence + static scorer)
RC33 Qualification Source: **`a6323728`** · Source-Attestation: **`5aad04d4`** · Source-CI: **`33589444701`** (`31/31`, skipped `0`)
Local Evidence: **5/5 chains · 27 files · run `7bbc2310-0bb3-42e5-8484-819c37d93431`**
Last Pushed Truth-Control: **`d9dbf8b3e7bd4deb5e20a029d88219f3c8b98810`**
Phase-6 Hardened Code-Control: **`bc2d4c8e82e08e4d3e3d29a26e61e2fb30d03eb0`** · exact-head CI **`33605838142`** (`31/31`, skipped `0`, failed `0`)
Phase-6 Grant/Anchor Control: **`664968f08a2b392463165118b77887cc21781a98`** · exact-head CI **`33610385136`** (`31/31`, skipped `0`, failed `0`)
Hosted Boundary: **Vercel Preview Ready; Cloudflare Preview HTTP `429/1027`, Stateful `94cee685`, LLM `87a2b17e`** — exact RC33 six-service parity is not proven
**B1 ERTEILT 2026-08-31** — `RubricApprovalCommit = e87c28a7c6cf32982caa849794042daa53ef022a`
Market Status: `MARKET_READY:false` — Overall `89`, Delta-Ledger `1`, L5 `86`

> **AKTIVER WIP-SCHRITT 2026-09-03:** Produkt-Freeze `S` ist noch nicht committed.
> Neu kreditiert `0/136`, offen `136` (`P3 +56`, `P5 +11`, `P6 +10`, `L4 +45`,
> `L5 +14`). Die S/Q-Publikationskette ist jetzt auf
> `source-qualification-control-v1` mit exakter Release-ID, `S` und `git archive` SHA-256
> umgestellt. Sechs lokale Images bauen, starten/importieren und scannen gruen
> (HIGH/CRITICAL `0`, Secrets `0`); CycloneDX `6/6`. Unit `119/119`, Progress/Phase5
> `60/60`, Rubrik `15/15`, OAuth `36/36`, Stateful Worker `69/69`, P6-Static und
> Supply-Chain-Pins sind PASS. O1/O3 sind nur als grant/ref vorbereitet;
> `live_verified=false`. Kein Push, Deploy, Dispatch, Providercall oder Prozentkredit.
> Naechster Schritt: finaler Security-/Pfadinventar-Check, exakter S-Commit/Push,
> Exact-Head-CI und danach direkter Q-Kindcommit.

> **RC33 Qualification-Freeze ist abgeschlossen.** Qualification-/Evidence-/Truth-Commit
> `d9dbf8b3` ist gepusht; final-head `pr-check` `33597146482` bestand `31/31`, skipped `0`,
> failed `0`. Die Preview-Neumessung ist aktuell durch den accountweiten Cloudflare-
> Free-Plan-Tagesrequest-Grenzwert blockiert: Stateful und LLM liefern HTTP `429/1027`,
> waehrend Vercel Ready ist und MCP/LLM deshalb fail-closed `degraded` melden. Nach dem
> `00:00 UTC`-Reset gilt die aktuelle Reihenfolge aus dem Phase-6-Checkpoint unten.
> Preview-Loop-Guard, Phase-6-Production-Rebind und B3 sind inzwischen eng autorisiert;
> B2/Production-OAuth sowie B4/I1/GHCR bleiben getrennte Owner-Entscheidungen.

> **Wartung spaeter:** Die GitHub-Actions-Runtime-Pins bleiben fuer RC33 eingefroren.
> `upload-artifact` v4.6.2 sowie `checkout`/`setup-node` v4 werden erst nach dem naechsten
> Freeze in einem separaten Slice aktualisiert.

> **AKTUELLER SCHRITT:** Die Phase-6-Urkunde ist jetzt eng als
> `owner_granted=true` mit
> `OWNER_GRANTS_2026-09-02.json::O2:phase6_scale_runtime` eingetragen;
> `live_verified=false`, keine Evidence und kein Credit. Der Scale-Workflow bleibt bis
> nach dem Worker-Rebind und genau einem `200`-Health-Read undispatcht. Der fruehere
> Verifier-Widerspruch ist in `63983d6b` eng
> behoben: der Null-Credit-Beweis wird am unveraenderlichen B1-Approval-Commit gelesen,
> waehrend spaetere getrennt autorisierte Grants moeglich bleiben. Die Worker-Rekursion ist
> in `c24b7bfd` lokal behoben und `/cdn-cgi/trace` in `bc2d4c8e` kriteriumsgemaess nur
> Attribution-Control; exact-head CI `33605838142` ist vollstaendig gruen. Trotzdem bleibt
> `live_verified=false`: zuerst den autorisierten Production-Worker-Rebind mit dem
> Loop-Guard auf aktuelle Source, danach genau einmal HTTP `200`, frische immutable
> Deployment-Evidence und erst dann ein einziger Actions-Lauf. Der OAuth-Alias
> `frontend-seven-psi-78` ist
> bestaetigt, ersetzt aber nicht den einzigen Phase-6-Origin
> `cloud-superbrain-stateful-runtime.strazzusochr.workers.dev`. Kein GHCR-Transfer.
> Der Grant ist auf Control `664968f0` durch `pr-check` `33610385136` mit `31/31`,
> skipped `0`, failed `0` attestiert; der Phase-5-Ankerfehler ist damit geschlossen,
> ohne I1/I5 oder Prozente zu veraendern.

> **QUOTA-ATTRIBUTION:** Das eingeloggte Cloudflare-Dashboard misst ueber 24 Stunden
> Production Stateful mit `159` Invocations/`0` Errors, Preview Stateful dagegen mit
> `868.21k`/`0`; `868k` entfallen auf Preview-Version `fc27406d`. Preview ist damit der
> dominante gemessene Invocation-Verbraucher. Dass diese Last der primaere Beitrag zur
> Shared-Limit-Ausschoepfung war, ist stark gestuetzt; alleinige Verursachung ist nicht
> bewiesen und die Cross-Origin-Bounce bleibt ohne Requestpfad-
> Analytics eine begruendete, aber nicht kausal bewiesene Ursache. Vor dem Reset keine
> weiteren Worker-Reads; danach Loop-Guard zuerst auf Preview und den finalen Phase-6-
> Production-Sourcepfad, dann exakt ein eigenstaendiger Production-Health-Read, ein frischer
> kanonischer O2Core-Write/Read/Delete-Verifierlauf mit State/Evidence <24 h und ein Scale-
> Run. Dessen GitHub-Readback muss innerhalb 24 h nach Evidence-Erzeugung folgen.

**Dies ist die einzige Zieldatei.** Sie sagt, *was zu tun ist*.
Die Lage steht in `CODEX_UEBERGABE_MASTER_2026-08-29.md`.

> Der Dateiname bleibt bewusst auf `2026-08-29` stehen, damit Codex genau eine Zieldatei und
> genau eine Uebergabe findet. Massgeblich ist das Feld `Stand` oben.

**Vorrangregel.** Im Repository liegen weitere `CODEX_*.md` aus historischen Gruenden.
Gueltig sind ausschliesslich diese beiden Dateien. Ueberholt und im Kopf markiert sind
`CODEX_100_PROZENT_ZIEL_2026-08-29.md`, `CODEX_ZIELVERFOLGUNG_KURZ.md`,
`CODEX_UEBERGABE_2026-08-29-SESSION16.md`, `CODEX_MASTER_GOAL_AUTONOM_WEITER.md` und
`CODEX_MASTER_GOAL_FINALE.md`.

## Owner-Aktionen 2026-09-01 — bereits ausgefuehrt, nicht wiederholen

Der Owner hat an diesem Tag zwei Dinge selbst ausgefuehrt. Beide sind gemessen bestaetigt:

1. **B1-Approval-Commit** `e87c28a7c6cf32982caa849794042daa53ef022a` (am 2026-08-31),
   gepusht auf `origin/codex/organism-visual-v2`.
2. **PR #32 gemerged** — `phase6-scale-runtime.yml` liegt jetzt auf dem Default-Branch,
   Merge-Commit `ce75bb00`, byte-identisch (Blob `0b2f7e3b`), `state=active`.

**Ein Nebeneffekt, den Codex kennen muss.** Der Merge war ein Push auf
`chore/repo-bootstrap`, und die dort liegende **alte** `main-deploy.yml` traegt
`on: push: branches: [chore/repo-bootstrap]` zusammen mit `packages: write`. Sie ist
dadurch von selbst gestartet (Lauf `33497699169`). Sie brach im `verify`-Job an der
Frontend-`npm audit`-Stufe ab; `production-gate` und `build-and-push` blieben `skipped`.
**Kein Image erreichte GHCR** — belegt durch den Job-Status, nicht durch eine
Registry-Abfrage (dem Token fehlt `read:packages`).

Konsequenz: **jeder weitere Push auf den Default-Branch weckt diesen alten Workflow**,
solange der gehaertete Blob `14e84b31` ihn nicht ersetzt hat. Das ist jetzt Teil von B4 und
kein Nice-to-have mehr. Ein Owner-Zweig `owner/harden-main-deploy-on-default` ist bereits
angelegt (Basis `ce75bb00`); die Datei darin fehlt noch. Die exakten Befehle stehen in
`OWNER_ANLEITUNG_2026-09-01.md`.

---

**Aktuelle Aussagen** sind lokal gegen RC33-Source `a6323728`, Source-Attestation
`5aad04d4`, Source-CI `33589444701`, finalen Truth-Head `d9dbf8b3`, final-head CI
`33597146482`, die fuenf lokalen Qualification-Ketten und das exakte
27-Dateien-Evidence-Set gemessen. Die vertikale L5-Messung bleibt an Evidence-Control
`532a3c8c` und die vier immutable RC30 Hosted-MCP-Reports gebunden. Die runtime-identische
Vercel-Frontend-Preview `50a591d4` ist browser-gruen, aber keine exakte RC33-sechs-Service-
Paritaet und schliesst I1 weiter fail-closed aus.

---

## 1. Endziel

`pwsh -NoProfile -File .\scripts\verify-market-ready.ps1 -IncludeExternalGates` druckt real:

```text
MARKET_READY: true
```

Beide Matrizen **evidenzbasiert** 100. Production-Deploy und Release-Promotion bleiben
danach **separate** Owner-Entscheidungen.

---

## 2. Restdelta

```text
Horizontal:  P0 100 | P1 100 | P2 100 | P3 44 | P4 100 | P5 89 | P6 90
Vertikal:    L1 100 | L2 100 | L3 100 | L4 55 | L5 86 | L6 100 | L7 100
Delta-Ledger: 1 Eintrag
```

| Zelle | Rest | Was jetzt konkret fehlt |
| --- | ---: | --- |
| P3 | **+56** | OAuth-Kette ist hosted gefahren. Es fehlen **5 von 12** Evidence-Schritten und das Evidence-Dokument; B1 ist erledigt. |
| P5 | **+11** | `I5` faellt evidenzgetrieben nach P3. `I1` braucht Hosted-Candidate-Paritaet **plus** Codeaenderung. |
| P6 | **+10** | Verifier, Environment, Secret, geschuetzter Default-Branch-Workflow und B3-Grant sind vorhanden. Offen: Quota-Reset, Preview-Guard, finaler Production-Rebind, frische canonical O2Core-Evidence <24 h, genau ein 900er-Lauf und GitHub-Readback <24 h. Der alte 900er-Lauf zaehlt nicht. |
| L4 | **+45** | Exakte RC33 Hosted-Paritaet fehlt. Die fuenf generativen Verifier warten zusaetzlich fail-closed auf das lokale Verifier-Credential. |
| L5 | **+14** | Vier Hosted-Kriterien (+30) sind kreditiert. Offen: Registry-Digests, Remote-Scan, Candidate-SBOM-Credit und Protected-Publish. |

**136 offene Punkte.** `overall = round(sum(7 Phasen)/7)`
(`scripts/verify_project_progress_manifest.py:328`). L4/L5 sind Pflicht fuer die vertikale
100, bewegen die 89 aber **nie**.

---

## 3. Kritischer Pfad

```text
S1  B1  Rubriken freigeben  ── ERLEDIGT 2026-08-31  e87c28a7
                                          │
S1d RC33 lokal qualifiziert ── ERLEDIGT ─┤  Source a6323728, 5 Ketten, 27 Dateien
                                          │
S2a Hosted-Boundary-Fixes ───── ERLEDIGT ──┤  source-attestiert, lokal verifiziert
                                          │
S2c RC33 Final-Head-CI ─────── ERLEDIGT ──┤  d9dbf8b3, CI 33597146482, skipped=0
S2d Preview-Guard/O2-Refresh ── BLOCKIERT ─┤  CF Free-Plan-Tageslimit: HTTP 429/1027
                                          │
      ├─> S3  L4/L5 Hosted-Laeufe ────────┼──> L4 +45, L5 +14   L5 vier Kriterien erledigt
      │                                   │
      ├─> S4  P3-Evidence vervollstaendigen ──> P3 +56 ──> P5-I5   (braucht B2)
      │                                   │
      ├─> S5  P6-Scale mit echtem Verifier ──> P6 +10              (B3 erteilt; braucht frische Evidence)
      │                                   │
      └─> S6  I1: Candidate-Paritaet + Codepin ──> P5 100          (braucht B4-Dispatch)
                                          │
                          S7  Delta-Ledger: erster Real-Replay erledigt ──> Finalstack
```

**S1 ist erledigt.** Der Owner hat am 2026-08-31 alle drei Rubriken freigegeben;
Approval-Commit `e87c28a7c6cf32982caa849794042daa53ef022a`, gepusht auf
`origin/codex/organism-visual-v2`. Alle drei tragen dort `Status: \`APPROVED\``,
`Credit-Anwendung erlaubt: \`true\`` und eine `Owner-Freigabe-Ref:`-Zeile. Nachgemessen:
`overall = 89`, `17/19` — die Freigabe allein hat **keinen Punkt** vergeben, sie hat
nur die Verifier startbar gemacht.

**Der aktuelle Hosted-Engpass ist extern:** Cloudflare hat den accountweiten Free-Plan-
Tagesrequest-Grenzwert erreicht und liefert bis zum `00:00 UTC`-Reset HTTP `429/1027`.
Danach wird genau einmal neu gemessen. L4 braucht danach weiterhin das lokale Verifier-
Credential; L5s letzte 14 Punkte brauchen B4/GHCR. Der erste reale v2-Ledger-Replay ist
gruen und beweist, dass vertikaler Hosted-Credit ohne Phase-5-Inflation gebucht werden kann.

---

## 4. Was bereits erledigt ist — nicht wiederholen

- **F1/F2 sind live.** Deployment `6bf89fc8`, Source-Bindung gesetzt und geprueft.
  `GITHUB_OAUTH_REDIRECT_URI` zeigt auf den Worker-Callback und stimmt mit der GitHub-App
  ueberein (Wildcard aus, Scope `read:user`).
- **Die OAuth-Kette ist hosted gefahren** — der Owner hat einmal Authorize geklickt.
  Serverseitig in D1 belegt: Cancel fail-closed, Authorize mit `identity_verified` und
  `oauth_state_consumed`, Familie `subject=github:237145441`, Refresh `rotated`, Logout
  `revoked` mit `revocation_reason=user_logout`, danach `me=401`/`refresh=401`.
  **Der teure Teil ist erbracht.**
- **RC24 ist lokal qualifiziert**: fuenf Ketten gruen, 27-Dateien-Evidence-Set,
  CI `33359506266` `30/30`, Selection-CI `33369934779` `30/30`, Browser `22/22`/`29/29`/`161/161`.
- **Die zehn L4/L5-Verifier sind echte Skripte** (88–307 Zeilen statt 43–69), mit
  Pflichtparametern, Owner-Grant-Pruefung gegen `capability-gates.json`, Rubrik-Bindung und
  echten Hosted-Operationen inklusive Readback. Dazu neuer Worker-Code
  (`src/mcp-hosted.js`, Migrationen 0006/0008).
- **`scripts/deploy-cloudflare-stateful-runtime.ps1`** ist der einzige zugelassene
  Deploy-Pfad und verhindert den Var-Verlust strukturell.

---

## 5. Die Stufen im Detail

### S1 — B1: Rubriken freigeben — ERLEDIGT 2026-08-31

```text
RubricApprovalCommit = e87c28a7c6cf32982caa849794042daa53ef022a
```

Alle drei Rubriken unter `docs/runtime-contracts/` tragen bei diesem Commit
`Status: \`APPROVED\``, `Credit-Anwendung erlaubt: \`true\`` und die vom Verifier verlangte
`Owner-Freigabe-Ref:`-Zeile. Nachgemessen: `overall = 89`, `deltas = 0`, `17/19` — die
Freigabe hat **keinen Punkt** vergeben. Kriterienzeilen, Punkte, Statusspalten und
`Version:`-Strings sind unveraendert; insbesondere die woertlich abgeglichene 10-Punkte-Zeile
fuer `verify-llm-hosted-stream-parity.ps1`.

Der Vertrag, den jeder Verifier prueft:

```text
-RubricApprovalCommit  ^[0-9a-f]{40}$
                       existierender Commit
                       Ancestor von ExpectedSourceCommitSha
                       Rubriktext wird aus GENAU diesem Commit gelesen
                       Rubrik-Blob identisch in Approval-Commit und Kandidat
Contract-Feld rubric_approval_sha  muss identisch sein
```

**Die drei Rubriken sind ab jetzt eingefroren.** Jede weitere Aenderung bricht die
Blob-Gleichheit (`rubric_blob_drift`) und erzwingt eine neue Owner-Freigabe.

### S1d — RC33 einfrieren und lokal qualifizieren — ERLEDIGT

RC33-Source `a632372863a39faa0e53d780c1942938a2b3241c` enthaelt die Hosted-Next-
API-Sicherheitsheader, deterministische Read-Projektionen, fail-closed Gateway-Fallback,
redaktierte Plattformfehler, die vollstaendige Gameplay-Transition-Projektion und den
byte-/EOL-sicheren Candidate-Verifier-Vergleich. Control
`5aad04d47375490dfbd8765d6e9e3f77241f3fdf` wurde durch `pr-check` `33589444701`
source-attestiert (`31/31`, skipped `0`). Candidate-Images, Runtime, Browser,
Candidate-Runtime und Security sind unter Evidence-Run
`7bbc2310-0bb3-42e5-8484-819c37d93431` gruen; das Evidence-Set enthaelt exakt 27
Dateien. Browser: `22/22`, `29/29`, `161/161`; Runtime: `10/10 healthy`; Kandidaten-
Archiv-Audit: `0` Schwachstellen, gitleaks: `no leaks`. RC31 ist der lokale Rollback.

**Kredit:** keiner aus Qualification; P5 bleibt `89`, I1/I5 bleiben blockiert.

### S1c — RC31 einfrieren und lokal qualifizieren — ERLEDIGT (HISTORISCHER VORGAENGER)

RC31-Source `94cee68508196195454139a7c4a432b024f91869` enthaelt den nativen fail-closed
Stateful-Preview-MCP-Health-Handler. Control
`7e99d6c815015ac792864700b2cf57ea8c042fe0` wurde durch `pr-check` `33566857871`
source-attestiert (`31/31`, skipped `0`). Candidate-Images, Runtime, Browser,
Candidate-Runtime und Security sind unter Evidence-Run
`1d69dcc1-8383-4447-8158-912e98b9f8fe` gruen; das Evidence-Set enthaelt exakt 27
Dateien. Browser: `22/22`, `29/29`, `161/161`; Runtime: `10/10 healthy`; Kandidaten-
Archiv-Audit: `0` Schwachstellen. RC30 ist der lokale Rollback.

**Kredit:** keiner aus Qualification; P5 bleibt `89`, I1/I5 bleiben blockiert.

### S1b — RC30 einfrieren — ERLEDIGT (HISTORISCHER VORGAENGER)

RC30-Source `9e88f84ac6c4afd78e152b5dc3b5bb08cf636c68` enthaelt den Approval-Commit.
Control `f5a31e52e8bbf6d166c7a1c11932f15219c587c1` wurde durch `pr-check` `33540678387`
source-attestiert. Candidate-Images, Runtime, Browser, Candidate-Runtime und Security sind
gruen; das unveraenderliche Evidence-Set enthaelt exakt 27 Dateien. Der spaetere
Hosted-Evidence-Control `532a3c8c` bestand `pr-check` `33560498326` mit `31/31`,
`skipped=0`, `failed=0`.

RC29s finaler Head-CI-Lauf scheiterte an zwei neu veroeffentlichten HIGH-Advisories fuer
`browserslist <=4.28.6`. RC30 pinnt `browserslist` `4.28.8`; der saubere Kandidaten-Audit
meldet `0` Schwachstellen. Produktlogik und die RC29-Three.js-Reparatur bleiben unveraendert.

**Kredit:** keiner aus Qualification; die spaeteren Hosted-Kriterien werden separat gebucht.

### S2 — Hosted-Rebind auf die RC30-Source — ERLEDIGT (HISTORISCHER VORGAENGER)

Vor jeder Mutation zuerst Worker-Health, Source-SHA, Bundle-SHA, D1-Migrationen und die
isolierten Preview-Namen neu read-only messen. Solange Health nicht exakt RC30-Source und
den passenden Source-Archive-SHA meldet, kann kein L4/L5-Verifier Source-Paritaet
feststellen.

```powershell
Set-Location <RC30-Arbeitsbaum>
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
Get-Content 'C:\Users\immer\.codex\secrets\cloud-superbrain.local.env' | ForEach-Object {
  if ($_ -match '^(CLOUDFLARE_API_TOKEN|CLOUDFLARE_ACCOUNT_ID)=(.*)$') {
    Set-Item -Path "env:$($Matches[1])" -Value ($Matches[2].Trim().Trim('"').Trim("'"))
  }
}
pwsh -NoProfile -File .\scripts\deploy-cloudflare-stateful-runtime.ps1 -CommitSha 9e88f84ac6c4afd78e152b5dc3b5bb08cf636c68
```

**Vorher:** D1 read-only auditieren und nur nachweislich fehlende additive Migrationen ueber
den vorgesehenen Deploy-/Migrationspfad anwenden; keine Migration aus altem Protokollstand
blind wiederholen.

**Abnahme:** Stateful- und LLM-Preview-Health melden `source_commit_sha = 9e88f84a...`,
Archive `71e9dafe...` und den gebundenen Bundle-Hash. D1-Migrationen blieben unveraendert
vollstaendig. Der einheitliche Vercel-Pfad ist separat blockiert (`/mcp/.../health = 404`).

**Kredit:** keiner. Voraussetzung fuer S3 bis S6.

**Non-Claim:** Preview-Rebind ist kein Production-Alias, Rollout oder Release.

### S2b — Hosted-Rebind auf die RC31-Source — HISTORISCHER VORGAENGER

Nur die isolierte Cloudflare Stateful Preview auf die eingefrorene RC31-Source deployen;
Source-, Archiv-, Bundle- und D1-Read-Bindung muessen gruen sein. Danach nur die Vercel-
Preview-Variable `MCP_GATEWAY_BASE_URL` auf den verifizierten Preview-MCP-Pfad setzen und
die Vercel Preview neu deployen. Unified `/mcp/api/v1/health` muss ueber nichtlokales HTTPS
`200`, `integrity=verified` und RC31-Source melden. Anschliessend echte sichtbare Browser-
Navigation und Funktionsklicks auf dem Preview-Alias. Kein Production-Alias, kein GHCR,
keine Scope-/Secret-Ausweitung.

### S2c — RC33 Qualification-Freeze — ERLEDIGT

RC33 ist mit Control `664968f0` und exact-head `pr-check` `33610385136` (`31/31`,
`skipped=0`, `failed=0`) eingefroren. Der Phase-5-Ankerfehler ist geschlossen; kein
Kredit wurde vergeben.

### S2d — Phase-6 Preview-Guard, Production-Rebind und O2Core — AKTUELLER SCHRITT

Vor dem `00:00 UTC`-Reset keinen Worker-Endpunkt aufrufen. Danach aus dem finalen,
CI-gruenen Source-Commit `S`: Preview-Loop-Guard rein ueber die Control Plane deployen
(`0` Worker-Requests), denselben Source auf den eng autorisierten Production-Worker
deployen und dort exakt einen redirect-freien Health-GET (`200`) ausfuehren. Beide
Deploy-Ergebnisse innerhalb zehn Minuten mit
`write-phase6-scale-deployment-preflight.ps1` in den separaten P6-Preflight-State plus
immutable Evidence/Sidecar binden. Danach einmal den kanonischen O2Core-Verifier mit
echtem Write/Read/Delete fahren. Preview-, Deployment- und canonical O2Core-Evidence
muessen beim Dispatch source-bound, getrackt und juenger als 24 Stunden sein.

Der daraus entstehende Control-Commit `C` darf nur die allowlisteten State-/Evidence-
Pfade enthalten. Ab `C` bis zur P6-Evidence-Verifikation/Gate-Promotion keinen weiteren
Branch-Commit erzeugen. Auf exakt `C` ist nur `run_attempt=1` und genau ein Dispatch
erlaubt; ein zweiter Lauf oder Rerun ist ungueltig. GitHub-Run/Artefakt-Readback sofort,
spaetestens 24 Stunden nach der Scale-Evidence, sammeln. Die menschliche Environment-
Freigabe separat per GitHub-API/UI belegen. I1/GHCR und I5/Production-OAuth bleiben
getrennte Owner-Gates; `live_verified` wird nie von Hand gesetzt.

### S3 — L4/L5 Hosted-Verifier — TEILWEISE ERLEDIGT (+0 / +30)

Erst nach S1 und S2c. Jeder neue Verifier braucht mindestens:

```text
-ExpectedSourceCommitSha a6323728...
-ExpectedSourceBundleSha256 <64 hex>
-OwnerGrantRef <exakte Referenz aus capability-gates.json>
-RubricApprovalCommit <40 hex aus S1>
```

Der Verifier prueft zusaetzlich, dass das passende Gate in
`docs/runtime-state/capability-gates.json` `owner_granted = true` traegt **und** die
`owner_grant_ref` exakt uebereinstimmt. Beispiel `verify-mcp-hosted-write.ps1`: Gate
`live_mcp_writes`, Evidence-Felder `write_performed`, `readback_verified`,
`immutable_receipt_verified`, `channel_state_current`, `audit_persisted`,
`audit_fail_closed`, `rollback_on_audit_failure`, `live_mcp_writes`; Contract-Phasen
`bounded_write`, `server_readback`, `audit_prewrite`, `audit_postwrite`.

Nur der Erfolgspfad setzt `credit_eligible = $true`. Ein blockierter Lauf schreibt
`credit_eligible = $false` — dann **nicht** kreditieren, sondern die Ursache beheben.

**Aktueller Kredit:** L5 `56 -> 86` durch exakt vier immutable, auf RC30 source-bound
scorer-verifizierte Reports. Dieser bereits kreditierte Beweis wird nicht umetikettiert.
Neue Hosted-Laeufe muessen RC33-bound sein. L4 bleibt `55`; L5-Ziel `100` wartet auf die
14 Registry-/Scan-/Publish-Punkte.

### S4 — P3 vervollstaendigen und Evidence schreiben (+56, danach I5)

`scripts/verify-production-auth-identity-evidence.ps1 -ValidateOnly -EvidencePath <pfad>
-ExpectedCandidateSha <40 hex>` verlangt `production-auth-identity-proof-v1` mit **exakten**
Feldmengen — unbekannte Felder lassen ihn ebenso scheitern wie fehlende.

**Die zwoelf Kettenschritte** in `human_flow_verified_steps`:

```text
bewiesen   github_cancel_no_credentials     github_authorize_owner_identity
           callback_one_time_state          auth_me_verified_identity
           refresh_atomic_rotation          logout_revocation_audited
           post_logout_refresh_rejected

offen      anonymous_login_no_identity      github_start_exact_query
           reload_session_continuity        old_refresh_replay_rejected
           callback_replay_rejected
```

`old_refresh_replay_rejected` ist der anspruchsvollste: der **alte** Refresh-Token muss nach
der Rotation erneut gesendet werden. Aus dem Browser geht das nicht — die Cookies sind
`HttpOnly` und werden bei der Rotation ersetzt. Es braucht einen Client, der den
`Set-Cookie`-Wert vor der Rotation mitschneidet und danach replayt (`curl` mit Cookie-Jar
oder ein Playwright-Kontext).

**25 Felder muessen `true` sein**, darunter `hosted_https`, `real_browser`,
`oauth_scope_exact_read_user_verified`, `callback_replay_rejected_verified`,
`refresh_family_replay_rejected_verified`, `audit_before_credential_verified`,
`rollback_verified`, `unauthenticated_me_401_verified`, `cookie_policy_verified`,
`owner_numeric_id_allowlist_verified`, `source_parity_verified`,
`request_session_audit_correlation_verified`, `redaction_verified`,
`branch_protection_verified`, `secret_scan_verified`, `live_github_oauth_call`.
**Vier muessen `false` sein:** `dev_only`, `secret_output`, `gate_promotion_performed`,
`verifier_mutations_performed`.

**`source_binding` verlangt drei Mal denselben Kandidaten-SHA:**

```text
source_commit_sha == frontend_source_commit_sha == auth_runtime_source_commit_sha == ExpectedCandidateSha
deployment_id     == auth_runtime_deployment_id
immutable_frontend_deployment_verified     = true
immutable_auth_runtime_deployment_verified = true
```

Das heisst: **auch das Vercel-Frontend muss aus demselben Commit unveraenderlich deployt
sein**, nicht nur der Worker. Dazu Hash-gebundene Referenzen auf
`docs/runtime-state/frontend-hosted-current.json`, auf ein Auth-Runtime-Evidence-Dokument
und auf eine **Owner-Architekturentscheidung** (`owner_architecture_decision_ref` mit
`owner_approved` und `selected_architecture`) — das ist **B2**.

**Kredit:** P3 `44 -> 100`. Danach faellt `I5` automatisch, weil `expected_blocked_ids` es
rein evidenzgetrieben behandelt (`verify_phase5_credit_itemization.py:290`). P5 geht auf
`95` (18/19).

### S5 — P6: 900 Requests mit dem zugelassenen Verifier (+10)

Voraussetzung **B3 ist seit 2026-09-02 vollstaendig erfuellt und CI-attestiert.** Gemessen:

```text
Environment  phase6-scale-hosted-writes           vorhanden, Required Reviewer aktiv
  Secret     AGENT_API_AUTH_TOKEN                 vorhanden seit 2026-08-30T12:12:44Z
Workflow     auf chore/repo-bootstrap (Default)   vorhanden, state=active, id=347406379
Gate         phase6_scale_runtime                 owner_granted=true
Grant-Ref    OWNER_GRANTS_2026-09-02.json::O2:phase6_scale_runtime
CI           Control 664968f0                     run 33610385136, 31/31, skipped=0
```

Der Workflow kam per Owner-PR #32 (Merge `ce75bb00`) auf den Default-Branch und ist dort
als `workflow_dispatch` aktiv. Der Secret-**Wert** ist von aussen nicht pruefbar — GitHub
gibt ihn nie heraus; ein falscher Wert faellt im geschuetzten Lauf fail-closed auf. Der
Grant wurde in `638ba0a9` eng eingetragen, `live_verified=false` blieb unveraendert, und
Control `664968f0` ist durch `pr-check` `33610385136` exakt attestiert.

Der aktuelle Blocker ist nicht B3, sondern die kontoweite Cloudflare-Quota plus zwei
Frischefenster. Nach Reset zuerst den Preview-Loop-Guard und den finalen Production-Source-
Rebind ausfuehren. Danach muss `verify-cloudflare-stateful-runtime.ps1` die canonical
O2Core-Write/Read/Delete-Evidence samt `cloudflare-native-hosted-current.json` source-bound
und <24 h neu erzeugen. Erst dann folgt genau ein Scale-Dispatch; dessen GitHub-Readback
muss innerhalb 24 h nach Evidence-Erzeugung gesammelt werden. `live_verified` wird erst
durch den erfolgreichen Beweis bewegt, niemals von Hand.

Der vorhandene 900er-Lauf zaehlt **nicht** — er lief am Verifier vorbei, waehrend das Gate
`phase6_scale_runtime` auf `owner_granted=false` stand, und liefert weder D1-Readback noch
No-Loss/No-Duplicate-Zaehlung noch Cleanup-Semantik noch Control-Tier.

Gegen `docs/runtime-state/phase6-scale-criterion.json` (v2):

```text
Reads   60 @ concurrency 1 | 240 @ 10 | 500 @ 50
Writes  50 x POST /api/v1/builds @ 10, serverseitiger D1-Readback je Record
Deletes 50 authentifiziert, soft_delete_then_active_row_absence_and_audit_readback
Control /cdn-cgi/trace, separates Budget, max 500
Gesamt  exakt 900 Worker-Requests
```

Bestehen: Quote >= `0.99`, p95 <= `1500 ms`, eigene 5xx = `0`, 50 erstellt/eindeutig/
geloescht, Verlust `0`, Duplikate `0`, Cleanup vollstaendig, Audit persistiert, Evidence
SHA-256-gebunden. `429` ist **nur** auf Health-Read-Tiers zulaessig und muss fail-closed
sein. Der Token gehoert ausschliesslich ins Prozess-Environment.

**Kredit:** P6 `90 -> 100`.

### S6 — I1 und der P5-Abschluss

1. **B4 Teil 1 ist erledigt** (2026-09-01): der gehaertete `main-deploy`-Blob `14e84b31`
   liegt auf dem Default-Branch, PR #33 gemerged als `9c508aab`; `registry-publication`
   traegt bereits `required_reviewers`. Offen ist nur noch: Candidate dispatchen und den
   Gate-Grant `docker_registry_publish` setzen. Sechs unveraenderliche
   SHA-Digests fuer frontend, agent-api, agent-worker, memory-worker, mcp-gateway,
   llm-gateway. Das schliesst `ghcr_image_digest_verify` — das letzte External Gate.
   **Kein Deadlock:** `scripts/verify-main-deploy-transition.ps1:63` fuehrt `market_ready`
   in der Liste **verbotener** Tokens; die Publikation setzt `MARKET_READY:true` nicht voraus.
2. Kandidatgebundenes Hosted-Staging mit **denselben** Digests -> das ist I1.
3. **Erst danach** die Codeaenderung:

```python
# scripts/verify_phase5_credit_itemization.py:44
BASELINE_BLOCKED_IDS = set()      # war: {"I1"}
```

Ohne sie bleibt `expected_percent` bei 95 und `require(computed_percent == expected_percent)`
schlaegt fehl. Fuer `I5` gilt das **nicht** — dort genuegt der Beweis.

**Kredit:** P5 `95 -> 100` (19/19).

### S7 — Delta-Ledger und Finalstack

`docs/runtime-state/project-progress-delta-ledger.json` ist der **einzige** zugelassene Weg,
eine Manifestzelle zu bewegen. `entries = 1`, `baseline.source_sha = 9a3776ff`.

Der synthetische Protokoll-Probelauf ist am Measurement-Ref `8adb6183` erledigt:
`py -3 -m unittest scripts.tests.test_verify_project_progress_manifest -v` bestand
`27/27`. Er akzeptiert den source-gebundenen P3-Replay und weist unter anderem falschen
`source_sha`, Nicht-Ancestor, falschen Projection-Hash, Prozent ueber 100, falschen
`overall`, alte Prozent-/Baseline-Kette, fehlende oder hash-abweichende Artefakte sowie
nicht approvierte/fehlgeschlagene/timeoutende Scorer fail-closed ab. Der erste reale
Anwendungsfall ist jetzt erfolgreich: der statisch zugelassene L5-Scorer bindet vier
immutable RC30-Reports und replayt `56 -> 86`, Overall `89`, ohne Phase-5-Aenderung.

Je bewegter Zelle **ein** SHA-gebundener Eintrag. Danach muss
`py -3 scripts/verify_project_progress_manifest.py` die neuen Werte akzeptieren. **Niemals**
einen Prozentwert direkt im Manifest setzen.

Finalstack, streng seriell:

```powershell
$env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'; $env:PYTHONUTF8='1'
npm run verify
npm run verify:runtime
pwsh -NoProfile -File .\scripts\start-dev-live.ps1
npm run verify:browser
npm run verify:csrf
npm run verify:responsive
npm run verify:frontend-hosted-current
npm run verify:backend-hosted-current
npm run verify:phase5-credit
npm run verify:current-release-candidate
npm run verify:release-candidate
npm run verify:external-gates
pwsh -NoProfile -File .\scripts\verify-market-ready.ps1 -IncludeExternalGates
```

Zielausgabe muss **real** sein: `MARKET_READY: true`, Overall `100`, alle Zellen `100`,
Ledger enthaelt die legitimen Eintraege, Hosted-SHA = Kandidatenquelle, keine
`OWNER_BLOCKED` mehr.

---

## 6. Owner-Gates

| Gate | Entscheidung | Blockiert |
| --- | --- | --- |
| ~~**B1**~~ | **ERTEILT 2026-08-31** — Approval-Commit `e87c28a7c6cf32982caa849794042daa53ef022a` | — |
| **B2** | OAuth-ADR festschreiben (`owner_architecture_decision_ref`, `owner_approved`, `selected_architecture`) | P3-Evidence |
| ~~**B3**~~ | **ERTEILT UND CI-ATTESTIERT 2026-09-02**: Environment, Secret, Default-Branch-Workflow (PR #32, `ce75bb00`, `state=active`, id `347406379`), Required Reviewer sowie Gate-Grant `OWNER_GRANTS_2026-09-02.json::O2:phase6_scale_runtime`; Control `664968f0`, CI `33610385136`. `live_verified=false` bis zum echten Lauf. | — |
| **B4** | **Teil 1 erledigt 2026-09-01**: Default traegt jetzt den gehaerteten Blob `14e84b31` (11.623 Bytes), PR #33 gemerged als `9c508aab`. Push-Trigger ist weg, top-level `contents: read`, Publikation an `registry-publication` gebunden. Offen bleiben: Dispatch mit `candidate_sha` und der Gate-Grant `docker_registry_publish`. | GHCR / I1 |
| **B5** | Der enge Phase-6-Production-Rebind und der notwendige Preview-Loop-Guard sind 2026-09-02 autorisiert. Die breitere sechs-Service-I1-Paritaet/Vercel-Unified-Origin bleibt separat offen. | I1, S4 |

### Drei Waende, die keine Freigabe verschiebt

1. **Der GitHub-Authorize-Klick** braucht Passwort und 2FA des Owners. *Fuer die aktuelle
   Kette bereits erledigt* — bei einem neuen Kandidaten faellt er erneut an.
2. **Secret-Werte in Konsolen-Felder eintippen** ist einem Agenten kategorisch untersagt.
3. **Die Schreibsperren der Claude-Code-Harness.** Am 2026-09-01 praezise vermessen: Dateien
   schreiben, committen, pushen, Branches anlegen und Pull Requests **oeffnen** ist erlaubt;
   GitHub-**Einstellungen** aendern und Pull Requests **mergen** wird vom Auto-Mode-
   Klassifizierer blockiert. Codex hat diese Sperre nicht. Fuer Claude gilt: vorbereiten ja,
   ausloesen nein — der Owner oder ein zweiter Agent fuehrt den letzten Schritt aus.

---

## 7. Der offene Architekturpunkt: drei Origins

`/api/v1/project/progress` liefert hosted `84` statt `89`. **Kein Worker-Deploy aendert
das.** Der Worker hat keine native Progress-Route; alles Unbekannte faellt auf
`CONTRACT_ORIGIN` durch (`src/index.js:2011`), und dieser Origin meldet selbst `degraded`
und `84`.

```text
Frontend   frontend-seven-psi-78.vercel.app
Backend    cloud-superbrain-developer-platform.vercel.app   (= CONTRACT_ORIGIN, degraded)
Session    cloud-superbrain-stateful-runtime.strazzusochr.workers.dev
```

Drei Origins, und `__Host-`-Cookies gelten nur auf einem davon. Dieselbe Wurzel erklaert,
warum der Login zeitweise in einem 404 endete und warum ein Nutzer auf einer Frontend-Seite
nicht als angemeldet erscheinen kann. Zwei saubere Wege, beide Owner-Entscheidung:

- **A** — den Contract-Origin source-gebunden neu deployen, oder
- **B** — eine native Progress-Projektion in den Worker bauen und `CONTRACT_ORIGIN` fuer
  diese Route nicht mehr benutzen; Frontend-Pfade ueber den Worker routen.

`source_binding` in S4 verlangt ohnehin ein Frontend-Deployment aus derselben Quelle — diese
Entscheidung laesst sich also nicht umgehen.

---

## 8. Schutzregeln — bindend

- nie `git add -A`; immer exakte Pathspecs; nie `git commit` ohne Pathspec
- kein `git stash`, kein Force-Push, kein Push auf `chore/repo-bootstrap`
- Playwright, Docker-Build und Verifier **nie parallel**
- keine Frontend-Datei aendern, waehrend ein Browserlauf laeuft
- Evidence nie nachbearbeiten; `.phase1-artifacts/` und `docs/release-artifacts/` nie
  aufraeumen
- `live_verified` **niemals** von Hand setzen
- Verifier **nie** abschwaechen, um gruen zu werden
- keine Secrets in Ausgabe, Log oder Commit
- fremde Dirty-Pfade weder stagen noch zuruecksetzen
- Worker **nur** ueber `scripts/deploy-cloudflare-stateful-runtime.ps1` deployen
- `PYTHONUTF8=1` vor jedem Python-Verifier, `TEMP`/`TMP` auf `D:\_sb_tmp`
- solange ein RC eingefroren ist: kein neuer Produktcode-Commit

---

## 9. Was ausdruecklich verboten bleibt

Ein Kredit ohne den zugehoerigen echten Beweis ist Fake-Done. Konkret heute:

- **Keinen L4/L5-Verifier kreditieren, der `credit_eligible = false` schreibt.**
- Den alten 900er-Lauf **nicht** fuer P6 kreditieren.
- `production_auth_identity` **nicht** oeffnen, bevor das Evidence-Dokument den Verifier
  besteht — die gefahrene Kette allein reicht nicht.
- `BASELINE_BLOCKED_IDS` **nicht** leeren, bevor I1 belegt ist.
- Keinen Prozentwert direkt im Manifest setzen — ausschliesslich ueber den Delta-Ledger.
- Kein lokaler RC-Beweis darf als hosted, Production-Deploy, Promotion, Registry-Push,
  Produktions-OAuth oder Marktfreigabe umgedeutet werden.

`MARKET_READY:false` · `DEV-ONLY; hosted proof still blocked.`
