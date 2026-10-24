unit Mir2HomeGameState;
interface
uses Classes;
function Mir2HomeGameStateEnabled: Boolean;
procedure SaveMir2HomeGameState(const MapName: string; X, Y, HP, MaxHP, MP, MaxMP: Integer);
procedure SaveMir2HomeMonsterState(Lines: TStrings);
implementation
uses Windows, SysUtils, IniFiles;
var Checked, Enabled: Boolean;
function Mir2HomeGameStateEnabled: Boolean;
{$IFDEF DEBUG}
var Ini: TIniFile; Path: string;
{$ENDIF}
begin
  Result := False;
{$IFDEF DEBUG}
  try
    if not Checked then begin
      Checked := True;
      Path := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
      Ini := TIniFile.Create(Path + 'Mir2Classic176.ini');
      try Enabled := Ini.ReadBool('Diagnostics', 'GameState', False); finally Ini.Free; end;
    end;
    Result := Enabled;
  except Result := False; end;
{$ENDIF}
end;
procedure SaveMir2HomeGameState(const MapName: string; X, Y, HP, MaxHP, MP, MaxMP: Integer);
var Lines: TStringList; Path: string;
begin
{$IFDEF DEBUG}
  try
    if not Mir2HomeGameStateEnabled then Exit;
    Path := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
    Lines := TStringList.Create;
    try
      Lines.Values['Map'] := MapName;
      Lines.Values['X'] := IntToStr(X); Lines.Values['Y'] := IntToStr(Y);
      Lines.Values['HP'] := IntToStr(HP); Lines.Values['MaxHP'] := IntToStr(MaxHP);
      Lines.Values['MP'] := IntToStr(MP); Lines.Values['MaxMP'] := IntToStr(MaxMP);
      Lines.SaveToFile(Path + '!game-state.tmp', TEncoding.UTF8);
      MoveFileEx(PChar(Path + '!game-state.tmp'), PChar(Path + '!game-state.txt'), MOVEFILE_REPLACE_EXISTING);
    finally Lines.Free; end;
  except end;
{$ENDIF}
end;
procedure SaveMir2HomeMonsterState(Lines: TStrings);
var Path: string;
begin
{$IFDEF DEBUG}
  try
    if (Lines = nil) or not Mir2HomeGameStateEnabled then Exit;
    Path := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
    Lines.SaveToFile(Path + '!monster-state.tmp', TEncoding.UTF8);
    MoveFileEx(PChar(Path + '!monster-state.tmp'), PChar(Path + '!monster-state.txt'), MOVEFILE_REPLACE_EXISTING);
  except end;
{$ENDIF}
end;
end.
