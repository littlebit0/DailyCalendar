"""Audit current CNU education-only research candidates without printing source fields."""
import json,re,hashlib,sys
from pathlib import Path
R=Path(__file__).resolve().parent
candidate=sys.argv[1];audit_name=sys.argv[2]
files=['cnu-daedeok-2026-2.whole-checkpoint-next-eleven-mode-v2.json',candidate];findings=[];rows=0
private_key=re.compile(r'STAFF_NO|PHONE|EMAIL|PASSWORD|TOKEN|FRAMEWORK|SESSION|MNG_NO|ACCESS_ID',re.I)
contact=re.compile(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|(?<!\d)0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)|(?<!\d)\d{3}[- ]\d{4}(?!\d)')
def walk(v,p):
 if isinstance(v,dict):
  for k,x in v.items():
   if private_key.search(k):findings.append(p+':private-key')
   walk(x,p+':'+k)
 elif isinstance(v,list):
  for i,x in enumerate(v):walk(x,p+f'[{i}]')
 elif isinstance(v,str):
  if contact.search(v):findings.append(p+':contact')
  if re.search(r'https?://',v) and not p.endswith(':sourceUrl'):findings.append(p+':access-or-extra-url')
for name in files:
 value=json.loads((R/name).read_text());walk(value,name);rows+=len(value['courses'])
assert rows==3888 and not findings,{'rows':rows,'findingPaths':findings}
hashes={name:hashlib.sha256((R/name).read_bytes()).hexdigest() for name in files}
(R/audit_name).write_text(json.dumps({'wholeRows':rows,'educationOnlyPrivacyFindings':findings,'hashes':hashes,'publicTeacherNamesRetained':True},indent=2)+'\n');print('whole3888 privacy findings0')
