unit LegacyItemWire;
interface
uses Windows, SysUtils, Grobal2, EDcode;
function DecodeLegacyItem(const Body: AnsiString; var Item: TClientItem): Boolean;
function DecodeLegacyStdItem(const Body: AnsiString; var Item: TClientStdItem): Boolean;
function DecodeLegacyMagic(const Body: AnsiString; var Magic: TClientMagic): Boolean;
function DecodeLegacyUserState(const Body: AnsiString; var State: TUserStateInfo): Boolean;
function LegacyItemExtraHint(const Item: TClientItem; Observed: Boolean = False): string;
procedure ClearLegacyItemMetadata;
procedure ForgetLegacyItem(MakeIndex: Integer);
procedure ResetLegacyBagMetadata(const Equipped: array of TClientItem);
implementation
type
  TStdWire = packed record
    Name: string[14];
    StdMode, Shape, Weight, AniCount: Byte;
    SpecialPwr: ShortInt;
    ItemDesc, Pad1: Byte;
    Looks, DuraMax, AC, MAC, DC, MC, SC: Word;
    Need, NeedLevel, NeedIdentify, Pad2: Byte;
    Price, Stock: Integer;
    AtkSpd, Agility, Accurate, MgAvoid, Strong, Undead, Pad3, Pad4: Byte;
    HpAdd, MpAdd, ExpAdd: Integer;
    EffType1, EffRate1, EffValue1, EffType2, EffRate2, EffValue2: Byte;
    Slowdown, Tox, ToxAvoid, UniqueItem, OverlapItem, Light, ItemType, Pad5: Byte;
    ItemSet: Word;
    Reference: string[14];
    Pad6: Byte;
  end;
  TItemWire = packed record
    Std: TStdWire;
    MakeIndex: Integer;
    Dura, DuraMax: Word;
    Desc: array[0..13] of Byte;
    Pad1, Pad2: Byte;
  end;
  TUserStateWire = packed record
    Feature: Integer;
    UserName: string[14];
    Pad: Byte;
    NameColor: Integer;
    GuildName: string[20];
    GuildRankName: string[14];
    Items: array[0..12] of TItemWire;
    ExistLover: Byte;
    LoverName: string[14];
  end;
  TItemMetadata = record
    MakeIndex: Integer;
    Name: string[14];
    Std: TStdWire;
    Desc: array[0..13] of Byte;
  end;
  TItemMetadataArray = array of TItemMetadata;
  TMagicDefWire = packed record
    MagicId: Word;
    Name: string[14];
    EffectType, Effect, Pad1: Byte;
    Spell, Power: Word;
    TrainLevel: array[0..3] of Byte;
    MaxTrain: array[0..3] of Integer;
    TrainLv, Job, Pad2, Pad3: Byte;
    DelayTime: Integer;
    DefSpell, DefPower: Byte;
    MaxPower: Word;
    DefMaxPower: Byte;
    Description: string[15];
    Pad4, Pad5, Pad6: Byte;
  end;
  TMagicWire = packed record
    Key, Level, Pad1, Pad2: Byte;
    CurTrain: Integer;
    Def: TMagicDefWire;
  end;
var
  ItemMetadata, ObservedMetadata: TItemMetadataArray;

procedure StoreMetadata(const Wire: TItemWire; var Cache: TItemMetadataArray);
var I, N: Integer;
begin
  if (Wire.MakeIndex = 0) or (Wire.Std.Name = '') then Exit;
  N := Length(Cache);
  for I := 0 to High(Cache) do
    if Cache[I].MakeIndex = Wire.MakeIndex then begin N := I; Break; end;
  if N = Length(Cache) then begin
    // Bound untrusted/obsolete item identities; no metadata affects game state.
    if N >= 4096 then begin SetLength(Cache, 0); N := 0; end;
    SetLength(Cache, N + 1);
  end;
  Cache[N].MakeIndex := Wire.MakeIndex;
  Cache[N].Name := Wire.Std.Name;
  Cache[N].Std := Wire.Std;
  Move(Wire.Desc, Cache[N].Desc, SizeOf(Cache[N].Desc));
end;

procedure ClearLegacyItemMetadata;
begin
  SetLength(ItemMetadata, 0);
  SetLength(ObservedMetadata, 0);
end;

procedure ForgetLegacyItem(MakeIndex: Integer);
var I, J: Integer;
begin
  for I := High(ItemMetadata) downto 0 do
    if ItemMetadata[I].MakeIndex = MakeIndex then begin
      for J := I to High(ItemMetadata)-1 do ItemMetadata[J] := ItemMetadata[J+1];
      SetLength(ItemMetadata, Length(ItemMetadata)-1);
    end;
end;

procedure ResetLegacyBagMetadata(const Equipped: array of TClientItem);
var I, J: Integer; Keep: Boolean;
begin
  for I := High(ItemMetadata) downto 0 do begin
    Keep := False;
    for J := Low(Equipped) to High(Equipped) do
      if (Equipped[J].S.Name <> '') and
        (Equipped[J].MakeIndex = ItemMetadata[I].MakeIndex) then begin Keep := True; Break; end;
    if not Keep then ForgetLegacyItem(ItemMetadata[I].MakeIndex);
  end;
end;

function Range(Value: Word): Integer;
begin
  Result := Integer(Value and $FF) or (Integer(Value shr 8) shl 16);
end;
procedure ConvertStd(const Wire: TStdWire; var Item: TClientStdItem);
begin
  FillChar(Item, SizeOf(Item), 0);
  Item.Name := Wire.Name;
  Item.StdMode := Wire.StdMode;
  Item.Shape := Wire.Shape;
  Item.Weight := Wire.Weight;
  Item.AniCount := Wire.AniCount;
  Item.NeedIdentify := Wire.NeedIdentify;
  Item.Looks := Wire.Looks;
  Item.DuraMax := Wire.DuraMax;
  Item.AC := Range(Wire.AC);
  Item.MAC := Range(Wire.MAC);
  Item.DC := Range(Wire.DC);
  Item.MC := Range(Wire.MC);
  Item.SC := Range(Wire.SC);
  Item.Need := Wire.Need;
  Item.NeedLevel := Wire.NeedLevel;
  Item.Price := Wire.Price;
  Item.UniqueItem := Wire.UniqueItem;
  Item.Overlap := Wire.OverlapItem;
  Item.ItemType := Wire.ItemType;
  Item.ItemSet := Wire.ItemSet;
  // Server extension fields have no equivalent in this model. Never treat their bytes as evaluation data.
end;
function ValidStd(const Wire: TStdWire): Boolean;
begin
  Result := (Ord(Wire.Name[0]) <= 14) and (Ord(Wire.Reference[0]) <= 14);
end;

procedure ConvertItem(const Wire: TItemWire; var Item: TClientItem);
begin
  FillChar(Item, SizeOf(Item), 0);
  ConvertStd(Wire.Std, Item.S);
  Item.MakeIndex := Wire.MakeIndex;
  Item.Dura := Wire.Dura;
  Item.DuraMax := Wire.DuraMax;
end;

function DecodeLegacyUserState(const Body: AnsiString; var State: TUserStateInfo): Boolean;
var Wire: TUserStateWire; Decoded: TUserStateInfo; I: Integer;
begin
  Result := False;
  // Parse the entire packet before changing either the panel or its metadata.
  if (SizeOf(Wire) <> 1688) or (Length(Body) <> 2251) then Exit;
  FillChar(Wire, SizeOf(Wire), 0);
  DecodeBuffer(Body, @Wire, SizeOf(Wire));
  if (Ord(Wire.UserName[0]) > 14) or (Ord(Wire.GuildName[0]) > 20) or
    (Ord(Wire.GuildRankName[0]) > 14) or (Ord(Wire.LoverName[0]) > 14) then Exit;
  for I := 0 to 12 do if not ValidStd(Wire.Items[I].Std) then Exit;
  FillChar(Decoded, SizeOf(Decoded), 0);
  Decoded.Feature := Wire.Feature;
  Decoded.btGender := (Cardinal(Wire.Feature) shr 24) and 1;
  Decoded.UserName := Wire.UserName;
  Decoded.NameColor := Wire.NameColor;
  Decoded.GuildName := Wire.GuildName;
  Decoded.GuildRankName := Wire.GuildRankName;
  for I := 0 to 12 do ConvertItem(Wire.Items[I], Decoded.UseItems[I]);
  SetLength(ObservedMetadata, 0);
  for I := 0 to 12 do StoreMetadata(Wire.Items[I], ObservedMetadata);
  State := Decoded;
  Result := True;
end;

function LegacyItemExtraHint(const Item: TClientItem; Observed: Boolean = False): string;
var Cache: TItemMetadataArray; I: Integer; W: TStdWire;
  procedure Add(const LabelText: string; Value: Integer);
  begin
    if Value <> 0 then Result := Result + Format('<%s %d|C=clWhite>\', [LabelText, Value]);
  end;
begin
  Result := '';
  if not (Item.S.StdMode in [5, 6, 10, 11, 15, 19, 20, 21, 22, 23, 24, 26, 30]) then Exit;
  if Observed then Cache := ObservedMetadata else Cache := ItemMetadata;
  for I := 0 to High(Cache) do
    if (Cache[I].MakeIndex = Item.MakeIndex) and (Cache[I].Name = Item.S.Name) then begin
      W := Cache[I].Std;
      // These are real server fields, separate from the incompatible evaluation model.
      Add('攻击速度', W.AtkSpd); Add('准确', W.Accurate); Add('敏捷', W.Agility);
      Add('魔法躲避', W.MgAvoid); Add('强度', W.Strong); Add('神圣', W.Undead);
      Add('生命增加', W.HpAdd); Add('魔法增加', W.MpAdd);
      // Raw effect codes remain decoded metadata, never player-facing text.
      Exit;
    end;
end;

function DecodeLegacyStdItem(const Body: AnsiString; var Item: TClientStdItem): Boolean;
var Wire: TStdWire;
begin
  Result := False;
  FillChar(Item, SizeOf(Item), 0);
  if (SizeOf(Wire) <> 100) or (Length(Body) <> 134) then Exit;
  FillChar(Wire, SizeOf(Wire), 0);
  DecodeBuffer(Body, @Wire, SizeOf(Wire));
  if not ValidStd(Wire) then Exit;
  ConvertStd(Wire, Item);
  Result := True;
end;
function DecodeLegacyItem(const Body: AnsiString; var Item: TClientItem): Boolean;
var Wire: TItemWire;
begin
  Result := False;
  FillChar(Item, SizeOf(Item), 0);
  if (SizeOf(Wire) <> 124) or (Length(Body) <> 166) then Exit;
  FillChar(Wire, SizeOf(Wire), 0);
  DecodeBuffer(Body, @Wire, SizeOf(Wire));
  if not ValidStd(Wire.Std) then Exit;
  ConvertItem(Wire, Item);
  StoreMetadata(Wire, ItemMetadata);
  Result := True;
end;
function DecodeLegacyMagic(const Body: AnsiString; var Magic: TClientMagic): Boolean;
var Wire: TMagicWire; I: Integer;
begin
  Result := False;
  FillChar(Magic, SizeOf(Magic), 0);
  if (SizeOf(Wire) <> 84) or (Length(Body) <> 112) then Exit;
  FillChar(Wire, SizeOf(Wire), 0);
  DecodeBuffer(Body, @Wire, SizeOf(Wire));
  FillChar(Magic, SizeOf(Magic), 0);
  Magic.Key := Char(Wire.Key);
  Magic.Level := Wire.Level;
  Magic.CurTrain := Wire.CurTrain;
  Magic.Def.wMagicId := Wire.Def.MagicId;
  Magic.Def.sMagicName := Wire.Def.Name;
  Magic.Def.btEffectType := Wire.Def.EffectType;
  Magic.Def.btEffect := Wire.Def.Effect;
  Magic.Def.wSpell := Wire.Def.Spell;
  Magic.Def.wPower := Wire.Def.Power;
  for I := 0 to 3 do begin
    Magic.Def.TrainLevel[I] := Wire.Def.TrainLevel[I];
    Magic.Def.MaxTrain[I] := DWORD(Wire.Def.MaxTrain[I]);
  end;
  Magic.Def.btTrainLv := Wire.Def.TrainLv;
  Magic.Def.btJob := Wire.Def.Job;
  Magic.Def.dwDelayTime := DWORD(Wire.Def.DelayTime);
  Magic.Def.btDefSpell := Wire.Def.DefSpell;
  Magic.Def.btDefPower := Wire.Def.DefPower;
  Magic.Def.wMaxPower := Wire.Def.MaxPower;
  Magic.Def.btDefMaxPower := Wire.Def.DefMaxPower;
  Magic.Def.sDescr := Wire.Def.Description;
  Result := True;
end;
end.
