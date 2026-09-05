from __future__ import annotations

import asyncio
import json
import os
import threading
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


async def asgi_request(
    method: str,
    path: str,
    *,
    json_body: object | None = None,
    cookie_header: str = "",
    extra_headers: dict[str, str] | None = None,
) -> httpx.Response:
    headers = {"origin": "https://example.test", "sec-fetch-site": "same-origin", **(extra_headers or {})}
    if cookie_header:
        headers["cookie"] = cookie_header
    transport = httpx.ASGITransport(app=main.app)
    async with httpx.AsyncClient(transport=transport, base_url="https://example.test") as client:
        return await client.request(method, path, headers=headers, json=json_body)


async def invoke_mutation_guard(
    method: str,
    path: str,
    *,
    headers: dict[str, str] | None = None,
    query_string: str = "",
) -> tuple[Response, bool]:
    encoded_headers = [
        (name.lower().encode("latin-1"), value.encode("latin-1")) for name, value in (headers or {}).items()
    ]
    scope = {
        "type": "http",
        "http_version": "1.1",
        "method": method,
        "scheme": "https",
        "path": path,
        "raw_path": path.encode("ascii"),
        "query_string": query_string.encode("ascii"),
        "headers": encoded_headers,
        "client": ("127.0.0.1", 12345),
        "server": ("example.test", 443),
        "root_path": "",
    }
    request = main.Request(scope)
    called = False

    async def call_next(_request: main.Request) -> Response:
        nonlocal called
        called = True
        return Response(status_code=204)

    response = await main.production_mutation_authorization_middleware(request, call_next)
    return response, called


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
        self.lock = threading.RLock()

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

    def _revoke_family(self, family_id: str | None, reason: str) -> bool:
        if not family_id:
            return False
        family_key = main.auth_refresh_family_key(family_id)
        raw = self.values.get(family_key)
        if not raw:
            return False
        family = json.loads(raw)
        current_hash = family.get("current_token_hash")
        if current_hash:
            self.values.pop(main.AUTH_REFRESH_ACTIVE_PREFIX + current_hash, None)
        family.update(status="revoked", current_token_hash="", revoked_reason=reason)
        self.values[family_key] = json.dumps(family, separators=(",", ":"), sort_keys=True)
        return True

    def eval(self, script: str, numkeys: int, *arguments: object) -> object:
        keys = [str(item) for item in arguments[:numkeys]]
        argv = [str(item) for item in arguments[numkeys:]]
        with self.lock:
            if script == main._AUTH_OAUTH_RATE_LIMIT_SCRIPT:
                count = int(self.values.get(keys[0], "0")) + 1
                self.values[keys[0]] = str(count)
                return [count, int(argv[0])]
            if script == main._AUTH_REFRESH_INITIAL_REGISTER_SCRIPT:
                if keys[0] in self.values or keys[1] in self.values:
                    return 0
                subject, family_id, token_hash, issued_at = argv[1], argv[2], argv[3], int(argv[4])
                self.values[keys[0]] = json.dumps(
                    {"subject": subject, "family_id": family_id, "generation": 0, "issued_at": issued_at},
                    separators=(",", ":"),
                    sort_keys=True,
                )
                self.values[keys[1]] = json.dumps(
                    {
                        "subject": subject,
                        "family_id": family_id,
                        "generation": 0,
                        "status": "active",
                        "current_token_hash": token_hash,
                    },
                    separators=(",", ":"),
                    sort_keys=True,
                )
                return 1
            if script == main._AUTH_REFRESH_ROTATED_REGISTER_SCRIPT:
                if keys[0] in self.values or keys[1] not in self.values:
                    return 0
                family = json.loads(self.values[keys[1]])
                subject, family_id, new_hash, predecessor_hash, issued_at = (
                    argv[1], argv[2], argv[3], argv[4], int(argv[5])
                )
                if (
                    family.get("status") != "rotating"
                    or family.get("family_id") != family_id
                    or family.get("subject") != subject
                    or family.get("previous_token_hash") != predecessor_hash
                ):
                    return 0
                generation = int(family.get("generation", 0)) + 1
                self.values[keys[0]] = json.dumps(
                    {
                        "subject": subject,
                        "family_id": family_id,
                        "generation": generation,
                        "issued_at": issued_at,
                    },
                    separators=(",", ":"),
                    sort_keys=True,
                )
                family.update(
                    generation=generation,
                    status="active",
                    current_token_hash=new_hash,
                    previous_token_hash=predecessor_hash,
                )
                self.values[keys[1]] = json.dumps(family, separators=(",", ":"), sort_keys=True)
                return 1
            if script == main._AUTH_REFRESH_CONSUME_SCRIPT:
                reason, token_hash = argv[1], argv[2]
                if keys[1] in self.values:
                    self._revoke_family(self.values.get(keys[2]), "replay")
                    return ["", "blacklisted"]
                record_raw = self.values.pop(keys[0], None)
                if not record_raw:
                    return ["", "unknown"]
                try:
                    record = json.loads(record_raw)
                except json.JSONDecodeError:
                    self.values[keys[1]] = "invalid_record"
                    return ["", "invalid_record"]
                family_id = record.get("family_id")
                self.values[keys[1]] = reason
                if family_id:
                    self.values[keys[2]] = str(family_id)
                family_raw = self.values.get(main.auth_refresh_family_key(str(family_id)))
                family = json.loads(family_raw) if family_raw else None
                if (
                    not isinstance(family, dict)
                    or family.get("status") != "active"
                    or family.get("current_token_hash") != token_hash
                    or family.get("subject") != record.get("subject")
                ):
                    self._revoke_family(str(family_id) if family_id else None, "invalid_family")
                    return ["", "invalid_family"]
                if reason == "rotated":
                    family.update(status="rotating", previous_token_hash=token_hash, current_token_hash="")
                    self.values[main.auth_refresh_family_key(str(family_id))] = json.dumps(
                        family, separators=(",", ":"), sort_keys=True
                    )
                else:
                    self._revoke_family(str(family_id), reason)
                return [record_raw, ""]
            if script == main._AUTH_REFRESH_REVOKE_FAMILY_SCRIPT:
                family_id = keys[0].removeprefix(main.AUTH_REFRESH_FAMILY_PREFIX)
                return int(self._revoke_family(family_id, argv[2]))
            if script == main._AUTH_REFRESH_VERIFY_FAMILY_SCRIPT:
                family_raw = self.values.get(keys[0])
                active_raw = self.values.get(keys[1])
                if not family_raw or not active_raw:
                    return 0
                family = json.loads(family_raw)
                active = json.loads(active_raw)
                return int(
                    family.get("status") == "active"
                    and family.get("current_token_hash") == argv[1]
                    and family.get("subject") == argv[0]
                    and active.get("family_id") == family.get("family_id")
                    and active.get("subject") == argv[0]
                )
        raise AssertionError("unexpected Redis Lua script")


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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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

        with (
            patch.object(main, "redis_client", return_value=FakeRedis()),
            patch.object(main, "persist_auth_audit"),
            patch.object(main, "exchange_github_identity") as exchange,
        ):
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
            "GITHUB_OAUTH_OWNER_IDS": "123",
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
    def test_owner_identity_allowlist_is_required_and_never_exposes_ids(self) -> None:
        missing = main.auth_configuration()
        self.assertFalse(missing["credentials_configured"])
        self.assertFalse(missing["owner_identity_allowlist_configured"])
        self.assertIn("GITHUB_OAUTH_OWNER_IDS", missing["missing_configuration"])

        for invalid in ("0", "00123", "123,123", str(main.AUTH_GITHUB_USER_ID_MAX + 1), "true"):
            with self.subTest(invalid=invalid), patch.dict(os.environ, {"GITHUB_OAUTH_OWNER_IDS": invalid}):
                self.assertFalse(main.auth_configuration()["owner_identity_allowlist_configured"])

        with patch.dict(os.environ, {"GITHUB_OAUTH_OWNER_IDS": "123,456"}):
            configuration = main.auth_configuration()
            contract = main.auth_contract_payload()
        self.assertTrue(configuration["credentials_configured"])
        self.assertTrue(contract["owner_identity_allowlist_configured"])
        self.assertEqual(contract["owner_identity_allowlist_count"], 2)
        serialized_contract = json.dumps(contract)
        self.assertNotIn('"123"', serialized_contract)
        self.assertNotIn('"456"', serialized_contract)

    def test_github_identity_rejects_bool_out_of_range_and_unlisted_ids(self) -> None:
        cases = (
            (True, frozenset({1}), 401, "github_identity_verification_failed"),
            (main.AUTH_GITHUB_USER_ID_MAX + 1, frozenset({1}), 401, "github_identity_verification_failed"),
            (456, frozenset({123}), 403, "github_owner_identity_not_allowed"),
        )
        for provider_id, allowed_ids, expected_status, expected_error in cases:
            with self.subTest(provider_id=provider_id):
                client = MagicMock()
                client.__enter__.return_value = client
                token_response = MagicMock(status_code=200)
                token_response.json.return_value = {"access_token": "gho_" + ("x" * 32)}
                identity_response = MagicMock(status_code=200)
                identity_response.json.return_value = {"id": provider_id}
                client.post.return_value = token_response
                client.get.return_value = identity_response
                with patch.object(main.httpx, "Client", return_value=client):
                    with self.assertRaises(HTTPException) as raised:
                        main.exchange_github_identity(
                            "provider-code",
                            {
                                "client_id": "client-id",
                                "client_secret": "client-secret",
                                "redirect_uri": "https://example.test/api/v1/auth/callback",
                                "owner_github_user_ids": allowed_ids,
                            },
                        )
                self.assertEqual(raised.exception.status_code, expected_status)
                self.assertEqual(raised.exception.detail["error"], expected_error)
        self.assertIsNone(main.canonical_github_user_id(True))
        self.assertIsNone(main.canonical_github_user_id(main.AUTH_GITHUB_USER_ID_MAX + 1))

    def test_refresh_replay_and_stale_logout_revoke_successors(self) -> None:
        client = FakeRedis()
        old_token = main.create_refresh_token()
        family_id = main.register_refresh_token(client, old_token, "github:123")
        subject, reason = main.consume_refresh_token(client, old_token, "rotated")
        self.assertEqual((subject, reason), ("github:123", None))
        successor = main.create_refresh_token()
        main.register_refresh_token(
            client,
            successor,
            "github:123",
            family_id=family_id,
            predecessor_token=old_token,
        )
        self.assertIsNotNone(client.get(main.auth_refresh_active_key(successor)))
        self.assertEqual(main.consume_refresh_token(client, old_token, "rotated"), (None, "blacklisted"))
        self.assertIsNone(client.get(main.auth_refresh_active_key(successor)))

        stale = main.create_refresh_token()
        stale_family = main.register_refresh_token(client, stale, "github:123")
        self.assertEqual(main.consume_refresh_token(client, stale, "rotated"), ("github:123", None))
        pending_successor = main.create_refresh_token()
        with patch.object(main, "redis_client", return_value=client), patch.object(
            main, "persist_auth_audit", return_value=True
        ):
            logout = main.auth_logout(Response(), request=None, refresh_token_cookie=stale)
        self.assertFalse(logout["refresh_token_revoked"])
        self.assertEqual(client.get(main.auth_blacklist_key(stale)), "rotated")
        with self.assertRaises(RuntimeError):
            main.register_refresh_token(
                client,
                pending_successor,
                "github:123",
                family_id=stale_family,
                predecessor_token=stale,
            )
        self.assertIsNone(client.get(main.auth_refresh_active_key(pending_successor)))

    def test_redis_failures_still_clear_auth_cookie_pair(self) -> None:
        refresh_response = Response()
        with patch.object(main, "redis_client", side_effect=RuntimeError("redis down")):
            with self.assertRaises(HTTPException) as raised:
                main.auth_refresh(refresh_response, request=None, refresh_token_cookie=main.create_refresh_token())
        self.assertEqual(raised.exception.status_code, 503)
        rendered = render_http_exception(raised.exception)
        clear_headers = rendered.headers.getlist("set-cookie")
        self.assertEqual(len(clear_headers), 2)
        self.assertTrue(all("Max-Age=0" in header for header in clear_headers))

        logout_response = Response()
        with (
            patch.object(main, "redis_client", side_effect=RuntimeError("redis down")),
            patch.object(main, "persist_auth_audit", return_value=False),
        ):
            logout = main.auth_logout(
                logout_response,
                request=None,
                refresh_token_cookie=main.create_refresh_token(),
            )
        self.assertEqual(logout_response.status_code, 503)
        self.assertEqual(logout["status"], "storage_unavailable")
        raw_clear_headers = [
            value.decode("latin-1") for key, value in logout_response.raw_headers if key == b"set-cookie"
        ]
        self.assertEqual(len(raw_clear_headers), 2)
        self.assertTrue(all("Max-Age=0" in header for header in raw_clear_headers))

    def test_validation_errors_do_not_reflect_credential_input(self) -> None:
        credential = "csr_" + ("S" * 700)
        response = asyncio.run(
            asgi_request(
                "POST",
                "/api/v1/auth/refresh",
                json_body={"refresh_token": credential, "trace_id": "validation-redaction"},
            )
        )
        self.assertEqual(response.status_code, 422)
        self.assertNotIn(credential, response.text)
        detail = response.json()["detail"]
        self.assertTrue(detail)
        self.assertTrue(all("input" not in item and "ctx" not in item for item in detail))

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
            "GITHUB_OAUTH_OWNER_IDS": "123",
        },
        clear=True,
    )
    def test_oauth_start_and_exchange_rate_limits_are_bounded(self) -> None:
        client = FakeRedis()
        for _index in range(main.AUTH_OAUTH_START_RATE_LIMIT):
            with patch.object(main, "redis_client", return_value=client):
                self.assertEqual(main.auth_github_start(Response()).status_code, 303)
        with (
            patch.object(main, "redis_client", return_value=client),
            patch.object(main, "persist_auth_audit", return_value=True),
        ):
            with self.assertRaises(HTTPException) as raised:
                main.auth_github_start(Response())
        self.assertEqual(raised.exception.status_code, 429)
        self.assertEqual(raised.exception.detail["error"], "oauth_rate_limit_exceeded")

        exchange_client = FakeRedis()
        counts = [
            main.enforce_oauth_rate_limit(exchange_client, "exchange", main.AUTH_OAUTH_EXCHANGE_RATE_LIMIT)
            for _index in range(main.AUTH_OAUTH_EXCHANGE_RATE_LIMIT + 1)
        ]
        self.assertEqual(counts[-1]["remaining"], 0)
        self.assertGreater(counts[-1]["count"], counts[-1]["limit"])

        route_client = FakeRedis()
        for _index in range(main.AUTH_OAUTH_EXCHANGE_RATE_LIMIT):
            main.enforce_oauth_rate_limit(route_client, "exchange", main.AUTH_OAUTH_EXCHANGE_RATE_LIMIT)
        state = "phase3-auth-state-" + ("L" * 32)
        main.register_oauth_state(route_client, state)
        with (
            patch.object(main, "redis_client", return_value=route_client),
            patch.object(main, "persist_auth_audit", return_value=True),
            patch.object(main, "exchange_github_identity") as exchange,
        ):
            with self.assertRaises(HTTPException) as exchange_limited:
                main.auth_callback(
                    Response(),
                    code="provider-code",
                    state=state,
                    oauth_error=None,
                    oauth_state_cookie=state,
                )
        self.assertEqual(exchange_limited.exception.status_code, 429)
        exchange.assert_not_called()

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
            "GITHUB_OAUTH_OWNER_IDS": "123",
        },
        clear=True,
    )
    def test_rejected_auth_audit_failure_and_configuration_drift_fail_closed(self) -> None:
        client = FakeRedis()
        with (
            patch.object(main, "redis_client", return_value=client),
            patch.object(main, "persist_auth_audit", return_value=False),
        ):
            with self.assertRaises(HTTPException) as rejected:
                main.auth_callback(Response(), code="unused", state="invalid", oauth_state_cookie="invalid")
        self.assertEqual(rejected.exception.status_code, 503)
        self.assertEqual(rejected.exception.detail["error"], "auth_audit_unavailable")

        state = "phase3-auth-state-" + ("R" * 32)
        client = FakeRedis()
        main.register_oauth_state(client, state)
        ready = main.auth_configuration()
        blocked = {**ready, "owner_activation_granted": False, "credential_issuance_ready": False}
        with (
            patch.object(main, "redis_client", return_value=client),
            patch.object(main, "auth_configuration", side_effect=[ready, blocked]),
            patch.object(main, "exchange_github_identity", return_value="github:123"),
            patch.object(main, "persist_auth_audit", return_value=True),
        ):
            with self.assertRaises(HTTPException) as drifted:
                main.auth_callback(
                    Response(),
                    code="provider-code",
                    state=state,
                    oauth_error=None,
                    oauth_state_cookie=state,
                )
        self.assertEqual(drifted.exception.status_code, 403)
        self.assertFalse(any(key.startswith(main.AUTH_REFRESH_ACTIVE_PREFIX) for key in client.values))

    @patch.dict(
        os.environ,
        {
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
            "GITHUB_OAUTH_OWNER_IDS": "123",
        },
        clear=True,
    )
    def test_owner_false_refresh_is_forbidden_not_service_unavailable(self) -> None:
        client = FakeRedis()
        token = main.create_refresh_token()
        main.register_refresh_token(client, token, "github:123")
        self.capability_gate_state_mock.return_value = {
            "gates": {"production_auth_identity": {"owner_granted": False, "live_verified": False}}
        }
        with patch.object(main, "redis_client", return_value=client), patch.object(
            main, "persist_auth_audit", return_value=True
        ):
            with self.assertRaises(HTTPException) as raised:
                main.auth_refresh(Response(), request=None, refresh_token_cookie=token)
        self.assertEqual(raised.exception.status_code, 403)
        self.assertEqual(raised.exception.detail["error"], "production_auth_owner_activation_required")
        self.assertIsNotNone(client.get(main.auth_refresh_active_key(token)))

    @patch.dict(
        os.environ,
        {
            "SUPERBRAIN_RUNTIME_MODE": "production",
            "AGENT_API_AUTH_TOKEN": "service-boundary-value",
            "GITHUB_OAUTH_CLIENT_ID": "client-id",
            "GITHUB_OAUTH_CLIENT_SECRET": "client-secret",
            "GITHUB_OAUTH_REDIRECT_URI": "https://example.test/api/v1/auth/callback",
            "JWT_SIGNING_SECRET": TEST_SIGNING_SECRET,
            "GITHUB_OAUTH_OWNER_IDS": "123",
        },
        clear=True,
    )
    def test_oauth_display_identity_cannot_authorize_production_mutations(self) -> None:
        oauth_jwt = main.create_access_jwt("github:123", "mutation-auth-test")
        headers = {"authorization": f"Bearer {oauth_jwt}"}
        cookie = f"{main.AUTH_ACCESS_COOKIE}={oauth_jwt}"
        with patch.object(main, "persist_mutation_authorization_rejection_audit", return_value=True):
            prompt = asyncio.run(
                asgi_request(
                    "POST",
                    "/api/v1/prompt",
                    json_body={"project_id": "authz-test", "prompt": "must not persist"},
                    cookie_header=cookie,
                    extra_headers=headers,
                )
            )
            memory_delete = asyncio.run(
                asgi_request(
                    "DELETE",
                    "/api/v1/memory?project_id=authz-test&confirm=true",
                    cookie_header=cookie,
                    extra_headers=headers,
                )
            )
        for response in (prompt, memory_delete):
            self.assertEqual(response.status_code, 401)
            self.assertEqual(response.json()["error"], "service_authorization_required")
            self.assertFalse(response.json()["detail"]["mutation_performed"])
            self.assertTrue(response.json()["audit_persisted"])
            self.assertNotIn(oauth_jwt, response.text)
        self.assertFalse(main._build_registry_authenticated(oauth_jwt))
        with patch.object(main, "persist_mutation_authorization_rejection_audit", return_value=True):
            jwt_in_service_header = asyncio.run(
                asgi_request(
                    "POST",
                    "/api/v1/prompt",
                    json_body={"project_id": "authz-test", "prompt": "must not persist"},
                    extra_headers={"x-superbrain-agent-token": oauth_jwt},
                )
            )
        self.assertEqual(jwt_in_service_header.status_code, 401)
        self.assertNotIn(oauth_jwt, jwt_in_service_header.text)

        with (
            patch.dict(os.environ, {"AGENT_API_AUTH_TOKEN": ""}),
            patch.object(main, "persist_mutation_authorization_rejection_audit", return_value=True),
        ):
            unavailable = asyncio.run(
                asgi_request(
                    "POST",
                    "/api/v1/prompt",
                    json_body={"project_id": "authz-test", "prompt": "must not persist"},
                )
            )
        self.assertEqual(unavailable.status_code, 503)
        self.assertEqual(unavailable.json()["error"], "service_authorization_unavailable")

        with patch.dict(os.environ, {"SUPERBRAIN_RUNTIME_MODE": "dev-only"}):
            dev_only_validation = asyncio.run(
                asgi_request("POST", "/api/v1/prompt", json_body={"project_id": "authz-test", "prompt": ""})
            )
        self.assertEqual(dev_only_validation.status_code, 422)

    def test_production_mutation_guard_exact_methods_paths_modes_and_audit(self) -> None:
        self.assertEqual(
            main._PRODUCTION_MUTATION_SAFE_PATHS,
            {
                "/api/v1/auth/refresh",
                "/api/v1/auth/logout",
                "/api/v1/security/csp/report",
                "/api/v1/security/csrf/probe",
            },
        )
        protected_paths = ("/api/v1/generic-mutation", "/internal/generic-mutation")
        with patch.dict(
            os.environ,
            {"SUPERBRAIN_RUNTIME_MODE": "production", "AGENT_API_AUTH_TOKEN": "exact-service-token"},
            clear=True,
        ):
            for method in ("POST", "PUT", "PATCH", "DELETE"):
                for path in protected_paths:
                    with self.subTest(method=method, path=path), patch.object(
                        main, "persist_mutation_authorization_rejection_audit", return_value=True
                    ) as audit:
                        blocked, called = asyncio.run(invoke_mutation_guard(method, path))
                    self.assertEqual(blocked.status_code, 401)
                    self.assertFalse(called)
                    self.assertTrue(json.loads(blocked.body)["audit_persisted"])
                    audit.assert_called_once()

                    allowed, called = asyncio.run(
                        invoke_mutation_guard(
                            method,
                            path,
                            headers={"x-superbrain-agent-token": "exact-service-token"},
                        )
                    )
                    self.assertEqual(allowed.status_code, 204)
                    self.assertTrue(called)

            for safe_path in main._PRODUCTION_MUTATION_SAFE_PATHS:
                with self.subTest(safe_path=safe_path), patch.object(
                    main, "persist_mutation_authorization_rejection_audit"
                ) as audit:
                    allowed, called = asyncio.run(
                        invoke_mutation_guard("POST", safe_path, query_string="lookalike=1")
                    )
                self.assertEqual(allowed.status_code, 204)
                self.assertTrue(called)
                audit.assert_not_called()

            lookalikes = (
                "/api/v1/auth/refresh/",
                "/api/v1/auth/Refresh",
                "/api/v1/auth/logout-extra",
                "/api/v1/security/csp/report/extra",
                "/api/v1/security/csrf/probe%2Fextra",
            )
            for path in lookalikes:
                with self.subTest(lookalike=path), patch.object(
                    main, "persist_mutation_authorization_rejection_audit", return_value=True
                ):
                    blocked, called = asyncio.run(invoke_mutation_guard("POST", path))
                self.assertEqual(blocked.status_code, 401)
                self.assertFalse(called)

            with patch.object(main, "persist_mutation_authorization_rejection_audit", return_value=False):
                audit_down, called = asyncio.run(invoke_mutation_guard("POST", "/api/v1/prompt"))
            self.assertEqual(audit_down.status_code, 503)
            self.assertEqual(json.loads(audit_down.body)["error"], "security_audit_unavailable")
            self.assertFalse(json.loads(audit_down.body)["audit_persisted"])
            self.assertFalse(called)

        for runtime_mode, expected_bypass in (
            ("dev-only", True),
            ("", False),
            ("production", False),
            ("development", False),
            ("DEV-ONLY", False),
            ("dev-only ", False),
        ):
            with (
                self.subTest(runtime_mode=runtime_mode),
                patch.dict(
                    os.environ,
                    {"SUPERBRAIN_RUNTIME_MODE": runtime_mode, "AGENT_API_AUTH_TOKEN": "exact-service-token"},
                    clear=True,
                ),
                patch.object(main, "persist_mutation_authorization_rejection_audit", return_value=True),
            ):
                response, called = asyncio.run(invoke_mutation_guard("POST", "/api/v1/prompt"))
            self.assertEqual(called, expected_bypass)
            self.assertEqual(response.status_code, 204 if expected_bypass else 401)

    def test_mutation_rejection_audit_persists_no_path_or_credential_values(self) -> None:
        credential = "eyJ" + ("A" * 40) + "." + ("B" * 40) + "." + ("C" * 40)
        path = "/api/v1/" + credential
        headers = {
            "authorization": f"Bearer {credential}",
            "cookie": f"{main.AUTH_ACCESS_COOKIE}={credential}",
            "x-superbrain-agent-token": credential,
        }
        scope = {
            "type": "http",
            "http_version": "1.1",
            "method": "POST",
            "scheme": "https",
            "path": path,
            "raw_path": path.encode("ascii"),
            "query_string": b"",
            "headers": [(key.encode("ascii"), value.encode("ascii")) for key, value in headers.items()],
            "client": ("127.0.0.1", 12345),
            "server": ("example.test", 443),
            "root_path": "",
        }
        connection = MagicMock()
        connection.__enter__.return_value = connection
        with (
            patch.object(main, "database_url", return_value="postgresql://audit.invalid/test"),
            patch.object(main.psycopg, "connect", return_value=connection),
            patch.object(main, "redact_json", side_effect=lambda value: value) as redact,
        ):
            persisted = main.persist_mutation_authorization_rejection_audit(
                main.Request(scope), "service_authorization_required"
            )
        self.assertTrue(persisted)
        details = redact.call_args.args[0]
        serialized = json.dumps(details)
        self.assertNotIn(credential, serialized)
        self.assertNotIn(path, serialized)
        self.assertEqual(details["path_scope"], "api")
        self.assertFalse(details["raw_path_persisted"])
        self.assertTrue(details["service_token_present"])
        self.assertTrue(details["authorization_header_present"])
        self.assertTrue(details["oauth_access_cookie_present"])

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
