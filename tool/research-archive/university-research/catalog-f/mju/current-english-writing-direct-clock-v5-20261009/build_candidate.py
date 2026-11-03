# coding:utf-8
from pathlib import Path
import copy,json,hashlib,datetime
ROOT=Path.cwd();F=ROOT/'work/university-research/catalog-f/mju';D=Path(__file__).parent
url='https://english.mju.ac.kr/bbs/english/1034/233737/artclView.do'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(n,v):(D/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
row={'nativeAcademicHeading':'2026-2 학기 외국인 학생 전용 [영어작문] 과목 안내','courseName':'영어작문','nativeWeekdays':'화요일, 목요일','nativeTime':'화/목 12:00~13:15','professor':'이은주','nativeEligibility':'외국인 학생 전용 과목','nativeRestriction':'외국인 학생 전용 과목은 한국인 학생은 수강 불가하니 수강신청에 유의 바랍니다.'}
write('current-official-course-education.json',{'sourceUrl':url,'publishedDate':'2026-07-22','modifiedDate':'2026-07-22','academicYear':2026,'semester':'2','sourceObservedChain':['https://www.mju.ac.kr/mjukr/204/subview.do','https://english.mju.ac.kr','https://english.mju.ac.kr/bbs/english/1034/233737/artclView.do'],'nativeTableRow':row,'bodyRepeatsSameWeekdayTimeProfessorEligibility':True,'codeSectionLectureReferenceRoomCampusIndividuallyPrinted':False,'contactsOrStudentInformationSaved':False,'scope':'one current undergraduate offering notice, not full department or university catalog','completionClaim':False})
paths={'humanities':F/'natural-reference-v3-fixture-derivative-20261009/baseline-humanities.json','natural':F/'current-natural-reference-v3-20261009/mju-natural-2026-2.natural-reference-v3.json','unknown':F/'current-electronics-ie-reference-v4-20261009/mju-unknown-2026-2.electronics-ie-reference-v4.json'}
prior={k:read(p) for k,p in paths.items()};whole=[c for doc in prior.values() for c in doc['courses']];assert len(whole)==220
assert not any(c['courseName']=='영어작문' for c in whole)
calendarpath=F/'mju-current-calendar-room-guide-20261008.json';cal=read(calendarpath);dates=[]
a=datetime.date.fromisoformat(cal['startDate']);z=datetime.date.fromisoformat(cal['reservationEndDate'])
while a<=z:
 s=a.isoformat()
 if a.isoweekday() in (2,4) and s not in cal['excludedHolidays'] and not cal['midtermStartDate']<=s<=cal['midtermEndDate']:dates.append(s)
 a+=datetime.timedelta(days=1)
assert len(dates)==25
note='2026-2 공식 공개 주간 시간표에 따른 계획 예약입니다. 외국인 학생 전용 과목; 한국인 학생 수강 불가. 과목코드·강좌번호·분반·강의실·개별 캠퍼스는 원문 미게시하여 빈값/미확인으로 보존했습니다. 내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다. 화/목12:00–13:15는 원문 표와 본문의 명시 시각이며 임의 교시 환산을 하지 않았습니다. 자체 개강9/1부터 기말시험 전12/7까지의 보수적 계획 범위; 공휴일9/24 및 중간시험10/20–26 구간 예약을 보류했습니다. 실제 개별 출석·중간시험 실시일·보강·전체 최신 폐강·운영 변경 확인은 미완료이며 강의실/대면·원격 방식은 확인되지 않았습니다. 미게시 운영방식은 사용자 선택 모드를 유지합니다.'
meetings=[{'date':s,'weekday':datetime.date.fromisoformat(s).isoweekday(),'startMinute':720,'endMinute':795,'classroom':'','originalStartMinute':720,'originalEndMinute':795} for s in dates]
new={'sourceId':url+'#table=1&row=2','referenceKind':'internalDocumentLocator','campus':'unknown','academicYear':2026,'semester':'2','courseCode':'','courseName':'영어작문','section':'','professor':'이은주','classification':'','departmentClassifications':{},'credits':None,'departmentCredits':{},'departments':['영어영문학전공'],'departmentRemarks':{'영어영문학전공':note},'sourceSchedule':'화요일, 목요일; 화/목 12:00~13:15','sourceClassroom':'','scheduleStatus':'scheduled','schedules':meetings,'period':{'startDate':'2026-09-01','endDate':'2026-12-07'},'sourceEducation':{'referenceKind':'internalDocumentLocator','nativeCourseCodePublished':False,'nativeSectionPublished':False,'nativeLectureNumberPublished':False,'sourceCampusIndividuallyPrinted':False,'nativePublicCells':row,'sourceUrl':url,'publishedDate':'2026-07-22','modifiedDate':'2026-07-22','sourceEducationReceiptSHA256':sha(D/'current-official-course-education.json'),'actualOperatingMeetingsConfirmed':False,'operatingReviewComplete':False,'classroomPublished':False,'deliveryModePublished':False,'wholeLatestClosureConfirmed':False,'nativeClosureJoinPossible':False,'dateScope':'planned ordinary calendar window only; actual per-course examinations/makeup not confirmed'}}
candidate=copy.deepcopy(prior['unknown']);candidate['courses'].append(new);candidate['researchOnly']=True;candidate['productionIntegrationEnabled']=False;candidate['completionClaim']=False
write('mju-unknown-2026-2.english-writing-direct-clock-v5.json',candidate)
allcourses=prior['humanities']['courses']+prior['natural']['courses']+candidate['courses'];assert len(allcourses)==221
byid={c['sourceId']:c for c in allcourses};assert len(byid)==221
for old in whole:assert byid[old['sourceId']]==old
write('independent-literal-date-clock-proof.json',{'sourceInputs':[{'path':str(p.relative_to(ROOT)),'sha256':sha(p)} for p in list(paths.values())+[calendarpath,D/'current-official-course-education.json']],'priorDatasetPaths':{k:str(p.relative_to(ROOT)) for k,p in paths.items()},'old220WholeExact':True,'newCourses':1,'newAppointments':25,'plannedUnionObjects':221,'scheduledObjects':8,'appointments':197,'literalSourceId':new['sourceId'],'literalWeekdays':[2,4],'literalStartMinute':720,'literalEndMinute':795,'literalClassroom':'','literalDates':dates,'independentBodyTableAgreement':True,'sourceCodeSectionUnpublishedBlank':True,'nativeRegistrationAliasCreated':False,'calendarOwnSourceURL':cal['sourceUrl'],'calendarOriginalSHA256':cal['sourceSHA256'],'excludedDatesWithPublishedReason':[{'date':'2026-09-24','reason':'학교 자체 공휴일'},{'date':'2026-10-20','reason':'학교 중간시험 범위; 실제 해당과목 시험날짜 미확인 보수적 예약보류'},{'date':'2026-10-22','reason':'학교 중간시험 범위; 실제 해당과목 시험날짜 미확인 보수적 예약보류'}],'SDKExecuted':False,'completionClaim':False})
print('PASS source220 whole deep preserved; one direct native75min/25 planned dates;221objects/8scheduled197dates')
