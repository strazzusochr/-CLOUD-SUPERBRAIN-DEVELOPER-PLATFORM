param(
  [string]$InventoryPath = ".codex\runs\CURRENT\goal-d4\batch0\inventory\inventory.json",
  [string]$OutDir = ".codex\runs\CURRENT\goal-d4\batch1"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Get-Location).Path
$inventoryFile = Join-Path $repoRoot $InventoryPath
$outPath = Join-Path $repoRoot $OutDir
if (-not (Test-Path -LiteralPath $inventoryFile)) { throw "Missing Batch 0 inventory: $inventoryFile" }
New-Item -ItemType Directory -Force $outPath | Out-Null
$inventory = Get-Content -LiteralPath $inventoryFile -Raw | ConvertFrom-Json
$cloudRows = @($inventory.cloud_api_matrices.$($inventory.canonical_cloud))

$classB = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
@(
  "/api/v1/agent-activity/recent",
  "/api/v1/audit/mcp",
  "/api/v1/escalations/recent",
  "/api/v1/memory/consolidation/recent",
  "/api/v1/memory/embedding-consistency/contract",
  "/api/v1/rotation/events"
) | ForEach-Object { [void]$classB.Add($_) }

$classC = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
@(
  "/api/v1/agents/status",
  "/api/v1/live-agents/status",
  "/api/v1/phase2/runtime/runs",
  "/api/v1/task/dispatches/recent",
  "/api/v1/tasks/recent"
) | ForEach-Object { [void]$classC.Add($_) }

function Get-Rationale([string]$Class, [string]$Path, [bool]$HashEqual) {
  switch ($Class) {
    "A" {
      if ($HashEqual) { return "Cloud payload hash equals local response." }
      return "Read-only contract or state projection is already cloud-served; source/timestamp drift is documented, not a backend-live claim."
    }
    "B" { return "Read-only data/projection surface can use Vercel route handlers plus GitHub Store or Workers AI without Fly." }
    "C" { return "Requires a real hosted LangGraph/Redis/PostgreSQL runtime for authoritative live state; Fly plan is owner/billing-gated." }
    "D" { return "DEV-only runtime/infrastructure diagnostic; excluded from cloud parity target." }
  }
}

function Get-Action([string]$Class, [string]$Path) {
  switch ($Class) {
    "A" { return "No transfer; retain source labeling and probe parity." }
    "B" {
      if ($Path -eq "/api/v1/memory/embedding-consistency/contract") { return "Align Workers-AI embedding model/vector contract and prove memory search roundtrip." }
      if ($Path -match "agent-activity|audit/mcp|escalations|rotation") { return "Project redacted GitHub-store audit/session events with explicit source header." }
      if ($Path -match "budget|cost") { return "Expose free Workers-AI quota/read-only cost state; do not imply paid-provider spend." }
      return "Map alias/contract to the existing GitHub-store or route-handler surface; prove with HTTPS source header." 
    }
    "C" { return "List as Fly Plan B only; do not deploy or activate without owner billing approval." }
    "D" { return "Keep local-only and exclude from cloud completion calculations." }
  }
}

$matrix = foreach ($delta in @($inventory.transfer_delta_candidates)) {
  $local = @($inventory.local_api_matrix | Where-Object { $_.path -eq $delta.path }) | Select-Object -First 1
  $cloud = @($cloudRows | Where-Object { $_.path -eq $delta.path }) | Select-Object -First 1
  $hashEqual = ($null -ne $local -and $local.payload_sha256 -eq $cloud.payload_sha256)
  $class = if ($classC.Contains($delta.path)) { "C" } elseif ($classB.Contains($delta.path)) { "B" } else { "A" }
  [pscustomobject]@{
    id = "api:$($delta.path)"
    scope = "workspace_api"
    path = $delta.path
    class = $class
    local_http = $local.http_status
    cloud_http = $cloud.http_status
    cloud_source = $cloud.source
    cloud_source_kind = $cloud.source_kind
    cloud_live_backend = $cloud.live_backend
    payload_hash_equal = $hashEqual
    rationale = Get-Rationale $class $delta.path $hashEqual
    required_action = Get-Action $class $delta.path
  }
}

$supplemental = @(
  [pscustomobject]@{ id="api:/api/v1/organism/events"; scope="cloud_projection"; path="/api/v1/organism/events"; class="B"; local_http=200; cloud_http=200; cloud_source="github-store or projection"; cloud_source_kind="redacted event projection"; cloud_live_backend=$false; payload_hash_equal=$false; rationale="D4 explicitly requires free redacted audit/session feed for the cortex."; required_action="Project GitHub-store audit/session events without prompts, user IDs, or secrets." }
  [pscustomobject]@{ id="api:/api/v1/organism/replay"; scope="cloud_projection"; path="/api/v1/organism/replay"; class="B"; local_http=200; cloud_http=200; cloud_source="github-store or projection"; cloud_source_kind="redacted replay projection"; cloud_live_backend=$false; payload_hash_equal=$false; rationale="D4 explicitly requires free replay frames from persisted redacted events."; required_action="Project replay frames from GitHub-store audit/session events." }
  [pscustomobject]@{ id="api:/api/v1/artifacts"; scope="alias"; path="/api/v1/artifacts"; class="B"; local_http=200; cloud_http=200; cloud_source="workspace-artifacts alias candidate"; cloud_source_kind="alias"; cloud_live_backend=$false; payload_hash_equal=$false; rationale="Alias gap: canonical workspace artifacts may be live while the short alias is empty."; required_action="Map alias to /api/v1/workspace/artifacts with GitHub-store source label." }
  [pscustomobject]@{ id="runtime:local-llm"; scope="runtime"; path="docker://local-llm:8080"; class="D"; local_http=200; cloud_http=$null; cloud_source=$null; cloud_source_kind="DEV-only local llama.cpp"; cloud_live_backend=$false; payload_hash_equal=$false; rationale="Local Gemma endpoint is replaced by Workers AI for free cloud inference."; required_action="Do not transfer; cloud Workers AI remains the free equivalent." }
  [pscustomobject]@{ id="runtime:compose-health"; scope="runtime"; path="docker-compose.dev.yml healthchecks"; class="D"; local_http=200; cloud_http=$null; cloud_source=$null; cloud_source_kind="DEV-only Docker health"; cloud_live_backend=$false; payload_hash_equal=$false; rationale="Docker internal healthchecks are local harness diagnostics."; required_action="Do not count as cloud gap." }
  [pscustomobject]@{ id="runtime:host-portscan"; scope="runtime"; path="host TCP 1000-9999"; class="D"; local_http=200; cloud_http=$null; cloud_source=$null; cloud_source_kind="DEV-only host audit"; cloud_live_backend=$false; payload_hash_equal=$false; rationale="Host listener audit has no cloud product endpoint."; required_action="Keep DEV-only." }
  [pscustomobject]@{ id="runtime:worker-heartbeats"; scope="runtime"; path="Redis worker heartbeats"; class="D"; local_http=200; cloud_http=$null; cloud_source=$null; cloud_source_kind="DEV-only queue health"; cloud_live_backend=$false; payload_hash_equal=$false; rationale="Redis worker liveness requires the class-C runtime."; required_action="Do not emulate in Vercel projection." }
)
$allRows = @($matrix) + $supplemental
$classCounts = foreach ($className in @("A", "B", "C", "D")) {
  [pscustomobject]@{ class=$className; count=@($allRows | Where-Object { $_.class -eq $className }).Count }
}
if (@($allRows | Group-Object id | Where-Object { $_.Count -ne 1 }).Count) { throw "Transfer matrix contains duplicate IDs." }
foreach ($class in @("A", "B", "C", "D")) {
  if (@($allRows | Where-Object { $_.class -eq $class }).Count -eq 0) { throw "Transfer matrix misses class $class." }
}

$result = [ordered]@{
  contract_version = "goal-d4-transfer-matrix-v1"
  inventory_ref = $InventoryPath
  canonical_cloud = $inventory.canonical_cloud
  delta_api_count = @($matrix).Count
  supplemental_count = $supplemental.Count
  class_counts = $classCounts
  entries = $allRows
  non_claims = @("Class A projection is not a hosted-agent-api claim.", "Class B remains incomplete until HTTPS probes are fresh after deployment.", "Class C is not implemented without an owner-approved Fly plan.", "Class D is excluded from cloud parity.")
}
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outPath "transfer-matrix.json") -Encoding utf8

$rows = $allRows | Sort-Object class, path | ForEach-Object {
  "| $($_.class) | $($_.scope) | $($_.path) | $($_.local_http) | $($_.cloud_http) | $($_.cloud_source) | $($_.required_action) |"
}
$classSummary = $result.class_counts | ForEach-Object { "| $($_.class) | $($_.count) |" }
$markdown = @(
  "# Goal D4 Batch 1 Transfer Matrix",
  "",
  "Source: ``$InventoryPath``; canonical HTTPS cloud: ``$($inventory.canonical_cloud)``.",
  "",
  "| Class | Entries |",
  "| --- | ---: |",
  ($classSummary -join "`n"),
  "",
  "A = already cloud-served read-only projection/contract; B = free Vercel route-handler + GitHub Store/Workers AI transfer; C = needs real hosted LangGraph/Redis/PostgreSQL runtime; D = DEV-only diagnostic/runtime.",
  "",
  "| Class | Scope | Surface | Local HTTP | Cloud HTTP | Cloud source | Required action |",
  "| --- | --- | --- | ---: | ---: | --- | --- |",
  ($rows -join "`n"),
  "",
  "No class-C deployment is performed. No class-D surface is counted as a cloud defect. Batch 2 owns only class-B work and must prove each completed transfer against HTTPS with source headers.",
  ""
) -join "`n"
$markdown | Set-Content -LiteralPath (Join-Path $outPath "batch1-transfer-matrix.md") -Encoding utf8
Write-Host "[goal-d4-batch1] entries=$($allRows.Count) A=$(@($allRows | Where-Object { $_.class -eq 'A' }).Count) B=$(@($allRows | Where-Object { $_.class -eq 'B' }).Count) C=$(@($allRows | Where-Object { $_.class -eq 'C' }).Count) D=$(@($allRows | Where-Object { $_.class -eq 'D' }).Count)"
