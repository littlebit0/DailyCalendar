"""Fresh 2026-2 public catalog traversal by published college options (searchType 02)."""
import json,time,urllib.request,sys
from pathlib import Path
OUT=Path(sys.argv[2]); colleges=json.loads(Path(sys.argv[1]).read_text())['collegeList']
URL='https://sugang.kookmin.ac.kr/api/subject/public/lectures/conditions/validation/ko'
BASE=dict.fromkeys('stuno locale studentUnivDeptCd scheduleDivCd subjtCd subjtNm professorNm daywCd lessnLestmCd cmpsjDivCd estblCrseDivCd cltrDomnCd dghtDivCd univCd deprtCd bchdmCntcSubjtYn srclnLctreLangDivCd grade cmpsjCdt'.split(),None)
BASE.update(syy='2026',smtCd='20',searchType='02',locale='ko',scheduleSeq=0,offset=0,limit=50)
UA='Mozilla/5.0 (compatible; DailyCalendar/1.0)'
rows={};audit=[]
def post(body):
    req=urllib.request.Request(URL,data=json.dumps(body).encode(),headers={'Content-Type':'application/json','User-Agent':UA})
    with urllib.request.urlopen(req,timeout=30) as r: return json.load(r)
for c in colleges:
    code=c['deptCd'];offset=0;got=0
    while True:
        rom=post(dict(BASE,univCd=code,deprtCd=code,offset=offset))['lectureRoms']
        res=rom['results'];total=rom['totalCount']
        for row in res:
            row={k:v for k,v in row.items() if not any(w in k.lower() for w in ['empno','professorno','email','phone','mobile','token','password'])}
            for m in row.get('schedule',{}).get('lectureTimes',[]): m.pop('instructorId',None)
            rows[row['id']]=row
        got+=len(res); time.sleep(.6)
        if got>=total or not res: break
        offset+=50
    audit.append({'collegeCode':code,'collegeName':c['deptNm'],'declared':total,'received':got})
OUT.write_text(json.dumps({'fetchedAt':time.strftime('%Y-%m-%dT%H:%M:%S%z'),'source':URL,'collegeQueries':audit,'records':list(rows.values())},ensure_ascii=False,indent=1))
print('colleges',len(audit),'unique',len(rows),'declaredSum',sum(a['declared'] for a in audit),'mismatch',[a for a in audit if a['declared']!=a['received']])
