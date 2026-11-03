# coding: utf-8
"""Separate verified July clocks from known delivery gaps; never claim current whole scope."""
import collections,copy,json
from pathlib import Path
P=Path(__file__).resolve().parent
source=json.loads((P/'tuk-prepared-courses.json').read_text())
rows=[]
for old in source:
 r=copy.deepcopy(old);reasons=[]
 if old['scheduleStatus']=='unrecognized':reasons.append('Individual ER/fieldwork/service attendance dates not established by printed placeholder clock')
 if any('원격중심' in x for x in r['departmentRemarks'].values()):reasons.append('Published 원격중심 does not establish synchronous/asynchronous or per-week attendance')
 if r['courseCode']=='AFT21002':reasons.append('Current guide PDF29 printed26 explicitly says theory is video; which published weekday slot is video/onsite unposted')
 r['snapshotActualSlotCandidates']=copy.deepcopy(r['schedules'])
 r['individualBlockingReasons']=reasons
 if reasons:r['scheduleStatus']='unrecognized';r['schedules']=[]
 if r['courseCode']=='AFT21004':
  for meeting in r['schedules']:meeting['deliveryMode']='liveOnline'
  r['deliveryEvidence']='Official2026-2 guide PDF29 printed26: merged remark for AFT21003/AFT21004 specifies SiliconValleyexpert lecture via Zoom'
 r['researchOnly']=True;r['currentWholeCatalogVerified']=False;r['campusAssignmentVerified']=False
 r['scopeBlockingReasons']=['July15 snapshot not current whole catalog; latest official confirmation is integrated information system','Enterprise/industry curricula scope has missing published course identities','main scope is internal preparation alias; actual whole campus mapping pending']
 rows.append(r)
counts=dict(collections.Counter(r['scheduleStatus'] for r in rows));assert len(rows)==1431;assert counts=={'scheduled':1349,'unrecognized':65,'unscheduled':17}
assert all(not r['schedules'] for r in rows if r['individualBlockingReasons'])
assert len({r['sourceId'] for r in rows})==1431
(P/'tuk-research-safe-snapshot-candidates.json').write_text(json.dumps({'researchOnly':True,'productionReady':False,'completionClaim':False,'sourceScope':'July15 ordinary+fusion snapshot after latest observed36 closures','sourceRows':2242,'remainingUniqueCourses':1431,'countsWithinSnapshot':counts,'scopeBlocksMustNotBeDiscarded':True,'limitation':'Within-snapshot parsed clocks only. Not1349 verified current operational classes or complete university support.','courses':rows},ensure_ascii=False,indent=2))
print(counts)
