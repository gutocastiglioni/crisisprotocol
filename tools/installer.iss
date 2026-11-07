; Script de Instalador para Crisis Protocol (Inno Setup 6)

[Setup]
AppId={{8B5C0851-930B-4AEB-8643-98781B85D36B}
AppName=Crisis Protocol
AppVersion=1.0
AppPublisher=Crisis Protocol
DefaultDirName={autopf}\Crisis Protocol
DefaultGroupName=Crisis Protocol
AllowNoIcons=yes
OutputDir=..\INSTALADOR
OutputBaseFilename=CrisisProtocol_Setup
Compression=lzma2/ultra64
SolidCompression=yes
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\INSTALADOR\Versao_Portatil_Windows\CrisisProtocol.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Crisis Protocol"; Filename: "{app}\CrisisProtocol.exe"
Name: "{group}\{cm:UninstallProgram,Crisis Protocol}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Crisis Protocol"; Filename: "{app}\CrisisProtocol.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\CrisisProtocol.exe"; Description: "{cm:LaunchProgram,Crisis Protocol}"; Flags: nowait postinstall skipifsilent

