# RC62 Masterprotokoll

Stand: 2026-09-12
Status: E04-03 erledigt; E04-01 aktiv; E04-02/E04-04 bis zur neuen Kandidatenqualifikation blockiert; P05 gesperrt.
Ziel: `MARKET_READY:true`, `100%`, `1400/1400`, I1 und I5 verifiziert.

## Unveränderliche Identität

| Feld | Wert |
| --- | --- |
| Pull Request | `#110` |
| Release-ID | `prod-candidate-2026-09-11-local-rc62` |
| Produktquelle S15 | `63c854867cb1082c209718b64fddcbb52e5dd99b` |
| Qualifikationsnachfolger Q16 | `f3faff1d96aeb56d89b122cb0b4069e4c1618e7f` |
| Finaler PR-Kopfstand | `d321fcdffbc2ebad43981232895e71290ecb050a` |
| Merge-/Kontroll-SHA nach PR #110 | `cbb3d1e9ffa3663d756be70216fcd59139c7b685` |
| S15-Archiv-SHA-256 | `22a6083470db47f9691993e86b6a9a11581baebe458f7c0fc534892b404840f0` |
| Standardzweig | `chore/repo-bootstrap` |
| OAuth-Architektur | `cloudflare_native` |
| OAuth-Callback | `https://frontend-seven-psi-78.vercel.app/api/v1/auth/callback` |
| OAuth-Scope | `read:user` |

Wenn Release-ID, S15, Q16 oder Archivhash abweichen, bleibt jeder Folgepunkt gesperrt.

## Status- und Hakenregel

- `[ ] OFFEN`: noch nicht begonnen.
- `[ ] AKTIV`: wird geprüft oder ausgeführt.
- `[ ] BLOCKIERT`: eine Vorbedingung oder ein erwarteter Beweis fehlt.
- `[x] ERLEDIGT`: Handlung, Readback, Evidence, Hash und Regressionstest sind vollständig.
- `[x] ENTFÄLLT`: nur mit dokumentierter Begründung und Abhängigkeitsbeweis.

Ein Haken setzt unmittelbar geprüfte Vorbedingungen, protokollierte Eingaben,
vollständige Ausführung, Readback aus dem Zielsystem, gehashte Evidence,
Regressionstest aller vorher grünen Gates und den benannten nächsten Punkt voraus.
Absicht, Button-Verfügbarkeit, gestarteter Workflow oder grüne Teilprüfung reichen nicht.

Kanonische Evidence-Hashes werden aus den Git-Blobbytes berechnet. Ein davon
abweichender Windows-Arbeitsbaumhash durch CRLF wird als Transportdarstellung
protokolliert und darf weder als Git-Drift noch als kanonischer Evidence-Hash gelten.

## Gate-Lock-Inhalt

Vor und nach Review, Merge, Veröffentlichung oder Provideränderung werden mindestens
Arbeitsbaum, Zweig, lokaler/entfernter HEAD, Standardzweig-HEAD, PR-/Review-/CI-Status,
Release-ID, S15, Q16, Archivhash, Fortschritt, P0-P6, sieben Layer, Phase-5-Items,
Capability-Gates, External-Gates, `MARKET_READY`, Secret-Scan, geschützte Evidence,
Provider-Deployment-IDs und Rollback-Ziel gelesen. Nicht erlaubte Differenzen stoppen.

## Aktueller Gesamtstand

- Overall `90%`
- Horizontal P0-P6 `100/100/100/44/100/89/100` = `633/700`
- Vertikal sieben Layer jeweils `100` = `700/700`
- Gesamt `1333/1400`, `67` offen
- Phase 5 `17/19`, Blocker `I1,I5`
- `MARKET_READY:false`
- Keine Registry-Publikation und keine Produktions-OAuth-Identity für RC62 behauptet

## P00 – Ausgangszustand vollständig binden

- [x] P00.01 Arbeitsverzeichnis `D:\_sb_tmp\rc62-requalify-26-page-fix` bestätigt.
- [x] P00.02 Zweig `codex/rc62-requalify-26-page-fix` bestätigt.
- [x] P00.03 Lokalen HEAD `d321fcd...` bestätigt.
- [x] P00.04 Remote-Upstream `d321fcd...` bestätigt.
- [x] P00.05 Sauberen Arbeitsbaum bestätigt.
- [x] P00.06 PR #110 offen und kein Draft bestätigt.
- [x] P00.07 PR technisch `MERGEABLE` bestätigt.
- [x] P00.08 Fehlende Review als damaligen Blocker bestätigt.
- [x] P00.09 Damals keine Review vorhanden bestätigt.
- [x] P00.10 Pflichtprüfung `verify=SUCCESS` bestätigt.
- [x] P00.11 Beide damaligen Vercel-Preview-Statusprüfungen grün.
- [x] P00.12 Kilo `ACTION_REQUIRED` als nicht verpflichtend bestätigt.
- [x] P00.13 64 geänderte Dateien und relevante Codeänderungen geprüft.
- [x] P00.14 Dynamische 26-Routen-Regel geprüft.
- [x] P00.15 Run-Detail-404-Ausnahme als eng korreliert geprüft.
- [x] P00.16 Keine globale Abschwächung von Fehlerregeln festgestellt.
- [x] P00.17 `git diff --check` grün.
- [x] P00.18 S15/Q16/Release-/Archivbindung geprüft.
- [x] P00.19 Phase 5 `17/19`, `89%`, `I1,I5` bestätigt.
- [x] P00.20 Hosted-Health-404 als externen damaligen Blocker dokumentiert.
- [x] P00.21 `90%`, `1333/1400`, `67` offen bestätigt.
- [x] P00.22 Sieben vertikale Layer jeweils `100%` bestätigt.
- [x] P00.23 `MARKET_READY:false` bestätigt.
- [x] P00.24 Keine Projektdatei während P00 verändert.
- [x] P00.25 P01 als nächsten Punkt festgelegt.

## P01 – Review mit `endzeit2030666-lang`

- [x] P01.01 Endzeit-Konto in Edge bestätigt.
- [x] P01.02 PR #110 geöffnet.
- [x] P01.03 `Files changed` geöffnet.
- [x] P01.04 `Review changes` geöffnet.
- [x] P01.05 `Approve` auswählbar bestätigt.
- [x] P01.06 Auditkommentar war optional und für die Freigabe nicht erforderlich.
- [x] P01.07 `Approve` ausgewählt.
- [x] P01.08 Review gesendet.
- [x] P01.09 Vor dem unabhängigen Readback nicht gemerged.
- [x] P01.10 `Review gesendet` zurückgemeldet.
- [x] P01.11 Abschluss erst nach P02 gesetzt.

## P02 – Review unabhängig zurücklesen

- [x] P02.01 PR-HEAD erneut aus GitHub gelesen.
- [x] P02.02 PR-HEAD weiterhin `d321fcd...`.
- [x] P02.03 Autor `endzeit2030666-lang`.
- [x] P02.04 Zustand `APPROVED`.
- [x] P02.05 Review nach letztem Push und an exaktem Commit.
- [x] P02.06 Pflichtprüfung `verify=SUCCESS`.
- [x] P02.07 Keine ungelöste Diskussion; Thread-Anzahl `0`.
- [x] P02.08 `REVIEW_REQUIRED` aufgehoben.
- [x] P02.09 Kilo erneut als nicht verpflichtend geprüft.
- [x] P02.10 Gate-Lock mit P00 verglichen.
- [x] P02.11 Ausschließlich Reviewstatus änderte sich.
- [x] P02.12 Review-URL und Zeit `2026-09-12T13:15:53Z` gelesen.
- [x] P02.13 P01 und P02 geschlossen.

## P03 – PR mit Merge-Commit zusammenführen

- [x] P03.01 `GATE_LOCK_BEFORE` grün.
- [x] P03.02 P02 vollständig geschlossen.
- [x] P03.03 Geschützte Standardzweigänderung durch Masterplan freigegeben.
- [x] P03.04 GitHub-Konto `strazzusochr` bestätigt.
- [x] P03.05 Merge-Operation vorbereitet.
- [x] P03.06 Ausschließlich Merge-Commit verwendet.
- [x] P03.07 Squash und Rebase ausgeschlossen.
- [x] P03.08 Merge am exakten PR-HEAD bestätigt.
- [x] P03.09 PR-Status aus GitHub zurückgelesen.
- [x] P03.10 PR #110 ist `MERGED`.
- [x] P03.11 Standardzweig-HEAD `cbb3d1e9...` protokolliert.
- [x] P03.12 `d321fcd...` ist Vorfahre.
- [x] P03.13 Q16 ist Vorfahre.
- [x] P03.14 S15 ist Vorfahre.
- [x] P03.15 Release-ID und Archivhash erneut gelesen.
- [x] P03.16 Keine automatische Kandidaten-/Prozentänderung.
- [x] P03.17 `GATE_LOCK_AFTER` ausgeführt.
- [x] P03.18 Nur PR-Status und Merge-Commit änderten sich.
- [x] P03.19 `cbb3d1e9ffa3663d756be70216fcd59139c7b685` als Kontroll-SHA.

## P04 – RC62 nach Merge vollständig nachqualifizieren

- [x] P04.01 Frischer Arbeitsbaum `D:\_sb_tmp\rc62-post-merge-qualification`.
- [x] P04.02 Arbeitsbaum sauber und am Merge-Commit abgetrennt.
- [x] P04.03 Release-Kandidat gelesen.
- [x] P04.04 S15/Q16-/Archiv-Abstammung geprüft.
- [x] P04.05 Phase-5-Credit-Verifier ausgeführt.
- [x] P04.06 Ergebnis exakt `89%`, `17/19`, `I1,I5`.
- [x] P04.07 Fortschrittsmanifest verifiziert.
- [x] P04.08 Source-Qualification-Control verifiziert.
- [x] P04.09 Statische Market-Ready-Prüfung ausgeführt; vor/nach Merge identisch `INVALID` wegen veralteter Owner-/Gate-Aggregation, ohne Readiness-Claim; E04-02 eröffnet.
- [x] P04.10 Gitleaks ohne Fund.
- [x] P04.11 297 PowerShell-Skripte syntaktisch grün.
- [x] P04.12 24 kritische Python-Dateien syntaktisch grün.
- [x] P04.13 34 I1-/OAuth-Vertragstests bestanden.
- [x] P04.14 Exact-Head-CI Run `34696298574`, Job `103560257339`, grün.
- [x] P04.15 Capability-Gates gegen P00 verglichen.
- [x] P04.16 Layerwerte gegen P00 verglichen.
- [x] P04.17 Keine Prozentänderung.
- [x] P04.18 Kontroll-Snapshot und kanonische Git-Blob-Hashes geprüft.
- [x] P04.19 P05 bleibt bis zu E04-01, E04-02 und der dadurch erforderlichen neuen Kandidatenqualifikation gesperrt.

## P05 – Sechs private S15-Abbilder in GHCR veröffentlichen

- [ ] P05.01 Gate-Lock einschließlich Registry-Stand.
- [ ] P05.02 O3-Freigabe exakt an S15 und sechs Images binden.
- [ ] P05.03 Workflow `main-deploy` am aktuellen Standardzweig wählen.
- [ ] P05.04 `candidate_sha` exakt S15.
- [ ] P05.05 Workflow als `strazzusochr` starten.
- [ ] P05.06 Preflight bestätigt Release-ID, S15, Kontroll-SHA und Abstammung.
- [ ] P05.07 Alle sechs Pakete vor Push als privat lesen.
- [ ] P05.08 Bei public/internal vor Push stoppen.
- [ ] P05.09 Sichtbarkeitskorrektur gegebenenfalls als Ergänzung dokumentieren.
- [ ] P05.10 Auf menschliche Environment-Freigabe warten.
- [ ] P05.11 Anforderung in Edge als `endzeit2030666-lang` öffnen.
- [ ] P05.12 Run, Repository, S15 und Workflow prüfen.
- [ ] P05.13 Environment-Freigabe erteilen.
- [ ] P05.14 Sechs Images bauen oder unveränderlich wiedererkennen.
- [ ] P05.15 Keinen vorhandenen S15-Tag überschreiben.
- [ ] P05.16 Zwölf Plattform-Digests prüfen.
- [ ] P05.17 Trivy vollständig grün.
- [ ] P05.18 OCI-Revision jedes Images gleich S15.
- [ ] P05.19 Candidate-Manifest herunterladen und hashen.
- [ ] P05.20 Publication Receipt herunterladen und hashen.
- [ ] P05.21 Run-ID und Attempt protokollieren.
- [ ] P05.22 Kein Release-Tag und keine Produktionspromotion.
- [ ] P05.23 `secret_output=false`.
- [ ] P05.24 `GATE_LOCK_AFTER` vergleichen.
- [ ] P05.25 Alle zuvor grünen Gates unverändert.
- [ ] P05.26 Erst nach vollständigem Remote-Readback schließen.

## P06 – I1 Digest-only in Codespaces prüfen

- [ ] P06.01 Verbleibende kostenlose Codespaces-Nutzung prüfen.
- [ ] P06.02 Keine Zahlung oder automatische Mehrverbrauchsfreigabe.
- [ ] P06.03 Bei erschöpfter Inklusivnutzung blockieren.
- [ ] P06.04 Codespace am exakten Kontroll-SHA öffnen.
- [ ] P06.05 Arbeitsbaum und Kontroll-SHA prüfen.
- [ ] P06.06 Privaten GHCR-Lesezugriff prüfen.
- [ ] P06.07 Exaktes P05-Manifest laden.
- [ ] P06.08 Manifesthash mit P05 vergleichen.
- [ ] P06.09 Statischen I1-Verifier ausführen.
- [ ] P06.10 Sechs Images ausschließlich per Digest konfigurieren.
- [ ] P06.11 `--no-build` erzwingen.
- [ ] P06.12 Keine Quellcode-Mounts.
- [ ] P06.13 Keine lokalen Docker-Builds.
- [ ] P06.14 Sechs gesunde Dienste abwarten.
- [ ] P06.15 Runtime-Provenance erzeugen.
- [ ] P06.16 Port 8080 weiterleiten.
- [ ] P06.17 Internes Portprotokoll HTTP.
- [ ] P06.18 Port vorübergehend Public.
- [ ] P06.19 Öffentliche HTTPS-URL zurücklesen.
- [ ] P06.20 Read-only-Abfragen ohne Anmeldung erreichbar.
- [ ] P06.21 Workflow `i1-codespaces-candidate-verify` starten.
- [ ] P06.22 Release-ID exakt RC62.
- [ ] P06.23 Source SHA exakt S15.
- [ ] P06.24 Control SHA exakt aktuell.
- [ ] P06.25 P05-Run-ID und Attempt übernehmen.
- [ ] P06.26 P05-Artefaktname exakt übernehmen.
- [ ] P06.27 Sechs Dienste HTTP-gesund.
- [ ] P06.28 Digests stimmen mit Manifest überein.
- [ ] P06.29 OCI-Revisionen melden S15.
- [ ] P06.30 Same-Origin-HTTPS funktioniert.
- [ ] P06.31 SSE funktioniert.
- [ ] P06.32 Persistenzoberfläche vertragsgemäß erreichbar.
- [ ] P06.33 `registry_write_performed=false`.
- [ ] P06.34 `live_provider_calls=false`.
- [ ] P06.35 `production_deploy=false`.
- [ ] P06.36 `secret_output=false`.
- [ ] P06.37 I1-Evidence herunterladen und hashen.
- [ ] P06.38 Port wieder Private.
- [ ] P06.39 Codespace stoppen.
- [ ] P06.40 Öffentliche URL anschließend unerreichbar.
- [ ] P06.41 Vorher grüne Gates regressionsprüfen.
- [ ] P06.42 Erst danach schließen.

## P07 – RC62-Frontend auf Vercel nachweisen

- [ ] P07.01 Gate-Lock mit aktueller Deployment-ID.
- [ ] P07.02 Letztes funktionsfähiges Deployment als Rollback-Ziel.
- [ ] P07.03 Deploy an S15 und Nicht-Release-Zweck binden.
- [ ] P07.04 Projekt exakt `frontend`.
- [ ] P07.05 Scope entspricht getracktem Projekt.
- [ ] P07.06 Quelle S15 oder erlaubter Qualifikationsnachfolger.
- [ ] P07.07 Keine fremden lokalen Dateien.
- [ ] P07.08 Build und Frontend-Audit vor Deploy.
- [ ] P07.09 Secret-Scan vor Deploy.
- [ ] P07.10 Produktionsbetriebsdeploy starten.
- [ ] P07.11 Providerstatus `READY`.
- [ ] P07.12 Deployment-ID zurücklesen.
- [ ] P07.13 Git-Quellbindung aus Metadaten.
- [ ] P07.14 Kanonischen Alias an Deployment binden.
- [ ] P07.15 Aliasbindung aus Provider-Metadaten lesen.
- [ ] P07.16 Immutable Origin und Aliasinhalt vergleichen.
- [ ] P07.17 Frontend-Hosted-Verifier.
- [ ] P07.18 22 kanonische UI-Oberflächen prüfen.
- [ ] P07.19 Alle 26 dynamischen Arbeitsbereichsrouten prüfen.
- [ ] P07.20 Desktop- und Mobile-Viewport.
- [ ] P07.21 Keine nicht erlaubten Konsolenfehler.
- [ ] P07.22 Keine Overflow-/Overlay-Kollisionen.
- [ ] P07.23 Auth-Routen über Frontend-Origin.
- [ ] P07.24 Keine OAuth-/JWT-Secrets im Frontend.
- [ ] P07.25 `production_operational_deploy_verified=true` zulässig.
- [ ] P07.26 `production_release_claimed=false` bleibt.
- [ ] P07.27 Frontend-Evidence hashen.
- [ ] P07.28 `GATE_LOCK_AFTER`.
- [ ] P07.29 Bei Regression Alias auf Rollback-Deployment.
- [ ] P07.30 Rollback als Ergänzung; bis erneuter Prüfung blockiert.

## P08 – Ersten RC62-Hosted-Control-PR erstellen und mergen

- [ ] P08.01 Zweig `codex/rc62-hosted-controls` vom dann aktuellen Standardzweig.
- [ ] P08.02 Ausschließlich geprüfte Evidence P05-P07 übernehmen.
- [ ] P08.03 Jeden Evidence-Hash neu berechnen.
- [ ] P08.04 GHCR-Manifest und Publication Receipt binden.
- [ ] P08.05 I1-Evidence an S15 und GHCR-Run binden.
- [ ] P08.06 Frontend-Evidence an Vercel-Deployment-ID binden.
- [ ] P08.07 Auth-Architektur an S15 und Callback binden.
- [ ] P08.08 External-Gate-Summary aktualisieren.
- [ ] P08.09 `production_auth_identity.live_verified=false` belassen.
- [ ] P08.10 P3 bei `44` belassen.
- [ ] P08.11 P5 bei `89` belassen.
- [ ] P08.12 Overall bei `90%` belassen.
- [ ] P08.13 `MARKET_READY:false` belassen.
- [ ] P08.14 Nur explizite Pfade stagen.
- [ ] P08.15 Secret-Scan.
- [ ] P08.16 Evidence-Verifier.
- [ ] P08.17 Manifest-Replay.
- [ ] P08.18 Vollständige PR-CI.
- [ ] P08.19 Review am finalen Kopfstand.
- [ ] P08.20 Review per GitHub-Readback.
- [ ] P08.21 Mit Merge-Commit zusammenführen.
- [ ] P08.22 S15-Abstammung prüfen.
- [ ] P08.23 Neuen Evidence-Kontroll-SHA protokollieren.
- [ ] P08.24 Vollständiger Gate-Lock-Vergleich.

## P09 – Produktions-OAuth und Secrets sicher konfigurieren

- [ ] P09.01 Owner-Freigabe für Secretrotation und Konfiguration binden.
- [ ] P09.02 OAuth-Anwendung über nicht geheime Metadaten identifizieren.
- [ ] P09.03 Callback exakt mit kanonischem Vercel-Callback vergleichen.
- [ ] P09.04 Scope exakt `read:user`.
- [ ] P09.05 Keine E-Mail-, Repository- oder Organisationsberechtigung.
- [ ] P09.06 Früher offengelegtes Secret als kompromittiert behandeln.
- [ ] P09.07 Altes Secret in GitHub widerrufen.
- [ ] P09.08 Neues Secret direkt in GitHub erzeugen.
- [ ] P09.09 Secret niemals in Chat kopieren.
- [ ] P09.10 Secret niemals in Repository-Datei schreiben.
- [ ] P09.11 Secret direkt als verschlüsseltes Worker-Secret setzen.
- [ ] P09.12 Starken JWT-Signierschlüssel direkt beim Provider setzen.
- [ ] P09.13 Keine OAuth-/JWT-Secrets an Vercel.
- [ ] P09.14 Numerische Owner-ID-Allowlist prüfen.
- [ ] P09.15 Nicht geheimen Konfigurationsvertrag read-only abrufen.
- [ ] P09.16 Erforderliche Namen als konfiguriert gemeldet.
- [ ] P09.17 Kein Secretwert im Vertrag.
- [ ] P09.18 Ausgaben auf Redaction prüfen.
- [ ] P09.19 Keine Gate-Promotion.
- [ ] P09.20 Nur nicht geheime Bestätigungen protokollieren.

## P10 – Cloudflare-Produktions-OAuth-Runtime aus S15 deployen

- [ ] P10.01 Gate-Lock mit Worker-Version und Deployment-ID.
- [ ] P10.02 Letzte gesunde Version als Rollback-Ziel.
- [ ] P10.03 Produktionsdeploy-Freigabe exakt an S15.
- [ ] P10.04 Nur sanktioniertes Deployment-Skript.
- [ ] P10.05 `CommitSha` exakt S15.
- [ ] P10.06 Modus `ProductionOAuthIdentity`.
- [ ] P10.07 Frontend-Origin exakt kanonischer Vercel-Alias.
- [ ] P10.08 Evidence-Control-SHA aus P08.
- [ ] P10.09 Zuerst `ValidateOnly`.
- [ ] P10.10 Danach Dry-Run.
- [ ] P10.11 Source-Archivhash prüfen.
- [ ] P10.12 Upload-Bundle-Hash prüfen.
- [ ] P10.13 Frontend-Source-Abstammung prüfen.
- [ ] P10.14 Callback-Bindung prüfen.
- [ ] P10.15 D1-Binding prüfen.
- [ ] P10.16 Durable-Object-Binding prüfen.
- [ ] P10.17 Queue/Vector/Workers-AI auf unerwünschte Änderung prüfen.
- [ ] P10.18 R2 deaktiviert.
- [ ] P10.19 Remote-Secrets erhalten.
- [ ] P10.20 Produktionsdeploy ausführen.
- [ ] P10.21 Worker-Version-ID lesen.
- [ ] P10.22 Deployment-ID lesen.
- [ ] P10.23 Deployment zu 100% auf neue Version.
- [ ] P10.24 `/api/v1/health=200`.
- [ ] P10.25 Health meldet S15.
- [ ] P10.26 Health meldet erwartete Archiv-/Bundle-Hashes.
- [ ] P10.27 Auth-Vertrag credential-ready.
- [ ] P10.28 Anonymes `/api/v1/auth/me=401`.
- [ ] P10.29 Identity-Projektion zählt nicht als Login-Erfolg.
- [ ] P10.30 Keine Prozent-/Gate-Promotion.
- [ ] P10.31 `secret_output=false`.
- [ ] P10.32 Gate-Lock-Vergleich.
- [ ] P10.33 Bei Regression sofort Rollback.
- [ ] P10.34 Nach Rollback alle Readbacks wiederholen.
- [ ] P10.35 Nur bei vollständig gesunder S15-Runtime schließen.

## P11 – I5 Produktions-OAuth in 16 Schritten beweisen

- [ ] P11.01 Browserprofil ohne Superbrain-Session.
- [ ] P11.02 Anonym: keine Identity, erwartetes `401`.
- [ ] P11.03 GitHub-Start auslösen.
- [ ] P11.04 Redirect `303`.
- [ ] P11.05 Host, Querykeys, Callback und Scope prüfen.
- [ ] P11.06 Ersten Flow abbrechen.
- [ ] P11.07 Abbruch endet ohne Credentials.
- [ ] P11.08 Verbrauchten State erneut testen; Ablehnung.
- [ ] P11.09 Neuen Flow für Familie A.
- [ ] P11.10 Owner-Zugriff autorisieren.
- [ ] P11.11 Callback konsumiert State genau einmal.
- [ ] P11.12 Audit vor Cookie-/Credential-Ausgabe persistiert.
- [ ] P11.13 `/auth/me` bestätigt erlaubte Owner-Identity.
- [ ] P11.14 Reload und Sitzungskontinuität.
- [ ] P11.15 Refresh Familie A.
- [ ] P11.16 Genau eine atomare Rotation erfolgreich.
- [ ] P11.17 Alten Refresh wiederverwenden.
- [ ] P11.18 Alter Refresh `401` und Familie gesperrt.
- [ ] P11.19 Alten Callback wiederverwenden.
- [ ] P11.20 Callback-Replay `401`, keine Credentials.
- [ ] P11.21 Neuen unabhängigen Flow B.
- [ ] P11.22 Owner erneut autorisieren.
- [ ] P11.23 Unabhängigen Callback prüfen.
- [ ] P11.24 Familien A und B verschieden.
- [ ] P11.25 Logout Familie B.
- [ ] P11.26 Widerruf und Cookie-Clear.
- [ ] P11.27 Refresh nach Logout.
- [ ] P11.28 Refresh nach Logout `401`.
- [ ] P11.29 Genau vier GitHub-Provideraufrufe.
- [ ] P11.30 Genau zwölf definierte menschliche Klicks.
- [ ] P11.31 Scope exakt `read:user`.
- [ ] P11.32 Provider-Schreibzugriffe null.
- [ ] P11.33 Deployment-Schreibzugriffe im Verifier null.
- [ ] P11.34 Localhost-Nutzung null.
- [ ] P11.35 Cookie-Flags `Secure`, `HttpOnly`, `__Host-`, `Path=/`.
- [ ] P11.36 SameSite-Regeln prüfen.
- [ ] P11.37 Audit-Reihenfolge prüfen.
- [ ] P11.38 Korrelation nur gehasht.
- [ ] P11.39 Rohdaten auf Codes, States, Tokens, Cookies und IDs scannen.
- [ ] P11.40 Sanitized Flow-Evidence.
- [ ] P11.41 Cloudflare-Runtime-Evidence.
- [ ] P11.42 Production-Auth-Identity-Evidence.
- [ ] P11.43 Alle drei Dateien hashen.
- [ ] P11.44 Read-only Evidence-Verifier.
- [ ] P11.45 Noch keine Gate-Promotion.
- [ ] P11.46 Vorher grüne Gates regressionsprüfen.

## P12 – I1 und I5 atomar in Fortschritt übernehmen

- [ ] P12.01 Zweig `codex/rc62-market-ready-evidence` vom aktuellen Standardzweig.
- [ ] P12.02 I1-Evidence P06.
- [ ] P12.03 GHCR-Evidence P05.
- [ ] P12.04 Frontend-Evidence P07/P08.
- [ ] P12.05 I5-Flow-Evidence P11.
- [ ] P12.06 Auth-Runtime-Evidence P11.
- [ ] P12.07 Production-Auth-Identity-Evidence P11.
- [ ] P12.08 Exact-Head-CI-Attestation binden.
- [ ] P12.09 Hashes aus getrackten Bytes neu berechnen.
- [ ] P12.10 Production-Auth-Gate nur über Promoter öffnen.
- [ ] P12.11 Phase-3-Credit-Scorer.
- [ ] P12.12 Phase-5-Credit-Scorer.
- [ ] P12.13 P3 atomar `44 -> 100`.
- [ ] P12.14 P5 atomar `89 -> 100`.
- [ ] P12.15 Kein Zwischenwert.
- [ ] P12.16 Horizontal `633/700 -> 700/700`.
- [ ] P12.17 Vertikal unverändert `700/700`.
- [ ] P12.18 Gesamt `1333/1400 -> 1400/1400`.
- [ ] P12.19 Offen `67 -> 0`.
- [ ] P12.20 Overall `90 -> 100`.
- [ ] P12.21 Manifest-Replay.
- [ ] P12.22 External-Gate-Verifier.
- [ ] P12.23 Secret-Scan.
- [ ] P12.24 Source-Binding-Verifier.
- [ ] P12.25 Relevante Unit-/Integrationstests.
- [ ] P12.26 Hosted-Evidence read-only erneut prüfen.
- [ ] P12.27 Nur explizite Dateien stagen.
- [ ] P12.28 PR erstellen.
- [ ] P12.29 Pflicht-CI vollständig abwarten.
- [ ] P12.30 Kein fehlgeschlagener/übersprungener Pflichtschritt.
- [ ] P12.31 Review am finalen Kopfstand.
- [ ] P12.32 Review per Readback.
- [ ] P12.33 Mit Merge-Commit zusammenführen.
- [ ] P12.34 S15-/Evidence-Abstammung prüfen.
- [ ] P12.35 Vollständiger Gate-Lock.
- [ ] P12.36 Nur vorgesehene P3-/P5-/Gate-Werte geändert.

## P13 – Endgültige Market-Ready-Prüfung

- [ ] P13.01 Frischer sauberer Standardzweig-Checkout.
- [ ] P13.02 Standardzweig-HEAD protokollieren.
- [ ] P13.03 S15-Abstammung.
- [ ] P13.04 Q16-Abstammung.
- [ ] P13.05 Evidence-Kontroll-SHAs.
- [ ] P13.06 Release-ID und Archivhash.
- [ ] P13.07 Phase-3-Scorer.
- [ ] P13.08 Phase-5-Scorer.
- [ ] P13.09 Fortschrittsmanifest.
- [ ] P13.10 External-Gates.
- [ ] P13.11 GHCR-Digests read-only.
- [ ] P13.12 I1-Evidence read-only.
- [ ] P13.13 Vercel Deployment/Alias-Parität.
- [ ] P13.14 Cloudflare Source-/Bundlebindung.
- [ ] P13.15 Produktions-OAuth-Vertrag.
- [ ] P13.16 Anonymes `/auth/me=401`.
- [ ] P13.17 Hosted-Browservertrag.
- [ ] P13.18 Secret-Scan.
- [ ] P13.19 Pflicht-CI finaler Standardzweig-HEAD.
- [ ] P13.20 `verify-market-ready.ps1 -IncludeExternalGates -RequireReady`.
- [ ] P13.21 Exitcode `0`.
- [ ] P13.22 `MARKET_READY:true`.
- [ ] P13.23 Overall `100%`.
- [ ] P13.24 `1400/1400`.
- [ ] P13.25 `0` offen.
- [ ] P13.26 I1 verifiziert.
- [ ] P13.27 I5 verifiziert.
- [ ] P13.28 Alle P00-Gates vergleichen.
- [ ] P13.29 Keine ungeplante Regression.
- [ ] P13.30 Erst dann Market-Ready melden.

## P14 – Temporäre Zugänge schließen und Zustand einfrieren

- [ ] P14.01 Codespaces-Port nicht öffentlich.
- [ ] P14.02 Codespace stoppen.
- [ ] P14.03 Nicht benötigte Providerfreigaben entfernen.
- [ ] P14.04 OAuth-Scope `read:user`.
- [ ] P14.05 Alte Secrets widerrufen.
- [ ] P14.06 Rollback-Deployment-IDs dokumentieren.
- [ ] P14.07 Neueste Evidence plus erforderliche Rollbackkopie erhalten.
- [ ] P14.08 Geschützte Evidence-Verzeichnisse nicht bereinigen.
- [ ] P14.09 Keine getrackte Datei löschen.
- [ ] P14.10 Finalen Arbeitsbaum sauber.
- [ ] P14.11 Finalen Remote-HEAD lesen.
- [ ] P14.12 Market-Ready-Verifier nach Cleanup read-only wiederholen.
- [ ] P14.13 Protokoll mit Haken, Ergänzungen, Links und Hashes speichern.
- [ ] P14.14 Produktveröffentlichung bleibt separate spätere Aktion.

## Ergänzungen

### E00-01 – Veralteter Einstieg in AI_HANDOFF

- Grund: RC57 stand vor RC62 und konnte einen Neustart in den falschen Arbeitsbaum lenken.
- Betroffene Gates: C3/Handoff-Wahrheit, kein Produktgate.
- Handlung: RC62-Fortsetzung an den Anfang setzen; RC57 als historisch markieren.
- Status: `[ ] AKTIV`; Abschluss erst nach Review, CI, Merge und Readback.

### E00-02 – Widersprüchliche Phase-5-Beschreibungstexte

- Grund: RC48-Bezeichnungen sowie falsche `owner_granted=false`-Sätze widersprachen den referenzierten Dateien.
- Betroffene Gates: C3, C4, I2 und I5 Beschreibung; keine Status-/Creditänderung.
- Handlung: sämtliche kandidatenspezifischen Claims und Referenzen auf echte RC62-Artefakte binden; historische Providerbeweise ausdrücklich historisch belassen.
- Status: `[ ] AKTIV`; Abschluss erst nach Review, CI, Merge und Readback.

### E00-03 – Exact-Head-CI nach Merge

- Grund: `pr-check` startet nicht automatisch bei Push auf den Standardzweig.
- Evidence: GitHub Run `34696298574`, Job `103560257339`, SHA `cbb3d1e9...`, Erfolg.
- Status: `[x] ERLEDIGT`.

### E04-01 – Getracktes Masterprotokoll und Pre-Publication-Kontrolle

- Grund: Das Masterprotokoll muss nach PR #110 getrackt weitergeführt werden; bekannte Wahrheitsformulierungen müssen vor P05 geschlossen sein.
- Erlaubte Pfade: dieses Protokoll, `AI_HANDOFF.md`, `PROJECT_STATE.md`, `docs/runtime-state/phase5-credit-itemization.json` und `docs/runtime-state/owner-input-manifest.json`.
- Verboten: Produkt-/Runtimecode, Dockerfiles, Abhängigkeiten, Verifierlogik, Gate-Booleans, Prozente, Release-ID, S15/Q16 oder Archivhash ändern.
- Status: `[ ] AKTIV`.
- Abschluss: Diffprüfung, Phase-5-Verifier, Manifest-Verifier, Source-Control, Syntax,
  Secret-Scan, relevante Tests, PR-Exact-Head-CI, unabhängige Review, Merge-Commit,
  Remote-Readback und unveränderte P00-P04-Gates.


### E04-02 – Veraltete OWNER_BLOCKED-Aggregation reparieren

- Grund: Der statische Market-Ready-Verifier verlangte bei `docker_registry_publish` und `phase6_scale_runtime` veraltete geschlossene Zustände, führte O2 trotz nachgewiesener O2Core-/Scale-Beweise als offen und verband O6 fälschlich mit einer nicht vorhandenen kombinierten aktuellen Hosted-Akzeptanz.
- Neue Erkenntnis: Eine reine Datenkorrektur würde grüne Gates zurücksetzen oder historische Beweise als RC62-Beweis umlabeln und ist deshalb verboten.
- Betroffene Gates: Nur die Bewertung des gültigen `OWNER_BLOCKED`-Zustands; I1 und I5 bleiben blockiert, Phase 5 bleibt `89%`, Gesamtfortschritt bleibt `90%`, `MARKET_READY:false`.
- Zusätzliche Handlung: Owner-Matrix semantisch berichtigen, Verifier fail-closed an die aktuellen belegten Gates binden und fokussierte Positiv-/Negativtests ergänzen. Der finale READY-Zweig darf nicht abgeschwächt werden.
- Kandidatenfolge: Nach der Protokollregel invalidiert jede Verifierlogikänderung S15 als fortzusetzenden Publikationskandidaten. RC62/S15 bleiben unveränderte historische Qualifikation; vor P05 ist ein neuer Source-Commit, Release-Kandidat, Archivhash, direkter Qualifikationsnachfolger und vollständige No-Credit-Requalifikation erforderlich.
- Zusätzliche Prüfung: `OWNER_BLOCKED` muss Exitcode `0` und `MARKET_READY:false` liefern; Manipulationen an O2, offenen Gates, I1/I5 oder READY-Voraussetzungen müssen fail-closed bleiben.
- Teststand: 12 fokussierte Market-Ready-Tests und die breite Market-Ready-Unit-Suite sind grün. Der Owner-Matrix-Teil ist grün; der Gesamtverifier stoppt erwartungsgemäß am S15-Schutz, bis ein Nachfolgekandidat gebunden ist.
- Status: `[ ] BLOCKIERT` bis zur ausdrücklich freigegebenen Nachfolgekandidatenqualifikation; P05 ist `[ ] BLOCKIERT`.

### E04-03 – Kanonischen Secret-Scan im temporären Spiegel pfadtreu ausführen

- Grund: Der externe Gate-Verifier kopiert ausschließlich getrackte und nicht ignorierte Dateien in einen temporären Scan-Spiegel. Ein absoluter `--source`-Pfad verhindert dort, dass die bereits eng begrenzte, pfadgebundene `generic-api-key`-Ausnahme greift.
- Neue Erkenntnis: Der vollständig geschwärzte Diagnosebericht zeigte ausschließlich die seit RC57 unveränderte Zeile `GITHUB_OAUTH_CLIENT_ID` in `services/cloudflare-stateful-runtime/wrangler.jsonc`. Ein relativer Kontrollscan desselben Arbeitsbaums ist ohne Fund grün.
- Betroffene Gates: `canonical_gitleaks_scan`; keine Secret-Regel und keine Allowlist wird erweitert.
- Zusätzliche Handlung: Den bestehenden temporären Scan-Spiegel beibehalten, den Scanner innerhalb dieses Spiegels mit relativer Quelle ausführen und das Arbeitsverzeichnis in jedem Erfolgs- und Fehlerfall sicher zurücksetzen.
- Zusätzliche Prüfung: PowerShell-Syntax, fokussierter Pfadvertragstest, synthetische Positivkontrolle und vollständiger kanonischer Scan müssen grün sein.
- Evidence: 25 fokussierte External-Gate-/Pfadvertragstests grün; PowerShell-Syntax grün; kanonischer Gitleaks-Readback `canonical_gitleaks_claim_allowed=true`; relativer Vollscan ohne Fund.
- Status: `[x] ERLEDIGT`; nächster Punkt E04-04. P05 bleibt `[ ] BLOCKIERT`.

### E04-04 – Aktuelle External-Gate-Wahrheit aus Live-Readback ableiten

- Grund: Die getrackte External-Gate-Zusammenfassung von 2026-08-29 führt nur GHCR als offen und enthält einen dazu widersprüchlichen aktiven Zielwert.
- Neue Erkenntnis: Der read-only Kontrolllauf am 2026-09-12 bestätigte Branch Protection und Cloudflare-native weiterhin grün. Gehostete Agent-API-Verträge, das RC62-GHCR-Digestmanifest und die Vercel-Backend-Ursprünge sind offen; der zusätzliche Secret-Scan-Fehler gehört zu E04-03.
- Betroffene Gates: `hosted_agent_api_contracts`, `ghcr_image_digest_verify`, `vercel_backend_origin_health` und vor Abschluss von E04-03 `canonical_gitleaks_scan`.
- Zusätzliche Handlung: Summary und Audit ausschließlich durch den External-Gate-Verifier neu erzeugen; `owner-input-manifest.external_gate_truth` muss Status, geordnete Missing-Liste, aktives erstes Ziel und Production-Claim exakt spiegeln.
- Zusätzliche Prüfung: Missing-Liste muss aus den sechs Claim-Flags in `gate_ids`-Reihenfolge folgen; Summary, Audit und Owner-Projektion müssen identisch sein; bereits grüne Branch-Protection-, Cloudflare- und Secret-Scan-Gates dürfen nicht zurückfallen.
- Nicht-Claim: Diese Korrektur öffnet kein Gate, vergibt keinen Credit und verändert weder `90%`/`1333/1400` noch I1/I5 oder `MARKET_READY:false`.
- Evidence: Verifier-Readback `2026-09-12T16:10:30.9196575Z`; Summary-SHA-256 `CCFA6AAC9B1E7699885C4CACE00F89197157CC2905A729EBCBA99F7483FE761C`; Audit-SHA-256 `F81F482F80EBBAD755FB21F2973EE56DAD07F26093749E90F95C862F89A51EBD`.
- Status: `[ ] BLOCKIERT` bis Summary, Audit und Owner-Projektion in einem neuen qualifizierten Kandidaten source-bound sind; P05 bleibt `[ ] BLOCKIERT`.

### E04-05 – Source-Prequalification für External-Gate-Wahrheitswechsel ergänzen

- Grund: GitHub-Run `34704623284` band Q17 und S16 korrekt, stoppte aber im Progress-Guard, weil der Workflow nur den älteren erwarteten Runtime-Source-Drift kannte.
- Evidence: Der Verifier lieferte exakt `no-credit requalification may not inflate external gate truth` und anschließend `Phase-5 credit itemization is invalid`; alle 28 vorgelagerten Progress-Regressionstests waren grün.
- Zweiter Readback: Run `34704869336` bestand den reparierten Progress-Guard und stoppte anschließend im unabhängigen Five-Axis-Wrapper an derselben, dort noch nicht allowlisteten exakten External-Truth-Drift-Ausgabe.
- Zusätzliche Handlung: Der Source-Prequalification-Zweig akzeptiert zusätzlich genau diese zweizeilige, fail-closed External-Truth-Drift-Ausgabe. Jede andere Ausgabe und jeder andere Exitcode bleiben Fehler.
- Zusätzliche Prüfung: Fokussierter Workflow-Vertragstest, vollständige lokale Kontrollsuite sowie neuer GitHub-Run mit neuem S16/Q17.
- Status: `[ ] AKTIV`; der fehlgeschlagene Run bleibt historisch, P05 bleibt `[ ] BLOCKIERT`.

## Vorlage für weitere Ergänzungen

> **Ergänzung `E<HAUPTPUNKT>-<NUMMER>`**
> Grund:
> Neue Erkenntnis oder Abweichung:
> Betroffene Gates:
> Zusätzliche Handlung:
> Zusätzliche Prüfung:
> Evidence/Link/Hash:
> Auswirkung auf den nächsten Punkt:
> Status: `[ ] OFFEN` / `[x] ERLEDIGT`

## Testschichten

1. Identität: Release-ID, S15, Q16, Archivhash und Kontroll-SHA.
2. Statisch: Syntax, Konfiguration, Verifierverträge, verbotene Abhängigkeiten, Diff.
3. Lokal: Builds, Unit-/Runtimeverträge, Browserlogik, Manifest-Replay.
4. Provider-Readback: tatsächlich gespeicherter GitHub/GHCR/Vercel/Cloudflare-Zustand.
5. Hosted-Verhalten: HTTPS, Health, SSE, OAuth, Cookies, Persistenz und Audit.
6. Security: Secret-Scan, Scope, Redaction, Replay und unerlaubte Writes.
7. CI: unabhängige Prüfung des exakten Remote-Commits.
