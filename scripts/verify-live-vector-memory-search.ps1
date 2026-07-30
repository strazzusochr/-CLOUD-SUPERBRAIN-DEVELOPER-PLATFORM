param(
  [string]$CapabilityStatePath = "docs\runtime-state\capability-gates.json",
  [string]$OwnerManifestPath = "docs\runtime-state\owner-input-manifest.json",
  [string]$WranglerConfigPath = "services\cloudflare-stateful-runtime\wrangler.jsonc",
  [string]$WorkerSourcePath = "services\cloudflare-stateful-runtime\src\index.js",
  [string]$SecretsPath = "$env:USERPROFILE\.codex\secrets\cloud-superbrain.local.env",
  [string]$RequiredIndexName = "cloud-superbrain-memory-v1",
  [string]$OutFile = ".phase1-artifacts\live-vector-memory-search-proof.json",
  # Read-only by default. The switch below never creates anything; it only allows the
  # anonymous-to-us scope probe against the Cloudflare API using the configured token.
  [switch]$AllowScopeProbe,
  # Performs the real hosted store/query roundtrip. Writes two sentences into the index.
  [switch]$AllowHostedRoundtrip,
  [string]$HostedBaseUrl = "https://cloud-superbrain-stateful-runtime.strazzusochr.workers.dev",
  # Refuses to run at all unless the full chain is satisfied. Used once the gate should open.
  [switch]$RequireHostedProof,
  # Writes the capability gate. Only ever effective on a complete pass, never by hand.
  [switch]$PromoteGateOnFullPass
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# O5 / live_vector_memory_search.
#
# This verifier exists because `capability-gates.json` reserves its exact path but the file was never
# written, leaving the owner input manifest pointing at a verifier that did not exist. It reports the
# real state of the semantic-retrieval chain and is fail-closed in a specific way:
#
#   * a MISSING precondition is `blocked` and exits 0 - that is the honest current state,
#   * an INCOHERENT state is `failed` and exits 1 - for example a gate that claims semantic proof
#     without an evidence artefact, or an evidence artefact that claims an index that is not there.
#
# It never writes `live_verified`. The lexical D1 memory proof is explicitly NOT semantic retrieval
# and must never be reused as evidence here.

$contractVersion = "live-vector-memory-search-proof-v1"
$requiredProvider = "cloudflare_vectorize"
$reservedVerifierPath = "scripts/verify-live-vector-memory-search.ps1"

$checks = [System.Collections.Generic.List[object]]::new()
$blockers = [System.Collections.Generic.List[string]]::new()

function Add-Check([string]$Id, [bool]$Ok, [string]$Detail) {
  $checks.Add([ordered]@{ id = $Id; ok = $Ok; detail = $Detail })
  $marker = if ($Ok) { "ok" } else { "blocked" }
  Write-Host "[vector-search] $marker : $Id - $Detail"
}

function Assert-Coherent([string]$Label, [bool]$Condition) {
  if (-not $Condition) {
    throw "Live vector memory search verification failed: $Label"
  }
}

function Read-SecretMap([string]$Path) {
  $map = @{}
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $map }
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
      $map[$Matches[1]] = $Matches[2].Trim().Trim('"')
    }
  }
  return $map
}

# --- 1) Gate contract must still be the one this verifier was written against -------------------
Assert-Coherent "capability state exists" (Test-Path -LiteralPath $CapabilityStatePath -PathType Leaf)
$state = Get-Content -LiteralPath $CapabilityStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$gateNames = @($state.gates.PSObject.Properties.Name)
Assert-Coherent "live_vector_memory_search gate is present" ($gateNames -contains "live_vector_memory_search")
Assert-Coherent "live_memory_provider gate is present" ($gateNames -contains "live_memory_provider")

$gate = $state.gates.live_vector_memory_search
Assert-Coherent "vector gate provider is $requiredProvider" ([string]$gate.provider -eq $requiredProvider)
Assert-Coherent "vector gate reserves this verifier" ([string]$gate.verifier -eq $reservedVerifierPath)
Assert-Coherent "vector gate must never be a paid provider" (-not [bool]$gate.paid_provider)

# A claimed proof without an artefact is the exact failure mode this project calls fake-done.
if ([bool]$gate.live_verified -or [bool]$gate.hosted_semantic_search_verified) {
  Assert-Coherent "a claimed semantic proof must reference an evidence artefact" (
    -not [string]::IsNullOrWhiteSpace([string]$gate.evidence_artifact)
  )
  Assert-Coherent "a claimed semantic proof must reference an existing evidence artefact" (
    Test-Path -LiteralPath ([string]$gate.evidence_artifact) -PathType Leaf
  )
}

# The lexical D1 proof must not be recycled as semantic evidence.
$lexicalGate = $state.gates.live_memory_provider
if (-not [string]::IsNullOrWhiteSpace([string]$gate.evidence_artifact)) {
  Assert-Coherent "vector evidence must differ from the lexical D1 evidence" (
    [string]$gate.evidence_artifact -ne [string]$lexicalGate.evidence_artifact
  )
}

# --- 2) Owner preconditions ---------------------------------------------------------------------
Add-Check "owner_scope_approved" ([bool]$gate.owner_scope_approved) `
  "Owner approval that the Cloudflare token may carry the Vectorize scope."
if (-not [bool]$gate.owner_scope_approved) { $blockers.Add("owner_scope_approved") }

Add-Check "architecture_approved" ([bool]$gate.architecture_approved) `
  "Owner approval of the Vectorize architecture, including index creation on the account."
if (-not [bool]$gate.architecture_approved) { $blockers.Add("architecture_approved") }

Assert-Coherent "owner input manifest exists" (Test-Path -LiteralPath $OwnerManifestPath -PathType Leaf)
$ownerManifest = Get-Content -LiteralPath $OwnerManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$o5 = @($ownerManifest.actions | Where-Object { [string]$_.id -eq "O5" }) | Select-Object -First 1
Assert-Coherent "owner manifest still tracks O5" ($null -ne $o5)
Assert-Coherent "owner manifest still names this verifier for O5" (
  @($o5.verifier_after | ForEach-Object { [string]$_ }) -contains $reservedVerifierPath
)

# --- 3) Token scope, read-only, never printing any value ----------------------------------------
$scopePresent = $false
$scopeDetail = "not probed; pass -AllowScopeProbe to check the Vectorize scope read-only"
if ($AllowScopeProbe) {
  $secrets = Read-SecretMap $SecretsPath
  $accountId = if ($secrets.ContainsKey("CLOUDFLARE_ACCOUNT_ID")) { $secrets["CLOUDFLARE_ACCOUNT_ID"] } else { "" }
  $apiToken = if ($secrets.ContainsKey("CLOUDFLARE_API_TOKEN")) { $secrets["CLOUDFLARE_API_TOKEN"] } else { "" }
  if ([string]::IsNullOrWhiteSpace($accountId) -or [string]::IsNullOrWhiteSpace($apiToken)) {
    $scopeDetail = "Cloudflare account id or token is not configured in the secrets file"
  } else {
    try {
      $listUri = "https://api.cloudflare.com/client/v4/accounts/$accountId/vectorize/v2/indexes"
      $response = Invoke-RestMethod -Method Get -Uri $listUri `
        -Headers @{ Authorization = "Bearer $apiToken" } -TimeoutSec 30
      $scopePresent = [bool]$response.success
      $indexNames = @($response.result | ForEach-Object { [string]$_.name })
      $scopeDetail = "Vectorize list succeeded; $($indexNames.Count) index(es) on the account"
      $script:DiscoveredIndexNames = $indexNames
    } catch {
      # Deliberately does not echo the exception body: it can carry request context.
      $scopeDetail = "Vectorize list did not succeed; scope or account is not usable"
    }
  }
}
Add-Check "vectorize_scope_readable" $scopePresent $scopeDetail
if (-not $scopePresent) { $blockers.Add("vectorize_scope_readable") }

# --- 4) The index the architecture requires ------------------------------------------------------
$indexPresent = $false
if ($scopePresent -and (Get-Variable -Name DiscoveredIndexNames -Scope Script -ErrorAction SilentlyContinue)) {
  $indexPresent = @($script:DiscoveredIndexNames) -contains $RequiredIndexName
}
Add-Check "vectorize_index_present" $indexPresent `
  "Index '$RequiredIndexName' must exist before any semantic retrieval can be proven."
if (-not $indexPresent) { $blockers.Add("vectorize_index_present") }

# --- 5) Worker wiring ----------------------------------------------------------------------------
Assert-Coherent "wrangler config exists" (Test-Path -LiteralPath $WranglerConfigPath -PathType Leaf)
Assert-Coherent "worker source exists" (Test-Path -LiteralPath $WorkerSourcePath -PathType Leaf)
$wrangler = Get-Content -LiteralPath $WranglerConfigPath -Raw -Encoding UTF8
$workerSource = Get-Content -LiteralPath $WorkerSourcePath -Raw -Encoding UTF8

$vectorizeBinding = $wrangler -match '"vectorize"\s*:'
Add-Check "worker_vectorize_binding" $vectorizeBinding `
  "wrangler.jsonc must declare a vectorize binding for the runtime to query the index."
if (-not $vectorizeBinding) { $blockers.Add("worker_vectorize_binding") }

$aiBinding = $wrangler -match '"ai"\s*:'
Add-Check "worker_ai_binding" $aiBinding `
  "wrangler.jsonc must declare a Workers AI binding to produce embeddings inside the Worker."
if (-not $aiBinding) { $blockers.Add("worker_ai_binding") }

# Deliberately matches binding USE, not the words. A substring match on "vectorize" or "semantic"
# reports green on this very file today, because the Worker contains `vectorize: "owner_gate_required"`
# and a non-claim sentence about pgvector parity - both of which say the opposite of "implemented".
$semanticRoute = ($workerSource -match 'env\.VECTORIZE') -and ($workerSource -match 'env\.AI\b')
Add-Check "worker_semantic_route" $semanticRoute `
  "The Worker must actually use env.VECTORIZE and env.AI, not merely mention Vectorize in a non-claim."
if (-not $semanticRoute) { $blockers.Add("worker_semantic_route") }

# --- 6) Hosted semantic roundtrip ---------------------------------------------------------------
# The decisive check. It is built so a lexical engine cannot pass it: the query shares no content
# word with the target sentence, and a topically unrelated decoy is stored alongside. Only cosine
# retrieval over embeddings can rank the target first, which is exactly what D1 cannot do.
$roundtripProven = $false
$roundtripDetail = "not attempted; pass -AllowHostedRoundtrip"
$roundtripEvidence = $null
if ($AllowHostedRoundtrip -and $blockers.Count -eq 0) {
  $secrets = Read-SecretMap $SecretsPath
  $workerToken = if ($secrets.ContainsKey("AGENT_API_AUTH_TOKEN")) { $secrets["AGENT_API_AUTH_TOKEN"] } else { "" }
  if ([string]::IsNullOrWhiteSpace($workerToken)) {
    $roundtripDetail = "worker write token is not configured"
  } else {
    $writeHeaders = @{ "x-superbrain-agent-token" = $workerToken; "Content-Type" = "application/json" }
    $readHeaders = @{ "x-superbrain-agent-token" = $workerToken }
    $target = "A tabby cat dozed on the warm windowsill through the quiet afternoon."
    $decoy = "Quarterly invoice reconciliation for the logistics subcontractor was completed."
    $query = "feline napping in sunshine"
    try {
      foreach ($text in @($target, $decoy)) {
        Invoke-RestMethod -Method Post -Uri "$HostedBaseUrl/api/v1/memory/semantic" -Headers $writeHeaders `
          -Body (@{ project_id = "o5-semantic-proof"; text = $text } | ConvertTo-Json) -TimeoutSec 60 | Out-Null
      }
      $encoded = [uri]::EscapeDataString($query)
      $search = $null
      for ($attempt = 1; $attempt -le 8; $attempt++) {
        Start-Sleep -Seconds 15
        $candidate = Invoke-RestMethod -Method Get `
          -Uri "$HostedBaseUrl/api/v1/memory/semantic/search?q=$encoded&top_k=3" -Headers $readHeaders -TimeoutSec 60
        if ([int]$candidate.match_count -gt 0) { $search = $candidate; break }
      }
      if ($null -eq $search) {
        $roundtripDetail = "index did not become queryable within the retry budget"
      } else {
        $top = @($search.matches)[0]
        $queryWords = @(($query.ToLowerInvariant() -split '\W+') | Where-Object { $_.Length -gt 3 })
        $topWords = @((([string]$top.text).ToLowerInvariant() -split '\W+') | Where-Object { $_.Length -gt 3 })
        $overlap = @($queryWords | Where-Object { $topWords -contains $_ })
        $roundtripProven = (
          ([string]$top.text -eq $target) -and
          ($overlap.Count -eq 0) -and
          ([string]$search.retrieval_mode -eq "semantic_vector_cosine")
        )
        $roundtripDetail = "top score $($top.score) with $($overlap.Count) shared content words"
        $roundtripEvidence = [ordered]@{
          retrieval_mode           = [string]$search.retrieval_mode
          top_score                = $top.score
          top_is_target            = ([string]$top.text -eq $target)
          lexical_overlap_words    = $overlap.Count
          runner_up_score          = if (@($search.matches).Count -gt 1) { @($search.matches)[1].score } else { $null }
          model                    = [string]$search.model
          dimensions               = [int]$search.dimensions
        }
      }
    } catch {
      $roundtripDetail = "hosted roundtrip request failed"
    }
  }
}
Add-Check "hosted_semantic_roundtrip" $roundtripProven $roundtripDetail
if (-not $roundtripProven) { $blockers.Add("hosted_semantic_roundtrip") }

# --- 7) Verdict ----------------------------------------------------------------------------------
$allSatisfied = ($blockers.Count -eq 0)
$status = if ($allSatisfied) { "verified" } else { "blocked" }

if ($RequireHostedProof -and -not $allSatisfied) {
  throw "Live vector memory search cannot be proven: $($blockers -join ', ')"
}

$outDirectory = Split-Path -Parent $OutFile
if ($outDirectory -and -not (Test-Path -LiteralPath $outDirectory)) {
  New-Item -ItemType Directory -Force -Path $outDirectory | Out-Null
}

$report = [ordered]@{
  contract_version                = $contractVersion
  status                          = $status
  gate                            = "live_vector_memory_search"
  provider                        = $requiredProvider
  required_index_name             = $RequiredIndexName
  checks                          = @($checks)
  blockers                        = @($blockers)
  # Explicit non-claims. Everything below stays false until a real hosted semantic roundtrip runs.
  live_verified                   = $false
  hosted_semantic_search_verified = $false
  lexical_evidence_reused         = $false
  paid_provider                   = $false
  secret_output                   = $false
  percentage_credit               = 0
  non_claims                      = @(
    "This verifier never sets live_verified; only a real hosted semantic roundtrip may do that.",
    "The lexical Cloudflare D1 memory proof is not semantic vector retrieval and is not reused here.",
    "A readable Vectorize scope is not an architecture approval and not a retrieval proof.",
    "No index, embedding, upsert, or query was created or executed by this verifier."
  )
}

if ($null -ne $roundtripEvidence) { $report["hosted_roundtrip"] = $roundtripEvidence }
if ($allSatisfied) {
  $report["live_verified"] = $true
  $report["hosted_semantic_search_verified"] = $true
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding UTF8

# Gate promotion happens here and nowhere else. It is impossible to reach without a real roundtrip,
# because $allSatisfied requires the zero-lexical-overlap retrieval assertion above to have passed.
if ($PromoteGateOnFullPass) {
  if (-not $allSatisfied) {
    throw "Refusing to promote live_vector_memory_search: $($blockers -join ', ')"
  }
  $evidenceHash = (Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash
  $gate.live_verified = $true
  $gate.hosted_semantic_search_verified = $true
  $gate.evidence_artifact = ($OutFile -replace '\\', '/')
  $gate.evidence_sha256 = $evidenceHash
  $gate.verified_at_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $CapabilityStatePath -Encoding UTF8
  Write-Host "[vector-search] capability gate promoted by verifier evidence $evidenceHash"
}

Write-Host ""
Write-Host "[vector-search] status=$status blockers=$($blockers.Count) evidence=$OutFile"
if ($allSatisfied) {
  Write-Host "[vector-search] semantic retrieval proven by hosted roundtrip; lexical D1 evidence not reused"
} else {
  Write-Host "[vector-search] live_verified stays false by contract"
}
exit 0
