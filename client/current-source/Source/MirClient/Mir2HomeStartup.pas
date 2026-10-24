unit Mir2HomeStartup;

interface

uses MShare;

procedure ApplyMir2HomeStartup(var Info: TMirStartupInfo);

implementation

uses SysUtils, IniFiles;

procedure ApplyMir2HomeStartup(var Info: TMirStartupInfo);
var
  Ini: TIniFile;
  IniPath, Address, ResourcePath: string;
  Port, Width, Height: Integer;
begin
  // Existing encoded launcher arguments retain precedence.
  if ParamStr(1) <> '' then Exit;
  IniPath := ExtractFilePath(ParamStr(0)) + 'Mir2Classic176.ini';
  if not FileExists(IniPath) then
    raise Exception.Create('Mir2Classic176.ini is missing.');
  Ini := TIniFile.Create(IniPath);
  try
    Address := Trim(Ini.ReadString('Server', 'Address', ''));
    Port := Ini.ReadInteger('Server', 'Port', 7000);
    ResourcePath := Ini.ReadString('Client', 'ResourceDir', 'Resource');
    Width := Ini.ReadInteger('Client', 'Width', 800);
    Height := Ini.ReadInteger('Client', 'Height', 600);
    if (Address = '') or (Length(Address) > 30) then
      raise Exception.Create('Server address must contain 1 to 30 characters.');
    if (Port < 1) or (Port > 65535) then
      raise Exception.Create('Server port must be between 1 and 65535.');
    if (Length(ResourcePath) > 50) or (Pos(':', ResourcePath) > 0) or
       (Pos('..', ResourcePath) > 0) or (ResourcePath = '') then
      raise Exception.Create('ResourceDir must be a relative directory of up to 50 characters.');
    if not (((Width = 800) and (Height = 600)) or
            ((Width = 1024) and (Height = 768))) then
      raise Exception.Create('Supported screen sizes: 800x600 or 1024x768.');
    FillChar(Info, SizeOf(Info), 0);
    Info.sServerName := 'Mir2Classic176';
    Info.sServeraddr := ShortString(Address);
    Info.nServerPort := Port;
    Info.sResourceDir := ShortString(ResourcePath);
    Info.nScreenWidth := Width;
    Info.nScreenHegiht := Height;
    Info.boFullScreen := Ini.ReadBool('Client', 'FullScreen', False);
    Info.boWaitVBlank := True;
    Info.bo3D := False;
    Info.boMini := False;
    Info.nLocalMiniPort := 0;
    Info.btClientVer := 1;
  finally
    Ini.Free;
  end;
end;

end.
