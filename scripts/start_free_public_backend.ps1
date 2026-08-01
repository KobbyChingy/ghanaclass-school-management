param(
  [Parameter(Mandatory = $true)]
  [string]$DatabaseUrl,

  [string]$JwtSecret = "dev-secret-change-me",

  [int]$Port = 8081,

  [switch]$RunMigrate
)

$ErrorActionPreference = 'Stop'

$repoRoot = Join-Path $PSScriptRoot '..'
$backendScript = Join-Path $repoRoot 'backend\scripts\start_supabase_local.ps1'
$tunnelScript = Join-Path $repoRoot 'scripts\start_public_tunnel.ps1'

if (-not (Test-Path $backendScript)) {
  throw "Backend start script not found: $backendScript"
}

if (-not (Test-Path $tunnelScript)) {
  throw "Tunnel start script not found: $tunnelScript"
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

$tunnelArgs = @(
  '-NoExit'
  '-ExecutionPolicy'
  'Bypass'
  '-File'
  $tunnelScript
  '-Port'
  $Port
)

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

Write-Host "Starting Cloudflare tunnel in a new PowerShell window..."
$tunnelProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $tunnelArgs -PassThru

Write-Host "Backend PID: $($backendProcess.Id)"
Write-Host "Tunnel PID: $($tunnelProcess.Id)"
Write-Host "Watch the tunnel window for the public https://*.trycloudflare.com URL."
Write-Host "Use that URL as GHANACLASS_API_BASE_URL for your Flutter app while these windows stay open."