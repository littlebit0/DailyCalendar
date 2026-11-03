# coding: utf-8
import json,pathlib,urllib.request,hashlib
D=pathlib.Path(__file__).parent/'jbnu-new-official-paths'
body={'data':{'dmReqKey':{'strYrsa':'2026','strSemstrCd':'SUSR016.020','strCertDivCd':'1','strLanDivcd':'CCMN101.KOR','strLang':'ko'}}}
def post(endpoint):
 url='https://jump.jbnu.ac.kr/SCH/SucrLessnSbjctInq/'+endpoint+'.do'
 with urllib.request.urlopen(urllib.request.Request(url,data=json.dumps(body).encode(),headers={'Content-Type':'application/json'}),timeout=25) as r:return url,json.loads(r.read())
u,guard=post('date');(D/'current-20261012-date-guard.json').write_text(json.dumps(guard,ensure_ascii=False,indent=2));ok=guard.get('data',guard).get('dmResSchedule',{}).get('strSchedule')=='Y'
if not ok:print('Public guard closed; no list attempted');raise SystemExit(0)
u,data=post('list');rows=data.get('data',data).get('dsEstSbjList',[])
keys=list(json.loads(pathlib.Path('work/university-research/catalog-c/jbnu-current-20261008/current-public-type1-education.json').read_text())['rows'][0])
rows=[{k:r.get(k) for k in keys} for r in rows if r.get('MNG_SCSBJT_CDNM')=='의학과'];out={'sourceUrl':u,'request':body,'publicGuardVerified':True,'rows':rows};(D/'current-20261012-medical-visible-education.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print('Visible medical rows',len(rows))
