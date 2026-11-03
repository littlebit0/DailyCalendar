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
commands=[]
for sql in ['sugang:POPUP_PROGRAM_01','sugang:POPUP_PROGRAM_03','sugang:POPUP_PROGRAM_04','sugang:POPUP_PROGRAM_05']:
 command={key:'' for key in ['KEY_SQL_ID','KEY_INCREMENT','CALLBACK_SQL_ID','INSERT_SQL_ID','UPDATE_SQL_ID','DELETE_SQL_ID','EXEC','FAIL','FAIL_MSG','MSG']}
 command.update(TYPE='N',SQL_ID=sql,SAVE_FLAG_COLUMN=None,KEY_ZERO_LEN=None,EXEC_TYPE='B',USE_INPUT='N',USE_ORDER='Y',EXEC_CNT=0);commands.append(command)
def clean(value):
 if not isinstance(value,str):return value
 return '\n'.join(line for line in value.splitlines() if not re.search(r'@|(?:010|02|0[3-6]\d)[- ]\d{3,4}[- ]\d{4}',line))
manifest=json.loads((ROOT/'seoultech-current-plan-audit.json').read_text())
errors={item['key'] for item in manifest['errors']}
inventory=json.loads((ROOT/'seoultech-all-2026-2.json').read_text())
for key in sorted(errors):
 item=next(item for item in inventory if item['row']['SUBJ_CD']+'-'+item['row']['LECT_NUMB']==key)
 values={'fsp_action':'GridAction','fsp_cmd':'getScheduleGridData','SP_YMST':'20262','LESS_CD':item['queryDepartment'],'DN_DIV':item['dayNight'],'SUBJ_NM':'','LECT_DIV':'','DOTW_CD':''}
 result=query(values)
 if int(result.get('records',-1))!=len(result.get('rows',[])):raise ValueError('Incomplete current scope')
 row=next(row for row in result['rows'] if row['SUBJ_CD']+'-'+row['LECT_NUMB']==key)
 values={'SP_YMST':'20262','SUBJ_CD':row['SUBJ_CD'],'LECT_NUMB':row['LECT_NUMB'],'PERS_NUMB':row['PROF_NUMB'],'fsp_action':'xDefaultAction','fsp_cmd':'execute','fsp_ds_cmd':commands}
 records=query(values).get('ds_subjCls',[])
 if len(records)!=1:raise ValueError('Missing unique current plan')
 plan=records[0]
 if str(plan.get('SP_YMST'))!='20262' or plan.get('SUBJ_CD')!=row['SUBJ_CD']:raise ValueError('Current plan identity mismatch')
 fields={'SP_YMST','SUBJ_CD','SUBJ_CD_NM','SUBJ_CD_ENM','LS_TM_LIST','BLDG_COUM','CONC_SMTS_DIV','CONC_SMTS_DIV_NM','UNIT_NM','CMPT_DIV_NM','LESS_CD_NM','GRAD_SMST_NM','COUS_LNG_CD_NM','EDUC_METH','SUBJ_SMRY','STRE_RELA'}
 safe={k:clean(v) for k,v in plan.items() if k in fields or re.fullmatch(r'(COUS_CONT|TASK_NOTT)_\d+',k)}
 safe['publishedOffering']={k:row.get(k) for k in ('SUBJ_KNM','LECT_NUMB','LSTM_LIST','BLDG_COUM','PROF_NM','CMPT_DIV_NM','UNIT','NOTE','ETC','OTSH_LIMT_YN','DLES_COUR_PBT_YN')}
 (ROOT/'seoultech-public-plans'/(key+'.json')).write_text(json.dumps(safe,ensure_ascii=False,indent=2))
 manifest['errors']=[item for item in manifest['errors'] if item['key']!=key];manifest['plans']+=1
 (ROOT/'seoultech-current-plan-audit.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
 print('Recovered current plan',key,flush=True);time.sleep(.7)
