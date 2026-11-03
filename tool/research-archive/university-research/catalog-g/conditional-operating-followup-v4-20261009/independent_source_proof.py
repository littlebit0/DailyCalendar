import collections, datetime as dt, json, re
from pathlib import Path
D=Path(__file__).resolve().parent; P=D.parent
read=lambda p:json.loads(p.read_text())
reports={(r['campus'],r['sourceRow']['HAKSU_NO']):r for r in read(P/'gachon-full-operating-report-audit.json')['reports']}
clock=read(P/'gachon-current-scope-clock-term-manifest.json')['clock50minPeriods']; rules=read(D/'individual-source-review-rules.json')
days=dict(zip('월화수목금토일',range(1,8))); holidays={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
proof=[]; unchanged=0
for campus,src in [('global','20'),('medical','21')]:
 old=read(P/'conditional-operating-followup-v3-20261009'/f'gachon-{campus}-2026-2.json')['courses'];new=read(D/f'gachon-{campus}-2026-2.json')['courses']
 assert len(old)==len(new)
 for prev,row in zip(old,new):
  native=row['courseCode']+row['section']
  if native not in rules:assert row==prev;unchanged+=1;continue
  r=reports[src,native];rule=rules[native];raw=r['sourceRow']; period=row['period'];slots=collections.defaultdict(list)
  for day,num in re.findall(r'([월화수목금토일])([0-9]+)',raw['TIME']):slots[days[day]].append(int(num))
  blocks=[]
  for day,nums in sorted(slots.items()):
   runs=[]
   for n in sorted(nums):
    if not runs or n!=runs[-1][-1]+1:runs.append([])
    runs[-1].append(n)
   for run in runs:blocks.append({'weekday':day,'startMinute':clock[str(run[0])]['startMinute'],'endMinute':clock[str(run[-1])]['endMinute'],'classroom':raw['LOC_NM'] or ''})
  expected=[]; date=dt.date.fromisoformat(period['startDate']);end=dt.date.fromisoformat(period['endDate'])
  rows=r['weeklyRows'];ranges=[(dt.date(2026,*map(int,w['startMonthDay'].split('/'))),dt.date(2026,*map(int,w['endMonthDay'].split('/'))),w['week'])for w in rows]
  assert ranges[0][0]<=date<=ranges[0][1] and ranges[-1][1]==end
  while date<=end:
   week=next(w for start,finish,w in ranges if start<=date<=finish)
   if week not in rule['omitWeeks'] and date.isoformat() not in holidays|set(rule['heldDates']):
    expected.extend(dict(b,date=date.isoformat())for b in blocks if b['weekday']==date.isoweekday())
   date+=dt.timedelta(days=1)
  assert expected==row['schedules'],native
  proof.append({'nativeOffering':native,'sourceId':row['sourceId'],'sourceClockString':raw['TIME'],'sourceClassroomNullable':raw['LOC_NM'],'sourcePeriod':period,'expectedClockBlocks':blocks,'expectedMeetings':expected,'weeklyRowCount':len(rows),'omitWeeks':rule['omitWeeks'],'heldDates':rule['heldDates']})
assert unchanged==3608 and len(proof)==201 and sum(len(r['expectedMeetings'])for r in proof)==2956
(D/'independent-native-clock-date-room-proof.json').write_text(json.dumps({'researchOnly':True,'completionClaim':False,'sourceSnapshotDate':'2026-10-08','newPublishedSourceAcquisition':False,'unchangedWholeCourseObjects':unchanged,'newCourses':201,'newDates':2956,'nativeIndependentCheckPassed':True,'rows':proof},ensure_ascii=False,indent=2)+'\n')
print('Independent raw TIME/own clock/printed weekly period/room/exception proof: 201/2956; unchanged3608 PASS')
