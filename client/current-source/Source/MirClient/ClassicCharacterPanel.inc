{ Classic character window: original source sprites, no replacement artwork. }
procedure TFrmDlg.ConfigureClassicCharacterPanel;
begin
  if (DStateWin.WLib <> g_WMainImages) or (DStateWin.FaceIndex <> 370) then begin
    DStateWin.SetImgIndex(g_WMainImages, 370);
    DStateWin.Left := SCREENWIDTH - 232;
    DStateWin.Top := 0;
    DStateWin.Width := 232;
    DStateWin.Height := 325;
    DCloseState.SetImgIndex(g_WMainImages, 371, 8, 39);
    DCloseState.OnDirectPaint := DPrevStateDirectPaint;
    DBState.SetImgIndex(g_WMainImages, 373, 0, 122);
    DBState.Width := 36; DBState.Height := 36;
    DBState.OnDirectPaint := DBStateDirectPaint;
    DBState.OnMouseUp := DBStateMouseUp;
    DBState2.SetImgIndex(g_WMainImages, 372, 0, 182);
    DBState2.Width := 36; DBState2.Height := 36;
    DBState2.OnDirectPaint := DBStateDirectPaint;
    DBState2.OnMouseUp := DBState2MouseUp;
    DSWNecklace.AdjustPos(168, 85, 34, 31);
    DSWLight.AdjustPos(168, 125, 34, 31);
    DSWArmRingR.AdjustPos(42, 174, 34, 31);
    DSWArmRingL.AdjustPos(168, 174, 34, 31);
    DSWRingR.AdjustPos(42, 211, 34, 31);
    DSWRingL.AdjustPos(168, 211, 34, 31);
    DSWHelmet.AdjustPos(115, 93, 18, 18);
    DSWWeapon.AdjustPos(47, 80, 47, 87);
    DSWDress.AdjustPos(96, 122, 53, 112);
    DSWDress.DisableTransparent := True;
    DSWWeapon.DisableTransparent := True;
    DSWHelmet.DisableTransparent := True;
    { Keep the existing separate talisman wire slot without a later extra row. }
    DSWBujuk.AdjustPos(42, 125, 34, 31);
    DItemGrid.OnMouseLeave := ClassicBagHintLeave;
    DStMag1.AdjustPos(44, 55, 31, 33);
    DStMag2.AdjustPos(44, 92, 31, 33);
    DStMag3.AdjustPos(44, 129, 31, 33);
    DStMag4.AdjustPos(44, 166, 31, 33);
    DStMag5.AdjustPos(44, 203, 31, 33);
    DStPageUp.SetImgIndex(g_WMainImages, 398, 213, 113);
    DStPageDown.SetImgIndex(g_WMainImages, 396, 213, 143);
    DStPageUp.OnDirectPaint := DMsgDlgOkDirectPaint;
    DStPageDown.OnDirectPaint := DMsgDlgOkDirectPaint;
    m_ClassicBagHint := 0;
  end;
  DBState.Visible := True;
  DBState2.Visible := True;
end;

procedure TFrmDlg.ClassicBagHintLeave(Sender: TObject);
begin
  m_ClassicBagHint := 0;
end;

procedure TFrmDlg.DrawClassicDockedItem(dsurface: TCustomCanvas; const Item: TClientItem; X, Y, MaxWidth: Integer);
var
  HintText, Plain, Part, Meta, Stats, Requirement, Line: string;
  I, Row: Integer;
  InTag, InStyle, RequirementMet: Boolean;
  procedure AppendStat(const Value: string);
  begin
    if Stats <> '' then Stats := Stats + ' ';
    Stats := Stats + Value;
  end;
  procedure DrawWrapped(const Value: string; LastRow: Integer; Color: Integer);
  var J: Integer; Candidate: string;
  begin
    Line := '';
    for J := 1 to Length(Value) do begin
      Candidate := Line + Value[J];
      if FontManager.Default.TextWidth(Candidate) > MaxWidth then begin
        if Row > LastRow then Exit;
        dsurface.TextOut(X, Y + Row * 12, Line, Color);
        Inc(Row); Line := Value[J];
      end else Line := Candidate;
    end;
    if (Line <> '') and (Row <= LastRow) then begin
      dsurface.TextOut(X, Y + Row * 12, Line, Color);
      Inc(Row);
    end;
  end;
begin
  if Item.S.Name = '' then Exit;
  GetMouseItemInfoHint(Item, HintText);
  Plain := ''; InTag := False; InStyle := False;
  for I := 1 to Length(HintText) do begin
    case HintText[I] of
      '<': begin InTag := True; InStyle := False; end;
      '>': begin InTag := False; InStyle := False; end;
      '|': if InTag then InStyle := True;
      #0: ;
    else
      if not InStyle then Plain := Plain + HintText[I];
    end;
  end;
  Meta := Item.S.Name; Stats := ''; Requirement := '';
    while Plain <> '' do begin
      Plain := GetValidStr3(Plain, Part, ['\']);
      Part := Trim(Part);
      if (Pos('重量 ', Part) = 1) or (Pos('持久 ', Part) = 1) then
        Meta := Meta + ' ' + StringReplace(Part, '持久 ', '持久力', [])
      else if Pos('需要', Part) = 1 then Requirement := Part
      else if (Pos('防御 ', Part) = 1) or (Pos('魔防 ', Part) = 1) or
        (Pos('攻击 ', Part) = 1) or (Pos('魔法 ', Part) = 1) or (Pos('道术 ', Part) = 1) or
        (Pos('准确 ', Part) = 1) or (Pos('敏捷 ', Part) = 1) or (Pos('幸运 ', Part) = 1) or
        (Pos('诅咒 ', Part) = 1) or (Pos('攻击速度 ', Part) = 1) or
        (Pos('强度 ', Part) = 1) or (Pos('神圣 ', Part) = 1) or
        (Pos('生命增加 ', Part) = 1) or (Pos('魔法增加 ', Part) = 1) or
        (Pos('魔法躲避 ', Part) = 1) then AppendStat(Part);
    end;
    Row := 0;
    DrawWrapped(Meta, 2, clWhite);
    dsurface.TextOut(X, Y, Item.S.Name, clYellow);
    DrawWrapped(Stats, 2, clWhite);
    RequirementMet := True;
    case Item.S.Need of
      0: RequirementMet := g_Myself.m_Abil.Level >= Item.S.NeedLevel;
      1: RequirementMet := HiWord(g_Myself.m_Abil.DC) >= Item.S.NeedLevel;
      2: RequirementMet := HiWord(g_Myself.m_Abil.MC) >= Item.S.NeedLevel;
      3: RequirementMet := HiWord(g_Myself.m_Abil.SC) >= Item.S.NeedLevel;
    end;
    if Requirement <> '' then begin
      if Row > 3 then Row := 3;
      if RequirementMet then DrawWrapped(Requirement, 3, clWhite)
      else DrawWrapped(Requirement, 3, clRed);
    end;
end;

procedure TFrmDlg.DrawClassicCharacterPanel(dsurface: TCustomCanvas);
var
  D: TCustomLockableTexture;
  X, Y, AX, AY, I, Slot, Row, Train: Integer;
  PM: PTClientMagic;
  Text, KeyText: string;
  function Hovered(Control: TDControl): Boolean;
  var CX, CY: Integer;
  begin
    CX := Control.SurfaceX(Control.Left);
    CY := Control.SurfaceY(Control.Top);
    Result := Control.Visible and (g_nMouseX >= CX) and (g_nMouseX < CX + Control.Width) and
      (g_nMouseY >= CY) and (g_nMouseY < CY + Control.Height);
  end;
  procedure DrawStateItem(Index: Integer);
  begin
    if g_UseItems[Index].S.Name = '' then Exit;
    D := frmMain.GetWStateImg(g_UseItems[Index].S.Looks, AX, AY);
    if D <> nil then dsurface.Draw(X + 31 + AX, Y + 94 + AY, D.ClientRect, D, True);
  end;
  procedure ValueAt(Value: LongWord; Offset: Integer);
  begin
    dsurface.TextOut(X + 110, Y + 98 + Offset,
      Format('%d-%d', [LoWord(Value), HiWord(Value)]), clWhite);
  end;
  procedure Fact(const LabelText, Value: string; ARow: Integer);
  begin
    dsurface.TextOut(X + 48, Y + 60 + ARow * 18, LabelText, clSilver);
    dsurface.TextOut(X + 112, Y + 60 + ARow * 18, Value, clWhite);
  end;
begin
  StatePage := ClassicPage(ClassicPageIndex(StatePage));
  X := DStateWin.SurfaceX(DStateWin.Left);
  Y := DStateWin.SurfaceY(DStateWin.Top);
  D := g_WMainImages.Images[370];
  if D = nil then Exit;
  dsurface.Draw(X, Y, D.ClientRect, D, True);
  if StatePage = 0 then begin
    D := g_WMainImages.Images[376 + Integer(g_Myself.m_btSex)];
    if D <> nil then dsurface.Draw(X + 38, Y + 50, D.ClientRect, D, False);
    D := g_WMainImages.GetCachedImage(440 + g_Myself.m_btHair div 2 + g_Myself.m_btSex, AX, AY);
    if D <> nil then dsurface.Draw(X + 31 + AX, Y + 94 + AY, D.ClientRect, D, True);
    DrawStateItem(U_DRESS);
    DrawStateItem(U_WEAPON);
    DrawStateItem(U_HELMET);
    Text := Trim(g_sGuildName + ' ' + g_sGuildRankName);
    if Text <> '' then dsurface.TextOut(X + 42, Y + 54, Text, clSilver);
    { Resolve every frame: sibling leave callbacks must not erase the new slot. }
    Slot := -1;
    if Hovered(DSWHelmet) then Slot := U_HELMET
    else if Hovered(DSWNecklace) then Slot := U_NECKLACE
    else if Hovered(DSWLight) then Slot := U_RIGHTHAND
    else if Hovered(DSWArmRingR) then Slot := U_ARMRINGR
    else if Hovered(DSWArmRingL) then Slot := U_ARMRINGL
    else if Hovered(DSWRingR) then Slot := U_RINGR
    else if Hovered(DSWRingL) then Slot := U_RINGL
    else if Hovered(DSWBujuk) and (g_UseItems[U_BUJUK].S.Name <> '') then Slot := U_BUJUK
    else if Hovered(DSWDress) then Slot := U_DRESS
    else if Hovered(DSWWeapon) then Slot := U_WEAPON;
    if ClassicEquipmentSlotAllowed(Slot) then
      DrawClassicDockedItem(dsurface, g_UseItems[Slot], X + 34, Y + 268, 176);
  end else if StatePage = ClassicStatusPage then begin
    ValueAt(g_Myself.m_Abil.AC, 0); ValueAt(g_Myself.m_Abil.MAC, 20);
    ValueAt(g_Myself.m_Abil.DC, 40); ValueAt(g_Myself.m_Abil.MC, 60);
    ValueAt(g_Myself.m_Abil.SC, 80);
    dsurface.TextOut(X + 110, Y + 198, Format('%d/%d', [g_Myself.m_Abil.HP, g_Myself.m_Abil.MaxHP]), clWhite);
    dsurface.TextOut(X + 110, Y + 218, Format('%d/%d', [g_Myself.m_Abil.MP, g_Myself.m_Abil.MaxMP]), clWhite);
  end else begin
    D := g_WMain3Images.Images[32];
    if D <> nil then begin
      { Crop the source background to the original 168x199 content area. }
      dsurface.Draw(X + 38, Y + 50, IntRect(0, 0, 168, 199), D, False);
    end;
    if StatePage = ClassicAttributePage then begin
      Fact('职业', IntToJob(g_Myself.m_btJob), 0);
      Fact('等级', IntToStr(g_Myself.m_Abil.Level), 1);
      Fact('当前经验', IntToStr(g_Myself.m_Abil.Exp), 2);
      Fact('升级经验', IntToStr(g_Myself.m_Abil.MaxExp), 3);
      Fact('背包重量', Format('%d/%d', [g_Myself.m_Abil.Weight, g_Myself.m_Abil.MaxWeight]), 4);
      Fact('穿戴重量', Format('%d/%d', [g_Myself.m_Abil.WearWeight, g_Myself.m_Abil.MaxWearWeight]), 5);
      Fact('腕力', Format('%d/%d', [g_Myself.m_Abil.HandWeight, g_Myself.m_Abil.MaxHandWeight]), 6);
      Fact('准确', IntToStr(g_nMyHitPoint), 7);
      Fact('敏捷', IntToStr(g_nMySpeedPoint), 8);
    end else if StatePage = ClassicSkillPage then begin
      m_nMagTop := MagicPage * ClassicSkillsPerPage;
      for I := m_nMagTop to _MIN(m_nMagTop + ClassicSkillsPerPage, g_MagicList.Count) - 1 do begin
        PM := PTClientMagic(g_MagicList[I]); Row := I - m_nMagTop;
        dsurface.TextOut(X + 82, Y + 56 + Row * 37, PM.Def.sMagicName, clSilver);
        Train := _MIN(14, PM.Level);
        Text := Format('%d级 ', [PM.Level]);
        if (PM.Level < PM.Def.btTrainLv) and (PM.Def.MaxTrain[Train] > 0) then
          Text := Text + Format('%d/%d', [PM.CurTrain, PM.Def.MaxTrain[Train]])
        else Text := Text + '已修炼';
        dsurface.TextOut(X + 82, Y + 71 + Row * 37, Text, clSilver);
        KeyText := '';
        if Byte(PM.Key) in [Byte('1')..Byte('8')] then KeyText := 'F' + Char(PM.Key)
        else if Byte(PM.Key) in [Byte('E')..Byte('L')] then KeyText := 'F' + IntToStr(Byte(PM.Key) - Byte('E') + 1);
        if KeyText <> '' then dsurface.TextOut(X + 184, Y + 56 + Row * 37, KeyText, clWhite);
      end;
      dsurface.TextOut(X + 80, Y + 272,
        Format('技能 %d/%d', [MagicPage + 1, _MAX(1, (g_MagicList.Count + ClassicSkillsPerPage - 1) div ClassicSkillsPerPage)]), clSilver);
    end;
  end;
  Text := g_Myself.m_sUserName;
  dsurface.TextOut(X + 122 - FontManager.Default.TextWidth(Text) div 2, Y + 17, Text, g_Myself.m_nNameColor);
end;
