import urllib.request,json,time
from pathlib import Path
ROOT=Path(__file__).parent
URL='https://sugang.kookmin.ac.kr/api/subject/public/lectures/conditions/validation/ko'
BASE=dict.fromkeys('stuno locale studentUnivDeptCd scheduleDivCd subjtCd subjtNm professorNm daywCd lessnLestmCd cmpsjDivCd estblCrseDivCd cltrDomnCd dghtDivCd univCd deprtCd bchdmCntcSubjtYn srclnLctreLangDivCd grade'.split(),None)
BASE.update(syy='2026',smtCd='20',searchType='01',locale='ko',scheduleSeq=0,offset=0,limit=50)
events={r['id']:r for r in json.loads((ROOT/'kookmin-all-integer-credit2026-2.json').read_text())['records']};before=set(events);counts={}
for day in (3,4,6):
 offset=0;found=0
 while True:
  body=dict(BASE,cmpsjCdt=None,daywCd=str(day),offset=offset)
  req=urllib.request.Request(URL,data=json.dumps(body).encode(),headers={'Content-Type':'application/json','User-Agent':'Mozilla/5.0'})
  with urllib.request.urlopen(req,timeout=35) as response:raw=response.read()
  data=json.loads(raw);rom=data['lectureRoms'];rows=rom['results'];total=rom['totalCount']
  (ROOT/f'kookmin-day{day}-offset{offset}.json').write_bytes(raw)
  for row in rows:events[row['id']]=row
  found+=len(rows)
  if found>=total:break
  if not rows:raise RuntimeError('Premature empty page')
  offset+=50;time.sleep(.15)
 counts[str(day)]={'totalCount':total,'received':found}
 assert found==total,(day,found,total)
extra=[events[k] for k in set(events)-before]
(ROOT/'kookmin-credit-weekday2026-2.json').write_text(json.dumps({'records':list(events.values()),'dayCounts':counts,'additionalRows':extra,'scope':'Integer credit0..23 plus differing weekday3/4/6 crosscheck; untimed fractional completeness not yet verified'},ensure_ascii=False,indent=2)+'\n')
print('unique',len(events),'additional',[(r['id'],r['credits']) for r in extra])
