# -*- coding: utf-8 -*-
from pathlib import Path
import json,hashlib,datetime as dt,re
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
proof=json.loads((OUT/'independent-native-clock-date-proof.json').read_text())
review=json.loads((OUT/'all73-individual-operating-source-review.json').read_text())['reviews']
for p,s in {**proof['baselineSHA256'],**proof['sourceInputsSHA256']}.items():assert hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==s,p
old={};new={}
for campus in ['seoul','global']:
 op=ROOT/f'work/university-research/catalog-c/khu-conditional-date-allocation-followup-v5-20261009/khu-{campus}-2026-2.conditional-operating-research-v5-20261009.json'
 for c in json.loads(op.read_text())['courses']:old[c['sourceId']]=c
 for c in json.loads((OUT/f'khu-{campus}-2026-2.empty-room-research-v6-20261009.json').read_text())['courses']:new[c['sourceId']]=c
assert old.keys()==new.keys() and len(old)==4666
added={p['sourceId']:p for p in proof['proofs']};assert len(added)==41
for sid,c in new.items():
 if sid not in added:assert c==old[sid],sid;continue
 assert not old[sid]['schedules']
 for k,v in old[sid].items():
  if k not in ['schedules','scheduleStatus','departmentRemarks','semanticOperatingReview']:assert c[k]==v,(sid,k)
 for k,v in old[sid]['departmentRemarks'].items():assert c['departmentRemarks'][k].startswith(v)
 p=added[sid];ranges=[(dt.date.fromisoformat(a),dt.date.fromisoformat(b)) for a,b in p['exclusions']]
 expected=set()
 for wd,a,b,room in p['directSlots']:
  day=dt.date(2026,9,1)
  day+=dt.timedelta(days=(wd-day.isoweekday())%7)
  while day<=dt.date(2026,12,21):
   if day.isoformat() not in ['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'] and not any(x<=day<=y for x,y in ranges):expected.add((day.isoformat(),wd,a,b,room))
   day+=dt.timedelta(days=7)
 actual={(m['date'],m['weekday'],m['startMinute'],m['endMinute'],m['classroom']) for m in c['schedules']}
 assert actual==expected and len(actual)==len(c['schedules']),sid
 assert all(m['weekday']==dt.date.fromisoformat(m['date']).isoweekday() and 'deliveryMode' not in m for m in c['schedules'])
assert sum(bool(c['schedules']) for c in old.values())==1906
assert sum(len(c['schedules']) for c in old.values())==35970
assert sum(bool(c['schedules']) for c in new.values())==1947
assert sum(len(c['schedules']) for c in new.values())==36548
assert len(review)==73 and sum(r['selected'] for r in review)==41
print('PASS source-only: 4666 identity /4625 other deep /1906 old35970 dates /41 new578 exact weekdays clocks rooms, three-mode Drive not yet run')
