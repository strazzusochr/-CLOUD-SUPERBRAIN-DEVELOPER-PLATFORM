# 🌐 AUFTRAG FÜR ANTIGRAVITY — Cloud-Konsolen im Browser

> **Du arbeitest ausschliesslich im Browser in den Cloud-Konsolen.**
> Du fasst **kein** Repository, **keine** lokale Datei und **keinen** Terminalbefehl an —
> das macht Codex (siehe `AGENT_AUFTRAG_RC21_UND_RESTLISTE.md`).
>
> Ziel: die Owner-Wände öffnen, die `overall 89 % -> 100 %` blockieren.
> Repo: `strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
> Aktiver Branch: `codex/organism-visual-v2` — **niemals** `main` oder `chore/repo-bootstrap`

---

## 0 · DIE VIER GRENZEN, DIE DU NIEMALS ÜBERSCHREITEST

Diese vier Dinge macht **immer der Mensch selbst an der Tastatur**. Du navigierst hin,
erklärst was zu tun ist, und **wartest**:

| Grenze | Warum |
|---|---|
| **Passwort / 2FA eingeben** | Kontozugang gehört dem Owner |
| **CAPTCHA lösen** | ausdrücklich verboten |
| **Secret-Werte tippen, kopieren oder anzeigen** | nur Variablennamen, niemals Werte |
| **Zahlung, Kreditkarte, kostenpflichtiger Tarif** | Free-Only-Vorgabe |

**Zusätzlich gilt:**
- Ein Secret-Wert erscheint **nie** in deiner Antwort, nie in einem Screenshot, nie in einem
  Repo, nie in DevTools. Du meldest ausschliesslich **Name + Status** (`gesetzt` / `fehlt`).
- **Nichts löschen.** Kein Paket, kein Deployment, kein Environment, keine App.
- **Nichts öffentlich schalten.** GHCR-Pakete bleiben **privat** — `public` ist irreversibel
  und eine eigene Owner-Entscheidung.
- **Kein Production-Deploy, keine Release-Promotion.** Nur bis zur beschriebenen Stufe.
- Vor jedem Klick, der etwas **erzeugt, ändert oder freigibt**: kurz sagen was passiert,
  dann bestätigen lassen.

---

## 1 · BESTANDSAUFNAHME ZUERST — nur lesen, nichts ändern

Öffne der Reihe nach und **melde den exakten Ist-Zustand**, bevor du irgendetwas anfasst:

| # | Konsole | Was du abliest |
|---|---|---|
| 1 | GitHub -> Settings -> Developer settings -> **OAuth Apps** | Existiert eine App? Name, Callback-URL, Scopes |
| 2 | GitHub -> Repo -> Settings -> **Environments** | Gibt es `registry-publication` und `production`? Required Reviewer gesetzt? |
| 3 | GitHub -> Repo -> Settings -> **Branches** | Ist der Default-Branch geschützt? Welche Regeln? |
| 4 | GitHub -> Repo -> **Packages** | Existieren die 6 GHCR-Pakete? Sichtbarkeit? Digests? |
| 5 | GitHub -> Settings -> Developer settings -> **Personal access tokens** | Ist der genutzte Token **abgelaufen**? (nur Status, kein Wert) |
| 6 | Cloudflare -> **Workers & Pages** | Welche Worker laufen? Version, letzter Deploy |
| 7 | Cloudflare -> Worker -> Settings -> **Variables and Secrets** | Welche Namen sind gesetzt? (nur Namen) |
| 8 | Cloudflare -> **Workers AI** | Aktiv? Free-Tier-Kontingent? |
| 9 | Vercel -> **Projekt** | Deployments, Aliase, geschützt oder öffentlich? |
| 10 | Vercel -> Settings -> **Environment Variables** | Welche Namen sind gesetzt? (nur Namen) |

> **Berichte diese 10 Punkte als Tabelle, bevor du zu Abschnitt 2 gehst.**
> Ohne diese Bestandsaufnahme weiss niemand, was schon da ist.

---

## 2 · AUFGABE B1 — `github_actions = api_error` aufklären  ⟵ zuerst, weil billig

**Symptom:** Die Plattform meldet für GitHub Actions `status: api_error`, obwohl
`GITHUB_TOKEN` gesetzt ist (`configured: true`). Gleichzeitig konnte sich der
GitHub-MCP-Server nicht verbinden (`CONNECTION_CLOSED`).

**Deine Aufgabe — nur lesen:**

1. GitHub -> Settings -> Developer settings -> **Personal access tokens**
2. Prüfe für den genutzten Token: **abgelaufen?** Welche **Scopes**? Wann zuletzt benutzt?
3. GitHub -> Repo -> **Actions**: laufen Workflows? Gibt es Fehlermeldungen?
4. Prüfe, ob das Konto ein **Rate-Limit** oder eine **Sperre** hat

**Melde:** abgelaufen ja/nein · fehlende Scopes · Rate-Limit ja/nein.
**Rotiere nichts.** Ein neuer Token ist eine Owner-Entscheidung — der Owner hat eine
Rotation in der Vergangenheit ausdrücklich abgelehnt.

---

## 3 · AUFGABE V4 — GitHub Environments anlegen  ⟵ reine Konfiguration, kein Secret

Das löst den **GHCR-Deadlock**: Registry-Push ist vor `MARKET_READY:true` verboten, aber
`MARKET_READY:true` verlangt GHCR-Digests. Der Owner bricht den Zyklus mit
Required-Reviewer-Environments.

**Schritte:**

1. GitHub -> Repo -> **Settings** -> **Environments** -> **New environment**
2. Name exakt: `registry-publication`
3. **Required reviewers** aktivieren, den Owner eintragen -> **Save protection rules**
4. Zurück zu Environments -> **New environment**
5. Name exakt: `production`
6. **Required reviewers** aktivieren, den Owner eintragen -> **Save protection rules**

**Nicht tun:** keinen Workflow starten, keine Deployment freigeben, keine Secrets in die
Environments legen.

**Melde:** beide Environments angelegt · Reviewer gesetzt · Screenshot der Übersicht.

---

## 4 · AUFGABE V1 — GitHub OAuth App (öffnet P3, +56 Punkte)

> **Vorbedingung:** Der Owner muss zuerst entscheiden, **wo** die Auth-Runtime läuft:
> (a) Cloudflare-native stateful, oder (b) gehosteter Agent-API-Stack mit PostgreSQL+Redis.
> Der heutige Vercel-Ursprung ist **read-only** und kann das **nicht**.
> **Ohne diese Entscheidung nicht anfangen** — die Callback-URL hängt daran.

**Schritte:**

1. GitHub -> Profilbild -> **Settings** -> **Developer settings** -> **OAuth Apps**
   -> **New OAuth App**
2. **Application name:** `Cloud Superbrain Developer Platform`
3. **Homepage URL:** der exakte Hosted-Ursprung aus der Entscheidung oben
4. **Authorization callback URL** exakt:
   ```
   https://<AUTH_PUBLIC_ORIGIN>/api/v1/auth/callback
   ```
5. **Register application**
6. **Client ID** notieren — das ist **kein** Secret, darf gemeldet werden
7. **Generate a new client secret** klicken

> ⛔ **Ab hier übernimmt der Mensch.** Du zeigst das Feld, du liest den Wert **nicht**,
> kopierst ihn **nicht** und schreibst ihn **nirgends** hin.
> Der Owner überträgt ihn selbst in den Secret Store.

8. **Scope prüfen:** Die App darf **ausschliesslich** `read:user` anfordern.
   Keine E-Mail-, Repo- oder Org-Scopes. Wenn mehr angefragt wird: **stopp und melden.**

**Diese vier Variablennamen** gehören in den Secret Store des Auth-Runtimes (Werte trägt
der Owner ein):

```
GITHUB_OAUTH_CLIENT_ID
GITHUB_OAUTH_CLIENT_SECRET
GITHUB_OAUTH_REDIRECT_URI
JWT_SIGNING_SECRET
```

**Wo eintragen:**
- **Cloudflare:** Worker -> Settings -> **Variables and Secrets** -> Add -> **Secret** -> Deploy
- **Vercel:** Settings -> Environment Variables -> **gilt erst ab dem nächsten Deployment**

---

## 5 · AUFGABE V3 — `AGENT_API_AUTH_TOKEN` setzen (öffnet P6, +10 Punkte)

**Ein einziges Secret.** Keine Zahlung.

1. Cloudflare -> betroffener Worker -> **Settings** -> **Variables and Secrets**
2. **Add** -> Typ **Secret** -> Name exakt `AGENT_API_AUTH_TOKEN`
3. Der **Owner** fügt den Wert ein — du siehst ihn nicht
4. **Deploy** klicken

> **Falle, die schon einmal Zeit gekostet hat:** `wrangler secret put` scheitert hier mit
> **CF-10053**, weil die Source-Bindungen `plain_text`-Variablen sind. Der richtige Weg
> über die Konsole ist der oben beschriebene; per CLI wäre es
> `wrangler deploy --keep-vars --var …`.

**Melde:** Name gesetzt ja/nein · Deploy erfolgt ja/nein. **Niemals den Wert.**

Den 900-Request-Lastbeweis führt danach **Codex lokal** aus — nicht du.

---

## 6 · AUFGABE V2 — Hosted Staging bereitstellen (öffnet P5, +11 Punkte)

**Das ist der aufwendigste Block.** Verlangt wird laut Verifier wörtlich:
*„Candidate-bound hosted staging verified over non-local HTTPS"*.

**Bedingung:** Es müssen **exakt dieselben Images/Digests** des Kandidaten laufen —
nicht ein neuer Build, nicht ein anderer Commit.

**Deine Schritte:**

1. Cloudflare -> Worker -> prüfen, welche **Source-SHA** dort deployt ist
2. Vergleichen mit dem Kandidaten-SHA, den Codex meldet
3. Stimmen sie **nicht** überein: den Worker auf den Kandidaten-SHA deployen
   — **mit `--keep-vars`**, damit gesetzte Variablen erhalten bleiben
4. Vercel -> Preview/Staging-Deployment auf denselben Commit
5. Prüfen, ob die Fläche **öffentlich erreichbar** ist (nicht Vercel-Login-geschützt) —
   ein geschütztes Deployment kann der Verifier nicht prüfen
6. Die **HTTPS-URL** melden (keine localhost-Adresse)

**Wichtiger Hinweis zum Ist-Zustand:** Die gehosteten Flächen laufen derzeit auf **sehr
altem Code** — Vercel-Frontend `67f41cec` ist **252 Commits** hinter HEAD, der
Backend-Ursprung `21913f8c` sogar **254**. Beide müssen neu deployt werden.

**Nicht tun:** kein Production-Alias umhängen, keine Release-Promotion, kein Rollout.

---

## 7 · WAS DU AUF KEINEN FALL TUST

| Verboten | |
|---|---|
| GHCR-Paket auf **public** stellen | irreversibel, eigene Owner-Entscheidung |
| **Production-Alias** umhängen | Owner-Gate |
| Ein Deployment **freigeben** (`Approve and deploy`) | Owner-Gate, separate Freigabe |
| Ein Repo, Paket, Deployment oder Environment **löschen** | nie |
| Einen Token **rotieren** oder neu erstellen | Owner hat abgelehnt |
| Auf einen **kostenpflichtigen** Tarif wechseln | Free-Only |
| Einen Secret-**Wert** irgendwo hinschreiben | vier Grenzen |
| In `main` / `chore/repo-bootstrap` schreiben | Owner-Gate |

---

## 8 · WAS DU AM ENDE MELDEST

Eine Tabelle, ehrlich, ohne Beschönigung:

| Aufgabe | Status | Beleg |
|---|---|---|
| Bestandsaufnahme (10 Punkte) | | Screenshots |
| B1 GitHub-Token-Diagnose | | abgelaufen? Scopes? Rate-Limit? |
| V4 Environments `registry-publication` + `production` | | Screenshot mit Reviewer |
| V1 OAuth App | | Client ID (kein Secret), Callback-URL, Scope `read:user` |
| V3 `AGENT_API_AUTH_TOKEN` | | Name gesetzt ja/nein, Deploy ja/nein |
| V2 Hosted Staging | | HTTPS-URL, deployte Source-SHA |

**Für jeden Punkt, den du nicht abschliessen konntest: schreib hin warum.**
Ein ehrliches „blockiert, weil …" ist wertvoll. Ein geschöntes „erledigt" macht den
gesamten Nachweis wertlos.

**Melde niemals einen Secret-Wert.** Nur Name und Status.

---

*Erstellt 2026-08-28. Gegenstück für das Repository: `AGENT_AUFTRAG_RC21_UND_RESTLISTE.md` (Codex).
Projektwahrheit: `CODEX_ZIELVERFOLGUNG_KURZ.md`. Regeln: `REGELN_OPTIK_UND_FERTIG.md`.*
