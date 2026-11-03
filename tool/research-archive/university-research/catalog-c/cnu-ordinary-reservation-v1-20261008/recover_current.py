"""Normal anonymous current public outlink; educational whitelist only."""
import sys
from pathlib import Path
BASE=Path(__file__).resolve().parent
SOURCE=BASE.parents[1]/'catalog-f'
sys.path.insert(0,str(SOURCE))
code=(SOURCE/'cnu-current-education-collector.py').read_text()
exec(code[:code.index("query={'ORGN_CLSF_CD'")],globals())
from cnu_education_token_cleaner import clean as token_clean, COUNTS
clean=token_clean
D=BASE/'current-education';D.mkdir(exist_ok=True)
screen=json.loads((BASE/'cnu-native-cache-screen.json').read_text())
selected=[d['courseId'] for d in screen['decisions'] if d['ordinaryReviewShortlistOnly']]
query={'ORGN_CLSF_CD':'CBA01.020','YR':'2026','SHTM_CD':'USR01.20','SUST_MJ_CD':'','INCLUDE_ORGN_YN':'0','CPTN_DIV_CD':'','CULT_FLD_CD':'','TRGT_CORS_CD':'','LSN_METHOD_CD':'','CLOSE_YN':'','OPEN_SBJT_NO':'','STAFF_GB':''}
j,whole_sha=send('Uls0321Service','selectList01',query)
current={r['COURSE_NO']:r for r in j['ds_out']};del j
atomic(BASE/'current-whole-educational-catalog.json',[{k:token_clean(row.get(k)) for k in CAT_FIELDS+['LT_STAFF_NM']} for row in current.values()])
old={r['COURSE_NO']:r for r in json.loads((SOURCE/'cnu-current-catalog-education-with-public-names.json').read_text())}
audit={'completionClaim':False,'normalAnonymousPublishedOutlinkOnly':True,'privateStateOrStaffIdentifiersSaved':False,'rawBodySaved':False,'currentWholeResponseSHA256':whole_sha,'wholeRows':len(current),'target':len(selected),'processed':0,'finished':False,'results':[]}
try:
 for cid in selected:
  row=current.get(cid)
  if not row or str(row.get('CLOSE_YN'))!='0' or str(row.get('OPEN_YR'))!='2026' or row.get('OPEN_SHTM_CD')!='USR01.20':raise GuardStop('current public offering changed or closed')
  if not row.get('LT_STAFF_NO'):
   audit['results'].append({'courseId':cid,'held':True,'reason':'Actual current published popup argument absent; no guessed value or unpublished route queried'});audit['processed']=len(audit['results']);atomic(BASE/'current-recovery-audit.json',audit);continue
  file=D/f'{cid}.json'
  if file.exists():fresh=json.loads(file.read_text())
  else:
   data,digest=send('Uls0604Service','selectTab01List',{k:row.get(k) if row.get(k) is not None else '' for k in ARGS})
   fresh={'courseId':cid,'verifiedOn':'2026-10-08','sourceService':'Uls0604Service/selectTab01List','sourceResponseSHA256':digest,'recoveryMethod':'educationTokenOnlyRedactionActualHtmlOnly','header':[{k:token_clean(h[k]) for k in PLAN_FIELDS if h.get(k) is not None} for h in data.get('ds_out01',[])],'weeks':[{k:token_clean(w[k]) for k in WEEK_FIELDS if w.get(k) is not None} for w in data.get('ds_out02',[])]};del data
   if not fresh['header']:
    audit['results'].append({'courseId':cid,'held':True,'reason':'Current normal public plan absent; no alternate unpublished lookup'});audit['processed']=len(audit['results']);atomic(BASE/'current-recovery-audit.json',audit);continue
   for section in ['header','weeks']:
    for item in fresh[section]:
     for value in item.values():
      if isinstance(value,str) and re.search(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|https?://|(?<!\d)0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)',value,re.I):raise GuardStop('residual contact/access value; not persisted')
   atomic(file,fresh)
  changes=[k for k in CAT_FIELDS+['LT_STAFF_NM'] if token_clean(row.get(k))!=old.get(cid,{}).get(k)]
  audit['results'].append({'courseId':cid,'currentPlanSHA256':fresh['sourceResponseSHA256'],'publicEducationalCatalogChangedFields':changes,'newFieldWeeks':[w['WKORD'] for w in fresh['weeks'] if str(w.get('CLS_METHOD_FIELD',0))=='1'],'currentSpecialHours':[h.get('LSN_MTHD_SCENE') for h in fresh['header'] if h.get('LSN_MTHD_SCENE') not in [None,0,'0','']]})
  audit['processed']=len(audit['results']);audit['redactionCounts']=dict(COUNTS);atomic(BASE/'current-recovery-audit.json',audit)
  if audit['processed']%20==0:print('current educational plans',audit['processed'],'/',len(selected),flush=True)
except Exception as e:
 audit.update(stopped=True,stopCourseId=cid if 'cid' in globals() else None,stopType=type(e).__name__,stopReason=str(e) if isinstance(e,(GuardStop,ValueError)) else 'bounded public request failure; raw not printed');atomic(BASE/'current-recovery-audit.json',audit);print('STOP',audit['processed'],audit['stopType'],flush=True);raise SystemExit(1)
audit['finished']=True;atomic(BASE/'current-recovery-audit.json',audit);print('finished current educational recovery',audit['processed'],flush=True)
