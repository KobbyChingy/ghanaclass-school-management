param(
  [string]$ApiBaseUrl = "http://localhost:8081",

  [string]$TenantSchema = "school_demo",

  [string]$SupabaseUrl = "https://eqrkfynzaznoarcziepm.supabase.co",

  [string]$SupabasePublishableKey = "sb_publishable_7oThgrzPu25cDp-4i_7I-w_y8YJ7H0f",

  [string]$Device = "windows",

  [switch]$Detached
)

$ErrorActionPreference = 'Stop'

Push-Location (Join-Path $PSScriptRoot '..')
try {
  Write-Host "Starting Flutter against $ApiBaseUrl on device $Device..."

  $dartDefines = @(
    "--dart-define=GHANACLASS_API_BASE_URL=$ApiBaseUrl"
    "--dart-define=GHANACLASS_TENANT_SCHEMA=$TenantSchema"
    "--dart-define=GHANACLASS_SUPABASE_URL=$SupabaseUrl"
    "--dart-define=GHANACLASS_SUPABASE_PUBLISHABLE_KEY=$SupabasePublishableKey"
  )

  if ($Detached -and $Device -eq 'windows') {
    flutter build windows --debug @dartDefines

    $exePath = Join-Path $PWD 'build\windows\x64\runner\Debug\ghanaclass_school_management.exe'
    if (-not (Test-Path $exePath)) {
      throw "Built executable not found at $exePath"
    }

    $process = Start-Process -FilePath $exePath -PassThru
    Write-Host "Launched detached Windows app (PID: $($process.Id))."
  } else {
    flutter run -d $Device @dartDefines
  }
}
finally {
  Pop-Location
}