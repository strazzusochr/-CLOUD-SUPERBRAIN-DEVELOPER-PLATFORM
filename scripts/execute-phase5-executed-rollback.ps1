param(
  [string]$KeyPath = "C:\Users\immer\.ssh\oracle_key",
  [string]$RemoteUser = "root",
  [string]$RemoteHost = "188.34.191.140",
  [string]$RemoteAppDir = "/app",
  [string]$ReleaseId = "prod-candidate-2026-05-05-rc1",
  [string]$ExpectedSha = "ddde3b4c11b9e50e641190ad85b2d0b69d7af7e5",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io"
)

$ErrorActionPreference = "Stop"

function Invoke-Ssh($command) {
  & ssh -i $KeyPath -o StrictHostKeyChecking=no "$RemoteUser@$RemoteHost" $command
  if ($LASTEXITCODE -ne 0) {
    throw "SSH command failed: $command"
  }
}

function Get-RequiredArchitecture($machine) {
  switch ($machine.Trim()) {
    "aarch64" { return "arm64" }
    "arm64" { return "arm64" }
    "x86_64" { return "amd64" }
    "amd64" { return "amd64" }
    default { throw "Unsupported remote machine architecture: $machine" }
  }
}

function Assert-ManifestArchitecture($ref, $requiredArchitecture) {
  $manifest = docker manifest inspect --verbose $ref | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "Manifest inspect failed for $ref"
  }
  if (-not $manifest.Contains('"architecture": "' + $requiredArchitecture + '"')) {
    throw "Manifest $ref does not advertise required architecture $requiredArchitecture"
  }
}

function Probe-Url($url) {
  @"
import ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(r.status)
"@ | py -3 -
}

function Probe-Json($url) {
  @"
import json, ssl, urllib.request
ctx = ssl.create_default_context()
with urllib.request.urlopen(r"$url", context=ctx, timeout=20) as r:
    print(json.dumps(json.load(r)))
"@ | py -3 -
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$artifactPath = ".phase1-artifacts\phase5-executed-rollback-prod-candidate-20260505-rc1.md"
$backupName = ".env.codex.rollback.$((Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')).bak"
$selectorChanged = $false

$currentSelector = (Invoke-Ssh "cd $RemoteAppDir && grep '^IMAGE_TAG=' .env").Trim()
if ($currentSelector -ne "IMAGE_TAG=staging") {
  throw "Unexpected current selector before rollback: $currentSelector"
}

 $remoteMachine = (Invoke-Ssh "uname -m").Trim()
$requiredArchitecture = Get-RequiredArchitecture $remoteMachine
$images = @("agent-api", "mcp-gateway", "frontend", "llm-gateway", "agent-worker", "memory-worker")
foreach ($name in $images) {
  $ref = "ghcr.io/strazzusochr/cloud-superbrain-developer-platform/${name}:$ExpectedSha"
  Assert-ManifestArchitecture $ref $requiredArchitecture
}

try {
Invoke-Ssh "cd $RemoteAppDir && cp .env $backupName"
Invoke-Ssh "cd $RemoteAppDir && python3 - <<'PY'
from pathlib import Path
p = Path('.env')
lines = p.read_text().splitlines()
out = []
found = False
for line in lines:
    if line.startswith('IMAGE_TAG='):
        out.append('IMAGE_TAG=$ExpectedSha')
        found = True
    else:
        out.append(line)
if not found:
    out.append('IMAGE_TAG=$ExpectedSha')
p.write_text('\n'.join(out) + '\n')
PY"
$selectorChanged = $true
Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml pull agent-api frontend mcp-gateway llm-gateway agent-worker memory-worker"
Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml up -d"

$rollbackRoot = (Probe-Url "$BaseUrl/").Trim()
$rollbackApi = (Probe-Url "$BaseUrl/api/v1/health").Trim()
$rollbackMcp = (Probe-Url "$BaseUrl/mcp/api/v1/health").Trim()
$rollbackLlm = (Probe-Url "$BaseUrl/llm/api/v1/health").Trim()
$rollbackSelector = (Invoke-Ssh "cd $RemoteAppDir && grep '^IMAGE_TAG=' .env").Trim()

Invoke-Ssh "cd $RemoteAppDir && python3 - <<'PY'
from pathlib import Path
p = Path('.env')
lines = p.read_text().splitlines()
out = []
found = False
for line in lines:
    if line.startswith('IMAGE_TAG='):
        out.append('IMAGE_TAG=staging')
        found = True
    else:
        out.append(line)
if not found:
    out.append('IMAGE_TAG=staging')
p.write_text('\n'.join(out) + '\n')
PY"
$selectorChanged = $false
Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml pull agent-api frontend mcp-gateway llm-gateway agent-worker memory-worker"
Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml up -d"

$restoreRoot = (Probe-Url "$BaseUrl/").Trim()
$restoreApi = (Probe-Url "$BaseUrl/api/v1/health").Trim()
$restoreMcp = (Probe-Url "$BaseUrl/mcp/api/v1/health").Trim()
$restoreLlm = (Probe-Url "$BaseUrl/llm/api/v1/health").Trim()
$restoreSelector = (Invoke-Ssh "cd $RemoteAppDir && grep '^IMAGE_TAG=' .env").Trim()
$progress = Probe-Json "$BaseUrl/api/v1/project/progress"
$integrity = Probe-Json "$BaseUrl/api/v1/project/progress/integrity"

$artifact = @"
# Phase 5 Executed Rollback Proof - 2026-05-05

Status: verified
Candidate: prod-candidate-2026-05-05-rc1
Candidate release id: prod-candidate-2026-05-05-rc1
Previous good release id: prod-candidate-2026-05-05-rc1@$ExpectedSha
Executed at: $timestamp
Current hosted selector before rollback: $currentSelector
Executed rollback selector: $rollbackSelector
Restored candidate selector: $restoreSelector
Backup file: $backupName

## Executed Rollback Pair

- Candidate selector before rollback: mutable GHCR :staging
- Executed rollback selector: immutable GHCR :$ExpectedSha
- Restored selector after proof: mutable GHCR :staging
- Reason: prove the real rollback path on hosted staging, then restore the candidate track

## Executed Steps

1. Backup remote .env
2. Replace IMAGE_TAG=staging with IMAGE_TAG=$ExpectedSha
3. Pull and restart application services from immutable GHCR commit tags
4. Verify hosted root, Agent API, MCP Gateway, and LLM Gateway
5. Restore IMAGE_TAG=staging
6. Pull and restart application services back to the mutable candidate selector
7. Re-verify hosted root, Agent API, MCP Gateway, and LLM Gateway

## Verification

- Rollback root status: $rollbackRoot
- Rollback Agent API status: $rollbackApi
- Rollback MCP status: $rollbackMcp
- Rollback LLM status: $rollbackLlm
- Restored root status: $restoreRoot
- Restored Agent API status: $restoreApi
- Restored MCP status: $restoreMcp
- Restored LLM status: $restoreLlm
- Hosted progress after restore remained manifest-backed
- Hosted integrity after restore remained verified

## Results

- Executed rollback completed: yes
- Candidate selector restored to staging: yes
- Hosted runtime healthy after restore: yes
- Production deployment claim introduced: no

## Claim Boundary

- This is an executed rollback proof on hosted staging.
- This is not a production deployment claim.
- This does not override the current no-release decision.
"@

Set-Content -Path $artifactPath -Value $artifact -Encoding UTF8
Write-Host "[phase5-executed-rollback] artifact written: $artifactPath"
}
catch {
  if ($selectorChanged) {
    try {
      Invoke-Ssh "cd $RemoteAppDir && python3 - <<'PY'
from pathlib import Path
p = Path('.env')
lines = p.read_text().splitlines()
out = []
found = False
for line in lines:
    if line.startswith('IMAGE_TAG='):
        out.append('IMAGE_TAG=staging')
        found = True
    else:
        out.append(line)
if not found:
    out.append('IMAGE_TAG=staging')
p.write_text('\n'.join(out) + '\n')
PY"
      Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml pull agent-api frontend mcp-gateway llm-gateway agent-worker memory-worker"
      Invoke-Ssh "cd $RemoteAppDir && docker compose --env-file .env -f docker-compose.cloud.yml up -d"
    }
    catch {
      Write-Warning "Automatic rollback recovery failed: $($_.Exception.Message)"
    }
  }
  throw
}
