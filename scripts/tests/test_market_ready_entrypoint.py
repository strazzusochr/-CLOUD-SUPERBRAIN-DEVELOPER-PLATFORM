from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import textwrap
import unittest
import uuid
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


class MarketReadyEntrypointTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        npm = shutil.which("npm")
        if npm is None:
            raise unittest.SkipTest("npm is unavailable")
        completed = subprocess.run(
            [npm, "pkg", "get", "scripts"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        cls.scripts = json.loads(completed.stdout)
        cls.pwsh = shutil.which("pwsh")
        if cls.pwsh is None:
            raise unittest.SkipTest("pwsh is unavailable")

    def test_plain_market_ready_runs_the_external_gate_audit(self) -> None:
        command = self.scripts["verify:market-ready"]
        self.assertIn(" -IncludeExternalGates", command)
        self.assertNotIn(" -RequireReady", command)

    def test_static_audit_stays_offline_and_require_ready_stays_fail_closed(self) -> None:
        static_command = self.scripts["verify:market-ready:static"]
        require_ready_command = self.scripts["verify:market-ready:require-ready"]
        self.assertNotIn(" -IncludeExternalGates", static_command)
        self.assertIn(" -IncludeExternalGates", require_ready_command)
        self.assertIn(" -RequireReady", require_ready_command)

        source = (REPO_ROOT / "scripts" / "verify-market-ready.ps1").read_text(encoding="utf-8")
        self.assertIn("$readyTruthFilesClean = $false\n$readyTrackedWorktreeClean = $false", source)

    def test_market_ready_python_launcher_is_cross_platform_and_fail_closed(self) -> None:
        source = (REPO_ROOT / "scripts" / "verify-market-ready.ps1").read_text(encoding="utf-8")
        self.assertLess(source.index('@{ Name = "py"'), source.index('@{ Name = "python3"'))
        self.assertLess(source.index('@{ Name = "python3"'), source.index('@{ Name = "python"'))
        self.assertIn('$registryExit = 127', source)
        self.assertIn('$bindingExit = 127', source)
        self.assertNotIn('& py -3', source)

    def _invoke_current_owner_blocked_helper(self, helper: str, payload: dict) -> dict:
        script_source = (REPO_ROOT / "scripts" / "verify-market-ready.ps1").read_text(
            encoding="utf-8"
        )
        preamble = script_source.split(
            'Write-Host "=== MARKET-READY AGGREGATE GATE ==="', 1
        )[0]
        with tempfile.TemporaryDirectory(prefix="market-ready-owner-blocked-") as tmp:
            payload_path = Path(tmp) / "payload.json"
            self._write_json(payload_path, payload)
            wrapper = REPO_ROOT / "scripts" / f"owner-blocked-helper-{uuid.uuid4().hex}.ps1"
            try:
                wrapper.write_text(
                    preamble
                    + textwrap.dedent(
                        f"""
                        $payload = Get-Content -LiteralPath $env:MARKET_READY_TEST_PAYLOAD -Raw | ConvertFrom-Json
                        $result = {helper}
                        $result | ConvertTo-Json -Depth 12 -Compress
                        """
                    ),
                    encoding="utf-8",
                )
                env = os.environ.copy()
                env["MARKET_READY_TEST_PAYLOAD"] = str(payload_path)
                completed = subprocess.run(
                    [self.pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(wrapper)],
                    cwd=REPO_ROOT,
                    check=False,
                    capture_output=True,
                    text=True,
                    env=env,
                )
            finally:
                wrapper.unlink(missing_ok=True)
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        return json.loads(completed.stdout.strip().splitlines()[-1])

    def test_current_owner_blocked_historical_gates_are_valid_without_rc62_rebinding(self) -> None:
        capability = json.loads(
            (REPO_ROOT / "docs" / "runtime-state" / "capability-gates.json").read_text(
                encoding="utf-8-sig"
            )
        )
        result = self._invoke_current_owner_blocked_helper(
            "Get-OwnerBlockedFinalGateValidation $payload", capability
        )
        self.assertIs(result["ok"], True, result["detail"])
        self.assertIn("auth_pending", result["detail"])
        self.assertIn("registry_historical_verified", result["detail"])
        self.assertIn("phase6_historical_verified", result["detail"])

        cases = (
            (
                "production auth incorrectly live",
                lambda p: p["gates"]["production_auth_identity"].update(live_verified=True),
                "production_auth_identity_must_remain_pending",
            ),
            (
                "registry evidence hash",
                lambda p: p["gates"]["docker_registry_publish"].update(evidence_sha256="0" * 64),
                "docker_registry_publish",
            ),
            (
                "phase6 evidence hash",
                lambda p: p["gates"]["phase6_scale_runtime"].update(evidence_sha256="0" * 64),
                "phase6_scale_runtime",
            ),
            (
                "phase6 capability no longer verified",
                lambda p: p["gates"]["phase6_scale_runtime"].update(live_verified=False),
                "phase6_scale_runtime",
            ),
        )
        for name, mutate, expected_detail in cases:
            with self.subTest(name=name):
                forged = json.loads(json.dumps(capability))
                mutate(forged)
                result = self._invoke_current_owner_blocked_helper(
                    "Get-OwnerBlockedFinalGateValidation $payload", forged
                )
                self.assertIs(result["ok"], False, name)
                self.assertIn(expected_detail, result["detail"])

    def test_owner_blocked_action_map_requires_o2_resolved(self) -> None:
        owner = json.loads(
            (REPO_ROOT / "docs" / "runtime-state" / "owner-input-manifest.json").read_text(
                encoding="utf-8-sig"
            )
        )
        payload = {"actions": owner["actions"]}
        helper = "Get-OwnerBlockedActionMapValidation @($payload.actions) $true"
        result = self._invoke_current_owner_blocked_helper(helper, payload)
        self.assertIs(result["ok"], True, result["detail"])

        stale = json.loads(json.dumps(payload))
        next(action for action in stale["actions"] if action["id"] == "O2")["status"] = "owner_required"
        result = self._invoke_current_owner_blocked_helper(helper, stale)
        self.assertIs(result["ok"], False)
        self.assertIn("O2_status", result["detail"])

        wrong_cells = json.loads(json.dumps(payload))
        next(action for action in wrong_cells["actions"] if action["id"] == "O2")["affected_cells"] = ["phase_5"]
        result = self._invoke_current_owner_blocked_helper(helper, wrong_cells)
        self.assertIs(result["ok"], False)
        self.assertIn("O2_affected_cells", result["detail"])

    def _external_truth_fixture(self, **claim_overrides: bool) -> dict:
        gate_claims = (
            ("hosted_agent_api_contracts", "hosted_staging_claim_allowed"),
            ("github_branch_protection_current_verify", "branch_protection_claim_allowed"),
            ("ghcr_image_digest_verify", "ghcr_image_digest_claim_allowed"),
            ("vercel_backend_origin_health", "vercel_backend_origins_claim_allowed"),
            ("canonical_gitleaks_scan", "canonical_gitleaks_claim_allowed"),
            (
                "cloudflare_native_zero_card_hosted_runtime",
                "cloudflare_native_zero_card_hosted_runtime_claim_allowed",
            ),
        )
        claims = {
            "frontend_preview_claim_allowed": True,
            "hosted_staging_claim_allowed": True,
            "branch_protection_claim_allowed": True,
            "ghcr_image_digest_claim_allowed": True,
            "vercel_backend_origins_claim_allowed": True,
            "canonical_gitleaks_claim_allowed": True,
            "cloudflare_native_zero_card_hosted_runtime_claim_allowed": True,
        }
        claims.update(claim_overrides)
        missing = [gate_id for gate_id, claim in gate_claims if not claims[claim]]
        target = missing[0] if missing else ""
        status = "blocked" if missing else "verified"
        production = not missing
        shared = {
            **claims,
            "generated_at_utc": "2026-09-12T12:00:00Z",
            "requested_release_candidate_selector": "a" * 40,
            "active_release_candidate_sha": "",
            "ghcr_published_manifest_ref": "",
            "status": status,
            "active_target_gate": target,
            "missing_or_failed_gates": missing,
            "production_deploy_claim_allowed": production,
            "failed_hosted_required_probe_ids": [],
            "failed_vercel_origin_probe_ids": [],
        }
        summary = {
            "contract_version": "external-gate-summary-v2",
            "source_contract_version": "external-gate-audit-v2",
            "gate_ids": [gate_id for gate_id, _ in gate_claims],
            **shared,
        }
        audit = {"contract_version": "external-gate-audit-v2", **shared}
        owner = {
            "status": status,
            "active_target_gate": target,
            "missing_or_failed_gates": list(missing),
            "production_deploy_claim_allowed": production,
        }
        return {"summary": summary, "audit": audit, "owner": owner}

    def _assert_external_truth(self, payload: dict, expected_ok: bool, detail: str = "") -> None:
        helper = "Get-ExternalGateTruthValidation $payload.summary $payload.audit $payload.owner"
        result = self._invoke_current_owner_blocked_helper(helper, payload)
        self.assertIs(result["ok"], expected_ok, result["detail"])
        if detail:
            self.assertIn(detail, result["detail"])

    def test_external_truth_accepts_three_missing_gates_and_later_partial_progress(self) -> None:
        three_missing = self._external_truth_fixture(
            hosted_staging_claim_allowed=False,
            ghcr_image_digest_claim_allowed=False,
            vercel_backend_origins_claim_allowed=False,
        )
        self._assert_external_truth(three_missing, True)
        result = self._invoke_current_owner_blocked_helper(
            "Get-ExternalGateTruthValidation $payload.summary $payload.audit $payload.owner",
            three_missing,
        )
        self.assertIn(
            "missing=hosted_agent_api_contracts,ghcr_image_digest_verify,vercel_backend_origin_health",
            result["detail"],
        )

        later_partial = self._external_truth_fixture(ghcr_image_digest_claim_allowed=False)
        self._assert_external_truth(later_partial, True)
        result = self._invoke_current_owner_blocked_helper(
            "Get-ExternalGateTruthValidation $payload.summary $payload.audit $payload.owner",
            later_partial,
        )
        self.assertIn("target=ghcr_image_digest_verify", result["detail"])

    def test_external_truth_rejects_order_target_claim_and_green_gate_regressions(self) -> None:
        base = self._external_truth_fixture(
            hosted_staging_claim_allowed=False,
            ghcr_image_digest_claim_allowed=False,
            vercel_backend_origins_claim_allowed=False,
        )
        cases = []

        wrong_order = json.loads(json.dumps(base))
        wrong_order["summary"]["missing_or_failed_gates"] = [
            "ghcr_image_digest_verify",
            "hosted_agent_api_contracts",
            "vercel_backend_origin_health",
        ]
        cases.append(("missing order", wrong_order, "summary_missing_order"))

        wrong_target = json.loads(json.dumps(base))
        wrong_target["summary"]["active_target_gate"] = "ghcr_image_digest_verify"
        cases.append(("active target", wrong_target, "summary_active_target"))

        claim_contradiction = json.loads(json.dumps(base))
        claim_contradiction["summary"]["ghcr_image_digest_claim_allowed"] = True
        claim_contradiction["audit"]["ghcr_image_digest_claim_allowed"] = True
        cases.append(("claim contradiction", claim_contradiction, "summary_missing_order"))

        green_regression = self._external_truth_fixture(
            branch_protection_claim_allowed=False,
            ghcr_image_digest_claim_allowed=False,
        )
        cases.append(
            (
                "green branch protection regression",
                green_regression,
                "green_gate_regression_branch_protection_claim_allowed",
            )
        )

        for name, payload, expected_detail in cases:
            with self.subTest(name=name):
                self._assert_external_truth(payload, False, expected_detail)

    def test_ready_mode_keeps_current_candidate_and_hosted_acceptance_guards(self) -> None:
        source = (REPO_ROOT / "scripts" / "verify-market-ready.ps1").read_text(
            encoding="utf-8"
        )
        ready = source.split('$truthMode = "ready"', 1)[1]
        self.assertIn(
            'Get-ReadyGateEvidenceValidation $capabilityState.gates.docker_registry_publish "docker_registry_publish" $candidateSha $activeReleaseId',
            ready,
        )
        self.assertIn(
            'Get-ReadyGateEvidenceValidation $capabilityState.gates.phase6_scale_runtime "phase6_scale_runtime" $candidateSha $activeReleaseId',
            ready,
        )
        self.assertIn("$hostedAcceptanceOk -and", ready)
        self.assertNotIn("-HistoricalOfflinePhase6", ready)

    def test_production_auth_gate_has_a_real_verifier_availability_transition(self) -> None:
        source = (REPO_ROOT / "scripts" / "verify-market-ready.ps1").read_text(
            encoding="utf-8"
        )
        arm = source.split('"production_auth_identity" {', 1)[1].split(
            '"docker_registry_publish" {', 1
        )[0]
        markers = (
            '$authVerifierRelative = "scripts/verify-production-auth-identity-evidence.ps1"',
            "Resolve-RepoScopedFile $authVerifierRelative",
            "Test-TrackedCleanRepoFile $authVerifierRelative",
            "-EvidencePath $relativeEvidence",
            "-ExpectedCandidateSha $ExpectedCandidateSha",
            "-ValidateOnly",
            "auth_dedicated_non_mutating_verifier_failed",
            "validation_mode=true read_only=true gate_promotion_performed=false secret_output=false",
            "oauth_scope_exact_read_user_verified",
            "oauth_state_one_time_verified",
            "callback_replay_rejected_verified",
            "refresh_family_replay_rejected_verified",
            "audit_before_credential_verified",
        )
        for marker in markers:
            with self.subTest(marker=marker):
                self.assertIn(marker, arm)

        guard = "if ([string]$Gate.verifier -ne $authVerifierRelative -or"
        unavailable = '$failures.Add("auth_dedicated_non_mutating_verifier_unavailable")'
        self.assertEqual(arm.count(unavailable), 1)
        self.assertLess(arm.index(guard), arm.index(unavailable))

    def test_production_auth_evidence_verifier_is_read_only_and_fail_closed(self) -> None:
        source = (
            REPO_ROOT / "scripts" / "verify-production-auth-identity-evidence.ps1"
        ).read_text(encoding="utf-8")
        for marker in (
            "production-auth-identity-proof-v2",
            "oauth_scope_exact_read_user_verified",
            "oauth_state_one_time_verified",
            "callback_replay_rejected_verified",
            "refresh_family_replay_rejected_verified",
            "audit_before_credential_verified",
            "human_flow_verified_steps",
            "Evidence must contain exactly the 16 canonical OAuth flow steps.",
            "Evidence must be clean relative to HEAD.",
            "validation_mode=true read_only=true gate_promotion_performed=false secret_output=false",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, source)
        self.assertIn("if (-not $ValidateOnly)", source)
        self.assertNotIn("Invoke-WebRequest", source)
        self.assertNotIn("Invoke-RestMethod", source)

    def _run_git(self, repo: Path, *args: str) -> str:
        completed = subprocess.run(
            ["git", *args],
            cwd=repo,
            check=True,
            capture_output=True,
            text=True,
        )
        return completed.stdout.strip()

    def _write_json(self, path: Path, payload: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    def _sha256_file(self, path: Path) -> str:
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def _install_python_launcher_shim(self, repo: Path) -> Path:
        shim_dir = repo / "bin"
        shim_dir.mkdir()
        if os.name != "nt" or shutil.which("py") is None:
            (shim_dir / "py").write_text(
                "#!/usr/bin/env sh\nif [ \"$1\" = \"-3\" ]; then shift; fi\nexec python3 \"$@\"\n",
                encoding="utf-8",
            )
            (shim_dir / "py").chmod(0o755)
        return shim_dir

    def _install_market_ready_preamble(self, repo: Path) -> Path:
        script_source = (REPO_ROOT / "scripts" / "verify-market-ready.ps1").read_text(
            encoding="utf-8"
        )
        preamble = script_source.split(
            'Write-Host "=== MARKET-READY AGGREGATE GATE ==="', 1
        )[0]
        scripts_dir = repo / "scripts"
        scripts_dir.mkdir(exist_ok=True)
        (scripts_dir / "market-ready-preamble.ps1").write_text(
            preamble, encoding="utf-8"
        )
        wrapper = scripts_dir / "invoke-ready-gate.ps1"
        wrapper.write_text(
            textwrap.dedent(
                """
                param(
                  [Parameter(Mandatory = $true)][string]$GateJson,
                  [Parameter(Mandatory = $true)][string]$GateId,
                  [Parameter(Mandatory = $true)][string]$ExpectedCandidateSha,
                  [Parameter(Mandatory = $true)][string]$ExpectedReleaseId
                )
                . (Join-Path $PSScriptRoot 'market-ready-preamble.ps1')
                $gate = Get-Content -LiteralPath $GateJson -Raw | ConvertFrom-Json
                $result = Get-ReadyGateEvidenceValidation $gate $GateId $ExpectedCandidateSha $ExpectedReleaseId
                $result | ConvertTo-Json -Depth 10 -Compress
                """
            ).lstrip(),
            encoding="utf-8",
        )
        return wrapper

    def _install_dummy_validators(self, repo: Path) -> None:
        (repo / "scripts" / "verify_layer5_registry_release_evidence.py").write_text(
            textwrap.dedent(
                """
                from __future__ import annotations

                import argparse
                import json
                import sys
                from pathlib import Path

                parser = argparse.ArgumentParser()
                parser.add_argument("--evidence", required=True)
                parser.add_argument("--expected-release-id", required=True)
                parser.add_argument("--expected-source-sha", required=True)
                parser.add_argument("--expected-control-sha", required=True)
                parser.add_argument("--validate-only", action="store_true")
                args = parser.parse_args()
                evidence = json.loads(Path(args.evidence).read_text(encoding="utf-8"))
                if evidence.get("force_deep_fail"):
                    print("[layer5-registry-release-evidence] FAIL")
                    sys.exit(7)
                assert args.validate_only
                assert evidence["release_id"] == args.expected_release_id
                assert evidence["source_commit_sha"] == args.expected_source_sha
                assert evidence["control_commit_sha"] == args.expected_control_sha
                print("[layer5-registry-release-evidence] PASS")
                """
            ).lstrip(),
            encoding="utf-8",
        )
        (repo / "scripts" / "verify-phase6-scale-evidence.ps1").write_text(
            textwrap.dedent(
                """
                param(
                  [Parameter(Mandatory = $true)][string]$EvidencePath,
                  [switch]$ValidateOnly
                )
                $evidence = Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
                if ($evidence.force_deep_fail -eq $true) {
                  Write-Host '[phase6-scale-evidence] promotion=false read_only=true'
                  exit 9
                }
                if (-not $ValidateOnly) { exit 8 }
                Write-Host '[phase6-scale-evidence] promotion=false read_only=true'
                exit 0
                """
            ).lstrip(),
            encoding="utf-8",
        )

    def _build_fixture(
        self,
        repo: Path,
        gate_id: str,
        *,
        evidence_mutation=None,
        gate_mutation=None,
        control_not_ancestor: bool = False,
        control_not_descendant: bool = False,
        bad_hash: bool = False,
        verifier_symlink_escape: bool = False,
    ) -> dict:
        self._run_git(repo, "init", "-b", "main")
        self._run_git(repo, "config", "user.email", "codex@example.invalid")
        self._run_git(repo, "config", "user.name", "Codex Test")
        self._install_python_launcher_shim(repo)
        wrapper = self._install_market_ready_preamble(repo)
        self._install_dummy_validators(repo)
        if verifier_symlink_escape:
            verifier_name = (
                "verify_layer5_registry_release_evidence.py"
                if gate_id == "docker_registry_publish"
                else "verify-phase6-scale-evidence.ps1"
            )
            escaped = repo.parent / f"escaped-{verifier_name}"
            escaped.write_text("exit 0\n", encoding="utf-8")
            verifier_path = repo / "scripts" / verifier_name
            verifier_path.unlink()
            try:
                os.symlink(escaped, verifier_path)
            except (OSError, NotImplementedError) as exc:
                raise unittest.SkipTest(f"symlink creation unavailable: {exc}") from exc

        (repo / "README.md").write_text("source\n", encoding="utf-8")
        self._run_git(repo, "add", ".")
        self._run_git(repo, "commit", "-m", "source")
        source_sha = self._run_git(repo, "rev-parse", "HEAD")

        if control_not_ancestor:
            self._run_git(repo, "checkout", "-b", "side-control", source_sha)
            (repo / "CONTROL.txt").write_text("side control\n", encoding="utf-8")
            self._run_git(repo, "add", ".")
            self._run_git(repo, "commit", "-m", "side control")
            control_sha = self._run_git(repo, "rev-parse", "HEAD")
            self._run_git(repo, "checkout", "main")
            (repo / "MAIN.txt").write_text("main head\n", encoding="utf-8")
            self._run_git(repo, "add", ".")
            self._run_git(repo, "commit", "-m", "main head")
        else:
            (repo / "CONTROL.txt").write_text("control\n", encoding="utf-8")
            self._run_git(repo, "add", ".")
            self._run_git(repo, "commit", "-m", "control")
            control_sha = self._run_git(repo, "rev-parse", "HEAD")

        release_id = "prod-candidate-test"
        expected_source_sha = "f" * 40 if control_not_descendant else source_sha
        owner_ref = "TEST_OWNER_GRANT"
        if gate_id == "docker_registry_publish":
            evidence_path = repo / "evidence" / "registry.json"
            verifier = "scripts/verify_layer5_registry_release_evidence.py"
            evidence = {
                "contract_version": "layer5-registry-release-credit-evidence-v1",
                "status": "verified",
                "secret_output": False,
                "release_id": release_id,
                "source_commit_sha": expected_source_sha,
                "control_commit_sha": control_sha,
            }
            provider = "ghcr"
        elif gate_id == "phase6_scale_runtime":
            evidence_path = repo / "evidence" / "phase6.json"
            verifier = "scripts/verify-phase6-scale-evidence.ps1"
            evidence = {
                "contract_version": "phase6-scale-evidence-v2",
                "result": "provisional_pending_github_readback",
                "source_binding": {
                    "source_commit_sha": expected_source_sha,
                    "repository_head_sha": control_sha,
                    "release_candidate": {
                        "active_release_id": release_id,
                        "source_commit_sha": expected_source_sha,
                    },
                    "owner_granted": True,
                    "owner_grant_ref": owner_ref,
                    "health_json_source_binding_verified": True,
                },
                "request_budget": {
                    "exact_plan_executed": True,
                    "cap_respected": True,
                },
                "cleanup": {"complete": True},
                "aggregate": {"criterion_met": True, "failures": []},
                "auth": {"value_recorded": False},
                "gate_promotion_performed": False,
                "percentage_credit_awarded": 0,
            }
            provider = "cloudflare-workers-d1-zero-card"
        else:
            raise AssertionError(f"unsupported gate fixture: {gate_id}")

        if evidence_mutation is not None:
            evidence_mutation(evidence)
        self._write_json(evidence_path, evidence)
        evidence_sha = self._sha256_file(evidence_path)
        gate = {
            "owner_granted": True,
            "live_verified": True,
            "paid_provider": False,
            "owner_grant_ref": owner_ref,
            "provider": provider,
            "verifier": verifier,
            "verified_at_utc": "2026-09-10T00:00:00Z",
            "evidence_artifact": evidence_path.relative_to(repo).as_posix(),
            "evidence_sha256": "0" * 64 if bad_hash else evidence_sha,
        }
        if gate_mutation is not None:
            gate_mutation(gate)
        gate_path = repo / "gate.json"
        self._write_json(gate_path, gate)
        self._run_git(repo, "add", ".")
        self._run_git(repo, "commit", "-m", "evidence")
        return {
            "wrapper": wrapper,
            "gate_path": gate_path,
            "release_id": release_id,
            "expected_source_sha": expected_source_sha,
        }

    def _invoke_fixture_gate(self, repo: Path, fixture: dict, gate_id: str) -> dict:
        env = os.environ.copy()
        env["PATH"] = str(repo / "bin") + os.pathsep + env.get("PATH", "")
        completed = subprocess.run(
            [
                self.pwsh,
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(fixture["wrapper"]),
                "-GateJson",
                str(fixture["gate_path"]),
                "-GateId",
                gate_id,
                "-ExpectedCandidateSha",
                fixture["expected_source_sha"],
                "-ExpectedReleaseId",
                fixture["release_id"],
            ],
            cwd=repo,
            check=True,
            capture_output=True,
            text=True,
            env=env,
        )
        return json.loads(completed.stdout.strip().splitlines()[-1])

    def _assert_gate_fixture(self, gate_id: str, *, expected_ok: bool, expected_detail: str = "", **kwargs) -> None:
        with tempfile.TemporaryDirectory(prefix="market-ready-gate-") as tmp:
            repo = Path(tmp)
            fixture = self._build_fixture(repo, gate_id, **kwargs)
            result = self._invoke_fixture_gate(repo, fixture, gate_id)
        self.assertIs(result["ok"], expected_ok)
        if expected_detail:
            self.assertIn(expected_detail, result["detail"])

    def test_registry_gate_replays_aggregate_evidence_behaviorally(self) -> None:
        cases = (
            ("positive", {}, True, ""),
            ("wrong release", {"evidence_mutation": lambda e: e.update(release_id="wrong")}, False, "ghcr_release"),
            ("wrong source", {"evidence_mutation": lambda e: e.update(source_commit_sha="0" * 40)}, False, "ghcr_candidate"),
            ("wrong hash", {"bad_hash": True}, False, "evidence_sha256"),
            ("wrong status", {"evidence_mutation": lambda e: e.update(status="historical_only")}, False, "evidence_status"),
            ("wrong verifier", {"gate_mutation": lambda g: g.update(verifier="scripts/wrong.py")}, False, "ghcr_dedicated_non_mutating_verifier_unavailable"),
            ("escaped verifier", {"verifier_symlink_escape": True}, False, "ghcr_dedicated_non_mutating_verifier_unavailable"),
            ("control not descendant", {"control_not_descendant": True}, False, "ghcr_control_not_descendant"),
            ("control not ancestor", {"control_not_ancestor": True}, False, "ghcr_control_not_ancestor"),
            ("deep verifier failure", {"evidence_mutation": lambda e: e.update(force_deep_fail=True)}, False, "ghcr_dedicated_non_mutating_verifier_failed"),
        )
        for name, kwargs, expected_ok, expected_detail in cases:
            with self.subTest(name=name):
                self._assert_gate_fixture(
                    "docker_registry_publish",
                    expected_ok=expected_ok,
                    expected_detail=expected_detail,
                    **kwargs,
                )

    def test_phase6_gate_keeps_provisional_source_control_behavioral(self) -> None:
        cases = (
            ("positive", {}, True, ""),
            ("wrong release", {"evidence_mutation": lambda e: e["source_binding"]["release_candidate"].update(active_release_id="wrong")}, False, "phase6_release_binding"),
            ("wrong source", {"evidence_mutation": lambda e: e["source_binding"].update(source_commit_sha="0" * 40)}, False, "phase6_candidate"),
            ("wrong hash", {"bad_hash": True}, False, "evidence_sha256"),
            ("wrong status", {"evidence_mutation": lambda e: e.update(result="verified")}, False, "phase6_provisional_status"),
            ("wrong verifier", {"gate_mutation": lambda g: g.update(verifier="scripts/wrong.ps1")}, False, "phase6_verifier_identity"),
            ("wrong provider", {"gate_mutation": lambda g: g.update(provider="cloudflare")}, False, "phase6_verifier_identity"),
            ("escaped verifier", {"verifier_symlink_escape": True}, False, "phase6_verifier_identity"),
            ("control not descendant", {"control_not_descendant": True}, False, "phase6_control_not_descendant"),
            ("control not ancestor", {"control_not_ancestor": True}, False, "phase6_control_not_ancestor"),
            ("deep verifier failure", {"evidence_mutation": lambda e: e.update(force_deep_fail=True)}, False, "phase6_deep_non_mutating_verifier"),
        )
        for name, kwargs, expected_ok, expected_detail in cases:
            with self.subTest(name=name):
                self._assert_gate_fixture(
                    "phase6_scale_runtime",
                    expected_ok=expected_ok,
                    expected_detail=expected_detail,
                    **kwargs,
                )

    def test_repo_scoped_file_rejects_parent_directory_link(self) -> None:
        with tempfile.TemporaryDirectory(prefix="market-ready-path-") as tmp:
            base = Path(tmp)
            repo = base / "repo"
            repo.mkdir()
            external = base / "outside"
            external.mkdir()
            (external / "proof.json").write_text("{}\n", encoding="utf-8")
            self._install_market_ready_preamble(repo)
            wrapper = repo / "scripts" / "check-path.ps1"
            wrapper.write_text(textwrap.dedent("""
                $ErrorActionPreference = 'Stop'
                . (Join-Path $PSScriptRoot 'market-ready-preamble.ps1')
                $link = Join-Path $repoRoot 'linked'
                $outside = Join-Path (Split-Path $repoRoot -Parent) 'outside'
                $kind = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
                New-Item -ItemType $kind -Path $link -Target $outside -ErrorAction Stop | Out-Null
                try {
                  if ($null -ne (Resolve-RepoScopedFile 'linked/proof.json')) { throw 'parent link accepted' }
                  '{}' | Set-Content -LiteralPath (Join-Path $repoRoot 'plain.json')
                  if ($null -eq (Resolve-RepoScopedFile 'plain.json')) { throw 'regular file rejected' }
                } finally { [IO.Directory]::Delete($link) }
            """).lstrip(), encoding="utf-8")
            result = subprocess.run([self.pwsh, "-NoProfile", "-File", str(wrapper)],
                                    cwd=repo, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
