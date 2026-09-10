<#
RETIRED_HISTORICAL_DO_NOT_EXECUTE

The former Fly.io production rollout is not part of the active Cloudflare-native
gate path. This compatibility path is deliberately fail-closed.

Use scripts\owner-cloud-gate-activation.ps1 without -Apply to generate the
current review plan. Hosted writes, deployment, registry publication, release
promotion, and main-branch changes still require their exact Owner gates.
#>

[CmdletBinding()]
param(
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

throw "RETIRED_HISTORICAL_DO_NOT_EXECUTE: use scripts\owner-cloud-gate-activation.ps1 in PlanOnly mode."
