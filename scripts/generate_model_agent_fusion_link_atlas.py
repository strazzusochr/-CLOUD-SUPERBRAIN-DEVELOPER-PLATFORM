from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
AGENT_API_ROOT = REPO_ROOT / "services" / "agent-api"
sys.path.insert(0, str(AGENT_API_ROOT))

from app.link_atlas import (  # noqa: E402
    CATALOG_FIELDS,
    LINK_ATLAS_CONTRACT_VERSION,
    LINK_ATLAS_EVIDENCE_REF,
    PROMPT_REQUIRED_URLS,
    SHARD_DEFINITIONS,
    SOURCE_DEFINITIONS,
    link_atlas_contract_payload,
    link_atlas_shards_payload,
    shard_items,
    validate_link_atlas,
)

ATLAS_DIR = REPO_ROOT / "docs" / "analysis" / "model-agent-fusion-link-atlas"
README_PATH = ATLAS_DIR / "README.md"


def md_escape(value: object) -> str:
    text = str(value)
    return text.replace("|", "\\|").replace("\n", " ")


def markdown_link(url: str) -> str:
    if url.startswith("/"):
        return f"`{url}`"
    return f"[link]({url})"


def item_table(items: list[dict[str, Any]]) -> str:
    header = "| canonical_id | source | kind | name | url | api_url | category | tags | license | gated/private | dedupe_group | last_seen |\n"
    divider = "|---|---|---|---|---|---|---|---|---|---:|---|---|\n"
    rows: list[str] = []
    for item in items:
        tags = ", ".join(str(tag) for tag in item.get("tags", []))
        rows.append(
            "| "
            + " | ".join(
                [
                    f"`{md_escape(item['canonical_id'])}`",
                    md_escape(item["source"]),
                    md_escape(item["kind"]),
                    md_escape(item["name"]),
                    markdown_link(str(item["url"])),
                    markdown_link(str(item["api_url"])),
                    md_escape(item["category"]),
                    md_escape(tags),
                    md_escape(item["license"]),
                    str(bool(item["gated_private"])).lower(),
                    f"`{md_escape(item['dedupe_group'])}`",
                    md_escape(item["last_seen"]),
                ]
            )
            + " |"
        )
    return header + divider + "\n".join(rows) + "\n"


def write_readme() -> None:
    contract = link_atlas_contract_payload()
    shards = link_atlas_shards_payload()["shards"]
    lines: list[str] = [
        "# Model Agent Fusion Link Atlas",
        "",
        f"Contract: `{LINK_ATLAS_CONTRACT_VERSION}`",
        f"Evidence: `{LINK_ATLAS_EVIDENCE_REF}`",
        "Status: `generated-static-seed-pending-post-release-full-crawl`",
        "Gate: `post_release_after_verified_100_percent`",
        "",
        "This atlas is generated from `services/agent-api/app/link_atlas.py`.",
        "It stores metadata links only: no model downloads, no provider secrets, no production rollout claim.",
        "",
        "## API Surfaces",
        "",
        "- `GET /catalog/link-atlas/sources`",
        "- `GET /catalog/link-atlas/items?source=&kind=&cursor=&limit=`",
        "- `GET /catalog/link-atlas/items/{canonical_id}`",
        "- `GET /catalog/link-atlas/shards`",
        "- `GET /catalog/link-atlas/export.jsonl`",
        "- `GET /catalog/link-atlas/export.csv`",
        "- `GET /api/v1/catalog/link-atlas/sources`",
        "- `GET /api/v1/catalog/link-atlas/items?source=&kind=&cursor=&limit=`",
        "- `GET /api/v1/catalog/link-atlas/items/{canonical_id}`",
        "- `GET /api/v1/catalog/link-atlas/shards`",
        "- `GET /api/v1/catalog/link-atlas/export.jsonl`",
        "- `GET /api/v1/catalog/link-atlas/export.csv`",
        "",
        "## Required Prompt Links",
        "",
    ]
    lines.extend(f"- {url}" for url in PROMPT_REQUIRED_URLS)
    lines.extend(
        [
            "",
            "## Sources",
            "",
            "| source | import_mode | auth_env | source_urls | api_urls | shards |",
            "|---|---|---|---|---|---|",
        ]
    )
    for source in SOURCE_DEFINITIONS:
        source_urls = "<br>".join(str(url) for url in source.get("source_urls", []))
        api_urls = "<br>".join(str(url) for url in source.get("api_urls", [])) or "none"
        shards_text = "<br>".join(str(shard) for shard in source.get("shards", []))
        lines.append(
            "| "
            + " | ".join(
                [
                    f"`{source['source']}`",
                    md_escape(source["import_mode"]),
                    f"`{source['auth_env']}`" if source.get("auth_env") else "`none`",
                    source_urls,
                    api_urls,
                    shards_text,
                ]
            )
            + " |"
        )
    lines.extend(
        [
            "",
            "## Shards",
            "",
            "| shard | source | kinds | item_count | path |",
            "|---|---|---|---:|---|",
        ]
    )
    for shard in shards:
        lines.append(
            "| "
            + " | ".join(
                [
                    f"`{shard['shard_id']}`",
                    md_escape(shard["source"]),
                    md_escape(", ".join(str(kind) for kind in shard["include_kinds"])),
                    str(shard["item_count"]),
                    f"[{Path(shard['path']).name}]({Path(shard['path']).name})",
                ]
            )
            + " |"
        )
    lines.extend(
        [
            "",
            "## Contract Summary",
            "",
            f"- Source count: `{contract['source_count']}`",
            f"- Seed item count: `{contract['item_count']}`",
            f"- Shard count: `{contract['shard_count']}`",
            f"- Required fields: `{', '.join(CATALOG_FIELDS)}`",
            "",
            "## Non-Claims",
            "",
        ]
    )
    lines.extend(f"- {claim}" for claim in contract["non_claims"])
    README_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_shard(shard: dict[str, Any]) -> None:
    path = REPO_ROOT / str(shard["path"])
    source = next(source for source in SOURCE_DEFINITIONS if source["source"] == shard["source"])
    items = shard_items(shard)
    lines = [
        f"# {shard['title']}",
        "",
        f"Contract: `{LINK_ATLAS_CONTRACT_VERSION}`",
        f"Evidence: `{LINK_ATLAS_EVIDENCE_REF}`",
        f"Source: `{source['source']}`",
        f"Import mode: `{source['import_mode']}`",
        f"Auth env: `{source['auth_env'] or 'none'}`",
        f"Item count: `{len(items)}`",
        "",
        "Generated from `services/agent-api/app/link_atlas.py`.",
        "Rows are metadata links only and do not authorize live calls or model downloads.",
        "",
        item_table(items),
        "## Source Policy",
        "",
        f"- Target scope: {source['target_scope']}",
        f"- Non-claim: {source['non_claim']}",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    errors = validate_link_atlas()
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    ATLAS_DIR.mkdir(parents=True, exist_ok=True)
    write_readme()
    for shard in SHARD_DEFINITIONS:
        write_shard(shard)

    print(f"generated={ATLAS_DIR}")
    print(f"contract_version={LINK_ATLAS_CONTRACT_VERSION}")
    print(f"evidence_ref={LINK_ATLAS_EVIDENCE_REF}")
    print(f"shard_count={len(SHARD_DEFINITIONS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
