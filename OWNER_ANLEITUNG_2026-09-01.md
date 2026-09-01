# OWNER-ANLEITUNG — Stand 2026-09-01

Diese Datei ist **fuer dich**, nicht fuer Codex. Sie sagt, was heute passiert ist, was du
noch anklicken musst und wie du jeden Schritt selbst nachpruefst.

Alles hier ist **gemessen**, nicht behauptet. Wo ich etwas nicht pruefen konnte, steht es
ausdruecklich dabei.

---

## 1. Was heute erledigt wurde

| Was | Ergebnis | Beweis |
| --- | --- | --- |
| **B1 — Rubriken freigegeben** | ✅ fertig | Commit `e87c28a7c6cf32982caa849794042daa53ef022a` |
| **Phase-6-Workflow auf den Hauptzweig** | ✅ fertig | PR #32 gemerged, Merge-Commit `ce75bb00` |
| **Masterdateien im Hauptordner** | ✅ aktuell | byte-identisch mit `origin` |

### B1 im Detail

Drei Regelwerke unter `docs/runtime-contracts/` standen auf Entwurf und blockierten
**alle zehn** Layer-Pruefskripte. Sie tragen jetzt `Status: APPROVED`,
`Credit-Anwendung erlaubt: true` und die Zeile `Owner-Freigabe-Ref:`.

Die dritte Zeile fehlte vorher in **allen drei** Dateien und wird vom Pruefer verlangt.
Ohne sie waere die Freigabe wirkungslos geblieben — Freigabe erteilt, Pruefer verweigert
trotzdem den Start.

Nachgemessen nach der Freigabe: `overall = 89`, `deltas = 0`, `17/19`.
**Die Freigabe hat keinen einzigen Punkt vergeben.** Sie hat nur die Pruefer startbar
gemacht. Genau so soll es sein.

### Phase-6-Workflow im Detail

Gemessener Stand vorher:

```text
Environment  phase6-scale-hosted-writes           vorhanden
  Secret     AGENT_API_AUTH_TOKEN                 vorhanden seit 2026-08-30 12:12 UTC
Workflow     auf codex/organism-visual-v2         vorhanden
Workflow     auf chore/repo-bootstrap (Default)   FEHLTE
```

Du wolltest ein Secret eintragen — **das war nicht noetig und waere am falschen Ort
gewesen.** Die Seite `/settings/secrets/actions` traegt *Repository*-Secrets ein; gebraucht
wird ein *Environment*-Secret. Das existierte bereits.

Gefehlt hat nur die Workflow-Datei auf dem Hauptzweig. GitHub startet
`workflow_dispatch`-Laeufe **ausschliesslich** aus der Kopie auf dem Hauptzweig. Das ist
eine GitHub-Regel, kein Projektentscheid.

Nach dem Merge geprueft:

```text
phase6-scale-runtime.yml auf chore/repo-bootstrap   5.357 Bytes, Blob 0b2f7e3b
Von GitHub registriert                              state=active, id=347406379
```

---

## 2. Ein Fehler von mir — und warum nichts passiert ist

Ich habe dir gesagt, du sollst PR #32 mergen. Ich hatte die Ausloeser der Datei geprueft,
die **hinzukam** — aber nicht die der Dateien, die auf dem Hauptzweig schon **lauerten**.

Auf dem Hauptzweig liegt eine alte `main-deploy.yml` mit:

```yaml
on:
  push:
    branches: [chore/repo-bootstrap]
permissions:
  packages: write
```

Dein Merge war ein Push. Der alte Deploy-Workflow ist von selbst losgelaufen.

**Was tatsaechlich geschah** (Lauf `33497699169`):

```text
verify           ❌ Schritt 9 "Frontend audit"
production-gate  ⏭️ uebersprungen
build-and-push   ⏭️ uebersprungen        ← nie ausgefuehrt
```

**Kein Image ging nach GHCR.** Ein uebersprungener Job kann nichts veroeffentlichen.

*Einschraenkung:* Die Registry selbst konnte ich nicht abfragen — dem Token fehlt die
Berechtigung `read:packages`. Meine Aussage stuetzt sich auf den Job-Status `skipped`.
Wenn du es selbst sehen willst: <https://github.com/strazzusochr?tab=packages>

Die Ironie: **die rote Pruefung, die wir uebersteuert haben, war hier der Sicherheitsgurt.**

---

## 3. Was du jetzt noch machen musst

Drei Dinge. Reihenfolge einhalten.

### Schritt A — PR #33 mergen

**Der Pull Request ist fertig und liegt bereit:**

<https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/pull/33>

Inhalt: **eine Datei**, `.github/workflows/main-deploy.yml`, byte-identisch mit der
gehaerteten Fassung vom Arbeitszweig (Blob `14e84b31`). Commit `055351bf`.

Das raeumt genau die Falle weg, in die wir bei PR #32 gelaufen sind:

| | alt (liegt jetzt dort) | neu |
| --- | --- | --- |
| Ausloeser | **bei jedem Push** + manuell | **nur manuell**, Kandidat-SHA Pflicht |
| Rechte | `packages: write` | `contents: read` |
| Veroeffentlichung | ungeschuetzt | Environment `registry-publication` mit Freigabe |

**Klicken — genau wie bei #32:** ganz nach unten, Haken bei
*„Merge without waiting for requirements to be met (bypass rules)"*, dann
**„Bypass rules and merge"**, dann bestaetigen.

Die roten Meldungen sind dieselben wie vorher und aus demselben Grund: die alten
Frontend-Bibliotheken auf dem Hauptzweig, nicht diese Aenderung. Der PR fasst keine
`package.json` an.

**Danach kontrollieren:**

```powershell
gh run list --repo 'strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM' --branch chore/repo-bootstrap --limit 3
```

Erwartung: **kein neuer `main-deploy`-Lauf**. Der Merge-Commit enthaelt bereits die
dispatch-only Fassung, also darf kein Push-Ausloeser mehr greifen. Falls doch einer
erscheint: er kann nichts veroeffentlichen, weil `verify` weiterhin rot ist.

### Schritt B — `phase6-scale-hosted-writes` schuetzen

**Korrektur zu einer frueheren Annahme:** `registry-publication` hat den Pflicht-Freigeber
**bereits** (gemessen: `required_reviewers` = `strazzusochr`, `prevent_self_review=false`).
Dort ist nichts zu tun.

Ungeschuetzt ist dagegen das **andere** Environment:

```text
registry-publication          protection_rules: required_reviewers ✅
phase6-scale-hosted-writes    protection_rules: []                 ❌ leer
```

Die Phase-6-Rubrik verlangt aber ausdruecklich ein *geschuetztes* Environment, und die
L5-Zeile „Geschuetzter Workflow verlangt Environment-Review vor Write/Publish" (6 Punkte)
haengt daran. So setzt du es:

1. <https://github.com/strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM/settings/environments>
2. **`phase6-scale-hosted-writes`** anklicken
3. Haken bei **„Required reviewers"**
4. Dich selbst eintragen (`strazzusochr`)
5. **„Save protection rules"**

Das ist kein Deploy und veroeffentlicht nichts.

### Schritt C — Nichts weiter. Der Rest ist Codex.

Der eigentliche B3-Grant und der B4-Dispatch gehoeren in Codex' Ablauf, weil sie an
Kandidat, Evidence und Reihenfolge haengen. Beides steht in der Zieldatei.

---

## 4. Was du **nicht** tun sollst

| Nicht anklicken | Warum |
| --- | --- |
| **„Close pull request"** | wirft den Pull Request weg |
| **„Comment"** (gruen, unten) | schickt nur einen Kommentar, merged nichts |
| **„npm audit fix"** oder Dependabot-Vorschlaege | veraendert Abhaengigkeiten, eigenes Thema |
| **„Rueckgaengig machen"** in der Codex-Oberflaeche | loescht unveroeffentlichte Beweisdateien |
| Irgendetwas unter `/settings/secrets/actions` | Secrets sind vollstaendig, falscher Ort |

---

## 5. Wie du den Gesamtstand selbst pruefst

Ein Befehl, jederzeit:

```powershell
Set-Location 'D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
$env:PYTHONUTF8='1'; $env:TEMP='D:\_sb_tmp'; $env:TMP='D:\_sb_tmp'
py -3 .\scripts\verify_project_progress_manifest.py
```

Erwartete Ausgabe heute:

```text
[project-progress] manifest valid: overall=89% deltas=0 ...
```

**Solange `deltas=0` steht, ist noch kein einziger Punkt vergeben worden.** Die Zahl
bewegt sich erst ganz am Ende, wenn alle Beweise liegen. Das ist kein Stillstand, sondern
die Sicherung gegen selbstvergebene Punkte.

---

## 6. Warum es immer noch 89 % sind

Die sieben waagerechten Phasen ergeben den Gesamtwert:

```text
(100 + 100 + 100 + 44 + 100 + 89 + 90) / 7 = 89
```

Die senkrechten Ebenen L4 und L5 bewegen diese Zahl **nie** — sie zaehlen fuer die zweite
Matrix. Wer also L4 und L5 auf 100 bringt, sieht den Gesamtwert trotzdem bei 89.

Offen sind **166 Punkte**:

| Zelle | Rest | Haengt an |
| --- | ---: | --- |
| P3 | +56 | 5 von 12 Kettenschritten, Evidence-Dokument, **B2** |
| P5 | +11 | faellt nach P3 und nach der Registry-Paritaet |
| P6 | +10 | Scale-Lauf, **B3-Grant** — Workflow liegt jetzt richtig |
| L4 | +45 | Hosted-Laeufe nach Rebind |
| L5 | +44 | Hosted-Laeufe, echtes SBOM, **B4** |

---

## 7. Wo alles steht

```text
Repository   D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
Zieldatei    CODEX_ZIEL_MASTER_2026-08-29.md       <- was zu tun ist
Uebergabe    CODEX_UEBERGABE_MASTER_2026-08-29.md  <- was los ist
Diese Datei  OWNER_ANLEITUNG_2026-09-01.md         <- was DU tun musst
Arbeitszweig codex/organism-visual-v2
Hauptzweig   chore/repo-bootstrap
```

Beide Masterdateien im Hauptordner sind **lose Kopien**, die kein Push erreicht. Sie
werden nach jeder Aenderung von Hand nachgezogen. Wenn ein Datum dort alt aussieht, sag es
— dann ist genau das passiert.

---

`MARKET_READY:false` · `DEV-ONLY; hosted proof still blocked.`
