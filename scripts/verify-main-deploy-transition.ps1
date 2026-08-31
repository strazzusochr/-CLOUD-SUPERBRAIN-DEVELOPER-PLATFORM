[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $repoRoot ".github\workflows\main-deploy.yml"
$prCheckPath = Join-Path $repoRoot ".github\workflows\pr-check.yml"
$ghcrVerifierPath = Join-Path $repoRoot "scripts\verify_ghcr_candidate.py"
$phase5CreditVerifierPath = Join-Path $repoRoot "scripts\verify_phase5_credit_itemization.py"

function Assert-True([string]$Label, [bool]$Condition) {
  if (-not $Condition) {
    throw "main-deploy transition verification failed: $Label"
  }
  Write-Host "[main-deploy-transition] PASS $Label"
}

function Assert-Contains([string]$Label, [string]$Text, [string]$Needle) {
  Assert-True $Label $Text.Contains($Needle)
}

function Assert-Regex([string]$Label, [string]$Text, [string]$Pattern) {
  Assert-True $Label ([regex]::IsMatch($Text, $Pattern))
}

function Assert-NotRegex([string]$Label, [string]$Text, [string]$Pattern) {
  Assert-True $Label (-not [regex]::IsMatch($Text, $Pattern))
}

function Assert-Count([string]$Label, [string]$Text, [string]$Pattern, [int]$Expected) {
  $actual = [regex]::Matches($Text, $Pattern).Count
  Assert-True "$Label (expected=$Expected actual=$actual)" ($actual -eq $Expected)
}

Assert-True "main workflow exists" (Test-Path -LiteralPath $workflowPath -PathType Leaf)
Assert-True "reusable pr-check exists" (Test-Path -LiteralPath $prCheckPath -PathType Leaf)
Assert-True "read-only GHCR verifier exists" (Test-Path -LiteralPath $ghcrVerifierPath -PathType Leaf)
Assert-True "Phase-5 credit verifier exists" (Test-Path -LiteralPath $phase5CreditVerifierPath -PathType Leaf)
$workflow = Get-Content -LiteralPath $workflowPath -Raw
$prCheck = Get-Content -LiteralPath $prCheckPath -Raw
$ghcrVerifier = Get-Content -LiteralPath $ghcrVerifierPath -Raw
$phase5CreditVerifier = Get-Content -LiteralPath $phase5CreditVerifierPath -Raw

# Event and input boundary: manual candidate publication only.
$onMatch = [regex]::Match($workflow, '(?ms)^on:\s*\r?\n(?<body>.*?)(?=^permissions:)')
Assert-True "event block is parseable" $onMatch.Success
$eventBlock = $onMatch.Groups['body'].Value
Assert-Contains "workflow_dispatch trigger exists" $eventBlock "workflow_dispatch:"
foreach ($forbiddenTrigger in @('push', 'pull_request', 'schedule', 'repository_dispatch', 'workflow_run')) {
  Assert-NotRegex "trigger $forbiddenTrigger is absent" $eventBlock ("(?m)^\s{2}" + [regex]::Escape($forbiddenTrigger) + ":")
}
$dispatchInputs = @(
  [regex]::Matches($eventBlock, '(?m)^\s{6}(?<name>[a-zA-Z0-9_-]+):\s*$') |
    ForEach-Object { $_.Groups['name'].Value }
)
Assert-True "candidate_sha is the only dispatch input" ($dispatchInputs.Count -eq 1 -and $dispatchInputs[0] -eq 'candidate_sha')
Assert-Regex "candidate_sha is required string input" $eventBlock '(?ms)^\s{6}candidate_sha:\s+description:.*?^\s{8}required: true\s+^\s{8}type: string\s*$'

foreach ($forbidden in @(
  'release_mode',
  'candidate_ref',
  'deploy_environment',
  'market_ready',
  'github.event.inputs',
  'environment: staging',
  'environment: production',
  ':latest'
)) {
  Assert-True "forbidden legacy or runtime-release token is absent: $forbidden" (-not $workflow.Contains($forbidden))
}
Assert-NotRegex "mutable staging tag is absent" $workflow '(?m)^\s+[^#\r\n]*:staging\s*$'
Assert-NotRegex "mutable production tag is absent" $workflow '(?m)^\s+[^#\r\n]*:production\s*$'
Assert-NotRegex "staging and production claims are absent" $workflow '(?i)\b(staging|production)\b'

# Least privilege. Environment protection itself is external Owner-readable state.
$topPermissions = [regex]::Match($workflow, '(?ms)^permissions:\s*\r?\n(?<body>.*?)(?=^env:)')
Assert-True "top-level permissions are parseable" $topPermissions.Success
Assert-Regex "top-level contents permission is read-only" $topPermissions.Groups['body'].Value '(?m)^\s{2}contents: read\s*$'
Assert-Count "top-level permission has one entry" $topPermissions.Groups['body'].Value '(?m)^\s{2}[a-z-]+:\s*\w+\s*$' 1
Assert-Count "packages write appears only once" $workflow '(?m)^\s+packages: write\s*$' 1
Assert-Count "packages read appears only in aggregate job" $workflow '(?m)^\s+packages: read\s*$' 1
foreach ($forbiddenPermission in @('contents: write', 'actions: write', 'deployments: write', 'id-token: write', 'security-events: write', 'delete-packages')) {
  Assert-True "permission expansion is absent: $forbiddenPermission" (-not $workflow.Contains($forbiddenPermission))
}
Assert-Regex "publication job uses registry-publication without deployment claim" $workflow '(?ms)^\s{2}publish-candidate:.*?^\s{4}environment:\s+^\s{6}name: registry-publication\s+^\s{6}deployment: false\s*$'
$publishJobMatch = [regex]::Match(
  $workflow,
  '(?ms)^  publish-candidate:\s*\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\s*(?:\r?\n|$)|\z)'
)
Assert-True "publish-candidate job block is parseable" $publishJobMatch.Success
$publishJobBlock = $publishJobMatch.Groups['body'].Value
Assert-Regex "publish-candidate is gated by successful candidate preflight and CI" $publishJobBlock '(?m)^\s{4}needs:\s*\[candidate-preflight,\s*verify-candidate\]\s*$'
Assert-NotRegex "publish-candidate has no job-level always bypass" $publishJobBlock '(?im)^\s{4}if:\s*.*\balways\s*\('
Write-Host "[main-deploy-transition] OWNER-READ-GATE registry-publication protection rules are external GitHub state; this static verifier does not claim they are configured."

# Control/workflow SHA and candidate SHA must remain independent.
foreach ($required in @(
  'ref: ${{ github.sha }}',
  'fetch-depth: 0',
  'CONTROL_SHA: ${{ github.sha }}',
  'CONTROL_REF: ${{ github.ref }}',
  'control_ref != "refs/heads/chore/repo-bootstrap"',
  'docs/runtime-state/phase5-credit-itemization.json',
  'docs/runtime-state/capability-gates.json',
  'active_source_commit_sha',
  'capability-gate-state-v1',
  'gates.get("docker_registry_publish")',
  'registry_gate.get("owner_granted") is not True',
  'owner_grant_ref',
  'registry_gate.get("paid_provider") is not False',
  '["git", "ls-files", "--error-unmatch", truth_path.as_posix()]',
  '["git", "rev-parse", "HEAD"]',
  '["git", "cat-file", "-e", f"{candidate_sha}^{{commit}}"]',
  '["git", "merge-base", "--is-ancestor", candidate_sha, control_sha]',
  'candidate_sha == control_sha',
  'control_sha={control_sha}',
  'candidate_sha={candidate_sha}'
)) {
  Assert-Contains "control/candidate guard: $required" $workflow $required
}
foreach ($forbiddenEquality in @(
  'candidate_sha != dispatch_sha',
  'candidate_sha != control_sha',
  'candidate_sha must exactly match github.sha',
  'CANDIDATE_SHA: ${{ github.sha }}'
)) {
  Assert-True "candidate is not equated to control: $forbiddenEquality" (-not $workflow.Contains($forbiddenEquality))
}

# Reusable CI verifies the candidate checkout, while preserving normal PR behavior.
Assert-Regex "pr-check declares optional workflow_call candidate input" $prCheck '(?ms)^\s{2}workflow_call:\s+inputs:\s+candidate_sha:\s+description:.*?required: false\s+type: string\s*$'
Assert-Contains "pr-check checks out supplied candidate or normal event SHA" $prCheck 'ref: ${{ inputs.candidate_sha || github.sha }}'
Assert-Regex "pr-check manual dispatch declares explicit source prequalification" $prCheck '(?ms)^\s{2}workflow_dispatch:\s+inputs:\s+candidate_sha:.*?required: false\s+type: string\s+source_prequalification:.*?required: false\s+default: false\s+type: boolean\s*$'
Assert-Contains "source prequalification is manual-dispatch only" $prCheck 'event_name != "workflow_dispatch"'
Assert-Contains "source prequalification requires an explicit candidate" $prCheck 'source prequalification requires an explicit candidate_sha'
Assert-Contains "source prequalification is branch-ref only" $prCheck 'event_ref.startswith("refs/heads/")'
Assert-Contains "source attestation is runner-temp bounded" $prCheck 'os.environ["RUNNER_TEMP"]'
$projectProgressStepMatch = [regex]::Match(
  $prCheck,
  '(?ms)^      - name: Project progress delta-ledger replay regression\s*\r?\n(?<body>.*?)(?=^      - name:)'
)
Assert-True "project-progress step is parseable" $projectProgressStepMatch.Success
$projectProgressStep = $projectProgressStepMatch.Value
Assert-Contains "project-progress source prequalification env is bound" `
  $projectProgressStep `
  'SOURCE_PREQUALIFICATION: ${{ steps.source-binding.outputs.source_prequalification }}'
Assert-Contains "project-progress prequalification remains explicit" `
  $projectProgressStep `
  'if [[ "$SOURCE_PREQUALIFICATION" == "true" ]]; then'
Assert-Contains "project-progress prequalification requires exact exit 1" `
  $projectProgressStep `
  'if [[ "$progress_exit" -ne 1 ]]; then'
Assert-Contains "project-progress prequalification requires exact drift output" `
  $projectProgressStep `
  'if [[ "$progress_output" != "$expected_progress_drift" ]]; then'
Assert-Contains "project-progress prequalification pins runtime-source drift" `
  $projectProgressStep `
  '[phase5-credit] active candidate has committed or staged runtime-source drift outside the exact post-qualification or no-credit requalification truth transition\n[project-progress] Phase-5 credit itemization is invalid'
Assert-Regex "project-progress normal validation is retained" `
  $projectProgressStep `
  '(?ms)^\s{10}else\s*\r?\n\s{12}python scripts/verify_project_progress_manifest\.py\s*\r?\n\s{10}fi\s*$'
Assert-Regex "project-progress unit and endpoint tests remain outside conditional" `
  $projectProgressStep `
  '(?ms)python -m unittest scripts\.tests\.test_verify_project_progress_manifest -v.*?^\s{10}if \[\[.*?^\s{10}fi\s*\r?\n\s{10}node --test scripts/tests/endpoint-snapshot-metadata\.test\.mjs'
Assert-Count "project-progress manifest executes in both explicit modes" `
  $projectProgressStep `
  '(?m)python scripts/verify_project_progress_manifest\.py' `
  2
Assert-NotRegex "project-progress manifest has no blanket bypass" `
  $projectProgressStep `
  'python scripts/verify_project_progress_manifest\.py[^\r\n]*\|\|\s*true'
$fiveAxisStepMatch = [regex]::Match(
  $prCheck,
  '(?ms)^      - name: Five-axis delta-ledger integration\s*\r?\n(?<body>.*?)(?=^      - name:)'
)
Assert-True "five-axis step is parseable" $fiveAxisStepMatch.Success
$fiveAxisStep = $fiveAxisStepMatch.Value
Assert-Contains "five-axis source prequalification env is bound" `
  $fiveAxisStep `
  'SOURCE_PREQUALIFICATION: ${{ steps.source-binding.outputs.source_prequalification }}'
Assert-Contains "five-axis prequalification remains explicit" `
  $fiveAxisStep `
  'case "$SOURCE_PREQUALIFICATION" in'
Assert-Contains "five-axis prequalification keeps negative ledger regressions" `
  $fiveAxisStep `
  "--test-name-pattern='^(rejects the retired v1 permanent-empty ledger contract without browser evidence|rejects a structurally typed but unauthenticated v2 ledger entry|keeps future evidence-backed vertical deltas reachable)$'"
Assert-Contains "five-axis prequalification requires exact exit 1" `
  $fiveAxisStep `
  'if [[ "$five_axis_exit" -ne 1 ]]; then'
Assert-Contains "five-axis prequalification requires exact drift output" `
  $fiveAxisStep `
  'if [[ "$five_axis_output" != "$expected_five_axis_drift" ]]; then'
Assert-Contains "five-axis prequalification pins runtime-source drift" `
  $fiveAxisStep `
  '[five-axis-audit] project progress verifier failed via python3: [phase5-credit] active candidate has committed or staged runtime-source drift outside the exact post-qualification or no-credit requalification truth transition\n[project-progress] Phase-5 credit itemization is invalid'
Assert-Regex "five-axis normal validation is retained" `
  $fiveAxisStep `
  '(?ms)^\s{12}false\)\s*\r?\n\s{14}node --test scripts/tests/five-axis-delta-ledger-regression\.test\.mjs\s*\r?\n\s{14}node scripts/verify-five-axis-substance-audit\.mjs\s*\r?\n\s{14};;'
Assert-Contains "five-axis prequalification rejects unexpected mode values" `
  $fiveAxisStep `
  'unexpected SOURCE_PREQUALIFICATION value'
Assert-NotRegex "five-axis audit has no blanket bypass" `
  $fiveAxisStep `
  '(?m)(node --test|node scripts/verify-five-axis-substance-audit\.mjs)[^\r\n]*\|\|\s*true'
foreach ($requiredNoCreditGuard in @(
  'NO_CREDIT_REQUALIFICATION_RUNTIME_PATHS',
  'def require_no_credit_requalification(',
  'phase5_credit_projection(index_itemization) == phase5_credit_projection(source_itemization)',
  'external_gate_truth_projection(index_external) == external_gate_truth_projection(source_external)',
  'snapshot.get("/api/v1/project/progress") == index_manifest',
  'runtime_source_parity_mode=no_credit_requalification',
  'progress_credit_changed=false'
)) {
  Assert-Contains "no-credit requalification guard: $requiredNoCreditGuard" `
    $phase5CreditVerifier `
    $requiredNoCreditGuard
}
Assert-Contains "no-credit requalification has an exact runtime truth delta" `
  $phase5CreditVerifier `
  'if changed_paths == NO_CREDIT_REQUALIFICATION_RUNTIME_PATHS:'
Assert-Contains "direct Phase-5 truth check is retained" $prCheck 'if [[ "$CANDIDATE_DIFFERS" != "true" ]]; then'
Assert-Contains "direct Phase-5 truth verifier is retained" $prCheck 'python scripts/verify_phase5_credit_itemization.py'
Assert-Contains "reusable candidate CI validates control truth" $prCheck 'elif [[ "$SOURCE_PREQUALIFICATION" != "true" ]]; then'
Assert-Contains "reusable candidate CI creates isolated control truth" $prCheck 'git worktree add --detach "$CONTROL_TRUTH_DIR" "${GITHUB_SHA}"'
Assert-Contains "reusable candidate CI runs the control-truth verifier" $prCheck 'python "$CONTROL_TRUTH_DIR/scripts/verify_phase5_credit_itemization.py"'
Assert-True "main publication workflow cannot enable source prequalification" (-not $workflow.Contains('source_prequalification'))
Assert-Contains "OAuth CI line is preserved" $prCheck 'run: npm run verify:oauth-boundary'
Assert-Count "stateful runtime dependency install occurs exactly once" `
  $prCheck `
  'npm ci --ignore-scripts --prefix services/cloudflare-stateful-runtime' `
  1
Assert-Regex "stateful runtime dependencies precede OAuth and runtime tests" `
  $prCheck `
  '(?ms)npm ci --ignore-scripts --prefix services/cloudflare-stateful-runtime.*?run: npm run verify:oauth-boundary.*?run: npm test --prefix services/cloudflare-stateful-runtime'
Assert-Contains "backend auth security tests are CI-gated" $prCheck 'python -m unittest discover -s services/agent-api/tests -p test_auth_security.py -v'
Assert-Contains "Phase-6 scale static contracts are CI-gated" $prCheck 'run: npm run verify:phase6-scale:static'
Assert-Contains "Cloudflare stateful runtime tests are CI-gated" $prCheck 'npm test --prefix services/cloudflare-stateful-runtime'
Assert-Contains "Cloudflare LLM gateway tests are CI-gated" $prCheck 'npm test --prefix services/cloudflare-llm-gateway'
Assert-Contains "source prequalification validates control tests" $prCheck 'python -m unittest scripts.tests.test_verify_phase5_credit_itemization -v'
Assert-Contains "source prequalification validates the publication transition" $prCheck 'pwsh -NoProfile -File scripts/verify-main-deploy-transition.ps1'
Assert-Contains "source prequalification validates supply-chain pins" $prCheck 'pwsh -NoProfile -File scripts/verify-supply-chain-pins.ps1'
Assert-Regex "main calls reusable candidate CI with exact SHA" $workflow '(?ms)^\s{2}verify-candidate:.*?uses: \./\.github/workflows/pr-check\.yml\s+with:\s+candidate_sha: \$\{\{ needs\.candidate-preflight\.outputs\.candidate_sha \}\}\s*$'

# Exactly six image builds, one immutable SHA tag, and no overwrite path.
$expectedServices = @('agent-api', 'mcp-gateway', 'frontend', 'llm-gateway', 'agent-worker', 'memory-worker')
$serviceMatches = [regex]::Matches($workflow, '(?m)^\s{10}- name: (?<name>[a-z0-9-]+)\s*$')
$actualServices = @($serviceMatches | ForEach-Object { $_.Groups['name'].Value })
Assert-True "exactly six service matrix entries exist" ($actualServices.Count -eq 6)
foreach ($service in $expectedServices) {
  Assert-True "service matrix includes $service exactly once" (@($actualServices | Where-Object { $_ -eq $service }).Count -eq 1)
}
foreach ($service in @('agent-api', 'mcp-gateway', 'llm-gateway', 'agent-worker', 'memory-worker')) {
  $pattern = '(?ms)^\s{10}- name: ' + [regex]::Escape($service) + '\s+context: \.\s+dockerfile: services/' + [regex]::Escape($service) + '/Dockerfile\s*$'
  Assert-Regex "$service builds from repository context" $workflow $pattern
}
Assert-Regex "frontend builds from frontend context" $workflow '(?ms)^\s{10}- name: frontend\s+context: apps/frontend\s+dockerfile: apps/frontend/Dockerfile\s*$'

$registryCheckIndex = $workflow.IndexOf('      - name: Refuse to overwrite an existing candidate tag')
$buildPushIndex = $workflow.IndexOf('      - name: Build and push absent candidate tag once')
Assert-True "registry existence check precedes build" ($registryCheckIndex -ge 0 -and $buildPushIndex -gt $registryCheckIndex)
foreach ($required in @(
  'docker buildx imagetools inspect "${IMAGE_REF}"',
  'Candidate tag already exists; build and push are intentionally skipped.',
  "grep -Eiq 'manifest unknown'",
  'grep -Fq "${IMAGE_REF}: not found"',
  "if: `${{ steps.registry-check.outputs.exists == 'false' }}",
  'group: ghcr-candidate-${{ inputs.candidate_sha }}',
  'cancel-in-progress: false'
)) {
  Assert-Contains "append-only publication guard: $required" $workflow $required
}
Assert-Count "one build-push action exists" $workflow '(?m)^\s+uses: docker/build-push-action@' 1
Assert-Count "one registry push flag exists" $workflow '(?m)^\s+push: true\s*$' 1
Assert-Count "one image tags field exists" $workflow '(?m)^\s+tags:\s*' 1
Assert-Contains "single tag is exact candidate SHA" $workflow 'tags: ${{ env.IMAGE_NAMESPACE }}/${{ matrix.name }}:${{ needs.candidate-preflight.outputs.candidate_sha }}'
Assert-Contains "two exact runtime platforms" $workflow 'platforms: linux/amd64,linux/arm64'
Assert-Contains "provenance descriptors are disabled for exact platform index" $workflow 'provenance: false'
Assert-Contains "SBOM descriptors are disabled for exact platform index" $workflow 'sbom: false'
foreach ($label in @(
  'org.opencontainers.image.source=https://github.com/${{ github.repository }}',
  'org.opencontainers.image.revision=${{ needs.candidate-preflight.outputs.candidate_sha }}',
  'org.opencontainers.image.version=candidate-${{ needs.candidate-preflight.outputs.candidate_sha }}'
)) {
  Assert-Contains "OCI label $label" $workflow $label
}

# Final job is read-only against GHCR and binds the immutable aggregate evidence.
Assert-Regex "aggregate job waits for all matrix publications" $workflow '(?ms)^\s{2}verify-candidate-manifest:.*?^\s{4}needs: \[candidate-preflight, publish-candidate\]\s*$'
$aggregateStart = $workflow.IndexOf('  verify-candidate-manifest:')
Assert-True "aggregate job exists" ($aggregateStart -ge 0)
$aggregateBlock = $workflow.Substring($aggregateStart)
Assert-True "aggregate job has no packages write" (-not $aggregateBlock.Contains('packages: write'))
Assert-True "aggregate job has no registry build/push action" (-not $aggregateBlock.Contains('docker/build-push-action@'))
foreach ($required in @(
  'ref: ${{ needs.candidate-preflight.outputs.control_sha }}',
  'WORKFLOW_CANDIDATE_SHA: ${{ needs.candidate-preflight.outputs.candidate_sha }}',
  'CONTROL_SHA: ${{ needs.candidate-preflight.outputs.control_sha }}',
  'WORKFLOW_RUN_URL: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}',
  'run: python scripts/verify_ghcr_candidate.py',
  'actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2',
  'ARTIFACT_DIGEST: ${{ steps.upload.outputs.artifact-digest }}',
  'overwrite: false',
  'retention-days: 90'
)) {
  Assert-Contains "aggregate evidence guard: $required" $aggregateBlock $required
}
Assert-True "aggregate does not override reserved GITHUB_SHA" (-not $aggregateBlock.Contains('GITHUB_SHA:'))
foreach ($requiredVerifierContract in @(
  'EXPECTED_SERVICES',
  'EXPECTED_PLATFORMS = ("linux/amd64", "linux/arm64")',
  'workflow.head_sha == config.control_sha',
  'workflow.candidate_sha == config.candidate_sha',
  'registry_write_performed": False',
  'write_evidence_exclusive'
)) {
  Assert-Contains "GHCR verifier contract: $requiredVerifierContract" $ghcrVerifier $requiredVerifierContract
}

foreach ($forbiddenRuntimeMutation in @(
  'kubectl ',
  'helm upgrade',
  'wrangler deploy',
  'vercel --prod',
  'fly deploy',
  'docker stack deploy',
  'watchtower',
  'ssh '
)) {
  Assert-True "runtime deployment command is absent: $forbiddenRuntimeMutation" (-not $workflow.Contains($forbiddenRuntimeMutation))
}

$uses = [regex]::Matches($workflow, '(?m)^\s+uses:\s+(?<use>[^\s#]+)')
Assert-True "workflow uses pinned third-party actions" ($uses.Count -gt 0)
foreach ($useMatch in $uses) {
  $use = $useMatch.Groups['use'].Value
  if ($use.StartsWith('./')) { continue }
  Assert-True "action pin is a full commit: $use" ([regex]::IsMatch($use, '@[0-9a-f]{40}$'))
}

Write-Host "[main-deploy-transition] VERIFIED candidate-only append-only GHCR publication contract"
exit 0

# Control commit marker: source-prequalification binding for the RC12 candidate.
# Placed directly on the candidate so the control delta stays inside the allowed path list;
# evidence commits necessarily come later, because they are produced by running against it.

# Control commit marker: source-prequalification binding for the RC13 candidate.
# Placed directly on the frozen candidate so CI can attest the exact source while the local
# qualification evidence remains on the separate mainline metadata commit.

# Control commit marker: source-prequalification binding for the RC14 candidate.
# Placed directly on the frozen candidate so CI can attest the exact source while the local
# qualification evidence remains on the separate mainline metadata commit.

# Control commit marker: source-prequalification binding for source 2e945a6.
# This attests the exact development source only; it does not select RC15 or promote a release.

# Control commit marker: source-prequalification binding for source 0a706be.
# This attests the exact development source only; it does not select RC16 or promote a release.

# Control commit marker: source-prequalification binding for source bbc2ad4.
# This attests the exact development source only; it does not select RC17 or promote a release.

# Control commit marker: source-prequalification binding for source 048ba55.
# This attests the exact development source only; it does not select RC18 or promote a release.

# Control commit marker: source-prequalification binding for source 5062de3.
# This attests the exact development source only; it does not select RC19 or promote a release.

# Control commit marker: source-prequalification binding for source c29c738.
# This attests the exact development source only; it does not select RC20 or promote a release.

# rc21-source-prequalification-binding

# rc22-source-prequalification-binding-v2

# rc24-source-prequalification-binding-9c9d2694

# rc24-source-prequalification-binding-8f20b6e2

# rc24-source-prequalification-binding-1cb03979

# rc25-source-prequalification-binding-d6a1c790
