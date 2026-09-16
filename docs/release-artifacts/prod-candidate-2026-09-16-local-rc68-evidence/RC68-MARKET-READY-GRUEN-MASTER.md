# RC68 — Master Market-Ready Grün

> **Eine Datei für Zielverfolgung, Master-Prompt und Kontrollprotokoll.**
>
> Dieser Plan beschreibt den einzigen zulässigen Weg zu `MARKET_READY:true`. Er
> setzt keinen Fortschritt, keine Gate-Werte und keine Owner-Freigabe. Ein Haken
> bedeutet ausschließlich: Handlung, Readback, Hash, Regressionstest und nächster
> Schritt wurden durch aktuelle Evidenz bestätigt.

## 1. Gebundene Ausgangswahrheit

| Feld | Aktueller, belegter Wert |
| --- | --- |
| Release | `prod-candidate-2026-09-16-local-rc68` |
| Produktquelle S | `10bccfcfb5a62c6883c7162b8b2eed4f3da817ff` |
| Qualifikation Q | `15b850fe03f07667e24a9a94987c1eab0fffa415` |
| S-Archiv SHA-256 | `352429b3a637112f34e7821eb89987d5e384e0e9de9c20168496747f80ce55a9` |
| Aktueller Standardzweig-HEAD | `59b9eb3cc70181e1be687608eab5f61c19ce1c9d` |
| Gesamtfortschritt | `90 %`, `1333/1400`, `67` offen |
| Horizontal | `P0=100`, `P1=100`, `P2=100`, `P3=44`, `P4=100`, `P5=89`, `P6=100` |
| Vertikale Layer | `7/7` jeweils `100 %` |
| Phase 5 | `17/19`; blockiert: `I1`, `I5` |
| Marktstatus | `MARKET_READY:false` |

### Bereits vorhandene, aber noch nicht kreditierte RC68-Evidence

| Bereich | Pfad | SHA-256 | Bedeutung |
| --- | --- | --- | --- |
| I1 Hosted Candidate | `i1/i1-hosted-candidate-parity.json` | `f0cbe7eb1174b86c080687d4099d3a8bb93f52ec229375b7cd1249379a9db1c9` | Sechs Digest-only Services, HTTPS, SSE und Persistenz; kein Einzelcredit vor dem atomaren Übergang. |
| Frontend | `frontend/frontend-hosted-current.json` | `0eb5320237a3e15544a7a88b1f826a2492b690a545703262a4b99178f530e47c` | RC68-Nachfolger, kanonischer Alias, Browservertrag; kein Release-Claim. |
| OAuth-Runtime | `oauth/cloudflare-runtime-deployment-readback.json` | `dc99e16620a717c84e18351981ef4f2738910075aeb49585c4c1be4b26ea27d7` | Worker auf RC68-S, Health 200 und anonymer `/auth/me` 401; kein OAuth-Flow. |
| Runtime-Status | `docs/runtime-state/cloudflare-oauth-hosted-current.json` | `56d3d3454e201cd48ca8de77e9602c67da858aac306a6d5fa699fc909133ef44` | RC68-S, Cloudflare-native, keine Provider- oder Deployment-Write im Readback. |

## 2. Was „Market Ready grün“ exakt bedeutet

Der Abschluss ist erst erreicht, wenn der aktuelle Standardzweig gleichzeitig
alle folgenden Aussagen belegt:

1. `MARKET_READY:true` aus `scripts/verify-market-ready.ps1 -IncludeExternalGates -RequireReady` mit Exitcode `0`.
2. Gesamtstand `1400/1400`, `100 %`, `0` offene Punkte.
3. Phase 3 wechselt atomar von `44` auf `100`; Phase 5 wechselt atomar von `89` auf `100`.
4. I1 und I5 sind beide durch getrackte, hashgebundene RC68-Evidence verifiziert.
5. Die kanonischen External Gates sind für RC68 aktuell, nicht nur historische oder lokale Evidenz.
6. Alle vor dem Übergang grünen Gates bleiben grün; keine Secrets, Tokens, Codes, Cookies, States oder Rohidentitäten werden gespeichert oder ausgegeben.
7. Der finale HEAD hat Exact-Head-CI, unabhängige Review und einen normalen Merge-Commit.

Bis alle sieben Punkte mit aktuellem Readback erfüllt sind, bleibt der korrekte
Zustand `MARKET_READY:false`.

## 3. Unverhandelbare Regeln

1. **Keine manuelle Promotion.** Prozentwerte, `live_verified`, I1, I5 und
   `MARKET_READY` dürfen ausschließlich durch die vorhandenen Verifier und
   Promoter geändert werden.
2. **Eine Quelle.** S, Q, Release-ID und Archivhash müssen vor jedem Loop und
   nach jeder zustandsverändernden Handlung wieder übereinstimmen.
3. **Keine Wiederverwendung alter OAuth-Beweise.** RC63-Flow-, Consent- und
   Architektur-Evidence bleibt historische Evidenz. Sie darf RC68 nicht
   zugeschrieben werden.
4. **Keine Secrets im Projekt oder Chat.** OAuth-Code, State, Token, Cookie,
   Client-Secret und Roh-Owner-ID sind nur im jeweiligen Provider bzw. in
   bereinigter, gehashter Evidence zulässig.
5. **Kein Teilcredit.** I1 und I5 werden gemeinsam über den kanonischen
   Phase-3-/Phase-5-Pfad übernommen. `95 %`, ein einzelner I1-Credit oder ein
   bloßes `live_verified=true` sind unzulässig.
6. **Kein Überschreiben.** Evidence wird als neue Datei mit neuem Hash erzeugt;
   vorhandene historische Beweise bleiben unverändert.
7. **Kein Admin-Bypass.** Jeder Evidence- oder Promotions-PR braucht Exact-Head-CI,
   unabhängige Review und `Create a merge commit`.

## 4. Aktuelle Gate-Landkarte

| Gate | Istzustand | Fehlender Nachweis | Freigabekriterium |
| --- | --- | --- | --- |
| External Gates | kanonische Zusammenfassung ist älter als RC68 und blockiert | RC68-gebundener GHCR-Digest-Readback in der kanonischen Audit-/Summary-Kette | Frischer Verifier-Readback meldet keine fehlenden Pflichtgates und `production_deploy_claim_allowed=true`. |
| I1 | RC68-Hinweis vorhanden, Credit absichtlich `false` | Kandidat, GHCR-Digests und kanonische External-Gate-Kette müssen gemeinsam aktuell sein | Dedicated I1-Verifier akzeptiert genau eine RC68, HTTPS-, Digest-only-Sechs-Service-Evidence. |
| Owner-Architektur | `production-auth-architecture-decision.json` bindet noch RC63-S | Neue RC68-gebundene Owner-Architekturentscheidung | `cloudflare_native`, Callback auf kanonischen Vercel-Alias, Scope `read:user`, Runtime-Ref und RC68-S stimmen. |
| Owner-Consent | Bestehende Consent-Datei bindet noch RC63-S | Neue RC68-gebundene, nicht geheime Consent-Bestätigung | Owner-Approval, Scope, Callback, Runtime- und RC68-S-Bindung stimmen. |
| I5 OAuth-Flow | Keine aktuelle RC68-Flow-Evidence | Echter 16-Schritte-Flow plus drei bereinigte Artefakte und Scorer | Read-only Hosted-Verifier akzeptiert alle Flow-, State-, Cookie-, Audit- und Redaction-Regeln. |
| I5 Capability Gate | `owner_granted=true`, `live_verified=false` | Verifizierte RC68 Production-Auth-Evidence | Kanonischer Promoter setzt den Gate-Wert atomar mit Hash, Provider und Zeit. |
| Finaler Stand | 90 % / 1333 von 1400 | Phase-3-, Phase-5- und External-Gate-Übergang | Gesamtaggregat-Verifier liefert `MARKET_READY:true` und Exitcode 0. |

## 5. Einheitliches Gate-Lock-Protokoll

Vor **und** nach jedem Provider-Write, OAuth-Flow, Evidence-PR, Merge oder
Promoter wird ein Gate-Lock erfasst. Der Lock enthält mindestens:

```text
Zeit (UTC):
Arbeitsbaum / Zweig:
Lokaler HEAD / origin/chore/repo-bootstrap:
Release / S / Q / Archivhash:
Score / P0-P6 / Layer / I1 / I5 / MARKET_READY:
PR-Nummer / PR-HEAD / CI / Review:
External-Audit-Hash / External-Summary-Hash:
I1-Hash / Frontend-Hash / OAuth-Runtime-Hash / I5-Hash:
Vercel Deployment / Alias / Cloudflare Deployment / Worker-Version:
Rollback-Ziele:
Secret-Scan-Status:
Erlaubte Differenz dieses Loops:
```

Eine unerwartete Differenz beendet den Loop. Der nächste Loop beginnt erst nach
einer dokumentierten Ergänzung `E<LOOP>-NN` mit Ursache, Wirkung, Hash,
Regressionstest und sicherem Rückweg.

## 6. Endgültige nummerierte Loop-Zielverfolgung

### LOOP 84 — RC68-Basis und External-Gate-Wahrheit aktualisieren

- [ ] **84.01** Frischen, sauberen Worktree vom aktuellen Standardzweig erzeugen.
- [ ] **84.02** S, Q, Archivhash, Release-ID und Standard-HEAD vor der Arbeit lesen.
- [ ] **84.03** `verify-external-gates.ps1` ausschließlich mit RC68-S und der RC68-GHCR-Kandidatenmanifest-Evidence vorbereiten.
- [ ] **84.04** Branch-Protection-, Hosted-Agent-API-, Vercel-Origin-, Gitleaks- und GHCR-Digest-Probes read-only zurücklesen.
- [ ] **84.05** Kanonische Audit- und Summary-Dateien nur bei vollständig konsistentem RC68-Readback aktualisieren.
- [ ] **84.06** Hashes, `missing_or_failed_gates` und `production_deploy_claim_allowed` dokumentieren.
- [ ] **84.07** Kontroll-PR mit CI, unabhängiger Review und Merge-Commit abschließen.

**Erfolgszustand:** Die kanonische External-Gate-Kette spricht über RC68. Ein
noch fehlendes Gate bleibt sichtbar blockiert; dieser Loop vergibt keinen Credit.

### LOOP 85 — I1 endgültig vorqualifizieren, noch nicht promoten

- [ ] **85.01** I1-Evidence-Hash gegen den getrackten RC68-Blob prüfen.
- [ ] **85.02** Sechs Images, zwölf Plattform-Digests, OCI-Revision S, HTTPS,
  Same-Origin, SSE, Persistenz, `--no-build` und keine Source-Mounts erneut
  über den dedizierten Verifier prüfen.
- [ ] **85.03** Verifizieren, dass der Codespaces-Port geschlossen und die
  temporäre Laufzeit gestoppt ist.
- [ ] **85.04** I1 nur dann als promotionsbereit markieren, wenn LOOP 84 den
  GHCR-External-Gate-Readback bestätigt.
- [ ] **85.05** I1 weiter als nicht kreditiert lassen, bis I5 vollständig grün ist.

**Erfolgszustand:** I1 ist RC68-gebunden und für den atomaren Übergang bereit;
Score bleibt 90 %.

### LOOP 86 — RC68 Owner-Architektur und Consent source-bound erneuern

- [ ] **86.01** Bestehende RC63-Architektur-, Consent- und Flow-Dateien als
  historische Evidence belassen.
- [ ] **86.02** Neue, nicht geheime RC68-Architekturentscheidung erzeugen:
  `cloudflare_native`, Callback
  `https://frontend-seven-psi-78.vercel.app/api/v1/auth/callback`, Scope
  `read:user`, Runtime-Ref und RC68-S.
- [ ] **86.03** Neue RC68-Consent-Bestätigung erzeugen; sie enthält keine
  OAuth-Geheimnisse, Codes, Tokens, Cookies oder Klartextidentität.
- [ ] **86.04** Owner-Bestätigung und neue Artefakte hashen und in einem
  no-credit Kontroll-PR mergen.
- [ ] **86.05** Hosted-OAuth-Verifier bis zum erwarteten Flow-Blocker ausführen;
  kein `live_verified` setzen.

**Erfolgszustand:** Die Bedingungen für den echten Flow sind source-bound und
auditierbar. Dieser Loop konfiguriert keine Secrets und startet keinen Flow.

### LOOP 87 — I5-Flow vor dem Start fail-closed prüfen

- [ ] **87.01** Gate-Lock einschließlich Vercel-Alias, Cloudflare-Worker,
  Runtime-Hash und Rollback-IDs schreiben.
- [ ] **87.02** Hosted Health muss HTTP 200, RC68-S und erwarteten Archiv-/Bundle-
  Hash melden.
- [ ] **87.03** Anonymes `/api/v1/auth/me` muss HTTP 401 liefern.
- [ ] **87.04** Auth-Konfigurationsvertrag muss credential-ready melden, ohne
  Secretwert auszugeben.
- [ ] **87.05** Der Browser muss ohne vorhandene Superbrain-Session starten.
- [ ] **87.06** Abbruch bei falschem GitHub-Konto, abweichendem Callback,
  erweitertem Scope, nicht passender Owner-ID oder Providerfehler.

**Erfolgszustand:** Nur ein sauberer, RC68-gebundener Browser kann LOOP 88
starten.

### LOOP 88 — Echter 16-Schritte-Produktions-OAuth-Flow

Alle Schritte finden im Browser mit dem hierfür zugelassenen Owner-Konto statt.
Der Operator kopiert keine sensitiven Werte in den Chat oder in eine Datei.

- [ ] **88.01** Frisches Browserprofil, anonyme Loginseite und `/auth/me=401` prüfen.
- [ ] **88.02** GitHub-Start prüfen: 303, richtiger Host, Callback und exakt `read:user`.
- [ ] **88.03** ersten Flow bei GitHub abbrechen; keine Credentials ausgeben.
- [ ] **88.04** verbrauchten State erneut prüfen; Ablehnung ist Pflicht.
- [ ] **88.05** Flow für Tokenfamilie A starten und Owner autorisieren.
- [ ] **88.06** Callback konsumiert State genau einmal; Audit vor Credentials bestätigen.
- [ ] **88.07** erlaubte Owner-Identity, Session und Seitenneuladen verifizieren.
- [ ] **88.08** Refresh A auslösen; genau eine atomare Rotation akzeptieren.
- [ ] **88.09** alten Refresh wiederverwenden; 401 und Sperre der Familie A bestätigen.
- [ ] **88.10** alten Callback wiederverwenden; 401 ohne neue Credentials bestätigen.
- [ ] **88.11** unabhängigen Flow für Tokenfamilie B starten und Owner autorisieren.
- [ ] **88.12** B-Callback und Unterschied zwischen A und B nachweisen.
- [ ] **88.13** B-Logout ausführen; Cookie-Clear und Widerruf nachweisen.
- [ ] **88.14** Refresh nach Logout muss 401 liefern.
- [ ] **88.15** exakt vier GitHub-Provideraufrufe, null Provider-Writes, null
  Deployment-Writes und null Localhost-Transport bestätigen.
- [ ] **88.16** Cookie-Flags, SameSite, Audit-Reihenfolge und nur gehashte
  Request-/Session-/Audit-Korrelation bestätigen.

**Erfolgszustand:** Der Browserlauf erzeugt nur bereinigte Beobachtungen und
keine Gate-Promotion.

### LOOP 89 — I5-Evidence aus dem echten Flow bauen und verifizieren

- [ ] **89.01** Drei neue, bereinigte Artefakte erzeugen: Browser, D1-Readback,
  Audit-Readback.
- [ ] **89.02** Für jedes Artefakt einen Scorer-Output erzeugen und alle sechs
  Dateien SHA-256-hashen.
- [ ] **89.03** Roh- und bereinigte Artefakte auf OAuth-Codes, States, Tokens,
  Cookies, Secrets und Klartextidentitäten scannen; Treffer blockieren den Loop.
- [ ] **89.04** Neue `production-auth-identity`-Evidence ausschließlich aus
  Flow, Runtime, Frontend, Architektur und Exact-Head-CI bauen.
- [ ] **89.05** `verify-production-auth-identity-evidence.ps1 -ValidateOnly`
  und `verify-cloudflare-oauth-hosted-current.ps1` auf RC68-S ausführen.
- [ ] **89.06** Gate-Lock nach dem Readback vergleichen; keine Gate- oder
  Prozentänderung zulassen.
- [ ] **89.07** Evidence-Control-PR mit CI, unabhängiger Review und Merge-Commit
  abschließen.

**Erfolgszustand:** Alle I5-Beweise sind immutabel, source-bound, sanitisiert
und noch nicht promotet.

### LOOP 90 — I5-Capability Gate nur über den kanonischen Promoter öffnen

- [ ] **90.01** Auf sauberem HEAD die I5-Evidence read-only validieren.
- [ ] **90.02** Hash der Capability-Datei und Gate-Identity unmittelbar vor der
  Promotion erfassen.
- [ ] **90.03** Den Promoter erst mit exakt diesen beiden Hashes starten.
- [ ] **90.04** Prüfen, dass ausschließlich `production_auth_identity` die
  erlaubten Evidence-/Zeit-/Provider-Felder erhält.
- [ ] **90.05** Gate-Lock danach vergleichen und I5 Readback erneut prüfen.
- [ ] **90.06** Promotions-PR mit CI, unabhängiger Review und Merge-Commit
  abschließen.

**Erfolgszustand:** I5 ist technisch gültig, aber P3/P5/Gesamtstand werden noch
nicht manuell verändert.

### LOOP 91 — I1 und I5 atomar in Phase 3 und Phase 5 übernehmen

- [ ] **91.01** I1- und I5-Evidence gegen RC68-S und ihre Hashes prüfen.
- [ ] **91.02** Kanonischen Phase-3-Input erstellen: `44 → 100`, exakt `56`
  Punkte, keine Zwischenwerte.
- [ ] **91.03** Kanonischen Phase-5-Input erstellen: `89 → 100`, genau I1/I5,
  keine Zwischenwerte.
- [ ] **91.04** Manifest-, Itemization-, External-Gate-, Source-Binding- und
  Secret-Scan-Validatoren auf den neu erzeugten Bytes ausführen.
- [ ] **91.05** Nur wenn alle Verifier grün sind, die erlaubten Manifest-/Ledger-
  Änderungen stagen und einen Evidence-Promotion-PR erstellen.
- [ ] **91.06** Exact-Head-CI, unabhängige Review und normaler Merge-Commit.
- [ ] **91.07** Nach Merge: `1400/1400`, P3=100, P5=100, I1/I5 verified,
  `MARKET_READY` weiterhin erst nach LOOP 92 bewerten.

**Erfolgszustand:** Der Fortschritt wird einmalig, belegbar und ohne
Zwischenzustand auf den Zielwert gebracht.

### LOOP 92 — Endgültige Market-Ready-Abnahme

- [ ] **92.01** Frischen Standardzweig-Checkout erzeugen und HEAD protokollieren.
- [ ] **92.02** S, Q, Archivhash, I1, I5, External Gates und Exact-Head-CI
  erneut unabhängig lesen.
- [ ] **92.03** Hosted I1, Vercel-Alias und Cloudflare-Runtime read-only prüfen.
- [ ] **92.04** Anonymes `/auth/me=401`, Auth-Vertrag und bereinigte I5-Evidence
  erneut prüfen.
- [ ] **92.05** Alle relevanten Unit-, Integration-, Browser-, Manifest-,
  Source-Binding- und Secret-Scans erfolgreich ausführen.
- [ ] **92.06** Abschließenden Verifier ausführen:

```powershell
pwsh -NoProfile -File .\scripts\verify-market-ready.ps1 -IncludeExternalGates -RequireReady
```

- [ ] **92.07** Exitcode `0`, `MARKET_READY:true`, `1400/1400`, `I1 verified`
  und `I5 verified` zusammen als finalen Beweis speichern.

**Erfolgszustand:** Erst hier darf Market Ready als bestätigt gemeldet werden.

### LOOP 93 — Freeze und Rückbau temporärer Testoberflächen

- [ ] **93.01** Codespaces-Port prüfen: nicht öffentlich.
- [ ] **93.02** Temporäre Codespaces stoppen und keine Testoberfläche offen lassen.
- [ ] **93.03** OAuth-Scope erneut auf `read:user` prüfen; alte widerrufene
  Secrets nur als Status, nie als Wert dokumentieren.
- [ ] **93.04** Rollback-Deployment-IDs, finale Evidence-Hashes und finalen
  Standard-HEAD festhalten.
- [ ] **93.05** Abschlussverifier nach dem Cleanup erneut read-only ausführen.
- [ ] **93.06** Diese Datei mit allen Haken, Ergänzungen, Hashes und Links
  aktualisieren; die historische Evidence nicht löschen.

## 7. Master-Prompt für jeden folgenden Loop

```text
Du arbeitest ausschließlich am RC68-Market-Ready-Pfad.

1. Lies zuerst diese Masterdatei, current-release-candidate.json,
   project-progress.manifest.json, capability-gates.json,
   external-gate-summary.json und den Remote-HEAD.
2. Binde Release prod-candidate-2026-09-16-local-rc68, S 10bccfc..., Q
   15b850..., Archivhash 352429.... Ein Mismatch stoppt den Loop.
3. Erfasse GATE_LOCK_BEFORE. Führe genau einen nummerierten offenen Punkt aus.
4. Trenne Read-only-Prüfungen, Owner-Interaktion, Provider-Write, Evidence-
   Erzeugung, Promoter und Merge strikt voneinander.
5. Erzeuge oder ändere niemals Prozentwerte, live_verified, I1, I5 oder
   MARKET_READY per Hand. Nutze nur den kanonischen Verifier/Promoter.
6. Speichere keine OAuth-Codes, States, Tokens, Cookies, Secrets oder
   Klartextidentitäten. Evidence ist sanitisiert und SHA-256-gebunden.
7. Nach der Handlung: Readback aus dem Zielsystem, Hashprüfung, Regression aller
   bereits grünen Gates und GATE_LOCK_AFTER. Dokumentiere nur die erlaubte Delta.
8. Bei Fehler: keine Umgehung. Ergänzung E<LOOP>-NN mit Ursache, Scope,
   Auswirkung, Beweis und sicherem nächsten Schritt anlegen.
9. Bei Git-Änderung: nur explizite Dateien stagen, diff-check, Verifier,
   Secret-Scan, Exact-Head-CI, unabhängige Review und Merge-Commit.
10. Melde MARKET_READY:true ausschließlich nach LOOP 92 mit Exitcode 0.
```

## 8. Verbindliche Verifier-Reihenfolge

Die exakten Dateipfade für neu erzeugte I5-Evidence werden erst nach LOOP 88
eingesetzt. Platzhalter dürfen nie in einen tatsächlichen Lauf übernommen werden.

```powershell
# Basis und Fortschritt
python scripts/verify_project_progress_manifest.py
python scripts/verify_phase5_credit_itemization.py
gitleaks detect --no-git --source . --redact --exit-code 1

# External Gates: nur mit RC68-S und dem tatsächlich validierten RC68-GHCR-Manifest
pwsh -NoProfile -File .\scripts\verify-external-gates.ps1 `
  -ActiveReleaseCandidateSha 10bccfcfb5a62c6883c7162b8b2eed4f3da817ff `
  -GhcrPublishedManifestPath <RC68-GHCR-MANIFEST> -RequireAllClosed

# I5 nach neuer Evidence
pwsh -NoProfile -File .\scripts\verify-cloudflare-oauth-hosted-current.ps1 `
  -ExpectedCandidateSha 10bccfcfb5a62c6883c7162b8b2eed4f3da817ff `
  -FlowEvidencePath <RC68-FLOW-EVIDENCE> `
  -FrontendEvidencePath <RC68-FRONTEND-EVIDENCE> `
  -OwnerApprovalPath <RC68-OWNER-APPROVAL> `
  -LiveConsentApprovalPath <RC68-CONSENT-APPROVAL>

pwsh -NoProfile -File .\scripts\verify-production-auth-identity-evidence.ps1 `
  -EvidencePath <RC68-PRODUCTION-AUTH-EVIDENCE> `
  -ExpectedCandidateSha 10bccfcfb5a62c6883c7162b8b2eed4f3da817ff `
  -ValidateOnly

# Nur unmittelbar vor der Promotion und nur mit frisch zurückgelesenen Hashes
pwsh -NoProfile -File .\scripts\promote-production-auth-identity-gate.ps1 `
  -EvidencePath <RC68-PRODUCTION-AUTH-EVIDENCE> `
  -ExpectedCandidateSha 10bccfcfb5a62c6883c7162b8b2eed4f3da817ff `
  -ExpectedCapabilityStateSha256 <FRESH-CAPABILITY-HASH> `
  -ExpectedGateIdentitySha256 <FRESH-GATE-IDENTITY-HASH> `
  -Promote

# Abschluss, ausschließlich nach atomarer I1/I5-Promotion
pwsh -NoProfile -File .\scripts\verify-market-ready.ps1 -IncludeExternalGates -RequireReady
```

## 9. Ergänzungsprotokoll

Für jede neue Erkenntnis nach einem abgeschlossenen oder blockierten Punkt:

```text
E<LOOP>-<NN>
Grund:
Neue Erkenntnis oder Abweichung:
Betroffene Gates:
Erlaubte zusätzliche Handlung:
Readback / Evidence-Pfad / SHA-256:
Regressionstest:
Auswirkung auf den nächsten Loop:
Status: [ ] OFFEN / [x] ERLEDIGT
```

## 10. Aktueller nächster Schritt

**LOOP 84.01–84.04:** Einen frischen RC68-External-Gate-Readback vorbereiten,
ohne Werte in `external-gate-summary.json` zu behaupten oder zu überschreiben.
Danach entscheidet der tatsächlich zurückgelesene GHCR-Digest-Status, ob I1 und
die spätere I5-Promotion überhaupt weitergehen dürfen.
