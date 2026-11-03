# -*- coding: utf-8 -*-
from pathlib import Path
from datetime import date,timedelta
import json,copy,hashlib,collections,re
P=Path('work/university-research/catalog-c/syu-current-career-native-clock-review-v5-20261009');P.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(n,d):(P/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
B=Path('assets/timetable/syu-main-2026-2.json');before=json.loads(B.read_text());save('prior-current-1391-94-956-baseline.json',before)
N=Path('work/university-research/catalog-l/syu-2026-2-public-all-rows.json');native={r[0]:r for r in json.loads(N.read_text())}
Q=Path('work/university-research/catalog-c/syu-general-clock-review-20261009');R=Path('work/university-research/catalog-c/syu-other-undergraduate-clock-review-20261009');C=Q/'current-own-calendar-reservation-scope.json';calendar=json.loads(C.read_text())
ids=['62','65','64','63','66','67','68','69','70','71','72','1540','296','297','302','298','305','304','303'];sourceIds={'syu/main/2026-2/'+i for i in ids}
days='2026-09-01 2026-09-08 2026-09-15 2026-09-22 2026-09-29 2026-10-13 2026-11-03 2026-11-10 2026-11-17 2026-11-24 2026-12-01'.split()
# Independent actual calendar derivation from own dates; no WKORD inference.
derived=[];dt=date(2026,9,1)
while dt<=date(2026,12,7):
 if dt.isoweekday()==2 and dt.isoformat() not in calendar['excludedConfirmedCalendarHolidayDates']+['2026-10-06','2026-10-07'] and not date(2026,10,20)<=dt<=date(2026,11,2):derived.append(dt.isoformat())
 dt+=timedelta(days=1)
assert days==derived
out=copy.deepcopy(before);proofs=[]
for c in out['courses']:
 if c['sourceId'] not in sourceIds:continue
 nr=c['sourceEducation']['nativeLectureNumber'];old=next(x for x in before['courses'] if x['sourceId']==c['sourceId']);a=c['sourceEducation']['nativePublicCells'];assert a==native[nr]
 assert c['courseName']=='인생설계와 진로 II' and c['courseCode']=='1006074' and c['section']=='' and a[13:]==['N','',''] and not c['schedules']
 assert c['sourceEducation']['currentNativeClosureCompared'] and not c['sourceEducation']['closed']
 isNursing=nr in ids[:12];dept='간호학과' if isNursing else '물리치료학과';assert c['departments']==[dept]
 assert c['sourceSchedule']==('화9' if isNursing else '화5')
 start,end=(1020,1070) if isNursing else (780,830)
 assert bool(c['sourceClassroom']) if isNursing else c['sourceClassroom']==''
 c['schedules']=[{'date':d,'weekday':2,'startMinute':start,'endMinute':end,'classroom':c['sourceClassroom']} for d in days];c['scheduleStatus']='scheduled';c['period']={'startDate':'2026-09-01','endDate':'2026-12-07'}
 prevRemarks=copy.deepcopy(c['departmentRemarks']);warning=' 전체 대학 교시 시각 미확인 또는 별도 운영/온라인/원문 잘림으로 일정 보류. 채플 시각을 일반 교과목에 적용하지 않았습니다.'
 note=f' 현재2026-2 {dept} 학부 시간표의 해당학과 자체 교시 범례와 현재9/7 전체공개원문 강좌번호{nr}·교과목코드1006074·원문교수·화요일 교시를 대조한 공개 정규 주간 예약 계획. 학과 이미지에는 이 강좌의 공식코드/분반 및 교수전체명이 미게시이므로 이미지에서 이를 읽었다고 주장하지 않습니다. 원문 분반은 미공개 빈값 유지. '
 note+=('간호학과 원문 화9 및 자체9교시17:00~17:50; 이미지의 동일화9 인생설계와진로 블록에는 여러교수 약자/각교실이 함께표시되며 실제개별배정/출석은 미확인입니다. 현재전체원문 교수/교실을 그대로 보존하며 약자를 새교수명으로 생성하지 않습니다. ' if isNursing else '물리치료학과 2학년 원문 화5 및 자체5교시13:00~13:50; 이미지 동일화5 인생설계와진로II 블록에 개별교수/교실 미게시. 현재전체원문 교수를 그대로 보존하고 교실 원문빈값 그대로 표시하며 다른교실을 생성하지 않습니다. ')
 note+='자체9/1개강부터12/8~14기말직전12/7까지의 보수적 예약범위이며 실제종강일/개별운영완료확정아님.10/20~26중간·10/27~11/2온라인권장기간 및10/6행사일은 개별운영미확인으로 예약제외하며 전교휴강/필수녹화주장아님. 다른학과로시각전파0,실제출석/최신보호포탈변경미확인. 사용자선택3수업모드 유지.'
 for dep in c['departmentRemarks']:c['departmentRemarks'][dep]=c['departmentRemarks'][dep].replace(warning,'')+note
 c['sourceEducation'].update(previousResearchDepartmentRemarks=prevRemarks,scopedCurrentUndergraduateClockVerified=True,scopedClockDepartment=dept,sourceImageCourseCodePublished=False,sourceImageOfficialSectionPublished=False,sourceImageFullProfessorForThisNativeOfferingPublished=False,imageProfessorInitialsNotExpanded=True,imageOfferingIdentityNotInvented=True,wholeUniversityClockConfirmed=False,individuallyPublishedDates=False,actualOperatingVerified=False,reservationScope='current own department period clock + exact current native offering weekday; regular booking, not confirmed attendance')
 proofs.append({'sourceId':c['sourceId'],'nativeLectureNumber':nr,'originalWholeObject':old,'nativeAllEducationalCells':a,'nativeCourseCode':'1006074','nativeSection':'','nativeProfessor':c['professor'],'nativeDepartment':dept,'nativeGrade':a[3],'nativeWeekdayPeriod':c['sourceSchedule'],'nativeClassroom':c['sourceClassroom'],'currentNativeClosureCompared':True,'closed':False,'nativeOnlineFlag':'N','literalDateClockRoomTuples':[f'{d}|2|{start}|{end}|{c["sourceClassroom"]}' for d in days],'publishedDepartmentPeriodClock':{'period':9 if isNursing else 5,'start':'17:00' if isNursing else '13:00','end':'17:50' if isNursing else '13:50'},'sourceImage':str(R/'latest-nursing-education-table-1.png' if isNursing else Q/'current-pt-undergraduate-education-table.jpg'),'sourceImageSHA256':sha(R/'latest-nursing-education-table-1.png' if isNursing else Q/'current-pt-undergraduate-education-table.jpg'),'sourceImageScope':'2026-2 간호학과 학년별 주간시간표260901; grade2 화9 인생설계와진로 + teacherinitial/multipliteralrooms' if isNursing else '2026년도2학기(정규) 물리치료학과 전공시간표; grade2 화5 인생설계와진로II; teacher/room blank','sameDepartmentClockApplicationOnly':True,'sourceImagePublishedOfficialCourseCode':'','sourceImagePublishedOfficialSection':'','fullProfessorFromCurrentWholeNativeOnly':True,'allocationUnknownNotActualAttendanceClaim':True,'reservationCount':11})
assert sum(bool(c['schedules']) for c in out['courses'])==113
assert sum(len(c['schedules']) for c in out['courses'])==1165
for x,y in zip(before['courses'],out['courses']):
 if x['sourceId'] not in sourceIds:assert x==y
out['researchOnly']=True;out['completionClaim']=False;out['candidateRevision']='syu-scoped-career-current-own-clock-v5'
save('syu-main-2026-2.scoped-career-own-clock-v5.json',out)
inputs=[B,N,C,Q/'current-pt-undergraduate-education-table.jpg',R/'latest-nursing-education-table-1.png',R/'latest-nursing-undergraduate-educational-timetable.pdf',Q/'current-public-notice-undergraduate-attachment-scope.json',R/'latest-nursing-official-scope.json']
save('independent-native-scoped-clock-date-proof.json',{'researchOnly':True,'completionClaim':False,'SDKExecuted':False,'priorWholeNativeCount':1391,'priorScheduled':94,'priorReservations':956,'newScheduled':19,'newReservations':209,'wholeScheduled':113,'wholeReservations':1165,'allPrior94WholeObjectsExact':True,'other1372WholeObjectsExact':True,'proofs':proofs,'sourceInputsSHA256':{str(p):sha(p) for p in inputs},'literalTuesdayDates':days,'calendar':calendar,'nativeIdentityRule':'Current whole native actual lectureNumber/code/blankpublishedsection/fullprofessor/department/grade/day/period retained. Department image supplies scoped current period clock plus matching course-title weekday grade; it does not publish code/section/fullprofessor for these rows. No image code/section join or initial expansion is claimed. No crossdepartment or title-only identity aliases.'})
held=[c for c in before['courses'] if not c['schedules']];audit=[]
for c in held:
 a=c['sourceEducation']['nativePublicCells'];nr=a[0];dep=c['departments'];reason='own_current_department_absolute_clock_not_obtained'
 if c['sourceId'] in sourceIds:reason='candidate_current_own_department_clock_and_native_regular_slot'
 elif dep==['간호학과']:
  reason='actual_nursing_native_vs_current_image_room_conflict' if nr in ['27','38','45','46','2','3'] else 'actual_nursing_title_and_enrollment_condition_conflict' if nr=='25' else 'separate_chapel_current_program_dates_unknown' if nr=='28' else 'actual_nursing_clinical_simulation_native_clock_blank_allocation_unknown'
 elif dep==['물리치료학과']:
  reason='actual_pt_native_vs_image_teacher_conflict' if nr=='309' else 'separate_chapel_current_program_dates_unknown' if nr in ['317','306','320'] else 'actual_pt_clinical_native_clock_blank_allocation_unknown'
 audit.append({'sourceId':c['sourceId'],'nativeLectureNumber':nr,'courseCode':c['courseCode'],'courseName':c['courseName'],'professor':c['professor'],'departments':dep,'nativeSchedule':c['sourceSchedule'],'nativeClassroom':c['sourceClassroom'],'nativeOnlineFlag':a[13],'nativeSpecialRemarks':a[14],'reason':reason,'hasDirectNativeHH':bool(re.search(r'\d{1,2}:\d{2}',c['sourceSchedule'])),'nativeTimeBlank':not bool(c['sourceSchedule'].strip()),'nativeRoomBlank':not bool(c['sourceClassroom'].strip()),'nativeProfessorBlank':not bool(c['professor'].strip())})
save('whole1297-held-source-triage.json',{'researchOnly':True,'currentWholeNative':1391,'currentScheduled94':94,'actualCurrentUnrecognized1297':len(held),'counts':dict(collections.Counter(x['reason'] for x in audit)),'directNativeHH0':all(not x['hasDirectNativeHH'] for x in audit),'nativeTimeBlank':sum(x['nativeTimeBlank'] for x in audit),'nativeRoomBlank':sum(x['nativeRoomBlank'] for x in audit),'nativeProfessorBlank':sum(x['nativeProfessorBlank'] for x in audit),'sourceRows':audit,'planContextNotYetAcquired':'Whole source PDF is metadata timetable, not full current per-offering syllabus. No full-plan review is claimed. Unknown department clocks remain held until own scoped source.'})
save('python-literal-preservation-validation.json',{'result':'PASS','whole1391Preserved':True,'old94Scheduled956DatesDeepUnchanged':True,'other1372WholeObjectsDeepUnchanged':True,'nineteenNativeCellsMatchCurrentOriginalRawExactly':True,'new19LiteralTuesday209Dates':True,'sevenPTClassroomsOriginalBlank':True,'newModesNotOverridden':True,'current1297HeldCensus':True,'SDKExecuted':False})
print(P);print('PASS current1391/94/956 =>113/1165 +19/209; previous1372wholeexact; all19literalraw/dateproof; heldcensus',collections.Counter(x['reason'] for x in audit))
