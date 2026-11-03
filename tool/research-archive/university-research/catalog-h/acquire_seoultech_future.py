"""Read actual course-specific public future-college schedules, never infer dates."""
import http.cookiejar,json,time,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parent;BASE='https://for-s.seoultech.ac.kr'
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()));op.addheaders=[('User-Agent','Mozilla/5.0'),('Referer',BASE+'/html/pub/schedule.jsp')]
with op.open(BASE+'/html/pub/schedule.jsp',timeout=30) as response:response.read()
# Candidate scope from actual current offerings; a code prefix does not itself prove faculty membership.
rows=[r for r in json.loads((ROOT/'seoultech-unique2026-2.json').read_text()) if r['SUBJ_CD'].startswith('7')]
c={key:'' for key in ['KEY_SQL_ID','KEY_INCREMENT','CALLBACK_SQL_ID','INSERT_SQL_ID','UPDATE_SQL_ID','DELETE_SQL_ID','EXEC','FAIL','FAIL_MSG','MSG']};c.update(TYPE='N',SQL_ID='sugang:F_TIMETABLE_SEARCH',SAVE_FLAG_COLUMN=None,KEY_ZERO_LEN=None,EXEC_TYPE='B',USE_INPUT='N',USE_ORDER='Y',EXEC_CNT=0)
fields={'LS_EDT','LS_DOTW_NM','RNUMB','LS_DT_NM','LS_TM_CD_NM','SUBJ_TYPE','SUBJ_CD_NM','LS_BLDG_COUM_NM','LS_DT'}
output=ROOT/'seoultech-future-public-schedules';output.mkdir(exist_ok=True)
audit={'researchOnly':True,'completionClaim':False,'complete':False,'candidateCount':len(rows),'processed':0,'published':0,'empty':[],'errors':[]}
def save():
 (ROOT/'seoultech-future-public-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2))
for i,row in enumerate(rows,1):
 key=row['SUBJ_CD']+'-'+row['LECT_NUMB'];dest=output/(key+'.json')
 try:
  p={'SP_YMST':'20262','SUBJ_CD':row['SUBJ_CD'],'LECT_NUMB':row['LECT_NUMB'],'fsp_action':'xDefaultAction','fsp_cmd':'execute','fsp_ds_cmd':[c]}
  request=urllib.request.Request(BASE+'/JSONMain',data=json.dumps(p).encode(),headers={'Content-Type':'application/json; charset=utf-8'})
  with op.open(request,timeout=30) as response:result=json.load(response)
  if str(result.get('ErrorCode'))!='0':raise ValueError('Normal public endpoint failed')
  data=result.get('ds_list',[])
  if data:
   safe=[{k:v for k,v in r.items() if k in fields} for r in data]
   dest.write_text(json.dumps({'term':'20262','sourceCourseKey':key,'publishedCourseTitle':row['SUBJ_KNM'],'publishedDepartment':row['SP_LESS_CD_NM'],'rows':safe},ensure_ascii=False,indent=2));audit['published']+=1
  else:audit['empty'].append(key)
 except urllib.error.HTTPError as error:
  audit['errors'].append({'key':key,'status':error.code})
  if error.code in (401,403,429):save();raise RuntimeError('Access review required') from None
 except Exception as error:audit['errors'].append({'key':key,'errorType':type(error).__name__})
 audit['processed']=i;save()
 if i%20==0:print('Reviewed',i,'published',audit['published'],'empty',len(audit['empty']),'errors',len(audit['errors']),flush=True)
 time.sleep(.7)
audit['complete']=True;save();print('Public course-specific schedule review completed',len(rows),flush=True)
