"""Check exact historical prose exceptions and reject fresh PATs in the same paths."""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
# These immutable hits were reviewed as documentation terms/header text, not credentials.
# Candidate hashes avoid emitting any scanned value or changing historical evidence.
REVIEWS = (
    (
        "fde53cb1011b445b0b385aa860da484e114fe388",
        "CODEX_UEBERPRUEFUNG_RC5_2026-07-22.md",
        127,
        r"Auth-Route,\s+(\S+)\s",
        "cbe3f39fea997c3755007bc6bfd8b4584c8a38667e5cb6cca8ba02bb1f796eff",
        "sub-verifier name in historical planning prose",
    ),
    (
        "d35f546b8789e16b5440b12fbe5a84ddc75cf342",
        "LAYER_MATRIX.md",
        24,
        r"agent-api:\s+(\S+)\s",
        "72c09cbd4e7db0b7d7b9b0aad566b436a2e0223226e3feaf9dbe5e8687c1778c",
        "API contract description in historical architecture prose",
    ),
    (
        "9c38c59238043dbda2d02ee4fcd0c59d44bac812",
        "scripts/verify-browser-contract.ps1",
        518,
        r'authCanaryId",\s*"([^"]+)"',
        "877bd9039096fd897e1aa1830313956b8c6978033eedeabe18afb57b26c4cc02",
        "Authorization header prefix in the forbidden-output assertion list",
    ),
)


def run(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, encoding="utf-8", capture_output=True, check=False)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def verify_reviews() -> None:
    expected = {
        f"{commit}:{path}:generic-api-key:{line}"
        for commit, path, line, _pattern, _digest, _reason in REVIEWS
    }
    entries = [
        line.strip()
        for line in (ROOT / ".gitleaksignore").read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    require(len(entries) == 3 and set(entries) == expected, "historical exception set is not exact")
    for commit, path, line, pattern, digest, _reason in REVIEWS:
        result = run(["git", "show", f"{commit}:{path}"], ROOT)
        require(result.returncode == 0, f"historical review source missing: {path}")
        lines = result.stdout.splitlines()
        require(0 < line <= len(lines), f"historical fingerprint line missing: {path}")
        # A source may contain several canary identifiers. Select by the reviewed
        # candidate hash rather than revealing the historical matched value.
        reviewed_matches = [
            match
            for match in re.finditer(pattern, result.stdout)
            if hashlib.sha256(match.group(1).encode("utf-8")).hexdigest() == digest
        ]
        require(len(reviewed_matches) == 1, f"historical reviewed context is not unique: {path}")


def verify_fresh_credentials_are_rejected() -> None:
    scanner = shutil.which("gitleaks")
    require(scanner is not None, "gitleaks is required; this guard must not be skipped")
    with tempfile.TemporaryDirectory(prefix="gitleaks-history-negative-") as temporary:
        repo = Path(temporary)
        shutil.copy2(ROOT / ".gitleaks.toml", repo / ".gitleaks.toml")
        shutil.copy2(ROOT / ".gitleaksignore", repo / ".gitleaksignore")
        for command in (
            ["git", "init", "-q"],
            ["git", "config", "user.email", "security-test@example.invalid"],
            ["git", "config", "user.name", "Security regression fixture"],
        ):
            require(run(command, repo).returncode == 0, "fixture git setup failed")
        # Synthetic, non-provider-issued detector positive control; never call a provider.
        probe = "ghp_" + "wA9mK2pLxN4vRtQzY6bC8dEfGhJlM0oPq1rS"
        paths = [review[1] for review in REVIEWS]
        for path in paths:
            target = repo / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(f'synthetic_probe = "{probe}"\n', encoding="utf-8")
        require(run(["git", "add", "--", *paths], repo).returncode == 0, "fixture staging failed")
        require(run(["git", "commit", "-qm", "synthetic credential negative probes"], repo).returncode == 0,
                "fixture commit failed")
        report = repo / "redacted-findings.json"
        result = run([
            scanner, "git", "--log-opts", "HEAD", "--config", str(repo / ".gitleaks.toml"),
            "--redact", "--no-banner", "--report-format", "json", "--report-path", str(report), ".",
        ], repo)
        require(result.returncode == 1, "fresh credential probes were not rejected")
        require(report.is_file(), "negative-probe report missing")
        findings = json.loads(report.read_text(encoding="utf-8"))
        require(len(findings) == 3, "fresh credential probe count mismatch")
        require({item["File"] for item in findings} == set(paths), "same-path probes were not all detected")
        require(all(item["RuleID"] == "github-pat" for item in findings), "provider credential rule is not active")
        require(all(item["Secret"] == "REDACTED" for item in findings), "probe output was not redacted")


def main() -> int:
    try:
        verify_reviews()
        verify_fresh_credentials_are_rejected()
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as exc:
        print(f"[gitleaks-history-exceptions] FAIL: {exc}")
        return 1
    print("[gitleaks-history-exceptions] PASS exact_historical_prose_exceptions=3 same_path_PAT_rejections=3 secret_output=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
