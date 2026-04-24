████████████████████████████████████████████████████████████████████

SUPREME GODMODE SYNTHESIS ENGINE — FORENSIC DEPTH ACTIVATION

Dual-Skill Execution: PLANNING-ARC × SYNTHESIS-ENGINE

Dokument: -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM ULTIMATUM FINALE

Modus: MAXIMALE TIEFE · MAXIMALE VOLLSTÄNDIGKEIT · KEIN TOKEN VERGEUDET

████████████████████████████████████████████████████████████████████



═══════════════════════════════════════════════════════════════════

PRÄAMBEL — DUAL-SKILL AKTIVIERUNG

═══════════════════════════════════════════════════════════════════

Beide Skills sind jetzt gleichzeitig aktiv. Ihre Rollen sind komplementär und nicht trennbar:

SYNTHESIS-ENGINE übernimmt: Vollständige Dokument-Ingestion, forensische Tiefenanalyse, Cross-Dokument-Abgleich (hier: Intra-Dokument-Kohärenz), Lückenidentifikation, Widerspruchsmarkierung, Entscheidungsregister, Risikoregister, Master-Summary.

PLANNING-ARC übernimmt: Project Goal Lock Preservation, Memory Protocol Maintenance, Phase Execution Governance, Module Wiring Verification, Agent Governance Codex, Interface Contract Enforcement, Verification-First Engineering, Release Readiness Architecture, Anti-Drift Protocol, Next-Step-Block.

Diese Ausgabe ist das einzige Dokument das du brauchst um von Phase 0 zu Phase 5 zu kommen — ohne Informationsverlust, ohne Architektur-Drift, ohne Fake-Done.



═══════════════════════════════════════════════════════════════════

A. DOKUMENT-REGISTER

═══════════════════════════════════════════════════════════════════

\[D1] — ULTIMATUM FINALE / SUPREME GODMODE SYNTHESIS 2026

FeldInhaltLabelD1 — Master Synthesis DocumentKurzfunktionEinzige Wahrheitsquelle für das gesamte Projekt; löst 10 Vorgängerdokumente abHauptthemaCloud-native Multi-Agent AI Developer Platform, vollständig prompt-gesteuertStrategische RelevanzKRITISCH — ersetzt alle vorherigen Versionen; enthält Goal Lock, 11 System-Regeln, 7-Schichten-Architektur, Memory-System, Agent-Governance, UI/UX-System, Rotations-Engine, 6-Phasen-Roadmap, 10 Risiken, 20 Fallen, Pflicht-ArtefakteVertrauensgradHOCH — explizit als finale Auflösung von 14 Konflikten zwischen 10 Vordokumenten positioniertBesonders wichtige InhalteBudget-Limit 20€/Monat (hart), 14 Widerspruchs-Auflösungen, NEXT PROMPT Blocks per Phase, Memory-Konsolidierungslogik, Agent-Governance-Regeln G1-G7, UI-Zustandsmatrix, Rotations-Engine-Ablauf, Risikoschweregrad-Matrix

Interne Dokument-Qualitätsbewertung:



Vollständigkeit: 87/100 — Stärken in Architektur und Governance; Lücken in konkreten Interface-Contracts, Schema-DDL, API-Spezifikationen, Deployment-Playbooks

Kohärenz: 91/100 — Widersprüche weitgehend aufgelöst, aber 6 residuale Spannungen verbleiben (siehe Abschnitt E)

Operationalisierbarkeit: 72/100 — Gute Richtung, aber konkrete Implementierungsdetails fehlen in mehreren Modulen

Verifikationstiefe: 68/100 — Definition-of-Done vorhanden, aber Verifikationsbeweise nicht definiert





═══════════════════════════════════════════════════════════════════

B. EINZELSYNTHESE \[D1] — FORENSISCHE TIEFENANALYSE

═══════════════════════════════════════════════════════════════════

B.1 — TEIL 0: PROJECT GOAL LOCK

Analysiert:

Das Dokument definiert einen stabilen Goal Lock mit klarer North-Star-Formulierung. Die Kern-Fähigkeiten (5 Items) sind gut spezifiziert. Die harten Constraints (8 Items) sind eindeutig und unveränderlich deklariert.

Was zwingend erhalten bleiben muss:



KEIN Localhost — absolut, null Ausnahmen

KEINE lokalen Modell-Downloads — nur API-Inferenz

KEIN direkter Agent-Commit in Main ohne Human-Review-Gate

KEINE unkontrollierten Loops ohne Maximum-Iterations-Schutz

KEINE Secrets im Code

20€/Monat Infrastruktur-Betrieb — hartes Limit

OPEN-SOURCE-FIRST



Implizite, nicht explizit ausgesprochene Constraints (forensisch extrahiert):



Async-First-Constraint (implizit): Da keine lokale Last erlaubt ist und 3D-Builds "2-5 Minuten" dauern dürfen, ist das gesamte System implizit async-first. SSE-Streaming ist nicht optional — es ist architektonisch zwingend.

Single-Tenant-Assumption (Phase 1-5): Der Text adressiert immer "einen einzelnen Entwickler" als primären Nutzer. Dies ist eine implizite Single-Tenant-Architektur-Annahme in Phase 1-5. Multi-Tenancy ist erst Phase 6+. Diese Annahme muss explizit in ADR-006 dokumentiert werden, weil sie Auth-Design, Memory-Partitionierung und Cost-Tracking direkt beeinflusst.

Stateless-Frontend-Constraint (implizit): Vercel darf keine DB-Verbindungen haben. Das Frontend ist implizit vollständig stateless. State lebt im Orchestrator auf Hetzner.

Human-Override-First-Constraint (implizit): Der Text fordert Human-in-the-Loop für kritische Aktionen. Dies bedeutet implizit, dass alle kritischen Operationen eine asynchrone Confirmation-API benötigen — kein synchrones Blockieren des Agenten.



Offene Fragen aus Goal Lock:



OQ-01: Was ist die exakte Definition von "active user" für die K3s-Migrations-Bedingung ">3 aktive Nutzer"? Gleichzeitig oder kumulativ?

OQ-02: "Unbegrenzt in 4er-Agenten-Squads skalieren" — was ist das technische Maximum-Concurrency-Ziel für Phase 5 (vor K3s)?

OQ-03: "Hunderte von Prompts" als Langzeitgedächtnis-Ziel — ist das ein absoluter Schwellenwert oder eine Größenordnung?



B.2 — TEIL 1: DIE 11 ABSOLUTEN SYSTEM-REGELN

Analysiert:

Alle 11 Regeln sind klar, eindeutig und operationalisierbar. Regel R1-R9 entsprechen den Regeln im PLANNING-ARC Skill (Rule 1-9). R10 und R11 sind projektspezifische Ergänzungen.

Forensische Prüfung: Sind alle 11 Regeln durchsetzbar?



R1 (Keine Lügen): ✅ Durchsetzbar via Observability-Pflicht und Verifikations-Check

R2 (Kein Fake-Done): ✅ Durchsetzbar via Definition-of-Done-Matrix (Teil 12 SKILL)

R3 (Kein Zielverlust): ✅ Durchsetzbar via Goal Lock + NEXT PROMPT FOR AGENT

R4 (Keine Architekturdrift): ✅ Durchsetzbar via ADR-Pflicht — ABER: ADR-Trigger-Bedingungen sind nicht exakt definiert. Was genau löst einen neuen ADR aus? → LÜCKE L-01

R5 (Keine losen Fragmente): ✅ Durchsetzbar via Full Wiring Rule (SKILL §10) — ABER: keine explizite Wiring-Checkliste pro Modul → LÜCKE L-02

R6 (Keine unmarkierte Unsicherheit): ✅ Gut definiert

R7 (Kein One-Shot-Chaos): ✅ Phasenmodell ist vorhanden

R8 (Keine Blocker-Ausreden): ✅ Blocker-Handling-Protokoll vorhanden

R9 (Kein Release-Betrug): ✅ Release-Checkliste in Phase 5 geplant

R10 (Budgetgrenze hart): ✅ — ABER: Monitoring-Mechanismus für 20€/Monat Infrastruktur noch nicht implementiert. Wie wird das Infrastruktur-Budget getrennt vom LLM-Budget getrackt? → LÜCKE L-03

R11 (Open-Source Standard): ✅ — ABER: Kein expliziter Prozess für den Fall dass kein OSS-Äquivalent existiert. Wer entscheidet? Welche Prüfschritte? → LÜCKE L-04



B.3 — TEIL 2: SYSTEM-ARCHITEKTUR

Analysiert — 7 Schichten:

Alle 7 Schichten sind klar definiert mit Besitzer, Input, Output und verbotenen Aktionen. Dies ist ein starkes Architektur-Fundament.

Forensische Prüfung der Schicht-Grenzen:

SCHICHT 1 → SCHICHT 2 Interface:



Interface: REST/SSE

Fehlende Details: HTTP-Methoden, Endpoint-Pfade, Request/Response-Schema, Auth-Header-Format, SSE-Event-Types, Reconnect-Strategie bei SSE-Verbindungsabbruch → LÜCKE L-05

Kritische Lücke: Was passiert wenn Vercel-Edge-Function Timeout nach 30 Sekunden erreicht wird und der Agent noch arbeitet? SSE-Verbindung bricht ab. Wie wird der User informiert? Wie läuft die Wiederverbindung? Dies muss explizit designed werden.



SCHICHT 2 → SCHICHT 3 Interface:



Interface: "Task-Assignment" — nicht spezifiziert

Fehlende Details: Task-Assignment-Datenstruktur, Queue-Mechanismus (Redis Queue? Direct Call?), Backpressure-Strategie bei überlasteten Agenten → LÜCKE L-06



SCHICHT 3 → SCHICHT 4 Interface:



Interface: "Generischer LLM-Request" via LiteLLM

LiteLLM ist OpenAI-API-kompatibel — gut definiert

ABER: Streaming-Protokoll von LiteLLM zurück zum Agenten nicht beschrieben → LÜCKE L-07



SCHICHT 3 → SCHICHT 5 Interface:



Interface: MCP-Protokoll (Anthropic Standard 2024/25)

ABER: Welche MCP-Version genau? MCP hat mehrere Versionen. Versionspinning ist nicht definiert → LÜCKE L-08



SCHICHT 6 Memory-Konsolidierung — Kritische Analyse:

Das 3-Layer-Memory-System ist konzeptuell gut. Aber die Konsolidierungslogik hat einen impliziten Race Condition:



Redis TTL = 30 Minuten

Konsolidierungsjob läuft alle 30 Minuten

PROBLEM: Wenn der Job bei Minute 29 läuft und ein Entry bei Minute 1 erstellt wurde (28 Minuten alt), wird er nicht konsolidiert. Der Job muss alle Entries mit TTL < 5 Minuten konsolidieren — aber was wenn TTL-Drift durch Redis-Neustart entsteht? → RISIKO R-NEW-01

LÖSUNG-EMPFEHLUNG: Konsolidierungsjob auf TTL-basiertes Pattern umstellen: Job läuft alle 5 Minuten und schreibt alle Entries mit remaining\_ttl < 8 Minuten (Puffer). Dies verhindert Datenverlust bei Edge-Cases.



Deployment-Targets — Forensische Kostenprüfung:

Hetzner CPX51: €6-42/Monat. Das Dokument nennt diese Range ohne zu erklären wann welcher Preis gilt. CPX51 Kosten laut aktuellen Hetzner-Preisen (Stand April 2026): ca. €17-20/Monat je nach Region und Commitment. Damit wird das 20€/Monat-Infrastruktur-Limit durch den Server allein nahezu ausgeschöpft. Der CX22 Staging-Server (Phase 1, Aufgabe 1.6) kommt zusätzlich hinzu.

KRITISCHES PROBLEM: CPX51 (\~€17-20) + CX22 Staging (\~€4) = \~€21-24/Monat — das übersteigt das 20€/Infrastruktur-Limit bereits in Phase 1! → WIDERSPRUCH W-RESIDUAL-01 (Siehe Abschnitt E)

B.4 — TEIL 3: MEMORY-SYSTEM

Analysiert:

Das dreischichtige Memory-System ist gut konzipiert. Die Konsolidierungslogik ist nachvollziehbar. Die DSGVO-Purge-Pflicht ist explizit und korrekt positioniert (Phase 3).

Forensisch extrahierte implizite Anforderungen:



Embedding-Consistency-Anforderung: Wenn das Embedding-Modell gewechselt wird (z.B. von text-embedding-3-small zu einem OSS-Modell), werden alte Embeddings inkompatibel. Es muss eine Re-Embedding-Strategie definiert werden. → LÜCKE L-09

Chunk-Überlapp-Strategie: 512 Token Chunks mit 64 Token Overlap. Bei Prompts über mehrere Agenten-Iterationen können Chunks künstliche Trennungen an semantisch kritischen Stellen erzeugen. Die Chunk-Strategie sollte sentence-boundary-aware sein. → Empfehlung (nicht Blocker)

Memory-Search-Result-Injection: "Top-5 relevanteste Chunks werden als Kontext zum nächsten Agenten-Prompt hinzugefügt." Top-5 × 512 Token = 2.560 Token zusätzlicher Kontext pro Agent-Call. Bei einem 4K Context-Window-Modell (z.B. Claude Haiku Standard) ist das 64% des Kontextfensters verbraucht, bevor der Task-Prompt beginnt. → RISIKO R-NEW-02

Neo4j-Optionalität: Knowledge Graph ist als "optional Phase 4+" definiert. Dies ist korrekt. ABER: Das Schema für den Knowledge Graph ist komplett undefiniert. Wenn Phase 4 kommt, fehlt die Grundlage. Minimales Schema sollte in Phase 0-Dokumentation bereits skizziert werden. → LÜCKE L-10



B.5 — TEIL 4: AGENTEN-SYSTEM UND GOVERNANCE

Analysiert:

Die 7 Governance-Regeln (G1-G7) sind stark und operationalisierbar. Die Agenten-Profile für Phase 1-5 sind detailliert. Besondere Stärken:



Max-Execution-Time pro Agent definiert

Max-Output-Tokens differenziert

Eskalationsbedingungen klar



Forensisch extrahierte Governance-Lücken:

G1-Lücke: "Kein Agent trifft Architektur-Entscheidungen außerhalb des ADR-Registers" — ABER: Wie erkennt ein Agent, dass eine Entscheidung architekturrelevant ist? Kein Klassifizierungsschema definiert. → LÜCKE L-11

G2-Lücke: "Erledigt bedeutet: implementiert + getestet + integriert + Ergebnis rückgeliefert + geloggt." — ABER: Wer validiert diese 5 Kriterien? Der Agent selbst? Der Orchestrator? Nur ein Mensch? → LÜCKE L-12

G4-Lücke: "Kein Agent schreibt in Main-Branch" — ABER: Wie ist GitHub Branch Protection technisch konfiguriert? Branch-Schutz-Regeln für GitHub müssen explizit als Konfigurationsartefakt definiert werden. → LÜCKE L-13

G6 impliziert API-Vertrag: "Agent ruft Memory-System ab" — Dies impliziert einen definierten Memory-Read-API-Vertrag zwischen Agent und Memory-Schicht. Dieser Vertrag ist nicht spezifiziert. → LÜCKE L-14

Agenten-Profil CODER-AGENT — Kritische Analyse:

Max-Output-Tokens: 8192. Aktueller Claude Haiku 4.5 unterstützt bis zu 8192 Output-Tokens. ABER: DeepSeek-Chat hat je nach Version unterschiedliche Output-Limits. Versionspinning ist auch hier nicht definiert. → LÜCKE L-15

Agenten-Profil TESTER-AGENT:

E2B-Session-Pflicht: "Immer im finally-Block schließen. Timeout: 30 Minuten automatisch." Das ist korrekt. ABER: Was ist der Wiederherstellungs-Plan wenn E2B-API down ist? Tester-Agent fällt dann komplett aus. Graceful Degradation für E2B-Ausfall ist nicht definiert. → LÜCKE L-16

DEVOPS-AGENT — Kritische Analyse:

"Verbotene Aktionen: Direkte SSH-Verbindung auf Production-Server" — ABER: Wie deployt der DevOps-Agent dann in Phase 5? GitHub Actions ist der vorgesehene Weg, aber der Mechanismus "DevOps-Agent triggert GitHub Actions Workflow" ist nicht im Detail beschrieben. Welche GitHub Actions API-Endpunkte? Welche Authentifizierung? → LÜCKE L-17

Phase 6 Agenten-Profile:

4 Profile (Research, Security, Documentation, Database) sind nur grob skizziert. Kein Max-Execution-Time, kein Max-Retry, keine Eskalationsbedingungen. Dies ist Phase 6 — aber ein Minimum-Template sollte bereits definiert werden, damit Phase 6 nicht von Null beginnt. → Empfehlung

B.6 — TEIL 5: UI/UX-DESIGNSYSTEM

Analysiert:

Das Designsystem ist durchdacht. 9 Pflicht-Zustände pro Screen sind eine starke Anforderung. Die 4 Haupt-Screens sind klar definiert.

Forensisch extrahierte UI-Lücken:



Screen 3 (Agent-Activity) → Langfuse-Detailansicht: "Link zur Langfuse-Detailansicht" — ABER: Langfuse ist auf Hetzner deployed und nicht öffentlich erreichbar (laut Observability-Strategie). Wie kommt der User zur Langfuse-Detailansicht? VPN? Separater Auth-Flow? → LÜCKE L-18

Screen 4 (Cost-Monitor) — Export-Funktion: Format undefined. CSV? JSON? PDF? Wer triggert den Export? Welche Zeiträume? → LÜCKE L-19

Mobile-Responsiveness: Nicht adressiert. Ist das bewusst ausgeschlossen? → OQ-04

3D-Preview-Screenshot: "Screenshot-Vorschau im Workspace bevor User zur URL navigiert" — Playwright-MCP macht den Screenshot. ABER: Wie wird das Screenshot-Bild vom Hetzner-Server zum Vercel-Frontend transportiert? Base64 in SSE-Event? Object-Storage-URL? → LÜCKE L-20

Kein Error-Recovery-UI definiert: Was sieht der User wenn der gesamte Orchestrator-Stack ausfällt? Kein Fallback-UI-State für "System komplett nicht erreichbar" definiert. → LÜCKE L-21



B.7 — TEIL 6: ROTATIONS-ENGINE

Analysiert:

Das "Never blocked, always rotating" Prinzip ist stark. Die 6-Schritte-Ablauflogik ist klar. Die Fallback-Reihenfolge ist sinnvoll.

Forensisch extrahierte Rotations-Lücken:



Rotation-State-Persistence: Wenn Provider A ausfällt und auf Provider B gewechselt wird, wird der Rotations-State in Memory gespeichert. ABER: Nach welcher Zeit wird zurück zu Provider A rotiert? Exponential Backoff? Manuelles Reset? → LÜCKE L-22

Kosten-Spike durch Rotation: Fallback kann zu teureren Modellen führen als geplant. "Niemals teures Modell als Fallback wenn günstiges ausreicht" — aber wer entscheidet "ausreicht"? Modell-Capability-Matrix ist nicht definiert. → LÜCKE L-23

Rotation-Log-Format: "Rotationshistorie erfassen in Observability-System" — aber welches Format? Strukturiertes JSON? Wie wird auf historische Rotationen zugegriffen? → LÜCKE L-24



B.8 — TEIL 7: PHASEN-MODELL

Phase 0 — Analysiert:

5 klar definierte Aufgaben. NEXT PROMPT ist vollständig und kopierbar. Starke Phase.

Residuale Lücke Phase 0: Aufgabe 0.5 (Codex-Integration) beschreibt was erstellt werden soll, aber nicht den Inhalt von CODEX\_AGENT\_SKILL\_MASTER.md. Was soll darin stehen? Dies ist der einzige undefinierte Inhalt in Phase 0. → LÜCKE L-25

Phase 1 — Analysiert:

6 klar definierte Aufgaben. NEXT PROMPT vorhanden. Staging-Pflicht ist korrekt gesetzt.

Kritische Infrastruktur-Lücke Phase 1:

Aufgabe 1.2 (Docker-Compose Design) listet 8 Services. ABER: Langfuse benötigt 3 Container (Server + Worker + PostgreSQL). Wenn Langfuse eine eigene PostgreSQL-Instanz benötigt, bedeutet das 9+ Container, NICHT 8. Zudem: Läuft Langfuse auf derselben PostgreSQL-Instanz wie die Agent-Datenbank? Dies muss explizit entschieden werden, da es die DB-Performance beeinflusst. → WIDERSPRUCH W-RESIDUAL-02

Aufgabe 1.3 (CI/CD-Skeleton): 3 Workflows definiert. ABER: Wie wird das Staging-Deploy ausgelöst? Der Text sagt "Deploy zu Staging (automatisch)" — ABER: welcher Runner? GitHub-hosted-Runner kann nur auf öffentliche Server zugreifen. Hetzner-Server ist nicht öffentlich für direkte SSH. Deploy via Docker Hub + Hetzner Webhook? Via SSH mit GitHub Actions Secret? → LÜCKE L-26

Phase 2 — Analysiert:

LangGraph-Orchestrator mit 6 Nodes definiert. Memory-Konsolidierungsjob als Background-Worker. MCP-Server für 4 Tool-Sets.

Kritische LangGraph-Lücke Phase 2:

"LangGraph-Checkpointer: ausschließlich mit PostgreSQL (NIEMALS In-Memory in Production)" — ABER: Wie wird der LangGraph-Checkpoint-Schema auf der PostgreSQL-Datenbank initialisiert? Welche Tabellen erstellt LangGraph automatisch? Welche Migrations-Strategie? → LÜCKE L-27

Fehlender Node im LangGraph-Graph:

6 Nodes definiert: Intent-Parser, Task-Router, Agent-Executor, Result-Aggregator, Memory-Updater, Error-Handler. ABER: Kein expliziter "Budget-Guard"-Node. Budget-Checks sollten als eigener Node oder Middleware implementiert werden, der VOR dem Agent-Executor läuft. → ARCHITEKTUR-EMPFEHLUNG AE-01

Phase 3 — Analysiert:

Korrekte Positionierung von Auth, DSGVO, Rate-Limiting, Frontend. NEXT PROMPT vorhanden.

Phase 3 Auth-Design-Lücke:

JWT mit GitHub OAuth. ABER: Refresh-Token-Rotation-Strategie nicht definiert. Wenn Refresh-Token kompromittiert wird, wie wird es invalidiert? Blacklist in Redis? → LÜCKE L-28

Phase 4 — Analysiert:

10 Integrations-Test-Szenarien geplant. Security-Audit-Checkliste geplant. Performance-Baseline definiert.

Phase 4 Lücke — Konkrete Test-Scenarios fehlen:

Die 10 Szenarien sind nur als Titel aufgelistet (Happy Path, Retry-Limit etc.) aber nicht ausgeschrieben. Der NEXT PROMPT für Phase 4 fordert das Ausschreiben — aber der Masterplan selbst enthält sie nicht. Das ist konsistent (Agenten-Output), aber es bedeutet dass Phase 4 erst sinnvoll beginnen kann wenn Phase 2-3 vollständig funktional sind. → Anmerkung (kein Blocker)

Phase 5 — Analysiert:

Release-Checkliste mit 4 Sektionen, Rollback <5 Minuten-Ziel, Git-Artifact.

Phase 5 kritische Lücke:

Rollback-Plan ist als Ziel beschrieben aber nicht als Prozedur. "Rollback muss auf Staging getestet worden sein" — ABER: Was genau wird rollbacked? Docker-Image-Tags? DB-Migrations? Beide? Was passiert wenn ein Migration-Rollback scheitert? → LÜCKE L-29

Phase 6 — Analysiert:

3D-Webgame-Pipeline ist gut skizziert. Platform-Twin-Regeln sind klar restriktiv.

B.9 — TEIL 8: RISIKO-REGISTER

Alle 10 Risiken analysiert:



R1 (Kostenexplosion): Korrekt als KRITISCH eingestuft. Mitigation ist stark (Rate-Limiting als allererstes).

R2 (Architecture Drift): Korrekt als SEHR HOCH Wahrscheinlichkeit. ADR-Register ist notwendig aber nicht hinreichend — automatische Drift-Detection fehlt. → Empfehlung

R3 (Memory-Konsistenz-Verlust): Mitigations-Strategie hat die Race-Condition-Lücke (R-NEW-01, oben bereits identifiziert).

R4 (MCP-Server-Ausfall): "2 Instanzen für kritische Tools" — welche Tools sind "kritisch"? Liste fehlt. → LÜCKE L-30

R5 (3D-Rendering-Latenz): Gut mitigiert durch Client-Side-Rendering und Progress-Indicator.

R6 (Secrets-Leak): Stark mitigiert. Secret-Scanner-Tool nicht genannt. gitleaks? trufflehog? → LÜCKE L-31

R7 (Agent schreibt in Main): Stark mitigiert durch Branch-Protection.

R8 (LangGraph State-Recovery): Mitigation abhängig von Phase 2 State-Recovery-Test. Testprozedur nicht definiert. → LÜCKE L-32

R9 (Supabase Free-Tier-Pause): Keep-Alive-Ping beschrieben, aber Implementierungsdetail fehlt. Cron-Job? Scheduled GitHub Action? → LÜCKE L-33

R10 (WebGPU-Kompatibilität): Korrekt mitigiert durch Feature-Detection + WebGL-Fallback.



B.10 — TEIL 9: DIE 20 FALLEN

Analysiert:

Alle 20 Fallen sind valide und aus echter Engineering-Erfahrung destilliert. Keine der 20 ist redundant.

Forensisch hinzuzufügende Fallen (nicht in D1 enthalten):



Falle 21 — Single-Region-Dependency: Hetzner Frankfurt-Region als Single-Region. Wenn Frankfurt-Rechenzentrum-Ausfall, ist die gesamte Platform down. Phase 1-5 ist bewusst Single-Region — das ist korrekt. Aber ein Runbook für Rechenzentrum-Ausfall fehlt komplett.

Falle 22 — LiteLLM-Single-Point-of-Failure: LiteLLM als einzelner Gateway ist ein SPOF für alle LLM-Calls. Wenn LiteLLM abstürzt, sind alle Agenten blind. Restart-Prozedur und Health-Check müssen explizit definiert sein.

Falle 23 — Embedding-Model-Dependency-Lock: Wenn das gewählte Embedding-Modell decommissioned wird, sind alle gespeicherten Embeddings wertlos. Abstraktionsschicht für Embedding-Modelle ist empfohlen.

Falle 24 — Agent-Self-Assessment-Bias: Agenten bewerten ihre eigene Arbeit als "done". G2 adressiert das konzeptuell, aber kein technischer Enforcement-Mechanismus. Peer-Review zwischen Agenten oder Orchestrator-Level-Check ist notwendig.





═══════════════════════════════════════════════════════════════════

C. GEMEINSAME WAHRHEITEN (MEHRFACH BESTÄTIGT / INTERN KONSISTENT)

═══════════════════════════════════════════════════════════════════

Die folgenden Punkte sind intern in D1 konsistent, explizit ausgesprochen und durch multiple Abschnitte bestätigt:

C1 — Budget-Limit-Konsistenz \[D1 K1, R10, Teil 0, Teil 4.4]

20€/Monat Infrastruktur ist hartes Limit. Diese Aussage erscheint mindestens 8× im Dokument in verschiedenen Kontexten und ist vollständig konsistent.

C2 — Open-Source-First-Konsistenz \[D1 R11, Teil 0, Teil 2.4]

Open-Source-Präferenz ist konsistent durch alle Schichten. Die Ausnahme-Regelung ist klar: OSS fehlt UND Budget erlaubt es UND Owner-Freigabe.

C3 — No-Localhost-Konsistenz \[D1 Teil 0, Falle 6, Teil 2.2]

Absoluter Cloud-First-Ansatz ist durch alle Teile konsistent.

C4 — PostgreSQL-Checkpointer für LangGraph \[D1 K12, Phase 2, Falle 12, R8]

MemorySaver ist in Production verboten. PostgreSQL-Checkpointer ist Pflicht. 4× bestätigt.

C5 — Langfuse als Observability-Standard \[D1 K4, Teil 2.4, Falle 10, Phase 1]

Langfuse self-hosted auf Hetzner ist Standard. LangSmith ist nur ergänzend wenn Budget frei. Konsistent.

C6 — Client-Side WebGPU \[D1 K14, Teil 0, Phase 6, Falle 14, Teil 2.4]

Server-Side GPU erst Phase 6. Client-Side WebGPU mit WebGL-Fallback ist Standard. 5× bestätigt.

C7 — Max 5 Retry-Cycles \[D1 G3, Phase 2, Teil 4.2]

Maximale Retry-Anzahl für alle Agenten ist 5. Keine Ausnahmen. 3× bestätigt.

C8 — Dark Mode Standard \[D1 K6, Teil 5.1, Teil 5.2]

Dark Mode ist obligatorisch. Kein Light Mode als Default. 3× bestätigt.

C9 — Docker Compose bis Phase 6 \[D1 K11, Teil 2.4, Phase 1]

K3s erst wenn >3 aktive Nutzer oder >12 parallele Agenten. Docker Compose bis dahin. 3× bestätigt.

C10 — Human-Review-Gate für Production-Merge \[D1 G7, Teil 0, G4]

Kein Agent merged in Main. Nur Menschen. 3× bestätigt.



═══════════════════════════════════════════════════════════════════

D. ERGÄNZENDE ERKENNTNISSE (STRATEGISCH WICHTIG, NUR EINMAL GENANNT)

═══════════════════════════════════════════════════════════════════

D-E1 — CODEX\_LOADER\_PROMPT.txt Konzept \[D1 Phase 0.5]

Einmalig erwähnt aber strategisch wichtig. Dieser Loader-Prompt ist das Werkzeug das einen Codex-Agenten mit dem gesamten Projektkontext initialisiert. Er ist der Schlüssel zur Portabilität des Projekts zwischen Claude, Codex und anderen Ausführungsumgebungen. Seine Nicht-Existenz in Phase 0 blockiert Codex-Integration vollständig.

D-E2 — Cloudflare AI Gateway 40% Kosten-Caching \[D1 Teil 2.2]

Einmalig erwähnt. Wenn Cloudflare AI Gateway identische LLM-Anfragen cached, können bis zu 40% der LLM-Kosten eingespart werden. Dies ist eine direkte Entlastung für das 200€/Monat LLM-Budget. Die Implementierung dieser Caching-Schicht sollte in Phase 2 Priorität erhalten.

D-E3 — Coolify als optionales Server-Management \[D1 Phase 1, 1.1]

Einmalig als "optional" erwähnt. Coolify würde Docker-Management, Deployment-Automation und Service-Monitoring deutlich vereinfachen, ist aber nicht im Stack-Standard definiert. Wenn Coolify genutzt wird, beeinflusst es docker-compose.yml-Struktur, Port-Management und Reverse-Proxy-Konfiguration. Eine explizite Entscheidung ist notwendig. → OQ-05

D-E4 — Helicone Free Tier Limit \[D1 Teil 2.4]

Einmalig erwähnt: "100k requests/Monat". Wenn das Projekt über 100k LLM-Calls/Monat geht, fällt Helicone als kostenloses Cost-Tracking-Tool aus. Was ist der Fallback für Cost-Tracking jenseits von 100k Calls? → OQ-06

D-E5 — Platform-Twin/Clone Audit-Requirement \[D1 K7, Phase 6]

Einmalig als Phase-6-Meilenstein definiert. Die Regel "Alle Meta-Aktionen müssen auditierbar sein" ist kritisch. Was konkret bedeutet "auditierbar" für Selbstmodifikationen? Ein Selbstmodifikations-Audit-Log-Schema sollte bereits in Phase 0-Dokumentation skizziert werden, auch wenn die Implementierung Phase 6 ist.

D-E6 — Qdrant als separater Vector-DB-Service \[D1 Teil 2.4]

Qdrant ist im Stack definiert als "Qdrant OSS self-hosted auf Hetzner für semantische Memory-Schicht." ABER: In der 8-Service-Docker-Compose-Liste (Phase 1.2) erscheint Qdrant als einer von 8 Services. In Teil 3 (Memory-Schicht) wird Supabase pgvector → Hetzner pgvector als Long-Term-Memory definiert. Wann ist Qdrant die Memory-Datenbank und wann ist es pgvector? Sind das parallele Systeme für unterschiedliche Anwendungsfälle? → WIDERSPRUCH W-RESIDUAL-03

D-E7 — GitHub Actions Free für OSS \[D1 Teil 2.4]

"GitHub Actions free für OSS." — ABER: Ist das Projekt-Repository öffentlich? Wenn es privat ist, gelten Standard-Limits (2000 Minuten/Monat auf Free Tier). Dies beeinflusst CI/CD-Strategie erheblich. → OQ-07



═══════════════════════════════════════════════════════════════════

E. WIDERSPRÜCHE UND SPANNUNGEN (RESIDUAL — NACH DEN 14 AUFGELÖSTEN K-KONFLIKTEN)

═══════════════════════════════════════════════════════════════════

Das Dokument hat 14 Konflikte explizit aufgelöst. Diese 6 residualen Spannungen wurden durch forensische Analyse identifiziert und sind NICHT in den 14 Auflösungen enthalten:



W-RESIDUAL-01 — Infrastruktur-Budget vs. tatsächliche Hetzner-Kosten

Konflikt: Hartes Infrastruktur-Limit: 20€/Monat. CPX51 (Hauptserver): \~€17-20/Monat. CX22 Staging: \~€4/Monat. Summe: \~€21-24/Monat. Das übersteigt das Limit.

Beteiligte Aussagen: Teil 0 (20€ Limit), Teil 2.2 (Hetzner CPX51 €6-42/Monat), Phase 1.6 (CX22 €4/Monat Staging-Pflicht).

Mögliche Erklärung: Das Dokument könnte CPX11 (€4/Monat) für Phase 1 meinen, nicht CPX51 (€17+). CPX51 wäre dann erst Phase 3-4 wenn wirklich Last entsteht. Oder: "20€/Monat Infrastruktur" schließt Staging nicht ein und gilt nur für Production.

Auswirkung: Wenn nicht aufgelöst, ist Phase 1 Budget-kompromittiert bevor Code geschrieben wird.

REQUIRED DECISION RD-01: Welcher Server-Typ startet in Phase 1? CPX11/CX21 für MVP + CX22 Staging, beides zusammen ≤ €8/Monat? Oder CPX51 von Anfang an mit Staging im selben Server (kein separater Staging-Server)?

Empfohlene Auflösung: Phase 1-2: CX21 (€5/Monat) Production + Staging auf demselben Server (Docker-Compose mit separatem Staging-Stack). Phase 3-4: CPX31 (€10/Monat) wenn Last wächst. Phase 5+: CPX51 nur wenn nachgewiesen benötigt. Staging läuft auf separatem CX22 erst wenn Production und Staging divergieren.



W-RESIDUAL-02 — Langfuse-PostgreSQL vs. Agent-PostgreSQL (Datenbankkonflikt)

Konflikt: Langfuse benötigt eine eigene PostgreSQL-Datenbank (nicht optional — Langfuse-Architektur erfordert eigene DB). Gleichzeitig ist eine PostgreSQL-Instanz für Agent-Daten vorgesehen. Sind das eine oder zwei PostgreSQL-Instanzen?

Beteiligte Aussagen: Teil 2.4 (Supabase pgvector für MVP-Datenbank), Phase 1.2 (postgres als einer von 8 Services + langfuse-server + langfuse-worker in derselben Liste).

Mögliche Erklärung: Langfuse kann auf derselben PostgreSQL-Instanz laufen (separates Schema/Database). Das spart Ressourcen aber erhöht Risiko gegenseitiger Beeinträchtigung.

Auswirkung: Ressourcenplanung für Hetzner-Server. Wenn zwei PostgreSQL-Instanzen, erhöht sich RAM-Bedarf deutlich.

REQUIRED DECISION RD-02: Shared PostgreSQL mit separaten Databases für Langfuse und Agent-Daten, oder zwei separate PostgreSQL-Instanzen?

Empfohlene Auflösung: Shared PostgreSQL-Instanz, zwei separate Databases: superbrain\_prod (Agent-Daten) und langfuse (Observability-Daten). Ressourceneffizienter für Phase 1-4. Migration zu separaten Instanzen in Phase 5-6 wenn nötig.



W-RESIDUAL-03 — Qdrant vs. pgvector für semantische Memory

Konflikt: Stack-Tabelle (Teil 2.4) definiert "Qdrant OSS self-hosted auf Hetzner für semantische Memory-Schicht." Aber Teil 3 (Memory-System) definiert "Supabase pgvector → Hetzner pgvector" als Long-Term-Memory für semantische Suche.

Mögliche Erklärung: Qdrant könnte für eine andere Anwendung geplant sein (z.B. 3D-Asset-Suche, Phase 6), während pgvector die Haupt-Memory-Schicht ist. Oder Qdrant ist als Alternative zu pgvector geplant wenn pgvector-Performance nicht ausreicht.

Auswirkung: Wenn beide deployed werden, erhöht sich Komplexität und Ressourcenverbrauch. Wenn nur einer, muss entschieden werden welcher.

REQUIRED DECISION RD-03: Ist Qdrant für Phase 1-5 aktiv? Wenn ja, welchen Use-Case löst es anders als pgvector?

Empfohlene Auflösung: pgvector als primäre Vector-Memory-Schicht (Phase 1-5). Qdrant als Phase-6-Option wenn pgvector-Performance unter Last nicht ausreicht oder spezifische Qdrant-Features (Filtered Search, Multiple Vectors per Point) benötigt werden. Qdrant aus Phase-1-Docker-Compose entfernen um Ressourcen zu schonen.



W-RESIDUAL-04 — LangGraph vs. CrewAI Doppel-Orchestrierung

Konflikt: ADR-001 bestätigt LangGraph als Haupt-Orchestrator. Aber Teil 2.4 Stack-Tabelle sagt: "LangGraph OSS. Ergänzt durch CrewAI OSS für rollenbasierte 4er-Squads."

Problem: LangGraph und CrewAI sind beide Orchestrierungs-Frameworks. Wenn beide aktiv sind, welche Entität orchestriert welche andere? Läuft CrewAI innerhalb von LangGraph-Nodes? Oder sind sie koordiniert?

Auswirkung: Architektur-Grundfrage die die gesamte Orchestrierungs-Schicht betrifft.

REQUIRED DECISION RD-04: Wie ist die genaue Beziehung zwischen LangGraph und CrewAI? Option A: LangGraph ist der übergeordnete Graph, CrewAI-Crews laufen als Nodes innerhalb von LangGraph. Option B: LangGraph ist stateful State-Machine, CrewAI verwaltet Agent-Rollen innerhalb eines "Agent-Executor"-Schritts. Option C: CrewAI wird nicht verwendet, LangGraph implementiert rollenbasierte Squads nativ.

Empfohlene Auflösung: Option B ist die eleganteste: LangGraph verwaltet Workflow-State und Checkpointing. CrewAI-Crew wird als atomarer Agent-Executor-Step innerhalb eines LangGraph-Nodes verwendet. Dies trennt State-Management (LangGraph) von Role-Management (CrewAI) sauber.



W-RESIDUAL-05 — Supabase für MVP und gleichzeitig postgres in Docker

Konflikt: Teil 2.4 definiert "Supabase free tier + pgvector" als MVP-Datenbankschicht. Phase 1.2 listet "postgres (pgvector, intern Port 5432)" als einen der 8 Docker-Services auf Hetzner.

Problem: Wenn Supabase für Phase 1-3 genutzt wird, warum dann auch eine lokale PostgreSQL-Instanz auf Hetzner?

Mögliche Erklärung: Die Hetzner-PostgreSQL könnte für LangGraph-Checkpointing genutzt werden (LangGraph-Checkpointer benötigt direkten DB-Zugriff, was mit Supabase über Netzwerk möglicherweise zu langsam oder problematisch ist), während Supabase für Long-Term-Memory-Embeddings genutzt wird.

REQUIRED DECISION RD-05: Welche Daten gehen nach Supabase und welche in die Hetzner-PostgreSQL? Vorschlag: Hetzner-PostgreSQL für LangGraph-Checkpoints (Performance-kritisch, lokal). Supabase für pgvector-Embeddings (Phase 1-3, dann Migration). LangGraph-Checkpoints werden nie zu Supabase migriert — sie bleiben immer lokal.



W-RESIDUAL-06 — Continuous Staging vs. Budget-Limit

Konflikt: "Staging läuft immer" (Phase 1.6) impliziert dauerhaft laufenden zweiten Server. Aber 20€/Monat Infrastruktur-Limit. Wenn CPX51 \~€17-20/Monat kostet und CX22 Staging \~€4/Monat, ist Budget überschritten (wie bereits W-RESIDUAL-01). Selbst wenn Production auf CX21 (\~€5/Monat) startet: CX21 (€5) + CX22 Staging (€4) + Cloudflare (€0) = €9/Monat. Das ist im Budget. Aber CX21 hat nur 2 vCPU und 4 GB RAM — zu wenig für alle 8 Services gleichzeitig (Langfuse allein empfiehlt 4 GB RAM + 8 GB Swap).

REQUIRED DECISION RD-06: Welche Services laufen in Phase 1 auf dem Server? Volle 8-Service-Umgebung erfordert mindestens CX31 (4 vCPU, 8 GB RAM, \~€10/Monat) oder CPX21 (3 vCPU, 4 GB RAM, €8/Monat). Budget-konformes Phase-1-Setup: CPX21 Production (\~€8) + CX11 Minimal-Staging (\~€4) = €12/Monat. Gibt €8 Puffer.



═══════════════════════════════════════════════════════════════════

F. LÜCKEN UND UNSICHERHEITEN — VOLLSTÄNDIGES LÜCKEN-REGISTER

═══════════════════════════════════════════════════════════════════

Alle im Dokument D1 identifizierten Lücken, sortiert nach Kritikalität:

F.1 — KRITISCHE LÜCKEN (Blocker für jeweilige Phase)

IDLückeBetroffene PhaseImpactL-01ADR-Trigger-Bedingungen nicht definiert — was löst neuen ADR aus?Phase 0R4-Regel nicht durchsetzbarL-05Schicht-1/2-Interface-Spec fehlt (HTTP-Methoden, SSE-Event-Types, Reconnect)Phase 2-3Frontend-Backend-Integration blockiertL-06Task-Assignment-Datenstruktur zwischen Orchestrator und Agenten undefiniertPhase 2Agenten-Integration blockiertL-13GitHub Branch-Protection-Konfiguration nicht als Artefakt definiertPhase 1G4 technisch nicht durchsetzbarL-26Deploy-Mechanismus zu Hetzner via GitHub Actions nicht spezifiziertPhase 1CI/CD-Skeleton nicht implementierbarL-27LangGraph-Checkpoint-Schema-Initialisierung und Migration undefiniertPhase 2Checkpointer nicht aufzusetzenL-29Rollback-Prozedur nicht als Schritt-für-Schritt-Runbook definiertPhase 5Rollback-Test nicht durchführbar

F.2 — HOHE LÜCKEN (Risiko für Qualität und Sicherheit)

IDLückeBetroffene PhaseImpactL-03Infrastruktur-Budget-Tracking-Mechanismus undefiniertPhase 1+R10 nicht operationalisierbarL-07LiteLLM-Streaming-Protokoll zurück zum Agenten nicht beschriebenPhase 2Streaming-Pipeline unvollständigL-08MCP-Version nicht gepinntPhase 2KompatibilitätsrisikoL-12Done-Validierungs-Instanz (Agent vs. Orchestrator vs. Mensch) undefiniertPhase 2G2 nicht durchsetzbarL-14Memory-Read-API-Vertrag zwischen Agent und Memory-Schicht fehltPhase 2Agenten können Memory nicht strukturiert abfragenL-16E2B-Ausfall-Graceful-Degradation fehltPhase 2Tester-Agent SPOFL-17DevOps-Agent → GitHub Actions Trigger-Mechanismus undefiniertPhase 2-3Deployment-Trigger nicht implementierbarL-18Langfuse-Erreichbarkeit für End-User nicht gelöstPhase 3Screen 3 funktioniert nicht ohne LösungL-22Provider-Rotation-Backoff-Strategie und Reset-Logik fehltPhase 2+Rotation kann im schlechtesten Provider steckenL-28Refresh-Token-Rotation und Invalidierung undefiniertPhase 3Auth-SicherheitslückeL-31Secret-Scanner-Tool nicht konkret benanntPhase 1R6-Mitigation nicht implementierbarL-32State-Recovery-Testprozedur nicht definiertPhase 2R8-Mitigation unverified

F.3 — MITTLERE LÜCKEN (Qualitätssicherungs-relevant)

IDLückeBetroffene PhaseImpactL-02Wiring-Checkliste pro Modul fehltAlleR5 schwer durchsetzbarL-04OSS-Alternativ-Prüfprozess für proprietäre Tools fehltAlleR11 subjektivL-09Re-Embedding-Strategie bei Modellwechsel fehltPhase 4Memory-Inkonsistenz bei ModellwechselL-10Knowledge-Graph-Minimum-Schema für Phase 4+ fehltPhase 4Phase 4 startet ohne GrundlageL-11Klassifizierungsschema für architekturrelevante Entscheidungen fehltAlleG1 schwer durchsetzbarL-15DeepSeek-Version und Output-Token-Limit nicht verifiziertPhase 2Coder-Agent könnte abgeschnitten werdenL-19Cost-Monitor Export-Format undefiniertPhase 3Screen 4 unvollständigL-20Screenshot-Transport-Mechanismus (Playwright → Frontend) undefiniertPhase 63D-Preview brichtL-21UI-Fallback-State für kompletten System-Ausfall fehltPhase 3Schlechte UX bei OutageL-23Modell-Capability-Matrix für Rotation-Eignung fehltPhase 2Rotation kann ungeeignete Modelle wählenL-24Rotation-Log-Format undefiniertPhase 2Observability lückenhaftL-25CODEX\_AGENT\_SKILL\_MASTER.md Inhalt nicht definiertPhase 0Codex-Integration nicht aufzusetzenL-30"Kritische MCP-Server" Liste fehlt (welche brauchen 2 Instanzen?)Phase 1R4-Mitigation unvollständigL-33Supabase-Keep-Alive-Ping Implementierungsdetail fehltPhase 1R9 nicht mitigiert

F.4 — OFFENE FRAGEN (Owner-Entscheidung erforderlich)

IDFrageBetroffene PhaseOQ-01Definition "aktiver Nutzer" für K3s-SchwellenwertPhase 6OQ-02Maximum-Concurrency-Ziel vor K3s (Phase 5)Phase 4-5OQ-03"Hunderte von Prompts" — absoluter Schwellenwert?Phase 2OQ-04Mobile-Responsiveness — bewusst ausgeschlossen?Phase 3OQ-05Coolify-Entscheidung: nutzen oder nicht?Phase 1OQ-06Helicone-Fallback jenseits 100k Calls/MonatPhase 3+OQ-07GitHub-Repository: öffentlich oder privat?Phase 0



═══════════════════════════════════════════════════════════════════

G. VOLLSTÄNDIGES RISIKO-REGISTER (ERWEITERT)

═══════════════════════════════════════════════════════════════════

Alle 10 Risiken aus D1 plus neu identifizierte Risiken:

G.1 — KRITISCHE RISIKEN (Schweregrad: Systemgefährdend)

R1 — Kostenexplosion durch unkontrollierte API-Loops \[D1]



Ursache: LLM-Calls ohne Limit, Agenten-Loops ohne Abbruchbedingung

Auswirkung: Budget-Überschreitung, finanzielle Schäden

Betroffene Bereiche: Alle LLM-Calls in Schicht 4

Dringlichkeit: SOFORT — Phase 2, Schritt 1

Gegenmaßnahme: Rate-Limiting + Budget-Alert (80% = 160€) vor erstem Production-LLM-Call. Helicone ab erstem Call. Upstash-Rate-Limiter für alle öffentlichen API-Endpoints.



R6 — Secrets-Leak durch Agent-generierten Code \[D1]



Ursache: Agenten könnten Secrets in generierten Code oder Log-Output einbetten

Auswirkung: Credential-Kompromittierung, Security-Breach

Betroffene Bereiche: Coder-Agent, Log-System, GitHub-Repository

Dringlichkeit: HOCH — Pre-Phase 2

Gegenmaßnahme: gitleaks als Pre-Commit-Hook + GitHub-Actions-Secret-Scan. Agents haben keinen .env-Lesezugriff.



R7 — Agent schreibt in Main-Branch oder Production-DB \[D1]



Ursache: Misconfigured Branch-Protection oder fehlerhafte Tool-Permission

Auswirkung: Ungeprüfter Code in Production, Datenverlust

Betroffene Bereiche: GitHub-MCP, DevOps-Agent, Production-Datenbank

Dringlichkeit: HOCH — Phase 1 (Branch-Protection vor erstem Agenten-Lauf)

Gegenmaßnahme: Branch-Schutzregeln als IaC-Artefakt. Datenbankuser für Agenten: READONLY. Nur Migrations-Service hat WRITE-Rechte.



R-NEW-01 — Memory-Konsolidierungs-Race-Condition \[Neu identifiziert]



Ursache: Redis-TTL-Drift bei Server-Neustart, Konsolidierungsjob-Timing

Auswirkung: Memory-Entries gehen verloren, Kontext-Bruch für Agenten

Betroffene Bereiche: Schicht 6 (Memory)

Dringlichkeit: HOCH — Phase 2

Gegenmaßnahme: Konsolidierungsjob auf 5-Minuten-Interval verkürzen, Entry-Status-Flag implementieren (pending/consolidated/failed), Retry-Logic für fehlgeschlagene Konsolidierungen.



G.2 — HOHE RISIKEN

R2 — Architecture Drift durch schnelle Iteration \[D1]



Ursache: Schnelle Änderungen ohne ADR-Dokumentation

Auswirkung: Inkompatible Module, Technical Debt-Akkumulation

Gegenmaßnahme: ADR-Trigger-Checkliste (Lücke L-01) schließen. Weekly Architecture Review als feste Routine.



R3 — Memory-Konsistenz-Verlust \[D1 + R-NEW-01]



Ursache: Race Condition im Konsolidierungsjob (verstärkt durch R-NEW-01)

Gegenmaßnahme: Wie R-NEW-01.



R4 — MCP-Server-Ausfall lähmt alle Agenten \[D1]



Ursache: Single-Instance MCP-Server als SPOF

Gegenmaßnahme: Kritische MCP-Server (GitHub-MCP, E2B-MCP) in 2 Instanzen. Graceful Degradation: wenn GitHub-MCP down → kein Coder-Agent → User-Notification. Health-Check alle 30 Sekunden.



R8 — LangGraph State-Recovery nach Server-Neustart \[D1]



Gegenmaßnahme: PostgreSQL-Checkpointer. State-Recovery-Testprozedur definieren (Lücke L-32 schließen): Server während aktivem LangGraph-Run neustarten, verificieren dass State korrekt wiederhergestellt wird.



R9 — Supabase Free-Tier-Pause \[D1]



Gegenmaßnahme: Scheduled GitHub Action (täglich) als Keep-Alive-Ping. Alternativ: cron-Job auf Hetzner curl https://<supabase-project>.supabase.co/rest/v1/ -H "apikey: <anon-key>" 2>/dev/null alle 6 Tage.



R-NEW-02 — Context-Window-Erschöpfung durch Memory-Injection \[Neu identifiziert]



Ursache: Top-5 × 512 Token Memory-Chunks = 2.560 Token vor Task-Prompt. Bei kleinen Context-Windows erschöpft.

Auswirkung: Truncation von Task-Prompt oder Memory-Kontext, degradierte Agent-Performance

Betroffene Bereiche: Alle Agenten, Schicht 6

Dringlichkeit: MITTEL — Phase 2

Gegenmaßnahme: Modell-spezifisches Context-Budget-Management. Memory-Injection-Budget: max. 30% des Kontextfensters. Bei kleinen Modellen (Haiku): Top-3 statt Top-5. Bei großen Modellen (GPT-4o): Top-10 möglich.



G.3 — MITTLERE RISIKEN

R5 — 3D-Rendering-Latenz-Erwartung \[D1] — gut mitigiert.

R10 — WebGPU-Browser-Kompatibilität \[D1] — gut mitigiert.

R-NEW-03 — LiteLLM Single Point of Failure \[Neu identifiziert]



Ursache: LiteLLM als einziger Gateway für alle LLM-Calls

Auswirkung: Wenn LiteLLM abstürzt, sind alle Agenten blind

Gegenmaßnahme: Docker health-check mit auto-restart. Supervisor-Process. Alert wenn LiteLLM >30 Sekunden nicht erreichbar.



R-NEW-04 — Embedding-Model-Decommission \[Neu identifiziert]



Ursache: Embedding-Modell wird vom Provider eingestellt

Auswirkung: Alle gespeicherten Embeddings inkompatibel, semantische Suche broken

Gegenmaßnahme: Abstraktionsschicht für Embedding-Modell. Embedding-Modell-Version in jedem pgvector-Eintrag speichern. Re-Embedding-Prozedur als Runbook.





═══════════════════════════════════════════════════════════════════

H. VOLLSTÄNDIGES ENTSCHEIDUNGS-REGISTER

═══════════════════════════════════════════════════════════════════

H.1 — FINALE ENTSCHEIDUNGEN (aus 14 Widerspruchs-Auflösungen)

IDEntscheidungBegründungStatusK120€/Monat Infrastruktur-Limit. LLM-API separat max. 200€/Monat Phase 1-3.Hartes Budget-ConstraintENTSCHIEDENK27 tech. Schichten + 5 Governance-Schichten parallelKompatibles Dual-ModelENTSCHIEDENK3Supabase Free (Phase 0-1), Pro ab 400MB, Migration Hetzner Phase 4Kostenoptimierung + KontrolleENTSCHIEDENK4Langfuse self-hosted als Standard. LangSmith nur ergänzend wenn Budget freiOSS-FirstENTSCHIEDENK5MetaGPT + Strands: Phase-6-Optionen, nicht Kern-StackKomplexitätskontrolleENTSCHIEDENK6Dark Mode, Indigo/Violett/Türkis, 5 StatusfarbenPlattformCS-Designsystem verbindlichENTSCHIEDENK7Twin/Clone: Phase-6-Meilenstein, auditierbar, keine autonome Policy-UmschreibungSicherheitskritischENTSCHIEDENK8Codex ist valide Ausführungsumgebung für Coder-AgentFlexibilitätENTSCHIEDENK9Never blocked, always rotating. Rotation immer sichtbar, nie Budget-brechendCore-PrinzipENTSCHIEDENK10NEXT PROMPT FOR AGENT nach jeder PhaseKontinuitätENTSCHIEDENK11Docker Compose Phase 1-5. K3s erst bei >3 Nutzer oder >12 AgentenNo Over-EngineeringENTSCHIEDENK12Observability separat deployed. Main-App nur Status-BannerKlare TrennungENTSCHIEDENK13D1 Handoff-Template ist einziges gültiges FormatKonsistenzENTSCHIEDENK14Hetzner GEX44 GPU erst Phase 6 wenn nachgewiesen. Client-Side WebGPU bis dahinCost-ControlENTSCHIEDEN

H.2 — ERFORDERLICHE NEUE ENTSCHEIDUNGEN (Owner-Input benötigt)

IDEntscheidungOptionenBlocker wenn nicht entschiedenRD-01Server-Typ Phase 1 (Budget vs. Kapazität)CX21+CX11 / CPX21+CX11 / CPX51 ohne StagingPhase 1.1RD-02Shared vs. separate PostgreSQL (Langfuse + Agent)Shared (resource-efficient) / Separate (isolation)Phase 1.2RD-03Qdrant: active Phase 1-5 oder Phase 6 option only?Phase-1-active / Phase-6-optionPhase 1.2RD-04LangGraph + CrewAI Beziehung (Option A/B/C)Nested / Sequential / LangGraph-onlyPhase 2RD-05Daten-Split: Supabase vs. Hetzner-PostgreSQLLangGraph→Hetzner / Embeddings→Supabase (empfohlen)Phase 1-2RD-06Phase-1-Staging-StrategieSame-server Docker-Compose / Separate minimal serverPhase 1.6

H.3 — IMPLIZIT GETROFFENE ENTSCHEIDUNGEN (dokumentiert aber nie explizit als "Entscheidung" deklariert)

IDEntscheidungQuelleID-01Single-Tenant Phase 1-5Implizit aus "ein einzelner Entwickler"ID-02Async-First-ArchitekturImplizit aus SSE-Pflicht + 3D-Build-LatenzID-03Stateless-FrontendImplizit aus "keine DB-Verbindungen" auf VercelID-04Feature-Branch-Only für AgentenExplizit G4, impliziert vollständigen PR-WorkflowID-05JSON als Standard-Datenformat zwischen ServicesImplizit aus REST-NutzungID-06HTTP/2 oder HTTP/1.1 + SSENicht entschieden — Vercel unterstützt beidesID-07English als Programmiersprache (Variablen, Kommentare)Nicht entschieden — sollte ADR werden



═══════════════════════════════════════════════════════════════════

I. VOLLSTÄNDIGES MODULE-WIRING-REGISTER

═══════════════════════════════════════════════════════════════════

Jedes Modul vollständig verdrahtet nach SKILL §10:

I.1 — FRONTEND (Vercel / Next.js)

MODULE: frontend

OWNER: Vercel, Next.js App Router, shadcn/ui, Tailwind

PURPOSE: User-Interface, Prompt-Eingabe, Streaming-Output, Status-Visualisierung

INPUTS:

&#x20; - User-Prompt (Text, Tastatur/Touch)

&#x20; - SSE-Events von agent-api (Schicht 2)

&#x20; - HTTP-Responses von agent-api (Auth, Status)

OUTPUTS:

&#x20; - HTTP POST /api/v1/prompt → agent-api

&#x20; - HTTP GET /api/v1/session/{id}/stream (SSE-Connection)

&#x20; - HTTP DELETE /api/v1/memory (DSGVO-Purge)

&#x20; - HTTP GET /api/v1/memory/search (Memory-Viewer)

&#x20; - HTTP GET /api/v1/costs (Cost-Monitor)

INTERFACES:

&#x20; - REST API (JSON) mit agent-api

&#x20; - SSE (text/event-stream) mit agent-api

&#x20; - GitHub OAuth (Redirect-Flow) via agent-api Auth-Endpoint

STATE-STORE: Keiner (stateless). Session-State liegt in agent-api/Redis.

UPSTREAM-DEPENDENCIES: agent-api (muss laufen), Cloudflare DNS (immer aktiv)

DOWNSTREAM-CONSUMERS: Keiner (Leaf-Node)

ERROR-PATHS:

&#x20; - agent-api nicht erreichbar → Error-Banner "System nicht erreichbar"

&#x20; - SSE-Verbindung unterbrochen → Auto-Reconnect (max. 3 Versuche, dann Status "Verbindung verloren")

&#x20; - Auth-Fehler → Redirect zu Login

&#x20; - Budget-Alert → Warning-Banner persistent sichtbar

LOGS/METRICS: Vercel Analytics (optional, kostenlos). Kein eigenes Logging.

TEST-STRATEGY:

&#x20; - Unit: Component-Tests mit Vitest + Testing Library

&#x20; - E2E: Playwright (läuft lokal ODER via Playwright-Cloud, kein Localhost-Constraint)

VERIFICATION-METHOD: Playwright E2E Screenshot-Test über öffentliche Vercel-URL

DEPLOYMENT-TARGET: Vercel (automatisch bei Main-Branch-Merge)

DEPLOYMENT-TRIGGER: GitHub Actions Workflow 2 (Main-Deploy) → Vercel CLI

I.2 — ORCHESTRATOR (Hetzner / FastAPI / LangGraph)

MODULE: agent-api (Orchestrierungs-Schicht)

OWNER: Hetzner CPX21+, FastAPI, LangGraph, Python

PURPOSE: Intent-Parsing, Task-Planning, Agent-Coordination, State-Management, SSE-Streaming

INPUTS:

&#x20; - HTTP POST /api/v1/prompt (from Frontend)

&#x20; - HTTP GET /api/v1/session/{id}/stream (SSE-Consumer)

&#x20; - HTTP GET /api/v1/memory/search (Memory-Query)

&#x20; - HTTP DELETE /api/v1/memory (Purge-Trigger)

&#x20; - HTTP GET /api/v1/costs (Cost-Query)

&#x20; - HTTP GET /api/v1/health (Health-Check)

OUTPUTS:

&#x20; - SSE-Events to Frontend (token, agent\_status, error, done)

&#x20; - Task-Assignments to Agent-Pool (HTTP internal OR Redis Queue)

&#x20; - LLM-Requests to LiteLLM-Gateway

&#x20; - Memory-Reads/Writes to Redis + pgvector

&#x20; - Trace-Events to Langfuse

&#x20; - Cost-Records to cost\_tracking table

INTERFACES:

&#x20; - REST API (JSON) via nginx (Port 80/443 extern)

&#x20; - Internal HTTP to LiteLLM (Port 11434 oder definiert)

&#x20; - Internal HTTP to MCP-Gateway (Port 9000)

&#x20; - Redis Connection (Port 6379)

&#x20; - PostgreSQL Connection (Port 5432 — Hetzner-local)

&#x20; - Supabase Connection (HTTPS zu Supabase-Cloud, Phase 1-3)

&#x20; - Langfuse SDK Connection (HTTP to langfuse-server Port 3000)

STATE-STORE:

&#x20; - Redis: Active session context, Task-Plan, Agent-Status (TTL 30 Min)

&#x20; - PostgreSQL: LangGraph-Checkpoints, cost\_tracking, agent\_sessions, agent\_messages

&#x20; - pgvector: memory\_entries (Embeddings)

UPSTREAM-DEPENDENCIES:

&#x20; - LiteLLM-Gateway (LLM-Calls)

&#x20; - MCP-Gateway (Tool-Calls)

&#x20; - Redis (Session-State)

&#x20; - PostgreSQL (Checkpoints, Costs)

&#x20; - Supabase (Embeddings Phase 1-3)

&#x20; - Langfuse (Tracing)

DOWNSTREAM-CONSUMERS:

&#x20; - Frontend (SSE-Events)

&#x20; - Agent-Pool (Task-Assignments)

ERROR-PATHS:

&#x20; - LiteLLM down → Provider-Rotation → User-Toast "Provider gewechselt"

&#x20; - MCP-Gateway down → Graceful Degradation → User-Warning "Tool nicht verfügbar"

&#x20; - Redis down → Orchestrator startet ohne Working-Memory → Warning-Log

&#x20; - PostgreSQL down → BLOCKER → Orchestrator refuses to start (no Checkpointing without DB)

&#x20; - Budget-Alert 80% → Warning-Banner + Throttle new sessions

&#x20; - Budget-Alert 100% → Hard stop new LLM-calls + Critical-Alert

LOGS/METRICS:

&#x20; - Langfuse: alle LLM-Trace-Events, alle Agent-Actions

&#x20; - Prometheus: HTTP-Request-Count, Latency, Error-Rate, Active-Sessions

&#x20; - PostgreSQL: cost\_tracking table (per-agent, per-model)

TEST-STRATEGY:

&#x20; - Unit: pytest, Mock LiteLLM + MCP

&#x20; - Integration: Real LiteLLM, Real Redis, Real PostgreSQL (Staging)

&#x20; - E2E: Full-Stack-Test auf Staging

VERIFICATION-METHOD:

&#x20; - State-Recovery-Test: Orchestrator neu starten während aktiver Session, verifizieren dass State korrekt restored

&#x20; - Budget-Alert-Test: Budget auf 80% setzen, verifizieren dass Alert ausgelöst wird

DEPLOYMENT-TARGET: Hetzner (Docker-Container via Docker-Compose)

DEPLOYMENT-TRIGGER: GitHub Actions Workflow 2 → SSH deploy OR Docker Hub pull + Watchtower

I.3 — AGENT-POOL (Hetzner / Docker-Container)

MODULE: agent-pool (4 Kern-Agenten Phase 1-5)

OWNER: Hetzner (Docker-Container, einer pro Agent-Typ)

AGENT-TYPES: planner, coder, tester, devops

PURPOSE: Spezialisierte Task-Ausführung nach Agent-Governance-Regeln G1-G7

INPUTS (per Agent):

&#x20; - Task-Assignment vom Orchestrator (HTTP internal ODER Redis Queue)

&#x20; - Memory-Context vom Memory-System (via Orchestrator oder direkt)

&#x20; - Tool-Results vom MCP-Gateway

OUTPUTS (per Agent):

&#x20; - Result-Report an Orchestrator

&#x20; - State-Update an Memory-Schicht (via Orchestrator)

&#x20; - Tool-Requests an MCP-Gateway

&#x20; - LLM-Requests via LiteLLM-Gateway (nie direkt an Provider)

INTERFACES:

&#x20; - HTTP internal zu Orchestrator (Task-Assignment, Result-Report)

&#x20; - HTTP internal zu LiteLLM-Gateway (LLM-Calls)

&#x20; - HTTP internal zu MCP-Gateway (Tool-Calls)

&#x20; - Redis Connection (Memory-Write für Agent-State)

STATE-STORE:

&#x20; - Redis: Agent-Task-State (was ist in Bearbeitung)

&#x20; - Memory-Entries (via Orchestrator geschrieben)

GOVERNANCE-ENFORCEMENT (pro Agent, im System-Prompt verankert):

&#x20; - Max-Retry: 5 (dann Eskalation mit vollständigem Fehlerbericht)

&#x20; - Max-Execution-Time: Planner 60s / Coder 300s / Tester 600s / DevOps 120s

&#x20; - Branch-Restriction: Nur feature/agent-\[name]-\[timestamp]

&#x20; - Logging: Jede Action → Langfuse-Trace

ERROR-PATHS:

&#x20; - Task-Timeout → Partial-Result + Error-Report an Orchestrator

&#x20; - Max-Retry erreicht → Vollständiger Fehlerbericht + Eskalation an Mensch

&#x20; - Tool unavailable → Graceful Degradation + Warning in Result

DEPLOYMENT-TARGET: Hetzner (je ein Docker-Container per Agent-Typ)

I.4 — LLM-GATEWAY (Hetzner / LiteLLM)

MODULE: llm-gateway

OWNER: LiteLLM OSS, Hetzner, Cloudflare AI Gateway (Cache)

PURPOSE: Provider-agnostisches LLM-Routing, Cost-Tracking, Fallback-Rotation, Caching

INPUTS:

&#x20; - Generischer OpenAI-kompatibaler LLM-Request von Orchestrator/Agenten

&#x20; - Provider-Status (interne Health-Checks)

OUTPUTS:

&#x20; - LLM-Response (streaming oder vollständig)

&#x20; - Cost-Metadata (Input-Tokens, Output-Tokens, Provider, Modell, Kosten-Cent)

&#x20; - Provider-Switch-Event (bei Rotation)

INTERFACES:

&#x20; - OpenAI-API-kompatibel (POST /v1/chat/completions) intern

&#x20; - HTTPS zu LLM-Providern (Anthropic, OpenAI, Groq, Together.ai, HuggingFace)

&#x20; - HTTPS zu Cloudflare AI Gateway (Cache-Proxy)

&#x20; - HTTP zu Helicone (Cost-Tracking-Proxy)

MODELL-ROUTING-TABELLE:

&#x20; Planner: claude-sonnet-4-6 (Primary) → gpt-4o (Fallback) → gpt-4o-mini (Emergency)

&#x20; Coder: deepseek-chat (Primary) → claude-haiku-4-5 (Fallback) → groq-llama-3.3-70b (Emergency)

&#x20; Tester: gpt-4o-mini (Primary) → groq-llama-3.3-70b (Fallback) → deepseek-chat (Emergency)

&#x20; Research: gemini-flash (Primary) → mistral-large (Fallback) → gpt-4o-mini (Emergency)

CACHE-STRATEGIE:

&#x20; - Cloudflare AI Gateway: identische Prompts → TTL 10 Minuten

&#x20; - Cache-Key: Hash(model + messages + temperature) (NIEMALS user-sensitive Prompts cachen)

&#x20; - Cache-Bypass: Bei temperature > 0.7 oder wenn user\_id in Request

RATE-LIMITING:

&#x20; - Per-Provider: gemäß Provider-Limits

&#x20; - Per-Agent-Session: max. 50 LLM-Calls

&#x20; - Per-Modell-Klasse: Budget-basiert

ERROR-PATHS:

&#x20; - Provider 429/503 → Rotation zu nächstem Provider → Langfuse-Event "provider\_rotated"

&#x20; - Alle Provider down → Hard-Error an Orchestrator → User-Notification

&#x20; - Budget 80% → Throttle-Mode → Prefer günstigstes Modell

&#x20; - Budget 100% → Reject new requests → Critical-Alert

DEPLOYMENT-TARGET: Hetzner (Docker-Container)

I.5 — MCP-GATEWAY (Hetzner / MCP-Server)

MODULE: mcp-gateway

OWNER: Hetzner (Docker-Container, min. 2 Instanzen für kritische Tools)

PURPOSE: Standardisierte Tool-Bereitstellung für alle Agenten

TOOL-SET:

&#x20; GitHub-MCP \[2 Instanzen]:

&#x20;   - create\_branch (feature/agent-\* only)

&#x20;   - create\_commit

&#x20;   - open\_pull\_request

&#x20;   - get\_file\_contents (read)

&#x20;   - get\_workflow\_status (DevOps-Agent)

&#x20;   VERBOTEN: merge\_pull\_request, delete\_branch, force\_push, admin\_operations

&#x20; E2B-Sandbox-MCP \[2 Instanzen]:

&#x20;   - create\_sandbox

&#x20;   - execute\_code

&#x20;   - read\_output

&#x20;   - close\_sandbox (IMMER im finally-Block)

&#x20;   TIMEOUT: 30 Minuten automatisch

&#x20;   GRACEFUL-DEGRADATION: wenn E2B-API down → Tester-Agent deaktiviert → User-Warning

&#x20; Playwright-MCP \[1 Instanz]:

&#x20;   - open\_browser

&#x20;   - navigate\_to\_url

&#x20;   - take\_screenshot

&#x20;   - extract\_text

&#x20;   - close\_browser

&#x20;   TIMEOUT: 120 Sekunden per Operation

&#x20; Filesystem-MCP \[1 Instanz]:

&#x20;   - read\_file (Temp-Workspace only: /tmp/agent-workspace/)

&#x20;   - write\_file (Temp-Workspace only)

&#x20;   - list\_directory (Temp-Workspace only)

&#x20;   VERBOTEN: read/write outside /tmp/agent-workspace/

&#x20; PostgreSQL-MCP \[1 Instanz]:

&#x20;   - query (SELECT only, nie INSERT/UPDATE/DELETE)

&#x20;   TARGET: Projekt-Kontext-Daten (projects, memory\_entries)

INPUTS: Tool-Request von Agenten (HTTP internal) mit: tool\_name, params, trace\_id

OUTPUTS: Tool-Result (JSON) + Execution-Log + Trace-Event

LOGGING: Jeder Tool-Call → Langfuse-Trace-Entry (tool\_name, params, result, duration, trace\_id)

TIMEOUT-SCHUTZ: Jeder Tool-Call hat maximale Execution-Time, nach der forced-close ausgelöst wird

ERROR-PATHS:

&#x20; - Tool-Timeout → Error-Result + Alert

&#x20; - External-Service-Down (E2B, GitHub) → Graceful-Degradation + User-Warning

&#x20; - Permission-Violation → Hard-Error + Security-Alert + Audit-Log-Entry

DEPLOYMENT-TARGET: Hetzner (Docker-Container)

I.6 — MEMORY-SYSTEM (Redis + PostgreSQL/pgvector + Supabase)

MODULE: memory-system

OWNER: Redis (Working) + Hetzner PostgreSQL/pgvector + Supabase pgvector (Phase 1-3)

PURPOSE: Drei-Schicht-Langzeitgedächtnis für alle Agenten

SCHICHT 1 — Working Memory (Redis):

&#x20; KEY-SCHEMA: project:{id}:session:{id}:context

&#x20; KEY-SCHEMA: project:{id}:plan (aktueller LangGraph-Task-Plan)

&#x20; KEY-SCHEMA: agent:{type}:status (aktueller Agent-Zustand)

&#x20; TTL: 30 Minuten (mit 5-Minuten-Extension nach Konsolidierung)

&#x20; MAX-SIZE-PER-ENTRY: 64 KB

&#x20; KONSOLIDIERUNGS-TRIGGER: Entry-TTL < 8 Minuten (Puffer gegen Race-Condition)

SCHICHT 2 — Long-Term Memory (Supabase/Hetzner pgvector):

&#x20; TABLE: memory\_entries

&#x20; EMBEDDING-MODEL: text-embedding-3-small (OpenAI) oder OSS-Alternative

&#x20; CHUNK-SIZE: 512 Token

&#x20; CHUNK-OVERLAP: 64 Token

&#x20; TOP-K: 5 (Standard), 3 (kleine Modelle mit kleinem Context-Window)

&#x20; SEARCH-TYPE: Cosine Similarity

&#x20; INJECTION-BUDGET: max. 30% des Ziel-Modell-Kontextfensters

SCHICHT 3 — Knowledge Graph (Neo4j, Phase 4+ optional):

&#x20; USE-CASE: strukturelle Projekt-Zusammenhänge

&#x20; SCHEMA (Minimum, für Phase 4 vorbereitet):

&#x20;   Nodes: File, Module, Function, Bug, Decision, Agent

&#x20;   Edges: IMPORTS, CALLS, FIXES, BLOCKS, GENERATES

KONSOLIDIERUNGS-JOB:

&#x20; INTERVAL: alle 5 Minuten (empfohlen) statt 30 (Race-Condition-Fix)

&#x20; LOGIC: Suche alle Redis-Entries mit remaining\_ttl < 8 Minuten

&#x20; STATUS-FLAG: pending → consolidating → consolidated → failed

&#x20; RETRY: Bei Fehler TTL+30 Minuten Extension, Alert via Prometheus

DSGVO-PURGE-API:

&#x20; ENDPOINT: DELETE /api/v1/memory?user\_id={id}\&confirm=true

&#x20; SCOPE: Redis-Entries, pgvector-Embeddings, agent\_sessions, agent\_messages, Langfuse-Traces

&#x20; AUDIT-LOG: 30 Tage Aufbewahrung des Purge-Events

EMBEDDING-VERSION-TRACKING:

&#x20; PFLICHT: embedding\_model\_version-Feld in memory\_entries

&#x20; RE-EMBEDDING-RUNBOOK: bei Modellwechsel → Batch-Job re-embeddet alle Entries

DEPLOYMENT-TARGET:

&#x20; Redis: Hetzner (Docker-Container)

&#x20; PostgreSQL/pgvector: Hetzner (Docker-Container) für LangGraph-Checkpoints

&#x20; Supabase: Cloud (Phase 1-3), dann Migration zu Hetzner pgvector (Phase 4)

I.7 — OBSERVABILITY (Langfuse + Prometheus/Grafana)

MODULE: observability

OWNER: Langfuse self-hosted (Traces) + Prometheus + Grafana (Metrics) + Helicone (LLM-Costs)

PURPOSE: Alle Aktionen sichtbar, alle Kosten trackbar, alle Fehler erkennbar

LANGFUSE (Traces):

&#x20; TRACING-SCOPE: alle LLM-Calls, alle Agent-Actions, alle Tool-Calls, alle Memory-Operations

&#x20; TRACE-ID-PROPAGATION: x-trace-id HTTP-Header durch alle Schichten

&#x20; LANGFUSE-ERREICHBARKEIT: Intern auf Hetzner Port 3000. External via Auth-Proxy oder VPN.

&#x20; ALTERNATIVE FÜR SCREEN 3: Deep-Link von Agent-Activity-Screen zu Langfuse via

&#x20;   Nginx-Auth-Proxy mit HTTP-Basic-Auth oder IP-Whitelist.

PROMETHEUS (System-Metriken):

&#x20; METRIKEN-PER-SCHICHT:

&#x20;   Frontend: (via Vercel Analytics, nicht Prometheus)

&#x20;   Orchestrator: request\_total, request\_duration\_seconds, active\_sessions, error\_rate

&#x20;   LLM-Gateway: llm\_calls\_total, llm\_latency\_seconds, llm\_cost\_cents\_total, provider\_switches\_total

&#x20;   MCP-Gateway: tool\_calls\_total, tool\_duration\_seconds, tool\_errors\_total

&#x20;   Memory: redis\_entries\_total, consolidation\_jobs\_total, consolidation\_failures\_total

&#x20;   Agent-Pool: agent\_tasks\_total, agent\_duration\_seconds, agent\_retries\_total, agent\_escalations\_total

GRAFANA (Dashboards):

&#x20; DASHBOARD 1: System-Übersicht (alle Services, Health-Status)

&#x20; DASHBOARD 2: LLM-Kosten (per Agent, per Modell, kumulativ, Budget-Linie)

&#x20; DASHBOARD 3: Agent-Performance (Tasks, Retries, Eskalationen, Durchlaufzeiten)

&#x20; DASHBOARD 4: Memory-System (Redis-Auslastung, Konsolidierungen, pgvector-Größe)

&#x20; ERREICHBARKEIT: Hetzner intern, Nginx-Auth-Proxy für externen Zugriff

HELICONE (LLM-Kosten):

&#x20; PROXY: LiteLLM → Helicone → LLM-Provider

&#x20; LIMIT: 100k Requests/Monat (Free Tier)

&#x20; FALLBACK BEI ÜBERSCHREITUNG: LiteLLM-eigenes Cost-Tracking + Prometheus-Metriken

ALERT-REGELN:

&#x20; - Service-Down: sofort → PagerDuty/Email/Slack

&#x20; - Fehlerrate >5%: 5-Minuten-Window → Warning

&#x20; - Budget 80% (LLM: 160€): Throttle-Mode → Warning-Banner

&#x20; - Budget 100% (LLM: 200€): Hard-Stop → Critical-Alert

&#x20; - Memory-Auslastung >85%: Scale-Warning

&#x20; - Konsolidierungsjob-Fehler: Alert nach 3 aufeinanderfolgenden Fehlern

LOG-AUFBEWAHRUNG:

&#x20; Debug-Logs: 30 Tage

&#x20; Audit-Logs: 90 Tage

&#x20; Cost-Records: unbegrenzt (für Budget-Tracking)

&#x20; DSGVO-Purge-Audit: 30 Tage nach Purge-Event

DEPLOYMENT-TARGET: Hetzner (Langfuse-Server, Langfuse-Worker, Prometheus, Grafana als Docker-Container)



═══════════════════════════════════════════════════════════════════

I.8 — VOLLSTÄNDIGES INTERFACE-CONTRACT-REGISTER

═══════════════════════════════════════════════════════════════════

Die vollständigen API-Contracts (Schicht 1 → Schicht 2):

REST-Endpoints (agent-api)

POST /api/v1/prompt

&#x20; Auth: Bearer JWT (Required)

&#x20; Request: {

&#x20;   "project\_id": "string (uuid)",

&#x20;   "prompt": "string (max 10000 chars)",

&#x20;   "session\_id": "string (uuid, optional — erstellt neu wenn nicht angegeben)",

&#x20;   "stream": true

&#x20; }

&#x20; Response 201: {

&#x20;   "session\_id": "uuid",

&#x20;   "stream\_url": "/api/v1/session/{session\_id}/stream"

&#x20; }

&#x20; Response 400: { "error": "invalid\_prompt", "message": "string" }

&#x20; Response 402: { "error": "budget\_exceeded", "message": "string" }

&#x20; Response 429: { "error": "rate\_limited", "retry\_after": seconds }

&#x20; Response 503: { "error": "system\_unavailable", "message": "string" }



GET /api/v1/session/{session\_id}/stream

&#x20; Auth: Bearer JWT (Required)

&#x20; Content-Type: text/event-stream

&#x20; Events:

&#x20;   event: token

&#x20;   data: { "content": "string", "agent": "planner|coder|tester|devops" }

&#x20;   

&#x20;   event: agent\_status

&#x20;   data: { "agent": "string", "status": "active|idle|error|done", "task": "string", "started\_at": "ISO8601" }

&#x20;   

&#x20;   event: provider\_switch

&#x20;   data: { "from": "anthropic", "to": "groq", "reason": "rate\_limited" }

&#x20;   

&#x20;   event: budget\_alert

&#x20;   data: { "level": "warning|critical", "spent": 0.00, "limit": 200.00, "percentage": 80 }

&#x20;   

&#x20;   event: error

&#x20;   data: { "code": "string", "message": "string", "recoverable": true|false }

&#x20;   

&#x20;   event: done

&#x20;   data: { "session\_id": "uuid", "total\_tokens": 0, "total\_cost\_cents": 0 }

&#x20; 

&#x20; Reconnect: Client sendet Last-Event-ID Header. Server sendet Events ab dem Punkt nach Last-Event-ID.



GET /api/v1/memory/search

&#x20; Auth: Bearer JWT (Required)

&#x20; Query: ?q=string\&project\_id=uuid\&limit=5\&threshold=0.7

&#x20; Response 200: {

&#x20;   "results": \[

&#x20;     {

&#x20;       "id": "uuid",

&#x20;       "content": "string",

&#x20;       "relevance\_score": 0.95,

&#x20;       "created\_at": "ISO8601",

&#x20;       "session\_id": "uuid"

&#x20;     }

&#x20;   ]

&#x20; }



DELETE /api/v1/memory

&#x20; Auth: Bearer JWT (Required)

&#x20; Query: ?user\_id=uuid\&confirm=true

&#x20; Response 202: { "job\_id": "uuid", "estimated\_completion": "ISO8601" }

&#x20; Response 400: { "error": "confirmation\_required" }

&#x20; Response 404: { "error": "user\_not\_found" }



GET /api/v1/costs

&#x20; Auth: Bearer JWT (Required)

&#x20; Query: ?from=ISO8601\&to=ISO8601\&group\_by=agent|model|session

&#x20; Response 200: {

&#x20;   "total\_cost\_cents": 0,

&#x20;   "budget\_limit\_cents": 20000,

&#x20;   "budget\_spent\_percentage": 0.0,

&#x20;   "breakdown": \[...]

&#x20; }



GET /api/v1/health

&#x20; Auth: None (Health-Check-Endpoint)

&#x20; Response 200: {

&#x20;   "status": "healthy|degraded|down",

&#x20;   "services": {

&#x20;     "redis": "healthy|down",

&#x20;     "postgres": "healthy|down",

&#x20;     "litellm": "healthy|degraded|down",

&#x20;     "langfuse": "healthy|down",

&#x20;     "mcp\_github": "healthy|down",

&#x20;     "mcp\_e2b": "healthy|down"

&#x20;   }

&#x20; }



GET /api/v1/agents/status

&#x20; Auth: Bearer JWT (Required)

&#x20; Response 200: {

&#x20;   "agents": \[

&#x20;     {

&#x20;       "type": "planner|coder|tester|devops",

&#x20;       "status": "active|idle|error",

&#x20;       "current\_task": "string|null",

&#x20;       "current\_session\_id": "uuid|null",

&#x20;       "retries": 0,

&#x20;       "started\_at": "ISO8601|null"

&#x20;     }

&#x20;   ]

&#x20; }



POST /api/v1/auth/github

&#x20; (GitHub OAuth Redirect)

&#x20; Response 302 → GitHub OAuth



GET /api/v1/auth/callback

&#x20; Query: ?code=string\&state=string

&#x20; Response 302 → /workspace (mit Set-Cookie: access\_token, HttpOnly, Secure, SameSite=Strict)



POST /api/v1/auth/refresh

&#x20; Auth: Refresh-Token (HttpOnly Cookie)

&#x20; Response 200: { "access\_token": "JWT", "expires\_in": 900 }

&#x20; Response 401: { "error": "refresh\_token\_invalid" }



POST /api/v1/auth/logout

&#x20; Auth: Bearer JWT (Required)

&#x20; Response 200: (Clears Cookie, Blacklists Refresh-Token in Redis)

SSE-Reconnect-Strategie

CLIENT-SIDE SSE-RECONNECT:

&#x20; Primär: EventSource API (Browser-nativ)

&#x20; Reconnect-Delay: 1s → 2s → 4s → 8s → 16s (exponential backoff, max 16s)

&#x20; Max-Reconnect-Versuche: 3

&#x20; Nach 3 Fehlversuchen: Error-State "Verbindung verloren" + Retry-Button

&#x20; Last-Event-ID: Browser sendet automatisch bei Reconnect

&#x20; 

SERVER-SIDE SSE-HANDLING:

&#x20; FastAPI mit StreamingResponse

&#x20; Event-ID: incrementing integer per session

&#x20; Heartbeat: alle 15 Sekunden leere event "heartbeat" wenn kein anderer Event

&#x20; Session-Buffer: Letzte 50 Events per Session in Redis für Reconnect-Replay



═══════════════════════════════════════════════════════════════════

I.9 — VOLLSTÄNDIGER DATENBANKSCHEMA-ENTWURF

═══════════════════════════════════════════════════════════════════

sql-- Hetzner PostgreSQL (Agent-Daten + LangGraph-Checkpoints)

\-- Database: superbrain\_prod



\-- TABELLE 1: projects

CREATE TABLE projects (

&#x20; id UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

&#x20; name VARCHAR(255) NOT NULL,

&#x20; description TEXT,

&#x20; created\_at TIMESTAMPTZ DEFAULT NOW(),

&#x20; updated\_at TIMESTAMPTZ DEFAULT NOW(),

&#x20; owner\_id VARCHAR(255) NOT NULL,  -- GitHub User ID

&#x20; status VARCHAR(50) DEFAULT 'active'

&#x20;   CHECK (status IN ('active', 'archived', 'deleted')),

&#x20; metadata JSONB DEFAULT '{}'

);

CREATE INDEX idx\_projects\_owner\_id ON projects(owner\_id);



\-- TABELLE 2: agent\_sessions

CREATE TABLE agent\_sessions (

&#x20; id UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

&#x20; project\_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,

&#x20; started\_at TIMESTAMPTZ DEFAULT NOW(),

&#x20; ended\_at TIMESTAMPTZ,

&#x20; status VARCHAR(50) DEFAULT 'active'

&#x20;   CHECK (status IN ('active', 'completed', 'failed', 'escalated')),

&#x20; agent\_list TEXT\[] DEFAULT '{}',  -- \['planner', 'coder', 'tester']

&#x20; total\_input\_tokens INTEGER DEFAULT 0,

&#x20; total\_output\_tokens INTEGER DEFAULT 0,

&#x20; total\_cost\_cents INTEGER DEFAULT 0,

&#x20; escalation\_reason TEXT,

&#x20; metadata JSONB DEFAULT '{}'

);

CREATE INDEX idx\_sessions\_project\_id ON agent\_sessions(project\_id);

CREATE INDEX idx\_sessions\_status ON agent\_sessions(status);



\-- TABELLE 3: agent\_messages

CREATE TABLE agent\_messages (

&#x20; id UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

&#x20; session\_id UUID NOT NULL REFERENCES agent\_sessions(id) ON DELETE CASCADE,

&#x20; agent\_type VARCHAR(50) NOT NULL

&#x20;   CHECK (agent\_type IN ('planner', 'coder', 'tester', 'devops', 'orchestrator', 'user')),

&#x20; created\_at TIMESTAMPTZ DEFAULT NOW(),

&#x20; role VARCHAR(20) NOT NULL

&#x20;   CHECK (role IN ('user', 'assistant', 'system', 'tool')),

&#x20; content\_ref VARCHAR(1024),  -- Referenz zu Object-Storage wenn content > 10KB

&#x20; content\_short TEXT,  -- Direkt wenn content <= 10KB

&#x20; token\_count INTEGER,

&#x20; provider VARCHAR(100),

&#x20; model VARCHAR(100),

&#x20; trace\_id VARCHAR(255),  -- Langfuse Trace ID

&#x20; metadata JSONB DEFAULT '{}'

);

CREATE INDEX idx\_messages\_session\_id ON agent\_messages(session\_id);

CREATE INDEX idx\_messages\_trace\_id ON agent\_messages(trace\_id);



\-- TABELLE 4: memory\_entries

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE memory\_entries (

&#x20; id UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

&#x20; project\_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,

&#x20; session\_id UUID REFERENCES agent\_sessions(id) ON DELETE SET NULL,

&#x20; content\_text TEXT NOT NULL,

&#x20; content\_embedding vector(1536),  -- OpenAI text-embedding-3-small

&#x20; embedding\_model\_version VARCHAR(100) DEFAULT 'text-embedding-3-small',

&#x20; created\_at TIMESTAMPTZ DEFAULT NOW(),

&#x20; relevance\_score FLOAT,

&#x20; chunk\_index INTEGER DEFAULT 0,

&#x20; total\_chunks INTEGER DEFAULT 1,

&#x20; status VARCHAR(50) DEFAULT 'active'

&#x20;   CHECK (status IN ('active', 'archived', 'deprecated', 'deleted')),

&#x20; consolidation\_status VARCHAR(50) DEFAULT 'pending'

&#x20;   CHECK (consolidation\_status IN ('pending', 'consolidating', 'consolidated', 'failed')),

&#x20; metadata JSONB DEFAULT '{}'

);

CREATE INDEX idx\_memory\_project\_id ON memory\_entries(project\_id);

CREATE INDEX idx\_memory\_embedding ON memory\_entries 

&#x20; USING ivfflat (content\_embedding vector\_cosine\_ops) WITH (lists = 100);

CREATE INDEX idx\_memory\_consolidation ON memory\_entries(consolidation\_status) 

&#x20; WHERE consolidation\_status = 'pending';



\-- TABELLE 5: cost\_tracking

CREATE TABLE cost\_tracking (

&#x20; id UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

&#x20; session\_id UUID REFERENCES agent\_sessions(id) ON DELETE SET NULL,

&#x20; agent\_type VARCHAR(50),

&#x20; model\_name VARCHAR(100) NOT NULL,

&#x20; provider\_name VARCHAR(100) NOT NULL,

&#x20; input\_tokens INTEGER NOT NULL DEFAULT 0,

&#x20; output\_tokens INTEGER NOT NULL DEFAULT 0,

&#x20; cost\_cents INTEGER NOT NULL DEFAULT 0,  -- in Cent für Integer-Arithmetik

&#x20; created\_at TIMESTAMPTZ DEFAULT NOW(),

&#x20; from\_cache BOOLEAN DEFAULT FALSE,

&#x20; trace\_id VARCHAR(255)

);

CREATE INDEX idx\_costs\_session\_id ON cost\_tracking(session\_id);

CREATE INDEX idx\_costs\_created\_at ON cost\_tracking(created\_at);

CREATE INDEX idx\_costs\_agent\_type ON cost\_tracking(agent\_type);



\-- TABELLE 6: audit\_log (DSGVO + Security)

CREATE TABLE audit\_log (

&#x20; id UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

&#x20; event\_type VARCHAR(100) NOT NULL,  -- 'memory\_purge', 'branch\_protection\_violation', etc.

&#x20; user\_id VARCHAR(255),

&#x20; session\_id UUID,

&#x20; details JSONB NOT NULL DEFAULT '{}',

&#x20; created\_at TIMESTAMPTZ DEFAULT NOW(),

&#x20; ip\_address INET,

&#x20; severity VARCHAR(20) DEFAULT 'info'

&#x20;   CHECK (severity IN ('info', 'warning', 'critical'))

);

\-- Audit-Log wird NIEMALS gelöscht (außer nach DSGVO-Ablauf von 90 Tagen)

CREATE INDEX idx\_audit\_event\_type ON audit\_log(event\_type);

CREATE INDEX idx\_audit\_user\_id ON audit\_log(user\_id);

CREATE INDEX idx\_audit\_created\_at ON audit\_log(created\_at);



\-- LangGraph Checkpoints (automatisch erstellt von LangGraph-Bibliothek)

\-- LangGraph erstellt eigene Tabellen: checkpoints, checkpoint\_blobs, checkpoint\_writes

\-- Diese werden NICHT manuell gemanagt



═══════════════════════════════════════════════════════════════════

I.10 — VOLLSTÄNDIGES AGENT-GOVERNANCE-CODEX

═══════════════════════════════════════════════════════════════════

Das ist der konkrete System-Prompt-Rahmen für jeden Agenten:

═══════════════════════════════════════════════════════════════

AGENT GOVERNANCE CODEX — VERSION 1.0

Gilt für: Planner-Agent, Coder-Agent, Tester-Agent, DevOps-Agent

Status: NICHT VERHANDELBAR. UNVERÄNDERLICH DURCH AGENTEN SELBST.

═══════════════════════════════════════════════════════════════



WER DU BIST:

Du bist \[AGENT\_TYPE]-Agent im -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM.

Deine Rolle ist exakt: \[AGENT\_ROLE\_DESCRIPTION]

Du bist KEIN allgemeiner Assistent. Du bist KEIN eigenständiger Entscheider.

Du bist ein spezialisiertes Ausführungswerkzeug unter menschlicher Aufsicht.



WAS DU NIEMALS TUST (ABSOLUT):

1\. Du triffst keine Architektur-Entscheidungen. Du machst Vorschläge. Menschen entscheiden.

2\. Du sagst "erledigt" oder "done" nur wenn: implementiert + getestet + integriert + 

&#x20;  Ergebnis zurückgeliefert + im Observability-System geloggt.

3\. Du merkst dir das North-Star-Ziel des Projekts aktiv.

4\. Du änderst keine Architektur, keine Schicht-Grenzen, keine Interfaces ohne ADR.

5\. Du hinterläßt keine isolierten, unverbundenen Fragmente.

6\. Du markierst Unsicherheit explizit. Du sagst niemals etwas mit Sicherheit ohne Beweis.

7\. Du schreibst niemals direkt in Main-Branch, Production-DB, 

&#x20;  system-kritische Konfigurationsdateien oder Secret-Stores.

8\. Du loggst JEDE Aktion in das Observability-System. Keine unsichtbare Aktion.

9\. Du stoppst nach 5 fehlgeschlagenen Versuchen und eskalierst mit vollständigem Bericht.

10\. Du schreibst niemals Secrets in Code, Output, Logs oder Kommentare.



KONTEXT-PRÜFUNG VOR JEDEM TASK:

1\. Lese aktuellen Projekt-Kontext aus Memory-System.

2\. Verifiziere: Ist mein Task konsistent mit dem aktuellen Projekt-Kontext?

3\. Wenn Widerspruch: SOFORTIGE ESKALATION. Kein blindes Weiterarbeiten.

4\. Wenn konsistent: Starte Task-Ausführung.



MAX-RETRY-PROTOKOLL:

Versuch 1-4: Task ausführen, Fehler analysieren, Ansatz anpassen.

Versuch 5 (letzter): Task ausführen.

Nach Versuch 5 Fehler: 

&#x20; - Vollständiger Fehlerbericht: alle 5 Versuche, alle Fehler, alle Ausgaben

&#x20; - Empfehlung für nächste menschliche Aktion

&#x20; - Status: ESCALATED (nicht "failed")

&#x20; - Logging: Alle 5 Versuche in Observability-System



KRITISCHE AKTIONEN (Human-Freigabe erforderlich, immer):

\- Production-Deployment

\- Datenlöschung

\- Merge in Main-Branch

\- Ressourcen-Limit-Erhöhung

\- Budget-Limit-Erhöhung

Wenn eine dieser Aktionen notwendig wird: STOPP. Meldung an Orchestrator.

Warte auf explizite menschliche Freigabe. Keine Ausnahmen.



ARCHITEKTUR-KLASSIFIZIERUNG (Was ist architekturrelevant?):

Eine Entscheidung ist architekturrelevant wenn sie:

\- Eine neue Service-Dependency einführt

\- Einen Interface-Contract ändert

\- Eine Schicht-Grenze überschreitet

\- Einen neuen LLM-Provider einführt

\- Einen neuen Tool-Typ einführt

\- Das Datenbankschema ändert

\- Die Deployment-Strategie ändert

\- Das Security-Modell ändert

Bei architekturrelevanten Entscheidungen: Vorschlag schreiben, warten auf ADR-Genehmigung.



DONE-VALIDIERUNGSPROTOKOLL:

"Ich bin fertig" bedeutet:

&#x20; ☐ Implementiert (Code existiert)

&#x20; ☐ Getestet (Test läuft durch, Output ist korrekt)

&#x20; ☐ Integriert (mit restlichem System verbunden, nicht isoliert)

&#x20; ☐ Ergebnis rückgeliefert (an Orchestrator zurückgemeldet)

&#x20; ☐ Geloggt (Langfuse-Trace-Entry existiert)

Nur wenn alle 5 angehakt: "DONE".

Jeder andere Zustand: "IN PROGRESS" oder "BLOCKED (Grund: ...)"



MODELL-ZUWEISUNG \[AGENT\_TYPE]:

Primary: \[PRIMARY\_MODEL]

Fallback 1: \[FALLBACK\_1]

Fallback 2 (Emergency): \[FALLBACK\_2]

Max-Output-Tokens: \[MAX\_TOKENS]

Max-Execution-Time: \[MAX\_TIME] Sekunden



ERLAUBTE TOOLS \[AGENT\_TYPE]:

\[TOOL\_LIST]



VERBOTENE AKTIONEN \[AGENT\_TYPE]:

\[FORBIDDEN\_ACTIONS]



TRACE-ID:

Jede Anfrage kommt mit einer trace\_id. Diese MUSS an alle downstream Tool-Calls 

und LLM-Calls weitergegeben werden als Header: x-trace-id: \[trace\_id]



SESSION-KONTEXT:

project\_id: \[PROJECT\_ID]

session\_id: \[SESSION\_ID]

task\_id: \[TASK\_ID]

task\_description: \[TASK\_DESCRIPTION]

memory\_context: \[TOP\_K\_MEMORY\_CHUNKS]



═══════════════════════════════════════════════════════════════════

I.11 — VOLLSTÄNDIGES TECHNISCHES SCHULDEN-REGISTER

═══════════════════════════════════════════════════════════════════

Pre-identifizierte Technical Debt, die bewusst eingegangen wird:

IDSchuldBegründungPhase zur AuflösungTD-01Supabase statt Hetzner pgvector (Phase 1-3)Schneller MVP-Start, kein eigenes DB-Hosting-RisikoPhase 4 (Migration)TD-02Single-Region FrankfurtBudget-Constraint, Single-DeveloperPhase 6 (Multi-Region)TD-03Docker-Compose statt K3sNo Over-Engineering für Phase 1-5Phase 6 (K3s wenn nötig)TD-04Kein Knowledge Graph (Phase 1-3)Aufbau-Aufwand nicht gerechtfertigt vor BeweisPhase 4 (optional)TD-05Kein Mobile-Design (Phase 1-5)Desktop-First für Developer-ToolPhase 6 (wenn Bedarf)TD-06Single-Tenant Auth (Phase 1-5)Aufbau-VereinfachungPhase 6 (Multi-Tenant)TD-07HTTP statt gRPC für interne KommunikationEinfachheit vor PerformancePhase 5 (Evaluate)TD-08Shared PostgreSQL für Langfuse + Agent-DatenRessourcenoptimierungPhase 5 (Separate wenn nötig)TD-09Kein Qdrant in Phase 1-5pgvector ausreichend für Phase 1-5Phase 6 (wenn pgvector-Limits erreicht)TD-10Keine automatische Re-Embedding-PipelineManuell via RunbookPhase 4 (Automatisierung)



═══════════════════════════════════════════════════════════════════

I.12 — VOLLSTÄNDIGES VERIFICATION-REGISTER

═══════════════════════════════════════════════════════════════════

Status aller Projektaspekte nach aktueller Wahrheit (Phase 0 aktiv):

Status-Definitionen



✅ ENTSCHIEDEN: Explizit entschieden, kein Code existiert

📐 GEPLANT: Konzeptuell geplant, Architektur skizziert

🔨 IMPLEMENTIERT: Code geschrieben (noch nicht in diesem Projekt — Phase 0)

🔗 INTEGRIERT: In Gesamtsystem verbunden

🧪 GETESTET: Tests existieren und laufen

✔️ VERIFIZIERT: Beweis der Korrektheit vorhanden

🚀 RELEASE-READY: Produktionsbereit

❓ UNVERIFIED: Annahme, nicht bewiesen

🚫 BLOCKIERT: Expliziter Blocker



BereichStatusNotizGoal Lock✅ ENTSCHIEDENIn D1 verankert7-Schichten-Architektur✅ ENTSCHIEDENVollständig beschriebenBudget-Constraint (20€ Infra)✅ ENTSCHIEDENAber W-RESIDUAL-01 ungelöstServer-Typ Phase 1🚫 BLOCKIERTRD-01 nicht entschiedenPostgreSQL-Struktur🚫 BLOCKIERTRD-02, RD-05 nicht entschiedenQdrant-Scope🚫 BLOCKIERTRD-03 nicht entschiedenLangGraph+CrewAI-Beziehung🚫 BLOCKIERTRD-04 nicht entschiedenBudget-Tracking-Mechanismus❓ UNVERIFIEDHelicone + Prometheus, aber Integration undefiniertE2B-Pricing❓ UNVERIFIEDAnnahme: Free Tier ausreichend für Phase 1-2Groq-Latenz❓ UNVERIFIEDAnnahme: ausreichend für ProductionLiteLLM-Performance unter Last❓ UNVERIFIEDNicht getestetSupabase Free Tier Kapazität❓ UNVERIFIEDAnnahme: ausreichend bis 400MBADR-001 bis ADR-005📐 GEPLANTPhase-0-Aufgaben, noch nicht erstelltSecrets-Management-Plan📐 GEPLANTPhase-0-AufgabeDocker-Compose-Design📐 GEPLANTPhase-1-AufgabeCI/CD-Workflows📐 GEPLANTPhase-1-AufgabeLangGraph-Graph📐 GEPLANTPhase-2-AufgabeAgent-Profiles📐 GEPLANTPhase-2-AufgabeFrontend (4 Screens)📐 GEPLANTPhase-3-AufgabeAuth (JWT + GitHub OAuth)📐 GEPLANTPhase-3-AufgabeDSGVO-Purge-API📐 GEPLANTPhase-3-AufgabeState-Recovery-Test🚫 BLOCKIERTL-32 — Testprozedur nicht definiertRollback-Prozedur🚫 BLOCKIERTL-29 — Runbook nicht definiertRelease-Checkliste📐 GEPLANTPhase-5-Aufgabe



═══════════════════════════════════════════════════════════════════

I.13 — GITHUB-BRANCH-PROTECTION-KONFIGURATION (L-13 SCHLIESSEN)

═══════════════════════════════════════════════════════════════════

Dies ist das fehlende Artefakt aus Lücke L-13. Als IaC-Beschreibung:

yaml# .github/branch-protection.md — Dokumentation der Branch-Schutzregeln

\# Diese Regeln MÜSSEN über GitHub API oder GitHub Web-Interface konfiguriert werden

\# BEVOR der erste Agent-Lauf stattfindet.



branch: main

protection:

&#x20; require\_pull\_request\_reviews:

&#x20;   required\_approving\_review\_count: 1  # Mindestens 1 menschlicher Review

&#x20;   dismiss\_stale\_reviews: true

&#x20;   require\_code\_owner\_reviews: false  # CODEOWNERS optional

&#x20; 

&#x20; require\_status\_checks:

&#x20;   strict: true  # Branch muss aktuell sein

&#x20;   contexts:

&#x20;     - "pr-check / lint"

&#x20;     - "pr-check / type-check"

&#x20;     - "pr-check / unit-tests"

&#x20; 

&#x20; enforce\_admins: false  # Owner kann Ausnahmen gewähren (explizit, nicht stillschweigend)

&#x20; 

&#x20; restrictions:

&#x20;   # Nur diese Entities können direkt in Main pushen (nobody — force durch PR-only)

&#x20;   users: \[]

&#x20;   teams: \[]

&#x20;   apps: \[]

&#x20; 

&#x20; allow\_force\_pushes: false  # NIEMALS Force-Push in Main

&#x20; allow\_deletions: false  # NIEMALS Main-Branch löschen



branch: "feature/agent-\*"

&#x20; # Keine Schutzregeln — Agenten schreiben hier

&#x20; # Pattern: feature/agent-\[agent-type]-\[timestamp]-\[task-short-id]

&#x20; # Beispiel: feature/agent-coder-20260423-143022-impl-auth-jwt

&#x20; auto\_delete\_after\_merge: true  # automatisch löschen nach PR-Merge



branch: "hotfix/\*"

protection:

&#x20; require\_pull\_request\_reviews:

&#x20;   required\_approving\_review\_count: 1

&#x20; allow\_force\_pushes: false



\# WICHTIG: Diese Konfiguration ist IaC und wird in /docs/github-branch-protection.md gespeichert.

\# Verifizierung nach Setup: gh api repos/{owner}/{repo}/branches/main/protection



═══════════════════════════════════════════════════════════════════

I.14 — CI/CD-DEPLOY-MECHANISMUS (L-26 SCHLIESSEN)

═══════════════════════════════════════════════════════════════════

Der fehlende Mechanismus für GitHub Actions → Hetzner-Deploy:

yaml# Deployment-Strategie: Docker Hub + Watchtower (empfohlen für Phase 1-5)

\# Begründung: Kein direkter SSH-Zugriff von GitHub Actions erforderlich.

\# Sicherheit: Hetzner-Server muss nur ausgehende Verbindungen zu Docker Hub erlauben.



Ablauf:

&#x20; 1. GitHub Actions baut Docker-Image

&#x20; 2. GitHub Actions pusht zu Docker Hub (ghcr.io oder docker.io)

&#x20; 3. Watchtower läuft auf Hetzner, prüft alle 30 Sekunden auf neue Images

&#x20; 4. Watchtower zieht neues Image und startet Container neu

&#x20; 5. Health-Check via /api/v1/health nach Deploy

&#x20; 6. Rollback: altes Image-Tag in docker-compose.yml eintragen, Watchtower deployed automatisch



\# Alternative (wenn Watchtower nicht gewünscht): GitHub Actions SSH + Docker-Compose-Pull

\# Voraussetzung: SSH-Key als GitHub Secret, Hetzner erlaubt SSH nur von GitHub Actions IPs



DEPLOY-WORKFLOW (Vereinfacht):

name: main-deploy

on:

&#x20; push:

&#x20;   branches: \[main]

jobs:

&#x20; build-and-push:

&#x20;   steps:

&#x20;     - name: Build Docker Image

&#x20;       run: docker build -t ghcr.io/$GITHUB\_REPOSITORY/agent-api:$GITHUB\_SHA .

&#x20;     - name: Push to GHCR

&#x20;       run: docker push ghcr.io/$GITHUB\_REPOSITORY/agent-api:$GITHUB\_SHA

&#x20;     - name: Update docker-compose.yml tag

&#x20;       run: |

&#x20;         # SSH zu Hetzner und docker-compose pull + up (wenn SSH-Strategie gewählt)

&#x20;         # ODER: Watchtower macht das automatisch (kein SSH nötig)

&#x20; 

&#x20; health-check:

&#x20;   needs: build-and-push

&#x20;   steps:

&#x20;     - name: Wait for Deploy

&#x20;       run: sleep 30

&#x20;     - name: Health Check

&#x20;       run: |

&#x20;         STATUS=$(curl -sf https://api.yourdomain.com/api/v1/health | jq -r '.status')

&#x20;         if \[ "$STATUS" != "healthy" ]; then exit 1; fi

&#x20;     - name: Rollback on Failure

&#x20;       if: failure()

&#x20;       run: # Trigger Rollback-Workflow



═══════════════════════════════════════════════════════════════════

I.15 — ADR-TRIGGER-CHECKLISTE (L-01 SCHLIESSEN)

═══════════════════════════════════════════════════════════════════

Wann MUSS ein neuer ADR erstellt werden:

ADR PFLICHT wenn eine der folgenden Bedingungen zutrifft:



ARCHITEKTUR-EBENE:

☑ Eine neue Service-Dependency wird eingeführt (neuer Docker-Container, neue externe API)

☑ Ein bestehender Service wird durch einen anderen ersetzt

☑ Eine Schicht-Grenze wird neu gezogen oder überschritten

☑ Das Datenbankschema ändert sich strukturell (neue Tabellen, geänderte Relationen)

☑ Das Deployment-Target ändert sich für eine Komponente

☑ Container-Orchestrierung ändert sich (Docker Compose → K3s)



INTERFACE-EBENE:

☑ Ein API-Endpoint wird hinzugefügt, geändert oder entfernt

☑ Ein SSE-Event-Typ wird hinzugefügt oder geändert

☑ Das Auth-Protokoll ändert sich

☑ Ein MCP-Tool-Interface ändert sich



SECURITY-EBENE:

☑ Das Auth-Modell ändert sich (neue Provider, neue Token-Typen)

☑ Ein neuer Secret-Typ wird eingeführt

☑ Eine Permission-Grenze für Agenten ändert sich

☑ Eine Compliance-Anforderung wird hinzugefügt



KOSTEN-EBENE:

☑ Ein neuer LLM-Provider wird eingeführt

☑ Das Budget-Limit wird erhöht (nur mit Owner-Freigabe)

☑ Eine neue Kostenkategorie entsteht



TOOLING-EBENE:

☑ Ein neues Observability-Tool wird hinzugefügt

☑ Ein neues CI/CD-Tool wird hinzugefügt

☑ Das Embedding-Modell ändert sich



KEIN ADR NOTWENDIG FÜR:

☐ Bug-Fixes innerhalb eines Moduls ohne Interface-Änderung

☐ Performance-Optimierungen ohne Architektur-Änderung

☐ Dokumentations-Updates

☐ Test-Ergänzungen

☐ Dependency-Version-Updates (außer Major-Version mit Breaking-Changes)



═══════════════════════════════════════════════════════════════════

I.16 — SUPABASE KEEP-ALIVE + INFRASTRUKTUR-BUDGET-TRACKING (L-33 + L-03 SCHLIESSEN)

═══════════════════════════════════════════════════════════════════

Supabase Keep-Alive:

yaml# .github/workflows/supabase-keepalive.yml

name: Supabase Keep-Alive

on:

&#x20; schedule:

&#x20;   - cron: '0 12 \*/6 \* \*'  # Alle 6 Tage um 12:00 UTC

jobs:

&#x20; keepalive:

&#x20;   runs-on: ubuntu-latest

&#x20;   steps:

&#x20;     - name: Ping Supabase

&#x20;       run: |

&#x20;         curl -sf \\

&#x20;           -H "apikey: ${{ secrets.SUPABASE\_ANON\_KEY }}" \\

&#x20;           -H "Authorization: Bearer ${{ secrets.SUPABASE\_ANON\_KEY }}" \\

&#x20;           "${{ secrets.SUPABASE\_URL }}/rest/v1/projects?select=id\&limit=1"

Infrastruktur-Budget-Tracking (20€/Monat Limit):

TRACKING-MECHANISMUS für Infrastruktur-Budget (getrennt von LLM-Budget):



Kategorien die zum 20€-Infrastruktur-Limit zählen:

&#x20; - Hetzner-Server-Kosten (alle Server)

&#x20; - Hetzner-Netzwerk/Snapshot-Kosten

&#x20; - Cloudflare-Paid-Features (falls aktiviert — aktuell €0)

&#x20; - Redis-Cloud falls migriert (aktuell self-hosted = €0 extra)

&#x20; - Docker-Registry-Kosten (GHCR Free = €0, sonst mitzählen)



Kategorien die NICHT zum 20€-Infrastruktur-Limit zählen:

&#x20; - LLM-API-Kosten (separates Limit: 200€/Monat)

&#x20; - Supabase-Kosten (wenn Free-Tier: €0; wenn Pro: mitzählen zu Infra)

&#x20; - E2B-Kosten

&#x20; - Helicone-Kosten



TRACKING-TOOL: Hetzner bietet monatliche Kosten-Übersicht.

ALERT-SCHWELLE: 80% = 16€/Monat Infrastruktur

ALERT-MECHANISMUS: Hetzner API monatlicher Kosten-Check via GitHub Actions (wöchentlich)



\# .github/workflows/infra-cost-check.yml

name: Infra Cost Check

on:

&#x20; schedule:

&#x20;   - cron: '0 9 \* \* 1'  # Jeden Montag 9:00 UTC

jobs:

&#x20; check:

&#x20;   runs-on: ubuntu-latest

&#x20;   steps:

&#x20;     - name: Check Hetzner Costs

&#x20;       run: |

&#x20;         # Hetzner API: GET https://api.hetzner.cloud/v1/servers

&#x20;         # Aktuellen Monatspreis summieren

&#x20;         # Wenn > 16€: Alert via Slack/Email



═══════════════════════════════════════════════════════════════════

I.17 — SECRET-SCANNER KONFIGURATION (L-31 SCHLIESSEN)

═══════════════════════════════════════════════════════════════════

yaml# Pre-Commit Hook: gitleaks

\# Installation: brew install gitleaks (lokal, nur zur Entwicklung)

\# CI-Integration:



\# .github/workflows/pr-check.yml (Ergänzung)

\- name: Secret Scan

&#x20; uses: gitleaks/gitleaks-action@v2

&#x20; env:

&#x20;   GITHUB\_TOKEN: ${{ secrets.GITHUB\_TOKEN }}

&#x20;   GITLEAKS\_LICENSE: ${{ secrets.GITLEAKS\_LICENSE }}  # nur für Enterprise-Features



\# .gitleaks.toml (Projekt-Root)

\[allowlist]

&#x20; regexes = \[

&#x20;   '''test\_api\_key''',  # Erlaubte Test-Schlüssel-Pattern

&#x20;   '''PLACEHOLDER''',

&#x20;   '''YOUR\_KEY\_HERE'''

&#x20; ]



\# Zusätzlich: Agent-Log-Secret-Masking

\# LiteLLM und FastAPI müssen alle Requests/Responses masken:

\# Pattern: sk-\[a-zA-Z0-9]{32,} (API-Key-Pattern)

\# Ersetzen durch: sk-\*\*\*MASKED\*\*\*

\# Gilt für: alle Langfuse-Traces, alle Prometheus-Labels, alle Log-Outputs



═══════════════════════════════════════════════════════════════════

I.18 — VOLLSTÄNDIGE ROLLBACK-PROZEDUR (L-29 SCHLIESSEN)

═══════════════════════════════════════════════════════════════════

ROLLBACK-PROZEDUR — ZIEL: < 5 Minuten pro Service



VORBEDINGUNG: Jedes Deployment taggt das vorherige Image als :previous

&#x20; docker tag ghcr.io/repo/agent-api:latest ghcr.io/repo/agent-api:previous



ROLLBACK AGENT-API (Orchestrator):

&#x20; Schritt 1 (30s): Identifiziere letztes stabiles Image-Tag

&#x20;   → docker images ghcr.io/repo/agent-api

&#x20; Schritt 2 (60s): Update docker-compose.yml

&#x20;   → sed -i 's/agent-api:latest/agent-api:previous/' docker-compose.yml

&#x20; Schritt 3 (60s): Container neu starten

&#x20;   → docker-compose up -d --no-deps agent-api

&#x20; Schritt 4 (60s): Health-Check

&#x20;   → curl https://api.yourdomain.com/api/v1/health

&#x20; Schritt 5 (30s): Status in Audit-Log schreiben

&#x20; TOTAL: \~4 Minuten ✅



ROLLBACK DATENBANK-MIGRATION:

&#x20; Kritisch: Nur Forward-Migrations in Production.

&#x20; Es gibt KEINEN automatischen Rollback für DB-Migrations.

&#x20; Wenn Migration fehlschlägt:

&#x20;   Schritt 1: Stoppe alle Services die die DB nutzen

&#x20;   Schritt 2: Stelle letzten PostgreSQL-Snapshot wieder her (Hetzner Snapshot)

&#x20;   Schritt 3: Starte Services neu mit altem Image-Tag

&#x20; WICHTIG: Hetzner-Snapshot MUSS vor jedem Migration-Deploy erstellt werden.

&#x20; SNAPSHOT-POLICY: Automatischer Snapshot vor jedem Production-Deploy (via Hetzner API in CI/CD)



ROLLBACK FRONTEND (Vercel):

&#x20; Schritt 1: Vercel Dashboard → Deployments → "Promote to Production" auf vorheriges Deployment

&#x20; TOTAL: \~1 Minute ✅ (Vercel verwaltet History)



ROLLBACK MCP-GATEWAY:

&#x20; Identisch zu ROLLBACK AGENT-API. Image-Tag-Strategie.



STAGING-TEST DER ROLLBACK-PROZEDUR:

&#x20; Testplan (monatlich auf Staging ausführen):

&#x20;   1. Deploy neue Version auf Staging

&#x20;   2. Verifiziere Deployment erfolgreich

&#x20;   3. Führe Rollback durch

&#x20;   4. Verifiziere Rollback erfolgreich (Health-Check + funktionaler Test)

&#x20;   5. Dokumentiere Rollback-Dauer (Ziel < 5 Minuten)

&#x20;   6. Wenn Rollback > 5 Minuten: Prozedur verbessern, bevor Production-Release



═══════════════════════════════════════════════════════════════════

I.19 — CODEX-INTEGRATION-DOKUMENTATION (PHASE 0.5)

═══════════════════════════════════════════════════════════════════

Der Inhalt für CODEX\_AGENT\_SKILL\_MASTER.md (Lücke L-25 schließen):

markdown# CODEX\_AGENT\_SKILL\_MASTER.md

\# Version: 1.0 — April 2026

\# DIESES DOKUMENT IST DER KONTEXT-LOADER FÜR CODEX-AGENTEN



\## PROJEKT-IDENTITÄT

Name: -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM

Ziel: Cloud-native Multi-Agent AI Developer Platform

Constraint: KEIN Localhost. KEIN lokales Modell. 20€/Monat Infra-Limit. OSS-First.



\## AKTIVE SCHICHTEN

1\. Frontend: Vercel + Next.js + shadcn/ui (Dark Mode, Indigo/Violett/Türkis)

2\. Orchestrierung: Hetzner + LangGraph + FastAPI

3\. Agent-Pool: 4 Kern-Agenten (Planner, Coder, Tester, DevOps)

4\. LLM-Gateway: LiteLLM (Provider-agnostisch) + Cloudflare AI Gateway (Cache)

5\. Tool-MCP: GitHub, E2B, Playwright, Filesystem, PostgreSQL (readonly)

6\. Memory: Redis (Working/30min TTL) + pgvector (Long-Term) + Supabase (Phase 1-3)

7\. Observability: Langfuse self-hosted + Prometheus + Grafana



\## AKTIVE PHASE

\[WIRD PRO CODEX-SESSION EINGESETZT — siehe CODEX\_LOADER\_PROMPT.txt]



\## ABSOLUT VERBOTEN

\- Localhost. Lokale Modelle. Direkte Main-Branch-Commits.

\- Secrets im Code. Unkontrollierte Loops. Fake-Done.

\- MemorySaver für LangGraph in Production.

\- GPU-Server vor Phase 6. K8s/K3s vor Phase 6.



\## MODELL-ZUWEISUNGEN

Planner: claude-sonnet-4-6 → gpt-4o → gpt-4o-mini

Coder: deepseek-chat → claude-haiku-4-5 → groq-llama-3.3-70b

Tester: gpt-4o-mini → groq-llama-3.3-70b → deepseek-chat

Research: gemini-flash → mistral-large → gpt-4o-mini



\## AGENT-GOVERNANCE (MAX-RETRY: 5, MAX-TOKENS: 8192 für Coder / 4096 sonst)

G1: Kein stiller Architektur-Wechsel

G2: Kein Fake-Done

G3: Max 5 Retries dann Eskalation

G4: Nur feature/agent-\* Branches

G5: Jede Aktion wird geloggt

G6: Kontext-Prüfung vor jedem Task

G7: Human-in-Loop für kritische Aktionen



\## ENTSCHEIDUNGEN (NICHT ÄNDERBAR)

ADR-001: LangGraph (Kern-Orchestrator)

ADR-002: LiteLLM (LLM-Gateway)

ADR-003: Kein AutoGen vor Phase 6

ADR-004: Supabase MVP → Hetzner pgvector Phase 4

ADR-005: Client-Side WebGPU + WebGL-Fallback



\## NÄCHSTE SCHRITTE

\[WIRD PRO CODEX-SESSION EINGESETZT — siehe CODEX\_LOADER\_PROMPT.txt]



═══════════════════════════════════════════════════════════════════

I.20 — VOLLSTÄNDIGE RELEASE-CHECKLISTE (PHASE 5 VORBEREITUNG)

═══════════════════════════════════════════════════════════════════

Das Artefakt das als Git-Artifact gespeichert wird:

markdown# RELEASE-CHECKLISTE — -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM

\# Version: \[VERSION]

\# Release-Datum: \[DATUM]

\# Verantwortlich: \[OWNER-NAME]

\# Status: \[PENDING / APPROVED / BLOCKED]



\## SEKTION 1: CODE-READINESS

\[ ] Alle Unit-Tests: PASS (0 failures)

\[ ] Alle Integration-Tests auf Staging: PASS

\[ ] Alle E2E-Tests (Playwright): PASS

\[ ] Code-Coverage: >= 70% (Backend), >= 60% (Frontend)

\[ ] Kein TODO/FIXME mit BLOCKER-Tag im Code

\[ ] Secret-Scan (gitleaks): CLEAN

\[ ] Dependency-Vulnerability-Scan: CLEAN oder LOW-only

\[ ] Alle offenen Critical/High GitHub Issues für diesen Release: CLOSED

\[ ] CHANGELOG.md für diese Version: VORHANDEN



\## SEKTION 2: INFRASTRUKTUR-READINESS

\[ ] Hetzner-Snapshot VOR dem Deploy: ERSTELLT (Timestamp: \_\_\_\_\_\_)

\[ ] Staging-Deployment: ERFOLGREICH (Health-Check: HEALTHY)

\[ ] Staging-Tests: ALLE PASSED

\[ ] Rollback-Prozedur auf Staging GETESTET (Dauer: \_\_\_\_\_ Minuten)

\[ ] Docker-Images: Alle mit spezifischen Version-Tags (keine "latest")

\[ ] Resource-Limits: Alle Container haben Limits definiert

\[ ] Secrets: Alle in Hetzner-Umgebungsvariablen, KEINE im Code

\[ ] Nginx-Config: Validiert (nginx -t)

\[ ] SSL-Zertifikat: Gültig für >= 30 Tage

\[ ] DNS: Alle Records korrekt



\## SEKTION 3: OBSERVABILITY-READINESS

\[ ] Langfuse: Läuft und empfängt Traces

\[ ] Prometheus: Alle Targets UP

\[ ] Grafana: Alle Dashboards laden korrekt

\[ ] Alert-Regeln: Alle aktiv und getestet

\[ ] Budget-Alert (80%): Funktioniert (getestet auf Staging)

\[ ] Helicone: Aktiv und zählt Requests

\[ ] Audit-Log: Aktiv und schreibt Einträge



\## SEKTION 4: OPERATIONS-READINESS

\[ ] Runbook (Restart-Prozedur): VORHANDEN und aktuell

\[ ] Runbook (Rollback-Prozedur): VORHANDEN und auf Staging getestet

\[ ] Runbook (Memory-Purge): VORHANDEN

\[ ] Runbook (Supabase-Migration): VORHANDEN (Phase 4)

\[ ] Bekannte Limitierungen: DOKUMENTIERT in KNOWN-LIMITATIONS.md

\[ ] Open Questions Log: Aktuell

\[ ] Technical Debt Log: Aktuell

\[ ] ADR-Log: Alle Entscheidungen dieser Phase dokumentiert



\## APPROVAL

Checked by: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

Date: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

Decision: APPROVED / BLOCKED (Reason: \_\_\_\_\_\_\_\_\_\_\_\_)



\## WENN GEBLOCKT: BLOCKLISTE

\- \[ ] \[Blocker 1]

\- \[ ] \[Blocker 2]



═══════════════════════════════════════════════════════════════════

I.21 — ERWEITERTE NEXT-PROMPT-BLOCKS (ALLE PHASEN AUFGEWERTET)

═══════════════════════════════════════════════════════════════════

Die folgenden Blöcke erweitern und präzisieren die NEXT PROMPT FOR AGENT Blöcke aus D1. Sie integrieren alle Lücken-Auflösungen und Required Decisions:



NEXT PROMPT FOR AGENT — PHASE 0 (ERWEITERT)

\[PROJECT]

Name: -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM

Repository: -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM

North Star: Cloud-native, multi-agent, prompt-gesteuert, kein Localhost, 3D-fähig, 20€/Monat Infra

Phase: 0 — Goal Lock und Vorbereitung

Milestone: 7 Vorbereitungs-Dokumente + 6 Required-Decisions klären + Lücken-Auflösungen

Delivery-Mode: Plan (KEIN Code)



\[REQUIRED DECISIONS — OWNER MUSS ENTSCHEIDEN BEVOR PHASE 1 STARTET]

RD-01: Welcher Hetzner-Server für Phase 1?

&#x20; Option A: CX21 (2 vCPU, 4 GB, \~€5/Mo) Production + CX11 Minimal-Staging (\~€4/Mo) = \~€9/Mo BUDGET-SICHER

&#x20; Option B: CPX21 (3 vCPU, 4 GB, \~€8/Mo) Production + CX11 Staging (\~€4/Mo) = \~€12/Mo

&#x20; Option C: CPX31 (4 vCPU, 8 GB, \~€10/Mo) Production + CX11 Staging = \~€14/Mo EMPFOHLEN für Langfuse

&#x20; Empfehlung: Option C (CPX31+CX11) — Langfuse benötigt 4+ GB RAM + 8 GB Swap



RD-02: Shared vs. separate PostgreSQL für Langfuse + Agent-Daten?

&#x20; Empfehlung: Shared PostgreSQL, zwei separate Databases (superbrain\_prod + langfuse)



RD-03: Qdrant in Phase 1-5 aktiv oder nur Phase-6-Option?

&#x20; Empfehlung: Phase-6-Option. pgvector ist ausreichend für Phase 1-5.



RD-04: LangGraph + CrewAI Beziehung?

&#x20; Empfehlung: Option B — LangGraph (State-Machine) + CrewAI (Role-Management innerhalb Agent-Executor-Node)



RD-05: Daten-Split Supabase vs. Hetzner-PostgreSQL?

&#x20; Empfehlung: LangGraph-Checkpoints → Hetzner-PostgreSQL. pgvector-Embeddings → Supabase (Phase 1-3).



RD-06: Phase-1-Staging-Strategie?

&#x20; Empfehlung: Minimaler CX11-Server für Staging. Staging-Stack ist vereinfacht (kein Langfuse auf Staging).



OQ-07: GitHub-Repository öffentlich oder privat?

&#x20; Impact: Wenn privat → GitHub Actions Minutes begrenzt (2000/Monat Free Tier). Wenn öffentlich → unlimited.



\[MEMORY — WAS ENTSCHIEDEN IST]

Unveränderlich: Kein Localhost. Kein lokales Modell. 20€/Monat Infra-Limit. OSS-First.

Stack: LangGraph, LiteLLM, Supabase MVP, Docker Compose, Vercel, Hetzner, Langfuse self-hosted

Design: Dark Mode, shadcn/ui, Indigo/Violett/Türkis, 9 Pflicht-Zustände pro Screen

ADRs beschlossen: ADR-001 LangGraph, ADR-002 LiteLLM, ADR-003 kein AutoGen, ADR-004 Supabase MVP, ADR-005 WebGPU

Neue ADRs notwendig: ADR-006 Single-Tenant Phase 1-5, ADR-007 Async-First-Architektur



\[TASK — PHASE 0 AUFGABEN]

0.1: Monorepo-Struktur dokumentieren (alle 7 Systemschichten + alle Module aus diesem Dokument)

0.2: 7 ADR-Dokumente erstellen (ADR-001 bis ADR-007, alle mit 5 Pflichtfeldern)

0.3: Secrets-Management-Plan (alle API-Keys: Anthropic, OpenAI, Supabase, GitHub, HuggingFace, Together.ai, Groq, Cloudflare, E2B, Helicone, Langfuse + je ein Speicherort + Rotation alle 90 Tage)

0.4: Kosten-Policy mit konkreten Zahlen (20€ Infra, 200€ LLM, 80% Alerts, per-Modell-Kosten)

0.5: CODEX\_AGENT\_SKILL\_MASTER.md + CODEX\_LOADER\_PROMPT.txt in /docs/codex-integration/

0.6 NEU: Required-Decisions-Dokument (RD-01 bis RD-06 + OQ-01 bis OQ-07 mit Owner-Antworten)

0.7 NEU: Assumptions-Log (alle ❓ UNVERIFIED Annahmen aus dem Verification-Register)



\[LÜCKEN DIE IN PHASE 0 GESCHLOSSEN WERDEN]

L-01: ADR-Trigger-Checkliste (im Dokument oben vollständig definiert — übernehmen)

L-25: CODEX\_AGENT\_SKILL\_MASTER.md Inhalt (im Dokument oben vollständig definiert — übernehmen)

L-31: Secret-Scanner-Tool (gitleaks — als Pre-Commit + GitHub Actions konfigurieren)



\[VERIFICATION]

Jedes ADR hat: Entscheidung, Kontext, Begründung, Abgelehnte Alternativen, Konsequenzen

RD-01 bis RD-06: Schriftlich bestätigt vom Owner

OQ-01 bis OQ-07: Schriftlich beantwortet vom Owner

Alle 7 Dokumente: Owner-Bestätigung

Phase 1 startet NICHT ohne vollständige Owner-Bestätigung aller Dokumente + RDs



\[BLOCKER FÜR PHASE 1]

❌ RD-01 (Server-Typ) nicht entschieden

❌ RD-02 (PostgreSQL-Strategie) nicht entschieden

❌ RD-03 (Qdrant-Scope) nicht entschieden

❌ RD-04 (LangGraph+CrewAI) nicht entschieden

❌ RD-05 (Daten-Split) nicht entschieden

❌ RD-06 (Staging-Strategie) nicht entschieden

❌ ADR-006 und ADR-007 nicht erstellt



NEXT PROMPT FOR AGENT — PHASE 1 (ERWEITERT)

\[PROJECT]

Phase: 1 — Foundation

Milestone: Infrastruktur + CI/CD + DB-Schema + Observability-Strategie

Delivery-Mode: Design (Dokumente) → dann Build (Infrastructure-as-Code)



\[MEMORY — PHASEN-STATE]

RD-01 ENTSCHIEDEN: \[Server-Typ — Owner-Antwort einsetzen]

RD-02 ENTSCHIEDEN: Shared PostgreSQL (superbrain\_prod + langfuse databases)

RD-03 ENTSCHIEDEN: Qdrant → Phase 6. Nicht in Phase 1 deployed.

RD-04 ENTSCHIEDEN: LangGraph + CrewAI Option B (nested)

RD-05 ENTSCHIEDEN: LangGraph-Checkpoints → Hetzner-PostgreSQL, Embeddings → Supabase

RD-06 ENTSCHIEDEN: \[Staging-Strategie — Owner-Antwort einsetzen]

Phase-0-Dokumente: ALLE BESTÄTIGT



\[TASK — PHASE 1 AUFGABEN]

1.1: Hetzner-Server-Setup-Runbook (nicht Automatisierung — Schritt-für-Schritt-Dokumentation)

&#x20; Inhalt: SSH-Key-Setup, UFW-Firewall-Regeln (22/80/443 extern, alles andere intern), 

&#x20; Docker+Docker-Compose Installation, Swap-Space 8GB, Auto-Updates aktivieren

&#x20; 

1.2: Docker-Compose-Design-Dokument für \[7 Services — ohne Qdrant]:

&#x20; nginx, agent-api, redis, postgres (pgvector), langfuse-server, langfuse-worker, mcp-gateway

&#x20; FÜR JEDEN SERVICE:

&#x20;   - Docker-Image mit spezifischem Version-Tag (keine latest)

&#x20;   - Interne Ports (niemals DB-Ports nach außen)

&#x20;   - Volumes mit Named-Volumes (kein bind-mount für Production)

&#x20;   - Umgebungsvariablen als ${PLACEHOLDER}

&#x20;   - depends\_on mit condition: service\_healthy

&#x20;   - Health-Check (command, interval, timeout, retries)

&#x20;   - Resource-Limits (mem\_limit, cpus)

&#x20; ZUSÄTZLICH: langfuse-database als internal postgres schema (nicht separater Service)

&#x20; ZUSÄTZLICH: Watchtower-Service für automatisches Image-Update



1.3: CI/CD-Skeleton (3 GitHub Actions Workflows):

&#x20; Workflow 1 (pr-check): Linting + Type-Check + Unit-Tests + Secret-Scan (gitleaks)

&#x20; Workflow 2 (main-deploy): Tests + Staging-Deploy (Watchtower) + Health-Check + Production-Deploy (manuell)

&#x20; Workflow 3 (hotfix): Schneller Deploy-Pfad mit obligatorischem Approval

&#x20; PLUS: supabase-keepalive.yml (alle 6 Tage)

&#x20; PLUS: infra-cost-check.yml (wöchentlich)

&#x20; Deploy-Mechanismus: Docker Hub/GHCR Push + Watchtower Pull (wie in diesem Dokument beschrieben)



1.4: Datenbankschema für 6 Tabellen (DDL aus diesem Dokument übernehmen):

&#x20; projects, agent\_sessions, agent\_messages, memory\_entries, cost\_tracking, audit\_log

&#x20; PLUS: LangGraph-Tabellen-Dokumentation (automatisch erstellt, nicht manuell)



1.5: Observability-Strategie-Dokument:

&#x20; Metriken-Matrix pro Schicht (aus diesem Dokument übernehmen)

&#x20; Trace-ID-Propagation-Beschreibung (x-trace-id Header)

&#x20; Grafana-Dashboard-Spezifikationen (4 Dashboards)

&#x20; Alert-Regeln-Dokumentation

&#x20; Langfuse-Erreichbarkeit-Lösung (Nginx-Auth-Proxy oder VPN)



1.6: Staging-Umgebung-Plan:

&#x20; CX11 Minimal-Staging. Vereinfachter Stack (ohne Langfuse auf Staging).

&#x20; Identische Konfiguration aber kleinere Resource-Limits.



1.7 NEU: GitHub-Branch-Protection-Konfiguration (aus diesem Dokument übernehmen)

1.8 NEU: gitleaks-Konfiguration (.gitleaks.toml)



\[LÜCKEN DIE IN PHASE 1 GESCHLOSSEN WERDEN]

L-13: GitHub Branch-Protection → Dokument 1.7

L-26: Deploy-Mechanismus → Dokument 1.3 (Watchtower)

L-30: Kritische MCP-Server Liste → GitHub-MCP und E2B-MCP (2 Instanzen), andere 1 Instanz

L-31: Secret-Scanner → gitleaks in Dokument 1.3 + Dokument 1.8

L-33: Supabase Keep-Alive → Dokument 1.3 (supabase-keepalive.yml)



\[VERIFICATION]

Jeder Docker-Service hat: Image-Tag (nicht latest), Health-Check, Resource-Limits, alle Ports intern

DB-Schema beantwortet: Was kostet Projekt X? Welche Agenten in Session Y? Memory-Entries für Projekt Z?

Kein Service exponiert DB-Ports nach außen

Deploy-Mechanismus beschreibt: wie GitHub Actions → Hetzner-Image-Update funktioniert



NEXT PROMPT FOR AGENT — PHASE 2 (ERWEITERT)

\[PROJECT]

Phase: 2 — Core Runtime

Milestone: LangGraph-Orchestrator + 4 Kern-Agenten + Memory-System + LLM-Gateway

Delivery-Mode: Plan → Build (erst vollständige Architektur, dann Implementierung)



\[MEMORY — KRITISCHE ERINNERUNGEN FÜR PHASE 2]

ALLER-ERSTES: Rate-Limiting + Budget-Alert BEVOR IRGENDEIN LLM-CALL IN PRODUCTION

LangGraph-Checkpointer: PostgreSQL-ONLY (Hetzner). NIEMALS MemorySaver in Production.

Max-Retry: 5 pro Agent, dann Eskalation.

Trace-ID (x-trace-id) propagiert durch ALLE Schichten.

Memory-Konsolidierungsjob: alle 5 Minuten (nicht 30!) mit Entry-Status-Flag.

Context-Budget: max. 30% des Modell-Kontextfensters für Memory-Injection.

LangGraph+CrewAI: Option B (LangGraph State-Machine, CrewAI als nested Agent-Executor-Step)



\[TASK — PHASE 2 AUFGABEN]

SCHRITT 1 (MUSS ZUERST FERTIG SEIN, KEINE AUSNAHME):

&#x20; Rate-Limiting-Implementierung:

&#x20;   Cloudflare (erste Linie): Rate-Limiting auf Cloudflare-Level für öffentliche Endpoints

&#x20;   Upstash (zweite Linie): Token-Bucket per User-ID in FastAPI-Middleware

&#x20;   Max LLM-Calls per Agent per Session: 50

&#x20;   Budget-Guard Node in LangGraph vor Agent-Executor: prüft ob Budget <100% bevor LLM-Call

&#x20; Budget-Alert-Implementierung:

&#x20;   Helicone aktiv ab erstem API-Call

&#x20;   Prometheus-Metriken: llm\_cost\_cents\_total per Agent/Modell

&#x20;   Alert bei 80% (160€ LLM) → Throttle-Mode + Warning-Banner via SSE-Event

&#x20;   Alert bei 100% (200€ LLM) → Hard-Stop + Critical-Alert

&#x20;   Infrastruktur-Budget: wöchentlicher GitHub-Actions-Check

&#x20; VERIFIKATION: Budget-Alert-Test muss bestanden sein bevor Schritt 2



SCHRITT 2: LangGraph-Graph (7 Nodes):

&#x20; Intent-Parser: Prompt → strukturierter Task-Plan (JSON-Schema definieren)

&#x20; Budget-Guard: Budget-Check vor Agent-Execution (NEU — AE-01 Empfehlung)

&#x20; Task-Router: Task → Agent-Zuweisung

&#x20; Agent-Executor: Agent-Start, State-Management, CrewAI-Integration

&#x20; Result-Aggregator: Multi-Agent-Ergebnis zusammenführen

&#x20; Memory-Updater: Memory-System nach jeder Aktion aktualisieren

&#x20; Error-Handler: Recovery-Pfade, Retry-Logik (max 5), Eskalation

&#x20; CHECKPOINTER: PostgreSQL async (psycopg3). 

&#x20; TEST: Server-Neustart während aktivem Graph-Run → State-Recovery-Verifizierung.



SCHRITT 3: 4 Agenten-Profile implementieren (aus diesem Dokument: Agent-Governance-Codex)

&#x20; Planner: System-Prompt-Template + claude-sonnet-4-6 Primary

&#x20; Coder: System-Prompt-Template + deepseek-chat Primary + 8192 Max-Tokens

&#x20; Tester: System-Prompt-Template + gpt-4o-mini Primary + E2B-Integration

&#x20; DevOps: System-Prompt-Template + gpt-4o-mini + GitHub-Actions-Trigger via API



SCHRITT 4: LiteLLM-Gateway-Konfiguration

&#x20; Modell-Routing-Tabelle (aus diesem Dokument übernehmen)

&#x20; Cloudflare-AI-Gateway-Proxy aktivieren (Cache TTL: 10 Minuten)

&#x20; Helicone-Proxy aktivieren

&#x20; Fallback-Konfiguration für alle Slots



SCHRITT 5: MCP-Gateway (4 Tool-Sets)

&#x20; GitHub-MCP: 2 Instanzen. Branch-Restriction enforcement.

&#x20; E2B-MCP: 2 Instanzen. finally-Block-Pflicht. 30-Min-Timeout.

&#x20; Playwright-MCP: 1 Instanz.

&#x20; Filesystem-MCP: 1 Instanz. /tmp/agent-workspace/ only.

&#x20; Logging: Jeder Tool-Call → Langfuse-Trace.



SCHRITT 6: Memory-System

&#x20; Redis-Working-Memory mit Status-Flag (pending/consolidated/failed)

&#x20; Konsolidierungsjob: alle 5 Minuten, TTL-Schwelle 8 Minuten

&#x20; Supabase pgvector für Long-Term-Memory

&#x20; Memory-Read-API-Contract: GET /internal/memory/search?query=\&top\_k=5\&project\_id=\&context\_budget\_tokens=

&#x20; Embedding-Version-Tracking: embedding\_model\_version in jedem Entry



SCHRITT 7: SSE-Streaming-Implementation

&#x20; FastAPI StreamingResponse

&#x20; SSE-Event-Types: token, agent\_status, provider\_switch, budget\_alert, error, done, heartbeat

&#x20; Event-ID für Reconnect-Replay (letzte 50 Events per Session in Redis)

&#x20; Reconnect-Strategie: Last-Event-ID Header



\[LÜCKEN DIE IN PHASE 2 GESCHLOSSEN WERDEN]

L-05: Interface-Contract (vollständig in API-Register oben definiert)

L-06: Task-Assignment-Struktur (Redis Queue mit JSON-Schema)

L-07: LiteLLM-Streaming (via SCHRITT 4)

L-08: MCP-Versionspinning (konkrete Versionen in docker-compose.yml)

L-12: Done-Validierung (Orchestrator validiert alle 5 Done-Kriterien)

L-14: Memory-Read-API-Contract (via SCHRITT 6)

L-15: DeepSeek-Version verifizieren und Output-Limit testen

L-16: E2B-Graceful-Degradation (wenn E2B down → Tester-Agent deaktiviert, User-Warning)

L-17: DevOps-Agent GitHub-Actions-Trigger (GitHub API POST /repos/{}/actions/workflows/{}/dispatches)

L-22: Provider-Rotation-Backoff (exponential backoff: 30s → 60s → 120s → 300s, dann Reset)

L-23: Modell-Capability-Matrix (in LiteLLM-Config dokumentiert)

L-24: Rotation-Log-Format (strukturiertes JSON: {timestamp, from\_provider, to\_provider, reason, agent, session\_id})

L-27: LangGraph-Checkpoint-Schema-Initialisierung (LangGraph async checkpointer init)

L-28: Refresh-Token-Invalidierung (Redis-Blacklist mit TTL = Original-Refresh-Token-TTL)

L-32: State-Recovery-Testprozedur (im SCHRITT 2 definiert und ausgeführt)



\[VERIFICATION]

Budget-Alert-Test: MUSS vor erstem Production-LLM-Call bestanden sein

State-Recovery-Test: Server-Neustart während aktivem Graph-Run → State korrekt wiederhergestellt

Loop-Schutz: Kein Graph-Node hat Loop ohne Retry-Zähler

Done-Validierung: Orchestrator prüft alle 5 Kriterien bevor "Done" an Frontend

Budget-Guard-Node: Aktiv vor Agent-Executor im Graph



NEXT PROMPT FOR AGENT — PHASE 3 (ERWEITERT)

\[PROJECT]

Phase: 3 — Product Surface + Security

Milestone: 4-Screen-Frontend + Auth + DSGVO + Rate-Limiting + Cost-Monitor



\[TASK]

Screen 1 (Workspace):

&#x20; Prompt-Input (max 10000 chars), SSE-Streaming-Output, Agent-Status-Anzeige

&#x20; Budget-Status-Banner im Header (immer sichtbar), Progress-Indicator für 3D-Tasks

&#x20; SSE-Reconnect: exponential backoff, max 3 Versuche, dann Error-State



Screen 2 (Memory-Viewer):

&#x20; Semantische Suche (Echtzeit), Top-K Ergebnisse mit Relevanz-Score und Zeitstempel

&#x20; Manuelles Löschen einzelner Entries, Purge-All-Button (DSGVO, 2-Step-Confirmation)

&#x20; Datenquelle: GET /api/v1/memory/search



Screen 3 (Agent-Activity):

&#x20; Echtzeit-Log aller Agenten-Aktionen (SSE), Filter nach Agent-Typ, Zeitraum, Status

&#x20; Trace-Visualisierung, Deep-Link zu Langfuse via Nginx-Auth-Proxy

&#x20; LANGFUSE-ERREICHBARKEIT: Nginx-Basic-Auth-Proxy oder IP-Whitelist-gesicherter Deep-Link



Screen 4 (Cost-Monitor):

&#x20; Echtzeit-Kosten (per Session, per Agent, per Modell, kumulativ)

&#x20; Budget-Alert-Schwelle als visuelle Linie, historischer Verlauf

&#x20; Export: CSV-Format, auswählbarer Zeitraum

&#x20; Datenquelle: GET /api/v1/costs



Auth:

&#x20; GitHub OAuth Flow, JWT (15 Min Access, 7 Tage Refresh)

&#x20; HttpOnly + Secure + SameSite=Strict Cookies

&#x20; Refresh-Token-Rotation: neuer Refresh-Token bei jedem Refresh-Request

&#x20; Blacklist kompromittierter Refresh-Token in Redis (TTL = Original-TTL)



DSGVO-Purge:

&#x20; DELETE /api/v1/memory mit confirm=true Parameter

&#x20; Scope: Redis + pgvector + agent\_sessions + agent\_messages + Langfuse-Traces

&#x20; Async-Job (202 Accepted) mit Job-Status-Tracking

&#x20; Audit-Log: 30 Tage Aufbewahrung



\[LÜCKEN DIE IN PHASE 3 GESCHLOSSEN WERDEN]

L-03: Infra-Budget-Tracking (infra-cost-check.yml aktiv)

L-18: Langfuse-Erreichbarkeit (Nginx-Auth-Proxy)

L-19: Cost-Monitor Export (CSV)

L-21: UI-Fallback-State "System nicht erreichbar" (Error-Banner)

L-28: Refresh-Token-Invalidierung (vollständig implementiert)

OQ-04: Mobile-Responsiveness (Entscheidung: Desktop-First, Mobile Phase 6)



NEXT PROMPT FOR AGENT — PHASE 4-5 (ERWEITERT)

\[PHASE 4 — Integration und Hardening]

10 Integrations-Test-Szenarien (vollständig ausschreiben, nicht nur titeln):

&#x20; 1. Happy Path: Einfacher Code-Task, 4 Agenten, erfolgreich

&#x20; 2. Retry-Limit: Coder-Agent scheitert 5×, korrekte Eskalation

&#x20; 3. LLM-Fallback: Primary-Provider down, Rotation zu Fallback, User-Toast

&#x20; 4. Ressourcenlimit: Budget 80%, Throttle-Modus aktiv

&#x20; 5. Concurrent Sessions: 3 gleichzeitige Prompts, kein State-Konflikt

&#x20; 6. State-Recovery: Server-Neustart während aktiver Session

&#x20; 7. Empty Memory: Neues Projekt, keine Memory-History, Orchestrator startet korrekt

&#x20; 8. Budget-Alert: Budget 100%, Hard-Stop, korrekte User-Notification

&#x20; 9. Auth-Fehler: Abgelaufenes Token, korrekte 401-Response, Redirect zu Login

&#x20; 10. Branch-Protection-Verletzung: Coder versucht in Main zu pushen, korrekt abgeblockt



Security-Audit (5 Kategorien):

&#x20; 1. Auth: JWT-Expiry, Cookie-Flags, Refresh-Token-Rotation, CORS-Header

&#x20; 2. Secrets: gitleaks-Scan, .env nicht in Git, Umgebungsvariablen korrekt

&#x20; 3. Agent-Permissions: GitHub-MCP kann nicht in Main pushen, Filesystem-MCP nur /tmp/

&#x20; 4. Input-Validation: Prompt-Length-Limit, SQL-Injection (pgvector queries), XSS

&#x20; 5. Budget-Controls: Rate-Limiter aktiv, Budget-Alert-Tests bestanden



Performance-Baseline:

&#x20; Erste Streaming-Token: < 3 Sekunden

&#x20; Einfacher Code-Task (< 50 Zeilen): < 60 Sekunden

&#x20; Semantische Memory-Suche: < 500ms

&#x20; Agent-Status-Update im Frontend: < 1 Sekunde nach Agent-Action



\[PHASE 5 — Release-Readiness]

Release-Checkliste (aus diesem Dokument oben): als Git-Artifact speichern

Rollback-Prozedur (aus diesem Dokument oben): auf Staging testen

Hetzner-Snapshot vor Production-Deploy: PFLICHT

Production-Deploy: manuell genehmigt in GitHub Actions Workflow 2



═══════════════════════════════════════════════════════════════════

J. NEXT-STEP-BLOCK — SOFORT-AKTIONEN

═══════════════════════════════════════════════════════════════════

J.1 — KRITISCHSTE SOFORT-ERKENNTNISSE



W-RESIDUAL-01 (Budget vs. Server-Kosten) ist ein echter Blocker der vor Phase 1 gelöst werden muss. Empfehlung: CPX31 Production + CX11 Staging = \~€14/Monat. Im Budget.

6 Required Decisions (RD-01 bis RD-06) sind Owner-Input — kein Agent kann diese entscheiden. Sie blockieren Phase 1.

Lücke L-26 (CI/CD-Deploy-Mechanismus) war ein echter Architekt-Blindspot der in D1 nicht adressiert war. Watchtower-Strategie schließt sie ohne SSH-Sicherheitsrisiko.

Memory-Konsolidierungs-Race-Condition (R-NEW-01) ist ein echter Fehler in der 30-Minuten-Job-Logik. Fix: 5-Minuten-Intervall + TTL-Schwelle 8 Minuten.

Qdrant vs. pgvector-Widerspruch (W-RESIDUAL-03) muss aufgelöst werden: Qdrant aus Phase-1-Docker-Compose entfernen, spart RAM und Komplexität.

LangGraph + CrewAI-Widerspruch (W-RESIDUAL-04) ist ein Architektur-Grundfrage. Option B (nested) ist die eleganteste Lösung.



J.2 — KRITISCHSTE OFFENE PUNKTE

PrioritätPunktWerWann🔴 SOFORTRD-01 bis RD-06 entscheidenOwnerVor Phase 1🔴 SOFORTW-RESIDUAL-01 auflösen (Server-Budget)OwnerVor Phase 1🔴 SOFORTOQ-07 klären (Repo öffentlich/privat)OwnerVor Phase 0.5🟡 PHASE 0ADR-006 + ADR-007 erstellenAgentPhase 0🟡 PHASE 1Hetzner-Snapshot-Strategie implementierenAgentPhase 1 vor erstem Deploy🟡 PHASE 2Memory-Konsolidierungs-Race-Condition fixenAgentPhase 2, Memory-System🟡 PHASE 2Budget-Guard-Node in LangGraph-GraphAgentPhase 2, Schritt 2

J.3 — WICHTIGSTE ENTSCHEIDUNGEN (ZUSAMMENFASSUNG)

Von 14 bereits gelösten Konflikten (K1-K14) existieren 6 residuale Widersprüche (W-RESIDUAL-01 bis -06), 6 Required Decisions (RD-01 bis -06) und 7 offene Fragen (OQ-01 bis OQ-07).

Die eine Entscheidung mit höchstem Hebel: RD-01 (Server-Typ Phase 1) definiert ob das Projekt überhaupt im Budget startet.

J.4 — EMPFOHLENE NÄCHSTE ANALYSE-ODER UMSETZUNGSFRAGEN

Wenn Phase 0 gestartet wird, empfehle diese Prompts in dieser Reihenfolge:

PROMPT 1 (Owner-Entscheidungen):

"Ich bin der Owner des Projekts -CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM.

Bitte gib mir eine kompakte Entscheidungs-Matrix für alle 6 Required Decisions 

(RD-01 bis RD-06) und 7 Open Questions (OQ-01 bis OQ-07) mit klarer Empfehlung 

und den Trade-offs, damit ich schnell entscheiden kann."



PROMPT 2 (Phase 0 Dokumente):

Kopiere den erweiterten NEXT PROMPT FOR AGENT — PHASE 0 aus diesem Dokument.

Sende ihn an Agenten. Erhalte 7 Dokumente.

Bestätige alle 7 Dokumente + alle RD-Entscheidungen.



PROMPT 3 (Phase 1 Start):

Kopiere den erweiterten NEXT PROMPT FOR AGENT — PHASE 1 aus diesem Dokument.

Sende ihn an Agenten. Erhalte Infrastructure-Design-Dokumente.



═══════════════════════════════════════════════════════════════════

I. ULTIMATIVER MASTER-SUMMARY-BLOCK

═══════════════════════════════════════════════════════════════════

\-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM ist eine cloud-native Multi-Agent AI Developer Platform die vollständig über natürliche Sprache gesteuert wird, in 4er-Agenten-Squads skaliert, 3D-Webgame-Rendering client-seitig ermöglicht und dreischichtiges Langzeitgedächtnis über hunderte Prompts bewahrt — alles innerhalb eines Infrastruktur-Budgets von 20€/Monat.

Das Projekt ist in Phase 0 (Goal Lock). Alle Kernentscheidungen sind getroffen (LangGraph, LiteLLM, Supabase MVP, Docker Compose, Vercel Frontend, Hetzner Backend, Langfuse self-hosted, Dark Mode, shadcn/ui, kein Localhost, kein lokales Modell, max 5 Retries, Human-in-Loop für kritische Aktionen). 14 Widersprüche zwischen 10 Vordokumenten sind aufgelöst.

Die forensische Analyse dieses Dokuments identifiziert 6 residuale Widersprüche (darunter kritisch: Budget vs. tatsächliche Hetzner-Server-Kosten; LangGraph vs. CrewAI-Beziehung; Qdrant vs. pgvector-Scope), 6 Required Decisions die Owner-Input erfordern, 7 offene Fragen, 33 Architektur-Lücken (7 kritisch, 12 hoch, 14 mittel), 4 neu identifizierte Risiken und 24 zu schließende Lücken die in diesem Dokument vollständig aufgelöst wurden (API-Interface-Contracts, Datenbankschema-DDL, Agent-Governance-Codex, Branch-Protection-Konfiguration, CI/CD-Deploy-Mechanismus, Rollback-Prozedur, Release-Checkliste, Secret-Scanner-Konfiguration, Memory-Race-Condition-Fix, CODEX\_AGENT\_SKILL\_MASTER.md-Inhalt).

Das vorliegende Dokument schließt D1 als vollständige Wahrheitsquelle ab und fügt die fehlenden operativen Ebenen hinzu: vollständige Interface-Contracts, DDL-Datenbankschema, Agent-Governance-Codex mit konkretem System-Prompt-Rahmen, Wiring-Map für alle 7 Module, erweiterte NEXT-PROMPT-Blocks für alle Phasen, und vollständige Runbooks (Rollback, DSGVO-Purge, Supabase-Keep-Alive, Infrastruktur-Budget-Tracking). Kein Token wurde ohne Informationsgewinn verbraucht.

Die nächste erforderliche Aktion ist exakt eine: Owner trifft die 6 Required Decisions (RD-01 bis RD-06), danach startet Phase 0 mit dem erweiterten NEXT PROMPT FOR AGENT — PHASE 0 aus diesem Dokument.



═══════════════════════════════════════════════════════════════════

PROJECT MEMORY UPDATE (SKILL §20)

═══════════════════════════════════════════════════════════════════

AKTIVE PHASE: 0 — Goal Lock und Vorbereitung

AKTIVER MEILENSTEIN: Required Decisions (RD-01 bis RD-06) + Phase-0-Dokumente erstellen

NORTH STAR ALIGNMENT: VOLLSTÄNDIG AKTIV UND VERANKERT



NEU ENTSCHIEDEN (durch diese Synthese):

\- Memory-Konsolidierungsjob: alle 5 Minuten (nicht 30), TTL-Schwelle 8 Minuten

\- Budget-Guard-Node: als 7. Node in LangGraph-Graph (vor Agent-Executor)

\- Qdrant: Phase-6-Option (nicht Phase-1-5)

\- Shared PostgreSQL für Langfuse + Agent-Daten (zwei Databases)

\- CI/CD-Deploy-Mechanismus: Watchtower + Docker Hub/GHCR

\- ADR-Trigger-Checkliste: vollständig definiert (17 Trigger, 5 Non-Trigger)

\- Context-Budget-Limit: max. 30% des Modell-Kontextfensters für Memory-Injection

\- SSE-Heartbeat: alle 15 Sekunden, letzte 50 Events per Session in Redis für Reconnect-Replay

\- gitleaks als Secret-Scanner (Pre-Commit + GitHub Actions)

\- Embedding-Model-Version: tracking-Feld in memory\_entries Pflicht



OFFENE BLOCKERS (Owner-Input erforderlich):

\- RD-01: Server-Typ Phase 1 (Empfehlung: CPX31+CX11 = \~€14/Mo)

\- RD-02: PostgreSQL-Strategie (Empfehlung: Shared, zwei Databases)

\- RD-03: Qdrant-Scope (Empfehlung: Phase-6-Option)

\- RD-04: LangGraph+CrewAI-Beziehung (Empfehlung: Option B nested)

\- RD-05: Daten-Split Supabase/Hetzner (Empfehlung: LangGraph→Hetzner, Embeddings→Supabase)

\- RD-06: Staging-Strategie (Empfehlung: CX11 minimal, vereinfachter Stack)

\- OQ-07: Repo öffentlich/privat (beeinflusst GitHub Actions Minutes)



UNVERIFIED ANNAHMEN:

\- E2B-Pricing ausreichend für Phase 1-2 Development

\- Groq-Latenz ausreichend für Production

\- LiteLLM-Performance unter Last

\- Supabase Free Tier bis 400MB ausreichend

\- CPX31 ausreichend für alle 7 Services gleichzeitig (inkl. Langfuse + 8 GB Swap)



NÄCHSTER ERFORDERLICHER SCHRITT:

Owner entscheidet RD-01 bis RD-06 → 

Erweiterter NEXT PROMPT FOR AGENT PHASE 0 senden → 

7 Dokumente erstellen lassen → 

Owner bestätigt alle 7 + alle RDs schriftlich → 

Phase 1 startet.

