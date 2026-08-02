from __future__ import annotations

import asyncio
import json
import os
import unittest
import urllib.parse
from unittest.mock import ANY, MagicMock, patch

import httpx
from fastapi import HTTPException
from fastapi.responses import Response

from app import main


TEST_SIGNING_SECRET = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"


def render_http_exception(exc: HTTPException) -> Response:
    scope = {
        "type": "http",
        "http_version": "1.1",
        "method": "GET",
        "scheme": "https",
        "path": "/api/v1/auth/callback",
        "raw_path": b"/api/v1/auth/callback",
        "query_string": b"",
        "headers": [],
        "client": ("127.0.0.1", 12345),
        "server": ("example.test", 443),
        "root_path": "",
    }
    request = main.Request(scope)
    return asyncio.run(main.http_exception_envelope_handler(request, exc))


async def asgi_get(
    path: str,
    cookie_header: str = "",
    extra_headers: dict[str, str] | None = None,
) -> httpx.Response:
    headers = dict(extra_headers or {})
    if cookie_header:
        headers["cookie"] = cookie_header
    transport = httpx.ASGITransport(app=main.app)
    async with httpx.AsyncClient(transport=transport, base_url="https://example.test") as client:
        return await client.get(path, headers=headers)


class FakePipeline:
    def __init__(self, client: "FakeRedis") -> None:
        self.client = client
        self.commands: list[tuple[str, str]] = []

    def __enter__(self) -> "FakePipeline":
        return self

    def __exit__(self, *_args: object) -> None:
        return None

    def get(self, key: str) -> "FakePipeline":
        self.commands.append(("get", key))
        return self

    def delete(self, key: str) -> "FakePipeline":
        self.commands.append(("delete", key))
        return self

    def execute(self) -> list[object]:
        results: list[object] = []
        for command, key in self.commands:
            if command == "get":
                results.append(self.client.get(key))
            else:
                results.append(self.client.delete(key))
        return results


class FakeRedis:
    def __init__(self) -> None:
        self.values: dict[str, str] = {}

    def setex(self, key: str, _ttl: int, value: str) -> bool:
        self.values[key] = value
        return True

    def get(self, key: str) -> str | None:
        return self.values.get(key)

    def delete(self, key: str) -> int:
        return int(self.values.pop(key, None) is not None)

    def pipeline(self, transaction: bool = True) -> FakePipeline:
        if not transaction:
            raise AssertionError("auth consumption must use a Redis transaction")
        return FakePipeline(self)


def signed_access_token(
    now_seconds: int,
    *,
    header_overrides: dict[str, object] | None = None,
    payload_overrides: dict[str, object] | None = None,
) -> str:
    header: dict[str, object] = {"alg": "HS256", "typ": "JWT"}
    payload: dict[str, object] = {
        "sub": "github:123",
        "iat": now_seconds,
        "exp": now_seconds + main.AUTH_ACCESS_TOKEN_TTL_SECONDS,
        "iss": main.AUTH_JWT_ISSUER,
        "aud": main.AUTH_JWT_AUDIENCE,
        "trace_id": "auth-me-test",
        "mode": "verified_github_identity",
    }
    header.update(header_overrides or {})
    payload.update(payload_overrides or {})
    signing_input = f"{main.b64url_json(header)}.{main.b64url_json(payload)}"
    signature = main.hmac.new(main.auth_secret(), signing_input.encode("ascii"), main.hashlib.sha256).digest()
    return f"{signing_input}.{main.b64url_bytes(signature)}"


class AuthSecurityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.capability_gate_state_patcher = patch.object(
            main,
            "capability_gate_state",
            return_value={
                "contract_version": "capability-gate-state-v1",
                "status": "configured",
                "gates": {
                    "production_auth_identity": {
                        "owner_granted": True,
                        "live_verified": False,
                    }
                },
            },
        )
        self.capability_gate_state_mock = self.capability_gate_state_patcher.start()
        self.addCleanup(self.capability_gate_state_patcher.stop)

    def test_prompt_persistence_failure_redacts_internal_exception(self) -> None:
        sentinel = "postgresql://internal-user:internal-password@private-db.example/superbrain"
        request = main.PromptRequest(project_id="security-test", prompt="redaction probe")
        with (
            patch.object(main, "check_budget_guard", return_value=MagicMock()),
            patch.object(main, "rate_limit_prompt", return_value={"allowed": True}),
            patch.object(main, "register_session_llm_call", return_value=1),
            patch.object(main.psycopg, "connect", side_effect=RuntimeError(sentinel)),
        ):
            with self.assertRaises(HTTPException) as raised:
                main.create_prompt(request)

        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail, "session persistence failed")
        response = render_http_exception(raised.exception)
        body = response.body.decode("utf-8")
        self.assertNotIn(sentinel, body)
        self.assertNotIn("internal-password", body)

    def test_oauth_state_is_server_registered_and_one_time(self) -> None:
        client = FakeRedis()
        state = "phase3-auth-state-test"
        main.register_oauth_state(client, state)
        self.assertTrue(main.consume_oauth_state(client, state))
        self.assertFalse(main.consume_oauth_state(client, state))

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_owner_activation_is_exact_boolean_and_does_not_require_live_verified(self) -> None:
        configuration = main.auth_configuration()
        contract = main.auth_contract_payload()
        self.assertTrue(configuration["credentials_configured"])
        self.assertTrue(configuration["owner_activation_granted"])
        self.assertTrue(configuration["credential_issuance_ready"])
        self.assertTrue(contract["owner_activation_granted"])
        self.assertTrue(contract["owner_activation_required"])
        self.assertFalse(contract["live_github_oauth_call"])
        self.assertFalse(
            self.capability_gate_state_mock.return_value["gates"]["production_auth_identity"]["live_verified"]
        )

        self.capability_gate_state_mock.return_value = {
            "gates": {"production_auth_identity": {"owner_granted": "true", "live_verified": True}}
        }
        blocked = main.auth_configuration()
        self.assertFalse(blocked["owner_activation_granted"])
        self.assertFalse(blocked["credential_issuance_ready"])

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_full_credentials_without_owner_activation_issue_no_state_redirect_or_provider_call(self) -> None:
        self.capability_gate_state_mock.return_value = {
            "gates": {"production_auth_identity": {"owner_granted": False, "live_verified": False}}
        }
        response = Response()
        with (
            patch.object(main, "redis_client") as redis_boundary,
            patch.object(main, "exchange_github_identity") as exchange,
            patch.object(main, "persist_auth_audit"),
        ):
            start = main.auth_github_start(response)
            with self.assertRaises(HTTPException) as raised:
                main.auth_callback(
                    Response(),
                    code="unused",
                    state="phase3-auth-state-" + ("O" * 32),
                    oauth_state_cookie="phase3-auth-state-" + ("O" * 32),
                )

        self.assertIsInstance(start, dict)
        self.assertEqual(start["status"], "owner_activation_required")
        self.assertTrue(start["credentials_configured"])
        self.assertFalse(start["owner_activation_granted"])
        self.assertFalse(start["state_issued"])
        self.assertIsNone(start["authorize_url"])
        self.assertIn("Max-Age=0", response.headers["set-cookie"])
        self.assertIn("no-store", response.headers["cache-control"])
        self.assertEqual(response.headers["referrer-policy"], "no-referrer")
        self.assertEqual(raised.exception.status_code, 403)
        self.assertEqual(raised.exception.detail["error"], "production_auth_owner_activation_required")
        blocked_callback = render_http_exception(raised.exception)
        self.assertIn("Max-Age=0", blocked_callback.headers["set-cookie"])
        self.assertIn("no-store", blocked_callback.headers["cache-control"])
        self.assertEqual(blocked_callback.headers["referrer-policy"], "no-referrer")
        redis_boundary.assert_not_called()
        exchange.assert_not_called()

    def test_unknown_refresh_token_cannot_mint_credentials(self) -> None:
        client = FakeRedis()
        token = main.create_refresh_token()
        subject, reason = main.consume_refresh_token(client, token, "rotated")
        self.assertIsNone(subject)
        self.assertEqual(reason, "unknown")
        self.assertIsNone(client.get(main.auth_blacklist_key(token)))

    def test_registered_refresh_token_rotates_once(self) -> None:
        client = FakeRedis()
        token = main.create_refresh_token()
        main.register_refresh_token(client, token, "github:123")
        subject, reason = main.consume_refresh_token(client, token, "rotated")
        self.assertEqual(subject, "github:123")
        self.assertIsNone(reason)
        self.assertEqual(client.get(main.auth_blacklist_key(token)), "rotated")
        reused_subject, reused_reason = main.consume_refresh_token(client, token, "rotated")
        self.assertIsNone(reused_subject)
        self.assertEqual(reused_reason, "blacklisted")

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_configured_start_redirects_without_state_json_or_extra_scope(self) -> None:
        client = FakeRedis()
        with patch.object(main, "redis_client", return_value=client):
            result = main.auth_github_start(Response())
        self.assertEqual(result.status_code, 303)
        self.assertEqual(result.body, b"")
        location = urllib.parse.urlsplit(result.headers["location"])
        self.assertEqual((location.scheme, location.netloc, location.path), ("https", "github.com", "/login/oauth/authorize"))
        query = urllib.parse.parse_qs(location.query)
        self.assertEqual(query["scope"], ["read:user"])
        self.assertNotIn("user:email", result.headers["location"])
        self.assertIn("no-store", result.headers["cache-control"])
        self.assertEqual(result.headers["referrer-policy"], "no-referrer")
        state = query["state"][0]
        self.assertEqual(client.get(main.auth_oauth_state_key(state)), "pending")
        self.assertIn(main.AUTH_OAUTH_STATE_COOKIE + "=", result.headers["set-cookie"])
        self.assertNotIn(state, result.body.decode("utf-8"))

    def test_weak_or_legacy_signing_secrets_block_credential_issuance(self) -> None:
        weak_secrets = (
            "x" * 43,
            "phase3-local-dry-run-signing-secret",
            "0123456789abcdefghijklmnopqrstuv",
        )
        for signing_secret in weak_secrets:
            with self.subTest(secret_length=len(signing_secret)):
                environment = {
                    "GITHUB_OAUTH_CLIENT_ID": "client-id",
                    "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
                    "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
                    "JWT_SIGNING_SECRET": signing_secret,
                }
                client = FakeRedis()
                with patch.dict(os.environ, environment, clear=True), patch.object(
                    main, "redis_client", return_value=client
                ):
                    configuration = main.auth_configuration()
                    result = main.auth_github_start(Response())
                self.assertFalse(configuration["jwt_signing_configured"])
                self.assertFalse(configuration["credential_issuance_ready"])
                self.assertIn(
                    "JWT_SIGNING_SECRET_BASE64URL_256_BIT_MINIMUM",
                    configuration["missing_configuration"],
                )
                self.assertIsInstance(result, dict)
                self.assertFalse(result["state_issued"])
                self.assertEqual(client.values, {})

    @patch.dict(os.environ, {}, clear=True)
    def test_callback_without_configuration_fails_closed(self) -> None:
        with patch.object(main, "persist_auth_audit"):
            with self.assertRaises(HTTPException) as raised:
                main.auth_callback(Response(), code="arbitrary", state="arbitrary", oauth_state_cookie=None)
        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail["error"], "github_oauth_not_configured")
        self.assertFalse(raised.exception.detail["credentials_issued"])
        actual_response = render_http_exception(raised.exception)
        self.assertIn(main.AUTH_OAUTH_STATE_COOKIE + '=""', actual_response.headers["set-cookie"])
        self.assertIn("Max-Age=0", actual_response.headers["set-cookie"])
        self.assertIn("no-store", actual_response.headers["cache-control"])
        self.assertEqual(actual_response.headers["referrer-policy"], "no-referrer")
        self.assertNotIn(main.AUTH_ACCESS_COOKIE + "=", actual_response.headers["set-cookie"])
        self.assertNotIn(main.AUTH_REFRESH_COOKIE + "=", actual_response.headers["set-cookie"])

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_callback_rejects_unbound_state_before_provider_call(self) -> None:
        client = FakeRedis()
        with (
            patch.object(main, "redis_client", return_value=client),
            patch.object(main, "persist_auth_audit"),
            patch.object(main, "exchange_github_identity") as exchange,
        ):
            with self.assertRaises(HTTPException) as raised:
                main.auth_callback(Response(), code="arbitrary", state="arbitrary", oauth_state_cookie=None)
        self.assertEqual(raised.exception.status_code, 401)
        self.assertEqual(raised.exception.detail["error"], "oauth_state_invalid")
        exchange.assert_not_called()
        actual_response = render_http_exception(raised.exception)
        self.assertIn("Max-Age=0", actual_response.headers["set-cookie"])

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_callback_parameter_errors_clear_cookie_on_actual_asgi_response(self) -> None:
        cases = (
            ("missing-code", lambda state: "/api/v1/auth/callback?" + urllib.parse.urlencode({"state": state}), 400),
            (
                "oversized-code",
                lambda state: "/api/v1/auth/callback?" + urllib.parse.urlencode({"state": state, "code": "x" * 256}),
                400,
            ),
            (
                "provider-denied",
                lambda state: "/api/v1/auth/callback?" + urllib.parse.urlencode({"state": state, "error": "access_denied"}),
                401,
            ),
        )
        for label, path_builder, expected_status in cases:
            with self.subTest(case=label):
                client = FakeRedis()
                state = "phase3-auth-state-" + (label.replace("-", "_") + ("x" * 32))[:32]
                main.register_oauth_state(client, state)
                with (
                    patch.object(main, "redis_client", return_value=client),
                    patch.object(main, "persist_auth_audit") as audit,
                    patch.object(main, "exchange_github_identity") as exchange,
                ):
                    response = asyncio.run(
                        asgi_get(path_builder(state), f"{main.AUTH_OAUTH_STATE_COOKIE}={state}")
                    )
                self.assertEqual(response.status_code, expected_status)
                self.assertNotEqual(response.status_code, 422)
                self.assertIn("Max-Age=0", response.headers["set-cookie"])
                self.assertIsNone(client.get(main.auth_oauth_state_key(state)))
                exchange.assert_not_called()
                serialized_audit = json.dumps(audit.call_args.args[1])
                self.assertNotIn(state, serialized_audit)

        with patch.object(main, "persist_auth_audit"), patch.object(main, "exchange_github_identity") as exchange:
            malformed_response = asyncio.run(
                asgi_get(
                    "/api/v1/auth/callback?code=unused&state=%C3%BC",
                    f"{main.AUTH_OAUTH_STATE_COOKIE}=%C3%BC",
                )
            )
        self.assertEqual(malformed_response.status_code, 401)
        self.assertIn("Max-Age=0", malformed_response.headers["set-cookie"])
        exchange.assert_not_called()

    def test_refresh_body_token_is_rejected(self) -> None:
        request = main.AuthRefreshRequest(refresh_token=main.create_refresh_token(), trace_id="test")
        with patch.object(main, "persist_auth_audit"):
            with self.assertRaises(HTTPException) as raised:
                main.auth_refresh(Response(), request=request, refresh_token_cookie=None)
        self.assertEqual(raised.exception.status_code, 400)
        self.assertEqual(raised.exception.detail["error"], "refresh_token_body_not_allowed")

    def test_unknown_cookie_refresh_token_is_rejected(self) -> None:
        client = FakeRedis()
        with patch.object(main, "redis_client", return_value=client), patch.object(main, "persist_auth_audit"):
            with self.assertRaises(HTTPException) as raised:
                main.auth_refresh(Response(), request=None, refresh_token_cookie=main.create_refresh_token())
        self.assertEqual(raised.exception.status_code, 401)
        self.assertEqual(raised.exception.detail["reason"], "unknown")

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_registered_cookie_refresh_rotates_and_registers_replacement(self) -> None:
        client = FakeRedis()
        old_token = main.create_refresh_token()
        main.register_refresh_token(client, old_token, "github:123")
        response = Response()
        with patch.object(main, "redis_client", return_value=client), patch.object(main, "persist_auth_audit"):
            result = main.auth_refresh(response, request=None, refresh_token_cookie=old_token)
        self.assertTrue(result["refresh_token_rotated"])
        self.assertTrue(result["active_registry_verified"])
        self.assertEqual(client.get(main.auth_blacklist_key(old_token)), "rotated")
        active_records = [key for key in client.values if key.startswith(main.AUTH_REFRESH_ACTIVE_PREFIX)]
        self.assertEqual(len(active_records), 1)
        set_cookie_headers = [value.decode("latin-1") for key, value in response.raw_headers if key == b"set-cookie"]
        self.assertTrue(any(header.startswith(main.AUTH_ACCESS_COOKIE + "=") for header in set_cookie_headers))
        self.assertTrue(any(header.startswith(main.AUTH_REFRESH_COOKIE + "=") for header in set_cookie_headers))

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_refresh_audit_failure_issues_no_replacement_credentials(self) -> None:
        client = FakeRedis()
        old_token = main.create_refresh_token()
        main.register_refresh_token(client, old_token, "github:123")
        response = Response()
        with patch.object(main, "redis_client", return_value=client), patch.object(
            main, "persist_auth_audit", return_value=False
        ):
            with self.assertRaises(HTTPException) as raised:
                main.auth_refresh(response, request=None, refresh_token_cookie=old_token)
        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail["error"], "auth_audit_unavailable")
        self.assertEqual(client.get(main.auth_blacklist_key(old_token)), "rotated")
        self.assertFalse(any(key.startswith(main.AUTH_REFRESH_ACTIVE_PREFIX) for key in client.values))
        self.assertFalse(any(key == b"set-cookie" for key, _value in response.raw_headers))

    def test_registered_refresh_is_preserved_when_issuance_configuration_is_incomplete(self) -> None:
        incomplete_configurations = ({}, {"JWT_SIGNING_SECRET": TEST_SIGNING_SECRET})
        for environment in incomplete_configurations:
            with self.subTest(environment_keys=sorted(environment)):
                client = FakeRedis()
                token = main.create_refresh_token()
                main.register_refresh_token(client, token, "github:123")
                with (
                    patch.dict(os.environ, environment, clear=True),
                    patch.object(main, "redis_client", return_value=client),
                    patch.object(main, "persist_auth_audit") as audit,
                ):
                    with self.assertRaises(HTTPException) as raised:
                        main.auth_refresh(Response(), request=None, refresh_token_cookie=token)
                self.assertEqual(raised.exception.status_code, 503)
                self.assertEqual(raised.exception.detail["error"], "auth_configuration_required")
                self.assertIsNotNone(client.get(main.auth_refresh_active_key(token)))
                self.assertIsNone(client.get(main.auth_blacklist_key(token)))
                self.assertEqual(audit.call_args.args[1]["reason"], "credential_issuance_configuration_required")

    def test_logout_does_not_claim_revocation_for_unknown_token(self) -> None:
        client = FakeRedis()
        with patch.object(main, "redis_client", return_value=client), patch.object(main, "persist_auth_audit") as audit:
            result = main.auth_logout(
                Response(),
                request=main.AuthRefreshRequest(refresh_token=main.create_refresh_token()),
                refresh_token_cookie=main.create_refresh_token(),
            )
        self.assertFalse(result["refresh_token_revoked"])
        self.assertFalse(result["body_token_accepted"])
        self.assertTrue(result["active_refresh_token_absent"])
        self.assertNotIn("blacklist_key", result)
        self.assertTrue(result["audit_persisted"])
        self.assertEqual(audit.call_args.args[0], "auth_logout_no_active_token")

    def test_logout_audit_claims_revocation_only_for_active_cookie(self) -> None:
        client = FakeRedis()
        token = main.create_refresh_token()
        main.register_refresh_token(client, token, "github:123")
        with patch.object(main, "redis_client", return_value=client), patch.object(main, "persist_auth_audit") as audit:
            result = main.auth_logout(Response(), request=None, refresh_token_cookie=token)
        self.assertTrue(result["refresh_token_revoked"])
        self.assertTrue(result["active_refresh_token_absent"])
        self.assertTrue(result["audit_persisted"])
        self.assertEqual(audit.call_args.args[0], "auth_logout_revoked")
        self.assertEqual(client.get(main.auth_blacklist_key(token)), "logout")

    def test_logout_audit_failure_is_not_reported_as_success(self) -> None:
        client = FakeRedis()
        token = main.create_refresh_token()
        main.register_refresh_token(client, token, "github:123")
        response = Response()
        with patch.object(main, "redis_client", return_value=client), patch.object(
            main, "persist_auth_audit", return_value=False
        ):
            result = main.auth_logout(response, request=None, refresh_token_cookie=token)
        self.assertEqual(response.status_code, 503)
        self.assertEqual(result["status"], "audit_unavailable")
        self.assertFalse(result["audit_persisted"])
        self.assertTrue(result["refresh_token_revoked"])
        self.assertTrue(result["active_refresh_token_absent"])
        self.assertIn("no-store", response.headers["cache-control"])
        set_cookie_headers = [value.decode("latin-1") for key, value in response.raw_headers if key == b"set-cookie"]
        self.assertEqual(len(set_cookie_headers), 2)
        self.assertTrue(all("Max-Age=0" in header for header in set_cookie_headers))

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_verified_identity_path_registers_refresh_before_issuance(self) -> None:
        client = FakeRedis()
        state = "phase3-auth-state-" + ("B" * 32)
        main.register_oauth_state(client, state)
        response = Response()
        with (
            patch.object(main, "redis_client", return_value=client),
            patch.object(main, "persist_auth_audit") as audit,
            patch.object(main, "exchange_github_identity", return_value="github:123"),
        ):
            result = main.auth_callback(
                response,
                code="provider-code",
                state=state,
                oauth_error=None,
                oauth_state_cookie=state,
            )
        self.assertIsInstance(result, dict)
        self.assertTrue(result["identity_verified"])
        self.assertTrue(result["oauth_state_consumed"])
        self.assertTrue(result["access_token_issued"])
        serialized_result = json.dumps(result)
        self.assertNotIn("eyJ", serialized_result)
        self.assertNotIn("csr_", serialized_result)
        set_cookie_headers = [value.decode("latin-1") for key, value in response.raw_headers if key == b"set-cookie"]
        self.assertTrue(any(header.startswith(main.AUTH_ACCESS_COOKIE + "=") for header in set_cookie_headers))
        self.assertTrue(any(header.startswith(main.AUTH_REFRESH_COOKIE + "=") for header in set_cookie_headers))
        active_records = [key for key in client.values if key.startswith(main.AUTH_REFRESH_ACTIVE_PREFIX)]
        self.assertEqual(len(active_records), 1)
        audit_details = json.dumps(audit.call_args.args[1])
        self.assertNotIn("provider-code", audit_details)
        self.assertNotIn(state, audit_details)

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_html_callback_returns_strict_same_origin_workbench_redirect_with_auth_cookies(self) -> None:
        client = FakeRedis()
        state = "phase3-auth-state-" + ("H" * 32)
        main.register_oauth_state(client, state)
        path = "/api/v1/auth/callback?" + urllib.parse.urlencode({"code": "provider-code", "state": state})
        with (
            patch.object(main, "redis_client", return_value=client),
            patch.object(main, "persist_auth_audit", return_value=True),
            patch.object(main, "exchange_github_identity", return_value="github:123") as exchange,
        ):
            response = asyncio.run(
                asgi_get(
                    path,
                    f"{main.AUTH_OAUTH_STATE_COOKIE}={state}",
                    {"accept": "text/html,application/xhtml+xml;q=0.9"},
                )
            )

        self.assertEqual(response.status_code, 303)
        location = urllib.parse.urlsplit(response.headers["location"])
        self.assertEqual((location.scheme, location.netloc, location.path), ("https", "example.test", "/workbench"))
        self.assertEqual(location.query, "")
        self.assertEqual(location.fragment, "")
        self.assertEqual(response.content, b"")
        self.assertIn("no-store", response.headers["cache-control"])
        self.assertEqual(response.headers["referrer-policy"], "no-referrer")
        set_cookie_headers = response.headers.get_list("set-cookie")
        self.assertTrue(any(header.startswith(main.AUTH_OAUTH_STATE_COOKIE + '=""') for header in set_cookie_headers))
        self.assertTrue(any(header.startswith(main.AUTH_ACCESS_COOKIE + "=") for header in set_cookie_headers))
        self.assertTrue(any(header.startswith(main.AUTH_REFRESH_COOKIE + "=") for header in set_cookie_headers))
        self.assertEqual(len([key for key in client.values if key.startswith(main.AUTH_REFRESH_ACTIVE_PREFIX)]), 1)
        exchange.assert_called_once_with("provider-code", ANY)

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_auth_me_verifies_cookie_jwt_without_returning_credential_material(self) -> None:
        now = 2_000_000_000
        with patch.object(main.time, "time", return_value=now):
            token = main.create_access_jwt("github:123", "auth-me-test")
            response = asyncio.run(asgi_get("/api/v1/auth/me", f"{main.AUTH_ACCESS_COOKIE}={token}"))

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(
            payload["identity"],
            {"provider": "github", "provider_user_id": 123, "subject": "github:123"},
        )
        self.assertEqual(payload["trace_id"], "auth-me-test")
        self.assertTrue(payload["identity_verified"])
        self.assertTrue(payload["jwt_signature_verified"])
        self.assertTrue(payload["jwt_claims_verified"])
        self.assertFalse(payload["token_returned"])
        self.assertFalse(payload["cookie_returned"])
        self.assertFalse(payload["secret_output"])
        self.assertIn("no-store", response.headers["cache-control"])
        self.assertEqual(response.headers["referrer-policy"], "no-referrer")
        self.assertNotIn("access_token", payload)
        self.assertNotIn("refresh_token", payload)
        self.assertNotIn(token, response.text)

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_auth_me_rejects_missing_tampered_and_expired_tokens_fail_closed(self) -> None:
        now = 2_000_000_000
        with patch.object(main.time, "time", return_value=now):
            token = main.create_access_jwt("github:123", "auth-me-test")
            replacement = "A" if not token.endswith("A") else "B"
            cases = (
                ("missing", ""),
                ("tampered", token[:-1] + replacement),
            )
            for label, supplied in cases:
                with self.subTest(case=label):
                    cookie = f"{main.AUTH_ACCESS_COOKIE}={supplied}" if supplied else ""
                    response = asyncio.run(asgi_get("/api/v1/auth/me", cookie))
                    self.assertEqual(response.status_code, 401)
                    self.assertEqual(response.json()["error"], "access_token_invalid")
                    self.assertIn("Max-Age=0", response.headers["set-cookie"])
                    self.assertIn("no-store", response.headers["cache-control"])
                    self.assertEqual(response.headers["referrer-policy"], "no-referrer")
                    if supplied:
                        self.assertNotIn(supplied, response.text)

        with patch.object(main.time, "time", return_value=now + main.AUTH_ACCESS_TOKEN_TTL_SECONDS):
            expired = asyncio.run(asgi_get("/api/v1/auth/me", f"{main.AUTH_ACCESS_COOKIE}={token}"))
        self.assertEqual(expired.status_code, 401)
        self.assertEqual(expired.json()["error"], "access_token_invalid")
        self.assertNotIn(token, expired.text)

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_auth_me_rejects_signed_algorithm_issuer_audience_and_subject_drift(self) -> None:
        now = 2_000_000_000
        cases = (
            ("algorithm", {"alg": "none"}, {}),
            ("issuer", {}, {"iss": "other-issuer"}),
            ("audience", {}, {"aud": "other-audience"}),
            ("zero-subject", {}, {"sub": "github:0"}),
            ("non-github-subject", {}, {"sub": "name:123"}),
        )
        with patch.object(main.time, "time", return_value=now):
            for label, header_overrides, payload_overrides in cases:
                with self.subTest(case=label):
                    token = signed_access_token(
                        now,
                        header_overrides=header_overrides,
                        payload_overrides=payload_overrides,
                    )
                    response = asyncio.run(
                        asgi_get("/api/v1/auth/me", f"{main.AUTH_ACCESS_COOKIE}={token}")
                    )
                    self.assertEqual(response.status_code, 401)
                    self.assertEqual(response.json()["error"], "access_token_invalid")
                    self.assertNotIn(token, response.text)

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_callback_audit_failure_issues_no_credentials(self) -> None:
        client = FakeRedis()
        state = "phase3-auth-state-" + ("A" * 32)
        main.register_oauth_state(client, state)
        response = Response()
        with (
            patch.object(main, "redis_client", return_value=client),
            patch.object(main, "persist_auth_audit", return_value=False),
            patch.object(main, "exchange_github_identity", return_value="github:123"),
        ):
            with self.assertRaises(HTTPException) as raised:
                main.auth_callback(
                    response,
                    code="provider-code",
                    state=state,
                    oauth_error=None,
                    oauth_state_cookie=state,
                )
        self.assertEqual(raised.exception.status_code, 503)
        self.assertEqual(raised.exception.detail["error"], "auth_audit_unavailable")
        self.assertIsNone(client.get(main.auth_oauth_state_key(state)))
        self.assertFalse(any(key.startswith(main.AUTH_REFRESH_ACTIVE_PREFIX) for key in client.values))
        self.assertFalse(
            any(
                value.decode("latin-1").startswith((main.AUTH_ACCESS_COOKIE + "=", main.AUTH_REFRESH_COOKIE + "="))
                for key, value in response.raw_headers
                if key == b"set-cookie"
            )
        )
        actual_response = render_http_exception(raised.exception)
        self.assertIn("Max-Age=0", actual_response.headers["set-cookie"])

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
        },
        clear=True,
    )
    def test_provider_failure_consumes_state_and_clears_cookie_on_error(self) -> None:
        client = FakeRedis()
        state = "phase3-auth-state-" + ("P" * 32)
        main.register_oauth_state(client, state)
        provider_error = HTTPException(
            status_code=401,
            detail={"error": "oauth_code_exchange_failed", "credentials_issued": False},
        )
        with (
            patch.object(main, "redis_client", return_value=client),
            patch.object(main, "persist_auth_audit") as audit,
            patch.object(main, "exchange_github_identity", side_effect=provider_error),
        ):
            with self.assertRaises(HTTPException) as raised:
                main.auth_callback(
                    Response(),
                    code="rejected-code",
                    state=state,
                    oauth_error=None,
                    oauth_state_cookie=state,
                )
        self.assertIsNone(client.get(main.auth_oauth_state_key(state)))
        actual_response = render_http_exception(raised.exception)
        self.assertIn("Max-Age=0", actual_response.headers["set-cookie"])
        audit_details = json.dumps(audit.call_args.args[1])
        self.assertNotIn("rejected-code", audit_details)
        self.assertNotIn(state, audit_details)

    def test_provider_json_shapes_fail_closed_without_redirect_following(self) -> None:
        for malformed_stage in ("token", "identity"):
            with self.subTest(stage=malformed_stage):
                client = MagicMock()
                client.__enter__.return_value = client
                token_response = MagicMock(status_code=200)
                token_response.json.return_value = [] if malformed_stage == "token" else {"access_token": "gho_" + ("x" * 32)}
                identity_response = MagicMock(status_code=200)
                identity_response.json.return_value = []
                client.post.return_value = token_response
                client.get.return_value = identity_response
                with patch.object(main.httpx, "Client", return_value=client) as client_factory:
                    with self.assertRaises(HTTPException) as raised:
                        main.exchange_github_identity(
                            "provider-code",
                            {
                                "client_id": "client-id",
                                "client_secret": "client-secret",
                                "redirect_uri": "https://example.test/api/v1/auth/callback",
                            },
                        )
                self.assertEqual(raised.exception.status_code, 401)
                expected_error = "oauth_code_exchange_failed" if malformed_stage == "token" else "github_identity_verification_failed"
                self.assertEqual(raised.exception.detail["error"], expected_error)
                client_factory.assert_called_once_with(timeout=10.0, follow_redirects=False)


if __name__ == "__main__":
    unittest.main()
