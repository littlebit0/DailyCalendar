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
item=next(item for item in json.loads((ROOT/'seoultech-all-2026-2.json').read_text()) if item['row']['SUBJ_CD']=='111087')
x=query({'fsp_action':'GridAction','fsp_cmd':'getScheduleGridData','SP_YMST':'20262','LESS_CD':item['queryDepartment'],'DN_DIV':item['dayNight'],'SUBJ_NM':'','LECT_DIV':'','DOTW_CD':''})
row=next(row for row in x['rows'] if row['SUBJ_CD']=='111087')
result=query({'SP_YMST':'20262','SUBJ_CD':row['SUBJ_CD'],'LECT_NUMB':row['LECT_NUMB'],'PERS_NUMB':row['PROF_NUMB'],'fsp_action':'xDefaultAction','fsp_cmd':'execute','fsp_ds_cmd':commands})
for key,value in result.items():
 if key.startswith('ds_') and isinstance(value,list):print(key,len(value),list(value[0]) if value else [])
