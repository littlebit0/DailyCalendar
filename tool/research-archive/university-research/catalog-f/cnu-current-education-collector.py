# -*- coding: utf-8 -*-
"""Normal public CNU outlink; only educational fields persisted. No raw replies."""
import base64, hashlib, html, http.cookiejar, json, re, time, urllib.error, urllib.request, uuid
from pathlib import Path
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.padding import PKCS7
R=Path(__file__).resolve().parent
OUT=R/'cnu-current-education';OUT.mkdir(exist_ok=True)
CAT_FIELDS=['CPTN_DIV_CD','CPTN_DIV_CD_FNM','TLSN_REST_INFO_CD_NM','OPEN_SBJT_NO','COURSE_NO','CLOSE_YN','CNCL_LT_YN','CNCL_LT_DT','LSN_TM_CD','CURI_CORS_YR','SBJT_NM','TRGT_SHYR','PNT_TMCNT','CULT_FLD_CD_NM','OPEN_YR','CURI_CPTN_DIV_NM','GENRL_LT_PDOC_TYPE_CD','LSN_METHOD_CD_NM','LSN_TYPE_CD_NM','OPEN_SUST_MJ_CD_NM','OPEN_DCLSS','OBJ_CORS_CD_NM','ABEEK_CPTN_DIV_CD_NM','TMTBL_INFO','TCHR_FLD_CD_NM','TCHR_FLD_CD_NM2','CYBER_LT_TYPE_CD_NM','ENG_SBJT_NM','ABEEK_TMCNT','OPEN_ORGN_CLSF_CD','OPEN_SHTM_CD','TLSN_ANNM']
PLAN_FIELDS=['LSN_OPER_CONTACT_YN','LSN_OPER_UNTACT_YN','LSN_OPER_MTHD','LSN_OPER_MTHD_UNTACT','TEACHING_TYPE_NM','CONC_SBJT','TLSN_ANNM','LSN_RULE','ATTEND_RULE','PRE_LRN_CN','LSN_SMRY','SBJT_SMRY','REF_CTNT','LSN_MTHD_ETC','LSN_MTHD_SCENE','LSN_MTHD_PRAC','LSN_MTHD_LT','LSN_MTHD_FLIP','LSN_MTHD_DISC','LSN_MTHD_PROJECT','LSN_MTHD_PROBLEM','LSN_MTHD_INDIV_TEAM','CPTN_DIV_CD_NM','CORE_CULT_FLD_CD_NM','TRGT_SHYR','PNT_TMCNT','OPEN_SHTM_CD_NM']
WEEK_FIELDS=['WKORD','MAJ_LRN_CTNT','ETC_CTNT','PRJT','CLS_METHOD_FIELD','CLS_METHOD_ETC','CLS_METHOD_LECT','CLS_METHOD_FLIP','CLS_METHOD_DISC','CLS_METHOD_PROJ','CLS_METHOD_PRES','CLS_METHOD_PBL','CLS_METHOD_LAB']
ARGS=['OPEN_YR','OPEN_SHTM_CD','OPEN_ORGN_CLSF_CD','OPEN_SUST_MJ_CD','OPEN_SBJT_NO','OPEN_DCLSS','GENRL_LT_PDOC_TYPE_CD','LT_STAFF_NO']
class GuardStop(Exception):pass
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
last=0
redactions={'contactLines':0,'urls':0,'accessLines':0}
def clean(v):
 if not isinstance(v,str):return v
 v=re.sub(r'<(?:br\s*/?|/p|/div|/li)>','\n',v,flags=re.I)
 v=html.unescape(re.sub('<[^>]*>',' ',v)); out=[]
 for line in v.splitlines():
  if re.search(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|(?<!\d)(?:\+82[- ]?)?0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)',line):
   redactions['contactLines']+=1
   line=re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|(?<!\d)(?:\+82[- ]?)?0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)','[contact removed]',line)
  if re.search(r'^\s*[-*]?\s*(?:암호|비밀번호|password|passcode)\s*[:：]',line,re.I) or re.search(r'zoom\s*(?:주소|접속\s*주소)|담당\s*교수\s*(?:ID|아이디)|회의\s*(?:ID|아이디|암호|비밀번호)|meeting\s*(?:id|passcode|password)|(?:접속|입장)\s*(?:코드|암호|비밀번호)|(?<!\d)\d{3}\s+\d{4}\s+\d{4}(?!\d)',line,re.I):
   redactions['accessLines']+=1;continue
  line,n=re.subn(r'https?://[^\s<>]+|www\.[^\s<>]+','[link removed]',line);redactions['urls']+=n;out.append(line)
 return '\n'.join(out).strip()
def atomic(path,obj):
 t=path.with_suffix(path.suffix+'.tmp');t.write_text(json.dumps(obj,ensure_ascii=False,indent=2));t.replace(path)
def request(url,data=None,content=None):
 global last
 for attempt in range(3):
  time.sleep(max(0,.8-(time.monotonic()-last)))
  try:
   h={'User-Agent':'Mozilla/5.0','Referer':'https://cnuit.cnu.ac.kr/checkMenu.jsp?p0=M69r16057e79Y231'}
   if content:h['Content-Type']=content
   with op.open(urllib.request.Request(url,data=data,headers=h),timeout=20) as q:b=q.read()
   last=time.monotonic()
   low=b.lower()
   if any(x in low for x in (b'web firewall',b'web application firewall',b'access denied',b'request rejected',b'blocked by security',b'\xeb\xb0\xa9\xed\x99\x94\xeb\xb2\xbd')):raise GuardStop('public route guard')
   return b
  except urllib.error.HTTPError as e:
   last=time.monotonic()
   if e.code in (401,403,429):raise GuardStop('HTTP '+str(e.code))
   if attempt==2:raise
  except (urllib.error.URLError,TimeoutError,OSError):
   last=time.monotonic()
   if attempt==2:raise
  time.sleep((1,3)[attempt])
def enc(v,k):
 if v is None or v=='':return v
 key=k.replace('-','')[:16].encode();p=PKCS7(128).padder();x=p.update(str(v).encode())+p.finalize();c=Cipher(algorithms.AES(key),modes.CBC(key)).encryptor();return base64.b64encode(c.update(x)+c.finalize()).decode()
bootstrap=request('https://cnuit.cnu.ac.kr/patis/common/OutLinkController.do',b'method=checkURL&MENU_KEY=M69r16057e79Y231','application/x-www-form-urlencoded').decode('utf-8','replace')
m=re.search(r'"gv_sessionUser":"([^"]+)"',bootstrap)
if not m:raise GuardStop('normal anonymous outlink unavailable')
user=m[1];del bootstrap,m
def send(service,method,params):
 uid=uuid.uuid4().hex;args=dict(params)
 args.update(FRAMEWORK_SERVICE_NAME=service,FRAMEWORK_METHOD_NAME=method,FRAMEWORK_LANGUAGE_GB='KO',FRAMEWORK_TRANSACTION_ID=uid,FRAMEWORKLOG_PROTOCOL='JSON',FRAMEWORK_SESSION_USER=user,FRAMEWORK_FRAME_GB='3',FRAMEWORK_FRAME_INFO='outlink',FRAMEWORK_MENU_CD='S010403')
 out={};i=1
 for k,v in args.items():
  if k=='FRAMEWORK_TRANSACTION_ID':n=0;key=user
  else:n=i;i+=1;key=uid
  out[f'FRAMEWORKLOG_PARAM{n}']=[enc(k,key)];out[f'FRAMEWORKLOG_VALUE{n}']=[enc(v,key)]
 b=request(f'https://cnuit.cnu.ac.kr/patis/system/serviceController.do?GB={service}_{method}',json.dumps({'param':out}).encode(),'application/json')
 try:j=json.loads(b)
 except ValueError:raise GuardStop('non-JSON public reply; no raw reply persisted')
 meta=j.get('_METADATA_',{})
 if meta.get('success') is False or str(meta.get('ErrorCode','0')) not in ('0','', 'None'):raise GuardStop('public service error metadata code '+str(meta.get('ErrorCode'))+'; no raw reply persisted')
 return j,hashlib.sha256(b).hexdigest()
query={'ORGN_CLSF_CD':'CBA01.020','YR':'2026','SHTM_CD':'USR01.20','SUST_MJ_CD':'','INCLUDE_ORGN_YN':'0','CPTN_DIV_CD':'','CULT_FLD_CD':'','TRGT_CORS_CD':'','LSN_METHOD_CD':'','CLOSE_YN':'','OPEN_SBJT_NO':'','STAFF_GB':''}
j,sha=send('Uls0321Service','selectList01',query);rows=j.get('ds_out')
if not isinstance(rows,list) or not rows:raise GuardStop('missing current whole catalog')
del j
old=json.loads((R/'cnu-selectList01.json').read_text())['ds_out'];oldmap={r['COURSE_NO']:r for r in old}
education=[{k:clean(r.get(k)) for k in CAT_FIELDS} for r in rows]
currentmap={r['COURSE_NO']:r for r in education};changes=[]
for row in education:
 prior=oldmap.get(row['COURSE_NO'])
 if prior:
  diff={k:{'prior':clean(prior.get(k)),'current':row.get(k)} for k in CAT_FIELDS if clean(prior.get(k))!=row.get(k)}
  if diff:changes.append({'courseId':row['COURSE_NO'],'changedEducation':diff})
atomic(R/'cnu-current-catalog-education.json',education)
atomic(R/('cnu-current-catalog-reconciliation-resume.json' if (R/'cnu-current-catalog-reconciliation.json').exists() else 'cnu-current-catalog-reconciliation.json'),{'verifiedOn':'2026-10-08','publicWholeResponseSHA256':sha,'currentRows':len(rows),'uniqueCourseIds':len(currentmap),'active':sum(str(r.get('CLOSE_YN'))=='0' for r in rows),'closed':sum(str(r.get('CLOSE_YN'))=='1' for r in rows),'added':sorted(set(currentmap)-set(oldmap)),'absent':sorted(set(oldmap)-set(currentmap)),'changed':changes,'rawBodySaved':False,'anonymousStateSaved':False,'staffNumbersSaved':False,'contactFieldsSaved':False})
del old,oldmap
active=[r for r in rows if str(r.get('CLOSE_YN'))=='0'];status={'target':len(active),'processed':0,'published':0,'unpublished':0,'errors':[],'stoppedByGuard':False,'redactions':redactions,'finished':False}
print('current catalog',len(rows),'active',len(active),'closed',len(rows)-len(active),'education changes',len(changes),flush=True)
for index,row in enumerate(active):
 file=OUT/(row['COURSE_NO']+'.json')
 try:
  if file.exists():result=json.loads(file.read_text())
  else:
   availability=None
   if not row.get('LT_STAFF_NO'):
    gate,gateSHA=send('Uls0604Service','selectGangwiPopInitData',{k:row.get(k) if row.get(k) is not None else '' for k in ARGS[:6]})
    availability=[{k:g.get(k) for k in ('KOR','ENG','SPR','TOT','CERT','DGN','EXT')} for g in gate.get('ds_out',[])]
    if not any((g.get('EXT') or 0)>0 for g in availability):
     result={'courseId':row['COURSE_NO'],'sourceService':'Uls0604Service/selectGangwiPopInitData','verifiedOn':'2026-10-08','sourceResponseSHA256':gateSHA,'publicAvailability':availability,'planPresent':False,'blockReason':'current EXT plan absent; preliminary SPR presence retained separately','header':[],'weeks':[]}
     atomic(file,result);status['unpublished']+=1;status['processed']=index+1;atomic(R/'cnu-current-education-collection-audit.json',status);continue
   data,digest=send('Uls0604Service','selectTab01List',{k:row.get(k) if row.get(k) is not None else '' for k in ARGS})
   header=data.get('ds_out01',[]);weeks=data.get('ds_out02',[])
   result={'courseId':row['COURSE_NO'],'sourceService':'Uls0604Service/selectTab01List','verifiedOn':'2026-10-08','sourceResponseSHA256':digest,'publicAvailability':availability,'planPresent':bool(header),'header':[{k:clean(h.get(k)) for k in PLAN_FIELDS if h.get(k) is not None} for h in header],'weeks':[{k:clean(w.get(k)) for k in WEEK_FIELDS if w.get(k) is not None} for w in weeks],'otherEducationRowsCount':len(data.get('ds_out03',[]))}
   atomic(file,result);del data
  status['published' if result['planPresent'] else 'unpublished']+=1
 except GuardStop as e:
  status['stoppedByGuard']=True;status['guardCourseId']=row['COURSE_NO'];status['guardReason']=str(e);atomic(R/'cnu-current-education-collection-audit.json',status);print('STOP guard',str(e),flush=True);raise
 except Exception as e:
  status['errors'].append({'courseId':row['COURSE_NO'],'type':type(e).__name__})
 status['processed']=index+1
 atomic(R/'cnu-current-education-collection-audit.json',status)
 if (index+1)%50==0:print('plans',index+1,'/',len(active),'published',status['published'],'unpublished',status['unpublished'],'errors',len(status['errors']),flush=True)
status['finished']=True;atomic(R/'cnu-current-education-collection-audit.json',status);print('finished',status['processed'],flush=True)
