param(
  [int]$MaxWaitSeconds = 120,
  [int]$IntervalSeconds = 10,
  [switch]$AttemptSelfHeal,
  [switch]$AllowDestructiveDockerReset,
  [switch]$ReportOnly,
  [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

function Invoke-ProcessCapture([string]$FilePath, [string[]]$Arguments = @(), [int]$TimeoutSeconds = 30) {
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FilePath
  $psi.Arguments = (($Arguments | ForEach-Object {
    $argument = [string]$_
    if ($argument -match '[\s"]') {
      '"' + ($argument -replace '"', '\"') + '"'
    } else {
      $argument
    }
  }) -join " ")
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $psi
  try {
    $started = $process.Start()
    if (-not $started) {
      return [pscustomobject]@{
        exit_code = 1
        output = "failed to start process: $FilePath"
      }
    }

    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
      $process.Kill($true)
      return [pscustomobject]@{
        exit_code = 124
        output = "timeout after ${TimeoutSeconds}s: $FilePath $($Arguments -join ' ')"
      }
    }

    $output = (($stdout.Result + "`n" + $stderr.Result) | Out-String).Trim()
    return [pscustomobject]@{
      exit_code = $process.ExitCode
      output = $output
    }
  } catch {
    return [pscustomobject]@{
      exit_code = 1
      output = $_.Exception.Message
    }
  } finally {
    $process.Dispose()
  }
}

function Invoke-DockerInfoProbe() {
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if (-not $docker) {
    return [pscustomobject]@{
      ready = $false
      server_version = ""
      exit_code = 127
      output = "docker command is not available"
    }
  }

  $probe = Invoke-ProcessCapture -FilePath $docker.Source -Arguments @("info", "--format", "{{.ServerVersion}}") -TimeoutSeconds 20
  $version = ($probe.output | Select-String -Pattern '^[0-9]+(\.[0-9]+)+' | Select-Object -First 1).Matches.Value
  return [pscustomobject]@{
    ready = ($probe.exit_code -eq 0 -and -not [string]::IsNullOrWhiteSpace($version))
    server_version = if ($version) { $version } else { "" }
    exit_code = $probe.exit_code
    output = $probe.output
  }
}

function Wait-ForDocker([int]$WaitSeconds, [int]$EverySeconds) {
  $deadline = (Get-Date).AddSeconds([Math]::Max(0, $WaitSeconds))
  $attempts = [System.Collections.Generic.List[object]]::new()
  do {
    $probe = Invoke-DockerInfoProbe
    $attempts.Add([pscustomobject]@{
      at_utc = (Get-Date).ToUniversalTime().ToString("o")
      ready = $probe.ready
      exit_code = $probe.exit_code
      server_version = $probe.server_version
      output_excerpt = ($probe.output | Out-String).Trim().Substring(0, [Math]::Min(500, (($probe.output | Out-String).Trim()).Length))
    })
    if ($probe.ready) {
      return [pscustomobject]@{
        ready = $true
        server_version = $probe.server_version
        attempts = $attempts
      }
    }
    if ((Get-Date) -lt $deadline) {
      Start-Sleep -Seconds ([Math]::Max(1, $EverySeconds))
    }
  } while ((Get-Date) -lt $deadline)

  return [pscustomobject]@{
    ready = $false
    server_version = ""
    attempts = $attempts
  }
}

function Get-DockerDiagnostics() {
  $pipePath = "\\.\pipe\dockerDesktopLinuxEngine"
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  $wsl = Get-Command wsl -ErrorAction SilentlyContinue
  $dockerInfo = if ($docker) {
    Invoke-ProcessCapture -FilePath $docker.Source -Arguments @("info") -TimeoutSeconds 30
  } else {
    [pscustomobject]@{ exit_code = 127; output = "docker command is not available" }
  }
  $wslStatus = if ($wsl) {
    Invoke-ProcessCapture -FilePath $wsl.Source -Arguments @("--status") -TimeoutSeconds 20
  } else {
    [pscustomobject]@{ exit_code = 127; output = "wsl command is not available" }
  }
  $wslList = if ($wsl) {
    Invoke-ProcessCapture -FilePath $wsl.Source -Arguments @("-l", "-v") -TimeoutSeconds 20
  } else {
    [pscustomobject]@{ exit_code = 127; output = "wsl command is not available" }
  }
  $processes = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -match 'Docker|com\.docker|wsl'
  } | Select-Object -First 20 ProcessName, Id)

  return [ordered]@{
    docker_pipe_exists = Test-Path -LiteralPath $pipePath
    docker_info_exit_code = $dockerInfo.exit_code
    docker_info_excerpt = $dockerInfo.output.Substring(0, [Math]::Min(1200, $dockerInfo.output.Length))
    wsl_status_exit_code = $wslStatus.exit_code
    wsl_status_excerpt = $wslStatus.output.Substring(0, [Math]::Min(1200, $wslStatus.output.Length))
    wsl_list_exit_code = $wslList.exit_code
    wsl_list_excerpt = $wslList.output.Substring(0, [Math]::Min(1200, $wslList.output.Length))
    process_check_note = "Docker processes are diagnostic only and never prove readiness."
    matching_processes = $processes
  }
}

function Start-DockerDesktopIfPresent() {
  $dockerDesktop = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
  if (Test-Path -LiteralPath $dockerDesktop) {
    Start-Process -FilePath $dockerDesktop -WindowStyle Hidden | Out-Null
    return $true
  }
  return $false
}

if ($IntervalSeconds -lt 1) {
  throw "IntervalSeconds must be at least 1."
}

if ($AttemptSelfHeal -and $MaxWaitSeconds -lt 120) {
  throw "AttemptSelfHeal requires MaxWaitSeconds >= 120 so Docker gets a real readiness wait before healing."
}

$events = [System.Collections.Generic.List[object]]::new()
$initial = Wait-ForDocker -WaitSeconds $MaxWaitSeconds -EverySeconds $IntervalSeconds
$events.Add([pscustomobject]@{
  step = "initial_wait"
  ready = $initial.ready
  server_version = $initial.server_version
})

if (-not $initial.ready -and $AttemptSelfHeal) {
  $events.Add([pscustomobject]@{ step = "heal_a_wsl_shutdown"; action = "wsl --shutdown, start Docker Desktop, wait" })
  $wsl = Get-Command wsl -ErrorAction SilentlyContinue
  if ($wsl) {
    Invoke-ProcessCapture -FilePath $wsl.Source -Arguments @("--shutdown") -TimeoutSeconds 60 | Out-Null
  }
  Start-Sleep -Seconds 5
  Start-DockerDesktopIfPresent | Out-Null
  Start-Sleep -Seconds 30
  $afterA = Wait-ForDocker -WaitSeconds 120 -EverySeconds $IntervalSeconds
  $events.Add([pscustomobject]@{ step = "after_heal_a"; ready = $afterA.ready; server_version = $afterA.server_version })
  if ($afterA.ready) {
    $initial = $afterA
  }
}

if (-not $initial.ready -and $AttemptSelfHeal) {
  $events.Add([pscustomobject]@{ step = "heal_b_wsl_update"; action = "wsl --update, wsl --shutdown, start Docker Desktop, wait" })
  $wsl = Get-Command wsl -ErrorAction SilentlyContinue
  if ($wsl) {
    Invoke-ProcessCapture -FilePath $wsl.Source -Arguments @("--update") -TimeoutSeconds 300 | Out-Null
    Invoke-ProcessCapture -FilePath $wsl.Source -Arguments @("--shutdown") -TimeoutSeconds 60 | Out-Null
  }
  Start-Sleep -Seconds 5
  Start-DockerDesktopIfPresent | Out-Null
  Start-Sleep -Seconds 30
  $afterB = Wait-ForDocker -WaitSeconds 120 -EverySeconds $IntervalSeconds
  $events.Add([pscustomobject]@{ step = "after_heal_b"; ready = $afterB.ready; server_version = $afterB.server_version })
  if ($afterB.ready) {
    $initial = $afterB
  }
}

if (-not $initial.ready -and $AttemptSelfHeal -and $AllowDestructiveDockerReset) {
  $events.Add([pscustomobject]@{ step = "heal_c_destructive_unregister"; action = "wsl --unregister docker-desktop and docker-desktop-data" })
  $wsl = Get-Command wsl -ErrorAction SilentlyContinue
  if ($wsl) {
    Invoke-ProcessCapture -FilePath $wsl.Source -Arguments @("--unregister", "docker-desktop") -TimeoutSeconds 60 | Out-Null
    Invoke-ProcessCapture -FilePath $wsl.Source -Arguments @("--unregister", "docker-desktop-data") -TimeoutSeconds 60 | Out-Null
  }
  Start-DockerDesktopIfPresent | Out-Null
  Start-Sleep -Seconds 60
  $afterC = Wait-ForDocker -WaitSeconds 180 -EverySeconds $IntervalSeconds
  $events.Add([pscustomobject]@{ step = "after_heal_c"; ready = $afterC.ready; server_version = $afterC.server_version })
  if ($afterC.ready) {
    $initial = $afterC
  }
}

$status = if ($initial.ready) { "ready" } else { "blocked" }
$diagnostics = if ($initial.ready) { $null } else { Get-DockerDiagnostics }
$summary = [ordered]@{
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
  status = $status
  readiness_proof = "docker info --format '{{.ServerVersion}}'"
  server_version = $initial.server_version
  attempt_self_heal = [bool]$AttemptSelfHeal
  destructive_reset_allowed = [bool]$AllowDestructiveDockerReset
  events = $events
  diagnostics = $diagnostics
  blocked_gates_policy = if ($initial.ready) { @() } else { @("[BLOCKED] docker-compose gates", "[SKIPPED-REASON: docker-unavailable] docker-dependent verification") }
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
  $parent = Split-Path $OutputPath -Parent
  if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

if ($status -eq "ready") {
  Write-Host "[docker-readiness] status=ready server_version=$($initial.server_version)"
} else {
  Write-Host "[docker-readiness] status=blocked"
  Write-Host "[docker-readiness] readiness_proof=docker info --format '{{.ServerVersion}}'"
  Write-Host "[docker-readiness] blocked=[BLOCKED] docker-compose gates"
  Write-Host "[docker-readiness] skipped=[SKIPPED-REASON: docker-unavailable] docker-dependent verification"
  if ($diagnostics) {
    Write-Host ("[docker-readiness] docker_info_exit_code={0}" -f $diagnostics.docker_info_exit_code)
    Write-Host ("[docker-readiness] wsl_status_exit_code={0}" -f $diagnostics.wsl_status_exit_code)
    Write-Host ("[docker-readiness] wsl_list_exit_code={0}" -f $diagnostics.wsl_list_exit_code)
  }
}

if ($status -ne "ready" -and -not $ReportOnly) {
  exit 1
}
