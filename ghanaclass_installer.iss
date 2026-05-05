[Setup]
AppName=GhanaClass School Management
AppVersion=1.0.0
DefaultDirName={pf}\GhanaClassSchoolManagement
DefaultGroupName=GhanaClass School Management
OutputDir=.
OutputBaseFilename=GhanaClassSchoolManagementInstaller
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\GhanaClass School Management"; Filename: "{app}\ghanaclass_school_management.exe"
Name: "{group}\Uninstall GhanaClass School Management"; Filename: "{uninstallexe}"
