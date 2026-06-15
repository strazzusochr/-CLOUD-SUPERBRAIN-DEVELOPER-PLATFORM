# Assumption Log

Stand: 2026-04-23
Status: Active

## Zweck

Dieses Register sammelt bewusste Annahmen, die fuer die aktuelle Planung verwendet werden, aber spaeter bestaetigt oder ersetzt werden muessen.

## Eintraege

| Datum | Annahme | Warum aktuell sinnvoll | Risiko bei falscher Annahme | Trigger fuer Neubewertung |
| --- | --- | --- | --- | --- |
| 2026-04-23 | GitHub Environment Secrets genuegen fuer MVP als Source-of-Truth | schnell, guenstig, ohne Zusatzbetrieb | spaetere Compliance- oder Betriebsgrenzen | Security-/Compliance-Review oder Phase-4-Haertung |
| 2026-04-23 | `4` Agenten sind die sinnvolle MVP-Standardgroesse | deckt Goal Lock und Budget gleichzeitig ab | fruehe Engpaesse oder zu geringe Parallelitaet | erste reale Nutzungs- und Kostenmessungen |
| 2026-04-23 | PostgreSQL/pgvector bleibt fuer MVP die aktive Runtime-Grenze | reduziert Providerdrift und haelt Memory/Checkpointing in einem Modell | spaetere Skalierungsgrenzen | Phase-6-Datenbank-Review |
| 2026-04-23 | WebGPU plus WebGL-Fallback deckt MVP-Bedarf ausreichend ab | zukunftsfaehig und browserrobust | zu hohe Frontend-Komplexitaet oder schwache Kompatibilitaet | erste Browser-Matrix und Prototyping |
| 2026-04-23 | LiteLLM deckt die noetige Gateway-Kontrolle fuer den MVP ab | zentrale Providersteuerung | Sonderfaelle oder Kostenkontrolle reichen nicht aus | Gateway-Prototyp oder Lasttests |
