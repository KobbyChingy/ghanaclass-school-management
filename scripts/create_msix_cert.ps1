param(
  [string]$Subject = "CN=GhanaClass",
  [string]$PfxPath = "windows\\msix\\ghanaclass-dev.pfx",
  [string]$Password = "GhanaClassDev123!"
)

$ErrorActionPreference = 'Stop'

$fullPfxPath = Join-Path (Get-Location) $PfxPath
$fullPfxDir = Split-Path -Parent $fullPfxPath

if (-not (Test-Path $fullPfxDir)) {
  New-Item -ItemType Directory -Path $fullPfxDir | Out-Null
}

Write-Host "Creating self-signed code-signing certificate: $Subject"
$cert = New-SelfSignedCertificate `
  -Type Custom `
  -Subject $Subject `
  -KeyUsage DigitalSignature `
  -KeySpec Signature `
  -KeyExportPolicy Exportable `
  -FriendlyName "GhanaClass MSIX Dev Cert" `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")

$securePassword = ConvertTo-SecureString -String $Password -Force -AsPlainText

Write-Host "Exporting PFX to: $fullPfxPath"
Export-PfxCertificate -Cert $cert -FilePath $fullPfxPath -Password $securePassword | Out-Null

Write-Host "Done. Update pubspec.yaml msix_config if you change Subject/Password."
Write-Host "Publisher must match certificate Subject (e.g. CN=GhanaClass)."
