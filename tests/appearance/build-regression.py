#!/usr/bin/env python3
"""Compile the actual client routing methods with texture-recording test doubles."""
from pathlib import Path
import argparse,re

root=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--source',type=Path,default=root/'client/current-source/Source/MirClient/ClMain.pas')
parser.add_argument('--out',type=Path,required=True)
args=parser.parse_args()
source=args.source.read_text(encoding='gb18030')
weapon=re.search(r'(?ms)^function TfrmMain.GetWWeaponImg.*?(?=^function TfrmMain.GetWHumImg)',source).group(0)
dress=re.search(r'(?ms)^function TfrmMain.GetWHumImg.*?(?=^procedure TfrmMain.ClientGetPasswordStatus)',source).group(0)
header=r'''program AppearanceRegression;
{$mode delphi}
uses SysUtils, Classes;
const HUMANFRAME=600;
type
  TCustomLockableTexture=TObject;
  TWMImages=class
    Name:string;
    Appr:Integer;
    constructor Create(const AName:string);
    procedure Initialize;
    function GetCachedImage(Index:Integer;var X,Y:Integer):TCustomLockableTexture;
  end;
  TfrmMain=class
    function GetWWeaponImg(Weapon, m_btSex, nFrame: Integer;var ax, ay: Integer; boUseCboLib:Boolean):TCustomLockableTexture;
    function GetWHumImg(Dress, m_btSex, nFrame: Integer;var ax, ay: Integer; boUseCboLib:Boolean):TCustomLockableTexture;
  end;
var
  g_gcGeneral:array[0..16]of Boolean;
  g_WWeaponImages,g_WWeapon2Images,g_WWeapon3Images,g_cboweapon,g_cboweapon3:TWMImages;
  g_WHumImgImages,g_WHum2ImgImages,g_WHum3ImgImages,g_cbohum,g_cbohum3:TWMImages;
  g_GameDevice:Pointer;
  WeaponImageDir,HumImageDir,LastLibrary:string;
  LastIndex,Checks:Integer;
  WeaponImageList,HumImageList:TList;
  Form:TfrmMain;
constructor TWMImages.Create(const AName:string);
begin inherited Create;Name:=AName;end;
procedure TWMImages.Initialize;begin end;
function TWMImages.GetCachedImage(Index:Integer;var X,Y:Integer):TCustomLockableTexture;
begin LastLibrary:=Name;LastIndex:=Index;X:=0;Y:=0;Result:=Self;end;
function CreateImages(const Name:string;Device:Pointer):TWMImages;
begin Result:=TWMImages.Create(Name);end;
'''
tests=r'''
procedure Check(Value:Boolean;const LabelText:string);
begin if not Value then begin WriteLn('FAIL ',LabelText);Halt(1);end;Inc(Checks);end;
procedure Route(Armor:Boolean;Feature,Sex,Frame:Integer;Combo:Boolean;const LibraryName:string;Base:Integer);
var X,Y:Integer;Texture:TCustomLockableTexture;
begin
  LastLibrary:='';LastIndex:=-1;
  if Armor then Texture:=Form.GetWHumImg(Feature,Sex,Frame,X,Y,Combo)
  else Texture:=Form.GetWWeaponImg(Feature,Sex,Frame,X,Y,Combo);
  Check((Texture<>nil)and(LastLibrary=LibraryName)and(LastIndex=Base+Frame),
    Format('appearance route armor=%s feature=%d sex=%d frame=%d filter=%s combo=%s',
    [BoolToStr(Armor,True),Feature,Sex,Frame,BoolToStr(g_gcGeneral[7],True),BoolToStr(Combo,True)]));
end;
var Enabled:Boolean;Frame,X,Y:Integer;Texture:TCustomLockableTexture;
begin
  Form:=TfrmMain.Create;WeaponImageList:=TList.Create;HumImageList:=TList.Create;
  WeaponImageDir:='fixture/weapon/';HumImageDir:='fixture/hum/';
  g_WWeaponImages:=TWMImages.Create('Weapon');g_WWeapon2Images:=TWMImages.Create('Weapon2');g_WWeapon3Images:=TWMImages.Create('Weapon3');
  g_cboweapon:=TWMImages.Create('CboWeapon');g_cboweapon3:=TWMImages.Create('CboWeapon3');
  g_WHumImgImages:=TWMImages.Create('Hum');g_WHum2ImgImages:=TWMImages.Create('Hum2');g_WHum3ImgImages:=TWMImages.Create('Hum3');
  g_cbohum:=TWMImages.Create('CboHum');g_cbohum3:=TWMImages.Create('CboHum3');
  for Enabled:=False to True do begin
    g_gcGeneral[7]:=Enabled;
    // Explicit expected boundaries and reported extended shapes; no copied routing implementation.
    for Frame in [0,56,64,128,200,392,536]do begin
      Route(True,0,0,Frame,False,'Hum',0);Route(True,1,1,Frame,False,'Hum',600);
      Route(True,48,0,Frame,False,'Hum',28800);Route(True,49,1,Frame,False,'Hum',29400);
      Route(True,50,0,Frame,False,'Hum2',0);Route(True,51,1,Frame,False,'Hum2',600);
      Route(True,98,0,Frame,False,'Hum2',28800);Route(True,99,1,Frame,False,'Hum2',29400);
      Route(True,100,0,Frame,False,'Hum3',0);Route(True,101,1,Frame,False,'Hum3',600);
      Route(True,114,0,Frame,False,'Hum3',8400);Route(True,115,1,Frame,False,'Hum3',9000);
      Route(True,148,0,Frame,False,'Hum3',28800);Route(True,149,1,Frame,False,'Hum3',29400);
      Route(True,150,0,Frame,False,'fixture/hum/75.data',0);Route(True,151,1,Frame,False,'fixture/hum/75.data',600);
      Route(False,2,0,Frame,False,'Weapon',1200);Route(False,3,1,Frame,False,'Weapon',1800);
      Route(False,98,0,Frame,False,'Weapon',58800);Route(False,99,1,Frame,False,'Weapon',59400);
      Route(False,100,0,Frame,False,'Weapon2',0);Route(False,101,1,Frame,False,'Weapon2',600);
      Route(False,148,0,Frame,False,'Weapon2',28800);Route(False,149,1,Frame,False,'Weapon2',29400);
      Route(False,150,0,Frame,False,'Weapon3',0);Route(False,151,1,Frame,False,'Weapon3',600);
      Route(False,190,0,Frame,False,'Weapon3',24000);Route(False,191,1,Frame,False,'Weapon3',24600);
      Route(False,198,0,Frame,False,'Weapon3',28800);Route(False,199,1,Frame,False,'Weapon3',29400);
      Route(False,200,0,Frame,False,'fixture/weapon/100.data',0);Route(False,201,1,Frame,False,'fixture/weapon/100.data',600);
    end;
    Route(True,50,0,64,True,'CboHum',48000);Route(True,51,1,64,True,'CboHum',50000);
    Route(True,114,0,200,True,'CboHum3',28000);Route(True,115,1,200,True,'CboHum3',30000);
    Route(False,100,0,64,True,'CboWeapon',152000);Route(False,101,1,64,True,'CboWeapon',154000);
    Route(False,190,0,200,True,'CboWeapon3',80000);Route(False,191,1,200,True,'CboWeapon3',82000);
  end;
  Check((HumImageList.Count=1)and(WeaponImageList.Count=1),'external library cache reused across sex and filter changes');
  g_WHum3ImgImages:=nil;Texture:=Form.GetWHumImg(114,0,0,X,Y,False);Check(Texture=nil,'missing extended armor library returns no texture safely');
  g_WWeapon3Images:=nil;Texture:=Form.GetWWeaponImg(190,0,0,X,Y,False);Check(Texture=nil,'missing extended weapon library returns no texture safely');
  WriteLn('TOTAL ',Checks,' PASS actual production Pascal routing; no game session');
end.
'''
# Pascal set iterators accept byte values only; use a small constant array for frame IDs.
tests=tests.replace('var Enabled:Boolean;Frame,X,Y:Integer;',
    'const Frames:array[0..6]of Integer=(0,56,64,128,200,392,536);\nvar Enabled:Boolean;Frame,X,Y:Integer;')
tests=tests.replace('for Frame in [0,56,64,128,200,392,536]do','for Frame in Frames do')
args.out.parent.mkdir(parents=True,exist_ok=True)
args.out.write_text(header+weapon+'\n'+dress+'\n'+tests)
print('Prepared regression from actual client appearance methods')
