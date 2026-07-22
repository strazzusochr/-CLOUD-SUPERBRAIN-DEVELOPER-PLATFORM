param(
  [string]$CapabilityStatePath = "docs\runtime-state\capability-gates.json",
  [string]$AgentApiPath = "services\agent-api\app\main.py",
  [string]$ManifestPath = "docs\project-progress.manifest.json",
  [string]$OutFile = ".phase1-artifacts\vector-memory-gate-proof.json"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$proofLabel = "DEV-ONLY; hosted proof still blocked"
$vectorBlocker = "live_vector_memory_search_requires_owner_vectorize_scope_architecture_approval_and_hosted_proof"
$pendingMarker = "hosted_lexical_memory_only_vector_search_vectorize_pending"
$reservedVerifier = "scripts/verify-live-vector-memory-search.ps1"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) {
    throw "Vector-memory gate verification failed: $Label"
  }
  Write-Host "[vector-memory] $Label"
}

function Get-Sha256Hex([string]$Path) {
  $stream = [IO.File]::OpenRead([IO.Path]::GetFullPath($Path))
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return [BitConverter]::ToString($sha256.ComputeHash($stream)).Replace("-", "")
  } finally {
    $sha256.Dispose()
    $stream.Dispose()
  }
}

foreach ($path in @($CapabilityStatePath, $AgentApiPath, $ManifestPath)) {
  Assert-True "required input exists: $path" (Test-Path -LiteralPath $path -PathType Leaf)
}

$inputHashesBefore = @{}
foreach ($path in @($CapabilityStatePath, $AgentApiPath, $ManifestPath)) {
  $inputHashesBefore[$path] = Get-Sha256Hex $path
}

$state = Get-Content -LiteralPath $CapabilityStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
$gateNames = @($state.gates.PSObject.Properties.Name)
Assert-True "lexical and vector capability gates are distinct" (
  $gateNames -contains "live_memory_provider" -and
  $gateNames -contains "live_vector_memory_search"
)

$lexicalGate = $state.gates.live_memory_provider
$vectorGate = $state.gates.live_vector_memory_search
Assert-True "lexical gate is the verified Cloudflare D1 persistence evidence" (
  [string]$lexicalGate.provider -eq "cloudflare_d1" -and
  [bool]$lexicalGate.owner_granted -and
  [bool]$lexicalGate.live_verified -and
  -not [string]::IsNullOrWhiteSpace([string]$lexicalGate.evidence_artifact)
)
Assert-True "D1 note limits the verified scope to lexical persistence" (
  [string]$lexicalGate.note -match "lexical persistence" -and
  [string]$lexicalGate.note -match "does not prove" -and
  [string]$lexicalGate.note -match "semantic retrieval"
)
Assert-True "vector gate names Cloudflare Vectorize but has no evidence artifact" (
  [string]$vectorGate.provider -eq "cloudflare_vectorize" -and
  [string]::IsNullOrWhiteSpace([string]$vectorGate.evidence_artifact)
)
Assert-True "vector gate remains owner- and live-unverified" (
  -not [bool]$vectorGate.owner_granted -and
  -not [bool]$vectorGate.live_verified
)
Assert-True "vector gate approval and semantic proof flags all fail closed" (
  -not [bool]$vectorGate.owner_scope_approved -and
  -not [bool]$vectorGate.architecture_approved -and
  -not [bool]$vectorGate.hosted_semantic_search_verified
)
Assert-True "vector gate reserves the exact future live verifier" ([string]$vectorGate.verifier -eq $reservedVerifier)
Assert-True "vector note requires Owner scope, architecture approval, and hosted semantic proof" (
  [string]$vectorGate.note -match "Owner Vectorize scope" -and
  [string]$vectorGate.note -match "architecture approval" -and
  [string]$vectorGate.note -match "hosted semantic retrieval proof"
)
Assert-True "lexical evidence is not reused as vector evidence" (
  [string]$lexicalGate.provider -ne [string]$vectorGate.provider -and
  [string]$lexicalGate.evidence_artifact -ne [string]$vectorGate.evidence_artifact
)

$apiSource = Get-Content -LiteralPath $AgentApiPath -Raw -Encoding UTF8
$stateStart = $apiSource.IndexOf("def capability_gate_state()")
$openStart = $apiSource.IndexOf("def capability_gate_open(")
$externalStart = $apiSource.IndexOf("def external_gate_summary_path()")
Assert-True "capability gate functions are discoverable" ($stateStart -ge 0 -and $openStart -gt $stateStart -and $externalStart -gt $openStart)
$sanitizerSource = $apiSource.Substring($stateStart, $openStart - $stateStart)
$openSource = $apiSource.Substring($openStart, $externalStart - $openStart)

foreach ($required in @(
  '"live_vector_memory_search"',
  'entry.get("owner_granted") is True',
  'entry.get("live_verified") is True',
  'entry.get("owner_scope_approved") is True',
  'entry.get("architecture_approved") is True',
  'entry.get("hosted_semantic_search_verified") is True',
  'entry.get("paid_provider") is False',
  'provider == "cloudflare_vectorize"',
  'verifier == "scripts/verify-live-vector-memory-search.ps1"'
)) {
  Assert-True "sanitized vector gate requires: $required" $sanitizerSource.Contains($required)
}
foreach ($required in @(
  'gate_id != "live_vector_memory_search"',
  'entry.get("owner_granted") is True',
  'entry.get("live_verified") is True',
  'entry.get("owner_scope_approved") is True',
  'entry.get("architecture_approved") is True',
  'entry.get("hosted_semantic_search_verified") is True',
  'entry.get("paid_provider") is False',
  'entry.get("provider") == "cloudflare_vectorize"',
  'entry.get("verifier") == "scripts/verify-live-vector-memory-search.ps1"'
)) {
  Assert-True "open evaluation requires: $required" $openSource.Contains($required)
}

$layer6Start = $apiSource.IndexOf('"layer_6":')
$layer7Start = $apiSource.IndexOf('"layer_7":', $layer6Start)
Assert-True "Layer 6 completion block is discoverable" ($layer6Start -ge 0 -and $layer7Start -gt $layer6Start)
$layer6Source = $apiSource.Substring($layer6Start, $layer7Start - $layer6Start)
Assert-True "Layer 6 requires lexical provider gate" $layer6Source.Contains('capability_gate_open("live_memory_provider", capability_gates)')
Assert-True "Layer 6 requires vector search gate" $layer6Source.Contains('capability_gate_open("live_vector_memory_search", capability_gates)')
Assert-True "Layer 6 surfaces the exact vector blocker" $layer6Source.Contains($vectorBlocker)

$dynamicProbeSource = @'
import ast
import json
import sys

source_path, manifest_path = sys.argv[1:3]
source = open(source_path, encoding="utf-8-sig").read()
tree = ast.parse(source, filename=source_path)
required_functions = {
    "_completion_status",
    "project_progress_completion_payload",
    "capability_gate_state",
    "capability_gate_open",
}
required_assignments = {
    "CAPABILITY_GATE_IDS",
    "PROGRESS_COMPLETION_CONTRACT_VERSION",
    "PROGRESS_COMPLETION_EVIDENCE_REF",
}
selected = []
for node in tree.body:
    if isinstance(node, ast.FunctionDef) and node.name in required_functions:
        selected.append(node)
    elif isinstance(node, ast.Assign) and any(
        isinstance(target, ast.Name) and target.id in required_assignments
        for target in node.targets
    ):
        selected.append(node)
module = ast.Module(body=selected, type_ignores=[])
namespace = {"json": json}
exec(compile(module, source_path, "exec"), namespace)
assert required_functions <= namespace.keys()
assert required_assignments <= namespace.keys()

class MemoryPath:
    def __init__(self, text=None, exists=True):
        self.text = text
        self.exists_value = exists

    def exists(self):
        return self.exists_value

    def read_text(self, **_kwargs):
        return self.text

state_reader = namespace["capability_gate_state"]
gate_open = namespace["capability_gate_open"]

def read_state(raw=None, *, exists=True):
    namespace["capability_gate_path"] = lambda: MemoryPath(raw, exists=exists)
    return state_reader()

def vector_entry(**overrides):
    entry = {
        "owner_granted": True,
        "live_verified": True,
        "evidence_artifact": ".codex/runs/CURRENT/capability/live-vector-memory-search/report.json",
        "verified_at_utc": "future-proof",
        "provider": "cloudflare_vectorize",
        "paid_provider": False,
        "verifier": "scripts/verify-live-vector-memory-search.ps1",
        "owner_scope_approved": True,
        "architecture_approved": True,
        "hosted_semantic_search_verified": True,
    }
    entry.update(overrides)
    return entry

def configured_state(entry):
    return read_state(json.dumps({
        "contract_version": "capability-gate-state-v1",
        "status": "configured",
        "gates": {"live_vector_memory_search": entry},
        "non_claims": [],
    }))

missing_state = read_state(exists=False)
assert missing_state["status"] == "missing_state"
assert gate_open("live_vector_memory_search", missing_state) is False
malformed_state = read_state("{")
assert malformed_state["status"] == "unreadable_state"
assert gate_open("live_vector_memory_search", malformed_state) is False

invalid_cases = {
    "owner_false": {"owner_granted": False},
    "live_false": {"live_verified": False},
    "artifact_empty": {"evidence_artifact": ""},
    "paid_provider": {"paid_provider": True},
    "owner_scope_false": {"owner_scope_approved": False},
    "architecture_false": {"architecture_approved": False},
    "hosted_semantic_false": {"hosted_semantic_search_verified": False},
    "provider_mismatch": {"provider": "cloudflare_d1"},
    "verifier_mismatch": {"verifier": "scripts/verify-live-memory-provider.ps1"},
    "boolean_type_mismatch": {"owner_scope_approved": "true"},
}
for label, override in invalid_cases.items():
    state = configured_state(vector_entry(**override))
    entry = state["gates"]["live_vector_memory_search"]
    assert entry["live_verified"] is False, label
    assert gate_open("live_vector_memory_search", state) is False, label

valid_vector_state = configured_state(vector_entry())
valid_vector_entry = valid_vector_state["gates"]["live_vector_memory_search"]
assert valid_vector_entry["live_verified"] is True
assert gate_open("live_vector_memory_search", valid_vector_state) is True

manifest = json.load(open(manifest_path, encoding="utf-8-sig"))
generic_entry = {
    "owner_granted": True,
    "live_verified": True,
    "evidence_artifact": "ignored-local-proof",
    "paid_provider": False,
}
all_gates_valid = {
    gate_id: dict(generic_entry)
    for gate_id in namespace["CAPABILITY_GATE_IDS"]
}
all_gates_valid["live_vector_memory_search"] = dict(valid_vector_entry)
vector_invalid = {gate_id: dict(entry) for gate_id, entry in all_gates_valid.items()}
vector_invalid["live_vector_memory_search"]["owner_scope_approved"] = False

namespace["project_progress_payload"] = lambda: manifest
namespace["external_gate_verification_flags"] = lambda _progress: {
    "hosted_staging": True,
    "branch_protection": True,
    "canonical_secret_scan": True,
    "fly_cloud_stack": True,
    "production_gate_claim_allowed": True,
}
namespace["external_gate_state"] = lambda: {"gates": []}
completion = namespace["project_progress_completion_payload"]

namespace["capability_gate_state"] = lambda: {"gates": vector_invalid}
blocked_payload = completion()
namespace["capability_gate_state"] = lambda: {"gates": all_gates_valid}
valid_payload = completion()

blocker = "live_vector_memory_search_requires_owner_vectorize_scope_architecture_approval_and_hosted_proof"
blocked_layers = {item["id"]: item["blockers"] for item in blocked_payload["layer_completion"]}
valid_layers = {item["id"]: item["blockers"] for item in valid_payload["layer_completion"]}
assert blocked_layers["layer_6"] == [blocker]
assert valid_layers["layer_6"] == []
assert {
    key: value for key, value in blocked_layers.items() if key != "layer_6"
} == {
    key: value for key, value in valid_layers.items() if key != "layer_6"
}
assert blocked_payload["phase_completion"] == valid_payload["phase_completion"]
assert set(blocked_payload["hard_blockers"]) - set(valid_payload["hard_blockers"]) == {blocker}
assert set(valid_payload["hard_blockers"]) - set(blocked_payload["hard_blockers"]) == set()
assert valid_payload["can_set_all_to_100"] is False

print(json.dumps({
    "missing_blocked": True,
    "malformed_blocked": True,
    "invalid_cases_blocked": sorted(invalid_cases),
    "fully_valid_vector_gate_open": True,
    "fully_valid_clears_only_vector_blocker": True,
}))
'@

$previousErrorActionPreference = $ErrorActionPreference
$nativePreferenceVariable = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
if ($nativePreferenceVariable) {
  $previousNativePreference = $nativePreferenceVariable.Value
  Set-Variable -Name PSNativeCommandUseErrorActionPreference -Value $false
}
$ErrorActionPreference = "Continue"
try {
  $dynamicProbeOutput = $dynamicProbeSource | py -3 - $AgentApiPath $ManifestPath
  $dynamicProbeExit = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousErrorActionPreference
  if ($nativePreferenceVariable) {
    Set-Variable -Name PSNativeCommandUseErrorActionPreference -Value $previousNativePreference
  }
}
Assert-True "isolated dynamic vector gate probe exited successfully" ($dynamicProbeExit -eq 0)
$dynamicProbe = ($dynamicProbeOutput -join "`n") | ConvertFrom-Json
Assert-True "missing capability state blocks vector gate" ([bool]$dynamicProbe.missing_blocked)
Assert-True "malformed capability state blocks vector gate" ([bool]$dynamicProbe.malformed_blocked)
Assert-True "paid, malformed-type, and incomplete approval cases block vector gate" (@($dynamicProbe.invalid_cases_blocked).Count -eq 10)
Assert-True "fully valid vector evidence opens the vector gate" ([bool]$dynamicProbe.fully_valid_vector_gate_open)
Assert-True "fully valid vector evidence clears only the vector blocker" ([bool]$dynamicProbe.fully_valid_clears_only_vector_blocker)

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$memoryItems = @($manifest.vertical.items | Where-Object { [string]$_.id -eq "layer_6" })
Assert-True "manifest has exactly one Memory layer" ($memoryItems.Count -eq 1)
$memory = $memoryItems[0]
Assert-True "manifest Memory remains at 90 percent" ([int]$memory.percent -eq 90)
Assert-True "manifest keeps the Vectorize pending marker" ([string]$memory.status -match [regex]::Escape($pendingMarker))

$parseTokens = $null
$parseErrors = $null
$verifierAst = [Management.Automation.Language.Parser]::ParseFile(
  $PSCommandPath,
  [ref]$parseTokens,
  [ref]$parseErrors
)
Assert-True "verifier has no PowerShell parser errors" (@($parseErrors).Count -eq 0)
$commandNames = @(
  $verifierAst.FindAll(
    { param($node) $node -is [Management.Automation.Language.CommandAst] },
    $true
  ) | ForEach-Object { $_.GetCommandName() } | Where-Object { $_ }
)
foreach ($forbiddenCommand in @(
  "Invoke-RestMethod",
  "Invoke-WebRequest",
  "curl",
  "curl.exe",
  "wget",
  "wrangler",
  "docker",
  "ssh",
  "scp"
)) {
  Assert-True "verifier makes no network/provider call via $forbiddenCommand" ($commandNames -notcontains $forbiddenCommand)
}

$repoRoot = (Resolve-Path -LiteralPath ".").Path
$outFullPath = if ([IO.Path]::IsPathRooted($OutFile)) {
  [IO.Path]::GetFullPath($OutFile)
} else {
  [IO.Path]::GetFullPath((Join-Path $repoRoot $OutFile))
}
$repoPrefix = $repoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
Assert-True "evidence output stays inside the repository" $outFullPath.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)
$outRelativePath = $outFullPath.Substring($repoPrefix.Length)
$previousErrorActionPreference = $ErrorActionPreference
$nativePreferenceVariable = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
if ($nativePreferenceVariable) {
  $previousNativePreference = $nativePreferenceVariable.Value
  Set-Variable -Name PSNativeCommandUseErrorActionPreference -Value $false
}
$ErrorActionPreference = "Continue"
try {
  git check-ignore --quiet -- $outRelativePath
  $ignoreExit = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousErrorActionPreference
  if ($nativePreferenceVariable) {
    Set-Variable -Name PSNativeCommandUseErrorActionPreference -Value $previousNativePreference
  }
}
Assert-True "evidence output is git-ignored" ($ignoreExit -eq 0)

$report = [ordered]@{
  contract_version = "vector-memory-gate-static-proof-v1"
  status = "verified_blocked"
  label = $proofLabel
  evidence_ref = "live_vector_memory_search_fail_closed"
  lexical_memory = [ordered]@{
    provider = [string]$lexicalGate.provider
    live_verified = [bool]$lexicalGate.live_verified
    scope = "hosted_lexical_persistence_only"
    evidence_artifact = [string]$lexicalGate.evidence_artifact
  }
  vector_memory = [ordered]@{
    gate_id = "live_vector_memory_search"
    provider = [string]$vectorGate.provider
    owner_granted = [bool]$vectorGate.owner_granted
    owner_scope_approved = [bool]$vectorGate.owner_scope_approved
    architecture_approved = [bool]$vectorGate.architecture_approved
    hosted_semantic_search_verified = [bool]$vectorGate.hosted_semantic_search_verified
    live_verified = [bool]$vectorGate.live_verified
    evidence_artifact = [string]$vectorGate.evidence_artifact
    blocker = $vectorBlocker
  }
  manifest = [ordered]@{
    layer_id = "layer_6"
    percent = [int]$memory.percent
    pending_marker = $pendingMarker
  }
  execution_guards = [ordered]@{
    network_calls = $false
    provider_calls = $false
    runtime_writes = $false
    canonical_state_writes = $false
    ignored_local_evidence_write_only = $true
  }
  dynamic_cases = $dynamicProbe
}

$outParent = Split-Path -Parent $outFullPath
if (-not (Test-Path -LiteralPath $outParent -PathType Container)) {
  New-Item -ItemType Directory -Path $outParent -Force | Out-Null
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outFullPath -Encoding UTF8

foreach ($path in @($CapabilityStatePath, $AgentApiPath, $ManifestPath)) {
  $afterHash = Get-Sha256Hex $path
  Assert-True "canonical input remained read-only: $path" ($afterHash -eq $inputHashesBefore[$path])
}

Write-Host "[vector-memory] evidence=$outRelativePath"
Write-Host "[vector-memory] $proofLabel"
Write-Host "[vector-memory] checks completed"
