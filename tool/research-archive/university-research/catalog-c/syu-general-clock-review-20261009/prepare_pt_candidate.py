from pathlib import Path
from datetime import date,timedelta
import json,hashlib,copy
P=Path(__file__).resolve().parent
B=P.parent.parent/'catalog-f/syu/syu-main-2026-2.native1391-chapel-partial-v1.json'
baseline=json.loads(B.read_text());candidate=copy.deepcopy(baseline)
# Independently reviewed actual image geometry, not inferred from course names or older schedules.
plans={
'293':('화4~5','이재은','다니엘301'),
'294':('월2~4',None,'다니엘301'),
'315':('월6~8','임종은','다니엘301'),
'289':('금2~5','박은수','다니엘305'),
'313':('화6~7','이재은','다니엘301'),
'308':('목5~8','이승원','다니엘208'),
'312':('금2~4','이승원','다니엘208'),
'314':('목1~3','정태웅','다니엘208'),
'288':('수1~4','신두철','다니엘208'),
'310':('월5~8','이병희','다니엘302'),
'287':('수5~8','이병희','다니엘208'),
'291':('월1~3','정이정','다니엘208'),
'290':('화1~4','이완희','다니엘208'),
'286':('금1~4','윤효실','다니엘301'),
'316':('수5~8','신두철','다니엘301'),
'319':('수1~2','윤탁용','다니엘301'),
'311':('목5~6','박선건','다니엘301')}
clock={str(n):{'startMinute':540+(n-1)*60,'endMinute':590+(n-1)*60} for n in range(1,11)}
# Exact official calendar entries: precautionary omissions are distinct from confirmed holidays.
exclude={'2026-09-24','2026-09-25','2026-09-26','2026-09-27','2026-10-05','2026-10-09'}
precaution={'2026-10-06','2026-10-07'}
start=date(2026,9,1);end=date(2026,12,7)
audit=[]
for c in candidate['courses']:
 ident=c['sourceId'].rsplit('/',1)[-1]
 if ident not in plans:continue
 native,prof,room=plans[ident]
 assert c['sourceSchedule']==native
 if prof:assert c['professor']==prof
 assert room.replace('다니엘','다니엘관') in c['sourceClassroom']
 assert c['sourceEducation']['nativePublicCells'][13]=='N' and not c['sourceEducation']['nativePublicCells'][14]
 day='월화수목금'.index(native[0])+1;periods=native[1:].split('~');first=int(periods[0]);last=int(periods[-1]);meetings=[]
 d=start
 while d<=end:
  ds=d.isoformat()
  exam=date(2026,10,20)<=d<=date(2026,10,26)
  online=date(2026,10,27)<=d<=date(2026,11,2)
  if d.isoweekday()==day and ds not in exclude|precaution and not exam and not online and not (ident=='289' and ds in {'2026-11-20','2026-11-27'}):
   meetings.append({'date':ds,'weekday':day,'startMinute':clock[str(first)]['startMinute'],'endMinute':clock[str(last)]['endMinute'],'classroom':c['sourceClassroom']})
  d+=timedelta(days=1)
 note=' 현재2026-2 물리치료학과 학부 시간표에 직접 표시한 교시 시각(각50분), 요일 및 강의실과 최신9/7 공개 강좌표를 대조한 정규 주간 예약입니다. 날짜별 실제 출석·개별 강의계획 검증이 아닙니다. 공식9/1개강부터15주차 기말고사 직전12/7까지 예약하며12/8~14 기말,10/20~26 중간 및10/27~11/2 온라인 권장주간은 미확인으로 제외합니다. 공휴일과10/6축전·10/7체육대회는 제외하되 행사일 전체 휴강을 확정한 것은 아닙니다. 학기종료일을12/7로 주장하지 않습니다. 다른 학과에 시각표를 확대 적용하지 않습니다.'
 if ident=='289':note+=' 이미지에11/20·27 별도 실 표기가 있어 두 날짜는 예약에서 제외했습니다.'
 c['schedules']=meetings;c['scheduleStatus']='scheduled';c['period']={'startDate':'2026-09-01','endDate':'2026-12-07'}
 for dep in c['departmentRemarks']:
  c['departmentRemarks'][dep]=c['departmentRemarks'][dep].replace(' 전체 대학 교시 시각 미확인 또는 별도 운영/온라인/원문 잘림으로 일정 보류. 채플 시각을 일반 교과목에 적용하지 않았습니다.','')+note
 c['sourceEducation'].update({'ptCurrentUndergraduateClockMatched':True,'ptImageTeacherExplicit':prof is not None,'ptImageRoomLiteral':room,'wholeUniversityClockConfirmed':False,'individuallyPublishedDates':False,'actualOperatingVerified':False,'reservationScope':'ordinary weekly reservation within current official semester; individual dates not attendance proof'})
 audit.append({'sourceId':c['sourceId'],'nativeSchedule':native,'imageProfessorLiteral':prof,'imageRoomLiteral':room,'sourceRoomUnchanged':True,'reservationCount':len(meetings),'explicitDateExceptions':['2026-11-20','2026-11-27'] if ident=='289' else []})
old={c['sourceId']:c for c in baseline['courses']};changed={r['sourceId'] for r in audit}
assert len(changed)==17
assert all(c==old[c['sourceId']] for c in candidate['courses'] if c['sourceId'] not in changed)
assert all(c==old[c['sourceId']] for c in candidate['courses'] if old[c['sourceId']]['schedules'])
candidate['candidateRevision']='pt-current-clock-source-candidate-v2';candidate['completionClaim']=False
out=P/'syu-main-2026-2.pt-current-clock-candidate-v2.json';out.write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
receipt={'researchOnly':True,'SDKTestPending':True,'priorCandidateSHA256':hashlib.sha256(B.read_bytes()).hexdigest(),'prior38CoursesDeepUnchanged':True,'native1391Unchanged':True,'clockScope':'current2026-2 physical therapy undergraduate timetable only','clock':clock,'imageSourceSHA256':'6e529ff18e66fe114b17bbc2ece6f8f969d235f6ee00d83072f70cfd79030479','imageGeometryVisuallyReviewed':True,'reviewedCourses':audit,'heldConflicts':[{'nativeLectureNumber':'307','reason':'Initial visual read corrected: image Monday5-8 agrees with native. Image lacks teacher/room, so separate course plan cross-check remains incomplete; no actual contradiction claim.'}],'newCourses':17,'newReservations':sum(r['reservationCount'] for r in audit),'wholeScheduled':sum(bool(c['schedules']) for c in candidate['courses']),'wholeReservations':sum(len(c['schedules']) for c in candidate['courses']),'candidateSHA256':hashlib.sha256(out.read_bytes()).hexdigest(),'completionClaim':False}
(P/'pt-current-clock-source-candidate-audit.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n');print({k:receipt[k] for k in ['newCourses','newReservations','wholeScheduled','wholeReservations','candidateSHA256']})
