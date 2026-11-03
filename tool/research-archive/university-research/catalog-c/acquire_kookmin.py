import urllib.request,json,time
from pathlib import Path
ROOT=Path(__file__).parent
URL='https://sugang.kookmin.ac.kr/api/subject/public/lectures/conditions/validation/ko'
BASE=dict.fromkeys('stuno locale studentUnivDeptCd scheduleDivCd subjtCd subjtNm professorNm daywCd lessnLestmCd cmpsjDivCd estblCrseDivCd cltrDomnCd dghtDivCd univCd deprtCd bchdmCntcSubjtYn srclnLctreLangDivCd grade'.split(),None)
BASE.update(syy='2026',smtCd='20',searchType='01',locale='ko',scheduleSeq=0,offset=0,limit=50)
events={};counts={}
for credit in range(24):
 offset=0;found=0
 while True:
  body=dict(BASE,cmpsjCdt=credit,offset=offset)
  req=urllib.request.Request(URL,data=json.dumps(body).encode(),headers={'Content-Type':'application/json','User-Agent':'Mozilla/5.0'})
  with urllib.request.urlopen(req,timeout=35)as response:raw=response.read()
  data=json.loads(raw);rom=data['lectureRoms'];rows=rom['results'];total=rom['totalCount']
  (ROOT/f'kookmin-credit{credit}-offset{offset}.json').write_bytes(raw)
  for row in rows:events[row['id']]=row
  found+=len(rows)
  if found>=total:break
  if not rows:raise RuntimeError('Premature empty page')
  offset+=50;time.sleep(.15)
 counts[str(credit)]={'totalCount':total,'received':found}
 assert found==total,(credit,found,total)
 time.sleep(.15)
(ROOT/'kookmin-all-integer-credit2026-2.json').write_text(json.dumps({'records':list(events.values()),'creditCounts':counts,'scope':'Published credit filter 0..23; fractional credit coverage not yet verified'},ensure_ascii=False,indent=2)+'\n')
print('unique',len(events),'counts',counts)
