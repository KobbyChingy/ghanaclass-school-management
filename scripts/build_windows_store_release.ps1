param(
  [string]$ApiBaseUrl,

  [string]$TenantSchema = 'school_demo',

  [string]$SupabaseUrl = 'https://eqrkfynzaznoarcziepm.supabase.co',

  [string]$SupabasePublishableKey = 'sb_publishable_7oThgrzPu25cDp-4i_7I-w_y8YJ7H0f',

  [string]$ConfigFile = '.\scripts\release.env',

  [switch]$InstallCertificate
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

Push-Location (Join-Path $PSScriptRoot '..')
try {
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

  $dartDefines = @(
    "--dart-define=GHANACLASS_API_BASE_URL=$ApiBaseUrl"
    "--dart-define=GHANACLASS_TENANT_SCHEMA=$TenantSchema"
    "--dart-define=GHANACLASS_SUPABASE_URL=$SupabaseUrl"
    "--dart-define=GHANACLASS_SUPABASE_PUBLISHABLE_KEY=$SupabasePublishableKey"
  )

  Write-Host "Building Flutter Windows release with production defines..."
  flutter build windows --release @dartDefines

  $installCertificateValue = if ($InstallCertificate) { 'true' } else { 'false' }

  Write-Host "Packaging MSIX for Microsoft Store / App Installer distribution..."
  dart run msix:create --install-certificate $installCertificateValue --build-windows false
}
finally {
  Pop-Location
}