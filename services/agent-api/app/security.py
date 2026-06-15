from __future__ import annotations

import re
from typing import Any

SECRET_PATTERNS = [
    re.compile(r"\bsk-[A-Za-z0-9_-]{16,}\b"),
    re.compile(r"\bghp_[A-Za-z0-9_]{16,}\b"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{16,}\b"),
    re.compile(r"\bE2B_[A-Za-z0-9_-]{16,}\b"),
    re.compile(r"\bcfat_[A-Za-z0-9_-]{24,}\b"),
    re.compile(r"\bvck_[A-Za-z0-9_-]{24,}\b"),
    re.compile(r"\bhf_[A-Za-z0-9_-]{24,}\b"),
    re.compile(r"\bglpat-[A-Za-z0-9_.-]{20,}\b"),
    re.compile(r"(?i)\b(?:cloud|provider)\s+token\s+[A-Za-z0-9_-]{32,}\b"),
    re.compile(r"(?i)\b(api[_-]?key|secret|token|password)\s*[:=]\s*[^\s,;]{8,}"),
]

MASK = "***MASKED_SECRET***"


def redact_text(value: str) -> str:
    redacted = value
    for pattern in SECRET_PATTERNS:
        redacted = pattern.sub(lambda match: _redact_assignment(match.group(0)), redacted)
    return redacted


def _redact_assignment(value: str) -> str:
    if ":" in value:
        return value.split(":", 1)[0] + ": " + MASK
    if "=" in value:
        return value.split("=", 1)[0] + "=" + MASK
    return MASK


def redact_json(value: Any) -> Any:
    if isinstance(value, str):
        return redact_text(value)
    if isinstance(value, list):
        return [redact_json(item) for item in value]
    if isinstance(value, tuple):
        return tuple(redact_json(item) for item in value)
    if isinstance(value, dict):
        return {str(key): redact_json(item) for key, item in value.items()}
    return value
