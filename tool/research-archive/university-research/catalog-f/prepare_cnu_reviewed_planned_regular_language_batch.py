"""Reviewed public regular plans; distinct from confirmed actual attendance."""
import json,hashlib,datetime,copy
from pathlib import Path
R=Path(__file__).resolve().parent
review_files=['cnu-reviewed-twelve-language-and-community-operation-contexts-20261008.json','cnu-reviewed-twentyeight-language-flipped-and-project-contexts-20261008.json','cnu-reviewed-eleven-english-presentation-and-video-homework-contexts-20261008.json']
approved=[row['courseId'] for name in review_files for row in json.loads((R/name).read_text())['reviews'] if row['plannedRegularAllowed']]
clock={a['courseId']:a for a in json.loads((R/'cnu-current-clock-projection.json').read_text())}
source=json.loads((R/'cnu-unknown-2026-2.whole-checkpoint-next83-planned-regular71.json').read_text());out=copy.deepcopy(source)
excluded={'2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-12-08','2026-12-09','2026-12-10','2026-12-11'}
start=datetime.date(2026,9,1);end=datetime.date(2026,12,18);all_dates=[start+datetime.timedelta(days=i) for i in range((end-start).days+1)]
notes='학교 공시 정규수업 계획입니다. 날짜별 실제 출석 확인 기록이 아니며 시험·보강은 학교 공지와 확정 시각을 확인하세요. 정기휴업일과 12월 8~11일 보충기간은 정규 반복에서 제외했습니다.'
oldwait='수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.'
reviews=[]
for c in out['courses']:
 cid=c['sourceEducation']['courseId']
 if cid not in approved:continue
 assert c['scheduleStatus']!='scheduled'
 plan=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());assert plan['header']
 slots=clock[cid]['actualClockMeetings'];assert slots
 meetings=[{'date':d.isoformat(),'weekday':m['weekday'],'startMinute':m['startMinute'],'endMinute':m['endMinute'],'classroom':m['location'],'deliveryMode':'inPerson'} for d in all_dates if d.isoformat() not in excluded for m in slots if d.isoweekday()==m['weekday']]
 assert meetings
 c['scheduleStatus']='scheduled';c['schedules']=meetings;c['period']={'startDate':start.isoformat(),'endDate':end.isoformat()}
 evidence={'basis':'publishedRegularTimetable','actualAttendanceIndividuallyConfirmed':False,'officialTeachingPeriodProof':'cnu-2026-2-exchange-guide-selected-education.json','officialRuleProof':'cnu-planned-regular-vs-actual-dated-authority-20261008.json','normalStartDate':start.isoformat(),'normalEndDate':end.isoformat(),'excludedNormalDates':sorted(excluded),'excludedMakeupMeetingsIndividuallyConfirmed':False,'examMeetingsGenerated':False,'genericExamWeekDoesNotInvalidateRegularPlan':True,'sourcePlanResponseSHA256':plan['sourceResponseSHA256']}
 c['scheduleEvidence']=evidence;e=c['sourceEducation'];e.pop('derivedBlockingExplanation',None);e.update(registrationStatus='scheduledPublishedRegularPlan',scheduleEvidence=evidence,actualAttendanceIndividuallyConfirmed=False,partialSchedule=False,datesMeaning='Derived current published regular timetable plan; not independently printed attendance or exam dates')
 for dep,text in c['departmentRemarks'].items():c['departmentRemarks'][dep]='\n'.join(line for line in text.splitlines() if line!=oldwait)+'\n'+notes
 reviews.append({'courseId':cid,'sourceResponseSHA256':plan['sourceResponseSHA256'],'currentDisplayedClockRoom':e['originalEducationFields'].get('TMTBL_INFO') or c['sourceSchedule'],'plannedRegularAllowed':True,'actualAttendanceIndividuallyConfirmed':False,'finding':'Selected current teaching context reviewed: ordinary lecture/discussion/theory/lab with no definite date/weekday/room/delivery change. Topic films, repeated learning and generic exams do not establish VOD window or no class. Conditional remote branch does not establish actual change.','selectedEducationalCacheScope':'Preserved educational fields only; old contact-containing line omission limits full-original absence claims.'})
assert len(reviews)==45
for old,new in zip(source['courses'],out['courses']):
 if old['sourceEducation']['courseId'] not in approved:assert old==new
 else:
  for field in ['professor','courseName','courseCode','section','classification','departmentClassifications','credits','departmentCredits','departments','sourceSchedule','sourceClassroom']:assert old[field]==new[field]
  assert old['sourceEducation']['originalEducationFields']==new['sourceEducation']['originalEducationFields']
  assert old['sourceEducation']['actualDisplayedClocks']==new['sourceEducation']['actualDisplayedClocks']
out['verificationScope']='Research next128: previous83/1359 unchanged including actual12/172;45 additional reviewed published regular timetable plans, no actual attendance or exam claim.'
f=R/'cnu-unknown-2026-2.whole-checkpoint-next128-planned-regular116.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
(R/'cnu-reviewed-fortyfive-language-plans-approved-projection-20261008.json').write_text(json.dumps({'reviews':reviews,'authority':'cnu-planned-regular-vs-actual-dated-authority-20261008.json'},ensure_ascii=False,indent=2)+'\n')
audit={'candidate':f.name,'candidateSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'baseUnknownSHA256':hashlib.sha256((R/'cnu-unknown-2026-2.whole-checkpoint-next83-planned-regular71.json').read_bytes()).hexdigest(),'wholeRows':3888,'existingActualDatedCourses':12,'existingActualDatedMeetings':172,'existingActualDatedObjectsUnchanged':True,'newPublishedRegularPlanCourses':45,'newPlannedMeetings':sum(len(c['schedules']) for c in out['courses'] if c['sourceEducation']['courseId'] in approved),'plannedCourseIds':approved,'allOther3843RowsUnchanged':True,'previous83And1359MeetingsUnchanged':True,'originalEducationAndRestrictionsUnchanged':True,'actualAttendanceIndividuallyConfirmed':False,'fullSchoolSupportClaim':False,'exclusions':sorted(excluded),'derivationProof':'cnu-planned-regular-vs-actual-dated-authority-20261008.json'}
base_audit=json.loads((R/'cnu-next83-planned-regular71-candidate-audit.json').read_text())
audit.update(totalPlannedCourseIds=base_audit['totalPlannedCourseIds']+approved,totalScheduledCourses=128,totalPlannedMeetings=1187+audit['newPlannedMeetings'],totalMeetings=1359+audit['newPlannedMeetings'])
(R/'cnu-next128-planned-regular116-candidate-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(json.dumps(audit,ensure_ascii=False))
