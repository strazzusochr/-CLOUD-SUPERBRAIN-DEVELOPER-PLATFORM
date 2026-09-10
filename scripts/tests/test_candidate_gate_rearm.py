from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "rearm-candidate-capability-gates.ps1"


def write_json(path: Path, value: object) -> bytes:
    raw = (json.dumps(value, indent=2) + "\n").encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return raw


def run(cmd: list[str], cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)
    if check and completed.returncode != 0:
        raise AssertionError(
            f"command failed: {cmd}\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )
    return completed


def git(cwd: Path, *args: str) -> str:
    return run(["git", *args], cwd=cwd).stdout.strip()


def git_archive_sha(repo: Path, commit: str) -> str:
    archive = subprocess.check_output(["git", "archive", "--format=tar", commit], cwd=repo)
    return hashlib.sha256(archive).hexdigest()


def ps_base(repo: Path, fixture: dict[str, str], gate_id: str) -> list[str]:
    return [
        "pwsh",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(repo / "scripts" / "rearm-candidate-capability-gates.ps1"),
        "-GateId",
        gate_id,
        "-OldEvidencePath",
        fixture["old_evidence_path"],
        "-OldEvidenceSha256",
        fixture["old_evidence_sha"],
        "-OldReleaseId",
        fixture["old_release"],
        "-OldSourceSha",
        fixture["old_source"],
        "-OldQualificationSha",
        fixture["old_control"],
        "-NewReleaseId",
        fixture["new_release"],
        "-NewSourceSha",
        fixture["new_source"],
        "-NewQualificationSha",
        fixture["new_q"],
        "-NewSourceArchiveSha256",
        fixture["new_archive_sha"],
        "-NewOwnerGrantRef",
        f"chat:fixture::{gate_id}::{fixture['new_release']}::{fixture['new_source']}",
        "-CandidatePointerPath",
        fixture["candidate_pointer_path"],
        "-CapabilityStatePath",
        "docs/runtime-state/capability-gates.json",
    ]


class CandidateGateRearmTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not shutil.which("pwsh"):
            raise unittest.SkipTest("pwsh is unavailable")

    def make_repo(self, gate_id: str = "docker_registry_publish", *, control_patch: dict | None = None) -> tuple[tempfile.TemporaryDirectory[str], Path, dict[str, str]]:
        temp = tempfile.TemporaryDirectory(prefix="candidate-gate-rearm-")
        repo = Path(temp.name)
        (repo / ".rearm-fixture").write_text("fixture only\n", encoding="utf-8")
        (repo / "scripts").mkdir()
        shutil.copy2(SCRIPT, repo / "scripts" / "rearm-candidate-capability-gates.ps1")

        git(repo, "init", "--quiet")
        git(repo, "config", "user.email", "test@example.invalid")
        git(repo, "config", "user.name", "Candidate Gate Rearm Test")
        git(repo, "config", "core.autocrlf", "false")

        (repo / "product.txt").write_text("old source\n", encoding="utf-8")
        git(repo, "add", "product.txt", ".rearm-fixture", "scripts")
        git(repo, "commit", "--quiet", "-m", "old source")
        old_source = git(repo, "rev-parse", "HEAD")

        old_release = "prod-candidate-fixture-old-rc1"
        new_release = "prod-candidate-fixture-new-rc2"
        old_evidence_path = (
            "docs/release-artifacts/prod-candidate-fixture-old-rc1-evidence/registry/layer5.json"
            if gate_id == "docker_registry_publish"
            else ".phase1-artifacts/phase6-scale/scale-evidence-fixture.json"
        )
        if gate_id == "docker_registry_publish":
            old_evidence = {
                "contract_version": "layer5-registry-release-credit-evidence-v1",
                "status": "verified",
                "release_id": old_release,
                "source_commit_sha": old_source,
                "control_commit_sha": "",
            }
        else:
            old_evidence = {
                "contract_version": "phase6-scale-evidence-v2",
                "result": "provisional_pending_github_readback",
                "criterion_binding": {"gate_id": "phase6_scale_runtime"},
                "source_binding": {
                    "source_commit_sha": old_source,
                    "release_candidate": {
                        "active_release_id": old_release,
                        "source_commit_sha": old_source,
                    },
                    "source_archive_sha256": git_archive_sha(repo, old_source),
                },
                "non_claims": ["This evidence file does not promote phase6_scale_runtime."],
            }

        capability = {
            "contract_version": "capability-gate-state-v1",
            "status": "configured",
            "policy": "fixture verifier only",
            "gates": {
                "docker_registry_publish": {
                    "owner_granted": True,
                    "owner_grant_ref": "OWNER_GRANTS_2026-09-02.json::O3:docker_registry_publish",
                    "live_verified": gate_id == "docker_registry_publish",
                    "evidence_artifact": old_evidence_path if gate_id == "docker_registry_publish" else "",
                    "evidence_sha256": "",
                    "verified_at_utc": "2026-09-06T01:05:23.752Z" if gate_id == "docker_registry_publish" else "",
                    "provider": "ghcr",
                    "paid_provider": False,
                    "verifier": "scripts/verify_layer5_registry_release_evidence.py" if gate_id == "docker_registry_publish" else "",
                    "note": "old verified registry gate" if gate_id == "docker_registry_publish" else "owner grant only",
                },
                "phase6_scale_runtime": {
                    "owner_granted": True,
                    "owner_grant_ref": "OWNER_GRANTS_2026-09-02.json::O2:phase6_scale_runtime",
                    "live_verified": gate_id == "phase6_scale_runtime",
                    "evidence_artifact": old_evidence_path if gate_id == "phase6_scale_runtime" else "",
                    "evidence_sha256": "",
                    "verified_at_utc": "2026-09-08T20:29:57.5087349Z" if gate_id == "phase6_scale_runtime" else "",
                    "provider": "cloudflare-workers-d1-zero-card" if gate_id == "phase6_scale_runtime" else "",
                    "paid_provider": False,
                    "verifier": "scripts/verify-phase6-scale-evidence.ps1" if gate_id == "phase6_scale_runtime" else "",
                    "note": "old verified phase6 gate" if gate_id == "phase6_scale_runtime" else "owner grant only",
                },
                "unrelated": {"live_verified": False, "sentinel": "unchanged"},
            },
            "non_claims": ["fixture"],
        }
        old_evidence_bytes = write_json(repo / old_evidence_path, old_evidence)
        old_evidence_sha = hashlib.sha256(old_evidence_bytes).hexdigest()
        capability["gates"][gate_id]["evidence_sha256"] = old_evidence_sha  # type: ignore[index]
        write_json(repo / "docs/runtime-state/capability-gates.json", capability)
        git(repo, "add", "docs")
        if (repo / ".phase1-artifacts").exists():
            git(repo, "add", ".phase1-artifacts")
        git(repo, "commit", "--quiet", "-m", "old verified gate")
        old_control = git(repo, "rev-parse", "HEAD")

        evidence_json = json.loads((repo / old_evidence_path).read_text(encoding="utf-8"))
        if gate_id == "docker_registry_publish":
            evidence_json["control_commit_sha"] = old_control
        else:
            evidence_json["source_binding"]["repository_head_sha"] = old_control
        old_evidence_bytes = write_json(repo / old_evidence_path, evidence_json)
        old_evidence_sha = hashlib.sha256(old_evidence_bytes).hexdigest()
        capability_json = json.loads((repo / "docs/runtime-state/capability-gates.json").read_text(encoding="utf-8"))
        capability_json["gates"][gate_id]["evidence_sha256"] = old_evidence_sha
        write_json(repo / "docs/runtime-state/capability-gates.json", capability_json)
        git(repo, "add", "docs/runtime-state/capability-gates.json", old_evidence_path)
        git(repo, "commit", "--quiet", "-m", "bind old evidence hashes")

        (repo / "product.txt").write_text("new source\n", encoding="utf-8")
        git(repo, "add", "product.txt")
        git(repo, "commit", "--quiet", "-m", "new source")
        new_source = git(repo, "rev-parse", "HEAD")
        new_archive_sha = git_archive_sha(repo, new_source)

        pointer_path = "docs/release-artifacts/current-release-candidate.json"
        write_json(
            repo / pointer_path,
            {
                "contract_version": "current-release-candidate-v1",
                "active_release_id": new_release,
                "source_commit_sha": new_source,
                "updated_at": "2026-09-10T00:00:00Z",
                "production_rollout_claimed": False,
            },
        )
        write_json(
            repo / "docs/runtime-state/source-qualification-control.json",
            {
                "$schema": "../runtime-contracts/source-qualification-control.schema.json",
                "contract_version": "source-qualification-control-v1",
                "release_id": new_release,
                "runtime_candidate_sha": new_source,
                "source_archive_sha256": new_archive_sha,
                "production_rollout_claimed": False,
                "percentage_credit_awarded": 0,
                "secret_output": False,
                **(control_patch or {}),
            },
        )
        git(repo, "add", "docs/runtime-state/source-qualification-control.json")
        git(repo, "commit", "--quiet", "-m", "new qualification direct child")
        new_q = git(repo, "rev-parse", "HEAD")
        git(repo, "add", pointer_path)
        git(repo, "commit", "--quiet", "-m", "select qualified candidate")

        fixture = {
            "old_evidence_path": old_evidence_path,
            "old_evidence_sha": old_evidence_sha,
            "old_release": old_release,
            "old_source": old_source,
            "old_control": old_control,
            "new_release": new_release,
            "new_source": new_source,
            "new_q": new_q,
            "new_archive_sha": new_archive_sha,
            "candidate_pointer_path": pointer_path,
        }
        return temp, repo, fixture

    def parse_hashes(self, output: str) -> tuple[str, str]:
        state = re.search(r"capability_state_sha256=([0-9a-f]{64})", output)
        gate = re.search(r"gate_identity_sha256=([0-9a-f]{64})", output)
        self.assertIsNotNone(state, output)
        self.assertIsNotNone(gate, output)
        return state.group(1), gate.group(1)  # type: ignore[union-attr]

    def test_docker_registry_rearm_validation_and_apply(self) -> None:
        temp, repo, fixture = self.make_repo("docker_registry_publish")
        with temp:
            validation = run(ps_base(repo, fixture, "docker_registry_publish"), repo, check=False)
            self.assertEqual(validation.returncode, 0, validation.stderr)
            self.assertIn("status=rearm_ready", validation.stdout)
            state_sha, gate_sha = self.parse_hashes(validation.stdout)
            applied = run(
                ps_base(repo, fixture, "docker_registry_publish")
                + ["-Rearm", "-ExpectedCapabilityStateSha256", state_sha, "-ExpectedGateIdentitySha256", gate_sha],
                repo,
                check=False,
            )
            self.assertEqual(applied.returncode, 0, applied.stderr)
            self.assertIn("status=rearmed", applied.stdout)
            current = json.loads((repo / "docs/runtime-state/capability-gates.json").read_text(encoding="utf-8"))
            gate = current["gates"]["docker_registry_publish"]
            self.assertTrue(gate["owner_granted"])
            self.assertEqual(gate["owner_grant_ref"], f"chat:fixture::docker_registry_publish::{fixture['new_release']}::{fixture['new_source']}")
            self.assertFalse(gate["live_verified"])
            self.assertEqual(gate["provider"], "ghcr")
            self.assertEqual(gate["paid_provider"], False)
            self.assertEqual(gate["evidence_artifact"], "")
            self.assertEqual(gate["evidence_sha256"], "")
            self.assertEqual(gate["verified_at_utc"], "")
            self.assertEqual(gate["verifier"], "")
            self.assertIn(fixture["new_release"], gate["note"])
            self.assertEqual(current["gates"]["unrelated"], {"live_verified": False, "sentinel": "unchanged"})

    def test_phase6_rearm_uses_empty_provider_and_preserves_owner_grant_only_state(self) -> None:
        temp, repo, fixture = self.make_repo("phase6_scale_runtime")
        with temp:
            validation = run(ps_base(repo, fixture, "phase6_scale_runtime"), repo, check=False)
            self.assertEqual(validation.returncode, 0, validation.stderr)
            state_sha, gate_sha = self.parse_hashes(validation.stdout)
            applied = run(
                ps_base(repo, fixture, "phase6_scale_runtime")
                + ["-Rearm", "-ExpectedCapabilityStateSha256", state_sha, "-ExpectedGateIdentitySha256", gate_sha],
                repo,
                check=False,
            )
            self.assertEqual(applied.returncode, 0, applied.stderr)
            gate = json.loads((repo / "docs/runtime-state/capability-gates.json").read_text(encoding="utf-8"))["gates"][
                "phase6_scale_runtime"
            ]
            self.assertTrue(gate["owner_granted"])
            self.assertFalse(gate["live_verified"])
            self.assertEqual(gate["provider"], "")
            self.assertEqual(gate["evidence_artifact"], "")
            self.assertEqual(gate["evidence_sha256"], "")
            self.assertEqual(gate["verifier"], "")

    def test_rejects_unsupported_gate_and_replay(self) -> None:
        temp, repo, fixture = self.make_repo("docker_registry_publish")
        with temp:
            unsupported = run(ps_base(repo, fixture, "live_mcp_writes"), repo, check=False)
            self.assertNotEqual(unsupported.returncode, 0)
            validation = run(ps_base(repo, fixture, "docker_registry_publish"), repo, check=False)
            state_sha, gate_sha = self.parse_hashes(validation.stdout)
            first = run(
                ps_base(repo, fixture, "docker_registry_publish")
                + ["-Rearm", "-ExpectedCapabilityStateSha256", state_sha, "-ExpectedGateIdentitySha256", gate_sha],
                repo,
                check=False,
            )
            self.assertEqual(first.returncode, 0, first.stderr)
            replay = run(ps_base(repo, fixture, "docker_registry_publish"), repo, check=False)
            self.assertNotEqual(replay.returncode, 0)
            self.assertIn("already rearmed", replay.stderr + replay.stdout)

    def test_rejects_tampered_boolean_release_source_hash_and_new_pointer(self) -> None:
        cases = {
            "boolean": lambda repo, fixture: self._mutate_gate(repo, "docker_registry_publish", {"live_verified": "true"}),
            "old_release": lambda repo, fixture: fixture.update({"old_release": "prod-candidate-wrong"}),
            "old_source": lambda repo, fixture: fixture.update({"old_source": "0" * 40}),
            "old_hash": lambda repo, fixture: fixture.update({"old_evidence_sha": "1" * 64}),
            "new_pointer": lambda repo, fixture: self._mutate_json(
                repo / fixture["candidate_pointer_path"], {"source_archive_sha256": "2" * 64}
            ),
        }
        for label, mutate in cases.items():
            with self.subTest(label=label):
                temp, repo, fixture = self.make_repo("docker_registry_publish")
                with temp:
                    mutate(repo, fixture)
                    if label == "new_pointer":
                        git(repo, "add", fixture["candidate_pointer_path"])
                        git(repo, "commit", "--quiet", "-m", "tamper pointer archive binding")
                    original = (repo / "docs/runtime-state/capability-gates.json").read_bytes()
                    completed = run(ps_base(repo, fixture, "docker_registry_publish"), repo, check=False)
                    self.assertNotEqual(completed.returncode, 0, completed.stdout)
                    self.assertEqual((repo / "docs/runtime-state/capability-gates.json").read_bytes(), original)

    def test_rejects_bad_ancestry_and_dirty_qualification(self) -> None:
        cases = {
            "ancestry": lambda repo, fixture: fixture.update({"new_q": fixture["old_control"]}),
            "relevant_dirty": lambda repo, fixture: (repo / "docs/runtime-state/source-qualification-control.json").write_text(
                "{}\n", encoding="utf-8"
            ),
        }
        for label, mutate in cases.items():
            with self.subTest(label=label):
                temp, repo, fixture = self.make_repo("phase6_scale_runtime")
                with temp:
                    mutate(repo, fixture)
                    completed = run(ps_base(repo, fixture, "phase6_scale_runtime"), repo, check=False)
                    self.assertNotEqual(completed.returncode, 0, completed.stdout)

    def test_apply_with_stale_hash_fails_without_partial_mutation(self) -> None:
        temp, repo, fixture = self.make_repo("docker_registry_publish")
        with temp:
            validation = run(ps_base(repo, fixture, "docker_registry_publish"), repo, check=False)
            _state_sha, gate_sha = self.parse_hashes(validation.stdout)
            original = (repo / "docs/runtime-state/capability-gates.json").read_bytes()
            failed = run(
                ps_base(repo, fixture, "docker_registry_publish")
                + ["-Rearm", "-ExpectedCapabilityStateSha256", "0" * 64, "-ExpectedGateIdentitySha256", gate_sha],
                repo,
                check=False,
            )
            self.assertNotEqual(failed.returncode, 0)
            self.assertEqual((repo / "docs/runtime-state/capability-gates.json").read_bytes(), original)

    def _mutate_json(self, path: Path, patch: dict[str, object]) -> None:
        value = json.loads(path.read_text(encoding="utf-8"))
        value.update(patch)
        write_json(path, value)

    def test_phase6_rejects_wrong_repository_head_binding(self) -> None:
        temp, repo, fixture = self.make_repo("phase6_scale_runtime")
        with temp:
            path = repo / fixture["old_evidence_path"]
            value = json.loads(path.read_text(encoding="utf-8"))
            value["source_binding"]["repository_head_sha"] = fixture["old_source"]
            fixture["old_evidence_sha"] = hashlib.sha256(write_json(path, value)).hexdigest()
            self._mutate_gate(repo, "phase6_scale_runtime", {"evidence_sha256": fixture["old_evidence_sha"]})
            git(repo, "add", fixture["old_evidence_path"], "docs/runtime-state/capability-gates.json")
            git(repo, "commit", "--quiet", "-m", "tamper old control binding")
            before = (repo / "docs/runtime-state/capability-gates.json").read_bytes()
            result = run(ps_base(repo, fixture, "phase6_scale_runtime"), repo, check=False)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("qualification/control mismatch", result.stderr)
            self.assertEqual((repo / "docs/runtime-state/capability-gates.json").read_bytes(), before)

    def test_rejects_qualification_commit_with_runtime_delta(self) -> None:
        temp, repo, fixture = self.make_repo()
        with temp:
            git(repo, "checkout", "--quiet", "-b", "invalid-q", fixture["new_source"])
            git(repo, "checkout", fixture["new_q"], "--", "docs/runtime-state/source-qualification-control.json")
            (repo / "runtime.py").write_text("unexpected_runtime_change = True\n", encoding="utf-8")
            git(repo, "add", "runtime.py")
            git(repo, "commit", "--quiet", "-m", "invalid qualification with runtime delta")
            fixture["new_q"] = git(repo, "rev-parse", "HEAD")
            write_json(repo / fixture["candidate_pointer_path"], {
                "active_release_id": fixture["new_release"], "source_commit_sha": fixture["new_source"],
                "production_rollout_claimed": False,
            })
            git(repo, "add", fixture["candidate_pointer_path"])
            git(repo, "commit", "--quiet", "-m", "select invalid qualification")
            result = run(ps_base(repo, fixture, "docker_registry_publish"), repo, check=False)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("only source-qualification-control.json", result.stderr)

    def test_owner_reference_must_bind_candidate_and_gate(self) -> None:
        temp, repo, fixture = self.make_repo()
        with temp:
            command = ps_base(repo, fixture, "docker_registry_publish")
            command[command.index("-NewOwnerGrantRef") + 1] = "chat:fixture::docker_registry_publish"
            result = run(command, repo, check=False)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn("grant reference", result.stderr)

    def test_source_qualification_contract_rejects_coercion_and_extra_fields(self) -> None:
        cases = (
            ({"percentage_credit_awarded": "0"}, "credit must be integer zero"),
            ({"production_rollout_claimed": "false"}, "must be a JSON boolean"),
            ({"secret_output": True}, "'secret_output' mismatch"),
            ({"unknown_field": False}, "property count mismatch"),
        )
        for patch, message in cases:
            with self.subTest(patch=patch):
                temp, repo, fixture = self.make_repo(control_patch=patch)
                with temp:
                    original = (repo / "docs/runtime-state/capability-gates.json").read_bytes()
                    result = run(ps_base(repo, fixture, "docker_registry_publish"), repo, check=False)
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn(message, result.stderr)
                    self.assertEqual((repo / "docs/runtime-state/capability-gates.json").read_bytes(), original)

    def test_preserves_dirty_unrelated_gate_and_timestamp_exactly(self) -> None:
        temp, repo, fixture = self.make_repo()
        with temp:
            timestamp = "2026-09-06T01:05:23.7521234+02:00"
            self._mutate_gate(repo, "unrelated", {"sentinel": "foreign work", "timestamp": timestamp})
            before = json.loads((repo / "docs/runtime-state/capability-gates.json").read_text(encoding="utf-8"))
            validation = run(ps_base(repo, fixture, "docker_registry_publish"), repo, check=False)
            self.assertEqual(validation.returncode, 0, validation.stderr)
            state_sha, gate_sha = self.parse_hashes(validation.stdout)
            result = run(ps_base(repo, fixture, "docker_registry_publish") + [
                "-Rearm", "-ExpectedCapabilityStateSha256", state_sha, "-ExpectedGateIdentitySha256", gate_sha,
            ], repo, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            after = json.loads((repo / "docs/runtime-state/capability-gates.json").read_text(encoding="utf-8"))
            after["gates"]["docker_registry_publish"] = before["gates"]["docker_registry_publish"]
            self.assertEqual(after, before)

    def _mutate_gate(self, repo: Path, gate_id: str, patch: dict[str, object]) -> None:
        path = repo / "docs/runtime-state/capability-gates.json"
        value = json.loads(path.read_text(encoding="utf-8"))
        value["gates"][gate_id].update(patch)
        write_json(path, value)

    def test_atomic_write_rolls_back_and_never_overwrites_foreign_changes(self) -> None:
        for mode in ("before_replace", "validation_failure", "foreign_after_replace"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory(prefix="rearm-atomic-") as tmp:
                root = Path(tmp)
                target = root / "state.json"
                original = b'\xef\xbb\xbf{\r\n  "original": true\r\n}\r\n'
                target.write_bytes(original)
                wrapper = root / "atomic-test.ps1"
                wrapper.write_text(textwrap.dedent("""
                    param([string]$Source, [string]$Target, [string]$Mode)
                    $ErrorActionPreference = 'Stop'
                    $ast = [Management.Automation.Language.Parser]::ParseFile($Source, [ref]$null, [ref]$null)
                    $ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $false) |
                      ForEach-Object { Invoke-Expression $_.Extent.Text }
                    $expected = Get-FileSha $Target
                    if ($Mode -eq 'before_replace') {
                      function Read-JsonFile([string]$Path, [string]$Label) {
                        if ($Label -eq 'Temporary capability state') {
                          [IO.File]::WriteAllText($Target, '{"foreign":"before"}')
                        }
                        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
                      }
                    }
                    $validate = {
                      param($written)
                      if ($Mode -eq 'foreign_after_replace') {
                        [IO.File]::WriteAllText($Target, '{"foreign":"after"}')
                      }
                      throw 'injected post-replace validation failure'
                    }
                    try { Write-AtomicJson $Target ([pscustomobject]@{replacement=$true}) $expected $validate; exit 0 }
                    catch { Write-Output $_.Exception.Message; exit 7 }
                """).lstrip(), encoding="utf-8")
                result = run(["pwsh", "-NoProfile", "-File", str(wrapper), "-Source", str(SCRIPT),
                              "-Target", str(target), "-Mode", mode], root, check=False)
                self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
                expected = {"before_replace": b'{"foreign":"before"}',
                            "validation_failure": original,
                            "foreign_after_replace": b'{"foreign":"after"}'}[mode]
                self.assertEqual(target.read_bytes(), expected, result.stdout + result.stderr)
                self.assertEqual(list(root.glob("*.tmp")), [])
                backups = list(root.glob("*.rollback"))
                if mode == "foreign_after_replace":
                    self.assertEqual(len(backups), 1)
                    self.assertEqual(backups[0].read_bytes(), original)
                else:
                    self.assertEqual(backups, [])


if __name__ == "__main__":
    unittest.main()
