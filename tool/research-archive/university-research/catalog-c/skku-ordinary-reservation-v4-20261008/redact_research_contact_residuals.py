"""Redact confirmed non-educational contact/query fields; preserve native education."""
import hashlib,json,re
from pathlib import Path
P=Path(__file__).resolve().parent
SHORT=re.compile(r'(?<![A-Za-z0-9])\d{3,4}-\d{4}(?![A-Za-z0-9])')
OBFUSCATED=re.compile(r'\b[\w.+-]+\s*\[at\]\s*[\w.-]+\s*\[dot\]\s*[\w.-]+',re.I)
URL=re.compile(r'https?://[^\s<>"\u3000]+',re.I)
QUERY_PRIVATE=re.compile(r'(?:Signature|Key-Pair-Id|access_token|auth_token|sessionid|JSESSIONID|token)=',re.I)
def all_strings(x):
 if isinstance(x,str):yield x
 elif isinstance(x,list):
  for v in x:yield from all_strings(v)
 elif isinstance(x,dict):
  for v in x.values():yield from all_strings(v)
def main():
 current=json.loads((P/'current-flipped-educational-operation-recheck.json').read_text())
 assert len(current['records'])==215 and not current['stopped']
 confirmed=set()
 contact_rows={'PSY2003-01','KID3096-01'}
 for row in current['records']:
  if row['offeringCode'] not in contact_rows:continue
  for t in all_strings(row.get('attachments',[])):
   for m in SHORT.finditer(t):
    if re.search(r'contact|phone|tel|연락처|전화|office|Fax|☎',t[max(0,m.start()-180):m.start()],re.I):confirmed.add(m.group())
 # Repeated execution is safe after confirmed tokens were already removed.
 records=[]
 for f in P.glob('*.json'):
  if 'audit' in f.name or f.name=='privacy-residual-redaction-audit.json':continue
  before=f.read_bytes();x=json.loads(before);counts={'confirmedShortContact':0,'obfuscatedEmail':0,'signedOrSessionQuery':0}
  def clean(v):
   if isinstance(v,str):
    for token in confirmed:
     counts['confirmedShortContact']+=v.count(token);v=v.replace(token,'[비공개 정보 제거]')
    v=re.sub(r'^\d{4}(?= Fax:)', '[비공개 정보 제거]',v)
    counts['obfuscatedEmail']+=len(OBFUSCATED.findall(v));v=OBFUSCATED.sub('[비공개 정보 제거]',v)
    def url(m):
     value=m.group()
     if '?' in value and QUERY_PRIVATE.search(value):
      counts['signedOrSessionQuery']+=1;return value.split('?',1)[0]+'?[비공개 매개변수 제거]'
     return value
    return URL.sub(url,v)
   if isinstance(v,list):return [clean(i) for i in v]
   if isinstance(v,dict):return {k:clean(i) for k,i in v.items()}
   return v
  y=clean(x)
  if any(counts.values()):
   # All original native identity/time/room and public detail fields unchanged.
   a=x.get('records',[]);b=y.get('records',[])
   for old,new in zip(a,b):
    if 'sourceRow' in old:assert old['sourceRow']==new['sourceRow']
    if 'detail' in old:assert old['detail']==new['detail']
    for key in ('offeringCode','sourceSchedule','campus','courseName'):assert old.get(key)==new.get(key)
   f.write_text(json.dumps(y,ensure_ascii=False,indent=2)+'\n')
  after=f.read_bytes();records.append({'path':f.name,'beforeSha256':hashlib.sha256(before).hexdigest(),'afterSha256':hashlib.sha256(after).hexdigest(),'redactedTokenOccurrences':counts,'nativeIdentityClockRoomUnchanged':True})
 (P/'privacy-residual-redaction-audit-v2.json').write_text(json.dumps({'researchOnly':True,'noContactValuesPersisted':True,'confirmedShortContactSemanticSource':'PSY2003-01 actual Office(contact) and KID3096-01 actual phone/fax header; bibliographic ranges preserved; prior STA2010-01 audit retained','records':records},ensure_ascii=False,indent=2)+'\n')
 print('Redacted research residuals without emitting any contact/query values:',[(r['path'],r['redactedTokenOccurrences']) for r in records if r['beforeSha256']!=r['afterSha256']])
if __name__=='__main__':main()
