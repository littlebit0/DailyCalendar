from pathlib import Path
import json,copy,datetime,hashlib
D=Path(__file__).parent;F=D.parent;ROOT=Path.cwd()
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(n,v):(D/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
paths={'humanities':F/'natural-reference-v3-fixture-derivative-20261009/baseline-humanities.json','natural':F/'current-natural-reference-v3-20261009/mju-natural-2026-2.natural-reference-v3.json','unknown':F/'current-english-writing-direct-clock-v5-20261009/mju-unknown-2026-2.english-writing-direct-clock-v5.json'}
prior={k:read(p) for k,p in paths.items()};old=[c for d in prior.values() for c in d['courses']];assert len(old)==221
source=read(D/'current-bulk-table-education-first-transcription.json');body=read(D/'current-notice-education-body.json');cal=read(F/'mju-current-calendar-room-guide-20261008.json');proofs=[];new=[]
wdmap={'월':1,'화':2,'수':3,'목':4,'금':5}
for row in source['rows']:
 ref=row['nativeLectureNumber']
 if ref=='5190':continue
 days,tm=row['nativeTime'].split();a,b=tm.split('-');start=int(a[:2])*60+int(a[2:]);end=int(b[:2])*60+int(b[2:]);weekdays=[wdmap[w] for w in days];dates=[];dt=datetime.date.fromisoformat(cal['startDate']);enddate=datetime.date.fromisoformat(cal['reservationEndDate'])
 while dt<=enddate:
  s=dt.isoformat()
  if dt.isoweekday() in weekdays and s not in cal['excludedHolidays'] and not cal['midtermStartDate']<=s<=cal['midtermEndDate']:dates.append(s)
  dt+=datetime.timedelta(days=1)
 sid='mju/unknown/2026-2/'+ref
 assert not any(c['sourceId']==sid for c in old)
 note='2026-2 공식 일괄수강 공개 표의 정규 요일·명시 시각에 따른 계획 예약입니다. 실제 개별 출석·시험일·보강·최신 변경은 미확인입니다. 자체 개강9/1부터 기말시험 전12/7까지 보수적 계획 범위이며 공휴일과 중간시험 범위 예약은 보류했습니다. 강좌번호 '+ref+'는 학교 등록 참조이며 학수코드·분반으로 변환하지 않았습니다. 공식 학수코드·분반·개별 캠퍼스·강의실은 원문 미게시입니다. 원문 대상: '+row['targetDepartment']+'; '+row['nativeEligibility']+'. 일괄수강 교과목 변경 불가; 미리 담긴 교과목 외 교과목은 개별 수강신청. 강의실은 변경될 수 있음. 미게시 운영방식은 사용자 선택을 유지합니다.'
 if ref=='5895':note+=' 국제학생을위한경영학개론2는 외국인 신·편입학생의 두 번째 학기 일괄수강 과목으로 2026년9월 입학생은2027-1학기 수강 대상입니다.'
 if row['professorPendingPrinted']:note+=' 담당 교수는 원문 예정 표시를 보존하며 확정하지 않았습니다.'
 if not row['professor']:note+=' 교수 이름 작은 글씨 전사 미확정으로 빈값을 보존하며 원본 표 이미지 확인이 필요합니다.'
 meetings=[{'date':s,'weekday':datetime.date.fromisoformat(s).isoweekday(),'startMinute':start,'endMinute':end,'classroom':'','originalStartMinute':start,'originalEndMinute':end} for s in dates]
 c={'sourceId':sid,'referenceKind':'nativeLectureNumber','campus':'unknown','academicYear':2026,'semester':'2','courseCode':'','courseName':row['courseName'],'section':'','professor':row['professor'],'classification':row['classification'],'departmentClassifications':{},'credits':row['credits'],'departmentCredits':{},'departments':[row['targetDepartment']],'departmentRemarks':{row['targetDepartment']:note},'sourceSchedule':row['nativeTime'],'sourceClassroom':'','scheduleStatus':'scheduled','schedules':meetings,'period':{'startDate':'2026-09-01','endDate':'2026-12-07'},'sourceEducation':{'referenceKind':'nativeLectureNumber','nativeLectureNumber':ref,'nativeCourseCodePublished':False,'nativeSectionPublished':False,'sourceCampusIndividuallyPrinted':False,'nativePublicCells':row,'sourceUrl':source['sourceUrl'],'sourceImageURL':source['sourceImageUrl'],'sourceImageSHA256':body['imageOriginalSHA256'],'sourceEducationReceiptSHA256':sha(D/'current-bulk-table-education-first-transcription.json'),'nativeBody':body['nativeEducationalParagraphs'],'actualOperatingMeetingsConfirmed':False,'deliveryModePublished':False,'classroomPublished':False,'wholeLatestClosureConfirmed':False,'nativeClosureJoinCampusUnconfirmed':True,'professorTranscriptionPending':not bool(row['professor']),'professorPrintedButUncertain':not bool(row['professor'])}}
 new.append(c);proofs.append({'sourceId':sid,'nativeReference':ref,'literalWeekdays':weekdays,'literalStartMinute':start,'literalEndMinute':end,'literalClassroom':'','literalDates':dates,'nativeTableRow':row['nativeTableRow']})
candidate=copy.deepcopy(prior['unknown']);candidate['courses']+=new;candidate['researchOnly']=True;candidate['productionIntegrationEnabled']=False;candidate['completionClaim']=False
write('mju-unknown-2026-2.business-bulk-direct-clock-v11-prepared.json',candidate)
allc=prior['humanities']['courses']+prior['natural']['courses']+candidate['courses'];by={c['sourceId']:c for c in allc};assert len(allc)==len(by)==241
for c in old:assert by[c['sourceId']]==c
write('independent-literal-date-clock-proof-prepared.json',{'sourceInputs':[{'path':str(p),'sha256':sha(p)} for p in paths.values()],'priorDatasetPaths':{k:str(p) for k,p in paths.items()},'old221WholeExact':True,'existing5190BlendedHeld':True,'newCourses':len(new),'newAppointments':sum(len(c['schedules']) for c in new),'plannedUnionObjects':241,'scheduledObjects':sum(bool(c['schedules']) for c in allc),'appointments':sum(len(c['schedules']) for c in allc),'proofs':proofs,'sourceVisualReviewStillRequired':True,'SDKExecuted':False,'completionClaim':False})
print('prepared 20 /',sum(len(c['schedules']) for c in new),'new planned reservations; source visual review pending')
