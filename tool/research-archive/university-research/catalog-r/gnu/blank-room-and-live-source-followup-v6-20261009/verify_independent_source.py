import json,re,datetime as dt,hashlib,collections
from pathlib import Path
D=Path('work/university-research/catalog-r/gnu/blank-room-and-live-source-followup-v6-20261009');B=D.parent/'remaining-campus-clock-followup-v5-20261008'
read=lambda p:json.loads(p.read_text())
raw=read(Path('work/university-research/catalogs/gnu-public-course-rows.json'))
clock={}
for row in read(B/'current2026-2-university-undergraduate-clock-education.json')['clockTable'][1:]:
 for pos in (0,2):clock[int(re.search(r'\d+',row[pos])[0])]=[int(h)*60+int(m) for h,m in re.findall(r'(\d\d):(\d\d)',row[pos+1])]
calendar=read(B/'own-term-makeup-education.json')['visuallyVerifiedEducationOnly'];makeup=calendar['holidayToMakeup']
assert calendar['termStart']=='2026-09-01' and calendar['finalExamPeriod']==['2026-12-15','2026-12-21']
previous={c['sourceId']:c for p in B.glob('gnu-*.ordinary-university-guide-v5.json') for c in read(p)['courses']}
current={c['sourceId']:c for p in D.glob('gnu-*.blank-room-and-live-v6.json') for c in read(p)['courses']}
assert current.keys()==previous.keys() and len(current)==4842
changes=[];count=collections.Counter()
for key,c in current.items():
 old=previous[key]
 if c==old:count['untouched']+=1;continue
 assert not old['schedules']
 native=c['metadata']['originalEducationalFields'];assert native==old['metadata']['originalEducationalFields'] and native in raw
 assert not native['closedFirstAnnouncement'] and not native['closedSecondAnnouncement']
 for f in old:
  if f not in ('schedules','scheduleStatus','remarks','metadata'):assert c[f]==old[f],(key,f)
 expected=[]
 for day,numbers,room in re.findall(r'([월화수목금토일])(\d+(?:,\d+)*)(?:\[([^\]]+)\])?',native['schedule']):
  nums=list(map(int,numbers.split(',')));dow='월화수목금토일'.index(day)+1
  if key.endswith('/11006946-001') and dow==3:assert nums==[10,11,12] and 12 not in clock;continue
  assert len(nums)==len(set(nums)) and nums==sorted(nums) and all(n in clock for n in nums)
  runs=[]
  for n in nums:
   if not runs or n!=runs[-1][-1]+1:runs.append([])
   runs[-1].append(n)
  for run in runs:
   for offset in range((dt.date(2026,12,7)-dt.date(2026,9,1)).days+1):
    date=dt.date(2026,9,1)+dt.timedelta(days=offset)
    if date.isoweekday()!=dow or date==dt.date(2026,10,3):continue
    actual=makeup.get(str(date),str(date));row=dict(date=actual,weekday=dt.date.fromisoformat(actual).isoweekday(),startMinute=clock[run[0]][0],endMinute=clock[run[-1]][1],classroom=room)
    if native['remoteType']=='실시간 원격 화상강좌':row['deliveryMode']='liveOnline'
    expected.append(row)
 expected.sort(key=lambda x:(x['date'],x['startMinute'],x['classroom']))
 assert expected==c['schedules'],key
 changes.append(key);count['newDates']+=len(expected)
assert len(changes)==43 and count==dict(untouched=4799,newDates=630)
assert sum(bool(c['schedules']) for c in previous.values())==2962
assert sum(len(c['schedules']) for c in previous.values())==53239
assert sum(bool(c['schedules']) for c in current.values())==3005
assert sum(len(c['schedules']) for c in current.values())==53869
out={'researchOnly':True,'actualDartValidation':False,'independentOriginalEducationalRows':4842,'allSourceIdentitiesPreserved':True,'untouchedWholeObjects':4799,'previousScheduled':2962,'previousDates':53239,'newScheduled':43,'newDates':630,'totalScheduled':3005,'totalDates':53869,'clockReadDirectlyFromPublishedTable':True,'calendarReadDirectlyFromEducationalReceipt':True,'originalNativeClockRoomAndModeIndependentlyReconstructed':True,'changedSourceIds':changes}
(D/'independent-source-clock-date-proof.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(out)
