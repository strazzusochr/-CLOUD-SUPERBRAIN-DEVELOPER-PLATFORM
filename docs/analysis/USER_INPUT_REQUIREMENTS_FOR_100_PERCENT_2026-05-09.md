# User Input Requirements For 100 Percent

Stand: 2026-05-09
Repo: `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM`
Hosted staging: `https://188-34-191-140.sslip.io`

## Zweck

Dieses Dokument ist die aktuelle, nicht-geheime Liste dessen, was vom Owner noch benoetigt wird, damit das Projekt sauber weiter programmiert, verifiziert, rebaselined und spaeter released werden kann.

Es enthaelt keine Secret-Werte. Token duerfen nicht in Chat, Docs, Screenshots oder Git geschrieben werden.

## Analysierte Quellen

- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\docs\CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\PROJECT_STATE.md`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\AI_HANDOFF.md`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\docs\project-progress.manifest.json`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\docs\runtime-contracts\project-progress-completion-contract.md`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\docs\release-checklist.md`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\docs\secrets-strategy.md`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\.env.example`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\staging.env.template`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\docker-compose.cloud.yml`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\scripts\verify-external-gates.ps1`
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\scripts\verify.suites.json`
- `.github\workflows\main-deploy.yml`, `infra-cost-check.yml`, `hosted-staging-proof.yml`, `branch-protection.yml`
- Live checks: SSH to Hetzner staging, GitHub repo lookup, Vercel CLI access check
- `D:\PLATTFORM\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM\docs\analysis\TOOLING_CLI_READINESS_2026-05-09.md`

## Aktuelle harte Wahrheit

- Canonical progress bleibt `70%`.
- Phase 4 ist `100%`.
- Phase 5 ist `67%`.
- Phase 6 ist `0%`.
- Production ist noch nicht ausgerollt.
- Aktiver Candidate bleibt `prod-candidate-2026-05-05-rc1`.
- Candidate source commit bleibt `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5`.
- Aktuelle Owner-Entscheidung bleibt `no-release`.
- Staging nutzt weiterhin mutable `IMAGE_TAG=staging`.
- Staging-zu-immutable-Candidate-Paritaet ist weiterhin blockiert.
- Repo/worktree-Paritaet ist weiterhin blockiert, weil der Workspace nicht clean ist.

## Bereits vorhanden oder verifiziert

Diese Dinge muessen nicht neu erstellt werden, solange keine bewusste Rotation gewuenscht ist.

| Bereich | Status | Beweis |
| --- | --- | --- |
| Hetzner API Token | vorhanden und nutzbar | `D:\PLATTFORM\HCLOUD_TOKEN.txt`; live budget check hat funktioniert |
| Hetzner SSH Zugang | vorhanden und nutzbar | `C:\Users\immer\.ssh\oracle_key`; SSH zu `root@188.34.191.140` funktioniert |
| Docker auf Hetzner | bereit | Remote `docker info` meldet Server Version `29.4.2` |
| Hosted staging | erreichbar | `https://188-34-191-140.sslip.io` |
| GitHub local auth | nutzbar | `gh` kann Repo lesen; Repo `strazzusochr/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM` ist erreichbar |
| Branch protection verify | lokal mit `gh auth token` verifiziert | `scripts\apply_github_branch_protection.py --verify-only` lief erfolgreich |
| OpenAI API Key | lokal im Prozess vorhanden | nicht gedruckt; fuer lokale Live-LLM-Tests grundsaetzlich verfuegbar |
| Vercel Projekt-IDs | vorhanden | `apps\frontend\.vercel\project.json` enthaelt Project/Org IDs |
| Remote `/app/.env` | Schluesselnamen vorhanden | Werte wurden nicht ausgegeben; Schluesselnamen allein beweisen keine gueltigen Provider-Tokens |
| Cloudflare API Token | vorhanden und verifiziert | lokaler Secret-File-Wert ist aktiv; Wrangler funktioniert ausserhalb der aktuellen Sandbox |
| Hugging Face Token | vorhanden und verifiziert | `whoami-v2` identifiziert User `Wrzzzrzr` |
| Zentrale Verify-Suite | vorhanden | `scripts\verify.ps1` plus `scripts\verify.suites.json` |
| Secret Scanner | vorhanden | `gitleaks`, `detect-secrets`, Fallback-Scanner integriert |

## Ungueltig oder nicht aktiv nutzbar

Diese Punkte sind der Grund, warum ich nicht sauber behaupten kann, dass wirklich alles cloudseitig zu 100% bereit ist.

| Bereich | Status | Was fehlt |
| --- | --- | --- |
| Vercel | Token authentifiziert Account, aber Projektzugriff fehlt | `VERCEL_TOKEN` gibt `whoami=strazzusochr`, aber Project/Team API gibt `404 not_found`; Backup-Token ist ungueltig |
| Vercel MCP | `403 Forbidden` auf Project Lookup | Token/App-Zugriff fuer das Team/Projekt fehlt |
| Hetzner Secret-File-Wert | ungueltig fuer `hcloud` | lokaler `HETZNER_API_TOKEN` in `cloud-superbrain.local.env` wurde als unauthorized abgelehnt; `D:\PLATTFORM\HCLOUD_TOKEN.txt` ist der aktuell verifizierte Token |
| GitLab Identity | Token vorhanden, aber ungueltig | GitLab API gibt `401 Unauthorized` |
| GitKraken Identity | optional, nicht aktiv | `GITKRAKEN_API_TOKEN` fehlt; nur `GITKRAKEN_ORG_ID` ist gesetzt |
| Production Release | bewusst blockiert | Owner-Entscheidung von `no-release` auf `approved` und Release-Strategie |
| Repo/Worktree Paritaet | blockiert | Entscheidung, ob aktueller Workspace neuer Candidate wird oder alter Candidate sauber nachgezogen wird |
| Immutable Staging Paritaet | blockiert | Entscheidung, ob `staging` auf Candidate-SHA neu deployed wird oder Candidate auf aktuellen `staging` Stand rebaselined wird |

## Was ich konkret vom User brauche

### 1. Vercel Zugriff korrigieren

Pflicht, wenn Vercel wirklich Teil der finalen Cloud-Struktur sein soll.

Benötigte Werte:

```powershell
$env:VERCEL_TOKEN value redacted; set outside repo via local secret store"
$env:VERCEL_PROJECT_ID = "prj_ZbSNRVz5ijLQ4tQR61liHFw1x5eY"
$env:VERCEL_TEAM_ID = "team_v9yzEnXKNsbQMEIrdf0pd4RT"
```

Anforderung an den Token:

- Zugriff auf Team `team_v9yzEnXKNsbQMEIrdf0pd4RT`
- Zugriff auf Project `frontend`
- Lesen von Project/Deployments
- Deploy/Promote falls Vercel Deployment gewuenscht ist
- Env-Verwaltung falls Vercel Runtime-Env gesetzt werden soll

Aktueller Befund: Der vorhandene `VERCEL_TOKEN` authentifiziert den Account, sieht aber das hinterlegte Project nicht. Der `VERCEL_TOKEN_BACKUP` ist ungueltig.

### 2. Cloudflare Ziel-Domain bestaetigen

Pflicht, wenn Cloudflare Edge, Domain, Cache, DNS oder AI-Gateway wirklich produktiv verdrahtet werden sollen.

Token und Account-/Zone-Werte sind lokal vorhanden; der API-Token wurde als aktiv verifiziert. Noch benoetigt ist die Owner-Bestaetigung, dass die hinterlegte `CLOUDFLARE_PRODUCTION_DOMAIN` die echte Production-Domain ist.

Aktuelle Werte muessen lokal gesetzt bleiben:

```powershell
$env:CLOUDFLARE_API_TOKEN value redacted; set outside repo via local secret store"
$env:CLOUDFLARE_ACCOUNT_ID = "<account-id>"
$env:CLOUDFLARE_ZONE_ID = "<zone-id>"
$env:CLOUDFLARE_PRODUCTION_DOMAIN = "<production-domain>"
$env:CLOUDFLARE_DASHBOARD_URL = "<dashboard-url>"
$env:CLOUDFLARE_AI_GATEWAY_URL = "<optional-ai-gateway-url>"
```

Zusatzentscheidung:

- Welche echte Production-Domain soll verwendet werden?
- Soll `188-34-191-140.sslip.io` nur Staging bleiben?

### 3. Optional: externe Identity-Provider voll gruenschalten

Diese Tokens sind nicht zwingend fuer Hosted Staging, aber sie sind noetig, wenn die Cloud Inventory / Identity Claims wirklich voll verified werden sollen.

```powershell
$env:HF_TOKEN value redacted; set outside repo via local secret store" # currently verified
$env:HF_PROFILE_URL = "https://huggingface.co/Wrzzzrzr"

$env:GITLAB_TOKEN = "<valid-gitlab-token>" # current local value returns 401
$env:GITLAB_PROFILE_URL = "https://gitlab.com/strazzusochr"
$env:GITLAB_API_URL = "https://gitlab.com/api/v4"

$env:GITKRAKEN_API_TOKEN = "<valid-gitkraken-token>" # currently missing
$env:GITKRAKEN_ORG_ID = "<org-id>"
$env:GITKRAKEN_ORG_NAME = "<org-name>"
$env:GITKRAKEN_DASHBOARD_URL = "https://gitkraken.dev"
$env:GITKRAKEN_API_URL = "https://gitkraken.gitclear.com/api/v1"
```

Wenn diese Provider nicht Teil des echten Zielumfangs sind, muessen sie als optionale Non-Claims dokumentiert bleiben.

### 4. GitHub/GHCR Secret Policy fuer CI

Lokal funktioniert GitHub ueber `gh`. Fuer reproduzierbare CI/CD-Laeufe muessen diese Repository- oder Environment-Secrets gesetzt sein:

```text
HETZNER_API_TOKEN
HCLOUD_TOKEN
STAGING_BASE_URL
BRANCH_PROTECTION_TOKEN
OPENAI_API_KEY
```

Je nach finalem Scope zusaetzlich:

```text
VERCEL_TOKEN
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_ZONE_ID
HF_TOKEN
GITLAB_TOKEN
GITKRAKEN_API_TOKEN
```

GHCR Build/Push laeuft in GitHub Actions aktuell ueber `${{ secrets.GITHUB_TOKEN }}`. Ein separater `GHCR_TOKEN` ist nur noetig, wenn lokal oder ausserhalb von GitHub Actions gepusht werden soll.

### 5. Release-Entscheidung

Der aktuelle Candidate sagt explizit `owner_decision=no-release`. Fuer Production brauche ich eine eindeutige Owner-Entscheidung:

```text
owner_decision=approved
approved_release_id=prod-candidate-2026-05-05-rc1
approved_source_sha=ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5
approved_environment=production
```

Oder alternativ:

```text
no production release yet; continue Phase 5 evidence only
```

### 6. Candidate-Strategie

Eine von drei Entscheidungen ist noetig:

1. `deploy immutable candidate`: Staging wird exakt auf `ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5` gezogen und dann verifiziert.
2. `rebaseline current staging`: Der aktuelle `:staging` Stand wird zum neuen Candidate gemacht.
3. `rebaseline current worktree`: Der aktuelle lokale Workspace wird bereinigt, committed, gebaut, deployed und als neuer Candidate verifiziert.

Ohne diese Entscheidung bleibt `staging_tag_parity_status=blocked`.

### 7. Git-/Commit-Policy

Der Workspace ist stark dirty und enthaelt viele untracked Dateien. Ich brauche eine klare Ansage:

```text
Commit strategy:
- create new branch: codex/<name>
- include only verified code/docs/scripts
- keep screenshots/debug artifacts out of git
- do not commit secrets or local token files
```

Oder:

```text
Do not commit yet; only write docs and run verification
```

### 8. Live LLM Gateway Scope

Aktuell ist der LLM-Gateway in den Projekt-Claims weitgehend dry-run/fail-closed. Fuer echte Live-LLM-Verifikation brauche ich:

```powershell
$env:LLM_GATEWAY_MODE = "live"
$env:OPENAI_API_KEY value redacted; set outside repo via local secret store"
$env:OPENAI_RESPONSES_BASE_URL = "https://api.openai.com/v1"
$env:OPENAI_RESPONSES_MODEL = "gpt-5.5"
```

Zusatzentscheidung:

- Darf ein echter kostenpflichtiger OpenAI Responses API Call ausgefuehrt werden?
- Maximaler Testbetrag / Tokenbudget?
- Sollen Anthropic/OpenRouter/Groq wirklich implementiert werden oder bleiben sie nur dokumentierte Secret-Strategy-Optionen?

## Was ich nicht brauche

- Keinen neuen Hetzner Token, solange `D:\PLATTFORM\HCLOUD_TOKEN.txt` weiter gueltig ist.
- Keinen neuen SSH-Key, solange `C:\Users\immer\.ssh\oracle_key` weiter funktioniert.
- Keinen neuen lokalen GitHub Login, solange `gh` weiter funktioniert.
- Keinen neuen lokalen OpenAI-Key fuer reine lokale Tests, solange der aktuelle Prozess-Key gueltig bleibt.
- Keine Tokenwerte im Chat.

## Sichere Uebergabeform

Beste Option: Token als lokale Prozess-Env setzen und danach die Verifier/Deploy-Skripte laufen lassen.

Nicht empfohlen:

- Token in Markdown-Dateien
- Token in `.env.example`
- Token in Screenshots
- Token in Chatnachrichten
- Token in Git

Wenn eine persistente lokale Datei gebraucht wird, dann ausserhalb des Git-Repos, z.B.:

```text
C:\Users\immer\.codex\secrets\cloud-superbrain.local.env
```

Diese Datei muss lokal bleiben und darf nicht committed werden.

## Naechster technischer Ablauf nach Bereitstellung

1. Secrets nur transient laden.
2. `scripts\verify.ps1 -Suite security -RefreshSecretScans`
3. Vercel Token gegen Project/Team pruefen; aktuell blockiert durch fehlenden Projektzugriff.
4. Cloudflare Token gegen Account/Zone pruefen; Token ist aktiv, Domain muss bestaetigt werden.
5. Optional GitLab/HF/GitKraken Identity Probes pruefen.
6. `scripts\verify.ps1 -Suite external-gates -BaseUrl https://188-34-191-140.sslip.io`
7. Candidate-Strategie anwenden.
8. Immutable GHCR / Staging Paritaet klaeren.
9. Hosted smoke + browser contract + release-candidate suite erneut ausfuehren.
10. Erst nach Owner Approval Production Rollout ausfuehren.

## Minimalpaket fuer den naechsten sauberen Fortschritt

Wenn alles auf einmal vorbereitet werden soll, reicht dieses Paket:

1. Gueltiger `VERCEL_TOKEN` mit Zugriff auf das konkrete Frontend-Projekt.
2. Hetzner Secret-Datei korrigieren: `HETZNER_API_TOKEN` oder `HCLOUD_TOKEN` aus dem bekannten gueltigen Token-Source setzen.
3. Ziel-Domain fuer Production bestaetigen.
4. Entscheidung: `deploy immutable candidate`, `rebaseline current staging` oder `rebaseline current worktree`.
5. Entscheidung: `no production release yet` oder `owner_decision=approved`.
6. Erlaubnis fuer einen echten OpenAI Responses API Testcall oder explizite Ablehnung.
7. Entscheidung, ob GitLab/GitKraken Pflicht-Claims oder optionale Non-Claims sind; Hugging Face ist bereits verifiziert.
8. Git-Policy fuer den dirty Workspace.
