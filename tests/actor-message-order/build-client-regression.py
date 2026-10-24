#!/usr/bin/env python3
"""Compile actual PC hide/recreate routing with minimal scene/actor doubles."""
from pathlib import Path
import argparse
import re

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--out', type=Path, required=True)
args = parser.parse_args()
source = (root / 'client/current-source/Source/MirClient/PlayScn.pas').read_text(encoding='gb18030')
method = source[source.index('procedure TPlayScene.SendMsg('):]
start = method.index('    SM_HIDE: begin')
end = method.index('      case ident of', start)
routing = method[start:end]
constants = (root / 'client/current-source/Source/Common/Grobal2.pas').read_text(encoding='gb18030')
names = sorted(set(re.findall(r'\bSM_[A-Z0-9_]+\b', routing)))
definitions = []
for name in names:
    match = re.search(r'\b' + name + r'\s*=\s*(\d+)\s*;', constants)
    if not match:
        raise ValueError('Unresolved wire constant: ' + name)
    definitions.append(f'  {name} = {match.group(1)};')

header = r'''program ClientActorOrderRegression;
{$mode delphi}
uses Classes, SysUtils;
const
__CONSTANTS__
type
  TActor = class
    m_boDelActionAfterFinished, m_boDeath, m_boSkeleton, m_boItemExplore: Boolean;
    m_nWaitForRecogId, m_nChrLight, m_nIPowerLvl, m_nRecogId: Integer;
    m_HeroObject: TActor;
  end;
  TPlayScene = class
    Actors: TList;
    constructor Create;
    function FindActor(Id: Integer): TActor;
    function NewActor(Id, X, Y, Dir, Feature, State: Integer): TActor;
    function DeleteActor(Id: Integer; Death: Boolean = False): TActor;
    procedure SendMsg(ident, chrid, X, Y, cdir, Feature, State: Integer; Str: string; IPInfo: Integer);
  end;
var
  g_MySelf: TActor;
  Scene: TPlayScene;
function LoByte(Value: Integer): Byte; begin Result := Value and $FF; end;
function HiByte(Value: Integer): Byte; begin Result := (Value shr 8) and $FF; end;
function HiWord(Value: Integer): Word; begin Result := (Value shr 16) and $FFFF; end;
function IsMySlaveObject(Actor: TActor): Boolean; begin Result := False; end;
constructor TPlayScene.Create; begin inherited; Actors := TList.Create; end;
function TPlayScene.FindActor(Id: Integer): TActor;
var i: Integer;
begin
  Result := nil;
  for i := 0 to Actors.Count - 1 do
    if TActor(Actors[i]).m_nRecogId = Id then begin Result := Actors[i]; Exit; end;
end;
function TPlayScene.NewActor(Id, X, Y, Dir, Feature, State: Integer): TActor;
begin
  Result := FindActor(Id);
  if Result <> nil then Exit;
  Result := TActor.Create; Result.m_nRecogId := Id; Actors.Add(Result);
end;
function TPlayScene.DeleteActor(Id: Integer; Death: Boolean): TActor;
begin
  Result := FindActor(Id);
  if Result <> nil then begin Actors.Remove(Result); Result.Free; Result := nil; end;
end;
procedure TPlayScene.SendMsg(ident, chrid, X, Y, cdir, Feature, State: Integer; Str: string; IPInfo: Integer);
var Actor: TActor;
begin
  case ident of
'''.replace('__CONSTANTS__', '\n'.join(definitions))
tail = r'''
    // Animation and drawing follow this point in production. This test checks
    // whether the real routing has already recreated the removed actor.
    end;
  end;
end;
procedure Check(Condition: Boolean; const Description: string);
begin
  if not Condition then begin WriteLn('FAIL ', Description); Halt(1); end;
  WriteLn('PASS ', Description);
end;
begin
  Scene := TPlayScene.Create; g_MySelf := TActor.Create;
  Scene.NewActor(42, 10, 10, 2, 0, 0);
  Scene.SendMsg(SM_HIDE, 42, 0, 0, 0, 0, 0, '', 0);
  Scene.SendMsg(SM_BACKSTEP, 42, 10, 10, 2, 0, 0, '', 0);
  Check(Scene.FindActor(42) <> nil, 'old server order recreates a removed monster');
  Scene.SendMsg(SM_BACKSTEP, 42, 10, 10, 2, 0, 0, '', 0);
  Scene.SendMsg(SM_HIDE, 42, 0, 0, 0, 0, 0, '', 0);
  Check(Scene.FindActor(42) = nil, 'correct server order leaves no stale monster');
  WriteLn('TOTAL 2 PASS actual production PC hide/recreate routing; no game session');
end.
'''
args.out.parent.mkdir(parents=True, exist_ok=True)
args.out.write_text(header + routing + tail)
print('Prepared actual PC hide/recreate routing regression')
