"""Refresh the public whole timetable using its published normal department query."""
import http.cookiejar,json,time,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parent
BASE='https://for-s.seoultech.ac.kr'
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
opener.addheaders=[('User-Agent','Mozilla/5.0'),('Referer',BASE+'/html/pub/schedule.jsp')]
with opener.open(BASE+'/html/pub/schedule.jsp',timeout=30) as r:r.read()
fields={'SUBJ_CD','SUBJ_KNM','NOTE','LECT_NUMB','CMPT_DIV_NM','UNIT','LSTM_LIST','SP_LESS_CD_NM','MNG_LESS_NM','PROF_NM','BLDG_COUM','OTSH_LIMT_YN','DLES_COUR_PBT_YN','COUR_LANG','ETC'}
rows={};scopes=[]
for scope in json.loads((ROOT/'seoultech-scopes.json').read_text()):
 params={'fsp_action':'GridAction','fsp_cmd':'getScheduleGridData','SP_YMST':'20262','LESS_CD':scope['departmentCode'],'DN_DIV':scope['dayNight'],'SUBJ_NM':'','LECT_DIV':'','DOTW_CD':''}
 req=urllib.request.Request(BASE+'/JSONMain',data=json.dumps(params).encode(),headers={'Content-Type':'application/json; charset=utf-8'})
 with opener.open(req,timeout=40) as r:data=json.load(r)
 if str(data.get('ErrorCode'))!='0' or int(data.get('records',-1))!=len(data.get('rows',[])):raise ValueError('Incomplete current scope')
 for raw in data['rows']:
  row={k:v for k,v in raw.items() if k in fields};key=row['SUBJ_CD']+'-'+row['LECT_NUMB']
  if key in rows and rows[key]!=row:raise ValueError('Current aliases disagree')
  rows[key]=row
 scopes.append({**scope,'count':len(data['rows'])});time.sleep(.35)
old={r['SUBJ_CD']+'-'+r['LECT_NUMB']:r for r in json.loads((ROOT/'seoultech-unique2026-2.json').read_text())}
audit={'researchOnly':True,'completionClaim':False,'checkedDate':'2026-10-08','sourceUrl':BASE+'/html/pub/schedule.jsp','scopes':len(scopes),'courses':len(rows),'added':sorted(rows.keys()-old.keys()),'removed':sorted(old.keys()-rows.keys()),'changed':sorted(k for k in rows.keys()&old.keys() if rows[k]!=old[k])}
(ROOT/'seoultech-current-educational-20261008.json').write_text(json.dumps(list(rows.values()),ensure_ascii=False,indent=2))
(ROOT/'seoultech-current-refresh-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2));print(audit)
