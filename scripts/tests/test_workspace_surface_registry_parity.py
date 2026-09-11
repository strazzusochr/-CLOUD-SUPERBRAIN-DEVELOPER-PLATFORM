"""Workspace surface registry parity between backend and frontend.

The surface list exists twice: ORGANISM_PAGES in the agent-api (which feeds
GET /api/v1/workspace/wiring) and, in the frontend, WORKSPACE_PAGES (navigation
and command palette) plus the supplemental direct-route pages declared in
workspaceWiring.ts (landing, organism live, responsive, run detail). Nothing
enforced that the two sides agree.

Since PR #107 the registry carries 26 surfaces: 22 palette surfaces and 4
supplemental surfaces that scripts/verify-workspace-responsive-browser.cjs opens
by direct navigation (``surface.no > 22``). That threshold is also bound here.

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
RESPONSIVE_VERIFIER = REPO_ROOT / "scripts" / "verify-workspace-responsive-browser.cjs"


def _parse_nav_items(block: str) -> list[tuple[int, str, str]]:
    rows: list[tuple[int, str, str]] = []
    for entry in re.finditer(r"\{[^{}]*\}", block):
        text = entry.group(0)
        page_id = re.search(r'id:\s*"([^"]+)"', text)
        no = re.search(r"no:\s*(\d+)", text)
        route = re.search(r'route:\s*"([^"]+)"', text)
        if page_id and no and route:
            rows.append((int(no.group(1)), page_id.group(1), route.group(1)))
    return rows


def backend_pages() -> list[tuple[int, str, str]]:
    """Return (no, page_id, route) from the agent-api ORGANISM_PAGES literal."""
    source = AGENT_API.read_text(encoding="utf-8")
    match = re.search(r"^ORGANISM_PAGES = (\[.*?^\])", source, re.S | re.M)
    if not match:
        raise AssertionError("ORGANISM_PAGES literal not found in agent-api main.py")
    parsed = ast.literal_eval(match.group(1))
    return [(int(row[0]), str(row[1]), str(row[2])) for row in parsed]


def palette_pages() -> list[tuple[int, str, str]]:
    """Return (no, id, route) from the frontend WORKSPACE_PAGES literal (nav + command palette)."""
    source = FRONTEND_NAV.read_text(encoding="utf-8")
    match = re.search(r"WORKSPACE_PAGES[^=]*=\s*\[(.*?)^\]", source, re.S | re.M)
    if not match:
        raise AssertionError("WORKSPACE_PAGES literal not found in nav.tsx")
    rows = _parse_nav_items(match.group(1))
    if not rows:
        raise AssertionError("No WORKSPACE_PAGES entries parsed from nav.tsx")
    return rows


def supplemental_pages() -> list[tuple[int, str, str]]:
    """Return (no, id, route) of direct-route surfaces declared in workspaceWiring.ts."""
    source = FRONTEND_WIRING.read_text(encoding="utf-8")
    match = re.search(r"supplementalPages[^=]*=\s*\[(.*?)^\]", source, re.S | re.M)
    return _parse_nav_items(match.group(1)) if match else []


def frontend_pages() -> list[tuple[int, str, str]]:
    """All surfaces the frontend can resolve: palette pages plus supplemental pages."""
    return palette_pages() + supplemental_pages()


def verifier_palette_threshold() -> int | None:
    source = RESPONSIVE_VERIFIER.read_text(encoding="utf-8")
    match = re.search(r"surface\.no\s*>\s*(\d+)", source)
    return int(match.group(1)) if match else None


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


    def test_palette_pages_are_the_first_contiguous_block(self) -> None:
        """Palette surfaces must be 1..N, supplemental surfaces must follow after N."""
        palette = sorted(no for no, _, _ in palette_pages())
        self.assertEqual(list(range(1, len(palette) + 1)), palette, "WORKSPACE_PAGES numbering must be 1..N")
        late = [no for no, _, _ in supplemental_pages() if no <= len(palette)]
        self.assertEqual([], late, "Supplemental surfaces must be numbered after the palette block")

    def test_responsive_verifier_threshold_matches_palette_size(self) -> None:
        """The browser verifier opens surfaces with no > N directly; N must equal the palette size.

        If a page is added to WORKSPACE_PAGES without moving the threshold, the verifier would
        silently skip the command-palette proof for it; if a supplemental page were numbered
        inside the palette block, the verifier would look for it in the palette and fail with
        "Command palette route is not unique or missing".
        """
        threshold = verifier_palette_threshold()
        if threshold is None:
            self.skipTest("responsive verifier has no direct-route threshold")
        self.assertEqual(len(palette_pages()), threshold, "verify-workspace-responsive-browser.cjs palette threshold drifted")


if __name__ == "__main__":
    unittest.main()
