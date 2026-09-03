#!/usr/bin/env python3
"""Build one immutable Layer-4 current-hosted scorer-input artifact."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Callable

import validate_layer4_hosted_llm_current_evidence as validator


OUTPUT_FILENAME = "layer4-hosted-llm-current-evidence.json"


def build_document(
    descriptor_bytes: bytes,
    load_report: Callable[[str], bytes],
    *,
    checked_at: str | None = None,
) -> tuple[dict[str, Any], bytes]:
    descriptor = validator.decode_json(descriptor_bytes, "build descriptor")
    aggregate = validator.build_aggregate(descriptor, load_report, checked_at=checked_at)
    serialized = (json.dumps(aggregate, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    return aggregate, serialized


def write_new_file(path: Path, content: bytes) -> None:
    with path.open("xb") as handle:
        handle.write(content)


def main(argv: list[str]) -> int:
    if len(argv) != 3 or argv[0] != "--build-v1":
        print(
            "[layer4-current-evidence] usage: --build-v1 <repo-relative-descriptor.json> "
            f"<repo-relative-{OUTPUT_FILENAME}>",
            file=sys.stderr,
        )
        return 2
    repo_root = Path(__file__).resolve().parents[1]
    try:
        descriptor_ref = validator.normalized_repo_path(argv[1], "build descriptor path")
        output_ref = validator.normalized_repo_path(argv[2], "aggregate output path")
        validator.require(PurePosixPath(output_ref).name == OUTPUT_FILENAME, "aggregate output filename mismatch")
        descriptor_path = (repo_root / PurePosixPath(descriptor_ref)).resolve()
        output_path = (repo_root / PurePosixPath(output_ref)).resolve()
        validator.require(descriptor_path.is_relative_to(repo_root), "build descriptor escapes repository root")
        validator.require(output_path.is_relative_to(repo_root), "aggregate output escapes repository root")
        validator.require(output_path.parent.is_dir(), "aggregate output parent does not exist")
        _, serialized = build_document(
            descriptor_path.read_bytes(),
            validator.filesystem_loader(repo_root),
        )
        write_new_file(output_path, serialized)
    except (validator.EvidenceError, OSError, FileExistsError) as exc:
        print(f"[layer4-current-evidence] rejected: {exc}", file=sys.stderr)
        return 2
    digest = hashlib.sha256(serialized).hexdigest()
    print(
        "[layer4-current-evidence] "
        f"status=verified points=45 historical_credit_excluded=true sha256={digest} output={output_ref}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
