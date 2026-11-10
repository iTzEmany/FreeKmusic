; Inno Setup script: per-user installer, no administrator rights.
; Built by .github/workflows/release.yml with:
;   iscc /DAppVersion=1.2.0 packaging\windows\freekmusic.iss
; Expects, next to the release build, the third-party tools in build\windows\tools\
; (yt-dlp.exe, ffmpeg.exe and their licence texts: see the workflow).
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{EF5C9312-ED39-4531-983B-7B08205ECC81}
AppName=FreeKmusic
AppVersion={#AppVersion}
AppPublisher=FreeKmusic
DefaultDirName={localappdata}\Programs\FreeKmusic
DefaultGroupName=FreeKmusic
PrivilegesRequired=lowest
OutputDir=..\..\build
OutputBaseFilename=FreeKmusic-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\freekmusic.exe
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
; yt-dlp (Unlicense) and ffmpeg (LGPL build) go next to freekmusic.exe, where the app looks first.
Source: "..\..\build\windows\tools\yt-dlp.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\build\windows\tools\ffmpeg.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\build\windows\tools\licenses\*"; DestDir: "{app}\licenses"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\FreeKmusic"; Filename: "{app}\freekmusic.exe"
Name: "{autodesktop}\FreeKmusic"; Filename: "{app}\freekmusic.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\freekmusic.exe"; Description: "{cm:LaunchProgram,FreeKmusic}"; Flags: nowait postinstall skipifsilent

[Code]
// The user's data (library database, covers, downloads index) lives in
// %APPDATA% and is kept unless the user says otherwise.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    if MsgBox('Eliminare anche i dati di FreeKmusic (libreria, playlist, copertine)?', mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      DelTree(ExpandConstant('{userappdata}\com.freekmusic\FreeKmusic'), True, True, True);
end;
