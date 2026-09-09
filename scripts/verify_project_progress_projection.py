"""Offline ledger/mirror validation, not candidate qualification or new credit.

HTTP verifiers use this before comparing their live projection. Bounded O6
cannot credit hosted Layer 4; only the existing pinned ledger and scorers can.
The full manifest/release verifiers remain mandatory, unchanged, separate gates.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

try:
    from . import verify_project_progress_manifest as progress
except ImportError:
    import verify_project_progress_manifest as progress


def verify_projection(repo_root: Path) -> dict[str, Any]:
    manifest = progress.load_json(repo_root / progress.MANIFEST_PATH)
    ledger = progress.load_json(repo_root / progress.DELTA_LEDGER_PATH)
    schema = progress.load_json(repo_root / progress.DELTA_LEDGER_SCHEMA_PATH)
    snapshot = progress.load_json(repo_root / progress.ENDPOINT_SNAPSHOT_PATH)
    platform = (repo_root / progress.PLATFORM_MIRROR_PATH).read_text(encoding="utf-8")
    progress.validate_progress_truth(manifest, ledger, schema, snapshot, platform, repo_root)
    return manifest


def main() -> int:
    manifest = verify_projection(Path(__file__).resolve().parents[1])
    print(
        f"[progress-projection] PASS overall={manifest['overall_percent']} "
        "ledger_and_mirrors_verified=true candidate_qualification_checked=false "
        "new_credit=0 release_readiness_claimed=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
