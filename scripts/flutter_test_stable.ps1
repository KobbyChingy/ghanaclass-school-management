param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $TestArgs
)

$ErrorActionPreference = 'Stop'

# Ensure we run from the repo root (one level above /scripts).
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

# Use a stable, project-local temp folder to avoid intermittent failures on Windows
# where %TEMP% content can disappear mid-run.
$tmpDir = Join-Path $repoRoot '.tmp\flutter_temp'
if (!(Test-Path $tmpDir)) {
  New-Item -ItemType Directory -Path $tmpDir | Out-Null
}

$env:TEMP = $tmpDir
$env:TMP = $tmpDir

# Avoid invoking flutter.bat directly (can trigger an interactive
# "Terminate batch job (Y/N)?" prompt on Windows in some terminal states).
# Instead, invoke Flutter via flutter_tools.dart using the Dart VM.
#
# We locate the Flutter SDK root via the `flutter` command on PATH, then
# use the bundled dart.exe from that SDK (not dart.bat).
$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
$flutterBinDir = Split-Path -Parent $flutterCommand
$flutterRoot = Resolve-Path (Join-Path $flutterBinDir '..')

$dartExe = Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
if (!(Test-Path $dartExe)) {
  throw "Could not locate dart.exe at: $dartExe"
}

$flutterTools = Join-Path $flutterRoot 'packages\flutter_tools\bin\flutter_tools.dart'

if (!(Test-Path $flutterTools)) {
  throw "Could not locate flutter_tools.dart at: $flutterTools"
}

# Workaround for an intermittent Flutter tool crash on Windows where
# `flutter test` fails to create `build\unit_test_assets\...`.
$unitTestAssetsDir = Join-Path $repoRoot 'build\unit_test_assets\packages'
if (!(Test-Path $unitTestAssetsDir)) {
  New-Item -ItemType Directory -Force -Path $unitTestAssetsDir | Out-Null
}

# Default args: verbose + single worker tends to be the most stable on Windows.
$defaultArgs = @('-r', 'expanded', '-j', '1')

if ($TestArgs -and $TestArgs.Length -gt 0) {
  & $dartExe $flutterTools test @TestArgs
} else {
  & $dartExe $flutterTools test @defaultArgs
}

$exitCode = $LASTEXITCODE
Write-Output "exit=$exitCode"
exit $exitCode
