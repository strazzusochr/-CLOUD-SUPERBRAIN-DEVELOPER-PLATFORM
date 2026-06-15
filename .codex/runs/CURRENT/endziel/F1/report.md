# F1 - Echtes lokales LLM in /workbench

Stand: 2026-06-14
Status: ECHT (DEV-ONLY)

## Was wurde umgesetzt

- `llm-gateway` auf lokalen OpenAI-kompatiblen CPU-Pfad umgestellt: `local_openai_live`
- Neuer lokaler Modellservice: `local-llm` auf Basis `ghcr.io/ggml-org/llama.cpp:server`
- Modell: `gemma-3-1b-it`
- `/workbench` Run bindet jetzt an `POST /llm/v1/chat/completions` und rendert echten Modelltext
- Persistente Host-Ablage fuer Beweise aktiv unter `.codex/runs/CURRENT/endziel/`

## ECHT-Beweise

- `llm-response.json`
  - direkter API-Beweis: echter Modelltext + Tokenzahlen + `provider_name=local_llama_cpp`
- `workbench-before.png`
  - Browserzustand vor Klick auf Run
- `workbench-after.png`
  - Browserzustand nach echtem Ergebnis
- `workbench-f1.har`
  - Request-/Response-Kette fuer den Browserlauf
- `workbench-result.txt`
  - sichtbarer Result-Block aus `/workbench`

## Beispiel-Metrik

- Prompt-Tokenrate: ca. `31.8 tok/s`
- Decode-Tokenrate: ca. `14.6 tok/s`
- CPU-lokal, ohne Cloud, ohne Token

## Ehrliche Grenzen

- Das ist nur F1.
- Agenten/Multi-Agenten/Organismus-Live aus echtem F1-F3-Strom sind noch nicht abgeschlossen.
- DEV-ONLY; hosted proof still blocked.

