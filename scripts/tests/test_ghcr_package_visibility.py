from __future__ import annotations

import json
import unittest
import urllib.error

from scripts.verify_ghcr_package_visibility import SERVICES, VisibilityError, verify_visibility


class Response:
    def __init__(self, payload: dict[str, object], status: int = 200) -> None:
        self.status = status
        self._body = json.dumps(payload).encode("utf-8")

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self) -> bytes:
        return self._body


class GhcrPackageVisibilityTests(unittest.TestCase):
    owner = "strazzusochr"
    namespace = "cloud-superbrain-developer-platform"

    def package_name(self, request) -> str:
        encoded = request.full_url.rsplit("/", 1)[-1]
        from urllib.parse import unquote

        return unquote(encoded)

    def test_six_existing_private_packages_pass_read_only(self) -> None:
        requests = []

        def open_private(request, timeout):
            self.assertEqual(timeout, 20)
            requests.append(request)
            name = self.package_name(request)
            return Response({"name": name, "package_type": "container", "visibility": "private"})

        self.assertEqual(verify_visibility(self.owner, self.namespace, "not-output", opener=open_private), (6, 0))
        self.assertEqual(len(requests), len(SERVICES))
        self.assertTrue(all(request.method == "GET" for request in requests))

    def test_absent_packages_are_allowed_before_first_publish(self) -> None:
        def open_absent(request, timeout):
            raise urllib.error.HTTPError(request.full_url, 404, "Not Found", {}, None)

        self.assertEqual(verify_visibility(self.owner, self.namespace, "not-output", opener=open_absent), (0, 6))

    def test_public_or_internal_package_fails_closed(self) -> None:
        for visibility in ("public", "internal"):
            with self.subTest(visibility=visibility):
                def open_visible(request, timeout):
                    name = self.package_name(request)
                    return Response({"name": name, "package_type": "container", "visibility": visibility})

                with self.assertRaisesRegex(VisibilityError, "not private"):
                    verify_visibility(self.owner, self.namespace, "not-output", opener=open_visible)

    def test_identity_type_auth_and_shape_fail_closed(self) -> None:
        def wrong_name(request, timeout):
            return Response({"name": "foreign", "package_type": "container", "visibility": "private"})

        with self.assertRaisesRegex(VisibilityError, "identity mismatch"):
            verify_visibility(self.owner, self.namespace, "not-output", opener=wrong_name)
        with self.assertRaisesRegex(VisibilityError, "token is unavailable"):
            verify_visibility(self.owner, self.namespace, "", opener=wrong_name)

        def forbidden(request, timeout):
            raise urllib.error.HTTPError(request.full_url, 403, "Forbidden", {}, None)

        with self.assertRaisesRegex(VisibilityError, "HTTP 403"):
            verify_visibility(self.owner, self.namespace, "not-output", opener=forbidden)


if __name__ == "__main__":
    unittest.main()
