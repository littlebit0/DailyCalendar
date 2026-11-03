from pathlib import Path
from datetime import date,timedelta
import json,copy,hashlib
P=Path(__file__).parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
save=lambda n,d:(P/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
base=Path('assets/timetable/syu-main-2026-2.json');prior=json.loads(base.read_text());save('prior-full-1391-93-945-baseline.json',prior)
out=copy.deepcopy(prior);c=next(c for c in out['courses'] if c['sourceId']=='syu/main/2026-2/307');assert c['sourceSchedule']=='월5~8' and not c['schedules'];assert c['sourceEducation']['nativePublicCells'][13:16]==['N','',''];assert c['sourceClassroom']=='요한관423호(中)강의실'
ss=[];day=date(2026,9,1)
while day<=date(2026,12,7):
 ds=day.isoformat()
 if day.isoweekday()==1 and ds!='2026-10-05' and not date(2026,10,20)<=day<=date(2026,11,2):ss.append({'date':ds,'weekday':1,'startMinute':780,'endMinute':1010,'classroom':c['sourceClassroom']})
 day+=timedelta(days=1)
assert len(ss)==11
c['schedules']=ss;c['scheduleStatus']='scheduled';c['period']={'startDate':'2026-09-01','endDate':'2026-12-07'}
note=' 현재2026-2 물리치료학과 학부3학년 시간표 원문 근골격물리치료학III 월5~8 블록 및 자체5교시13:00~13:50·8교시16:00~16:50을 대조한 정규 주간 예약. 학과 이미지에는 교수·강의실 미공개이며 현재9/7 전체공개원문의 해당 강좌번호307 교수 이민우·요한관423호(中)강의실을 그대로 보존. 이미지에 다른교수/room가 있다는추정·분반생성0. 자체9/1개강부터15주차12/8~14기말직전12/7까지예약,10/20~26중간 및10/27~11/2온라인권장주간은 개별운영미확인으로 제외;10/5공휴일제외. 실제출석·최신폐강·개별강의계획·학기종료일확정아님. 해당PT학부외시각적용0. 원문학점/이수구분 겹침은보존하고숫자추정하지않음.'
for d in c['departmentRemarks']:c['departmentRemarks'][d]=c['departmentRemarks'][d].replace(' 전체 대학 교시 시각 미확인 또는 별도 운영/온라인/원문 잘림으로 일정 보류. 채플 시각을 일반 교과목에 적용하지 않았습니다.','')+note
c['sourceEducation'].update(ptCurrentUndergraduateClockMatched=True,ptImageTeacherExplicit=False,ptImageRoomLiteral='',ptImageProfessorLiteral='',ptImageTeacherAndRoomUnpublishedNotContradictory=True,nativeOwnProfessorRoomPreserved=True,wholeUniversityClockConfirmed=False,individuallyPublishedDates=False,actualOperatingVerified=False,reservationScope='own current PT undergraduate published clock/nativeweekday; ordinaryreservations not confirmed attendance')
out['completionClaim']=False;out['researchOnly']=True;out['candidateRevision']='pt-image-unpublished-room-teacher-source-v4'
unchanged=[i for i,(a,b) in enumerate(zip(out['courses'],prior['courses'])) if a!=b];assert len(unchanged)==1; assert all(c==prior['courses'][i] for i,c in enumerate(out['courses']) if c['sourceId']!='syu/main/2026-2/307');assert sum(bool(c['schedules']) for c in out['courses'])==94;assert sum(len(c['schedules']) for c in out['courses'])==956
save('syu-main-2026-2.pt307-own-clock-planned-v4.json',out)
Q=P.parent/'syu-general-clock-review-20261009';R=P.parent/'syu-other-undergraduate-clock-review-20261009';calendar=Q/'current-own-calendar-reservation-scope.json';save('reused-own-current-calendar-proof.json',json.loads(calendar.read_text()))
proof={'nativeSourceId':'syu/main/2026-2/307','nativeLectureNumber':'307','nativeCode':'1001045','nativeUnpublishedSection':'','nativeCurrentGrade':'3학년','nativeTitle':'근골격물리치료학 III','nativeProfessor':'이민우','nativeRoom':'요한관423호(中)강의실','nativeAllEducationCells':next(c for c in prior['courses'] if c['sourceId'].endswith('/307'))['sourceEducation']['nativePublicCells'],'nativeCurrentClosureCompared':True,'nativeClosed':False,'nativeOnlineFlag':'N','nativeSpecialRemarks':'','sourceImageFile':str(Q/'current-pt-undergraduate-education-table.jpg'),'sourceImageSHA256':sha(Q/'current-pt-undergraduate-education-table.jpg'),'actualSourceNotice':json.loads((Q/'current-public-notice-undergraduate-attachment-scope.json').read_text()),'sourceImageDirectlyViewedThisReview':True,'nativeImageGradeTitleScope':'2026년도2학기(정규)-학년별시간표/물리치료학과전공시간표/3학년','nativeImageOwnCellRect':[91,799,151,995],'nativeImageTitle':'근골격물리치료학 III','nativeImageWeekdayPeriod':'월5–8','nativeImageProfessor':'','nativeImageRoom':'','printedOwnPeriodClock':{'5':['13:00','13:50'],'6':['14:00','14:50'],'7':['15:00','15:50'],'8':['16:00','16:50']},'ownJoinRule':'Actualcurrentdepartment+grade+nativeuniquefulltitle+weekdayperiod plus owncurrentPTclock. Image教授roomabsent notcontradictory; nativecompletecurrent307ownvalues preserve. No title-only crossdepartment/coursecodealias or cross-day room substitution','nativeScopeWarnings':'Image notice graduate-hosted but explicitly undergraduate attached timetable; no graduateclassesused. Campusmain is institutiononly currentnativeproof, individualphysicalcampusunverifiedretained.','priorWholeScheduled93Unchanged':True,'other1390WholeObjectsUnchanged':True,'priorBaselineSHA256':sha(base),'frozenInputs':{str(f):sha(f) for f in [Q/'SHA256.json',R/'SHA256.json',Q/'current-pt-undergraduate-education-table.jpg',Q/'current-education-image-geometry-review.json',calendar]},'completionClaim':False,'SDKExecuted':False}
save('native-own-clock-whole-education-proof.json',proof)
# Independent own-calendar literal Mondays, not production loop.
expected='2026-09-07 2026-09-14 2026-09-21 2026-09-28 2026-10-12 2026-10-19 2026-11-09 2026-11-16 2026-11-23 2026-11-30 2026-12-07'.split();assert [s['date'] for s in ss]==expected
save('independent-python-validation.json',{'result':'PASS','literalMondayDates':expected,'addedOwnClock':[780,1010],'other1390WholeObjectsPreserved':True,'total1391Scheduled94Dates956':True,'new11Dates':True,'SDKExecuted':False})
