from __future__ import annotations

import re
import sys
import json
import hashlib
from collections import Counter
from pathlib import Path
from typing import Final


ROOT: Final = Path(__file__).resolve().parents[1]
PHASE3_PATH: Final = Path("docs/runtime-contracts/phase3-credit-rubric.md")
PHASE6_PATH: Final = Path("docs/runtime-contracts/phase6-credit-rubric.md")
MANIFEST_PATH: Final = Path("docs/project-progress.manifest.json")
GATES_PATH: Final = Path("docs/runtime-state/capability-gates.json")
LEDGER_PATH: Final = Path("docs/runtime-state/project-progress-delta-ledger.json")
ENDPOINT_SNAPSHOT_PATH: Final = Path("apps/frontend/lib/endpoint-snapshot.json")
PLATFORM_PATH: Final = Path("apps/frontend/lib/platform.ts")
PHASE6_CRITERION_PATH: Final = Path("docs/runtime-state/phase6-scale-criterion.json")
PHASE6_CRITERION_SHA256: Final = "edeeac95fac6fefe1dcde5b77a5d8b236685f28adf66f357706aed26971ed85f"

EXPECTED_PHASE3_ROWS: Final = (
    ("P3-B00", "Bereits kreditierter historischer Phase-3-Gesamtblock; keine Neuberechnung in diesem Entwurf", 44, "bestehender Manifestwert"),
    ("P3-01", "Hosted OAuth-Start liefert die echte freigegebene `client_id`, exakt Scope `read:user` und einen kryptographischen One-Time-State", 8, "offen"),
    ("P3-02", "Hosted Callback tauscht einen echten Code gegen die verifizierte numerische GitHub-Identitaet und stellt erst danach die Session bereit", 12, "offen"),
    ("P3-03", "Die Owner-Allowlist bindet die numerische GitHub-Identitaet fail-closed; fremde oder fehlende Identity erhaelt keine Credentials", 8, "offen"),
    ("P3-04", "OAuth-State-Cookie: `__Host-`, `Secure`, `HttpOnly`, `SameSite=Lax`, `Path=/`, kein `Domain`; Access-/Refresh-Cookies: `__Host-`, `Secure`, `HttpOnly`, `SameSite=Strict`, `Path=/`, kein `Domain`, freigegebene TTL", 6, "offen"),
    ("P3-05", "Refresh rotiert atomar; Replay des alten Tokens liefert exakt HTTP `401`, widerruft die komplette Tokenfamilie und stellt keine neuen Credentials aus", 8, "offen"),
    ("P3-06", "Logout widerruft nur einen aktiven registrierten Refresh-Token, loescht beide Auth-Cookies, persistiert den korrelierten Audit-Eintrag und Post-Logout-Refresh liefert `401`", 6, "offen"),
    ("P3-07", "Callback-Replay und Wiederverwendung des OAuth-State werden fail-closed abgewiesen", 4, "offen"),
    ("P3-08", "Die Auditkette ist Request-/Session-ID-korreliert, vor Credential-Ausgabe persistiert und enthaelt keine Codes, OAuth-State-Werte, Tokens, Cookie-Werte oder Secrets", 4, "offen"),
)
EXPECTED_PHASE6_ROWS: Final = (
    ("P6-B01", "Historischer gemeinsamer Frontend-Block: Client-Runtime, Interaktion, Scene-State und Performance-Budget", 32, "bereits kreditierter Gesamtblock"),
    ("P6-B02", "Kamera- und Lichtsteuerung", 8, "bereits kreditiert; DEV-ONLY Beweis"),
    ("P6-B03", "Gameplay-Zustandsmaschine", 8, "bereits kreditiert; DEV-ONLY Beweis"),
    ("P6-B04", "Asset-Policy und fail-closed Asset-Grenzen", 8, "bereits kreditiert; DEV-ONLY Beweis"),
    ("P6-B05", "Volatiler Save-/Load-Roundtrip", 8, "bereits kreditiert; DEV-ONLY Beweis"),
    ("P6-B06", "Accessibility-Steuerung und sichtbare Zustandswirkung", 8, "bereits kreditiert; DEV-ONLY Beweis"),
    ("P6-B07", "Browser-Loopback-Netcode ohne Remote-/Server-Claim", 8, "bereits kreditiert; DEV-ONLY Beweis"),
    ("P6-B08", "Lokale Scoreboard-/Performance-Klassifikation", 10, "bereits kreditiert; DEV-ONLY Beweis"),
    ("P6-H01", "Exakt 800 Hosted Reads in drei Stufen (`60@1`, `240@10`, `500@50`)", 3, "offen"),
    ("P6-H02", "Exakt 50 authentisierte D1-Creates bei Concurrency `10`, ohne Verlust/Duplikat und mit vollstaendigem Readback", 3, "offen"),
    ("P6-H03", "Exakt 50 auditierte Deletes mit `soft_delete_then_active_row_absence_and_audit_readback` und vollstaendigem Cleanup", 2, "offen"),
    ("P6-H04", "Exakte Requestzahl, Erfolgsquote, p95- und 5xx-Auswertung gegen die festgelegten Grenzwerte", 2, "offen"),
)
EXPECTED_BLOCKED_MULTSET: Final = (
    "binary_asset_upload_blocked",
    "benchmark_claim_blocked",
    "shader_hotload_blocked",
    "remote_multiplayer_netcode_blocked",
    "server_authoritative_sync_blocked",
    "physics_engine_blocked",
    "external_asset_fetch_blocked",
    "binary_asset_upload_blocked",
    "remote_cdn_fetch_blocked",
    "asset_pipeline_service_blocked",
    "load_without_snapshot_blocked",
    "persistent_browser_storage_blocked",
    "cloud_save_sync_blocked",
    "binary_snapshot_upload_blocked",
    "server_snapshot_write_blocked",
    "websocket_transport_blocked",
    "webrtc_transport_blocked",
    "matchmaking_blocked",
    "public_lobby_blocked",
    "server_authoritative_sync_blocked",
    "phase6_leaderboard_sync_blocked",
    "phase6_capacity_claim_blocked",
)


class RubricValidationError(ValueError):
    """A deterministic, user-actionable draft-rubric validation failure."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RubricValidationError(message)


def compact(text: str) -> str:
    return re.sub(r"\s+", " ", text.replace("\r\n", "\n")).strip()


def visible_markdown(text: str) -> str:
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL)


def require_markers(text: str, markers: tuple[str, ...], context: str) -> None:
    flattened = compact(text)
    for marker in markers:
        require(marker in flattened, f"{context} missing required statement: {marker}")


def metadata(text: str, label: str, context: str) -> str:
    candidate_lines = re.findall(
        rf"^{re.escape(label)}:.*$",
        text,
        flags=re.MULTILINE,
    )
    require(
        len(candidate_lines) == 1,
        f"{context} metadata field {label} must occur exactly once",
    )
    match = re.fullmatch(rf"{re.escape(label)}:\s+`([^`]+)`\s*", candidate_lines[0])
    require(match is not None, f"{context} metadata field {label} has invalid shape")
    return match.group(1)


def parse_credit_rows(
    text: str, prefix: str, context: str
) -> tuple[tuple[str, str, int, str], ...]:
    rows: list[tuple[str, str, int, str]] = []
    seen: set[str] = set()
    for line in text.splitlines():
        columns = [column.strip() for column in line.strip().strip("|").split("|")]
        if len(columns) != 4 or not re.fullmatch(
            rf"{re.escape(prefix)}-(?:[A-Z]\d{{2}}|\d{{2}})", columns[0]
        ):
            continue
        row_id, criterion, raw_points, state = columns
        require(row_id not in seen, f"{context} contains duplicate row {row_id}")
        require(raw_points.isdecimal(), f"{context} row {row_id} points must be an integer")
        seen.add(row_id)
        rows.append((row_id, criterion, int(raw_points), state))
    require(rows, f"{context} contains no credit rows")
    return tuple(rows)


def validate_metadata(
    text: str,
    *,
    context: str,
    version: str,
    cell: str,
    current: int,
    open_credit: int,
) -> None:
    expected = {
        "Status": "DRAFT_OWNER_APPROVAL_REQUIRED",
        "Version": version,
        "Zelle": cell,
        "Aktueller evidenzbasierter Credit": str(current),
        "Summe": "100",
        "Credit-Anwendung erlaubt": "false",
    }
    open_label = "Offener Hosted-OAuth-Credit" if cell == "phase_3" else "Offener Hosted-Scale-Credit"
    expected[open_label] = str(open_credit)
    for label, value in expected.items():
        require(
            metadata(text, label, context) == value,
            f"{context} metadata {label} must equal {value}",
        )
    require(current + open_credit == 100, f"{context} closed/open metadata must add to 100")


def validate_phase3(text: str) -> None:
    context = "phase3 rubric"
    validate_metadata(
        text,
        context=context,
        version="phase3-credit-rubric-draft-v1",
        cell="phase_3",
        current=44,
        open_credit=56,
    )
    rows = parse_credit_rows(text, "P3", context)
    require(rows == EXPECTED_PHASE3_ROWS, f"{context} row order, weights, or states drifted")
    require(sum(points for _, _, points, _ in rows) == 100, f"{context} row weights must add to 100")
    require(rows[0][2] == 44, f"{context} closed row weight must remain 44")
    require(sum(points for _, _, points, _ in rows[1:]) == 56, f"{context} open rows must add to 56")

    require_markers(
        text,
        (
            "Dieser Entwurf definiert nur eine entscheidbare Messlatte. Er aendert weder P3 `44` noch Overall `89`, ein Capability-Gate, `live_verified`, eine Hosted-Konfiguration oder eine Release-Aussage.",
            "P3=44`, `Overall=89`, `production_auth_identity` bleibt ungeschlossen, `MARKET_READY:false`, keine Production-Promotion und kein Secret-Output.",
            "Hosted OAuth-Start liefert die echte freigegebene `client_id`, exakt Scope `read:user` und einen kryptographischen One-Time-State",
            "Hosted Callback tauscht einen echten Code gegen die verifizierte numerische GitHub-Identitaet und stellt erst danach die Session bereit",
            "Die Owner-Allowlist bindet die numerische GitHub-Identitaet fail-closed; fremde oder fehlende Identity erhaelt keine Credentials",
            "OAuth-State-Cookie: `__Host-`, `Secure`, `HttpOnly`, `SameSite=Lax`, `Path=/`, kein `Domain`; Access-/Refresh-Cookies: `__Host-`, `Secure`, `HttpOnly`, `SameSite=Strict`, `Path=/`, kein `Domain`, freigegebene TTL",
            "Refresh rotiert atomar; Replay des alten Tokens liefert exakt HTTP `401`, widerruft die komplette Tokenfamilie und stellt keine neuen Credentials aus",
            "Logout widerruft nur einen aktiven registrierten Refresh-Token, loescht beide Auth-Cookies, persistiert den korrelierten Audit-Eintrag und Post-Logout-Refresh liefert `401`",
            "Callback-Replay und Wiederverwendung des OAuth-State werden fail-closed abgewiesen",
            "Die Auditkette ist Request-/Session-ID-korreliert, vor Credential-Ausgabe persistiert und enthaelt keine Codes, OAuth-State-Werte, Tokens, Cookie-Werte oder Secrets",
            "Reale Browserfolge: erster Start und Cancel/Deny ohne Credentials bei konsumiertem State; zweiter Start mit Owner-Authorize; Callback, `/auth/me`, Reload, Refresh, altes Refresh-Replay, Callback-Replay, Logout und Post-Logout-Refresh.",
            "`pwsh -NoProfile -File scripts/verify-production-auth-identity-evidence.ps1 -EvidencePath <TRACKED_JSON> -ExpectedCandidateSha <40_HEX_SHA> -ValidateOnly`.",
            "Der heutige Verifier validiert Envelope, Booleans und Source-Bindung; er berechnet keine P3-Punkte und recomputiert keine Rohartefakt-Hashes.",
            "`scripts/verify_phase3_credit_itemization.py`, der jede Rubrikzeile aus den gebundenen SHA-256-Rohbeweisen neu berechnet.",
            "Der A1-Replay hat aktuell keinen P3-Scorer freigeschaltet und muss jeden P3-Eintrag bis dahin ablehnen.",
            "Separater Owner-genehmigter Gate-Promoter; Evidence-Verifikation selbst bleibt nicht-mutierend.",
            "Authorize, Passwort, 2FA und CAPTCHA bleiben ausschliesslich Owner-Handlungen.",
        ),
        context,
    )


def parse_blocked_multiset(text: str) -> tuple[str, ...]:
    start_marker = "## Absichtliche Nichtziele"
    end_marker = "## Evidence- und Owner-Kette"
    require(start_marker in text and end_marker in text, "phase6 rubric missing blocked-list section")
    section = text.split(start_marker, 1)[1].split(end_marker, 1)[0]
    numbered = re.findall(r"^(\d+)\.\s+`([^`]+)`\s*$", section, flags=re.MULTILINE)
    require(
        [int(number) for number, _ in numbered] == list(range(1, 23)),
        "phase6 rubric blocked multiset must be numbered exactly 1 through 22",
    )
    return tuple(item for _, item in numbered)


def validate_phase6_request_math(text: str) -> None:
    flattened = compact(text)
    worker_match = re.search(
        r"Worker-Hardcap: exakt `(\d+)` Requests = `(\d+)` Reads \+ `(\d+)` Creates \+ `(\d+)` Deletes\.",
        flattened,
    )
    require(worker_match is not None, "phase6 rubric missing exact Worker request equation")
    worker, reads, creates, deletes = (int(value) for value in worker_match.groups())
    require(
        (worker, reads, creates, deletes) == (900, 800, 50, 50),
        "phase6 rubric Worker request equation must be 900=800+50+50",
    )
    require(worker == reads + creates + deletes, "phase6 rubric Worker request equation is inconsistent")

    control_match = re.search(
        r"Kontrolle umfasst exakt `(\d+)` Edge-Requests \(`4x1 \+ 4x10 \+ 4x50`\).*?Damit entstehen exakt `(1\.144)` ausgehende HTTP-Requests, davon `(\d+)` Worker-aufrufend und `(\d+)` reine Edge-Kontrollen\.",
        flattened,
    )
    require(control_match is not None, "phase6 rubric missing exact control/total request equation")
    control = int(control_match.group(1))
    total = int(control_match.group(2).replace(".", ""))
    worker_readback = int(control_match.group(3))
    control_readback = int(control_match.group(4))
    require(control == 244 == 4 * 1 + 4 * 10 + 4 * 50, "phase6 rubric control requests must equal 244")
    require(
        (total, worker_readback, control_readback) == (1144, 900, 244),
        "phase6 rubric outbound equation must be 1144=900+244",
    )
    require(total == worker + control, "phase6 rubric outbound request equation is inconsistent")


def validate_phase6(text: str) -> None:
    context = "phase6 rubric"
    validate_metadata(
        text,
        context=context,
        version="phase6-credit-rubric-draft-v1",
        cell="phase_6",
        current=90,
        open_credit=10,
    )
    rows = parse_credit_rows(text, "P6", context)
    require(rows == EXPECTED_PHASE6_ROWS, f"{context} row order, weights, or states drifted")
    baseline = sum(points for row_id, _, points, _ in rows if row_id.startswith("P6-B"))
    hosted = sum(points for row_id, _, points, _ in rows if row_id.startswith("P6-H"))
    require(baseline == 90, f"{context} baseline rows must add to 90")
    require(hosted == 10, f"{context} hosted rows must add to 10")
    require(baseline + hosted == 100, f"{context} rows must add to 100")
    require(
        tuple(points for row_id, _, points, _ in rows if row_id.startswith("P6-H")) == (3, 3, 2, 2),
        f"{context} hosted atomic weights must remain 3/3/2/2",
    )

    validate_phase6_request_math(text)
    blocked = parse_blocked_multiset(text)
    require(blocked == EXPECTED_BLOCKED_MULTSET, f"{context} ordered blocked multiset drifted")
    counts = Counter(blocked)
    require(
        counts["binary_asset_upload_blocked"] == 2
        and counts["server_authoritative_sync_blocked"] == 2,
        f"{context} required duplicate blocked entries drifted",
    )
    require(
        all(
            count == (2 if item in {"binary_asset_upload_blocked", "server_authoritative_sync_blocked"} else 1)
            for item, count in counts.items()
        ),
        f"{context} blocked multiset has an unexpected duplicate",
    )

    require_markers(
        text,
        (
            "Dieser Entwurf strukturiert den bestehenden P6-Stand und den einzigen offenen Block. Er aendert weder P6 `90` noch Overall `89`, das Gate `phase6_scale_runtime`, Hosted State, `live_verified` oder eine Release-Aussage.",
            "P6=90`, `Overall=89`, `phase6_scale_runtime` bleibt fuer Credit ungeschlossen, `MARKET_READY:false`, null Hosted Writes durch diesen Entwurf.",
            "Die vier Hosted-Zeilen `P6-H01` bis `P6-H04` sind Gewichtungsbestandteile eines einzigen atomaren Scale-Beweises. Schlaegt eine Zeile fehl, bleibt der gesamte offene Credit `0/10`.",
            "Vertrag: `phase6-scale-criterion-v2`; kanonischer SHA-256 `edeeac95fac6fefe1dcde5b77a5d8b236685f28adf66f357706aed26971ed85f`.",
            "Ziel: `https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev`.",
            "Zero-card only; Payment und Paid-Fallback sind verboten.",
            "Mindest-Erfolgsquote `0.99`, schlechtester p95 hoechstens `1500 ms`, eigene Worker-5xx exakt `0`.",
            "HTTP `429` ist nur in Read-Tiers beobachtbar und zaehlt nie als Erfolg; Create-/Delete- `429` macht den Lauf rot.",
            "Fehlende Authentisierung, Owner-Freigabe, Source-/Deployment-Paritaet oder expliziter Write-Schalter muss vor dem ersten HTTP-Aufruf mit null Requests abbrechen.",
            "das Criterion nennt die Edge-Kontrolle `not_a_pass_criterion`, waehrend der aktuelle Runtime-Verifier `edge_control_failure` in die passentscheidende Failure-Liste aufnimmt und der Evidence-Verifier eine leere Liste verlangt.",
            "Diese Semantik muss vor Aktivierung vereinheitlicht und Red-first abgesichert werden; der Entwurf entscheidet sie nicht.",
            "Read-only Evidence-Verifikation muss weiterhin `gate_may_open=false`, `gate_promotion_performed=false` und `percentage_credit_awarded=0` melden.",
            "das Secret `AGENT_API_AUTH_TOKEN` (nur sein Wert bleibt unausgegeben)",
            "`source_sha=<CURRENT_DEPLOYED_SOURCE_SHA>` sowie `allow_hosted_writes=true` genehmigt; der Workflow uebergibt daraus `-AllowHostedWrites`.",
            "Ausfuehrung nur per `workflow_dispatch`, exakter Execution-HEAD-/Source-Bindung und geschuetztem Environment `phase6-scale-hosted-writes`.",
            "Der A1-Replay hat aktuell keinen P6-Scorer freigeschaltet.",
        ),
        context,
    )


def load_json(repo_root: Path, relative_path: Path, context: str) -> dict[str, object]:
    path = repo_root / relative_path
    require(path.is_file(), f"missing {relative_path.as_posix()}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise RubricValidationError(f"unable to read {context}: {exc}") from exc
    require(isinstance(payload, dict), f"{context} root must be an object")
    return payload


def progress_cell(manifest: dict[str, object], section: str, cell_id: str) -> int:
    group = manifest.get(section)
    require(isinstance(group, dict), f"manifest {section} must be an object")
    items = group.get("items")
    require(isinstance(items, list), f"manifest {section}.items must be an array")
    matches = [item for item in items if isinstance(item, dict) and item.get("id") == cell_id]
    require(len(matches) == 1, f"manifest must contain exactly one {cell_id}")
    percent = matches[0].get("percent")
    require(type(percent) is int, f"manifest {cell_id} percent must be an integer")
    return percent


def validate_current_truth(repo_root: Path) -> None:
    manifest = load_json(repo_root, MANIFEST_PATH, "progress manifest")
    require(manifest.get("overall_percent") == 89, "rubric draft must not change overall percent")
    require(progress_cell(manifest, "horizontal", "phase_3") == 44, "rubric draft must not change P3")
    require(progress_cell(manifest, "horizontal", "phase_6") == 90, "rubric draft must not change P6")

    ledger = load_json(repo_root, LEDGER_PATH, "progress delta ledger")
    require(ledger.get("contract_version") == "project-progress-delta-ledger-v2", "delta ledger contract drifted")
    require(ledger.get("entries") == [], "rubric drafts must not add a progress delta")

    gates = load_json(repo_root, GATES_PATH, "capability gates")
    gate_map = gates.get("gates")
    require(isinstance(gate_map, dict), "capability gates.gates must be an object")
    for gate_id in ("production_auth_identity", "phase6_scale_runtime"):
        gate = gate_map.get(gate_id)
        require(isinstance(gate, dict), f"missing capability gate {gate_id}")
        require(gate.get("owner_granted") is False, f"rubric draft must not grant {gate_id}")
        require(gate.get("live_verified") is False, f"rubric draft must not verify {gate_id}")

    snapshot = load_json(repo_root, ENDPOINT_SNAPSHOT_PATH, "endpoint snapshot")
    require(
        snapshot.get("/api/v1/project/progress") == manifest,
        "endpoint snapshot progress mirror differs from manifest",
    )

    platform_path = repo_root / PLATFORM_PATH
    require(platform_path.is_file(), f"missing {PLATFORM_PATH.as_posix()}")
    try:
        platform_text = platform_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise RubricValidationError(f"unable to read platform progress mirror: {exc}") from exc
    block = re.search(r"export const MANIFEST\s*=\s*\{(?P<body>.*?)\}\s*as const;", platform_text, re.DOTALL)
    require(block is not None, "platform.ts missing MANIFEST mirror")
    body = block.group("body")
    require(re.search(r"\boverall:\s*89\b", body) is not None, "platform mirror overall must remain 89")
    require(re.search(r'\{\s*id:\s*"P3"\s*,\s*pct:\s*44\s*\}', body) is not None, "platform mirror P3 must remain 44")
    require(re.search(r'\{\s*id:\s*"P6"\s*,\s*pct:\s*90\s*\}', body) is not None, "platform mirror P6 must remain 90")

    criterion_path = repo_root / PHASE6_CRITERION_PATH
    require(criterion_path.is_file(), f"missing {PHASE6_CRITERION_PATH.as_posix()}")
    try:
        criterion_bytes = criterion_path.read_bytes()
        criterion = json.loads(criterion_bytes.decode("utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise RubricValidationError(f"unable to read Phase-6 criterion: {exc}") from exc
    require(
        hashlib.sha256(criterion_bytes).hexdigest() == PHASE6_CRITERION_SHA256,
        "Phase-6 criterion bytes differ from the canonical SHA-256",
    )
    require(isinstance(criterion, dict), "Phase-6 criterion root must be an object")
    require(criterion.get("contract_version") == "phase6-scale-criterion-v2", "Phase-6 criterion version drifted")
    require(
        isinstance(criterion.get("target"), dict)
        and criterion["target"].get("base_url") == "https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev",
        "Phase-6 criterion target drifted",
    )
    envelope = criterion.get("envelope")
    require(isinstance(envelope, dict), "Phase-6 criterion envelope must be an object")
    require(envelope.get("zero_card") is True, "Phase-6 criterion must remain zero-card")
    require(envelope.get("payment_forbidden") is True, "Phase-6 criterion must forbid payment")
    require(envelope.get("paid_fallback_forbidden") is True, "Phase-6 criterion must forbid paid fallback")
    require(envelope.get("max_total_requests") == 900, "Phase-6 Worker request cap must remain 900")
    require(
        criterion.get("read_tiers")
        == [
            {"concurrency": 1, "requests": 60},
            {"concurrency": 10, "requests": 240},
            {"concurrency": 50, "requests": 500},
        ],
        "Phase-6 read tiers drifted",
    )
    write_tier = criterion.get("write_tier")
    require(isinstance(write_tier, dict), "Phase-6 write tier must be an object")
    for key, expected in {
        "required": True,
        "auth_env_name": "AGENT_API_AUTH_TOKEN",
        "concurrency": 10,
        "records": 50,
        "readback_required": True,
        "no_loss_allowed": True,
        "no_duplicate_allowed": True,
        "http_429_allowed": False,
        "cleanup_semantics": "soft_delete_then_active_row_absence_and_audit_readback",
    }.items():
        require(write_tier.get(key) == expected, f"Phase-6 write tier {key} drifted")
    criteria = criterion.get("pass_criteria")
    require(isinstance(criteria, dict), "Phase-6 pass criteria must be an object")
    require(criteria.get("min_success_ratio") == 0.99, "Phase-6 success ratio drifted")
    require(criteria.get("max_p95_ms") == 1500, "Phase-6 p95 limit drifted")
    require(criteria.get("own_5xx_allowed") == 0, "Phase-6 5xx allowance drifted")


def validate_rubrics(repo_root: Path = ROOT) -> dict[str, int | bool]:
    phase3_file = repo_root / PHASE3_PATH
    phase6_file = repo_root / PHASE6_PATH
    require(phase3_file.is_file(), f"missing {PHASE3_PATH.as_posix()}")
    require(phase6_file.is_file(), f"missing {PHASE6_PATH.as_posix()}")
    try:
        phase3_text = visible_markdown(phase3_file.read_text(encoding="utf-8"))
        phase6_text = visible_markdown(phase6_file.read_text(encoding="utf-8"))
    except (OSError, UnicodeError) as exc:
        raise RubricValidationError(f"unable to read draft rubric: {exc}") from exc

    validate_phase3(phase3_text)
    validate_phase6(phase6_text)
    validate_current_truth(repo_root)
    return {
        "phase3_current": 44,
        "phase3_open": 56,
        "phase6_current": 90,
        "phase6_open": 10,
        "read_only": True,
        "credit_applied": False,
    }


def main() -> int:
    try:
        result = validate_rubrics()
    except RubricValidationError as exc:
        print(f"[credit-rubrics] FAIL {exc}", file=sys.stderr)
        return 1
    print(
        "[credit-rubrics] PASS "
        f"P3={result['phase3_current']}+{result['phase3_open']}=100 "
        f"P6={result['phase6_current']}+{result['phase6_open']}=100 "
        "requests=900+244=1144 blocked=22 "
        "read_only=true credit_applied=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
