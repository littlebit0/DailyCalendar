"""Reviewed isolated exceptions; retained public education only, no SDK/network."""
import copy
import hashlib
import json
import re
from datetime import date, timedelta
from pathlib import Path
ROOT = Path(__file__).resolve().parent
PRIOR = ROOT.parent
V5 = PRIOR / 'hufs-isolated-operation-v6-20261009'
def load(p): return json.loads(p.read_text())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(n,v): (ROOT/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
# Manual complete retained operating-context decisions, never lexical activation.
REVIEWS = {
'D03523101': {'examDates':['2026-10-20'],'reason':'Printed middle Oct20; printed final Dec15 outside ordinary.'},
'C01309501': {'remoteDates':['2026-09-11'],'examDates':['2026-10-23'],'reason':'Only Sept11 trip online-or-VOD ambiguous delivery omitted; other current dated native lectures and discussions ordinary.'},
'D01214301': {'examDates':['2026-10-23'],'reason':'Team teaching has ordinary current dates/room; Dec11 school-dependent makeup ambiguity outside ordinary only.'},
'D03530101': {'reason':'Only Sept25 and Dec11 no-class instructions; latter described as public holiday inconsistently but outside ordinary boundary. No whole assessment or remote delivery asserted.'},
'E11301102': {'middle':True,'reason':'Holiday makeups and email assignment deadline do not cancel other regular classes; no arbitrary submission-clock events.'},
'V43501101': {'examDates':['2026-10-20'],'reason':'Direct Oct20 No class/Online Quiz omitted; other dated writing instruction ordinary.'},
'E11456101': {'examDates':['2026-10-29'],'reason':'Direct Oct29 individual middle assessment overrides school generic interval for this course; preserve Oct22.'},
'E11456102': {'examDates':['2026-10-29'],'reason':'Direct Oct29 individual middle assessment overrides school generic interval for this course; preserve Oct22.'},
'V43201201': {'examDates':['2026-10-22'],'reason':'Direct exam Oct22 plus Sept24 holiday isolated; future makeup not generated.'},
'V43203201': {'examDates':['2026-10-22'],'reason':'Direct exam Oct22 plus Sept24 holiday isolated; future makeup not generated.'},
'Y91159101': {'middle':True,'reason':'Only Oct5 holiday and individual middle assessment; other current native ordinary unchanged.'},
'Y91141101': {'middle':True,'reason':'Explicit holiday/makeup split only; individual middle excluded using own direct exam range.'},
'Y91139101': {'middle':True,'reason':'Explicit holiday/makeup split only; individual middle excluded using own direct exam range.'},
'Q02003101': {'examDates':['2026-10-22'],'reason':'Direct Oct22 assessment isolated.'},
'Q02001109': {'examDates':['2026-10-23'],'reason':'Printed Oct23 assessment labelled6th wins; no week arithmetic or generic8th Nov6 exclusion.'},
'Y91149101': {'examDates':['2026-10-22'],'reason':'Printed Oct22 assessment labelled7th wins; preserve Oct29 labelled8th ordinary.'},
'U54120301': {'examDates':['2026-11-02'],'reason':'Explicit middle assessment postponed Nov2; preserve Oct26 direct ordinary.'},
'U54129301': {'examDates':['2026-10-23'],'reason':'Direct holiday and assessment dates only; shifted future makeups not generated.'},
'Y21154101': {'remoteDates':['2026-10-05','2026-10-19'],'examDates':['2026-10-26'],'reason':'Two directly printed VOD dates only; Oct5 also holiday. Dec7 TBA is unspecified curriculum topic, no cancellation/delivery/clock override.'},
'U74111101': {'examDates':['2026-10-23'],'reason':'Explicit in-person lecture current dated plan; course international security topic not military university or exclusion; seventh/eighth week numbering shifted by holidays.'},
'U76270201': {'examDates':['2026-10-23'],'reason':'Explicit in-person lecture current dated plan; holidays and exam printed separately, later makeup unknownclock omitted.'},
}
HOLIDAYS={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
proofs=[]; summary={}
for campus in ['seoul','global']:
 bp=V5/f'hufs-{campus}-2026-2.isolated-operation-v6-research.json'; base=load(bp); candidate=copy.deepcopy(base)
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
 name=f'hufs-{campus}-2026-2.isolated-operation-v7-research.json';save(name,candidate)
 summary[campus]={'candidateFile':name,'sha256':sha(ROOT/name),'whole':len(candidate['courses']),'scheduled':sum(bool(c['schedules']) for c in candidate['courses']),'reservations':sum(len(c['schedules']) for c in candidate['courses'])}
assert len(proofs)==21
save('reviewed21-source-proofs.json',proofs)
save('candidate-audit.json',{'sourceOnly':True,'modelValidated':False,'completionClaim':False,'sdkUsed':False,'productEdited':False,'priorScheduled':2404,'priorReservations':34814,'newCourses':len(proofs),'newReservations':sum(len(p['reservations']) for p in proofs),'campuses':summary,'priorV5TwelveMeaningfulHoldsPreserved':True,'allOutsideReviewed21DeepUnchanged':True,'wholeSupportedAttendanceClaim':False})
print(json.dumps(summary));print('new',len(proofs),sum(len(p['reservations']) for p in proofs))
