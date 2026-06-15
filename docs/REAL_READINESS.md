# REAL_READINESS

Stand: 2026-06-14
Scope: lokale DEV-ONLY Runtime auf `http://localhost:8081`

Ehrliche Zaehllogik:
- `ECHT`: Feature liefert lokal ein echtes Nutzerergebnis, nicht nur Marker/dry-run.
- `TEILWEISE`: Teile laufen real, aber die in der Mission geforderte Volltiefe fehlt noch.
- `BLOCKER`: aktuell nicht echt lauffaehig; Grund ist bekannt und nicht gefakt.

Gesamt:
- Voll echt gemaess Missionsdefinition: `2 / 11`
- Ehrliche Quote: `18%`
- DEV-ONLY; hosted proof still blocked.

## F1-F11

| Feature | Status | Ehrlicher Stand |
| --- | --- | --- |
| F1 Echte LLM-Antwort in `/workbench` | `ECHT` | `llm-gateway` laeuft lokal im Modus `local_openai_live` gegen `local_llama_cpp` (`gemma-3-1b-it`). `/workbench` -> Run rendert echten Modelltext, persistiert ein Artefakt und ist mit Screenshot/HAR/Antwort unter `.codex/runs/CURRENT/endziel/F1/` belegt. CPU-Beispiel: ca. 31.8 Tok/s Prompt, 14.6 Tok/s Decode. |
| F2 Echte Agenten | `TEILWEISE` | UI-/Status-/Reset-Pfade laufen lokal, aber Steering nutzt weiterhin den dry-run LLM-Pfad und erzeugt keinen voll echten Agentenlauf mit realem Modelloutput. |
| F3 Multi-Agenten / LangGraph | `TEILWEISE` | Orchestrator/LangGraph/Events laufen lokal, aber nicht als voll echter Multi-Agentenlauf mit echter lokaler LLM-Ausfuehrung. |
| F4 Tools / MCP / CLI | `TEILWEISE` | Read-only Tool-Execute liefert echte lokale Resultate; der volle lokale Sandbox-Container-/CLI-Missionsumfang ist nicht komplett als End-zu-End-Nutzerfeature bewiesen. |
| F5 Skills & Plugins | `BLOCKER` | Registry-/Katalogflaechen existieren, aber kein echter lokaler Register-und-Aufruf-Flow als Nutzerbeweis abgeschlossen. |
| F6 Files / Memory | `TEILWEISE` | Memory-Suche und Artifact-Persistenz laufen lokal; echter kompletter Datei-Lese/Schreib- und pgvector-Endzielpfad ist nicht voll bewiesen. |
| F7 3D-Web-Game | `BLOCKER` | 3D-/Workbench-Flaechen existieren, aber kein echter neuer spielbarer Game-Artifact-Flow mit gespeichertem WebGL-Ergebnis ist bewiesen. |
| F8 Bilder | `BLOCKER` | Kein lokales Bildmodell integriert; keine echte Bilddatei-Erzeugung bewiesen. |
| F9 Docs / Export | `ECHT` | `/docs-output` erzeugt lokal echte Markdown-/PDF-Dateien, liefert einen echten Download und persistiert den Nachweis im Artifact-Register. |
| F10 Video / Media | `BLOCKER` | Kein echter lokaler Video- oder Media-Generierungsstack bewiesen; Hardware-/Toolfrage offen. |
| F11 3D-Organismus Live | `TEILWEISE` | Organismus-UI und lokale Runtime-Events sind echt sichtbar; echter F1-F3 Live-Eventfluss mit lokaler Real-LLM-Kette fehlt noch. |

## Neu bewiesener Slice

- F1 wurde von Dry-Run auf echten lokalen Open-Source-LLM-Betrieb umgestellt.
- Neuer lokaler CPU-Modellpfad: `local-llm` (`ghcr.io/ggml-org/llama.cpp:server`) + `gemma-3-1b-it`.
- `/workbench` nutzt fuer Run jetzt den echten lokalen Chat-Completions-Pfad statt des alten Phase-2-Dry-Runs.
- Persistente Host-Beweise liegen unter `.codex/runs/CURRENT/endziel/F1/` (`llm-response.json`, `workbench-before.png`, `workbench-after.png`, `workbench-f1.har`, `workbench-result.txt`).
- F9 wurde von PlanOnly auf echten lokalen Export umgestellt.
- Klick in `/docs-output` erzeugt jetzt reale Markdown-/PDF-Dateien im Runtime-Temp-Store und startet einen Download.
- Der Export schreibt zusaetzlich einen echten lokalen Artefakt-Eintrag ueber das bestehende Workspace-Artifact-Register.

## Harte Blocker

- Kein lokales Bildmodell.
- Kein echter Game-Generierungs-Endlauf.
- Kein echter Video-/Media-Stack.
