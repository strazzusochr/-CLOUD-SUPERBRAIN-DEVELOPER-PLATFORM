# RC63/S16 – aktuelle Zielverfolgung bis Market Ready

**Dokumentstatus:** aktiv, evidence-gebunden, fortschreibbar
**Stand:** 15.09.2026
**Aktueller bestätigter Marktstatus:** `MARKET_READY:false`

Dieses Dokument ist der aktive Einstieg für die Zielverfolgung. Verbindliche Prozentwerte
und Gate-Wahrheiten kommen weiterhin ausschließlich aus den Manifesten und den
Verifiern. Dieses Dokument darf keine Prozentwerte, `live_verified`-Felder oder
Produktionsfreigaben manuell ändern.

## 1. Gebundene Identität

| Feld | Aktueller Wert |
|---|---|
| Standardzweig | `chore/repo-bootstrap` |
| bestätigter Remote-HEAD | `e4e50bc7eb6a396c63d268e729a877d6203ce80c` |
| letzter Merge | PR #131, normaler Merge-Commit |
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

### P03 – Merge in den Standardzweig `[x]`

- [x] PR #131 als normaler Merge-Commit zusammengeführt.
- [x] Neuer HEAD `e4e50bc7…` ist Vorfahr von PR-Kopf, S16 und Q17.
- [x] Keine Squash-/Rebase-Abstammung und keine Prozent-Promotion.

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

### P06 – I1 Hosted Candidate Parity `[~] BLOCKIERT`

- [x] Historischer I1-Run `34884107604` war technisch erfolgreich.
- [ ] Historischer Run ist nicht mehr gültig: Control-SHA `057a0b9…` ist nicht der
  aktuelle Kontrollstand `e4e50bc7…`.
- [ ] Die gespeicherte Codespaces-URL liefert inzwischen `404`.
- [ ] Frischen Codespace am aktuellen Standardzweig bereitstellen.
- [ ] `.devcontainer/i1-codespaces/devcontainer.json` verwenden.
- [ ] Digest-only-Stack mit sechs Diensten, ohne Build und ohne Source-Mount starten.
- [ ] Port `8080` nur für die Evidence-Erzeugung öffentlich freigeben.
- [ ] Workflow mit aktuellem `control_sha=e4e50bc7…` starten.
- [ ] Sechs Health-Readbacks, zwölf Plattform-Digests, HTTPS, SSE und Provenance
  zurücklesen.
- [ ] Port wieder privat stellen und Codespace stoppen.

**Aktueller Abbruch:** Ein frischer Codespace wurde versucht, blieb bei
`Provisioning` hängen und wurde nach Timeout gelöscht. Der alte fremde Codespace
bleibt unangetastet. I1 erhält deshalb keinen Credit.

### P07 – Aktuelle Vercel-Frontend-Evidence `[~] BLOCKIERT FÜR I5`

- [x] Canonical Alias `https://frontend-seven-psi-78.vercel.app` ist bekannt.
- [ ] Frontend-Evidence am aktuell gebundenen Alias neu erzeugen.
- [ ] Deployment-ID, Alias-Parität, Source-SHA, 26 Routen, zwei Viewports und
  null erlaubte Konsolenfehler neu readbacken.
- [ ] Keine Produktionsfreigabe aus der Frontend-Evidence ableiten.

**Stale-Befund:** Die alte OAuth-Evidence referenziert `dpl_AZK…`; der aktuelle
Alias-Readback zeigt `dpl_oEArn9VcPZU5nL3VaJeknJ64U2Hf`. Die alte Evidence darf nicht
umgeschrieben, sondern muss durch einen neuen source-bound Beleg ersetzt werden.

### P08 – Hosted-Control-Stand `[x]`

- [x] PR #131 enthält die RC63/S16-Kontrollkorrektur und den GHCR-Receipt.
- [x] Keine External-Gate- oder Prozent-Promotion im Merge enthalten.

### P09 – OAuth-Konfiguration `[~] OWNER-BLOCKIERT`

- [x] Architektur `cloudflare_native`, Callback und Scope sind festgelegt.
- [ ] Numerische Owner-Allowlist für das tatsächlich autorisierende Konto prüfen.
- [ ] `GITHUB_OAUTH_OWNER_IDS` darf nur über den freigegebenen Provider-Kanal geändert
  werden.
- [ ] Keine Secretwerte, Codes, States, Cookies oder Tokens in Chat, Git oder Evidence.

Der beobachtete Fehler `github_owner_identity_not_allowed` ist ein Konfigurations-
oder Allowlist-Problem, kein Grund für eine manuelle Gate-Öffnung.

### P10 – Cloudflare-OAuth-Runtime `[~]`

- [x] Source-bound Runtime-Evidence für S16 vorhanden.
- [x] Cloudflare-Readback ist schreibfrei und ohne Secret-Ausgabe.
- [ ] Bei Konfigurationsänderung zuerst `ValidateOnly`, danach `DryRun`, danach
  Deployment-ID und Health readbacken.
- [ ] Rollback-Ziel vor jeder Runtime-Änderung protokollieren.

### P11 – I5 Production OAuth Identity `[~] BLOCKIERT`

- [x] Alte Evidence enthält 16 Flow-Schritte und ist sanitisiert.
- [ ] Alte Evidence nicht wiederverwenden: der aktuelle dynamische Frontend-Readback
  schlägt mit `Canonical hosted frontend dynamic validation failed` fehl.
- [ ] Neue Frontend-Evidence und neue OAuth-Evidence am aktuellen Alias erzeugen.
- [ ] Owner-Identity, State-Replay, Callback-Replay, Refresh-Rotation, Logout,
  Cookie-Flags, Audit-Reihenfolge und Redaction erneut prüfen.
- [ ] Neue Evidence mit `verify-production-auth-identity-evidence.ps1` verifizieren.

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

Der nächste technisch zulässige Punkt ist **P06: frische I1-Evidence**. Dafür wird eine
erreichbare Codespaces-URL am aktuellen Kontrollstand benötigt. Parallel darf P07/P11
nur mit einem neuen Vercel- und OAuth-Readback fortgesetzt werden. Bis beide Nachweise
vorliegen, bleiben P12–P14 gesperrt und der bestätigte Stand bleibt unverändert bei
`90 %`, `1333/1400`, `MARKET_READY:false`.

## 6. Änderungslog

| Datum | Änderung | Beleg |
|---|---|---|
| 15.09.2026 | Zielverfolgung auf Merge-HEAD `e4e50bc7…` gebunden | Remote-Readback, PR #131 |
| 15.09.2026 | I1-Timeout und stale Codespaces-Evidence dokumentiert | Run `34884107604`, URL-Readback `404` |
| 15.09.2026 | Stale I5-Frontend-Bindung dokumentiert | alter `dpl_AZK…`, aktueller Alias-Readback |
