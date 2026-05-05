param(
  [Parameter(Mandatory = $true)]
  [string]$DatabaseUrl,

  [string]$JwtSecret = "dev-secret-change-me",

  [int]$Port = 8081,

  [int]$DartVmServicePort = 0,

  [bool]$StopExisting = $true,

  [switch]$RunMigrate
)

$ErrorActionPreference = 'Stop'

function Get-ListeningProcessOnPort {
  param([int]$TargetPort)

  $connection = Get-NetTCPConnection -LocalPort $TargetPort -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1

  if (-not $connection) {
    return $null
  }

  return Get-Process -Id $connection.OwningProcess -ErrorAction Stop
}

function Stop-ListeningProcessOnPort {
  param([int]$TargetPort)

  $process = Get-ListeningProcessOnPort -TargetPort $TargetPort
  if (-not $process) {
    return
  }

  $allowedProcessNames = @('dart', 'dartvm', 'powershell', 'pwsh')
  if ($allowedProcessNames -notcontains $process.ProcessName.ToLowerInvariant()) {
    throw "Port $TargetPort is already in use by process '$($process.ProcessName)' (PID $($process.Id)). Refusing to stop it automatically."
  }

  Write-Host "Stopping existing local backend process $($process.ProcessName) (PID $($process.Id)) on port $TargetPort..."
  Stop-Process -Id $process.Id -Force
  Wait-Process -Id $process.Id -Timeout 10 -ErrorAction SilentlyContinue
}

Push-Location (Join-Path $PSScriptRoot '..')
try {
  $env:DATABASE_URL = $DatabaseUrl
  $env:JWT_SECRET = $JwtSecret

  Write-Host "Refreshing backend Dart packages..."
  dart pub get

  if ($RunMigrate) {
    Write-Host "Running migrations against DATABASE_URL..."
    dart run bin/migrate.dart
  }

  if ($StopExisting) {
    Stop-ListeningProcessOnPort -TargetPort $Port
  }
  elseif (Get-ListeningProcessOnPort -TargetPort $Port) {
    throw "Port $Port is already in use. Rerun with -StopExisting `$true or free the port manually."
  }

  Write-Host "Starting Dart Frog backend on port $Port..."
  if ($DartVmServicePort -gt 0) {
    dart run dart_frog_cli:dart_frog dev --port $Port --dart-vm-service-port $DartVmServicePort
  }
  else {
    dart run dart_frog_cli:dart_frog dev --port $Port --dart-vm-service-port 0
  }
}
finally {
  Pop-Location
}