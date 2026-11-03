"""Add only literal published school holiday makeup plans, preserving all old meetings."""
from pathlib import Path
import json,copy,datetime
P=Path(__file__).parent
baseline=P.parent/'kau-main-2026-2.public83-partial-v1.json';(P/'baseline-public83-frozen.json').write_bytes(baseline.read_bytes());d=json.loads(baseline.read_text());source=json.loads((P/'current-published-holiday-makeup-education.json').read_text());proofs=[]
for c in d['courses']:
 if not c['schedules']:continue
 prior=copy.deepcopy(c['schedules']);added=[]
 for pair in source['publishedPairs']:
  holiday=datetime.date.fromisoformat(pair['holiday']);target=datetime.date.fromisoformat(pair['makeupDate']);blocks={(m['startMinute'],m['endMinute'],m['classroom']) for m in prior if m['weekday']==holiday.isoweekday()}
  for a,b,room in sorted(blocks):
   added.append({'date':target.isoformat(),'weekday':target.isoweekday(),'startMinute':a,'endMinute':b,'classroom':room})
   proofs.append({'sourceId':c['sourceId'],'nativeLectureNumber':c['sourceId'].split('/')[-1],'originalHoliday':holiday.isoformat(),'sourceWeekday':holiday.isoweekday(),'publishedMakeupDate':target.isoformat(),'actualDateWeekday':target.isoweekday(),'sourceStartMinute':a,'sourceEndMinute':b,'sourceRoom':room,'actualTeacherConfirmationPending':True})
 if not added:continue
 c['schedules']=prior+sorted(added,key=lambda x:(x['date'],x['startMinute']))
 c['period']={'startDate':c['period']['startDate'],'endDate':max(m['date'] for m in added)}
 c['sourceEducationalMetadata']={'priorPublishedReservationPeriod':json.loads(baseline.read_text())['courses'][d['courses'].index(c)]['period'],'publishedMakeupSource':source['sourceURL'],'publishedHolidayMakeupPlans':[p for p in proofs if p['sourceId']==c['sourceId']],'individualRoomStillUnpublished':True,'actualTeacherMakeupConfirmationPending':True,'actualAttendanceConfirmed':False,'reservationOnly':True}
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]+='\n현재 학교 지정 보강 예약 계획이며 실제 보강 진행 여부·구체적 일정은 담당 교원 확인 필요. 원래 수업의 공개 시각을 적용했고, 미공개 강의실은 빈 값 유지했습니다.'
d['candidateRevision']='public83-published-holiday-makeup-v2';d['reservationOnly']=True;d['completionClaim']=False;d['wholeOperatingVerified']=False;d['wholeSchoolCourseCoverageComplete']=False
(P/'kau-main-2026-2.public83-published-makeup-v2.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
(P/'audit.json').write_text(json.dumps({'wholeNative83':83,'existing22PlannedPreserved':True,'oldMeetings332PrefixPreserved':True,'newMakeupMeetings18':len(proofs),'affectedExistingCourses14':len({p['sourceId'] for p in proofs}),'currentWholeNativeDiscovered':False,'finalNativeClosureReconciled':False,'fullWhole83Retained':True,'scheduledCourses22':22,'meetings350':sum(len(c['schedules']) for c in d['courses']),'held61DeepUnchanged':True,'proofs':proofs,'actualFixture':'pending','SDKUsed':False},ensure_ascii=False,indent=2)+'\n');print('83/22/350,14courses+18plannedmakeups')
