"""Unit coverage for the memory-worker secret guard (contains_secret).

The guard decides whether a working-memory entry may be consolidated into PostgreSQL.
A miss here means a raw credential is persisted, so the cases below cover credential
shapes that carry no ``key:`` prefix, nested structures, alternative field spellings and
benign look-alikes that must stay consolidatable. Values are synthetic, never real keys.
"""

from __future__ import annotations

import importlib.util
import sys
import types
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
WORKER = REPO_ROOT / "services" / "memory-worker" / "app" / "worker.py"
FAKE = "Zq8LmN3pQ7rT2vX9wY4k"  # synthetic, random-looking, not a credential


def _load_worker():
    """Import worker.py without its runtime drivers (psycopg / redis are not needed here)."""
    stubs = {
        "psycopg": types.ModuleType("psycopg"),
        "psycopg.types": types.ModuleType("psycopg.types"),
        "psycopg.types.json": types.ModuleType("psycopg.types.json"),
        "redis": types.ModuleType("redis"),
    }
    stubs["psycopg"].Connection = object
    stubs["psycopg.types.json"].Json = object
    stubs["redis"].Redis = object
    saved = {name: sys.modules.get(name) for name in stubs}
    sys.modules.update({name: module for name, module in stubs.items() if saved[name] is None})
    try:
        spec = importlib.util.spec_from_file_location("memory_worker_under_test", WORKER)
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        sys.modules[spec.name] = module  # dataclasses resolve annotations via sys.modules
        spec.loader.exec_module(module)
        return module
    finally:
        for name, previous in saved.items():
            if previous is None:
                sys.modules.pop(name, None)


_WORKER = _load_worker()
contains_secret = _WORKER.contains_secret
parse_working_memory = _WORKER.parse_working_memory

MUST_BLOCK = {
    "nested password field": {"a": {"b": [{"password": "hunter2hunter2"}]}},
    "authorization header field": {"headers": {"Authorization": "Bearer " + FAKE}},
    "bearer token in free text": "curl -H 'Authorization: Bearer " + FAKE + FAKE + "'",
    "connection string with password": "postgresql://admin:" + FAKE + "@db.internal:5432/prod",
    "pem private key": "-----BEGIN PRIVATE KEY-----\nMIIEv" + FAKE + "\n-----END PRIVATE KEY-----",
    "rsa private key": "-----BEGIN RSA PRIVATE KEY-----",
    "aws access key id": "AKIA" + "ABCDEFGHIJKLMNOP",
    "jwt in free text": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0." + FAKE,
    "refresh_token field": {"refresh_token": FAKE},
    "db_password field": {"db_password": FAKE},
    "x-api-key field": {"x-api-key": FAKE},
    "upper-case API_TOKEN field": {"API_TOKEN": FAKE},
    "aws_secret_access_key field": {"aws_secret_access_key": FAKE},
    "client_secret field": {"client_secret": FAKE},
    "german Passwort keyword": "Passwort: " + FAKE,
    "slack bot token": "xoxb-1234567890-" + FAKE,
    "ghp token deep in lists": [[[["x", {"k": "ghp_" + FAKE}]]]],
    "token keyword in text": "token: " + FAKE,
    "secret in dict key itself": {"ghp_" + FAKE: "value"},
}

MUST_ALLOW = {
    "benign prose mentioning passwords": {"note": "Das Passwort-Feld muss validiert werden", "tags": ["token-limit", "secret-santa"]},
    "short password placeholder": {"password": "x"},
    "empty and null credential fields": {"token": None, "secret": ""},
    "numeric token counters": {"max_tokens": "4096", "total_tokens": 1234, "token_count": "123456789"},
    "tokenizer name": {"tokenizer": "cl100k_base"},
    "plain url without credentials": "https://example.org/docs?page=2",
    "deeply nested benign": {"a": [{"b": [{"c": {"d": "hello world"}}]}]},
}


class MemoryWorkerSecretGuardTests(unittest.TestCase):
    def test_credential_shapes_are_blocked(self) -> None:
        for name, value in MUST_BLOCK.items():
            with self.subTest(case=name):
                self.assertTrue(contains_secret(value), f"secret not detected: {name}")

    def test_benign_values_stay_consolidatable(self) -> None:
        for name, value in MUST_ALLOW.items():
            with self.subTest(case=name):
                self.assertFalse(contains_secret(value), f"false positive: {name}")

    def test_very_deep_nesting_does_not_hide_a_secret(self) -> None:
        value: object = {"password": "hunter2hunter2"}
        for _ in range(20):
            value = {"nested": [value]}
        self.assertTrue(contains_secret(value))

    def test_hostile_nesting_fails_closed_instead_of_crashing(self) -> None:
        """Nesting far beyond Python's recursion limit must not raise and must block persistence."""
        value: object = "harmless"
        for _ in range(5_000):
            value = {"nested": [value]}
        self.assertTrue(contains_secret(value))

    def test_moderate_benign_nesting_is_allowed(self) -> None:
        value: object = "harmless"
        for _ in range(15):
            value = {"nested": [value]}
        self.assertFalse(contains_secret(value))


class MemoryWorkerPoisonPillTests(unittest.TestCase):
    """A single hostile Redis value must not abort the consolidation pass for every other key."""

    def test_non_object_payloads_are_invalid_not_crashing(self) -> None:
        for raw in (b"[1, 2]", b'"text"', b"42", b"null", b"\xff\xfe"):
            with self.subTest(raw=raw):
                self.assertIsNone(parse_working_memory("memory:working:x", raw))

    def test_hostile_json_nesting_is_invalid_not_crashing(self) -> None:
        depth = 100_000
        raw = ('{"project_id":"p","content_text":"c","metadata":' + '{"a":' * depth + "1" + "}" * depth + "}").encode()
        self.assertIsNone(parse_working_memory("memory:working:x", raw))

    def test_regular_payload_still_parses(self) -> None:
        raw = b'{"project_id":"p","content_text":"hello","metadata":{"nested":{"k":"v"}}}'
        memory = parse_working_memory("memory:working:x", raw)
        self.assertIsNotNone(memory)
        self.assertEqual("p", memory.project_id)
        self.assertEqual({"nested": {"k": "v"}}, memory.metadata)


if __name__ == "__main__":
    unittest.main()
