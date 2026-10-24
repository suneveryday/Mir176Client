unit ClassicClientPolicy;

interface
uses Grobal2;
const
  ClassicExpansionUI = False;
  ClassicSkillsPerPage = 5;
{$IFDEF UI_0508}
  ClassicStatusPage = 1;
  ClassicAttributePage = 2;
  ClassicSkillPage = 3;
{$ELSE}
  ClassicStatusPage = 2;
  ClassicAttributePage = 3;
  ClassicSkillPage = 5;
{$ENDIF}
function ClassicPage(Index: Integer): Integer;
function ClassicPageStep(Page, Direction: Integer): Integer;
function ClassicPageIndex(Page: Integer): Integer;
function ClassicPageTitle(Index: Integer): string;
function ClassicEquipmentSlotAllowed(Slot: Integer): Boolean;
function ClassicCommandAllowed(Command: Integer): Boolean;
implementation
function ClassicPage(Index: Integer): Integer;
begin
  case Index of
    1: Result := ClassicStatusPage;
    2: Result := ClassicAttributePage;
    3: Result := ClassicSkillPage;
  else Result := 0;
  end;
end;
function ClassicPageStep(Page, Direction: Integer): Integer;
var I: Integer;
begin
  I := (ClassicPageIndex(Page) + Direction) mod 4;
  if I < 0 then Inc(I, 4);
  Result := ClassicPage(I);
end;
function ClassicPageIndex(Page: Integer): Integer;
begin
  if Page = ClassicStatusPage then Result := 1
  else if Page = ClassicAttributePage then Result := 2
  else if Page = ClassicSkillPage then Result := 3
  else Result := 0;
end;
function ClassicPageTitle(Index: Integer): string;
begin
  case Index of
    1: Result := '状态';
    2: Result := '属性';
    3: Result := '技能';
  else Result := '装备';
  end;
end;
function ClassicEquipmentSlotAllowed(Slot: Integer): Boolean;
begin
  // Keep the legacy wire array, including the right-hand medal/light slot.
  Result := (Slot >= U_DRESS) and (Slot <= U_BUJUK);
end;
function ClassicCommandAllowed(Command: Integer): Boolean;
begin
  case Command of
    CM_CANCELMISSION, CM_ADJUST_BONUS, CM_GETSHOPITEM, CM_BUYSHOPITEM, CM_SHOPPRESEND,
    CM_RECALLHERO, CM_UNRECALLHERO, CM_SETSERIESSKILL, CM_FIRESERIESSKILL,
    CM_BREAKPOINT, CM_QUERYHEROBAGITEMS, CM_HEROCHANGING,
    CM_PLAYERADDITEMTOHERO, CM_HEROADDITEMTOPLAYER, CM_HEROTAKEONITEM,
    CM_HEROTAKEOFFITEM, CM_HEROEAT, CM_HEROSETTARGET, CM_HERODROPITEM,
    CM_HERORECALLSLAVE, CM_HERORJOINTATTACK, CM_HEROMAGICKEYCHANGE:
      Result := False;
  else Result := True;
  end;
end;
end.
