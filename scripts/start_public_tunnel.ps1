param(
  [int]$Port = 8081
)

$ErrorActionPreference = 'Stop'

$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
if ($cloudflared) {
  $exe = $cloudflared.Source
} else {
  $candidatePaths = @(
    'C:\Program Files (x86)\cloudflared\cloudflared.exe',
    'C:\Program Files\cloudflared\cloudflared.exe'
  )
  $exe = $candidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $exe) {
  throw "cloudflared not found. Install with: winget install --id Cloudflare.cloudflared -e --accept-source-agreements --accept-package-agreements"
}

Write-Host "Starting public tunnel to http://localhost:$Port"
Write-Host "Using: $exe"
Write-Host "Press Ctrl+C to stop."

& $exe tunnel --url "http://localhost:$Port" --no-autoupdate
