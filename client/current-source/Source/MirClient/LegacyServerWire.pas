unit LegacyServerWire;

interface

uses Windows, SysUtils, Grobal2, EDcode;

const
  LegacyCharDescEncodedSize = 11; // 8 raw bytes, encoded by the server independently of its name

function DecodeLegacyAbility(const Body: AnsiString; var Abil: TAbility): Boolean;
procedure DecodeLegacyCharDesc(const Body: AnsiString; var Desc: TCharDesc);

implementation

type
  TLegacyAbilityWire = packed record
    Level, Reserved1: Byte;
    AC, MAC, DC, MC, SC: Word;
    HP, MP, MaxHP, MaxMP: Word;
    Reserved2: SmallInt;
    ExpCount, ExpMaxCount: Byte;
    Exp, MaxExp: Integer;
    Weight, MaxWeight: Word;
    WearWeight, MaxWearWeight, HandWeight, MaxHandWeight: Byte;
  end;
  TLegacyCharDescWire = packed record
    Feature, Status: Integer;
  end;

function ExpandRange(Value: Word): Integer;
begin
  Result := Integer(Value and $FF) or (Integer(Value shr 8) shl 16);
end;

function DecodeLegacyAbility(const Body: AnsiString; var Abil: TAbility): Boolean;
var
  Wire: TLegacyAbilityWire;
begin
  Result := False;
  // Reject truncated payloads instead of copying uninitialized decoder stack bytes.
  if (SizeOf(Wire) <> 40) or (Length(Body) <> 54) then Exit;
  FillChar(Wire, SizeOf(Wire), 0);
  DecodeBuffer(Body, @Wire, SizeOf(Wire));
  FillChar(Abil, SizeOf(Abil), 0);
  Abil.Level := Wire.Level;
  Abil.AC := ExpandRange(Wire.AC);
  Abil.MAC := ExpandRange(Wire.MAC);
  Abil.DC := ExpandRange(Wire.DC);
  Abil.MC := ExpandRange(Wire.MC);
  Abil.SC := ExpandRange(Wire.SC);
  Abil.HP := Wire.HP;
  Abil.MP := Wire.MP;
  Abil.MaxHP := Wire.MaxHP;
  Abil.MaxMP := Wire.MaxMP;
  Abil.Exp := DWORD(Wire.Exp);
  Abil.MaxExp := DWORD(Wire.MaxExp);
  Abil.Weight := Wire.Weight;
  Abil.MaxWeight := Wire.MaxWeight;
  Abil.WearWeight := Wire.WearWeight;
  Abil.MaxWearWeight := Wire.MaxWearWeight;
  Abil.HandWeight := Wire.HandWeight;
  Abil.MaxHandWeight := Wire.MaxHandWeight;
  Result := True;
end;

procedure DecodeLegacyCharDesc(const Body: AnsiString; var Desc: TCharDesc);
var
  Wire: TLegacyCharDescWire;
begin
  FillChar(Desc, SizeOf(Desc), 0);
  if Length(Body) < LegacyCharDescEncodedSize then Exit;
  FillChar(Wire, SizeOf(Wire), 0);
  DecodeBuffer(Copy(Body, 1, LegacyCharDescEncodedSize), @Wire, SizeOf(Wire));
  Desc.Feature := Wire.Feature;
  Desc.Status := Wire.Status;
  // This server has no StatusEx field in CharDesc. Never consume name bytes as that field.
end;

end.
