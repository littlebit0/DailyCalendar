"""Minimize public educational cache: omit connection IDs/passwords, retain methods."""
import json,re
from pathlib import Path
R=Path(__file__).resolve().parent
ACCESS=re.compile(r'(?:zoom\s*(?:주소|접속\s*주소)|담당\s*교수\s*(?:ID|아이디)|회의\s*(?:ID|아이디|암호|비밀번호)|meeting\s*(?:id|passcode|password)|(?:접속|입장)\s*(?:코드|암호|비밀번호))',re.I)
ID=re.compile(r'(?<!\d)\d{3}\s+\d{4}\s+\d{4}(?!\d)')
def minimize(v):
 if not isinstance(v,str):return v,0
 lines=[];n=0
 for line in v.splitlines():
  if ACCESS.search(line) or ID.search(line) or re.search(r'^\s*[-*]?\s*(?:암호|비밀번호|password|passcode)\s*[:：]',line,re.I):n+=1;continue
  # URL stripping may leave the final two groups of a Zoom meeting ID.
  if re.search(r'\[link removed\]\s*\d{3,4}\s+\d{4}(?!\d)',line):n+=1;continue
  line,shortphones=re.subn(r'(?<!\d)\d{3}[- ]\d{4}(?!\d)','[contact removed]',line)
  n+=shortphones
  lines.append(line)
 return '\n'.join(lines).strip(),n
changed=[];n=0
for f in (R/'cnu-current-education').glob('*.json'):
 j=json.loads(f.read_text());local=0
 for section in ('header','weeks'):
  for row in j.get(section,[]):
   for k,v in row.items():row[k],count=minimize(v);local+=count
 if local:
  t=f.with_suffix('.json.privacy-tmp');t.write_text(json.dumps(j,ensure_ascii=False,indent=2));t.replace(f)
  changed.append({'courseId':j['courseId'],'accessLineOrShortPhoneRedactions':local});n+=local
out={'changedCoursesThisSweep':changed,'accessLineOrShortPhoneRedactionsThisSweep':n,'collectionStillInProgress':False,'sourceResponseHashRetained':True,'noWholePrivacyCompletionClaim':True}
p=R/'cnu-access-minimization-audit.json'
if p.exists():
 old=json.loads(p.read_text());out['priorRedactions']=old.get('priorRedactions',old.get('priorOmittedAccessLines',0))+old.get('accessLineOrShortPhoneRedactionsThisSweep',old.get('omittedAccessLinesThisSweep',0))
p.write_text(json.dumps(out,ensure_ascii=False,indent=2));print('courses',len(changed),'access/short-phone redactions',n)
