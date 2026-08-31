from __future__ import annotations

import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts import verify_credit_rubric_drafts as verifier


REPO_ROOT = Path(__file__).resolve().parents[2]
ORIGINAL_IO_OPEN = io.open
ORIGINAL_OS_OPEN = os.open
TRUTH_PATHS = (
    verifier.MANIFEST_PATH,
    verifier.GATES_PATH,
    verifier.LEDGER_PATH,
    verifier.ENDPOINT_SNAPSHOT_PATH,
    verifier.PLATFORM_PATH,
    verifier.PHASE6_CRITERION_PATH,
)


class CreditRubricDraftTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.phase3 = (REPO_ROOT / verifier.PHASE3_PATH).read_text(encoding="utf-8")
        cls.phase6 = (REPO_ROOT / verifier.PHASE6_PATH).read_text(encoding="utf-8")

    def validate(
        self,
        *,
        phase3: str | None = None,
        phase6: str | None = None,
        truth_overrides: dict[Path, str] | None = None,
        guard_writes: bool = False,
    ) -> dict[str, int | bool]:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            contracts = root / "docs/runtime-contracts"
            contracts.mkdir(parents=True)
            (contracts / "phase3-credit-rubric.md").write_text(
                self.phase3 if phase3 is None else phase3,
                encoding="utf-8",
            )
            (contracts / "phase6-credit-rubric.md").write_text(
                self.phase6 if phase6 is None else phase6,
                encoding="utf-8",
            )
            for relative_path in TRUTH_PATHS:
                target = root / relative_path
                target.parent.mkdir(parents=True, exist_ok=True)
                override = (truth_overrides or {}).get(relative_path)
                if override is None:
                    target.write_bytes((REPO_ROOT / relative_path).read_bytes())
                else:
                    target.write_text(override, encoding="utf-8")

            if not guard_writes:
                return verifier.validate_rubrics(root)

            def guarded_io_open(file: object, mode: str = "r", *args: object, **kwargs: object):
                if any(flag in mode for flag in ("w", "a", "x", "+")):
                    raise AssertionError("verifier attempted an io write")
                return ORIGINAL_IO_OPEN(file, mode, *args, **kwargs)

            def guarded_os_open(path: object, flags: int, *args: object, **kwargs: object):
                write_flags = os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC | os.O_APPEND
                if flags & write_flags:
                    raise AssertionError("verifier attempted an os write")
                return ORIGINAL_OS_OPEN(path, flags, *args, **kwargs)

            with (
                patch("io.open", side_effect=guarded_io_open),
                patch("os.open", side_effect=guarded_os_open),
                patch("subprocess.run", side_effect=AssertionError("verifier attempted a subprocess")),
                patch("subprocess.Popen", side_effect=AssertionError("verifier attempted a subprocess")),
            ):
                return verifier.validate_rubrics(root)

    def assert_rejected(self, *, phase3: str | None = None, phase6: str | None = None) -> None:
        with self.assertRaises(verifier.RubricValidationError):
            self.validate(phase3=phase3, phase6=phase6)

    @staticmethod
    def mutate(text: str, old: str, new: str, count: int = 1) -> str:
        changed = text.replace(old, new, count)
        if changed == text:
            raise AssertionError(f"test mutation marker not found: {old}")
        return changed

    def test_current_approved_rubrics_pass_without_writes_or_credit(self) -> None:
        result = self.validate(guard_writes=True)
        self.assertEqual(
            result,
            {
                "phase3_current": 44,
                "phase3_open": 56,
                "phase6_current": 90,
                "phase6_open": 10,
                "rubrics_approved": True,
                "read_only": True,
                "credit_applied": False,
            },
        )

    def test_phase3_requires_approved_status_without_automatic_credit_and_current_math(self) -> None:
        mutations = (
            ("`APPROVED`", "`DRAFT_OWNER_APPROVAL_REQUIRED`"),
            ("Credit-Anwendung erlaubt: `true`", "Credit-Anwendung erlaubt: `false`"),
            ("Owner-Freigabe-Ref: `CODEX_UEBERGABE_MASTER_2026-08-29.md :: B1 Owner-Freigabe 2026-08-31 (Owner strazzusochr, an Claude delegiert)`", "Owner-Freigabe-Ref: `invalid`") ,
            ("Aktueller evidenzbasierter Credit: `44`", "Aktueller evidenzbasierter Credit: `45`"),
            ("Offener Hosted-OAuth-Credit: `56`", "Offener Hosted-OAuth-Credit: `55`"),
            ("| P3-02 | Hosted Callback", "| P3-02 | Hosted Callback"),
        )
        for old, new in mutations[:-1]:
            with self.subTest(old=old):
                self.assert_rejected(phase3=self.mutate(self.phase3, old, new))
        self.assert_rejected(
            phase3=self.mutate(
                self.phase3,
                "| P3-02 | Hosted Callback tauscht einen echten Code gegen die verifizierte numerische GitHub-Identitaet und stellt erst danach die Session bereit | 12 | offen |",
                "| P3-02 | Hosted Callback tauscht einen echten Code gegen die verifizierte numerische GitHub-Identitaet und stellt erst danach die Session bereit | 11 | offen |",
            )
        )
        self.assert_rejected(phase3=self.phase3 + "\nCredit-Anwendung erlaubt: `false`\n")

    def test_phase3_pins_oauth_session_replay_logout_and_audit_semantics(self) -> None:
        mutations = (
            ("exakt Scope `read:user`", "Scope `read:user user:email`"),
            ("stellt erst danach die Session bereit", "stellt vorher die Session bereit"),
            ("`SameSite=Lax`", "`SameSite=None`"),
            ("widerruft die komplette Tokenfamilie", "widerruft nur das alte Token"),
            ("nur einen aktiven registrierten Refresh-Token", "alle Refresh-Token"),
            ("Post-Logout-Refresh liefert `401`", "Post-Logout-Refresh liefert `200`"),
            ("OAuth-State-Werte, Tokens, Cookie-Werte oder Secrets", "Tokens oder Secrets"),
        )
        for old, new in mutations:
            with self.subTest(old=old):
                self.assert_rejected(phase3=self.mutate(self.phase3, old, new))

    def test_phase3_pins_human_flow_and_current_vs_future_verifiers(self) -> None:
        mutations = (
            ("erster Start und Cancel/Deny", "erster Start ohne Cancel/Deny"),
            ("-ExpectedCandidateSha <40_HEX_SHA> -ValidateOnly", "-ValidateOnly"),
            ("er berechnet keine\n   P3-Punkte", "er berechnet\n   P3-Punkte"),
            ("scripts/verify_phase3_credit_itemization.py", "scripts/verify_phase5_credit_itemization.py"),
            ("SHA-256-Rohbeweisen neu berechnet", "Envelope-Selbstclaims uebernimmt"),
            ("keinen\n   P3-Scorer freigeschaltet", "einen\n   P3-Scorer freigeschaltet"),
        )
        for old, new in mutations:
            with self.subTest(old=old):
                self.assert_rejected(phase3=self.mutate(self.phase3, old, new))

    def test_phase6_requires_approved_status_without_automatic_credit_and_exact_weights(self) -> None:
        mutations = (
            ("`APPROVED`", "`DRAFT_OWNER_APPROVAL_REQUIRED`"),
            ("Credit-Anwendung erlaubt: `true`", "Credit-Anwendung erlaubt: `false`"),
            ("Owner-Freigabe-Ref: `CODEX_UEBERGABE_MASTER_2026-08-29.md :: B1 Owner-Freigabe 2026-08-31 (Owner strazzusochr, an Claude delegiert)`", "Owner-Freigabe-Ref: `invalid`") ,
            ("Aktueller evidenzbasierter Credit: `90`", "Aktueller evidenzbasierter Credit: `91`"),
            ("Offener Hosted-Scale-Credit: `10`", "Offener Hosted-Scale-Credit: `9`"),
            ("| P6-H01 | Exakt 800 Hosted Reads in drei Stufen (`60@1`, `240@10`, `500@50`) | 3 | offen |", "| P6-H01 | Exakt 800 Hosted Reads in drei Stufen (`60@1`, `240@10`, `500@50`) | 4 | offen |"),
        )
        for old, new in mutations:
            with self.subTest(old=old):
                self.assert_rejected(phase6=self.mutate(self.phase6, old, new))
        self.assert_rejected(phase6=self.phase6 + "\nCredit-Anwendung erlaubt: `false`\n")

    def test_phase6_pins_worker_control_and_total_request_math(self) -> None:
        mutations = (
            ("exakt `900` Requests", "exakt `901` Requests"),
            ("`800` Reads + `50` Creates + `50` Deletes", "`801` Reads + `50` Creates + `50` Deletes"),
            ("exakt `244` Edge-Requests", "exakt `243` Edge-Requests"),
            ("exakt `1.144`\n  ausgehende HTTP-Requests", "exakt `1.145`\n  ausgehende HTTP-Requests"),
        )
        for old, new in mutations:
            with self.subTest(old=old):
                self.assert_rejected(phase6=self.mutate(self.phase6, old, new))
        self.assert_rejected(
            phase6=self.mutate(self.phase6, "exakt `1.144`", "exakt `11.44`")
        )

    def test_phase6_pins_decisive_hosted_criterion_semantics(self) -> None:
        mutations = (
            ("edeeac95fac6fefe1dcde5b77a5d8b236685f28adf66f357706aed26971ed85f", "0" * 64),
            ("https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev", "https://example.invalid"),
            ("Zero-card only; Payment und Paid-Fallback sind verboten.", "Payment und Paid-Fallback sind erlaubt."),
            ("Mindest-Erfolgsquote `0.99`", "Mindest-Erfolgsquote `0.50`"),
            ("hoechstens `1500 ms`", "hoechstens `99999 ms`"),
            ("eigene Worker-5xx\n  exakt `0`", "eigene Worker-5xx\n  exakt `100`"),
            ("Exakt 800 Hosted Reads", "Exakt 700 Hosted Reads"),
            ("Exakt 50 authentisierte D1-Creates", "Exakt 49 authentisierte D1-Creates"),
            ("und vollstaendigem Cleanup", "und delete_attempt_only"),
        )
        for old, new in mutations:
            with self.subTest(old=old):
                self.assert_rejected(phase6=self.mutate(self.phase6, old, new))

    def test_phase6_pins_control_runtime_contradiction(self) -> None:
        mutations = (
            ("`not_a_pass_criterion`", "`pass_criterion`"),
            ("`edge_control_failure` in die passentscheidende Failure-Liste", "`edge_control_failure` in eine rein informative Liste"),
            ("eine leere Liste verlangt", "die Liste ignoriert"),
            ("vor Aktivierung\n  vereinheitlicht und Red-first abgesichert", "nach Aktivierung\n  optional vereinheitlicht"),
        )
        for old, new in mutations:
            with self.subTest(old=old):
                self.assert_rejected(phase6=self.mutate(self.phase6, old, new))

    def test_phase6_pins_secret_and_exact_dispatch_inputs(self) -> None:
        mutations = (
            ("`AGENT_API_AUTH_TOKEN`", "`AGENT_API_TOKEN`"),
            ("nur sein\n   Wert bleibt unausgegeben", "sein\n   Wert wird protokolliert"),
            ("source_sha=<CURRENT_DEPLOYED_SOURCE_SHA>", "source_sha=<BRANCH_HEAD_SHA>"),
            ("allow_hosted_writes=true", "allow_hosted_writes=false"),
            ("`workflow_dispatch`", "`push`"),
        )
        for old, new in mutations:
            with self.subTest(old=old):
                self.assert_rejected(phase6=self.mutate(self.phase6, old, new))

    def test_phase6_pins_all_22_blocked_entries_in_order(self) -> None:
        removed = self.mutate(self.phase6, "22. `phase6_capacity_claim_blocked`\n", "")
        self.assert_rejected(phase6=removed)

        swapped = self.phase6.replace(
            "1. `binary_asset_upload_blocked`",
            "1. `benchmark_claim_blocked`",
            1,
        ).replace(
            "2. `benchmark_claim_blocked`",
            "2. `binary_asset_upload_blocked`",
            1,
        )
        self.assertNotEqual(swapped, self.phase6)
        self.assert_rejected(phase6=swapped)

    def test_phase6_preserves_both_deliberate_duplicates(self) -> None:
        mutations = (
            ("8. `binary_asset_upload_blocked`", "8. `binary_asset_upload_v2_blocked`"),
            ("20. `server_authoritative_sync_blocked`", "20. `server_snapshot_sync_blocked`"),
        )
        for old, new in mutations:
            with self.subTest(old=old):
                self.assert_rejected(phase6=self.mutate(self.phase6, old, new))

    def test_hidden_comment_or_decoy_table_cannot_satisfy_visible_contract(self) -> None:
        hidden_phase3 = self.phase3.replace(
            "| P3-02 | Hosted Callback tauscht einen echten Code gegen die verifizierte numerische GitHub-Identitaet und stellt erst danach die Session bereit | 12 | offen |",
            "<!-- | P3-02 | Hosted Callback tauscht einen echten Code gegen die verifizierte numerische GitHub-Identitaet und stellt erst danach die Session bereit | 12 | offen | -->\n"
            "| P3-02 | Hosted Callback kann eine beliebige Identitaet akzeptieren | 12 | offen |",
        )
        self.assert_rejected(phase3=hidden_phase3)

        hidden_phase6 = self.phase6.replace(
            "| P6-H02 | Exakt 50 authentisierte D1-Creates bei Concurrency `10`, ohne Verlust/Duplikat und mit vollstaendigem Readback | 3 | offen |",
            "<!-- | P6-H02 | Exakt 50 authentisierte D1-Creates bei Concurrency `10`, ohne Verlust/Duplikat und mit vollstaendigem Readback | 3 | offen | -->\n"
            "| P6-H02 | Ein einzelner unauthentisierter Create ohne Readback | 3 | offen |",
        )
        self.assert_rejected(phase6=hidden_phase6)

    def test_current_progress_gates_ledger_mirrors_and_criterion_remain_bound(self) -> None:
        manifest = (REPO_ROOT / verifier.MANIFEST_PATH).read_text(encoding="utf-8")
        gates = (REPO_ROOT / verifier.GATES_PATH).read_text(encoding="utf-8")
        ledger = (REPO_ROOT / verifier.LEDGER_PATH).read_text(encoding="utf-8")
        snapshot = (REPO_ROOT / verifier.ENDPOINT_SNAPSHOT_PATH).read_text(encoding="utf-8")
        platform = (REPO_ROOT / verifier.PLATFORM_PATH).read_text(encoding="utf-8")
        criterion = (REPO_ROOT / verifier.PHASE6_CRITERION_PATH).read_text(encoding="utf-8")

        def changed_gate(gate_id: str, field: str, value: bool) -> str:
            payload = json.loads(gates)
            payload["gates"][gate_id][field] = value
            return json.dumps(payload)

        def changed_snapshot_overall() -> str:
            payload = json.loads(snapshot)
            payload["/api/v1/project/progress"]["overall_percent"] = 90
            return json.dumps(payload)

        cases = (
            {verifier.MANIFEST_PATH: self.mutate(manifest, '"overall_percent": 89', '"overall_percent": 90')},
            {verifier.MANIFEST_PATH: self.mutate(manifest, '"id": "phase_3",\n        "label": "Phase 3 - Product Surface & Security",\n        "percent": 44', '"id": "phase_3",\n        "label": "Phase 3 - Product Surface & Security",\n        "percent": 45')},
            {verifier.MANIFEST_PATH: self.mutate(manifest, '"id": "phase_6",\n        "label": "Phase 6 - Scale & 3D Platform",\n        "percent": 90', '"id": "phase_6",\n        "label": "Phase 6 - Scale & 3D Platform",\n        "percent": 100')},
            {verifier.GATES_PATH: changed_gate("production_auth_identity", "owner_granted", True)},
            {verifier.GATES_PATH: changed_gate("phase6_scale_runtime", "owner_granted", True)},
            {verifier.GATES_PATH: changed_gate("phase6_scale_runtime", "live_verified", True)},
            {verifier.LEDGER_PATH: self.mutate(ledger, '"entries": []', '"entries": [{}]')},
            {verifier.ENDPOINT_SNAPSHOT_PATH: changed_snapshot_overall()},
            {verifier.PLATFORM_PATH: self.mutate(platform, 'overall: 89', 'overall: 90')},
            {verifier.PHASE6_CRITERION_PATH: self.mutate(criterion, '"max_p95_ms": 1500', '"max_p95_ms": 99999')},
        )
        for overrides in cases:
            with self.subTest(path=next(iter(overrides))):
                with self.assertRaises(verifier.RubricValidationError):
                    self.validate(truth_overrides=overrides)


if __name__ == "__main__":
    unittest.main()
