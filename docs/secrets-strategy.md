# Secrets Strategy

Stand: 2026-04-23
Status: Draft fuer Phase 0

## 1. Ziel

Dieses Dokument definiert den kontrollierten Umgang mit Secrets fuer MVP und fruehe Produktionspfade. Es legt pro Secret-Typ genau einen Source-of-Truth-Speicherort fest.

## 2. Grundregeln

1. Keine Secrets im Code, in Commits, in Beispieldateien oder in Logs.
2. Jeder Secret-Typ hat genau einen Source-of-Truth-Speicherort.
3. Laufzeitinjektion erfolgt aus dem Source-of-Truth, nicht aus lokalen Dotenv-Dateien.
4. Public Keys und oeffentliche Projekt-IDs sind keine Secrets und werden getrennt behandelt.
5. Secret-Rotation muss ohne Repo-Aenderung moeglich sein.

## 3. Source-of-Truth pro Secret-Typ

| Secret-Typ | Source-of-Truth | Verwendung |
| --- | --- | --- |
| `production/OPENAI_API_KEY` | GitHub Environment Secret `production` | LLM-Zugriffe im Produktionspfad |
| `production/ANTHROPIC_API_KEY` | GitHub Environment Secret `production` | optionaler LLM-Fallback |
| `production/OPENROUTER_API_KEY` | GitHub Environment Secret `production` | Multi-Provider-Routing |
| `production/GROQ_API_KEY` | GitHub Environment Secret `production` | guenstige Fast-Path-Modelle |
| `production/GITHUB_APP_PRIVATE_KEY` | GitHub Environment Secret `production` | GitHub-App-Signierung |
| `production/GITHUB_WEBHOOK_SECRET` | GitHub Environment Secret `production` | Webhook-Verifikation |
| `production/JWT_SIGNING_KEY` | GitHub Environment Secret `production` | Session- und API-Tokens |
| `production/SESSION_ENCRYPTION_KEY` | GitHub Environment Secret `production` | verschluesselte Sitzungsdaten |
| `production/DATABASE_URL` | GitHub Environment Secret `production` | Datenbankverbindung |
| `production/EMBEDDING_PROVIDER_API_KEY` | GitHub Environment Secret `production` | optionale Live-Embedding-Erzeugung nach Gate D |
| `production/FLY_API_TOKEN` | GitHub Environment Secret `production` | Fly.io Infrastrukturautomation |
| `production/VERCEL_DEPLOY_HOOK_SECRET` | GitHub Environment Secret `production` | kontrollierte Deploy-Triggers |
| `production/MCP_INTERNAL_SHARED_SECRET` | GitHub Environment Secret `production` | interne Tool-Authentisierung |
| `preview/*` Secrets | GitHub Environment Secret `preview` | isolierte Preview-Laufzeiten |

## 4. Nicht-Secrets

Die folgenden Werte werden nicht als Secret gefuehrt, duerfen aber auch nicht frei erfunden werden:

1. Projekt-IDs
2. oeffentliche Callback-URLs
3. reine Feature-Flags ohne Sicherheitswirkung
4. oeffentliche Langfuse-/Grafana-Proxy-Pfade ohne Token

Supabase-spezifische Public Keys sind keine aktiven MVP-Config-Werte mehr. Jede Reaktivierung von Supabase braucht ADR- und Owner-Gate.

## 5. Zugriffspolitik

1. Schreibzugriff auf `production`-Secrets nur fuer Owner und freigegebene CI/CD-Identitaeten.
2. Agenten duerfen Secrets nie lesen oder ausgeben; sie arbeiten nur mit vorhandenen Deploy- und Runtime-Pfaden.
3. Preview-Secrets sind strikt getrennt von `production`.
4. Jeder neue Secret-Typ muss zuerst in dieses Dokument aufgenommen werden.

## 6. Rotation und Incident-Pfad

1. Rotation ausloesen bei Leak-Verdacht, Rollenwechsel, Providerwechsel oder Ablaufdatum.
2. Reihenfolge: Secret im Source-of-Truth erneuern, abhängige Deployments neu ausrollen, alte Version deaktivieren, Audit-Eintrag erzeugen.
3. Bei Secret-Leak: betroffenen Provider sperren, Token rotieren, Runbooks und Audit-Log aktualisieren, betroffene Deployments neu ausrollen.

## 7. Verifikation

Diese Strategie gilt fuer `PHASE 0` als verifiziert, wenn:

1. jeder Secret-Typ genau einen Source-of-Truth hat,
2. keine echten Werte im Repo stehen,
3. Produktions- und Preview-Geheimnisse getrennt sind,
4. Rotation und Incident-Pfad beschrieben sind.
