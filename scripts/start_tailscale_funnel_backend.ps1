param(
  [Parameter(Mandatory = $true)]
  [string]$DatabaseUrl,

  [string]$JwtSecret = "dev-secret-change-me",

  [int]$Port = 8081,

  [switch]$RunMigrate
)

$ErrorActionPreference = 'Stop'

function Get-TailscaleExe {
  $command = Get-Command tailscale -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $candidatePaths = @(
    'C:\Program Files\Tailscale\tailscale.exe',
    'C:\Program Files (x86)\Tailscale\tailscale.exe'
  )

  return $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
}

$repoRoot = Join-Path $PSScriptRoot '..'
$backendScript = Join-Path $repoRoot 'backend\scripts\start_supabase_local.ps1'
$tailscaleExe = Get-TailscaleExe

if (-not (Test-Path $backendScript)) {
  throw "Backend start script not found: $backendScript"
}

if (-not $tailscaleExe) {
  throw "tailscale not found. Install it first, then rerun this script."
}

$backendArgs = @(
  '-NoExit'
  '-ExecutionPolicy'
  'Bypass'
  '-File'
  $backendScript
  '-DatabaseUrl'
  $DatabaseUrl
  '-JwtSecret'
  $JwtSecret
  '-Port'
  $Port
)

if ($RunMigrate) {
  $backendArgs += '-RunMigrate'
}

Write-Host "Starting backend in a new PowerShell window..."
$backendProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $backendArgs -PassThru

Write-Host "Waiting for backend to begin listening on http://localhost:$Port ..."
$deadline = (Get-Date).AddSeconds(45)
do {
  Start-Sleep -Milliseconds 500
  $listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
} until ($listening -or (Get-Date) -ge $deadline)

if (-not $listening) {
  throw "Backend did not start listening on port $Port within 45 seconds. Check the new backend PowerShell window."
}

$tailscaleStatus = & $tailscaleExe status --json | ConvertFrom-Json
if ($tailscaleStatus.BackendState -ne 'Running' -or -not $tailscaleStatus.Self.Online) {
  throw "Tailscale is not connected. Sign in to Tailscale first, then rerun this script."
}

$dnsName = $tailscaleStatus.Self.DNSName.TrimEnd('.')

Write-Host "Enabling Tailscale Funnel in the background..."
$null = & $tailscaleExe funnel --bg $Port 2>&1

$funnelStatus = & $tailscaleExe funnel status --json | ConvertFrom-Json
$route = $funnelStatus.Web."$dnsName:443".Handlers.'/'.Proxy

if ($route -ne "http://127.0.0.1:$Port") {
  throw "Funnel did not publish the expected backend route. Check 'tailscale funnel status --json'."
}

Write-Host "Backend PID: $($backendProcess.Id)"
Write-Host "Stable public URL: https://$dnsName"
Write-Host "Use this as GHANACLASS_API_BASE_URL while the backend window remains running."