"""Read the normal public GUEST timetable. No personal account/cookies used."""
import http.cookiejar, json, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parent
BASE='https://for-s.seoultech.ac.kr'
PAGE=BASE+'/html/pub/schedule.jsp'
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
opener.addheaders=[('User-Agent','Mozilla/5.0'),('Referer',PAGE)]
with opener.open(PAGE,timeout=30) as response:
    body=response.read()
(ROOT/'seoultech-public-schedule.html').write_bytes(body)
def query(data):
    request=urllib.request.Request(BASE+'/JSONMain',data=json.dumps(data).encode(),headers={'Content-Type':'application/json; charset=utf-8'})
    with opener.open(request,timeout=40) as response:
        return json.loads(response.read())
# Exact published fallback of refreshLessCombo -> $.setLessCommboToDb.
command={key:'' for key in ['KEY_SQL_ID','KEY_INCREMENT','CALLBACK_SQL_ID','INSERT_SQL_ID','UPDATE_SQL_ID','DELETE_SQL_ID','EXEC','FAIL','FAIL_MSG','MSG']}
command.update(TYPE='N',SQL_ID='admin:LESS_SEARCH',SAVE_FLAG_COLUMN=None,KEY_ZERO_LEN=None,EXEC_TYPE='B',USE_INPUT='N',USE_ORDER='Y',EXEC_CNT=0)
result=query({'SP_YMST':'20262','fsp_action':'xDefaultAction','fsp_cmd':'execute','fsp_ds_cmd':[command]})
(ROOT/'seoultech-departments.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('Response keys:',list(result))
print('Error code:',result.get('ErrorCode'),'departments:',len(result.get('ds_less',[])))
first=next(d for d in result['ds_less'] if d['ORGN_NM']=='안전공학과')
parameters={'fsp_action':'GridAction','fsp_cmd':'getScheduleGridData','SP_YMST':'20262','LESS_CD':first['ORGN_CD'],'DN_DIV':'00500001','SUBJ_NM':'','LECT_DIV':'','DOTW_CD':''}
rows=query(parameters)
print('Grid keys:',list(rows),'records:',rows.get('records'),'rowCount:',len(rows.get('rows',[])))
fields={'SUBJ_CD','SUBJ_KNM','NOTE','LECT_NUMB','CMPT_DIV_NM','UNIT','LSTM_LIST','SP_LESS_CD_NM','MNG_LESS_NM','PROF_NM','BLDG_COUM','OTSH_LIMT_YN','DLES_COUR_PBT_YN','COUR_LANG','ETC'}
clean={k:v for k,v in rows.items() if k!='rows'}
clean['rows']=[{k:v for k,v in r.items() if k in fields} for r in rows.get('rows',[])]
(ROOT/'seoultech-first-dept.json').write_text(json.dumps(clean,ensure_ascii=False,indent=2)+'\n')
print('Visible first row:',clean['rows'][:1])
import time
all_rows=[]
scopes=[]
for dept in result['ds_less']:
    for dn in ['00500001','00500002']:
        params={**parameters,'LESS_CD':dept['ORGN_CD'],'DN_DIV':dn}
        response=query(params)
        data=response.get('rows',[])
        if str(response.get('ErrorCode')) != '0' or int(response.get('records',-1))!=len(data):
            raise ValueError('Incomplete public department query: '+str((dept['ORGN_CD'],dn,response.get('ErrorCode'),response.get('records'),len(data))))
        cleaned=[{k:v for k,v in row.items() if k in fields} for row in data]
        scopes.append({'departmentCode':dept['ORGN_CD'],'departmentName':dept['ORGN_NM'],'dayNight':dn,'count':len(data)})
        all_rows.extend({'queryDepartment':dept['ORGN_CD'],'dayNight':dn,'row':row} for row in cleaned)
        (ROOT/'seoultech-scopes.json').write_text(json.dumps(scopes,ensure_ascii=False,indent=2)+'\n')
        (ROOT/'seoultech-all-2026-2.json').write_text(json.dumps(all_rows,ensure_ascii=False,indent=2)+'\n')
        print('scope',len(scopes),'rows',len(all_rows),flush=True)
        time.sleep(.35)
print('Complete:',len(scopes),'queries',len(all_rows),'display rows')
