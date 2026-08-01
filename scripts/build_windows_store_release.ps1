param(
  [string]$ApiBaseUrl,

  [string]$TenantSchema = 'school_demo',

  [string]$SupabaseUrl = 'https://eqrkfynzaznoarcziepm.supabase.co',

  [string]$SupabasePublishableKey = 'sb_publishable_7oThgrzPu25cDp-4i_7I-w_y8YJ7H0f',

  [string]$ConfigFile = '.\scripts\release.env',

  [string]$MsixConfigFile = '.\scripts\msix.release.env',

  [switch]$AllowLocalhostApiBaseUrl,

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

function Get-RequiredConfigValue {
  param(
    [hashtable]$Config,
    [string]$Key,
    [string]$SourceLabel
  )

  if (-not $Config.ContainsKey($Key) -or [string]::IsNullOrWhiteSpace($Config[$Key])) {
    throw "Missing $Key in $SourceLabel."
  }

  return $Config[$Key].Trim()
}

function ConvertTo-YamlSingleQuoted {
  param([string]$Value)

  return "'" + ($Value -replace "'", "''") + "'"
}

function Resolve-ConfigPath {
  param(
    [string]$Path,
    [string]$BaseDirectory
  )

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }

  return [System.IO.Path]::GetFullPath((Join-Path $BaseDirectory $Path))
}

function Set-PubspecMsixConfig {
  param(
    [string]$PubspecPath,
    [hashtable]$MsixValues
  )

  $originalContent = Get-Content -Raw -Path $PubspecPath
  $updatedBlock = @(
    'msix_config:'
    "  display_name: $(ConvertTo-YamlSingleQuoted $MsixValues['display_name'])"
    "  publisher_display_name: $(ConvertTo-YamlSingleQuoted $MsixValues['publisher_display_name'])"
    "  identity_name: $(ConvertTo-YamlSingleQuoted $MsixValues['identity_name'])"
    "  publisher: $(ConvertTo-YamlSingleQuoted $MsixValues['publisher'])"
    "  msix_version: $(ConvertTo-YamlSingleQuoted $MsixValues['msix_version'])"
    "  logo_path: $(ConvertTo-YamlSingleQuoted $MsixValues['logo_path'])"
    "  certificate_path: $(ConvertTo-YamlSingleQuoted $MsixValues['certificate_path'])"
    "  certificate_password: $(ConvertTo-YamlSingleQuoted $MsixValues['certificate_password'])"
    "  capabilities: $(ConvertTo-YamlSingleQuoted $MsixValues['capabilities'])"
  ) -join [Environment]::NewLine

  $updatedContent = [regex]::Replace(
    $originalContent,
    '(?ms)^msix_config:\r?\n(?:  .*\r?\n)*',
    "$updatedBlock$([Environment]::NewLine)"
  )

  if ($updatedContent -eq $originalContent) {
    throw 'Unable to locate msix_config block in pubspec.yaml.'
  }

  Set-Content -Path $PubspecPath -Value $updatedContent -NoNewline
  return $originalContent
}

function Assert-HostedApiBaseUrl {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Value,

    [switch]$AllowLocalhost
  )

  if ($AllowLocalhost) {
    return
  }

  $trimmed = $Value.Trim()
  [System.Uri]$uri = $null
  if (-not [System.Uri]::TryCreate($trimmed, [System.UriKind]::Absolute, [ref]$uri)) {
    throw "Invalid GHANACLASS_API_BASE_URL '$trimmed'. Use an absolute URL such as https://api.your-domain.com"
  }

  $apiHost = $uri.Host.ToLowerInvariant()
  $localHosts = @('localhost', '127.0.0.1', '::1')
  if ($localHosts -contains $apiHost) {
    throw "Refusing production desktop store build with local API URL '$trimmed'. Set GHANACLASS_API_BASE_URL to a hosted backend (or pass -AllowLocalhostApiBaseUrl for local-only testing)."
  }
}

Push-Location (Join-Path $PSScriptRoot '..')
try {
  $repoRoot = Get-Location
  $releaseConfig = Import-ReleaseConfig -Path $ConfigFile
  $pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
  $pubspecOriginalContent = $null

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

  Assert-HostedApiBaseUrl -Value $ApiBaseUrl -AllowLocalhost:$AllowLocalhostApiBaseUrl

  if (-not (Test-Path $MsixConfigFile)) {
    throw "Missing MSIX config file '$MsixConfigFile'. Copy scripts/msix.release.env.example to scripts/msix.release.env and fill in your real publisher + certificate values."
  }

  $msixConfig = Import-ReleaseConfig -Path $MsixConfigFile
  $msixDisplayName = Get-RequiredConfigValue -Config $msixConfig -Key 'MSIX_DISPLAY_NAME' -SourceLabel $MsixConfigFile
  $msixPublisherDisplayName = Get-RequiredConfigValue -Config $msixConfig -Key 'MSIX_PUBLISHER_DISPLAY_NAME' -SourceLabel $MsixConfigFile
  $msixIdentityName = Get-RequiredConfigValue -Config $msixConfig -Key 'MSIX_IDENTITY_NAME' -SourceLabel $MsixConfigFile
  $msixPublisher = Get-RequiredConfigValue -Config $msixConfig -Key 'MSIX_PUBLISHER' -SourceLabel $MsixConfigFile
  $msixVersion = Get-RequiredConfigValue -Config $msixConfig -Key 'MSIX_VERSION' -SourceLabel $MsixConfigFile
  $msixCertificatePathValue = Get-RequiredConfigValue -Config $msixConfig -Key 'MSIX_CERTIFICATE_PATH' -SourceLabel $MsixConfigFile
  $msixCertificatePassword = Get-RequiredConfigValue -Config $msixConfig -Key 'MSIX_CERTIFICATE_PASSWORD' -SourceLabel $MsixConfigFile
  $msixLogoPath = if ($msixConfig.ContainsKey('MSIX_LOGO_PATH') -and -not [string]::IsNullOrWhiteSpace($msixConfig['MSIX_LOGO_PATH'])) { $msixConfig['MSIX_LOGO_PATH'].Trim() } else { 'windows/runner/resources/app_icon.ico' }
  $msixCapabilities = if ($msixConfig.ContainsKey('MSIX_CAPABILITIES') -and -not [string]::IsNullOrWhiteSpace($msixConfig['MSIX_CAPABILITIES'])) { $msixConfig['MSIX_CAPABILITIES'].Trim() } else { 'internetClient' }

  $resolvedMsixCertificatePath = Resolve-ConfigPath -Path $msixCertificatePathValue -BaseDirectory $repoRoot
  if (-not (Test-Path $resolvedMsixCertificatePath)) {
    throw "Configured MSIX certificate path '$msixCertificatePathValue' was not found."
  }

  $devCertificatePath = Join-Path $repoRoot 'windows\msix\ghanaclass-dev.pfx'
  if ((Resolve-Path $resolvedMsixCertificatePath).Path -eq (Resolve-Path $devCertificatePath).Path) {
    throw 'Refusing store build with the development MSIX certificate. Replace MSIX_CERTIFICATE_PATH with your production signing certificate.'
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

  $pubspecOriginalContent = Set-PubspecMsixConfig -PubspecPath $pubspecPath -MsixValues @{
    display_name = $msixDisplayName
    publisher_display_name = $msixPublisherDisplayName
    identity_name = $msixIdentityName
    publisher = $msixPublisher
    msix_version = $msixVersion
    logo_path = $msixLogoPath
    certificate_path = $resolvedMsixCertificatePath
    certificate_password = $msixCertificatePassword
    capabilities = $msixCapabilities
  }

  Write-Host "Packaging MSIX for Microsoft Store / App Installer distribution..."
  dart run msix:create --install-certificate $installCertificateValue --build-windows false
}
finally {
  if ($pubspecOriginalContent) {
    Set-Content -Path $pubspecPath -Value $pubspecOriginalContent -NoNewline
  }
  Pop-Location
}