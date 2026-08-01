param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectId,

  [Parameter(Mandatory = $true)]
  [string]$DatabaseUrl,

  [string]$ServiceName = "ghanaclass-backend",

  [string]$Region = "us-central1",

  [string]$JwtSecret,

  [bool]$AllowUnauthenticated = $true
)

$ErrorActionPreference = 'Stop'

function New-Base64Secret {
  $bytes = New-Object byte[] 32
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $rng.GetBytes($bytes)
  }
  finally {
    $rng.Dispose()
  }

  return [Convert]::ToBase64String($bytes)
}

$gcloud = Get-Command gcloud -ErrorAction SilentlyContinue
if (-not $gcloud) {
  throw "gcloud CLI is not installed. Install Google Cloud SDK, then rerun this script."
}

if ([string]::IsNullOrWhiteSpace($JwtSecret)) {
  $JwtSecret = New-Base64Secret
  Write-Host "Generated JWT_SECRET for Cloud Run deployment."
}

$repoRoot = Join-Path $PSScriptRoot '..'
$backendDir = Join-Path $repoRoot 'backend'

if (-not (Test-Path $backendDir)) {
  throw "Backend directory not found: $backendDir"
}

Write-Host "Enabling required Google Cloud APIs for project $ProjectId..."
& gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --project $ProjectId

$deployArgs = @(
  'run'
  'deploy'
  $ServiceName
  '--project'
  $ProjectId
  '--source'
  $backendDir
  '--region'
  $Region
  '--platform'
  'managed'
  '--port'
  '8080'
  '--cpu'
  '1'
  '--memory'
  '512Mi'
  '--concurrency'
  '20'
  '--max-instances'
  '1'
  '--min-instances'
  '0'
  '--set-env-vars'
  "DATABASE_URL=$DatabaseUrl"
  '--set-env-vars'
  "JWT_SECRET=$JwtSecret"
  '--quiet'
)

if ($AllowUnauthenticated) {
  $deployArgs += '--allow-unauthenticated'
} else {
  $deployArgs += '--no-allow-unauthenticated'
}

Write-Host "Deploying $ServiceName to Cloud Run in $Region..."
& gcloud @deployArgs

$serviceUrl = & gcloud run services describe $ServiceName --project $ProjectId --region $Region --format 'value(status.url)'

if ([string]::IsNullOrWhiteSpace($serviceUrl)) {
  Write-Warning "Deploy completed, but the service URL could not be resolved automatically."
} else {
  Write-Host "Cloud Run service URL: $serviceUrl"
  Write-Host "Use this as GHANACLASS_API_BASE_URL for Flutter release builds."
}