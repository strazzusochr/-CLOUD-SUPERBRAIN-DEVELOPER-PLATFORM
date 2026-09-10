from __future__ import annotations

import copy
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch

from app import clouds

REPO_ROOT = Path(__file__).resolve().parents[3]
POWERSHELL = shutil.which("pwsh") or shutil.which("powershell")


class CloudLayerReadinessTests(unittest.TestCase):
    PROVIDERS = {
        "vercel_provider": "vercel_frontend",
        "fly_provider": "fly_io",
        "cloudflare_provider": "cloudflare_edge",
        "github_provider": "github_actions",
        "ghcr_provider": "ghcr_registry",
        "huggingface_provider": "huggingface_identity",
        "gitlab_provider": "gitlab_identity",
        "grafana_cloud_provider": "grafana_cloud",
    }
    OPTIONAL = {"huggingface_identity", "gitlab_identity"}

    def setUp(self) -> None:
        self.stack = ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.dict(os.environ, {}, clear=True))
        self.stack.enter_context(patch.object(clouds.httpx, "Client", side_effect=AssertionError("No network in unit tests")))

    def inventory(self, overrides: dict[str, dict] | None = None) -> dict:
        overrides = overrides or {}
        with ExitStack() as stack:
            for function, provider_id in self.PROVIDERS.items():
                required = provider_id not in self.OPTIONAL and provider_id != "fly_io"
                record = {
                    "id": provider_id,
                    "configured": required,
                    "live_verified": required,
                    "status": "verified" if required else "action_required",
                    "required_env": [],
                }
                record.update(overrides.get(provider_id, {}))
                stack.enter_context(patch.object(clouds, function, return_value=record))
            return clouds.cloud_provider_state()

    def readiness(self, inventory: dict) -> dict:
        with patch.object(clouds, "cloud_provider_state", return_value=inventory):
            return clouds.cloud_layer_readiness_state()

    def test_unavailable_optional_identities_do_not_block_verified_required_providers(self) -> None:
        for optional_status in ("action_required", "api_error", "metadata_only"):
            with self.subTest(optional_status=optional_status):
                inventory = self.inventory({
                    provider_id: {"configured": optional_status != "action_required", "status": optional_status}
                    for provider_id in self.OPTIONAL
                })
                before = copy.deepcopy(inventory)
                readiness = self.readiness(inventory)
                self.assertEqual(readiness["status"], "verified")
                self.assertEqual(readiness["ready_layer_count"], 7)
                self.assertEqual(inventory, before)
                self.assertEqual(inventory["live_verified_count"], 5)
                for layer in readiness["layers"]:
                    self.assertEqual(layer["blockers"], [])
                    self.assertTrue(self.OPTIONAL.isdisjoint(layer["required_providers"]))
                    self.assertTrue(self.OPTIONAL.isdisjoint(layer["live_verified_providers"]))
                layers = {layer["layer_id"]: layer for layer in readiness["layers"]}
                for layer_id, provider_id in (("layer_4", "huggingface_identity"), ("layer_5", "gitlab_identity")):
                    self.assertEqual(layers[layer_id]["optional_providers"], [provider_id])
                    self.assertTrue(any(provider_id in warning for warning in layers[layer_id]["optional_blockers"]))
                self.assertIn("This endpoint does not claim production deployment.", readiness["non_claims"])
                self.assertIn("This endpoint does not claim live LLM provider execution.", readiness["non_claims"])

    def test_verified_optional_identity_cannot_replace_required_provider_evidence(self) -> None:
        inventory = self.inventory({
            "cloudflare_edge": {"live_verified": False},
            "huggingface_identity": {"configured": True, "live_verified": True, "status": "verified"},
        })
        layer = next(layer for layer in self.readiness(inventory)["layers"] if layer["layer_id"] == "layer_4")
        self.assertEqual(layer["status"], "action_required")
        self.assertEqual(layer["live_verified_providers"], [])
        self.assertEqual(layer["optional_live_verified_providers"], ["huggingface_identity"])
        self.assertIn("cloudflare_native_zero_card_hosted_runtime_not_verified", layer["blockers"])

    def test_required_missing_env_still_blocks_the_layer(self) -> None:
        inventory = self.inventory({"ghcr_registry": {"configured": False, "live_verified": False, "required_env": ["GHCR_TOKEN"]}})
        layer = next(layer for layer in self.readiness(inventory)["layers"] if layer["layer_id"] == "layer_5")
        self.assertEqual(layer["status"], "partial_live_verified")
        self.assertIn("ghcr_registry_requires_GHCR_TOKEN", layer["blockers"])

    def test_absent_required_provider_record_fails_closed(self) -> None:
        inventory = self.inventory()
        inventory["providers"] = [provider for provider in inventory["providers"] if provider["id"] != "ghcr_registry"]
        layer = next(layer for layer in self.readiness(inventory)["layers"] if layer["layer_id"] == "layer_5")
        self.assertNotEqual(layer["status"], "live_verified")
        self.assertIn("ghcr_registry_configuration_missing", layer["blockers"])

    def test_mapping_without_optional_declaration_keeps_every_listed_provider_required(self) -> None:
        inventory = self.inventory()
        mapping = next(layer for layer in inventory["seven_layer_mapping"] if layer["layer_id"] == "layer_4")
        mapping.pop("optional_providers", None)
        mapping["providers"] = ["cloudflare_edge", "huggingface_identity"]
        layer = next(layer for layer in self.readiness(inventory)["layers"] if layer["layer_id"] == "layer_4")
        self.assertEqual(layer["status"], "partial_live_verified")
        self.assertIn("huggingface_identity", layer["required_providers"])
        self.assertTrue(any("huggingface_identity" in blocker for blocker in layer["blockers"]))

    def test_duplicate_optional_declaration_cannot_downgrade_a_required_provider(self) -> None:
        inventory = self.inventory({"cloudflare_edge": {"live_verified": False}})
        mapping = next(layer for layer in inventory["seven_layer_mapping"] if layer["layer_id"] == "layer_4")
        mapping["optional_providers"].append("cloudflare_edge")
        layer = next(layer for layer in self.readiness(inventory)["layers"] if layer["layer_id"] == "layer_4")
        self.assertEqual(layer["status"], "action_required")
        self.assertIn("cloudflare_edge", layer["required_providers"])
        self.assertNotIn("cloudflare_edge", layer["optional_providers"])

    @unittest.skipUnless(POWERSHELL, "PowerShell is required for the existing technology parity guard")
    def test_existing_technology_parity_guard_accepts_real_readiness_payloads(self) -> None:
        verifier = (REPO_ROOT / "scripts" / "verify-technology-runtime-view.ps1").read_text(encoding="utf-8")
        assert_true = verifier[verifier.index("function Assert-True"):verifier.index("function Assert-Contains")]
        assert_array = verifier[verifier.index("function Assert-StringArray"):verifier.index('Write-Host "[technology-runtime] static surface"')]
        readiness_guard = verifier[verifier.index("$mappingById = @{}"):verifier.index('Assert-True "preflight contract version"')]
        script = """param([string]$Fixture)
$ErrorActionPreference = 'Stop'
$case = Get-Content -LiteralPath $Fixture -Raw | ConvertFrom-Json
$inventory = $case.inventory
$readiness = $case.readiness
$currentLiveProof = $true
$providerIds = New-Object 'System.Collections.Generic.HashSet[string]'
$providersById = @{}
foreach ($provider in $inventory.providers) {
  [void]$providerIds.Add([string]$provider.id)
  $providersById[[string]$provider.id] = $provider
}
""" + assert_true + assert_array + readiness_guard
        with tempfile.TemporaryDirectory() as directory:
            script_path = Path(directory) / "parity.ps1"
            fixture_path = Path(directory) / "fixture.json"
            script_path.write_text(script, encoding="utf-8")
            for overrides in ({}, {"ghcr_registry": {"live_verified": False}}):
                with self.subTest(overrides=overrides):
                    inventory = self.inventory(overrides)
                    fixture_path.write_text(json.dumps({"inventory": inventory, "readiness": self.readiness(inventory)}), encoding="utf-8")
                    result = subprocess.run(
                        [POWERSHELL, "-NoProfile", "-File", str(script_path), "-Fixture", str(fixture_path)],
                        capture_output=True, text=True, timeout=30, check=False,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
