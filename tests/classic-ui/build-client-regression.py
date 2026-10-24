"""Compile the actual classic policy unit against frozen wire IDs in isolation."""
import argparse,re
from pathlib import Path
root=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
unit=root/'client/current-source/Source/MirClient/ClassicClientPolicy.pas'
s=unit.read_bytes().decode('gb18030');wire=(root/'client/current-source/Source/Common/Grobal2.pas').read_bytes().decode('gb18030')
names=set(re.findall(r'\b(?:CM_[A-Z0-9_]+|U_[A-Z0-9_]+)\b',s))|{'CM_TAKEONITEM','CM_QUERYBAGITEMS','CM_TURN','U_RIGHTHAND'}
rows={}
for name in names:
 m=re.search(r'^\s*'+name+r'\s*=\s*(\d+);',wire,re.M)
 if not m:raise RuntimeError('Missing wire constant '+name)
 rows[name]=int(m.group(1))
(a.out/'ClassicClientPolicy.pas').write_text(s,encoding='utf-8')
(a.out/'Grobal2.pas').write_text('unit Grobal2; interface\nconst\n'+''.join(f'{n}={v};\n' for n,v in sorted(rows.items()))+'implementation end.\n')
(a.out/'PolicyRegression.pas').write_text('''program PolicyRegression;
{$mode delphiunicode}
uses SysUtils, ClassicClientPolicy, Grobal2;
var I,N:Integer;
procedure Check(B:Boolean;const S:string);
begin if not B then raise Exception.Create(UTF8Encode(S));Inc(N);end;
begin
 N:=0;
 for I:=0 to 3 do Check(ClassicPageIndex(ClassicPage(I))=I,'page round trip');
 for I:=0 to 3 do begin
   Check(ClassicPageStep(ClassicPage(I),1)=ClassicPage((I+1) mod 4),'next character page');
   Check(ClassicPageStep(ClassicPage(I),-1)=ClassicPage((I+3) mod 4),'previous character page');
 end;
 Check(ClassicSkillsPerPage=5,'compact skill page size');
 Check(ClassicPageTitle(0)<>ClassicPageTitle(1),'distinct labels');
 Check(ClassicPage(-1)=0,'invalid page default');
 for I:=-1 to 17 do Check(ClassicEquipmentSlotAllowed(I)=((I>=0)and(I<=9)),'equipment boundary');
 Check(ClassicEquipmentSlotAllowed(U_RIGHTHAND),'medal/light retained');
 Check(ClassicEquipmentSlotAllowed(U_BUJUK),'talisman retained');
 Check(not ClassicCommandAllowed(CM_CANCELMISSION),'mission cancellation rejected');
 Check(not ClassicCommandAllowed(CM_BUYSHOPITEM),'shop rejected');
 Check(not ClassicCommandAllowed(CM_ADJUST_BONUS),'free points rejected');
 Check(not ClassicCommandAllowed(CM_QUERYHEROBAGITEMS),'hero bag rejected');
 Check(ClassicCommandAllowed(CM_TAKEONITEM),'normal equip retained');
 Check(ClassicCommandAllowed(CM_QUERYBAGITEMS),'normal bag retained');
 Check(ClassicCommandAllowed(CM_TURN),'normal movement retained');
 Writeln('TOTAL ',N,' PASS; actual classic policy unit');
end.
''')
