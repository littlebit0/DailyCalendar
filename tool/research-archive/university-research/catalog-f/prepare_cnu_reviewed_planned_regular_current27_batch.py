"""Reviewed public regular plans; distinct from confirmed actual attendance."""
import json,hashlib,datetime,copy
from pathlib import Path
R=Path(__file__).resolve().parent
review_files=json.loads((R/'cnu-proposed27-current-public-plan-context-selection.json').read_text())['reviewFiles']
approved=[row['courseId'] for name in review_files for row in json.loads((R/name).read_text())['reviews'] if row['plannedRegularAllowed'] and row['courseId'] != '1102-2012-01']
clock={a['courseId']:a for a in json.loads((R/'cnu-current-clock-projection.json').read_text())}
recovered=json.loads((R/'cnu-proposed27-preserved-context-recovery-audit.json').read_text());assert recovered['finished'] and recovered['processedPlans']==27
assert not any(x['publicCatalogChangedFields'] or x['newFieldTeachingWeeks'] or x['currentSceneHours'] for x in recovered['results'])
source=json.loads((R/'cnu-unknown-2026-2.whole-checkpoint-next225-planned-regular213-eligibility-v2.json').read_text());out=copy.deepcopy(source)
excluded={'2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-12-08','2026-12-09','2026-12-10','2026-12-11'}
start=datetime.date(2026,9,1);end=datetime.date(2026,12,18);all_dates=[start+datetime.timedelta(days=i) for i in range((end-start).days+1)]
notes='학교 공시 정규수업 계획입니다. 날짜별 실제 출석 확인 기록이 아니며 시험·보강은 학교 공지와 확정 시각을 확인하세요. 정기휴업일과 12월 8~11일 보충기간은 정규 반복에서 제외했습니다.'
oldwait='수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.'
reviews=[]
for c in out['courses']:
 cid=c['sourceEducation']['courseId']
 if cid not in approved:continue
 assert c['scheduleStatus']!='scheduled'
 plan=json.loads((R/'cnu-proposed27-recovered-education-20261008'/f'{cid}.json').read_text());assert plan['header']
 assert plan['header'][0].get('OPEN_SHTM_CD_NM')=='2학기'
 assert not any(str(w.get('CLS_METHOD_FIELD',0))=='1' for w in plan['weeks'])
 assert all(h.get('LSN_MTHD_SCENE') in [None,0,'0',''] for h in plan['header'])
 actual=plan['header'][0].get('TLSN_ANNM')
 if actual:assert ''.join(actual.split())==''.join(c['sourceSchedule'].split())
 slots=clock[cid]['actualClockMeetings'];assert slots
 meetings=[{'date':d.isoformat(),'weekday':m['weekday'],'startMinute':m['startMinute'],'endMinute':m['endMinute'],'classroom':m['location'],'deliveryMode':'inPerson'} for d in all_dates if d.isoformat() not in excluded for m in slots if d.isoweekday()==m['weekday']]
 assert meetings
 c['scheduleStatus']='scheduled';c['schedules']=meetings;c['period']={'startDate':start.isoformat(),'endDate':end.isoformat()}
 evidence={'basis':'publishedRegularTimetable','actualAttendanceIndividuallyConfirmed':False,'officialTeachingPeriodProof':'cnu-2026-2-exchange-guide-selected-education.json','officialRuleProof':'cnu-planned-regular-vs-actual-dated-authority-20261008.json','normalStartDate':start.isoformat(),'normalEndDate':end.isoformat(),'excludedNormalDates':sorted(excluded),'excludedMakeupMeetingsIndividuallyConfirmed':False,'examMeetingsGenerated':False,'genericExamWeekDoesNotInvalidateRegularPlan':True,'sourcePlanResponseSHA256':plan['sourceResponseSHA256']}
 c['scheduleEvidence']=evidence;e=c['sourceEducation'];e.pop('derivedBlockingExplanation',None);e.update(registrationStatus='scheduledPublishedRegularPlan',scheduleEvidence=evidence,actualAttendanceIndividuallyConfirmed=False,partialSchedule=False,datesMeaning='Derived current published regular timetable plan; not independently printed attendance or exam dates')
 for dep,text in c['departmentRemarks'].items():c['departmentRemarks'][dep]='\n'.join(line for line in text.splitlines() if line!=oldwait)+'\n'+notes
 reviews.append({'courseId':cid,'sourceResponseSHA256':plan['sourceResponseSHA256'],'currentDisplayedClockRoom':e['originalEducationFields'].get('TMTBL_INFO') or c['sourceSchedule'],'plannedRegularAllowed':True,'actualAttendanceIndividuallyConfirmed':False,'finding':'Selected current teaching context reviewed: ordinary lecture/discussion/theory/lab with no definite date/weekday/room/delivery change. Topic films, repeated learning and generic exams do not establish VOD window or no class. Conditional remote branch does not establish actual change.','selectedEducationalCacheScope':'Current public header and all weekly educational text/flags projected with token-only redaction; adjacent education preserved. Catalog/public teacher metadata compared unchanged. Source elective/category/native restrictions retained.'})
assert len(reviews)==27
for old,new in zip(source['courses'],out['courses']):
 if old['sourceEducation']['courseId'] not in approved:assert old==new
 else:
  for field in ['professor','courseName','courseCode','section','classification','departmentClassifications','credits','departmentCredits','departments','sourceSchedule','sourceClassroom']:assert old[field]==new[field]
  assert old['sourceEducation']['originalEducationFields']==new['sourceEducation']['originalEducationFields']
  assert old['sourceEducation']['actualDisplayedClocks']==new['sourceEducation']['actualDisplayedClocks']
out['verificationScope']='Research next253: previous225/4702 unchanged including actual12/172;27 additional reviewed published regular timetable plans, no actual attendance or exam claim.'
f=R/'cnu-unknown-2026-2.whole-checkpoint-next252-planned-regular240.json';f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
(R/'cnu-reviewed-twentyseven-current-token-recovered-approved-projection-20261008.json').write_text(json.dumps({'reviews':reviews,'authority':'cnu-planned-regular-vs-actual-dated-authority-20261008.json'},ensure_ascii=False,indent=2)+'\n')
audit={'candidate':f.name,'candidateSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'baseUnknownSHA256':hashlib.sha256((R/'cnu-unknown-2026-2.whole-checkpoint-next225-planned-regular213-eligibility-v2.json').read_bytes()).hexdigest(),'wholeRows':3888,'existingActualDatedCourses':12,'existingActualDatedMeetings':172,'existingActualDatedObjectsUnchanged':True,'newPublishedRegularPlanCourses':27,'newPlannedMeetings':sum(len(c['schedules']) for c in out['courses'] if c['sourceEducation']['courseId'] in approved),'plannedCourseIds':approved,'allOther3861RowsUnchanged':True,'previous225And4702MeetingsUnchanged':True,'originalEducationAndRestrictionsUnchanged':True,'actualAttendanceIndividuallyConfirmed':False,'fullSchoolSupportClaim':False,'exclusions':sorted(excluded),'derivationProof':'cnu-planned-regular-vs-actual-dated-authority-20261008.json'}
base_audit=json.loads((R/'cnu-next225-planned-regular213-eligibility-v2-candidate-audit.json').read_text())
audit.update(totalPlannedCourseIds=base_audit['totalPlannedCourseIds']+approved,totalScheduledCourses=252,totalPlannedMeetings=4530+audit['newPlannedMeetings'],totalMeetings=4702+audit['newPlannedMeetings'])
(R/'cnu-next252-planned-regular240-candidate-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print(json.dumps(audit,ensure_ascii=False))
