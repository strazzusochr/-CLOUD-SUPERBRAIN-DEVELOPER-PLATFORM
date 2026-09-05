from __future__ import annotations

import base64
import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "services" / "agent-api"))

from app import clouds  # noqa: E402


def cloud_token(region: str = "prod-eu-west-0") -> str:
    payload = json.dumps({"m": {"r": region}, "o": "test-org"}, separators=(",", ":"))
    encoded = base64.urlsafe_b64encode(payload.encode("utf-8")).decode("ascii").rstrip("=")
    return f"glc_{encoded}"


class GrafanaCloudLiveReadTests(unittest.TestCase):
    def setUp(self) -> None:
        clouds._grafana_cache = None
        clouds._grafana_cache_time = 0.0
        self.env = patch.dict(
            os.environ,
            {
                "GRAFANA_CLOUD_API_KEY": cloud_token(),
                "GRAFANA_CLOUD_URL": "https://test-stack.grafana.net",
            },
            clear=False,
        )
        self.env.start()

    def tearDown(self) -> None:
        self.env.stop()
        clouds._grafana_cache = None
        clouds._grafana_cache_time = 0.0

    @patch("app.clouds._grafana_cloud_get", return_value={"items": []})
    def test_cloud_access_token_requires_fixed_host_provider_read(self, provider_get) -> None:
        snapshot = clouds._fetch_grafana_cloud_snapshot()

        self.assertTrue(snapshot["live_verified"])
        self.assertEqual(snapshot["status"], "verified")
        _, token, url, path = provider_get.call_args.args
        self.assertEqual(token, os.environ["GRAFANA_CLOUD_API_KEY"])
        self.assertEqual(url, "https://grafana.com")
        self.assertEqual(path, "/api/v1/accesspolicies")
        self.assertEqual(provider_get.call_args.kwargs["params"]["region"], "prod-eu-west-0")

    @patch("app.clouds._grafana_cloud_get", side_effect=RuntimeError("provider read failed"))
    def test_decodable_token_is_not_live_when_provider_read_fails(self, provider_get) -> None:
        snapshot = clouds._fetch_grafana_cloud_snapshot()

        self.assertTrue(provider_get.called)
        self.assertFalse(snapshot["live_verified"])
        self.assertEqual(snapshot["status"], "api_error")
        self.assertEqual(snapshot["resources"], [])

    @patch("app.clouds._grafana_cloud_get")
    def test_invalid_cloud_token_never_reaches_provider(self, provider_get) -> None:
        os.environ["GRAFANA_CLOUD_API_KEY"] = "glc_not-valid-json"

        snapshot = clouds._fetch_grafana_cloud_snapshot()

        provider_get.assert_not_called()
        self.assertFalse(snapshot["live_verified"])
        self.assertEqual(snapshot["status"], "api_error")

    @patch("app.clouds._grafana_cloud_get")
    def test_service_account_token_is_not_sent_to_untrusted_host(self, provider_get) -> None:
        os.environ["GRAFANA_CLOUD_API_KEY"] = "glsa_test-token"
        os.environ["GRAFANA_CLOUD_URL"] = "https://example.com"

        snapshot = clouds._fetch_grafana_cloud_snapshot()

        provider_get.assert_not_called()
        self.assertFalse(snapshot["live_verified"])
        self.assertEqual(snapshot["status"], "api_error")


if __name__ == "__main__":
    unittest.main(verbosity=2)
