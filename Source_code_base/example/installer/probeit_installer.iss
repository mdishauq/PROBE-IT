; Probe IT installer script (Inno Setup)
; Build output: installer\dist\ProbeIT-Setup-<version>.exe

#define MyAppName "Probe IT"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Mohamed Ishauq Student Project"
#define MyAppURL "https://github.com/mdishauq/PROBE-IT"
#define MyAppExeName "cpu_analyser_example.exe"
#define MyAppIdNoBraces "C45FC3B4-3C11-4DDA-8AF0-577D5941CC67"
#define BuildRoot "..\\build\\windows\\x64\\runner\\Release"

[Setup]
AppId={{C45FC3B4-3C11-4DDA-8AF0-577D5941CC67}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=..\\..\\LICENSE
InfoBeforeFile=welcome.txt
OutputDir=dist
OutputBaseFilename=ProbeIT-Setup-{#MyAppVersion}
SetupIconFile=..\\windows\\runner\\resources\\app_icon.ico
UninstallDisplayIcon={app}\\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
MinVersion=10.0
DisableProgramGroupPage=no
DisableWelcomePage=no
ShowLanguageDialog=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: checkedonce
Name: "startmenuicon"; Description: "Create a Start Menu shortcut"; GroupDescription: "Additional icons:"; Flags: checkedonce
Name: "launchafter"; Description: "Launch {#MyAppName} after installation"; GroupDescription: "Post-install:"; Flags: unchecked

[Files]
Source: "{#BuildRoot}\\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{autodesktop}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"; Tasks: desktopicon
Name: "{group}\\{#MyAppName}"; Filename: "{app}\\{#MyAppExeName}"; Tasks: startmenuicon
Name: "{group}\\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent; Tasks: launchafter

[Code]
function InitializeSetup(): Boolean;
begin
  Result := SuppressibleMsgBox(
    'This is a student project created to help everyone monitor CPU and memory health.' + #13#10#13#10 +
    'It is provided for educational and general informational purposes only.' + #13#10 +
    'Do you want to continue installation?',
    mbInformation, MB_YESNO, IDYES
  ) = IDYES;
end;

function InitializeUninstall(): Boolean;
begin
  Result := SuppressibleMsgBox(
    'Do you want to remove Probe IT and all of its shortcuts?',
    mbConfirmation, MB_YESNO, IDYES
  ) = IDYES;
end;
