import json,datetime as dt,re,hashlib,collections
from pathlib import Path
p=Path(__file__).parent
a=json.loads((p/'candidate-audit-v2.json').read_text());new={x['sourceId'] for x in a['newNativeProofs']}
clock=json.loads((p/'current-native-clock-proof-v1.json').read_text());clocks={c['period']:(c['startMinute'],c['endMinute']) for c in next(r for r in clock if r['campus']=='mirae')['nativeClockRows']}
whole=set();oldscheduled=0;oldframes=0;newframes=0;changed=0
for campus in ['sinchon','international','mirae','unknown']:
 old=json.loads((p/f'baseline-yonsei-{campus}-v1.json').read_text())['courses'];now=json.loads((p/f'yonsei-{campus}-2026-2.published-partial-v2-20261009.json').read_text())['courses']
 assert len(old)==len(now)
 for b,c in zip(old,now):
  assert c['sourceId'] not in whole;whole.add(c['sourceId'])
  if b['schedules']:oldscheduled+=1;oldframes+=len(b['schedules'])
  if c['sourceId'] not in new:assert c==b;continue
  changed+=1;assert campus=='mirae' and not b['schedules']
  for key in b:
   if key not in ['schedules','scheduleStatus','remarks','departmentRemarks']:assert c[key]==b[key]
  native=c['sourceEducation'][0]
  assert native['sysinstDivCd']=='H2' and native['campsDivNm']=='미래' and native['lessnSessnDivNm']=='학기' and native['rmvlcYn']=='0'
  assert all(r['lctreTimeNm']==c['sourceSchedule'] and r['lecrmNm']==c['sourceClassroom'] for r in c['sourceEducation'])
  # Independent token sequence against immutable native source; no builder parser/proof read.
  tp=c['sourceSchedule'].split('/');rp=c['sourceClassroom'].split('/')
  if len(rp)==1:rp*=len(tp)
  assert len(tp)==len(rp)
  slots=set()
  for times,rooms in zip(tp,rp):
   tg=re.findall(r'\(([^()]*)\)|([^()]+)',times.replace(' ',''));rg=re.findall(r'\(([^()]*)\)|([^()]+)',rooms)
   if len(rg)==1 and rg[0][1]:rg=[((rg[0][1],'') if group[0] else ('',rg[0][1])) for group in tg]
   assert len(tg)==len(rg)
   for (practice,lecture),(labroom,lectureroom) in zip(tg,rg):
    assert bool(practice)==bool(labroom);raw=practice or lecture;room=labroom or lectureroom
    ms=list(re.finditer(r'([월화수목금토])(\d+(?:,\d+)*)',raw));assert ','.join(m.group() for m in ms)==raw
    for m in ms:
     for period in map(int,m[2].split(',')):
      start,end=clocks[period];slots.add(('월화수목금토'.index(m[1])+1,start,end,room))
  expected=set();day=dt.date(2026,9,1)
  while day<=dt.date(2026,12,7):
   if day.isoformat() not in {'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'} and not dt.date(2026,10,20)<=day<=dt.date(2026,10,26):
    expected.update((day.isoformat(),start,end,room) for weekday,start,end,room in slots if weekday==day.isoweekday())
   day+=dt.timedelta(days=1)
  actual={(m['date'],m['startMinute'],m['endMinute'],m['classroom']) for m in c['schedules']}
  assert actual==expected and len(actual)==len(c['schedules']);newframes+=len(actual)
assert len(whole)==4710 and oldscheduled==2396 and oldframes==83863 and changed==324 and newframes==13102
out={'researchOnly':True,'completionClaim':False,'passed':True,'wholeMetadata':len(whole),'priorScheduledDeepPreserved':oldscheduled,'priorFrames':oldframes,'newNativeSourceReviewed':changed,'newFrames':newframes,'parserImplementationImported':False,'nativeOriginalEducationUnchanged':True,'currentWholeCourseFreshnessVerified':False}
(p/'independent-native-date-audit.json').write_text(json.dumps(out,indent=2)+'\n');print(out)
