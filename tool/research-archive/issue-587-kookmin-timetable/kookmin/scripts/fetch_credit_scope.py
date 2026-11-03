"""Fresh 2026-2 public catalog traversal by published credit filter (searchType 01)."""
import json,time,urllib.request,sys
from pathlib import Path
OUT=Path(sys.argv[1])
URL='https://sugang.kookmin.ac.kr/api/subject/public/lectures/conditions/validation/ko'
BASE=dict.fromkeys('stuno locale studentUnivDeptCd scheduleDivCd subjtCd subjtNm professorNm daywCd lessnLestmCd cmpsjDivCd estblCrseDivCd cltrDomnCd dghtDivCd univCd deprtCd bchdmCntcSubjtYn srclnLctreLangDivCd grade'.split(),None)
BASE.update(syy='2026',smtCd='20',searchType='01',locale='ko',scheduleSeq=0,offset=0,limit=50)
UA='Mozilla/5.0 (compatible; DailyCalendar/1.0)'
rows={};counts={}
def post(body):
    req=urllib.request.Request(URL,data=json.dumps(body).encode(),headers={'Content-Type':'application/json','User-Agent':UA})
    with urllib.request.urlopen(req,timeout=30) as r: return json.load(r)
# unfiltered total first
counts['all']=None
for credit in range(24):
    offset=0;got=0
    while True:
        rom=post(dict(BASE,cmpsjCdt=credit,offset=offset))['lectureRoms']
        res=rom['results'];total=rom['totalCount']
        for row in res:
            row={k:v for k,v in row.items() if not any(w in k.lower() for w in ['empno','professorno','email','phone','mobile','token','password'])}
            for m in row.get('schedule',{}).get('lectureTimes',[]): m.pop('instructorId',None)
            rows[row['id']]=row
        got+=len(res)
        time.sleep(.6)
        if got>=total or not res: break
        offset+=50
    counts[str(credit)]={'total':total,'received':got}
OUT.write_text(json.dumps({'fetchedAt':time.strftime('%Y-%m-%dT%H:%M:%S%z'),'source':URL,'counts':counts,'records':list(rows.values())},ensure_ascii=False,indent=1))
print('unfiltered',counts['all'],'unique',len(rows),'sum',sum(v['total'] for k,v in counts.items() if k!='all'))
