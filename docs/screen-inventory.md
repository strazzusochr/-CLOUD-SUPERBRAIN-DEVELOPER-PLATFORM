# Screen Inventory

Stand: 2026-04-23
Status: Draft fuer Phase 0
Bezug: `docs/design-spec-register.md`

## 1. Zweck

Dieses Inventar listet die erwarteten Hauptscreens des MVP und ihrer fruehen Ausbaupfade. Es dient als gemeinsame Referenz fuer Design, Frontend und Verifikation.

## 2. Screens

| Screen-ID | Name | Zweck | MVP | Notiz |
| --- | --- | --- | --- | --- |
| `SC-001` | Workspace | zentrale Prompt-Eingabe und Streaming-Ausgabe | ja | Kernscreen des Produkts |
| `SC-002` | Session Detail | Verlauf, Agentenlauf, Evidence, Resultate | ja | braucht Observability-Verknuepfung |
| `SC-003` | Squad Panel | Agentenstatus, Rollen, Stop-Gates | ja | fuer 4-Agenten-MVP |
| `SC-004` | Memory Explorer | Memory-Suche, Summary-Ansicht, Kontextaufnahme | ja | Langzeitgedaechtnis sichtbar machen |
| `SC-005` | GitHub / Delivery View | PR-, Pipeline- und Release-Kontext | optional spaet MVP | stark von CI/CD-Reife abhaengig |
| `SC-006` | 3D Game Surface | 3D-Webgame-Rendering, HUD, Fallback-Zustaende | ja | WebGPU mit WebGL-Fallback |
| `SC-007` | Admin / Cost Control | Limits, Providerstatus, Rotation, Alerts | spaeter | nicht fuer ersten Nutzerfluss prioritaer |

## 3. Regeln

1. Jeder neue produktrelevante Screen bekommt eine stabile `Screen-ID`.
2. Ein Screen gilt erst als umsetzungsreif, wenn Verweis auf Design-Spec und UI-State-Matrix existiert.
3. Nicht jeder Screen ist Teil des ersten MVP-Releasepfads.

## 4. Verifikation

Dieses Inventar gilt fuer Phase 0 als ausreichend, wenn:

1. die MVP-Hauptscreens sichtbar sind,
2. 3D-Rendering und Memory nicht vergessen wurden,
3. spaetere Admin- und Delivery-Flaechen eindeutig reserviert sind.
