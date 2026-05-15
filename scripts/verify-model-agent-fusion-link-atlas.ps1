param(
  [string]$BaseUrl = "",
  [switch]$AllowLocalhost,
  [switch]$CheckExternalHttp
)

$ErrorActionPreference = "Stop"

function Assert-True($label, $condition) {
  if (-not $condition) {
    throw "Model/Agent/Fusion Link Atlas verification failed: $label"
  }
}

function Invoke-Text($url) {
  $python = @'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=30) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
'@
  return (($python | py -3 - $url) -join "`n")
}

function Invoke-JsonApi($url) {
  return (Invoke-Text $url | ConvertFrom-Json)
}

Write-Host "[link-atlas] static repo verification"

$staticPython = @'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

repo = Path.cwd()
sys.path.insert(0, str(repo / "services" / "agent-api"))

from app.link_atlas import (
    CATALOG_FIELDS,
    CATALOG_ITEMS,
    LINK_ATLAS_CONTRACT_VERSION,
    LINK_ATLAS_EVIDENCE_REF,
    PROMPT_REQUIRED_URLS,
    SHARD_DEFINITIONS,
    SOURCE_DEFINITIONS,
    link_atlas_contract_payload,
    link_atlas_export_csv_text,
    link_atlas_export_jsonl_text,
    link_atlas_items_page,
    link_atlas_shards_payload,
    link_atlas_sources_payload,
    validate_link_atlas,
)

errors = validate_link_atlas()
if errors:
    raise SystemExit("; ".join(errors))

docs_dir = repo / "docs" / "analysis" / "model-agent-fusion-link-atlas"
readme = docs_dir / "README.md"
if not readme.exists():
    raise SystemExit(f"missing README: {readme}")

all_docs = readme.read_text(encoding="utf-8")
for shard in SHARD_DEFINITIONS:
    path = repo / shard["path"]
    if not path.exists():
        raise SystemExit(f"missing shard: {path}")
    all_docs += "\n" + path.read_text(encoding="utf-8")

for url in PROMPT_REQUIRED_URLS:
    if url not in all_docs:
        raise SystemExit(f"prompt URL missing from docs: {url}")

for item in CATALOG_ITEMS:
    for field in CATALOG_FIELDS:
        if field not in item:
            raise SystemExit(f"{item['canonical_id']} missing field {field}")
    if item["canonical_id"] not in all_docs:
        raise SystemExit(f"item missing from docs: {item['canonical_id']}")

contract = link_atlas_contract_payload()
sources = link_atlas_sources_payload()
items = link_atlas_items_page(limit=500)
shards = link_atlas_shards_payload()
jsonl = link_atlas_export_jsonl_text()
csv_text = link_atlas_export_csv_text()

if contract["contract_version"] != LINK_ATLAS_CONTRACT_VERSION:
    raise SystemExit("contract version mismatch")
if contract["evidence_ref"] != LINK_ATLAS_EVIDENCE_REF:
    raise SystemExit("evidence ref mismatch")
if contract["openrouter_import"]["api_url"] != "https://openrouter.ai/api/v1/models":
    raise SystemExit("OpenRouter model import API mismatch")
if int(contract["openrouter_import"]["model_count"]) < 300:
    raise SystemExit("OpenRouter model import count below expected floor")
if sources["source_count"] != len(SOURCE_DEFINITIONS):
    raise SystemExit("source count mismatch")
if items["total_count"] != len(CATALOG_ITEMS):
    raise SystemExit("item count mismatch")
if shards["shard_count"] != len(SHARD_DEFINITIONS):
    raise SystemExit("shard count mismatch")
if len([line for line in jsonl.splitlines() if line.strip()]) != len(CATALOG_ITEMS):
    raise SystemExit("jsonl export count mismatch")
if len([line for line in csv_text.splitlines() if line.strip()]) != len(CATALOG_ITEMS) + 1:
    raise SystemExit("csv export count mismatch")

secret_patterns = [
    r"\bsk-[A-Za-z0-9_-]{12,}\b",
    r"\bgithub_pat_[A-Za-z0-9_]{20,}\b",
    r"\bgh[pousr]_[A-Za-z0-9_]{12,}\b",
    r"\bvck_[A-Za-z0-9_-]{24,}\b",
    r"\bcfat_[A-Za-z0-9_-]{24,}\b",
    r"\bhf_[A-Za-z0-9_-]{24,}\b",
    r"\bglpat-[A-Za-z0-9_.-]{20,}\b",
]
for pattern in secret_patterns:
    if re.search(pattern, all_docs):
        raise SystemExit(f"secret-like value found in docs by pattern {pattern}")

print(json.dumps({
    "status": "verified",
    "contract_version": LINK_ATLAS_CONTRACT_VERSION,
    "evidence_ref": LINK_ATLAS_EVIDENCE_REF,
    "source_count": len(SOURCE_DEFINITIONS),
    "item_count": len(CATALOG_ITEMS),
    "shard_count": len(SHARD_DEFINITIONS),
}, sort_keys=True))
'@

$staticResult = ($staticPython | py -3 - | ConvertFrom-Json)
Assert-True "static status" ($staticResult.status -eq "verified")
Assert-True "static contract version" ($staticResult.contract_version -eq "model-agent-fusion-link-atlas-v1")
Assert-True "static evidence ref" ($staticResult.evidence_ref -eq "model_agent_fusion_link_atlas_visible")
Assert-True "static sources" ([int]$staticResult.source_count -ge 6)
Assert-True "static items" ([int]$staticResult.item_count -ge 400)
Assert-True "static shards" ([int]$staticResult.shard_count -ge 9)

if ($BaseUrl) {
  $BaseUrl = $BaseUrl.TrimEnd("/")
  if ((-not $AllowLocalhost) -and ($BaseUrl -match "localhost|127\.0\.0\.1|\[::1\]")) {
    throw "Link Atlas proof refuses localhost unless -AllowLocalhost is set"
  }

  Write-Host "[link-atlas] runtime API verification: $BaseUrl"
  $contract = Invoke-JsonApi "$BaseUrl/api/v1/catalog/link-atlas/contract"
  Assert-True "runtime contract version" ($contract.contract_version -eq "model-agent-fusion-link-atlas-v1")
  Assert-True "runtime evidence" ($contract.evidence_ref -eq "model_agent_fusion_link_atlas_visible")
  Assert-True "runtime exact endpoints include sources" (@($contract.exact_plan_endpoints) -contains "GET /catalog/link-atlas/sources")

  $exactContract = Invoke-JsonApi "$BaseUrl/catalog/link-atlas/contract"
  Assert-True "exact route contract version" ($exactContract.contract_version -eq "model-agent-fusion-link-atlas-v1")

  $sources = Invoke-JsonApi "$BaseUrl/api/v1/catalog/link-atlas/sources"
  Assert-True "sources count" ([int]$sources.source_count -ge 6)
  foreach ($url in @(
    "https://openrouter.ai/docs/api/reference/overview",
    "https://openrouter.ai/api/v1/models",
    "https://openrouter.ai/models",
    "https://openrouter.ai/models?active=false",
    "https://openrouter.ai/models?order=top-weekly",
    "https://openrouter.ai/apps/category/coding",
    "https://huggingface.co/models?sort=trending",
    "https://huggingface.co/collections",
    "https://github.com/NousResearch/hermes-agent",
    "https://llm-explorer.com/"
  )) {
    Assert-True "prompt url visible $url" (@($sources.required_prompt_urls) -contains $url)
  }

  $items = Invoke-JsonApi "$BaseUrl/api/v1/catalog/link-atlas/items?limit=500"
  Assert-True "items count" ([int]$items.total_count -ge 400)
  foreach ($field in @("canonical_id", "source", "name", "url", "api_url", "category", "tags", "license", "gated_private", "dedupe_group", "last_seen")) {
    Assert-True "field visible $field" (@($items.fields) -contains $field)
  }

  $one = Invoke-JsonApi "$BaseUrl/api/v1/catalog/link-atlas/items/openrouter-api-overview"
  Assert-True "single item id" ($one.item.canonical_id -eq "openrouter-api-overview")

  $shards = Invoke-JsonApi "$BaseUrl/api/v1/catalog/link-atlas/shards"
  Assert-True "shard count" ([int]$shards.shard_count -ge 9)

  $jsonl = Invoke-Text "$BaseUrl/api/v1/catalog/link-atlas/export.jsonl"
  Assert-True "jsonl contains openrouter" ($jsonl.Contains("openrouter-api-overview"))

  $csv = Invoke-Text "$BaseUrl/api/v1/catalog/link-atlas/export.csv"
  Assert-True "csv contains canonical header" ($csv.Contains("canonical_id,source,kind,name,url,api_url"))
}

if ($CheckExternalHttp) {
  Write-Host "[link-atlas] optional external URL status verification"
  $externalPython = @'
from __future__ import annotations

import sys
import urllib.error
import urllib.request

sys.path.insert(0, "services/agent-api")
from app.link_atlas import PROMPT_REQUIRED_URLS

for url in PROMPT_REQUIRED_URLS:
    request = urllib.request.Request(url, headers={"User-Agent": "cloud-superbrain-link-atlas-verifier/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            status = int(response.status)
    except urllib.error.HTTPError as exc:
        status = int(exc.code)
    if status >= 500:
        raise SystemExit(f"{url} returned {status}")
    print(f"{status} {url}")
'@
  $externalPython | py -3 -
}

Write-Host "status=verified"
Write-Host "contract_version=$($staticResult.contract_version)"
Write-Host "evidence_ref=$($staticResult.evidence_ref)"
Write-Host "source_count=$($staticResult.source_count)"
Write-Host "item_count=$($staticResult.item_count)"
Write-Host "shard_count=$($staticResult.shard_count)"
