param(
  [string]$BaseUrl = "http://localhost:8081",
  [string]$SchoolSchema = "school_001"
)

$ErrorActionPreference = 'Stop'

function Invoke-JsonPost {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Uri,

    [Parameter(Mandatory = $true)]
    [string]$Body,

    [hashtable]$Headers
  )

  return Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -ContentType "application/json" -Body $Body
}

Write-Host "== Health =="
Invoke-RestMethod "$BaseUrl/" | ConvertTo-Json -Depth 10

Write-Host "== Register School (creates admin) =="
$registerSchoolBody = @{
  code = "001"
  name = "Demo School"
  adminEmail = "admin001@example.com"
  adminPassword = "Admin1234!"
  adminFullName = "Demo Admin"
} | ConvertTo-Json

$registerSchoolResp = $null
try {
  $registerSchoolResp = Invoke-JsonPost -Uri "$BaseUrl/auth/register_school" -Body $registerSchoolBody
  $registerSchoolResp | ConvertTo-Json -Depth 10
  $SchoolSchema = $registerSchoolResp.school.schema
} catch {
  $message = $_.Exception.Message
  if ($message -notmatch '409') {
    throw
  }
  Write-Host "School already exists; continuing with login flow."
}

Write-Host "== Login =="
$loginBody = @{ email = "admin001@example.com"; password = "Admin1234!" } | ConvertTo-Json
$loginResp = Invoke-JsonPost -Uri "$BaseUrl/auth/login" -Body $loginBody
$loginResp | ConvertTo-Json -Depth 10

$adminToken = $loginResp.token
if ($loginResp.school.schema) {
  $SchoolSchema = $loginResp.school.schema
}
$headers = @{ "Authorization" = "Bearer $adminToken" }

Write-Host "== Register Staff (teacher) =="
$staffBody = @{
  email = "teacher001@example.com"
  password = "Teacher1234!"
  fullName = "Teacher One"
  role = "teacher"
} | ConvertTo-Json
try {
  Invoke-JsonPost -Uri "$BaseUrl/auth/register_staff" -Headers $headers -Body $staffBody | ConvertTo-Json -Depth 10
} catch {
  $message = $_.Exception.Message
  if ($message -notmatch '409') {
    throw
  }
  Write-Host "Teacher already exists; continuing."
}

Write-Host "== Staff Login (email/password) =="
$staffLoginBody = @{ email = "teacher001@example.com"; password = "Teacher1234!" } | ConvertTo-Json
Invoke-JsonPost -Uri "$BaseUrl/auth/login" -Body $staffLoginBody | ConvertTo-Json -Depth 10

Write-Host "== Sync Push =="
$pushBody = @{
  deviceId = "windows-dev"
  ops = @(
    @{ opId = "11111111-1111-1111-1111-111111111111"; entityType = "student"; operation = "upsert"; payload = @{ id = "s1"; fullName = "Ada Lovelace" } }
  )
} | ConvertTo-Json -Depth 10
Invoke-JsonPost -Uri "$BaseUrl/sync/push" -Headers $headers -Body $pushBody | ConvertTo-Json -Depth 10

Write-Host "== Sync Pull (since=0) =="
$pullBody = @{ since = 0 } | ConvertTo-Json
Invoke-JsonPost -Uri "$BaseUrl/sync/pull" -Headers $headers -Body $pullBody | ConvertTo-Json -Depth 10

Write-Host "== Legacy Header Compatibility Check =="
$legacyHeaders = @{ "x-school-schema" = $SchoolSchema; "Authorization" = "Bearer $adminToken" }
Invoke-JsonPost -Uri "$BaseUrl/sync/pull" -Headers $legacyHeaders -Body $pullBody | ConvertTo-Json -Depth 10
