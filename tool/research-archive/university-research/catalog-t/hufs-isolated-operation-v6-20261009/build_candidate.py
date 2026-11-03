"""Reviewed isolated exceptions; retained public education only, no SDK/network."""
import copy
import hashlib
import json
import re
from datetime import date, timedelta
from pathlib import Path
ROOT = Path(__file__).resolve().parent
PRIOR = ROOT.parent
V5 = PRIOR / 'hufs-late-operation-v5-20261009'
def load(p): return json.loads(p.read_text())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(n,v): (ROOT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
# Manual complete retained operating-context decisions, never lexical activation.
REVIEWS = {
'A04310301': {'remoteDates':['2026-09-16'],'middle':True,'reason':'Only printed 9/16 VOD omitted; other native Wednesdays remain ordinary.'},
'A04464301': {'remoteDates':['2026-09-10','2026-09-17','2026-09-24'],'examDates':['2026-10-22'],'reason':'Three printed VOD dates and direct 10/22 assessment omitted.'},
'A02522101': {'middle':True,'reason':'9/24 holiday and 15th makeup do not cancel other weekly native classes.'},
'D03529103': {'examDates':['2026-10-21'],'reason':'Direct 10/21 assessment only; 12/16 final outside ordinary bounds.'},
'D03529105': {'examDates':['2026-10-21'],'reason':'Direct 10/21 assessment only; 12/16 final outside ordinary bounds.'},
'D01421101': {'examDates':['2026-10-20'],'reason':'Direct 10/20 assessment only; 12/15 final outside ordinary bounds.'},
'D02466101': {'examDates':['2026-10-22'],'reason':'Printed 10/22 overrides seventh-week label; no arithmetic week date.'},
'D02466201': {'examDates':['2026-10-22'],'reason':'Printed 10/22 overrides seventh-week label; no arithmetic week date.'},
'D02466203': {'examDates':['2026-10-23'],'reason':'Printed 10/23 overrides seventh-week label; no arithmetic week date.'},
'C01324504': {'middle':True,'reason':'Printed holiday/makeup dates isolated; unknown makeup HH not generated.'},
'C01324505': {'middle':True,'reason':'Printed holiday/makeup dates isolated; unknown makeup HH not generated.'},
'D02357403': {'middle':True,'reason':'Explicit weekly assigned classroom lecture; 9/24 holiday and later makeup isolated.'},
'D02357404': {'middle':True,'reason':'Explicit weekly assigned classroom lecture; 9/24 holiday and later makeup isolated.'},
'C04492201': {'reason':'Explicit middle-period class continues despite assignment replacement; preserve 10/22 ordinary.'},
'A40144101': {'middle':True,'reason':'Printed 9/25 and 10/9 holidays isolated; middle assessment omitted conservatively.'},
'A03392101': {'middle':True,'reason':'Printed 10/5 holiday and later makeup isolated; ordinary presentations preserved.'},
'R05351101': {'middle':True,'reason':'Printed 10/5 holiday and 12/14 makeup isolated, no makeup clock generated.'},
'Q02018101': {'onlyWeekday':5,'middle':True,'reason':'Monday normally VOD at individual convenience; other Friday native offline question class preserved.'},
}
for section in range(5,11):
 REVIEWS[f'Y121034{section:02}']={'prefixEnd':'2026-10-19','reason':'Employment first half ordinary native prefix; course eighth-week explicitly own midterm no class, own Oct20–26 direct calendar boundary. Ninth–fourteenth VOD and fifteenth unspecified makeup omitted, no week arithmetic.'}
HOLIDAYS={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
proofs=[]; summary={}
for campus in ['seoul','global']:
 bp=V5/f'hufs-{campus}-2026-2.late-operation-v5-research.json'; base=load(bp); candidate=copy.deepcopy(base)
 native={c['sourceId']:c for c in load(PRIOR/f'hufs-{campus}-2026-2.whole-candidate.json')['courses']}
 for c in candidate['courses']:
  key=c['courseCode']+c['section']
  if key not in REVIEWS: continue
  d=REVIEWS[key]; assert not c['schedules']
  pp=PRIOR/'hufs-public-operating-plans'/f"{'H1' if campus=='seoul' else 'H2'}-{key}.json"; plan=load(pp)
  assert plan['key']==key and plan['fields']['identity'].endswith(key)
  assert plan['fields']['schedule'].split('\n')[0]==c['sourceSchedule']
  rules=native[c['sourceId']]['schedules']; selected=[r for r in rules if not d.get('onlyWeekday') or r['weekday']==d['onlyWeekday']]
  dates=[]; excludes=[]; cursor=date(2026,9,1)
  while cursor<=date(2026,12,7):
   for r in selected:
    if cursor.isoweekday()!=r['weekday']: continue
    iso=cursor.isoformat(); reason=None
    if iso in HOLIDAYS: reason='ownHoliday'
    elif iso in d.get('remoteDates',[]): reason='explicitVODDate'
    elif iso in d.get('examDates',[]): reason='printedAssessmentDateUnknownClock'
    elif d.get('middle') and date(2026,10,20)<=cursor<=date(2026,10,26): reason='individualMiddleAssessmentInOwnDirectCalendar'
    elif d.get('prefixEnd') and iso>d['prefixEnd']: reason='middleNoClassThenExplicitBackHalfVODOrUnknownMakeup'
    if reason: excludes.append({'date':iso,'reason':reason,'nativeRule':r})
    else: dates.append({**r,'date':iso})
   cursor+=timedelta(days=1)
  assert dates
  c['schedules']=dates;c['scheduleStatus']='scheduled'
  note='公開 정규 주간 예약 계획; 실제 개별 출석일 미확정. 원문 특정 비대면·휴강·평가 차시 제외; 시각 미확정 보강·시험 생성 없음'.replace('公開','공개')
  if d.get('prefixEnd'): note+='; 전반부만 자체 중간시험 시작 전 10/19까지 예약, 후반 녹화 차시 제외'
  if d.get('onlyWeekday'): note+='; 월요일 녹화 차시 제외, 금요일 정규 예약만 제공'
  c['departmentRemarks']={dep:value.replace(' · 공개 운영 일정 확인 중: 자동 시간 생성 보류','')+' · '+note for dep,value in c['departmentRemarks'].items()}
  proofs.append({'sourceId':c['sourceId'],'baselinePath':str(bp),'baselineSHA256':sha(bp),'sourcePlanPath':str(pp),'sourcePlanSHA256':sha(pp),'educationPlan':plan,'priorHeldCourse':next(x for x in base['courses'] if x['sourceId']==c['sourceId']),'nativeWholeCourse':native[c['sourceId']],'decision':d,'selectedNativeRules':selected,'reservations':dates,'excludedNativeSlots':excludes,'derivedDates':True,'attendanceConfirmed':False,'sourceSnapshotDate':'2026-10-08','freshRequeryPerformed':False,'userModeForced':False})
 name=f'hufs-{campus}-2026-2.isolated-operation-v6-research.json';save(name,candidate)
 summary[campus]={'candidateFile':name,'sha256':sha(ROOT/name),'whole':len(candidate['courses']),'scheduled':sum(bool(c['schedules']) for c in candidate['courses']),'reservations':sum(len(c['schedules']) for c in candidate['courses'])}
assert len(proofs)==24
save('reviewed24-source-proofs.json',proofs)
save('candidate-audit.json',{'sourceOnly':True,'modelValidated':False,'completionClaim':False,'sdkUsed':False,'productEdited':False,'priorScheduled':2380,'priorReservations':34568,'newCourses':len(proofs),'newReservations':sum(len(p['reservations']) for p in proofs),'campuses':summary,'priorV5TwelveMeaningfulHoldsPreserved':True,'allOutsideReviewed24DeepUnchanged':True,'wholeSupportedAttendanceClaim':False})
print(json.dumps(summary));print('new',len(proofs),sum(len(p['reservations']) for p in proofs))
