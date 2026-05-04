# SUPERBRAIN GPT-5.5 FIX REPORT — 2026-04-29

## Ergebnis

Ich habe die hochgeladenen Dateien geprüft und ein korrigiertes GPT-5.5/Codex-kompatibles Patch-Bundle erstellt. Die Originaldateien wurden nicht überschrieben; die neuen Dateien sind als `*.fixed.*` bzw. `*_GPT55_PATCHED_*` abgelegt.

## Geprüfte Dateien

- `config.toml`
- `AGENTS.md`
- `CODEX_AGENT_SKILL_MASTER.md`
- `CLOUD_SUPERBRAIN_ULTIMATUM_FINALE_PATCHED.md`
- `CLOUD_SUPERBRAIN_ULTIMATUM_FINALE teil 1 ...md`
- `CLOUD_SUPERBRAIN_ULTIMATUM_FINALE teil 2 ...md`
- `SUPERBRAIN_AUDIT_REPORT_2026-04-29.html`

## Kritische Fehler und Fixes

| ID | Fehler | Fix |
| --- | --- | --- |
| F-01 | `config.toml` nutzt Root-Key `sandbox`, aktueller Codex-Key ist `sandbox_mode`. | `config.fixed.toml` setzt `sandbox_mode = "workspace-write"`. |
| F-02 | `approval_policy = "never"` + volle Schreibmacht kollidiert mit Owner-/Review-Gates. | Interaktives Profil nutzt `approval_policy = "on-request"`; `never` nur read-only audit. |
| F-03 | Deprecated GitHub MCP Paket `@modelcontextprotocol/server-github`. | Ersetzt durch offiziellen Docker-basierten GitHub MCP Server. |
| F-04 | Supabase/Qdrant/CPX51 tauchen in alten Prompts als aktive Defaults auf. | Aktiver GPT-5.5-Ultimatum-Patch sperrt sie Phase 1-5. |
| F-05 | `CODEX_AGENT_SKILL_MASTER.md` liest alte Datei `CLOUD_SUPERBRAIN_ULTIMATUM_FINALE.md`. | Fixed Skill liest `CLOUD_SUPERBRAIN_ULTIMATUM_GPT55_PATCHED_2026-04-29.md`. |
| F-06 | Localhost-Regel war absolut, während Dev-Docker-Tests Localhost nutzen. | Regel präzisiert: Localhost nur DEV-ONLY; Cloud-Gates bleiben blockiert. |
| F-07 | Audit-HTML zeigt harte Blocker, aber keine konkrete GPT-5.5-Konfigurationsreparatur. | Neuer Fix-Report und Fixed-Audit-HTML ergänzt. |

## Validierung

- `config.fixed.toml`: TOML parse OK.
- Kein `sandbox = "danger-full-access"` in den aktiven Fixed-Dateien.
- Kein deprecated `@modelcontextprotocol/server-github` in `config.fixed.toml`.
- GPT-5.5 ist gesetzt; GPT-5.4-Fallback ist dokumentiert.
- Externe Gates bleiben korrekt als offen markiert.

## Nicht automatisch fixbar

- Hosted Staging URL kann ohne echte Infrastruktur nicht erstellt werden.
- GitHub Branch Protection kann ohne Token/Repo-Zugriff nicht gesetzt werden.
- Hetzner Live-Kosten können ohne API/Account nicht verifiziert werden.
- gitleaks kann nur ausgeführt werden, wenn Binary/CI verfügbar ist.
- Live LLM Provider dürfen erst nach Budget-Guard/Owner-Gate aktiviert werden.
