param(
  [string]$BaseUrl = "http://localhost:8081",
  [switch]$AllowLocalhost
)

$ErrorActionPreference = "Stop"

function Assert-Contains($label, $value, $expected) {
  if ($value -notlike "*$expected*") {
    throw "Missing ${label}: expected '$expected'"
  }
}

if ($BaseUrl -match "localhost|127\.0\.0\.1" -and -not $AllowLocalhost) {
  throw "Localhost proof requires -AllowLocalhost"
}

$response = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/api/v1/agents/skill-mode/contract"
$body = $response.Content

Assert-Contains "contract version" $body '"contract_version":"agent-skill-mode-capability-contract-v1"'
Assert-Contains "status" $body '"status":"verified"'
Assert-Contains "evidence" $body '"evidence_ref":"agent_skill_mode_capability_visible"'
Assert-Contains "plugins count" $body '"plugins":11'
Assert-Contains "apps count" $body '"apps":4'
Assert-Contains "mcp count" $body '"mcp_servers":1'
Assert-Contains "skills count" $body '"skills":140'
Assert-Contains "api only" $body '"api_only":true'
Assert-Contains "no direct provider" $body '"direct_provider_calls":false'
Assert-Contains "no local model download" $body '"local_model_downloads":false'
Assert-Contains "no live mcp writes" $body '"live_mcp_writes":false'
Assert-Contains "no external mcp calls" $body '"external_mcp_server_calls":false'
Assert-Contains "no live external marker" $body "agent_skill_mode_no_live_external_calls"
Assert-Contains "no secret marker" $body "agent_skill_mode_no_secret_material"
Assert-Contains "no model marker" $body "agent_skill_mode_no_local_model_downloads"
Assert-Contains "production non-claim" $body "production_rollout_claimed=false"

Write-Host "[agent-skill-mode] checks completed"
