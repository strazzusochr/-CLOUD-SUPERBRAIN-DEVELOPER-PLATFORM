param(
  [string]$ReleaseId = "",
  [string]$BaseUrl = "https://188-34-191-140.sslip.io",
  [switch]$AllowLocalhost,
  [switch]$ReportOnly,
  [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

function Assert-Equal($Label, $Actual, $Expected) {
  if ($Actual -ne $Expected) {
    throw "Phase5 active security evidence bundle verification failed: $Label expected '$Expected' but got '$Actual'."
  }
}

function Assert-True($Label, $Condition) {
  if (-not $Condition) {
    throw "Phase5 active security evidence bundle verification failed: $Label"
  }
}

function Assert-False($Label, $Value) {
  if ([bool]$Value) {
    throw "Phase5 active security evidence bundle verification failed: $Label expected false."
  }
}

function Assert-Contains($Label, $Value, $Expected) {
  $text = ($Value | Out-String)
  if (-not $text.Contains($Expected)) {
    throw "Phase5 active security evidence bundle verification failed: $Label missing '$Expected'."
  }
}

function Assert-NotSecretBearing($Label, $Value) {
  $text = ($Value | Out-String)
  $forbiddenPattern = "sk-proj-[A-Za-z0-9_-]{16,}|github_pat_[A-Za-z0-9_]{16,}|ghp_[A-Za-z0-9_]{16,}|vck_[A-Za-z0-9_-]{24,}|cfat_[A-Za-z0-9_-]{24,}|hcloud_[A-Za-z0-9_-]{16,}|\bhf_[A-Za-z0-9_-]{24,}|glpat-[A-Za-z0-9_.-]{20,}|Authorization: Bearer|Bearer [A-Za-z0-9_.-]{16,}|Cookie:|Set-Cookie:|BEGIN PRIVATE KEY|private key|raw_file_contents|redaction-proof-value"
  if ($text -match $forbiddenPattern) {
    throw "Phase5 active security evidence bundle verification failed: $Label contained a forbidden secret/raw-payload pattern."
  }
}

function Assert-Sha($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^[0-9a-f]{40}$') {
    throw "Phase5 active security evidence bundle verification failed: $Label is not a lowercase 40-character SHA."
  }
}

function Assert-ReleaseId($Label, $Value) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch '^prod-candidate-[0-9]{4}-[0-9]{2}-[0-9]{2}-rc[0-9]+$') {
    throw "Phase5 active security evidence bundle verification failed: $Label is not a valid release candidate id."
  }
}

function Header-Value($Response, [string]$Name) {
  $value = $Response.Headers[$Name]
  if ($value -is [array]) { return [string]$value[0] }
  return [string]$value
}

function Invoke-JsonApi($Url) {
  return Invoke-RestMethod -Method Get -Uri $Url -Headers @{ Accept = "application/json" } -TimeoutSec 60
}

function Invoke-ExportSurface($Surface, [string]$BaseUrl) {
  $contract = Invoke-JsonApi "$BaseUrl$($Surface.ContractPath)"
  Assert-Equal "$($Surface.Id) contract version" $contract.contract_version $Surface.ContractVersion
  Assert-Equal "$($Surface.Id) evidence ref" $contract.evidence_ref $Surface.EvidenceRef
  Assert-Equal "$($Surface.Id) audit evidence ref" $contract.export_audit_evidence_ref $Surface.AuditEvidenceRef
  Assert-Equal "$($Surface.Id) redaction evidence ref" $contract.redaction_evidence_ref $Surface.RedactionEvidenceRef
  Assert-True "$($Surface.Id) read only" $contract.read_only
  Assert-True "$($Surface.Id) audit persisted" $contract.audit_persisted
  Assert-False "$($Surface.Id) production rollout claim" $contract.production_rollout_claimed
  Assert-False "$($Surface.Id) promotion allowed" $contract.promotion_allowed
  Assert-NotSecretBearing "$($Surface.Id) contract" ($contract | ConvertTo-Json -Depth 20 -Compress)

  $traceId = "$($Surface.Id)-phase5-bundle-" + [Guid]::NewGuid().ToString("N")
  $requestId = "req-$($Surface.Id)-phase5-bundle-" + [Guid]::NewGuid().ToString("N")
  $separator = if ($Surface.ExportPath.Contains("?")) { "&" } else { "?" }
  $response = Invoke-WebRequest -UseBasicParsing -Method Get -Uri "$BaseUrl$($Surface.ExportPath)${separator}trace_id=$traceId&request_id=$requestId" -TimeoutSec 60
  Assert-Equal "$($Surface.Id) export status" ([int]$response.StatusCode) 200
  Assert-Contains "$($Surface.Id) content type" (Header-Value $response "Content-Type") "text/csv"
  Assert-Equal "$($Surface.Id) response contract" (Header-Value $response "X-Contract-Version") $Surface.ContractVersion
  Assert-Equal "$($Surface.Id) response evidence" (Header-Value $response "X-Evidence-Ref") $Surface.EvidenceRef
  Assert-Equal "$($Surface.Id) response audit evidence" (Header-Value $response "X-Export-Audit-Evidence-Ref") $Surface.AuditEvidenceRef
  Assert-Equal "$($Surface.Id) response redaction evidence" (Header-Value $response "X-Redaction-Evidence-Ref") $Surface.RedactionEvidenceRef
  Assert-Equal "$($Surface.Id) response trace" (Header-Value $response "X-Trace-Id") $traceId
  Assert-Equal "$($Surface.Id) response request" (Header-Value $response "X-Request-Id") $requestId
  Assert-Contains "$($Surface.Id) csv header" ([string]$response.Content) $Surface.ExpectedHeaderStart
  Assert-Contains "$($Surface.Id) csv redaction evidence" ([string]$response.Content) $Surface.RedactionEvidenceRef
  Assert-NotSecretBearing "$($Surface.Id) csv" ([string]$response.Content)

  return [pscustomobject]@{
    id = $Surface.Id
    contract_version = $Surface.ContractVersion
    event_type = $Surface.AuditEventType
    evidence_ref = $Surface.EvidenceRef
    audit_evidence_ref = $Surface.AuditEvidenceRef
    trace_id = $traceId
    request_id = $requestId
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    throw "BaseUrl is required"
  }
  $BaseUrl = $BaseUrl.TrimEnd("/")
  if ((-not $AllowLocalhost) -and ($BaseUrl -notmatch "^https://")) {
    throw "Phase5 active security evidence bundle requires HTTPS unless -AllowLocalhost is set."
  }

  $configPath = "docs\release-artifacts\current-release-candidate.json"
  if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Missing current release candidate config: $configPath"
  }
  $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  $activeReleaseId = [string]$config.active_release_id
  if ([string]::IsNullOrWhiteSpace($ReleaseId)) {
    $ReleaseId = $activeReleaseId
  }
  Assert-Equal "release id" $ReleaseId $activeReleaseId
  Assert-ReleaseId "release id" $ReleaseId
  Assert-False "production rollout claimed" $config.production_rollout_claimed

  $candidatePath = "docs\release-artifacts\$ReleaseId.md"
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    throw "Missing active release candidate artifact: $candidatePath"
  }
  $candidate = Get-Content -LiteralPath $candidatePath -Raw
  Assert-Contains "candidate id" $candidate "release_id: ``$ReleaseId``"
  Assert-Contains "candidate environment" $candidate "environment: ``production-candidate``"
  Assert-Contains "candidate non-claim" $candidate "This artifact does not claim a production rollout."
  Assert-Contains "candidate security bundle proof" $candidate "active_security_evidence_bundle_proof: ``docs/release-artifacts/$ReleaseId-active-security-evidence-bundle-20260514.md``"
  Assert-Contains "candidate immutable parity verified" $candidate "immutable_staging_parity_status: ``verified``"

  if ($candidate -notmatch '(?m)^source_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Active release artifact is missing source_commit_sha."
  }
  $sourceSha = $Matches[1]
  Assert-Sha "source commit sha" $sourceSha
  if ($candidate -notmatch '(?m)^immutable_image_commit_sha:\s*`([^`]+)`\s*$') {
    throw "Active release artifact is missing immutable_image_commit_sha."
  }
  $immutableSha = $Matches[1]
  Assert-Sha "immutable image commit sha" $immutableSha
  Assert-Contains "candidate hosted selector" $candidate "hosted_selector_observed: ``IMAGE_TAG=$immutableSha``"

  $proofPath = "docs\release-artifacts\$ReleaseId-active-security-evidence-bundle-20260514.md"
  if (-not (Test-Path -LiteralPath $proofPath)) {
    throw "Missing active security evidence bundle proof: $proofPath"
  }
  $proof = Get-Content -LiteralPath $proofPath -Raw
  foreach ($required in @(
    "Status: ``verified``",
    "release_id: ``$ReleaseId``",
    "source_commit_sha: ``$sourceSha``",
    "immutable_image_commit_sha: ``$immutableSha``",
    "production_rollout_claimed: ``false``",
    "bundle_status: ``passed``",
    "security_export_surface_count: ``5``",
    "This proof does not claim a production rollout.",
    "This proof does not include secret values."
  )) {
    Assert-Contains "security evidence proof artifact" $proof $required
  }
  if ($AllowLocalhost) {
    Assert-Contains "security evidence proof local command" $proof "scripts\verify-phase5-active-security-evidence-bundle.ps1 -BaseUrl http://localhost:8081 -AllowLocalhost"
  } else {
    Assert-Contains "security evidence proof base url" $proof "base_url: ``$BaseUrl``"
  }

  $surfaces = @(
    [pscustomobject]@{
      Id = "llm-audit"
      ContractPath = "/api/v1/audit/llm/export/contract"
      ExportPath = "/api/v1/audit/llm/export?format=csv&limit=80"
      ContractVersion = "llm-audit-export-v1"
      EvidenceRef = "llm_audit_export_visible"
      AuditEvidenceRef = "llm_audit_export_audit_persisted"
      RedactionEvidenceRef = "llm_audit_redaction_enforced"
      AuditEventType = "llm_audit_export_generated"
      ExpectedHeaderStart = "sequence_index,event_id,created_at,event_type,severity,trace_id"
    },
    [pscustomobject]@{
      Id = "mcp-audit"
      ContractPath = "/api/v1/audit/mcp/export/contract"
      ExportPath = "/api/v1/audit/mcp/export?format=csv&limit=80"
      ContractVersion = "mcp-audit-export-v1"
      EvidenceRef = "mcp_audit_export_visible"
      AuditEvidenceRef = "mcp_audit_export_audit_persisted"
      RedactionEvidenceRef = "mcp_audit_redaction_enforced"
      AuditEventType = "mcp_audit_export_generated"
      ExpectedHeaderStart = "sequence_index,event_id,created_at,event_type,severity,trace_id"
    },
    [pscustomobject]@{
      Id = "gateway-correlation"
      ContractPath = "/api/v1/security/gateway-correlation/export/contract"
      ExportPath = "/api/v1/security/gateway-correlation/export?format=csv&limit=80"
      ContractVersion = "gateway-correlation-export-v1"
      EvidenceRef = "gateway_correlation_export_visible"
      AuditEvidenceRef = "gateway_correlation_export_audit_persisted"
      RedactionEvidenceRef = "gateway_correlation_redaction_enforced"
      AuditEventType = "gateway_correlation_export_generated"
      ExpectedHeaderStart = "sequence_index,correlation_key,trace_id,request_id"
    },
    [pscustomobject]@{
      Id = "auth-audit"
      ContractPath = "/api/v1/audit/auth/export/contract"
      ExportPath = "/api/v1/audit/auth/export?format=csv&limit=80"
      ContractVersion = "auth-audit-export-v1"
      EvidenceRef = "auth_audit_export_visible"
      AuditEvidenceRef = "auth_audit_export_audit_persisted"
      RedactionEvidenceRef = "auth_audit_redaction_enforced"
      AuditEventType = "auth_audit_export_generated"
      ExpectedHeaderStart = "sequence_index,event_id,created_at,event_type,lifecycle_step,status"
    },
    [pscustomobject]@{
      Id = "security-review"
      ContractPath = "/api/v1/security/review-queue/export/contract"
      ExportPath = "/api/v1/security/review-queue/export?format=csv&limit=80"
      ContractVersion = "security-review-queue-export-v1"
      EvidenceRef = "security_review_queue_export_visible"
      AuditEvidenceRef = "security_review_queue_export_audit_persisted"
      RedactionEvidenceRef = "security_review_redaction_enforced"
      AuditEventType = "security_review_queue_export_generated"
      ExpectedHeaderStart = "sequence_index,queue_item_id,source_event_id,created_at,event_type"
    }
  )

  $results = @()
  foreach ($surface in $surfaces) {
    $results += Invoke-ExportSurface -Surface $surface -BaseUrl $BaseUrl
  }

  Start-Sleep -Milliseconds 700
  $recentAudit = Invoke-JsonApi "$BaseUrl/api/v1/audit/recent?limit=100"
  $recentAuditText = $recentAudit | ConvertTo-Json -Depth 30 -Compress
  Assert-NotSecretBearing "recent audit bundle" $recentAuditText
  foreach ($result in $results) {
    $record = @($recentAudit.events) | Where-Object {
      $_.event_type -eq $result.event_type -and
      $_.details.trace_id -eq $result.trace_id -and
      $_.details.request_id -eq $result.request_id
    } | Select-Object -First 1
    Assert-True "$($result.id) export audit persisted" ($null -ne $record)
    Assert-Equal "$($result.id) persisted audit evidence" $record.details.evidence_ref $result.audit_evidence_ref
  }

  $summary = [ordered]@{
    status = "passed"
    passed = $true
    release_id = $ReleaseId
    base_url = $BaseUrl
    source_commit_sha = $sourceSha
    immutable_image_commit_sha = $immutableSha
    production_rollout_claimed = $false
    security_export_surface_count = @($surfaces).Count
    surfaces = @($results)
    policy = [ordered]@{
      mutates_production = $false
      deploys_production = $false
      claims_rollout = $false
      includes_secrets = $false
      live_provider_calls_claimed = $false
      live_mcp_writes_claimed = $false
    }
  }

  if ($JsonOnly) {
    $summary | ConvertTo-Json -Depth 8
  } else {
    Write-Host "[phase5-active-security-evidence-bundle] verified"
    Write-Host "[phase5-active-security-evidence-bundle] release_id=$ReleaseId"
    Write-Host "[phase5-active-security-evidence-bundle] security_export_surface_count=$(@($surfaces).Count)"
  }
} catch {
  if ($ReportOnly) {
    throw
  }
  throw
} finally {
  Pop-Location
}
