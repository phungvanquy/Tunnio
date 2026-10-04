[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={{INSTALL_DIR_NAME}}
UsePreviousAppDir=yes
CloseApplications=no
RestartApplications=no
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
WizardStyle=modern
PrivilegesRequired={{PRIVILEGES_REQUIRED}}
ArchitecturesAllowed={{ARCH}}
ArchitecturesInstallIn64BitMode={{ARCH}}

[Code]
function OpenAppProcess(Access: Cardinal; Inherit: Boolean; ProcessId: Cardinal): THandle;
  external 'OpenProcess@kernel32.dll stdcall';

function QueryAppPath(Process: THandle; Flags: Cardinal; Path: String; var Size: Cardinal): Boolean;
  external 'QueryFullProcessImageNameW@kernel32.dll stdcall';

function WaitForApp(Process: THandle; Milliseconds: Cardinal): Cardinal;
  external 'WaitForSingleObject@kernel32.dll stdcall';

function CloseAppHandle(Handle: THandle): Boolean;
  external 'CloseHandle@kernel32.dll stdcall';

function FindAppWindow(Parent, After: HWND; ClassName: String; WindowName: THandle): HWND;
  external 'FindWindowExW@user32.dll stdcall';

function AppWindowProcess(Window: HWND; var ProcessId: Cardinal): Cardinal;
  external 'GetWindowThreadProcessId@user32.dll stdcall';

function ShutdownAppProcess(ProcessId: Cardinal): Boolean;
var
  Process: THandle;
  Path: String;
  Size, WindowProcessId, ShutdownMessage, WaitResult: Cardinal;
  Window: HWND;
  Attempt: Integer;
begin
  Result := False;
  Process := OpenAppProcess($00101000, False, ProcessId);
  if Process = 0 then
  begin
    Result := DLLGetLastError = 87;
    Exit;
  end;
  try
    Size := 32768;
    SetLength(Path, Size);
    if not QueryAppPath(Process, 0, Path, Size) then
    begin
      Result := WaitForApp(Process, 0) = 0;
      Exit;
    end;
    SetLength(Path, Size);
    if (CompareText(Path, ExpandConstant('{app}\Tunnio.exe')) <> 0) and
      (CompareText(Path, ExpandConstant('{app}\FlClash.exe')) <> 0) then
    begin
      Result := True;
      Exit;
    end;
    ShutdownMessage := RegisterWindowMessage('com.follow.clash.shutdown');
    if ShutdownMessage = 0 then Exit;
    Log('Requesting application exit: ' + Path);
    for Attempt := 1 to 100 do
    begin
      WaitResult := WaitForApp(Process, 100);
      if WaitResult <> $102 then
      begin
        Result := WaitResult = 0;
        Exit;
      end;
      Window := FindAppWindow(0, 0, 'FLUTTER_RUNNER_WIN32_WINDOW', 0);
      while Window <> 0 do
      begin
        AppWindowProcess(Window, WindowProcessId);
        if WindowProcessId = ProcessId then
          PostMessage(Window, ShutdownMessage, 0, 0);
        Window := FindAppWindow(0, Window, 'FLUTTER_RUNNER_WIN32_WINDOW', 0);
      end;
    end;
    Result := WaitForApp(Process, 0) = 0;
  finally
    CloseAppHandle(Process);
  end;
end;

function ShutdownApplications: Boolean;
var
  Locator, Services, Processes, Process: Variant;
  I: Integer;
begin
  Result := False;
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Services := Locator.ConnectServer('.', 'root\CIMV2');
    Processes := Services.ExecQuery(
      'SELECT ProcessId FROM Win32_Process WHERE Name = ''Tunnio.exe'' OR Name = ''FlClash.exe''');
    for I := 0 to Processes.Count - 1 do
    begin
      Process := Processes.ItemIndex(I);
      if not ShutdownAppProcess(Process.ProcessId) then Exit;
    end;
    Result := True;
  except
    Log('Could not check running applications: ' + GetExceptionMessage);
  end;
end;

function UnregisterHelperService: String;
var
  HelperPath: String;
  ResultCode: Integer;
begin
  Result := '';
  HelperPath := ExpandConstant('{app}\TunnioHelperService.exe');
  if not FileExists(HelperPath) then
    HelperPath := ExpandConstant('{app}\FlClashHelperService.exe');
  if FileExists(HelperPath) then
  begin
    if not Exec(HelperPath, 'uninstall', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) or
      (ResultCode <> 0) then
    begin
      Log(Format('Helper uninstall failed: %d', [ResultCode]));
      Result := FmtMessage(SetupMessage(msgErrorExecutingProgram), [HelperPath]);
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  if not ShutdownApplications then
  begin
    Result := FmtMessage(SetupMessage(msgSetupAppRunningError), ['Tunnio']);
    Exit;
  end;
  Result := UnregisterHelperService;
end;

function ExpandEnvironmentStrings(Source: String; Destination: String; Size: Cardinal): Cardinal;
  external 'ExpandEnvironmentStringsW@kernel32.dll stdcall';

function DataFileAttributes(Path: String): Cardinal;
  external 'GetFileAttributesW@kernel32.dll stdcall';

function ExpandedPath(Value: String): String;
var
  Size: Cardinal;
begin
  Size := ExpandEnvironmentStrings(Value, '', 0);
  SetLength(Result, Size);
  if Size > 0 then
  begin
    ExpandEnvironmentStrings(Value, Result, Size);
    SetLength(Result, Size - 1);
  end;
end;

procedure RemoveAppData(Base: String);
var
  Directory: String;
  Attributes: Cardinal;
begin
  if Base = '' then Exit;
  Attributes := DataFileAttributes(AddBackslash(Base) + 'com.follow');
  if (Attributes = $FFFFFFFF) or ((Attributes and $400) <> 0) then Exit;
  Directory := AddBackslash(Base) + 'com.follow\clash';
  if DirExists(Directory) and not DelTree(Directory, True, True, True) then
    Log('Could not remove app data: ' + Directory);
  RemoveDir(AddBackslash(Base) + 'com.follow');
end;

function CommandUsesExecutable(Command, Executable: String): Boolean;
begin
  Result := (CompareText(Command, Executable) = 0) or
    (CompareText(Command, '"' + Executable + '"') = 0) or
    (Pos(Lowercase('"' + Executable + '" '), Lowercase(Command)) = 1);
end;

function OwnsCommand(Command: String): Boolean;
begin
  Result := CommandUsesExecutable(Command, ExpandConstant('{app}\Tunnio.exe')) or
    CommandUsesExecutable(Command, ExpandConstant('{app}\FlClash.exe'));
end;

procedure MigrateRegistrationValue(Root: Integer; Key, Name: String);
var
  Command, LegacyExecutable, Executable, Replacement: String;
begin
  if not RegQueryStringValue(Root, Key, Name, Command) then Exit;
  LegacyExecutable := ExpandConstant('{app}\FlClash.exe');
  if not CommandUsesExecutable(Command, LegacyExecutable) then Exit;
  Executable := ExpandConstant('{app}\Tunnio.exe');
  if Command[1] = '"' then
    Replacement := '"' + Executable + '"' +
      Copy(Command, Length(LegacyExecutable) + 3, Length(Command))
  else
    Replacement := Executable;
  if not RegWriteStringValue(Root, Key, Name, Replacement) then
    Log('Could not update registration: ' + Key);
end;

procedure MigrateUserRegistrations(Root: Integer; Prefix: String);
var
  Schemes: TArrayOfString;
  I: Integer;
begin
  MigrateRegistrationValue(Root,
    Prefix + 'Software\Microsoft\Windows\CurrentVersion\Run', 'FlClash');
  Schemes := ['clash', 'clashmeta', 'flclash', 'tunnio'];
  for I := 0 to GetArrayLength(Schemes) - 1 do
    MigrateRegistrationValue(Root,
      Prefix + 'Software\Classes\' + Schemes[I] + '\shell\open\command', '');
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Users: TArrayOfString;
  I: Integer;
begin
  if CurStep <> ssPostInstall then Exit;
  MigrateUserRegistrations(HKCU, '');
  if RegGetSubkeyNames(HKU, '', Users) then
    for I := 0 to GetArrayLength(Users) - 1 do
      MigrateUserRegistrations(HKU, Users[I] + '\');
end;

procedure RemoveUserRegistration(Root: Integer; Prefix: String);
var
  Schemes: TArrayOfString;
  Key, Command: String;
  I: Integer;
begin
  Schemes := ['clash', 'clashmeta', 'flclash', 'tunnio'];
  for I := 0 to GetArrayLength(Schemes) - 1 do
  begin
    Key := Prefix + 'Software\Classes\' + Schemes[I];
    if RegQueryStringValue(Root, Key + '\shell\open\command', '', Command) and
      OwnsCommand(Command) then
      RegDeleteKeyIncludingSubkeys(Root, Key);
  end;
  Key := Prefix + 'Software\Microsoft\Windows\CurrentVersion\Run';
  if RegQueryStringValue(Root, Key, 'FlClash', Command) and OwnsCommand(Command) then
  begin
    RegDeleteValue(Root, Key, 'FlClash');
    RegDeleteValue(Root, Prefix +
      'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run', 'FlClash');
  end;
end;

procedure RemoveSavedData;
var
  Profiles: TArrayOfString;
  Profile, Base, Key: String;
  I: Integer;
begin
  RemoveAppData(ExpandConstant('{userappdata}'));
  RemoveAppData(ExpandConstant('{localappdata}'));
  RemoveUserRegistration(HKCU, '');
  if not RegGetSubkeyNames(HKLM,
    'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList', Profiles) then Exit;
  for I := 0 to GetArrayLength(Profiles) - 1 do
  begin
    Key := 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\' + Profiles[I];
    if RegQueryStringValue(HKLM, Key, 'ProfileImagePath', Profile) then
    begin
      Profile := ExpandedPath(Profile);
      if Profile <> '' then
      begin
        RemoveAppData(AddBackslash(Profile) + 'AppData\Roaming');
        RemoveAppData(AddBackslash(Profile) + 'AppData\Local');
      end;
    end;
    Key := Profiles[I] + '\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders';
    if RegQueryStringValue(HKU, Key, 'AppData', Base) then RemoveAppData(Base);
    if RegQueryStringValue(HKU, Key, 'Local AppData', Base) then RemoveAppData(Base);
    RemoveUserRegistration(HKU, Profiles[I] + '\');
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Error: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    if not ShutdownApplications then
      Error := FmtMessage(SetupMessage(msgUninstallAppRunningError), ['Tunnio'])
    else
      Error := UnregisterHelperService;
    if Error <> '' then
    begin
      SuppressibleMsgBox(Error, mbError, MB_OK, IDOK);
      Abort;
    end;
    RemoveSavedData;
  end;
end;

[Languages]
{% for locale in LOCALES %}
{% if locale.lang == 'en' %}Name: "english"; MessagesFile: "compiler:Default.isl"{% endif %}
{% if locale.lang == 'hy' %}Name: "armenian"; MessagesFile: "compiler:Languages\\Armenian.isl"{% endif %}
{% if locale.lang == 'bg' %}Name: "bulgarian"; MessagesFile: "compiler:Languages\\Bulgarian.isl"{% endif %}
{% if locale.lang == 'ca' %}Name: "catalan"; MessagesFile: "compiler:Languages\\Catalan.isl"{% endif %}
{% if locale.lang == 'zh' %}
Name: "chineseSimplified"; MessagesFile: {% if locale.file %}{{ locale.file }}{% else %}"compiler:Languages\\ChineseSimplified.isl"{% endif %}
{% endif %}
{% if locale.lang == 'co' %}Name: "corsican"; MessagesFile: "compiler:Languages\\Corsican.isl"{% endif %}
{% if locale.lang == 'cs' %}Name: "czech"; MessagesFile: "compiler:Languages\\Czech.isl"{% endif %}
{% if locale.lang == 'da' %}Name: "danish"; MessagesFile: "compiler:Languages\\Danish.isl"{% endif %}
{% if locale.lang == 'nl' %}Name: "dutch"; MessagesFile: "compiler:Languages\\Dutch.isl"{% endif %}
{% if locale.lang == 'fi' %}Name: "finnish"; MessagesFile: "compiler:Languages\\Finnish.isl"{% endif %}
{% if locale.lang == 'fr' %}Name: "french"; MessagesFile: "compiler:Languages\\French.isl"{% endif %}
{% if locale.lang == 'de' %}Name: "german"; MessagesFile: "compiler:Languages\\German.isl"{% endif %}
{% if locale.lang == 'he' %}Name: "hebrew"; MessagesFile: "compiler:Languages\\Hebrew.isl"{% endif %}
{% if locale.lang == 'is' %}Name: "icelandic"; MessagesFile: "compiler:Languages\\Icelandic.isl"{% endif %}
{% if locale.lang == 'it' %}Name: "italian"; MessagesFile: "compiler:Languages\\Italian.isl"{% endif %}
{% if locale.lang == 'ja' %}Name: "japanese"; MessagesFile: "compiler:Languages\\Japanese.isl"{% endif %}
{% if locale.lang == 'no' %}Name: "norwegian"; MessagesFile: "compiler:Languages\\Norwegian.isl"{% endif %}
{% if locale.lang == 'pl' %}Name: "polish"; MessagesFile: "compiler:Languages\\Polish.isl"{% endif %}
{% if locale.lang == 'pt' %}Name: "portuguese"; MessagesFile: "compiler:Languages\\Portuguese.isl"{% endif %}
{% if locale.lang == 'ru' %}Name: "russian"; MessagesFile: "compiler:Languages\\Russian.isl"{% endif %}
{% if locale.lang == 'sk' %}Name: "slovak"; MessagesFile: "compiler:Languages\\Slovak.isl"{% endif %}
{% if locale.lang == 'sl' %}Name: "slovenian"; MessagesFile: "compiler:Languages\\Slovenian.isl"{% endif %}
{% if locale.lang == 'es' %}Name: "spanish"; MessagesFile: "compiler:Languages\\Spanish.isl"{% endif %}
{% if locale.lang == 'tr' %}Name: "turkish"; MessagesFile: "compiler:Languages\\Turkish.isl"{% endif %}
{% if locale.lang == 'uk' %}Name: "ukrainian"; MessagesFile: "compiler:Languages\\Ukrainian.isl"{% endif %}
{% endfor %}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}
[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: files; Name: "{app}\\FlClash.exe"
Type: files; Name: "{app}\\FlClashCore.exe"
Type: files; Name: "{app}\\FlClashHelperService.exe"
Type: files; Name: "{autoprograms}\\FlClash.lnk"
Type: files; Name: "{autodesktop}\\FlClash.lnk"

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon
[Run]
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: runasoriginaluser nowait postinstall skipifsilent
