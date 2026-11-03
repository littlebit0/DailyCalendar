"""Read only published GUEST plan queries; transient staff arguments never saved."""
import http.cookiejar,json,re,time,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parent
BASE='https://for-s.seoultech.ac.kr'
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
opener.addheaders=[('User-Agent','Mozilla/5.0'),('Referer',BASE+'/html/pub/schedule.jsp')]
with opener.open(BASE+'/html/pub/schedule.jsp',timeout=30) as response:response.read()
def query(values):
 request=urllib.request.Request(BASE+'/JSONMain',data=json.dumps(values).encode(),headers={'Content-Type':'application/json; charset=utf-8'})
 with opener.open(request,timeout=40) as response:result=json.load(response)
 if str(result.get('ErrorCode'))!='0':raise ValueError('Official public request failed')
 return result
scopes=json.loads((ROOT/'seoultech-scopes.json').read_text())
rows={};counts=[]
for scope in scopes:
 values={'fsp_action':'GridAction','fsp_cmd':'getScheduleGridData','SP_YMST':'20262','LESS_CD':scope['departmentCode'],'DN_DIV':scope['dayNight'],'SUBJ_NM':'','LECT_DIV':'','DOTW_CD':''}
 result=query(values);data=result.get('rows',[])
 if int(result.get('records',-1))!=len(data):raise ValueError('Incomplete published scope')
 counts.append({'departmentCode':scope['departmentCode'],'dayNight':scope['dayNight'],'count':len(data)})
 for row in data:
  key=row['SUBJ_CD']+'-'+row['LECT_NUMB']
  if key in rows and any(rows[key].get(k)!=row.get(k) for k in ('SUBJ_KNM','LSTM_LIST','BLDG_COUM')):raise ValueError('Conflicting current offering')
  rows[key]=row
 time.sleep(.4)
print('Current published scopes',len(counts),'unique offerings',len(rows),flush=True)
commands=[]
for sql in ['sugang:POPUP_PROGRAM_01','sugang:POPUP_PROGRAM_03','sugang:POPUP_PROGRAM_04','sugang:POPUP_PROGRAM_05']:
 command={key:'' for key in ['KEY_SQL_ID','KEY_INCREMENT','CALLBACK_SQL_ID','INSERT_SQL_ID','UPDATE_SQL_ID','DELETE_SQL_ID','EXEC','FAIL','FAIL_MSG','MSG']}
 command.update(TYPE='N',SQL_ID=sql,SAVE_FLAG_COLUMN=None,KEY_ZERO_LEN=None,EXEC_TYPE='B',USE_INPUT='N',USE_ORDER='Y',EXEC_CNT=0);commands.append(command)
output=ROOT/'seoultech-public-plans';output.mkdir(exist_ok=True)
manifest={'term':'20262','researchOnly':True,'completionClaim':False,'complete':False,'scopes':counts,'offeringCount':len(rows),'processed':0,'plans':0,'unpublished':[],'errors':[]}
def save():
 p=ROOT/'seoultech-current-plan-audit.json';tmp=p.with_suffix('.tmp');tmp.write_text(json.dumps(manifest,ensure_ascii=False,indent=2));tmp.replace(p)
def clean(value):
 if not isinstance(value,str):return value
 return '\n'.join(line for line in value.splitlines() if not re.search(r'@|(?:010|02|0[3-6]\d)[- ]\d{3,4}[- ]\d{4}',line))
for index,(key,row) in enumerate(sorted(rows.items()),1):
 dest=output/(key+'.json')
 if row.get('PROG_YN')!='Y':manifest['unpublished'].append(key)
 elif dest.exists():manifest['plans']+=1
 else:
  try:
   values={'SP_YMST':'20262','SUBJ_CD':row['SUBJ_CD'],'LECT_NUMB':row['LECT_NUMB'],'PERS_NUMB':row['PROF_NUMB'],'fsp_action':'xDefaultAction','fsp_cmd':'execute','fsp_ds_cmd':commands}
   result=query(values);records=result.get('ds_subjCls',[])
   if len(records)!=1:raise ValueError('Missing unique current plan')
   plan=records[0]
   if str(plan.get('SP_YMST'))!='20262' or plan.get('SUBJ_CD')!=row['SUBJ_CD']:raise ValueError('Current plan identity mismatch')
   fields={'SP_YMST','SUBJ_CD','SUBJ_CD_NM','SUBJ_CD_ENM','LS_TM_LIST','BLDG_COUM','CONC_SMTS_DIV','CONC_SMTS_DIV_NM','UNIT_NM','CMPT_DIV_NM','LESS_CD_NM','GRAD_SMST_NM','COUS_LNG_CD_NM','EDUC_METH','SUBJ_SMRY','STRE_RELA'}
   safe={k:clean(v) for k,v in plan.items() if k in fields or re.fullmatch(r'(COUS_CONT|TASK_NOTT)_\d+',k)}
   safe['publishedOffering']={k:row.get(k) for k in ('SUBJ_KNM','LECT_NUMB','LSTM_LIST','BLDG_COUM','PROF_NM','CMPT_DIV_NM','UNIT','NOTE','ETC','OTSH_LIMT_YN','DLES_COUR_PBT_YN')}
   dest.write_text(json.dumps(safe,ensure_ascii=False,indent=2));manifest['plans']+=1
  except urllib.error.HTTPError as err:
   manifest['errors'].append({'key':key,'httpStatus':err.code})
   if err.code in (401,403,429):save();raise RuntimeError('Public endpoint requires access review') from None
  except Exception as err:manifest['errors'].append({'key':key,'errorType':type(err).__name__})
 manifest['processed']=index;save()
 if index%25==0:print('Processed',index,'plans',manifest['plans'],'unpublished',len(manifest['unpublished']),'errors',len(manifest['errors']),flush=True)
 time.sleep(.6)
manifest['complete']=True;save();print('Complete',manifest['processed'],flush=True)
