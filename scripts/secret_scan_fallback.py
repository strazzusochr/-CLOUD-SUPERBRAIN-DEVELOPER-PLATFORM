from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

SKIP_DIRS = {
    ".git",
    ".next",
    ".pytest_cache",
    ".tools",
    "__pycache__",
    "node_modules",
}

SKIP_SUFFIXES = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".ico",
    ".woff",
    ".woff2",
    ".ttf",
    ".map",
    ".pyc",
}

ALLOWLIST_VALUES = {
    "change-me-now",
    "change-me-too",
    "placeholder",
    "your_key_here",
    "example.invalid",
    "test_api_key",
}

TOKEN_PATTERNS = [
    re.compile(r"\bsk-[A-Za-z0-9_-]{24,}\b"),
    re.compile(r"\bsk-ant-[A-Za-z0-9_-]{24,}\b"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{30,}\b"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{40,}\b"),
    re.compile(r"\bcfat_[A-Za-z0-9_-]{24,}\b"),
    re.compile(r"\bvck_[A-Za-z0-9_-]{24,}\b"),
    re.compile(r"\bhf_[A-Za-z0-9_-]{24,}\b"),
    re.compile(r"\bglpat-[A-Za-z0-9_.-]{20,}\b"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"),
    re.compile(r"\bAIza[0-9A-Za-z_-]{30,}\b"),
]

ASSIGNMENT_PATTERN = re.compile(
    r"(?i)\b(api[_-]?key|secret|token|password|private[_-]?key)\b\s*[:=]\s*[\"']?([^\"'\s#]{16,})"
)


def is_skipped(path: Path) -> bool:
    if any(part in SKIP_DIRS for part in path.parts):
        return True
    return path.suffix.lower() in SKIP_SUFFIXES


def is_allowed(value: str, path: Path) -> bool:
    normalized = value.strip().strip("\"'").lower()
    if path.name == ".env.example":
        return True
    if normalized in ALLOWLIST_VALUES:
        return True
    if "placeholder" in normalized or "example" in normalized:
        return True
    if normalized.startswith("${") and normalized.endswith("}"):
        return True
    if normalized.startswith("$"):
        return True
    if normalized.startswith("process.env."):
        return True
    return False


def scan_file(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return []

    findings: list[str] = []
    rel = path.relative_to(ROOT)
    for line_number, line in enumerate(text.splitlines(), start=1):
        for pattern in TOKEN_PATTERNS:
            match = pattern.search(line)
            if match and not is_allowed(match.group(0), path):
                findings.append(f"{rel}:{line_number}: token-like secret pattern")

        assignment = ASSIGNMENT_PATTERN.search(line)
        if assignment and not is_allowed(assignment.group(2), path):
            findings.append(f"{rel}:{line_number}: secret assignment pattern")

    return findings


def main() -> int:
    findings: list[str] = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or is_skipped(path):
            continue
        findings.extend(scan_file(path))

    if findings:
        print("[secret-scan] possible secrets found:", file=sys.stderr)
        for finding in findings:
            print(f"  - {finding}", file=sys.stderr)
        return 1

    print("[secret-scan] no secret patterns found")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
