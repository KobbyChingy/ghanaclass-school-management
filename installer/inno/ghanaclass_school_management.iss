; Inno Setup script for GhanaClass School Management (Flutter Windows)
; Compile with: ISCC.exe installer\inno\ghanaclass_school_management.iss

#define AppName "GhanaClass SMS"
#define AppPublisher "GhanaClass"
#define AppExeName "ghanaclass_school_management.exe"
#ifndef AppVersion
	#define AppVersion "1.0.0"
#endif

; Inno Setup version info fields prefer a 4-part dotted version.
#define AppVersionInfo AppVersion + ".0"

#ifndef BuildConfiguration
	#define BuildConfiguration "Release"
#endif

#define SourceDir "..\..\build\windows\x64\runner\" + BuildConfiguration
#define DistDir "..\..\dist"
#define RepoIcon "..\..\assets\branding\ghanaclass_logo.jpg"

[Setup]
AppId={{C2D3DB6E-9E1F-4F5D-9B9D-8D0CFF8C2B9C}
AppName={#AppName}
AppVerName={#AppName} {#AppVersion}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://ghanaclass.app
AppSupportURL=https://ghanaclass.app/support
AppUpdatesURL=https://ghanaclass.app/download
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Default to per-user installs to avoid UAC prompts, but allow an all-users install when run as admin.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#DistDir}
OutputBaseFilename=GhanaClassSchoolManagement_Setup_{#AppVersion}
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
; SetupIconFile expects a .ico file. Keep default installer icon until a valid .ico asset is provided.
; SetupIconFile={#RepoIcon}

; Keep behavior predictable across upgrades/reinstalls.
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes

; Avoid “files in use” failures when upgrading.
CloseApplications=yes
CloseApplicationsFilter={#AppExeName}
RestartApplications=no

; Add/Remove Programs + file version info.
UninstallDisplayIcon={app}\{#AppExeName}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppName}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersionInfo}
VersionInfoTextVersion={#AppVersion}
VersionInfoVersion={#AppVersionInfo}


; Prevent multiple running instances interfering with updates.
AppMutex=GhanaClassSchoolManagement

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
; Main exe + DLLs
Source: "{#SourceDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
; Source: "{#SourceDir}\native_assets.json"; DestDir: "{app}"; Flags: ignoreversion

; Flutter runtime data
Source: "{#SourceDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Visual C++ Redistributable
Source: "..\..\installer\vcredist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
Name: "{autoprograms}\{#AppName}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Microsoft Visual C++ Redistributable..."; Flags: waituntilterminated
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
