param(
  [int]$Port = 8081
)

$ErrorActionPreference = 'Stop'

$repoRoot = Join-Path $PSScriptRoot '..'
$backendDir = Join-Path $repoRoot 'backend'

if (-not (Test-Path $backendDir)) {
  throw "Backend directory not found: $backendDir"
}

Push-Location $backendDir
try {
  Write-Host "Installing backend dependencies..."
  dart pub get

  Write-Host "Starting backend on http://localhost:$Port"
  Write-Host "Press Ctrl+C to stop."
  dart run dart_frog_cli:dart_frog dev --port $Port
}
finally {
  Pop-Location
}
