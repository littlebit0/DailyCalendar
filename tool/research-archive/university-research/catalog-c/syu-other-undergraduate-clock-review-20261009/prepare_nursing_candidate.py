from pathlib import Path
from datetime import date,timedelta
import json,copy,hashlib,re
P=Path(__file__).resolve().parent
B=P.parent/'syu-general-clock-review-20261009/syu-main-2026-2.pt-current-clock-candidate-v2.json'
baseline=json.loads(B.read_text());candidate=copy.deepcopy(baseline)
byid={c['sourceEducation']['nativeLectureNumber']:c for c in baseline['courses']}
review=[]
def add(i,title,teachers,grade,group,meetings,printed=True,after=None,remarks=''):
 c=byid[str(i)]
 assert c['departments']==['간호학과'] and c['professor'] in teachers
 assert not c['schedules'] and not c['sourceEducation']['closed']
 native=','.join(f'{"월화수목금"[day-1]}{first}'+(f'~{last}' if first!=last else '') for day,first,last,room,bbox in meetings)
 assert c['sourceSchedule']==native,(i,c['sourceSchedule'],native)
 assert c['section']==''
 review.append({'nativeLectureNumber':str(i),'sourceId':c['sourceId'],'nativeCourseCode':c['courseCode'],'nativeTitle':c['courseName'],'PDFTitleLiteral':title,'PDFTeacherLiterals':teachers,'PDFGrade':grade,'PDFGroupLiteral':group,'PDFNativeLectureNumberPrinted':printed,'sourceImageIndex':1 if grade<=2 else 2,'sourceMeetings':[{'weekday':day,'firstPeriod':first,'lastPeriod':last,'PDFRoomLiteral':room,'educationImageCellBBox':bbox} for day,first,last,room,bbox in meetings],'PDFMidtermAfterRoomLiteral':after,'educationRemarksLiteral':remarks,'nativeFieldsUnchanged':True,'numericSectionInvented':False,'sourceAliasInvented':False,'sourceImageVisuallyReviewed':True})
# Coordinates are original embedded education image pixels, reviewed visually.
add(75,'종교와 인생 A(75)',['최선우'],1,'A',[(1,7,8,'3과209',[151,258,247,325])],after='다404')
add(76,'종교와 인생 B(76)',['최선우'],1,'B',[(1,5,6,'요223',[247,192,345,258])],after='다405')
add(1537,'병리학 B(1537)',['정현철'],1,'B',[(1,7,8,'2과학관407-1',[247,258,345,325])],after='다405')
add(81,'병리학 A(81)',['정현철'],1,'A',[(1,5,6,'요221',[151,192,247,258])],after='다404')
add(83,'임상약리학(전공기초)',['김희진'],1,'',[(2,1,2,'다404',[345,60,539,126])],False)
add(82,'인간관계와 의사소통',['유혜진'],1,'',[(2,3,3,'다405',[345,126,539,159])],False)
add(1,'성장과 발달',['박선정'],1,'',[(2,6,7,'3과207',[345,225,539,292])],False,'다404')
add(1269,'웰니스 영양과 간호',['이은혜','신경옥'],1,'',[(3,6,7,'에113',[539,225,733,292])],False)
add(19,'역사와 문화 B(19)',['최선우'],2,'B',[(5,1,2,'다306',[1024,388,1121,454])])
add(18,'역사와 문화 A(18)',['최선우'],2,'A',[(5,3,4,'다304',[927,454,1024,520])])
add(7,'비판적 사고 A(7)',['김지현'],2,'A',[(1,5,6,'다305',[151,520,247,586])])
add(8,'비판적 사고 B(8)',['김지현'],2,'B',[(1,1,2,'요323',[247,388,345,454])])
add(16,'기본간호학 II A(16)',['김현영'],2,'A',[(1,1,2,'다305',[151,388,247,454])])
add(17,'기본간호학 II B(17)',['김현영'],2,'B',[(1,5,6,'요323',[247,520,345,586])])
add(21,'기본간호실습 II A(21)',['김현영'],2,'A',[(2,1,2,'제3과213',[345,388,539,454])])
add(22,'기본간호실습 II B(22)',['김현영'],2,'B',[(2,3,4,'제3과213',[345,454,539,520])])
add(23,'기본간호실습 II C(23)',['김현영'],2,'C',[(3,3,4,'제3과213',[539,454,733,520])])
add(24,'기본간호실습 II D(24)',['김현영'],2,'D',[(3,5,6,'제3과213',[539,520,733,586])])
add(10,'건강사정 A(10)',['김지현'],2,'A',[(5,1,2,'다304',[927,388,1024,454])])
add(11,'건강사정 B(11)',['김지현'],2,'B',[(5,3,4,'다306',[1024,454,1121,520])])
add(73,'노인과재활간호',['정현철'],2,'',[(3,7,8,'요222',[539,586,733,653])],False)
add(49,'국제보건',['박지욱'],2,'',[(3,1,2,'요423',[636,388,733,454])],False,remarks='45명')
add(78,'디지털 헬스케어',['김현영'],2,'',[(4,1,3,'요323',[733,388,927,487])],False,remarks='45명')
add(80,'감염과 미생물학',['최성숙'],2,'',[(1,7,8,'다305',[151,586,345,653])],False)
add(26,'모성간호학 I A(26)',['백온전'],3,'A',[(1,1,3,'다302',[152,62,258,161]),(2,1,3,'3과207',[364,62,470,161])])
add(44,'아동간호학 I B(44)',['강경아','박선정'],3,'B',[(1,1,3,'다404',[258,62,364,161]),(2,1,3,'요323',[470,62,576,161])])
add(43,'아동간호학 I A(43)',['강경아','박선정'],3,'A',[(1,5,7,'다405',[152,195,258,294]),(4,6,8,'다405',[894,228,1000,327])])
add(13,'정신간호학 II A(13)',['유혜진'],3,'A',[(2,5,6,'다404',[364,195,576,261]),(5,3,4,'다405',[1106,128,1212,195])])
add(14,'정신간호학 II B(14)',['유혜진'],3,'B',[(2,7,8,'다404',[364,261,576,327]),(5,1,2,'다404',[1000,62,1106,128])])
add(12,'호흡과감각간호',['신성례','김희수'],3,'',[(3,6,7,'다405',[576,228,788,294]),(4,1,2,'다405',[788,62,1000,128])],False)
add(47,'신경간호과학 A(47)',['신선화'],3,'A',[(5,1,2,'다405',[1106,62,1212,128])])
add(1536,'신경간호과학 B(1536)',['신선화'],3,'B',[(5,3,4,'다404',[1000,128,1106,195])])
add(48,'간호학총론',['유혜진'],4,'',[(3,1,2,'다304',[682,390,788,456])],False)
add(37,'근거기반간호 A(37)',['천지영'],4,'A',[(1,3,4,'다305',[152,456,364,522]),(5,7,8,'다404',[1000,589,1106,654])])
add(15,'의료법규 및 간호윤리',['이은혜'],4,'',[(1,1,2,'다405',[152,390,364,456]),(2,1,2,'다405',[364,390,576,456])],False)
add(79,'종양 및 호스피스 (fix)',['이은혜'],4,'',[(4,3,4,'다405',[788,456,1000,522])],False,remarks='3학년/4학년 표에 같은 강좌가 반복됨; native 한 개로만 연결')
add(29,'응급간호 (fix)',['신선화'],4,'',[(1,8,9,'3과207',[152,622,258,695])],False,remarks='3학년/4학년 표에 같은 강좌가 반복됨; native 한 개로만 연결')
add(20,'중환자간호 (fix)',['이은혜'],4,'',[(1,8,9,'다304',[258,622,364,695])],False,remarks='3학년/4학년 표에 같은 강좌가 반복됨; native 한 개로만 연결')
assert len(review)==38
# Matching is an independently identified native offering, not a new section or a generalized building legend.
for r in review:
 c=byid[r['nativeLectureNumber']]
 parts=c['sourceClassroom'].split(',')
 for j,m in enumerate(r['sourceMeetings']):
  raw=parts[min(j,len(parts)-1)]
  short=m['PDFRoomLiteral']
  number=re.search(r'\d+(?:-\d+)?$',short).group()
  prefix=next(v for k,v in [('제3과','제3과학관'),('3과','제3과학관'),('2과학관','제2과학관'),('다','다니엘관'),('요','요한관'),('에','에스라관')] if short.startswith(k))
  assert raw.startswith(prefix[:3]) or raw.startswith(prefix), (c['sourceId'],raw,short)
  raw_number=re.search(r'(\d+(?:-\d+)?)',raw[len(prefix):]) if raw.startswith(prefix) else None
  if raw_number: assert raw_number.group()==number,(c['sourceId'],raw,short)
  elif not r['PDFNativeLectureNumberPrinted']:raise AssertionError('Unnumbered offering has truncated native room')
  m['nativeRoomPublishedLiteral']=raw
  m['nativeRoomNumberClipped']=raw_number is None
  m['roomJoinBasis']='printed native offering number + matching title/professor/weekday/period and compatible current room prefix' if raw_number is None else 'matching current room number and title/professor/weekday/period; displayed abbreviation stays unexpanded'
  m['startMinute']=540+60*(m['firstPeriod']-1);m['endMinute']=590+60*(m['lastPeriod']-1)
# Own official calendar, same conservative reservation scope as frozen v2.
exclude={'2026-09-24','2026-09-25','2026-09-26','2026-09-27','2026-10-05','2026-10-09'}
precaution={'2026-10-06','2026-10-07'}
changed={r['sourceId'] for r in review}
for r in review:
 c=next(c for c in candidate['courses'] if c['sourceId']==r['sourceId']);meetings=[]
 for m in r['sourceMeetings']:
  d=date(2026,9,1)
  while d<=date(2026,12,7):
   ds=d.isoformat();exam=date(2026,10,20)<=d<=date(2026,10,26);online=date(2026,10,27)<=d<=date(2026,11,2)
   if d.isoweekday()==m['weekday'] and ds not in exclude|precaution and not exam and not online:
    room=r['PDFMidtermAfterRoomLiteral'] if r['PDFMidtermAfterRoomLiteral'] and d>date(2026,10,26) else m['PDFRoomLiteral']
    meetings.append({'date':ds,'weekday':m['weekday'],'startMinute':m['startMinute'],'endMinute':m['endMinute'],'classroom':room})
   d+=timedelta(days=1)
 meetings.sort(key=lambda m:(m['date'],m['startMinute'],m['classroom']))
 c['schedules']=meetings;c['scheduleStatus']='scheduled';c['period']={'startDate':'2026-09-01','endDate':'2026-12-07'}
 note=' 현재 간호학과 공식 학부 메뉴의9/10 수정 PDF(인쇄260901)와9/7 공개 강좌표의 실제 강좌번호 또는 교수·요일·교시·실을 대조한 정규 주간 예약입니다. 간호학부 자체1~9교시 각50분 시각표만 적용했으며 타학과 시각표 근거가 아닙니다. A/B 등은 PDF의 학생그룹 원문으로만 보존하고 공개되지 않은 숫자 분반·새 강좌를 만들지 않았습니다. 날짜별 실제 출석·임상실습 배정 확인이 아닙니다. 실명은 PDF의 다/요/3과/에 등의 원문 약호를 그대로 표시하며 별도 공식 건물 약호 범례로 일반화하지 않습니다. 공식9/1개강부터15주차 기말고사 직전12/7까지 예약하며12/8~14 기말,10/20~26 중간 및10/27~11/2 온라인 권장주간은 개별 운영 미확인으로 제외합니다. 공휴일과10/6축전·10/7체육대회는 제외하되 행사일 전체 휴강을 확정한 것은 아닙니다.12/7을 실제 학기종료일로 주장하지 않습니다.'
 if r['PDFMidtermAfterRoomLiteral']:note+=f" PDF에 중간고사 이후 {r['PDFMidtermAfterRoomLiteral']}로 실 변경을 직접 명시하므로 공식 중간기간10/20~26 이후 예약에서 그 원문 실을 표시합니다."
 if len(r['PDFTeacherLiterals'])>1:note+=' PDF의 공동교수 원문: '+', '.join(r['PDFTeacherLiterals'])+'. 최신 강좌표의 대표 교수 필드는 그대로 보존했습니다.'
 if any(m['nativeRoomNumberClipped'] for m in r['sourceMeetings']):note+=' 최신 강좌표에서 두 번째 실번호가 잘려 PDF의 실제 강좌번호와 동일 요일·교시·교수에 직접 연결된 실 literal을 해당 만남에 표시했습니다. 잘린 원문 필드를 복원·교체하지 않았습니다.'
 if r['educationRemarksLiteral']:note+=' PDF 교육 비고: '+r['educationRemarksLiteral']+'.'
 for dep in c['departmentRemarks']:
  c['departmentRemarks'][dep]=c['departmentRemarks'][dep].replace(' 전체 대학 교시 시각 미확인 또는 별도 운영/온라인/원문 잘림으로 일정 보류. 채플 시각을 일반 교과목에 적용하지 않았습니다.','')+note
 c['sourceEducation'].update({'nursingCurrentUndergraduateClockMatched':True,'nursingPDFPrintedRevision':'260901','nursingPDFGroupLiteral':r['PDFGroupLiteral'],'nursingPDFNativeLectureNumberPrinted':r['PDFNativeLectureNumberPrinted'],'nursingPDFTeacherLiterals':r['PDFTeacherLiterals'],'nursingPDFRoomLiterals':[m['PDFRoomLiteral'] for m in r['sourceMeetings']],'nursingPDFMidtermAfterRoomLiteral':r['PDFMidtermAfterRoomLiteral'],'wholeUniversityClockConfirmed':False,'individuallyPublishedDates':False,'actualOperatingVerified':False,'reservationScope':'ordinary weekly reservation within current own official semester; individual dates not attendance proof'})
 r['reservationCount']=len(meetings)
old={c['sourceId']:c for c in baseline['courses']}
assert len(candidate['courses'])==1391 and len({c['sourceId'] for c in candidate['courses']})==1391
assert all(c==old[c['sourceId']] for c in candidate['courses'] if c['sourceId'] not in changed)
assert all(c==old[c['sourceId']] for c in candidate['courses'] if old[c['sourceId']]['schedules'])
for c in candidate['courses']:
 if c['sourceId'] in changed:
  for k in ['sourceId','courseCode','section','professor','courseName','credits','classification','campus','sourceSchedule','sourceClassroom','departments','departmentClassifications','departmentCredits']:
   assert c[k]==old[c['sourceId']][k]
  assert c['sourceEducation']['nativePublicCells']==old[c['sourceId']]['sourceEducation']['nativePublicCells']
candidate['candidateRevision']='nursing-current-clock-source-candidate-v3';candidate['completionClaim']=False
out=P/'syu-main-2026-2.nursing-current-clock-candidate-v3.json';out.write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
held_reasons={str(i):reason for ids,reason in [([27,38,45,46,2,3],'latest native room and latest department PDF room conflict; no preferred room chosen'),([25],'native basic nursing practice II but PDF explicitly prints I and enrollment-dependent possible closure; actual correction/eligibility unresolved'),([28],'current nursing chapel 다207 is outside previously verified 대강당 chapel program; own actual operating dates unknown'),([62,65,64,63,66,67,68,69,70,71,72,1540],'PDF teacher initials/group allocation is not an exact full-professor-to-room native offering mapping'),([31,33,32,34,35,36,55,54,53,40,41,39,4,6,5,52,51,50,57,56,58,59,61,60],'current native weekly clock/room blank and no individual clinical/simulation allocation in the department PDF')] for i in ids}
nursing=[c for c in baseline['courses'] if c['departments']==['간호학과']]
held=[{'sourceId':c['sourceId'],'nativeLectureNumber':c['sourceEducation']['nativeLectureNumber'],'nativeTitle':c['courseName'],'nativeSchedule':c['sourceSchedule'],'nativeRoom':c['sourceClassroom'],'reason':held_reasons[c['sourceEducation']['nativeLectureNumber']]} for c in nursing if not c['schedules'] and c['sourceId'] not in changed]
assert len(held)==44
receipt={'researchOnly':True,'SDKTestPending':True,'priorCandidatePath':str(B),'priorCandidateSHA256':hashlib.sha256(B.read_bytes()).hexdigest(),'prior55Courses448ReservationsDeepUnchanged':True,'native1391Unchanged':True,'nursingNative84Reviewed':True,'nursingPriorScheduled':2,'nursingNewScheduled':38,'nursingHeld':held,'reviewedCourses':review,'clock':{str(n):{'startMinute':540+60*(n-1),'endMinute':590+60*(n-1)} for n in range(1,10)},'clockScope':'2026-2 nursing undergraduate timetable only','latestPDFSHA256':'abff39cbce16267e0fdb770cd2d5107a9646878cf066b318f89ed3b9a6235576','latestPDFSourceVisuallyReviewed':True,'olderAugustPDFUsedForCurrentCandidate':False,'PDFSourcePrivateContactFieldsObserved':0,'newCourses':38,'newReservations':sum(r['reservationCount'] for r in review),'wholeScheduled':sum(bool(c['schedules']) for c in candidate['courses']),'wholeReservations':sum(len(c['schedules']) for c in candidate['courses']),'candidateSHA256':hashlib.sha256(out.read_bytes()).hexdigest(),'completionClaim':False}
(P/'nursing-current-clock-source-candidate-audit.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print({k:receipt[k] for k in ['newCourses','newReservations','wholeScheduled','wholeReservations','candidateSHA256']})
