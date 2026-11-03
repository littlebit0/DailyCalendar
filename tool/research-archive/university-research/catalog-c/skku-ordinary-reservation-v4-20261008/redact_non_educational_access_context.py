"""Remove concrete public-plan contact/access context, retaining native education."""
import json,re,hashlib
from pathlib import Path
P=Path(__file__).resolve().parent
patterns={
 'courseChatLink':re.compile(r'https?://open\.kakao\.com/[^\s<>"\u3000)]+',re.I),
 'publishedChatPassword':re.compile(r'(비밀번호\s*[:：]?\s*)([A-Za-z0-9_-]+)',re.I),
 'appointmentLink':re.compile(r'https?://bit\.ly/meet[^\s<>"\u3000)]+',re.I),
}
audit={'researchOnly':True,'completionClaim':False,'nativeIdentityDateClockRoomMutation':False,'files':[]}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def scan(obj,path='$',hits=None,mutate=False):
 if hits is None:hits=[]
 if isinstance(obj,str):
  for kind,pat in patterns.items():
   count=len(pat.findall(obj))
   if count:hits.append({'path':path,'kind':kind,'count':count})
   if mutate:obj=pat.sub((lambda m:m.group(1)+'[접속정보 제거]') if kind=='publishedChatPassword' else '[비교육 연락 경로 제거]',obj)
  return obj
 if isinstance(obj,list):return [scan(v,f'{path}[{i}]',hits,mutate) for i,v in enumerate(obj)]
 if isinstance(obj,dict):return {k:scan(v,f'{path}.{k}',hits,mutate) for k,v in obj.items()}
 return obj
for name in ['flipped-remaining-pool-classification.json','current-flipped-educational-operation-recheck.json','attached-semantic-review-checkpoint.json','incomplete-educational-enrichment-recheck.json']:
 p=P/name
 if not p.exists():continue
 before=sha(p);obj=json.loads(p.read_text());hits=[];redacted=scan(obj,hits=hits,mutate=True)
 if hits:p.write_text(json.dumps(redacted,ensure_ascii=False,indent=2)+'\n')
 audit['files'].append({'path':str(p),'sha256Before':before,'sha256After':sha(p),'hits':hits,'totalRemoved':sum(h['count'] for h in hits)})
# Frozen candidate is read only: concrete access/contact matches never printed.
v3=P.parent/'skku-ordinary-reservation-v3-20261008'
audit['frozenV3ReadOnlyAudit']=[]
for p in v3.glob('skku-*.json'):
 hits=[];scan(json.loads(p.read_text()),hits=hits)
 audit['frozenV3ReadOnlyAudit'].append({'path':str(p),'sha256':sha(p),'hits':hits,'total':sum(h['count'] for h in hits)})
(P/'privacy-non-educational-access-redaction-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print({'v4Removed':sum(f['totalRemoved'] for f in audit['files']),'v3ConcreteResidualCount':sum(f['total'] for f in audit['frozenV3ReadOnlyAudit'])})
