from pathlib import Path
import json,urllib.request,urllib.parse,urllib.error,time,re,hashlib,html,sys
P=Path(__file__).resolve().parent;H=P.parent.parent/'catalog-h';O=P/'selected-current-education-plans';O.mkdir(exist_ok=True)
a=json.loads((P/'clock-held131-inventory.json').read_text());s=a['held']
keys=[r['key'] for r in s]
rows=json.loads((H/'hansung-unique-2026-2.json').read_text());rows={r['kwamokcode']+'-'+r['bunban']:r for r in rows}
base='https://info.hansung.ac.kr/jsp_21/student/kyomu/'
contact=re.compile(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|(?<!\d)(?:0\d{1,2}[-. ]?)?\d{3,4}[-. ]\d{4}(?!\d)')
def safe(value):
 t=html.unescape(str(value or ''));t=re.sub(r'<br\s*/?>','\n',t,flags=re.I);t=re.sub('<[^>]+>','',t);t=re.sub(r'https?://\S+','[접속링크 제외]',t);return contact.sub('[연락처 제외]',t).strip()
first=rows[keys[0]];page_url=base+'suupplan_main_view.jsp?code='+urllib.parse.quote(first['plan'].strip())
raw=urllib.request.urlopen(page_url,timeout=30).read();text=raw.decode('cp949')
assert 'suupplan_main_view_data.jsp' in text and 'yearhakgi' in text
(P/'normal-public-plan-route-evidence.json').write_text(json.dumps({'nativeCatalogURL':'https://info.hansung.ac.kr/jsp_21/student/kyomu/siganpyo_aui.jsp?viewMode=oc','catalogObservedPlanButton':'/jsp_21/student/kyomu/suupplan_main_view.jsp?code= published row plan locator','currentPlanHTMLSHA256':hashlib.sha256(raw).hexdigest(),'nativeViewDataPathObserved':'suupplan_main_view_data.jsp','semesterArgumentObserved':'yearhakgi','personalSessionUsed':False,'rawHTMLSaved':False},ensure_ascii=False,indent=2)+'\n')
results=[]
for i,key in enumerate(keys,1):
 target=O/f'{key}.json'
 if target.exists():results.append({'key':key,'status':'alreadySaved'});continue
 row=rows[key];time.sleep(.8)
 req=urllib.request.Request(base+'suupplan_main_view_data.jsp',urllib.parse.urlencode({'type':'view','yearhakgi':'20262','code':row['plan'].strip()}).encode(),headers={'Referer':base+'suupplan_main_view.jsp?code='+urllib.parse.quote(row['plan'].strip())})
 try:
  body=urllib.request.urlopen(req,timeout=35).read(8000001)
 except urllib.error.HTTPError as e:
  if e.code in (401,403,429):raise RuntimeError('Normal public access boundary reached; no retry or bypass') from None
  results.append({'key':key,'status':f'HTTP{e.code}'});continue
 assert len(body)<=8000000
 payload=json.loads(body.decode('cp949'));data=payload.get('data',[])
 if payload.get('insertYn')!='Y' or len(data)!=1:
  results.append({'key':key,'status':'currentNotPublished'});continue
 d=data[0]
 for f,v in [('data_year','2026'),('hakgi','2'),('kwamok',row['kwamokcode']),('bunban',row['bunban'])]:assert str(d.get(f,'')).strip()==v,(key,f)
 fields=['data_year','hakgi','kwamok','kwamokname','bunban','timeclassroom','daesang','sunsu','offlineyn','onlinetype','onoffhakjum','gita']
 educational={f:safe(d.get(f)) for f in fields}
 educational['weeks']=[{'week':j,'topicEducationLiteral':safe(d.get(f'j{j}juje')),'flipped':d.get(f'j{j}f')=='Y','plannedMakeup1':safe(d.get(f'j{j}bogang1')),'plannedMakeup2':safe(d.get(f'j{j}bogang2'))} for j in range(1,17) if j<=15 or d.get(f'j{j}juje')]
 result={'key':key,'checkedDate':'2026-10-09','sourceResponseSHA256':hashlib.sha256(body).hexdigest(),'normalPublishedRouteUsed':True,'privacyWhitelist':'current course identity, eligible target, prerequisites, actual educational operating notes and weekly educational topics only; contacts/links masked; other fields omitted','hiddenStaffOrStudentFieldsSaved':False,'education':educational}
 target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');results.append({'key':key,'status':'current2026-2Published','educationalReceiptSHA256':hashlib.sha256(target.read_bytes()).hexdigest()})
 if i%10==0:print('Reviewed normal public educational responses',i,'/',len(keys),flush=True)
(P/'selected-current-plan-read-receipt.json').write_text(json.dumps({'selectedActualUnreviewedKeys':keys,'normalPublicRequests':len(keys),'results':results,'wholeRecollection':False,'productChanged':False,'completionClaim':False},ensure_ascii=False,indent=2)+'\n')
print('Selected official education receipts',len(results),'/',len(keys),flush=True)
