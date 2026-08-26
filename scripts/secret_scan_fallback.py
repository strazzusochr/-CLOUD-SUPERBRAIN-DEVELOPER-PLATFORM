from __future__ import annotations

import re
import subprocess
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
    ".har",
}

SUSPICIOUS_FILE_PATTERNS = (
    re.compile(r".*_token\.txt$", re.IGNORECASE),
    re.compile(r".*token.*\.(png|html?)$", re.IGNORECASE),
    re.compile(r".*tokens.*\.(png|html?)$", re.IGNORECASE),
    re.compile(r"superbrain_key(\.pub)?$", re.IGNORECASE),
    re.compile(r"(key_payload|server_payload|vercel_env|cloud_gate_data)\.json$", re.IGNORECASE),
)

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


def is_test_fixture(path: Path) -> bool:
    return any(part.lower() in {"test", "tests"} for part in path.parts) or ".test." in path.name.lower()


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
    if "$env:" in normalized:
        return True
    if normalized.startswith("process.env."):
        return True
    if "(" in normalized or ")" in normalized:
        return True
    if "," in normalized or ";" in normalized:
        return True
    return False


def scan_file(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return []

    findings: list[str] = []
    rel = path.relative_to(ROOT)
    scanner_config = rel.as_posix() == ".gitleaks.toml"
    test_fixture = is_test_fixture(rel)
    for line_number, line in enumerate(text.splitlines(), start=1):
        if not scanner_config:
            for pattern in TOKEN_PATTERNS:
                match = pattern.search(line)
                if match and not is_allowed(match.group(0), path):
                    findings.append(f"{rel}:{line_number}: token-like secret pattern")

        assignment = ASSIGNMENT_PATTERN.search(line)
        if assignment and not test_fixture and not is_allowed(assignment.group(2), path):
            findings.append(f"{rel}:{line_number}: secret assignment pattern")

    return findings


def scan_filename(path: Path) -> list[str]:
    rel = path.relative_to(ROOT)
    filename = path.name
    for pattern in SUSPICIOUS_FILE_PATTERNS:
        if pattern.fullmatch(filename):
            return [f"{rel}: suspicious secret-bearing filename"]
    return []


def release_scope_files() -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    paths: list[Path] = []
    for raw_path in result.stdout.split(b"\0"):
        if not raw_path:
            continue
        relative = raw_path.decode("utf-8", errors="surrogateescape")
        candidate = ROOT / relative
        if candidate.is_file():
            paths.append(candidate)
    return paths


def main() -> int:
    findings: list[str] = []
    for path in release_scope_files():
        if is_skipped(path):
            continue
        findings.extend(scan_filename(path))
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
