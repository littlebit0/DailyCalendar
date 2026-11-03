"""Research only: preserve whole metadata and known7; proposed2 confirmed meetings only."""
import json, hashlib
from pathlib import Path
R=Path(__file__).resolve().parent
base_path=R/'cnu-unknown-2026-2.whole-checkpoint-next-seven.json'
original=json.loads(base_path.read_text()); base=json.loads(base_path.read_text())
by={c['sourceEducation']['courseId']:c for c in base['courses']}
proof=json.loads((R/'cnu-two-proposed-final-week-blocking-proof-20261008.json').read_text())
for case in proof['cases']:
 cid=case['courseId'];c=by[cid];exam=case['explicitFinalExam'];makeup=case['centralThursdayMakeup']
 meetings=[{'date':date,'weekday':4,'startMinute':exam['startMinutes'],'endMinute':exam['endMinutes'],'classroom':exam['room'],'mode':'inPerson'} for date in ['2026-10-22','2026-12-17']]
 meetings.sort(key=lambda m:m['date'])
 c['scheduleStatus']='scheduled';c['schedules']=meetings
 # This bound scopes known meetings only; it does not assert normal course beginning/ending.
 c['period']={'startDate':'2026-10-22','endDate':'2026-12-17'}
 e=c['sourceEducation'];e.pop('derivedBlockingExplanation',None)
 e.update(registrationStatus='partiallyScheduledConfirmedExamsOnly', individualReviewStatus='Known exam2 directly confirmed; ordinary dates including final-week Tuesday and central makeup actual operation not confirmed',sourcePlanResponseSHA256=case['sourceResponseSHA256'],datesOrClockInvented=False,partialSchedule=True,periodMeaning='Outer bound of confirmed dated meetings only; not normal course teaching period',unconfirmedScheduleParts=['ordinary teaching dates','2026-12-15 Tuesday teaching/attendance','2026-12-10 individual makeup clock/mode/room'],unprintedSpecificRoomDates=[],directPrintedExamDates=['2026-10-22','2026-12-17'],schoolRuleDerivedMakeupDates=[],sourceSchoolMakeupProof='cnu-current-makeup-policy-20261008.json',sourceFixedTimeRuleProof='cnu-current-rule-282-20261008-text.txt Article32(1)')
 for department,note in c.get('departmentRemarks',{}).items():
  c['departmentRemarks'][department]=note+'\n일반 수업 날짜 확인 중: 지금 반영된 일정은 확인된 중간·기말시험 2회입니다. 12월 15일 수업 여부와 12월 10일 개별 보강의 실제 시각·방식·장소는 미확인입니다.'
old={c['sourceEducation']['courseId']:c for c in original['courses']}
assert all(c==old[c['sourceEducation']['courseId']] for c in base['courses'] if c['sourceEducation']['courseId'] not in ['1004-7003-06','1004-7003-08'])
base['verificationScope']='Research next9: previous7 unchanged; proposed2 partial confirmed exams and exams only; Thursday makeup remains unconfirmed; all ordinary dates still unconfirmed'
f=R/'cnu-unknown-2026-2.whole-checkpoint-next-nine-partial.json';f.write_text(json.dumps(base,ensure_ascii=False,indent=2)+'\n')
a={'wholeRows':3888,'scheduledCourses':9,'scheduledMeetingCount':169,'additionalPartiallyScheduledCourses':2,'additionalConfirmedExamMeetings':4,'additionalSchoolRuleDerivedMakeupMeetings':0,'ordinaryMeetingDatesGenerated':0,'finalWeekTuesdayGenerated':False,'existingSevenCoursesJSONUnchanged':True,'previousWholeCheckpointUnchangedSHA256':hashlib.sha256(base_path.read_bytes()).hexdigest(),'nextPartialUnknownSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'wholeSupportClaim':False,'productionRegistrationApproved':False,'periodScope':'Each proposed2 period is known-meeting boundary only; no normal teaching period asserted.'}
(R/'cnu-next-nine-partial-candidate-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print('Research candidate9/169; known7 unchanged; proposed2 partial only')
