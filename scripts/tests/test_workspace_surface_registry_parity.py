"""Workspace surface registry parity between backend and frontend.

The surface list exists twice: ORGANISM_PAGES in the agent-api (which feeds
GET /api/v1/workspace/wiring) and WORKSPACE_PAGES in the frontend (which feeds
the navigation and the command palette). Nothing enforced that the two agree.

When they drift, the runtime breaks in a way that is hard to read: the wiring
endpoint advertises a surface that the command palette cannot offer, and
scripts/verify-workspace-responsive-browser.cjs then fails with
"Command palette route is not unique or missing: <route>" instead of naming the
desync. These tests bind the two lists together at source level, so the drift is
caught without needing a running container.
"""

from __future__ import annotations

import ast
import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
AGENT_API = REPO_ROOT / "services" / "agent-api" / "app" / "main.py"
FRONTEND_NAV = REPO_ROOT / "apps" / "frontend" / "lib" / "nav.tsx"
FRONTEND_WIRING = REPO_ROOT / "apps" / "frontend" / "lib" / "workspaceWiring.ts"


def backend_pages() -> list[tuple[int, str, str]]:
    """Return (no, page_id, route) from the agent-api ORGANISM_PAGES literal."""
    source = AGENT_API.read_text(encoding="utf-8")
    match = re.search(r"^ORGANISM_PAGES = (\[.*?^\])", source, re.S | re.M)
    if not match:
        raise AssertionError("ORGANISM_PAGES literal not found in agent-api main.py")
    parsed = ast.literal_eval(match.group(1))
    return [(int(row[0]), str(row[1]), str(row[2])) for row in parsed]


def frontend_pages() -> list[tuple[int, str, str]]:
    """Return (no, id, route) from the frontend WORKSPACE_PAGES literal."""
    source = FRONTEND_NAV.read_text(encoding="utf-8")
    match = re.search(r"WORKSPACE_PAGES[^=]*=\s*\[(.*?)^\]", source, re.S | re.M)
    if not match:
        raise AssertionError("WORKSPACE_PAGES literal not found in nav.tsx")
    rows: list[tuple[int, str, str]] = []
    for entry in re.finditer(r"\{[^{}]*\}", match.group(1)):
        text = entry.group(0)
        page_id = re.search(r'id:\s*"([^"]+)"', text)
        no = re.search(r"no:\s*(\d+)", text)
        route = re.search(r'route:\s*"([^"]+)"', text)
        if page_id and no and route:
            rows.append((int(no.group(1)), page_id.group(1), route.group(1)))
    if not rows:
        raise AssertionError("No WORKSPACE_PAGES entries parsed from nav.tsx")
    return rows


def wiring_page_ids() -> list[str]:
    source = FRONTEND_WIRING.read_text(encoding="utf-8")
    match = re.search(r"WORKSPACE_WIRING[^=]*=\s*\[(.*?)^\]", source, re.S | re.M)
    if not match:
        raise AssertionError("WORKSPACE_WIRING literal not found in workspaceWiring.ts")
    return re.findall(r'pageId:\s*"([^"]+)"', match.group(1))


class WorkspaceSurfaceRegistryParity(unittest.TestCase):
    def test_backend_and_frontend_expose_the_same_routes(self) -> None:
        backend = {route for _, _, route in backend_pages()}
        frontend = {route for _, _, route in frontend_pages()}
        only_backend = sorted(backend - frontend)
        only_frontend = sorted(frontend - backend)
        self.assertEqual(
            ([], []),
            (only_backend, only_frontend),
            "Workspace surface registry drift: routes advertised by "
            f"/api/v1/workspace/wiring but absent from the frontend navigation/command "
            f"palette: {only_backend}; routes in the frontend but not advertised by the "
            f"backend: {only_frontend}. Both lists must be updated together.",
        )

    def test_backend_and_frontend_agree_on_page_ids(self) -> None:
        backend = {page_id for _, page_id, _ in backend_pages()}
        frontend = {page_id for _, page_id, _ in frontend_pages()}
        self.assertEqual(backend, frontend, "Workspace page ids drifted between backend and frontend")

    def test_ordering_numbers_match(self) -> None:
        backend = {page_id: no for no, page_id, _ in backend_pages()}
        frontend = {page_id: no for no, page_id, _ in frontend_pages()}
        mismatched = {
            page_id: (backend[page_id], frontend[page_id])
            for page_id in backend.keys() & frontend.keys()
            if backend[page_id] != frontend[page_id]
        }
        self.assertEqual({}, mismatched, "Surface ordering (no) differs backend vs frontend")

    def test_ordering_numbers_are_unique_and_contiguous(self) -> None:
        numbers = sorted(no for no, _, _ in backend_pages())
        self.assertEqual(
            list(range(1, len(numbers) + 1)),
            numbers,
            "ORGANISM_PAGES ordering numbers must be unique and start at 1 without gaps",
        )

    def test_routes_are_absolute_and_unique(self) -> None:
        routes = [route for _, _, route in backend_pages()]
        self.assertEqual(len(routes), len(set(routes)), "Duplicate route in ORGANISM_PAGES")
        non_absolute = [route for route in routes if not route.startswith("/")]
        self.assertEqual([], non_absolute, "Every workspace route must be absolute")

    def test_every_wired_page_is_a_known_page(self) -> None:
        known = {page_id for _, page_id, _ in frontend_pages()}
        unknown = sorted(set(wiring_page_ids()) - known)
        self.assertEqual([], unknown, "WORKSPACE_WIRING references unknown page ids")

    def test_every_page_has_wiring(self) -> None:
        wired = set(wiring_page_ids())
        missing = sorted({page_id for _, page_id, _ in frontend_pages()} - wired)
        self.assertEqual([], missing, "Workspace pages without a WORKSPACE_WIRING entry")

    def test_every_backend_route_resolves_to_a_page_component(self) -> None:
        """A registered surface must have a real Next.js page on disk."""
        app_dir = REPO_ROOT / "apps" / "frontend" / "app"
        missing = []
        for _, _, route in backend_pages():
            segments = [segment for segment in route.strip("/").split("/") if segment]
            if not (app_dir.joinpath(*segments, "page.tsx")).exists():
                missing.append(route)
        self.assertEqual([], missing, "Registered surfaces without a page.tsx on disk")


if __name__ == "__main__":
    unittest.main()
