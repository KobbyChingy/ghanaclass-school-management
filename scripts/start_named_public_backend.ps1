param(
  [Parameter(Mandatory = $true)]
  [string]$DatabaseUrl,

  [Parameter(Mandatory = $true)]
  [string]$TunnelToken,

  [string]$JwtSecret = "dev-secret-change-me",

  [int]$Port = 8081,

  [switch]$RunMigrate
)

$ErrorActionPreference = 'Stop'

$repoRoot = Join-Path $PSScriptRoot '..'
$backendScript = Join-Path $repoRoot 'backend\scripts\start_supabase_local.ps1'

if (-not (Test-Path $backendScript)) {
  throw "Backend start script not found: $backendScript"
}

$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($cloudflared) {
  $cloudflaredExe = $cloudflared.Source
} else {
  $candidatePaths = @(
    'C:\Program Files (x86)\cloudflared\cloudflared.exe',
    'C:\Program Files\cloudflared\cloudflared.exe'
  )
  $cloudflaredExe = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $cloudflaredExe) {
  throw "cloudflared not found. Install with: winget install --id Cloudflare.cloudflared -e --accept-source-agreements --accept-package-agreements"
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

Write-Host "Starting named Cloudflare tunnel in a new PowerShell window..."
$tunnelArgs = @(
  '-NoExit'
  '-Command'
  "& '$cloudflaredExe' tunnel run --token '$TunnelToken' --no-autoupdate"
)
$tunnelProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $tunnelArgs -PassThru

Write-Host "Backend PID: $($backendProcess.Id)"
Write-Host "Tunnel PID: $($tunnelProcess.Id)"
Write-Host "The public hostname is the one you configured in the Cloudflare dashboard for this named tunnel."