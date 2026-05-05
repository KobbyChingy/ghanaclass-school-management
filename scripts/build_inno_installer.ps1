param(
  [ValidateSet('Debug','Release')]
  [string]$Configuration = 'Release',

  [string]$ApiBaseUrl,

  [string]$TenantSchema = 'school_demo',

  [string]$SupabaseUrl = 'https://eqrkfynzaznoarcziepm.supabase.co',

  [string]$SupabasePublishableKey = 'sb_publishable_7oThgrzPu25cDp-4i_7I-w_y8YJ7H0f',

  [string]$ConfigFile = '.\scripts\release.env'
)

$ErrorActionPreference = 'Stop'

function Import-ReleaseConfig {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return @{}
  }

  $values = @{}
  foreach ($line in Get-Content -Path $Path) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#')) {
      continue
    }

    $parts = $trimmed -split '=', 2
    if ($parts.Count -ne 2) {
      continue
    }

    $values[$parts[0].Trim()] = $parts[1].Trim()
  }

  return $values
}

Push-Location (Split-Path -Parent $PSCommandPath)
Pop-Location

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$releaseConfig = Import-ReleaseConfig -Path $ConfigFile

if (-not $ApiBaseUrl) {
  $ApiBaseUrl = $releaseConfig['GHANACLASS_API_BASE_URL']
}
if ($releaseConfig.ContainsKey('GHANACLASS_TENANT_SCHEMA')) {
  $TenantSchema = $releaseConfig['GHANACLASS_TENANT_SCHEMA']
}
if ($releaseConfig.ContainsKey('GHANACLASS_SUPABASE_URL')) {
  $SupabaseUrl = $releaseConfig['GHANACLASS_SUPABASE_URL']
}
if ($releaseConfig.ContainsKey('GHANACLASS_SUPABASE_PUBLISHABLE_KEY')) {
  $SupabasePublishableKey = $releaseConfig['GHANACLASS_SUPABASE_PUBLISHABLE_KEY']
}

if (-not $ApiBaseUrl) {
  throw 'Missing ApiBaseUrl. Pass -ApiBaseUrl or create scripts/release.env from scripts/release.env.example.'
}

$issPath = Join-Path $repoRoot 'installer\inno\ghanaclass_school_management.iss'

# Best-effort: derive version from pubspec.yaml (e.g. 1.0.0+1 -> 1.0.0)
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$appVersion = '1.0.0'
if (Test-Path $pubspecPath) {
  $pubspec = Get-Content -Raw -Path $pubspecPath
  if ($pubspec -match "(?m)^version:\s*([^\s]+)\s*$") {
    $rawVersion = $Matches[1]
    $appVersion = ($rawVersion -split '\+')[0]
  }
}

# Ensure dist output folder exists
$distDir = Join-Path $repoRoot 'dist'
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

Write-Host "Building Flutter Windows ($Configuration)..."
$dartDefines = @(
  "--dart-define=GHANACLASS_API_BASE_URL=$ApiBaseUrl"
  "--dart-define=GHANACLASS_TENANT_SCHEMA=$TenantSchema"
  "--dart-define=GHANACLASS_SUPABASE_URL=$SupabaseUrl"
  "--dart-define=GHANACLASS_SUPABASE_PUBLISHABLE_KEY=$SupabasePublishableKey"
)

if ($Configuration -eq 'Release') {
  flutter build windows --release @dartDefines
} else {
  flutter build windows --debug @dartDefines
}

# Try to find ISCC.exe
$possibleIscc = @(
  (Get-Command iscc.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
  "${env:ProgramFiles(x86)}\\Inno Setup 6\\ISCC.exe",
  "$env:ProgramFiles\\Inno Setup 6\\ISCC.exe",
  "$env:LOCALAPPDATA\\Programs\\Inno Setup 6\\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

if (-not $possibleIscc) {
  Write-Host "ISCC.exe not found. Install Inno Setup 6, then rerun this script."
  Write-Host "Download: https://jrsoftware.org/isdl.php"
  Write-Host "After install, ensure ISCC.exe is on PATH or in Program Files."
  exit 2
}

$iscc = ($possibleIscc | Select-Object -First 1)
Write-Host "Compiling Inno Setup script with: $iscc"
& $iscc "/DAppVersion=$appVersion" "/DBuildConfiguration=$Configuration" $issPath

Write-Host "Done. Check the dist folder for the setup .exe."
