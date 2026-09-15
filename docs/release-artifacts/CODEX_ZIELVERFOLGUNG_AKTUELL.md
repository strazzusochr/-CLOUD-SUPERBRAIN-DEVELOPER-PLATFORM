# RC63/S16 – aktuelle Zielverfolgung bis Market Ready

**Dokumentstatus:** aktiv, evidence-gebunden, fortschreibbar
**Stand:** 15.09.2026, aktueller Remote-Readback
**Aktueller bestätigter Marktstatus:** `MARKET_READY:false`

Dieses Dokument ist der aktive Einstieg für die Zielverfolgung. Verbindliche Prozentwerte
und Gate-Wahrheiten kommen weiterhin ausschließlich aus den Manifesten und den
Verifiern. Dieses Dokument darf keine Prozentwerte, `live_verified`-Felder oder
Produktionsfreigaben manuell ändern.

## 1. Gebundene Identität

| Feld | Aktueller Wert |
|---|---|
| Standardzweig | `chore/repo-bootstrap` |
| bestätigter Remote-HEAD | `cfc7c529daffe5b523a7bc40b40082671d0f5c97` |
| letzter Merge | PR #136, normaler Merge-Commit |
| Release-ID | `prod-candidate-2026-09-12-local-rc63` |
| Produktquelle S16 | `0e9c680c191927dc352c96d119fc909c7d842296` |
| Qualifikation Q17 | `59fdd3fb15091fba160f830f5993c1254b2c52be` |
| S16-Archiv-SHA-256 | `0796e69e958c1abd1e466d74f79b7f82eac6207ef3706df3334ca3a178f01077` |
| Rollout-Claim | `false` |
| Prozentgutschrift in diesem Checkpoint | `0` |
| Secret-Ausgabe | `false` |

Vor jeder Fortsetzung muss der Remote-HEAD frisch gelesen werden. Der schmutzige
Root-Checkout `codex/organism-visual-v2` ist fremde Arbeit und keine Projektwahrheit.
Historische Dateien mit RC21–RC62-Koordinaten dürfen den aktiven RC63/S16-Stand nicht
überschreiben.

## 2. Aktueller Fortschritt

| Bereich | Stand |
|---|---:|
| Gesamt | **90 %** |
| Punkte | **1333/1400** |
| Offen | **67** |
| Horizontal P0–P6 | `100 / 100 / 100 / 44 / 100 / 89 / 100` |
| Vertikale Layer | alle sieben `100 %` |
| Phase 5 | `17/19`, offen: `I1`, `I5` |
| Marktstatus | `MARKET_READY:false` |

Die aktive External-Gate-Zusammenfassung bleibt im No-Credit-Checkpoint fail-closed.
Offen sind derzeit `hosted_agent_api_contracts`, `ghcr_image_digest_verify` und
`vercel_backend_origin_health`. Der GHCR-Readback ist vorhandene schreibfreie
Evidence, aber keine automatische Credit- oder Promotion-Erlaubnis.

## 3. Nummerierte Ziel- und Gate-Checkliste

Statusregeln: `[ ] OFFEN`, `[~] BLOCKIERT/TEILWEISE`, `[x] ERLEDIGT`. Ein Haken ist
nur erlaubt, wenn Handlung, Readback, Evidence-Hash und Regressionstest vorhanden
sind. Ein gestarteter Workflow oder eine grüne Teilprüfung reicht nicht.

### P00 – Ausgangszustand binden `[x]`

- [x] RC63/S16, Q17, Archiv-Hash und Release-ID gebunden.
- [x] PR #131, Review, vier Checks und Merge-Commit `e4e50bc7…` zurückgelesen.
- [x] Manifest, Phase-5-Itemisierung, Source-Qualification und Secret-Scan geprüft.
- [x] Fortschritt `90 %`, `1333/1400`, `67` offen bestätigt.

**Evidence:** Remote-Readback, `PROJECT_STATE.md`, Manifest und Verifierausgaben.

### P01 – Review am Kontroll-PR `[x]`

- [x] Review von `endzeit2030666-lang` am exakten PR-Kopf bestätigt.
- [x] Pflichtchecks `verify` und beide Vercel-Prüfungen erfolgreich.

### P02 – Review-Readback `[x]`

- [x] Reviewstatus `APPROVED` und PR-Kopf `fe03b118…` bestätigt.
- [x] Keine stale Review und keine Pflichtprüfung offen.
- [x] Aktueller Kontroll-Readback: PR #137 `APPROVED`, anschließend als Merge-Commit `cfc7c529…` gemergt.

### P03 – Merge in den Standardzweig `[x]`

- [x] PR #131 als normaler Merge-Commit zusammengeführt.
- [x] Neuer HEAD `e4e50bc7…` ist Vorfahr von PR-Kopf, S16 und Q17.
- [x] Keine Squash-/Rebase-Abstammung und keine Prozent-Promotion.
- [x] Aktueller Standardzweig-HEAD nach PR #137: `cfc7c529…`.

### P04 – Post-Merge-Qualifikation `[x]`

- [x] Projektmanifest: `PASS`, `overall=90`, source-bound.
- [x] Phase 5: `PASS`, `computed=89`, `credited=89`, `17/19`, `I1,I5` blockiert.
- [x] Five-axis audit: `PASS`, `MARKET_READY:false`.
- [x] Source-Qualification: `PASS`, `credit=0`, `rollout=false`.
- [x] Gitleaks: keine Secrets gefunden.

### P05 – GHCR-Readback `[~]`

- [x] Sechs Kandidaten-Images und zwölf Plattform-Digests read-only geprüft.
- [x] S16-Tag, Manifestbindung und OCI-Revisionen stimmen überein.
- [x] Receipt getrackt unter
  `docs/release-artifacts/prod-candidate-2026-09-12-local-rc63-evidence/registry/ghcr-candidate-readback.json`.
- [ ] Aktive External-Gate-Summary darf im No-Credit-Checkpoint nicht manuell auf
  `verified` gesetzt werden.

**Nicht-Claim:** Kein Registry-Write, kein Delete, keine Produktionspromotion.

### P06 – I1 Hosted Candidate Parity `[x]`

- [x] Frischer Codespace `rc63-i1-postmerge-20260915-4jpwpg49jj4qcjrr6` am Kontrollstand `cfc7c529…` bereitgestellt.
- [x] Digest-only-Stack mit sechs Diensten ohne Builds und Source-Mounts gestartet.
- [x] Port `8080` nur für den Verifier öffentlich freigegeben und danach privat gestellt.
- [x] Workflow `34986842543` erfolgreich: sechs Health-Readbacks, zwölf Plattform-Digests, HTTPS, SSE und Provenance.
- [x] Evidence-SHA `f061715c858bf344e025c9fdbb2df272f3bd6790432de0baeba65b09e87e7f38` gesichert.
- [x] Codespace beendet; keine Registry-/Provider-Writes und keine Secret-Ausgabe.
- [ ] Kein Credit/P5-Promotion: atomare I1+I5-Regel bleibt aktiv.

**Ergebnis:** I1 ist technisch bewiesen, bleibt bis zum gemeinsamen I1/I5-Übergang im Manifest blockiert.

### P07 – Aktuelle Vercel-Frontend-Evidence `[x] KONTROLLBELEG`

- [x] Canonical Alias `https://frontend-seven-psi-78.vercel.app` read-only geprüft.
- [x] Deployment-/Alias-Parität, 26 dynamische Routen, 2 Viewports, 52 Interaktionen und erlaubte Console-Ausnahmen geprüft.
- [x] Frontend-Evidence ist im Remote-Stand von PR #136 enthalten.
- [x] `production_release_claimed=false`; keine Gate- oder Prozent-Promotion.

**Nicht-Claim:** Dieser Kontrollbeleg allein schließt I5 nicht.

### P08 – Hosted-Control-Stand `[x]`

- [x] PR #131 enthält die RC63/S16-Kontrollkorrektur und den GHCR-Receipt.
- [x] Keine External-Gate- oder Prozent-Promotion im Merge enthalten.
- [x] PR #133 aktualisiert den RC63-Zielbericht; Remote-Merge `ce77f2d6…` bestätigt.

### P09 – OAuth-Konfiguration `[x] KONFIGURATION READ-BACK`

- [x] Architektur `cloudflare_native`, Callback und Scope `read:user` bestätigt.
- [x] Owner-Allowlist enthält die freigegebenen numerischen Identitäten `237145441` und `231157481`.
- [x] `/api/v1/auth/contract` meldet `owner_identity_allowlist_count=2` und `credential_issuance_ready=true`.
- [x] Keine Secretwerte, Codes, States, Cookies oder Tokens ausgegeben.

**Nicht-Claim:** Die Konfiguration ist bereit; I5 bleibt bis zum vollständigen source-gebundenen Live-Flow offen.

### P10 – Cloudflare-OAuth-Runtime `[~] SOURCE-MISMATCH`

- [x] Live Health und Auth-Contract read-only gelesen; keine Secret-Ausgabe.
- [x] Live Owner-Login für `GitHub #231157481` funktioniert.
- [ ] Aktuelle Runtime meldet Source `987871c4…`, während RC63/S16 `0e9c680c…` verlangt.
- [ ] Ein S16-Deploy mit der neuen Allowlist ist über den sanktionierten Deploypfad noch nicht source-konform möglich.

**Blocker:** Runtime, Frontend und RC63-Evidence müssen dieselbe Source-Epoche verwenden.

### P11 – I5 Production OAuth Identity `[~] BLOCKIERT`

- [x] Owner-Identität, Session-Kontinuität und `identity_verified=true` live beobachtet.
- [x] Alte Evidence enthält 16 Schritte und ist sanitisiert.
- [ ] Alte Evidence darf wegen Frontend-/Runtime-Hash- und Source-Mismatch nicht wiederverwendet werden.
- [ ] Neuer vollständiger 16-Schritte-Flow erforderlich: State-/Callback-Replay, Refresh-Rotation, Logout, Cookie-Flags, Audit-Reihenfolge und Redaction.
- [ ] `verify-production-auth-identity-evidence.ps1` muss am einheitlichen Source-Stand grün werden.

### P12 – Atomare Evidence-Promotion `[ ] GESPERRT`

- [ ] I1 und I5 müssen gleichzeitig source-bound und verifiergrün sein.
- [ ] Nur der vorgesehene Promoter darf `live_verified=true` setzen.
- [ ] Keine Zwischenwerte und keine manuelle Änderung an Manifest, Ledger oder Gates.
- [ ] Zulässiger Übergang erst: `44→100`, `89→100`, `17/19→19/19`, `1333→1400`.

### P13 – Finaler Market-Ready-Verifier `[ ] GESPERRT`

- [ ] Frischen Checkout vom dann aktuellen Standardzweig verwenden.
- [ ] Alle Source-, Evidence-, Provider- und External-Gate-Readbacks wiederholen.
- [ ] Erst dann `verify-market-ready.ps1 -IncludeExternalGates -RequireReady` ausführen.
- [ ] Erfolg ausschließlich bei Exitcode `0`, `MARKET_READY:true`, `1400/1400` und
  `I1/I5 verified` melden.

### P14 – Cleanup und Freeze `[ ] GESPERRT`

- [ ] Codespace und öffentlicher Port schließen.
- [ ] Rollback-IDs und aktuelle Evidence-Hashes erhalten.
- [ ] Keine geschützte Evidence löschen.
- [ ] Finalen Remote-HEAD und sauberen Arbeitsbaum readbacken.

## 4. Ergänzungsfelder

Nach jedem Hauptpunkt kann eine Ergänzung angehängt werden. Hauptnummern ändern sich
dabei nicht.

> **Ergänzung E<HAUPTPUNKT>-<NUMMER>**
> Grund: ___
> Abweichung/Erkenntnis: ___
> Betroffene Gates: ___
> Zusätzliche Handlung: ___
> Prüfung und Evidence-Hash: ___
> Auswirkung auf den nächsten Punkt: ___
> Status: `[ ] OFFEN` / `[x] ERLEDIGT`

## 5. Aktueller nächster Schritt

P06 und P07 sind technisch nachgewiesen. Der nächste zulässige Punkt ist P11: ein neuer vollständiger I5-Flow auf einer einheitlichen Source-Epoche. Bis Runtime, Frontend und RC63/S16-Evidence source-gebunden übereinstimmen, bleiben P12–P14 gesperrt und der bestätigte Stand bleibt unverändert bei `90 %`, `1333/1400`, `MARKET_READY:false`.

## 6. Änderungslog

| Datum | Änderung | Beleg |
|---|---|---|
| 15.09.2026 | Zielverfolgung auf Merge-HEAD `e4e50bc7…` gebunden | Remote-Readback, PR #131 |
| 15.09.2026 | I1-Timeout und stale Codespaces-Evidence dokumentiert | Run `34884107604`, URL-Readback `404` |
| 15.09.2026 | Stale I5-Frontend-Bindung dokumentiert | alter `dpl_AZK…`, aktueller Alias-Readback |
| 15.09.2026 | Zielbericht in PR #132 gemergt; alle vier PR-Checks, Manifest, Phase 5, Five-Axis und Gitleaks erneut grün | Merge-HEAD `8ac2dabb…` |
| 15.09.2026 | Aktueller Codespaces-Readback: nur alter fremder Shutdown-Codespace; kein neuer I1-Start ohne Kosten-/Kontingentbeleg | GitHub Codespaces API-Readback |
| 15.09.2026 | PR #133 gemergt und Remote-HEAD `ce77f2d6…` bestätigt | GitHub PR-/Branch-Readback |
| 15.09.2026 | Vercel-Redeploy `dpl_CQVsh…`, Alias-Bindung und neue 26×2-Hosted-Evidence erzeugt; keine Credit-/Gate-Promotion | Provider-Readback, Browser-Evidence, Commit `8ca44211…` |
| 15.09.2026 | PR #135 Owner-Allowlist und PR #136 Frontend-Evidence gemergt; Remote-HEAD `5b117aef…` bestätigt | GitHub-Readback |
| 15.09.2026 | PR #137 gemergt; neuer Kontroll-HEAD `cfc7c529…`; I1-Readback danach erneut ausgeführt | GitHub-Readback |`n| 15.09.2026 | P06/I1 fresh Codespaces verifier `34986842543` erfolgreich; Evidence-SHA `f061715c…` | GitHub Actions, Port privat, Codespace beendet |
