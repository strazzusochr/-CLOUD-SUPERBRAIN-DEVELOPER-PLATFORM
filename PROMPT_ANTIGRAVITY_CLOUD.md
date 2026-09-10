# 🌐 AUFTRAG FÜR ANTIGRAVITY — Cloud-Konsolen im Browser

> **Status: `HISTORICAL_DO_NOT_EXECUTE` (2026-08-29).** Die Bestandsaufnahme `11/13`,
> der behauptete alleinige GitLab-Ausfall und die alte `read:packages`-Ursachenzuordnung
> sind ueberholt. Aktuell sind DEV-ONLY `8/8` Provider konfiguriert, `7/8` live gelesen und
> die Cloud-Layer `6/7`; GitHub Actions und GitLab sind verifiziert, nur der GHCR-Live-Read
> bleibt `api_error`. Verbindlich sind `CODEX_UEBERGABE_2026-08-29-SESSION16.md`,
> `CODEX_ZIELVERFOLGUNG_KURZ.md` und `CODEX_100_PROZENT_ZIEL_2026-08-29.md`.

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

## 1 · BESTANDSAUFNAHME — 11 von 13 Punkten sind BEREITS GEMESSEN

> **Frag nicht nochmal danach.** Diese Werte wurden am 2026-08-28 direkt über `gh`, die
> Cloudflare-API, die Vercel-API, die HF-API und das Cloud-Inventar der Plattform erhoben.
> **Alle 8 Cloud-Provider sind abgedeckt.** Nur **Punkt 1 und 10** fehlen — die sind
> tatsächlich nur im Browser sichtbar. Fang mit denen an, dann geh sofort zu B1 und V4.

| # | Punkt | **Gemessener Ist-Zustand** |
|---|---|---|
| 1 | GitHub OAuth Apps | ⬜ **DU MUSST NACHSEHEN** — über die API nicht listbar |
| 2 | GitHub Environments | ✅ gemessen: **5 Vercel-Auto-Environments** (`Preview`, `Preview – cloud-superbrain-developer-platform`, `Preview – frontend`, `Production – cloud-superbrain-developer-platform`, `Production – frontend`). **`registry-publication` fehlt. `production` (klein) fehlt. KEINES hat protection_rules.** |
| 3 | Branch Protection | ✅ Default-Branch = `chore/repo-bootstrap`, **geschützt**: `required_reviews=true`, `status_checks=true`, `enforce_admins=false` |
| 4 | GHCR-Pakete | ⚠️ **nicht listbar — HTTP 403**: *„You need at least read:packages scope"* |
| 5 | Personal Access Token | ✅ **aktiv**, Konto `strazzusochr`, Scopes: `gist, read:org, repo, workflow`. Rate-Limit **4996/5000** — nicht limitiert. **`read:packages` / `write:packages` FEHLEN.** |
| 6 | Cloudflare Workers | ✅ **2 Worker**: `cloud-superbrain-stateful-runtime` (HTTP 200) und `cloud-superbrain-llm-gateway-preview` (HTTP 200). Beide zuletzt geändert **2026-08-26**. |
| 7 | Worker-Variablen | ✅ teilweise: Health meldet `d1_binding_configured=true`, `write_auth_configured=true`, `auth_required_for_writes=true`. **Exakte Namensliste nur im Browser** |
| 8 | Workers AI | ✅ **aktiv** — LLM-Gateway-Worker meldet `mode=cloudflare_workers_ai_live`, `status=healthy` |
| 9 | Vercel Deployments | ✅ Projekt `frontend` (`prj_ZbSNRVz5ijLQ4tQR61liHFw1x5eY`). **Kein Schutz**: passwordProtection/ssoProtection/trustedIps alle **deaktiviert** -> öffentlich prüfbar. Beide Flächen **HTTP 200**. |
| 10 | Vercel Env-Variablen | ⬜ **DU MUSST NACHSEHEN** — API-Abruf schlug fehl |

### Die restlichen 3 der 8 Cloud-Provider — ebenfalls gemessen

Die Plattform führt **8 Provider**. Die Punkte 1–10 decken GitHub, GHCR, Cloudflare und
Vercel ab. Hier die fehlenden drei plus den stillgelegten:

| # | Provider | Layer | **Gemessener Ist-Zustand** |
|---|---|---|---|
| 11 | **Hugging Face** | L4 · L7 | ✅ `status=verified`, `configured=true`, `live_verified=true`. `HF_TOKEN` **gesetzt**, `HF_PROFILE_URL` **fehlt**. Konto `Wrzzzrzr`, kein Pro. ⚠️ **OAuth-Credential läuft 2026-08-29 02:11 UTC ab** |
| 12 | **GitLab** | L5 · L7 | 🔴 `status=action_required`, `configured=false`. **Alle drei Variablen fehlen**: `GITLAB_TOKEN`, `GITLAB_PROFILE_URL`, `GITLAB_API_URL` |
| 13 | **Grafana Cloud** | L7 | ✅ `status=verified`, `live_verified=true`. `GRAFANA_CLOUD_API_KEY` **gesetzt**, `GRAFANA_CLOUD_URL` **fehlt** |
| — | *Fly.io* | *keine* | ⬛ `historical_read_verified` — **stillgelegt**, „not an active runtime target". **Nichts tun.** Nicht reaktivieren, nicht als verifiziert zählen. |

**Was daraus zu tun ist:**

- **GitLab (12)** ist der einzige echte Ausfall: komplett unkonfiguriert und blockiert
  L5 + L7. Frag den Owner, ob GitLab überhaupt gewollt ist. **Falls nein**, gehört der
  Provider als `optional` markiert statt als `action_required` — sonst zieht er dauerhaft
  eine Gate-Rotfärbung nach sich, die niemand schliessen will.
- **`HF_PROFILE_URL` (11)** und **`GRAFANA_CLOUD_URL` (13)** fehlen. Beides sind
  **keine Secrets**, sondern öffentliche URLs. Der Owner kann sie direkt eintragen.
  `GRAFANA_CLOUD_URL` war in der Vergangenheit die Ursache eines HTTP-503 an der
  Observability-Fläche — also nicht ignorieren.
- **Fly.io** nicht anfassen. Es zählt in keiner Layer-Zuordnung mit.

---

### 🔴 Der wichtigste Befund daraus — B1 ist damit im Kern gelöst

Der Token hat die Scopes `gist, read:org, repo, workflow`. **Es fehlt `read:packages`.**
Genau daran scheitert die Paket-Abfrage mit HTTP 403 — und das ist die naheliegendste
Ursache für `github_actions = api_error` **und** für das blockierte GHCR-Gate.

Der Token ist **nicht abgelaufen** und **nicht rate-limitiert**. Es fehlt nur eine
Berechtigung.

> **Das ist eine Owner-Entscheidung.** Du fügst **keinen** Scope hinzu und erstellst
> **keinen** neuen Token. Zeig dem Owner die Stelle
> (Settings -> Developer settings -> Personal access tokens -> Token -> Scopes) und
> erkläre, dass `read:packages` fehlt. **Er entscheidet.**

### 🔴 Zweiter Befund — die gehosteten Flächen laufen auf sehr altem Code

| Fläche | deployte Quelle | Abstand |
|---|---|---|
| Cloudflare `stateful-runtime` | `d0674bfc` (RC14) | **67 Commits** hinter HEAD · 53 hinter RC20 |
| Cloudflare `llm-gateway-preview` | `d0674bfc` (RC14) | **67 Commits** hinter HEAD |
| Vercel Frontend | `67f41cec` | **252 Commits** hinter HEAD |
| Vercel Backend-Origin | `21913f8c` | **254 Commits** hinter HEAD |

**Alle vier müssen für V2 neu deployt werden** — auf den Kandidaten-SHA, den Codex meldet.

---

## 1b · WAS DU NOCH SELBST NACHSEHEN MUSST — nur diese zwei

**Punkt 1 — OAuth Apps:**
GitHub -> Profilbild -> Settings -> Developer settings -> **OAuth Apps**
Melde: Existiert eine App? Name · Callback-URL · Scopes. Falls keine: sag das klar, dann
ist V1 ein Neuanlegen.

**Punkt 10 — Vercel Environment Variables:**
Vercel -> Projekt `frontend` -> Settings -> **Environment Variables**
Melde **nur die Namen**, niemals Werte. Achte besonders auf:
`GITHUB_OAUTH_CLIENT_ID` · `GITHUB_OAUTH_CLIENT_SECRET` · `GITHUB_OAUTH_REDIRECT_URI` ·
`JWT_SIGNING_SECRET` · `AGENT_API_AUTH_TOKEN`

**Danach sofort weiter mit Aufgabe B1 und V4.** Die restlichen 11 Punkte sind erledigt.

---

<details>
<summary>Ursprüngliche Prüfliste (nur noch Referenz)</summary>

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

</details>

> Die Tabelle oben ist bereits ausgefuellt. Ergaenze nur Punkt 1 und 10.

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
