# OWNER-RUNBOOK — SCHRITT FÜR SCHRITT (Stand 2026-07-27)
> Alles hier ist **kostenlos** und **ohne Kreditkarte**. Reihenfolge einhalten.
> Quelle der Anforderungen: `docs/runtime-state/owner-input-manifest.json` (`owner-input-manifest-v2`).

## ✅ BEREITS ERLEDIGT — nichts mehr zu tun
| Gate | Warum erledigt |
|---|---|
| **O2′** Cloudflare-Scopes | Token liest Workers Scripts · D1 · Queues · Durable Objects (alle HTTP 200). `-Profile O2Core` **4/4 PASS**, als `CLOUDFLARE_API_TOKEN_CANDIDATE` persistiert. |
| **O5** Vectorize | Derselbe Token liest Vectorize (HTTP 200), `-Profile O5` **1/1 PASS**. Die Matrix-Forderung „Vectorize Edit ergänzen" ist damit erfüllt. |
| **O6** Live-LLM | Bereits `resolved_verified`. |
| ~~**R2**~~ | ⛔ **Gestrichen.** Cloudflare verlangt eine Zahlungsmethode auch für den Gratis-Tarif → Free-Only-Wand. Artefakte gehen nach D1, Koordination in Durable Objects. Die Matrix erlaubt das ausdrücklich („otherwise keep R2 disabled"). |

| **O1** GitHub-OAuth | ✅ **ERLEDIGT 2026-07-27.** Konfiguration 4/4 lokal verifiziert (`credential_issuance_ready: true`), Vercel-Variablen am Projekt verankert + Redeploy. Der eigentliche Blocker war ein **Compose-Defekt** (die Variablen wurden nie an die agent-api durchgereicht) plus ein viertes, undokumentiertes `JWT_SIGNING_SECRET` — beides behoben, **nicht** durch Owner-Eingaben lösbar gewesen. |

**Offen bleiben genau zwei: O4, dann O3.**

> ⚠️ **Vor O4 unbedingt lesen:** Das bisherige `GITHUB_TOKEN` (`ghp_…`) ist **abgelaufen** — geprüft gegen
> `api.github.com/user` → **HTTP 401**. Es blockierte bereits den Git-Push und hätte
> `apply_github_branch_protection.py` ebenfalls scheitern lassen. Der neue Fine-grained-Token aus O4 ersetzt
> ihn — er ist also **ohnehin nötig**, nicht optional.

---

# O1 — GITHUB-OAUTH (schaltet P3 von 44 % auf 100 %)
**Ziel:** echte Login-Identität statt Fail-closed-Platzhalter. **Dauer ≈ 5 Minuten.**

## ❓ „GitHub ist doch längst mit Vercel verbunden — wozu noch eine App?"
Berechtigte Frage. Es sind **drei völlig verschiedene Dinge**, die nur zufällig alle „GitHub" heißen:

| Was | Wofür | Status |
|---|---|---|
| **GitHub ↔ Vercel Integration** | **Deployment.** Vercel liest das Repo und baut bei jedem Push. Authentifiziert *Vercel gegenüber deinem Repo*. | ✅ längst erledigt — **nicht anfassen** |
| **`GITHUB_TOKEN`** (Maschinen-Token) | **Automatisierung.** Branch-Protection, MCP-/Agent-Writes, API-Zugriffe. Authentifiziert *Skripte gegenüber GitHub*. | ✅ gesetzt (40 Z.) · wird in **O4** erweitert |
| **GitHub OAuth-App** ← *das hier* | **Benutzer-Login.** Damit ein *Mensch* im Browser „Mit GitHub anmelden" klicken und eine Session bekommen kann. Authentifiziert *Nutzer gegenüber deiner App*. | ❌ fehlt — genau das ist O1 |

Die ersten zwei ersetzen die dritte **nicht**. Nachweis direkt von der gehosteten Seite:
`GET https://frontend-seven-psi-78.vercel.app/api/v1/auth/contract` → HTTP 200 mit dem ehrlichen Non-Claim
*„No live GitHub OAuth exchange is claimed without GitHub OAuth credentials."* Es fehlen also wirklich nur
die OAuth-Zugangsdaten — sonst nichts.

> 📱 **Die GitHub-App auf deinem Handy hat mit dem Projekt nichts zu tun.** Das ist der GitHub-Mobilclient
> zum Repos-Ansehen. Nichts zu konfigurieren, nichts zu tun.

## 🔗 DEINE KONKRETE URL
Die von dir genannte Adresse `vercel.com/strazzusochrs-projects/frontend/Cmk8u8a2…` ist die **Vercel-Dashboard-Seite
einer Deployment-ID** — als OAuth-URL unbrauchbar. Gebraucht wird die **öffentliche App-Adresse**.
Verifiziert am 2026-07-27 (HTTP 200 auf `/`, `/login`, `/api/v1/auth/contract`):

```
https://frontend-seven-psi-78.vercel.app
```
> Falls du später eine eigene Domain aufschaltest, muss die Callback-URL in der OAuth-App **mitgeändert** werden.

### Schritt 1 — OAuth-App anlegen
1. `github.com` öffnen, oben rechts auf dein Profilbild → **Settings**
2. Ganz unten links: **Developer settings**
3. Links: **OAuth Apps** → Button **New OAuth App**

### Schritt 2 — Felder ausfüllen
**Kopiervorlage — genau diese Werte:**

| Feld | Wert |
|---|---|
| **Application name** | `Cloud Superbrain` |
| **Homepage URL** | `https://frontend-seven-psi-78.vercel.app` |
| **Application description** | frei lassen |
| **Authorization callback URL** | `https://frontend-seven-psi-78.vercel.app/api/v1/auth/callback` |

> Die Callback-URL muss **zeichengenau** stimmen — GitHub lehnt sonst jeden Login ab.
> Der Pfad `/api/v1/auth/callback` ist im Code fest verdrahtet, den nicht ändern.

3. **Register application** klicken

### Schritt 3 — Zugangsdaten erzeugen
1. Die **Client ID** steht sofort auf der Seite → kopieren
2. Button **Generate a new client secret** → das Secret wird **nur einmal** angezeigt → kopieren

### Schritt 4 — In die Secrets-Datei eintragen
Datei: `C:\Users\immer\.codex\secrets\cloud-superbrain.local.env`
Drei Zeilen ergänzen (**ohne Anführungszeichen, ohne Leerzeichen um `=`, nichts dahinter**):
```
GITHUB_OAUTH_CLIENT_ID=<Client ID>
GITHUB_OAUTH_CLIENT_SECRET=<Client Secret>
GITHUB_OAUTH_REDIRECT_URI=https://frontend-seven-psi-78.vercel.app/api/v1/auth/callback
```
> Die dritte Zeile ist **fertig zum Kopieren** — nur die ersten zwei Werte einsetzen.
> `GITHUB_TOKEN` in derselben Datei **nicht** anfassen; das ist der Maschinen-Token für O4.
> ⚠️ **Häufigster Fehler:** den Token-/App-Namen mit in die Zeile kopieren. Genau das ist beim Cloudflare-Token
> passiert (68 statt 53 Zeichen → `err=6003`). **Nur der Wert, sonst nichts.**

### Schritt 5 — Für die gehostete Seite zusätzlich in Vercel
Vercel-Projekt → **Settings → Environment Variables** → dieselben drei Namen/Werte anlegen → **Redeploy**.

### Fertig, wenn
Codex führt aus: `scripts/verify-phase3-auth-fail-closed.ps1` und `npm run verify:browser`.
→ Gate `production_auth_identity` öffnet sich, **P3 44 % → 100 %**.

---

# O4 — WRITE-ALLOWLIST + BRANCH-PROTECTION (schaltet Agent-/MCP-Writes frei)
**Ziel:** Agenten dürfen echt schreiben, abgesichert durch geschützten Branch und Audit. **Dauer ≈ 10 Minuten.**

### Schritt 1 — Token mit Admin-Rechten erzeugen
1. `github.com` → **Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. **Generate new token**
3. **Repository access** → *Only select repositories* → **`-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`**
4. Unter **Repository permissions** genau diese setzen:

| Permission | Stufe | wofür |
|---|---|---|
| **Administration** | **Read and write** | Branch-Protection setzen |
| **Contents** | **Read and write** | Agent-Writes |
| **Pull requests** | **Read and write** | PR-Fluss |
| **Metadata** | Read (wird automatisch gesetzt) | Pflicht |

5. **Generate token** → Wert wird **nur einmal** angezeigt → kopieren

### Schritt 2 — In die Secrets-Datei
```
GITHUB_TOKEN=<der neue Token>
GITHUB_REPOSITORY=strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM
```
> `GITHUB_REPOSITORY` muss die Form `owner/name` haben — das Skript bricht sonst ab.
> Ein bestehender `GITHUB_TOKEN`-Eintrag wird **ersetzt**, nicht doppelt angelegt (Doppelzeilen brechen Parser).

### Schritt 3 — Branch-Protection anwenden
Es existiert bereits ein Skript dafür. Codex führt aus:
```
python scripts/apply_github_branch_protection.py
```
Das setzt und **verifiziert** den Schutz für `main`. Du musst dafür nichts klicken.

### Schritt 4 — Deine Freigabe-Entscheidungen (die kann nur der Owner treffen)
Codex braucht von dir **schriftlich im Chat**, was erlaubt sein soll:
1. **Welche Repositories** dürfen beschrieben werden? (Vorschlag: nur dieses eine)
2. **Welche Branches**? (Vorschlag: nur `claude/*`-Arbeitsbranches, **niemals `main`**)
3. **Welche MCP-Tools** dürfen schreiben? (Vorschlag: nur Filesystem im Projektordner + Git im Arbeitsbranch)
4. **Audit-Aufbewahrung** bestätigen (Vorschlag: alle Writes im Audit-Log, Aufbewahrung unbegrenzt)

### Fertig, wenn
Codex führt aus: `npm run verify:runtime` und `npm run verify:browser`.
→ Gates `live_agent_tool_writes` + `live_mcp_writes` öffnen sich.

---

# O3 — GHCR-VERÖFFENTLICHUNG (⚠️ ZULETZT)
> **Wichtig:** Die Owner-Matrix verbietet ausdrücklich jede Registry-Veröffentlichung
> **bevor `MARKET_READY: true` erreicht ist.** Mach O3 also **erst ganz am Ende** — nach O1, O4 und dem
> hosted Produkt-Beweis. Wenn du es früher machst, blockiert der Verifier korrekterweise trotzdem.

### Schritt 1 — Token um Package-Rechte erweitern
Beim Token aus **O4** ergänzen (oder klassischen PAT nutzen):

| Token-Typ | Berechtigung |
|---|---|
| Fine-grained | **Packages: Read and write** |
| Classic PAT | Scope **`write:packages`** |

```
GHCR_TOKEN=<Token mit write:packages>
```

### Schritt 2 — Paket öffentlich schalten (das macht es kostenlos)
Nach dem ersten Push: `github.com/strazzusochr?tab=packages` → Paket wählen →
**Package settings** → **Change visibility** → **Public**.
> **Öffentliche GHCR-Pakete sind unbegrenzt gratis.** Private hätten ein Speicherlimit — deshalb öffentlich,
> was ohnehin zum Open-Source-Ziel des Projekts passt.

### Schritt 3 — Release-Freigabe erteilen
Codex darf erst nach deinem ausdrücklichen „Freigabe erteilt" im Chat promoten.

### Fertig, wenn
Codex führt aus: `npm run verify:release-candidate` und `npm run verify:current-release-candidate`.
→ Gate `docker_registry_publish` öffnet sich.

---

## 📋 DEINE CHECKLISTE
- [ ] **O1** OAuth-App anlegen → 3 Variablen in die Secrets-Datei → dieselben in Vercel → Redeploy
- [ ] **O4** Fine-grained Token (Administration + Contents + Pull requests = *Read and write*) → 2 Variablen →
      im Chat beantworten: welche Repos / Branches / MCP-Tools / Audit-Aufbewahrung
- [ ] **O3** *(zuletzt, nach `MARKET_READY: true`)* Packages-Recht → Paket auf **Public** → Freigabe im Chat

## ⛔ WAS DU NIEMALS TUN MUSST
Keine Kreditkarte, kein kostenpflichtiger Tarif, kein Fly.io, kein R2, keine Cloudflare-Containers,
kein Docker-Abo. Wenn dich irgendein Schritt nach Zahlungsdaten fragt: **abbrechen und melden** — dann ist
der Weg falsch, nicht dein Konto.

## ⚠️ DIE EINE FALLE, DIE DICH SCHON ZWEIMAL GETROFFEN HAT
Beim Kopieren von Tokens **nur den Wert** nehmen — nicht den Namen daneben, nicht das curl-Beispiel darunter.
Kontrolle: ein GitHub-Fine-grained-Token beginnt mit `github_pat_`, ein klassischer mit `ghp_`,
ein Cloudflare-Token ist 40 Zeichen (bzw. 53 mit `cfut_`-Präfix). Steht mehr in der Zeile, ist es falsch.
