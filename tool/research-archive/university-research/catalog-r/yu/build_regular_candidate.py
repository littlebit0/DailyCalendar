"""Separate regular room-change rows from examination references."""
import datetime as dt,hashlib,json,re,collections
from pathlib import Path
from openpyxl import load_workbook
R=Path(__file__).parent;T=Path('/private/tmp');exam=json.loads((R/'yu-current-midterm-educational-proof-v1.json').read_text());p=T/'daily-yu-roomchanges.xlsx';s=load_workbook(p,data_only=True).active;headers=list(next(s.iter_rows(min_row=2,max_row=2,values_only=True)));rows=[]
for i in range(3,65):
 v=list(next(s.iter_rows(min_row=i,max_row=i,values_only=True)));rows.append(dict(excelRow=i,values={headers[n]:v[n] for n in [0,1,2,3,4,5,6,7,9,10,11,12,13]}))
clocktext=exam['currentNativePeriodClockText'];clocks={n:(a,b) for n,a,b in re.findall(r'([1-9][AB])(\d\d:\d\d)\s*-\s*(\d\d:\d\d)',clocktext)};assert len(clocks)==18
proof=dict(noticeUrl='https://www.yu.ac.kr/main/bachelor/bachelor-guide.do?articleNo=231766391&mode=view',attachmentUrl='https://www.yu.ac.kr/main/bachelor/bachelor-guide.do?mode=fileDownload&articleNo=231766391&attachNo=378053',attachmentSha256=hashlib.sha256(p.read_bytes()).hexdigest(),nativeHeading=s.cell(1,1).value,nativeRows=rows,independentNativeClockText=clocktext,independentClockSource=exam['currentUndergraduateCalendar']['attachmentUrl'],independentClockSourceSha256=exam['currentUndergraduateCalendar']['sha256'],nativeUndergraduateCalendar=exam['currentUndergraduateCalendar']['nativePrintedPage4'],closureProof=exam['closureProof'],scope='current regular lesson room-change public rows only; excludes separate midterm-exam source',physicalCampusConfirmed=False,completionClaim=False)
(R/'yu-current-regular-roomchange-proof-v1.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
groups=collections.defaultdict(list)
for r in rows:groups[r['values']['수강번호']].append(r)
notes='공개 예약 계획, 실제 등교·집중이수/온라인 운영 날짜 미확인. 현재2026-2 정보전산원 정규수업 강의실 변경 공지의 수강번호·학부학과·학년·이수구분·교수·강의시간·변경 전후 방·적용기간·비고 원문을 보존합니다. 수강번호는 등록 참조번호이며 공식 과목코드·분반은 미공개로 빈값입니다. 학점과 수강제한도 미공개입니다. 개설학부학과는 수강제한으로 추정하지 않습니다. 변경 없음은 원문 변경전 강의실을 유지합니다. 변경 강의실 적용 시작일 이후만 예약합니다. 현재 학부 학사일정에 따라10/20–26중간시험과 공휴일 예약을 제외하고12/8공식 보강시작 전12/7까지만 일반 예약합니다. 개별 시험·보강을 생성하지 않으며 실제 출석/전체 운영 확인 주장이 아닙니다. 별도 중간시험 시간표의 고사실/시각을 정규수업으로 사용하지 않았습니다. 물리캠퍼스 및 전체 최신폐강·변경은 미확인입니다. 수업방식 미지정으로 사용자 선택을 유지합니다.'
cs=[];closurekeys={x['values']['수강번호'] for x in exam['closureProof']['nativeRows']}
for code,native in groups.items():
 v=native[0]['values'];assert all(all(x['values'][k]==v[k] for k in ['교과목명','강의시간','담당교수','변경 전 강의실','변경 후 강의실','변경 기간','과정구분']) for x in native)
 room=v['변경 전 강의실'].strip() if v['변경 후 강의실']=='변경 없음' else v['변경 후 강의실'];period=re.fullmatch(r'2026\.(\d\d)\.(\d\d)~(\d\d)\.(\d\d)',v['변경 기간']);assert period
 start=dt.date(2026,int(period[1]),int(period[2]));end=min(dt.date(2026,int(period[3]),int(period[4])),dt.date(2026,12,7));slots=[]
 for segment in v['강의시간'].split():
  m=re.fullmatch(r'([월화수목금])((?:[1-9][AB],?)+)',segment);assert m,segment
  for label in m[2].split(','):
   a,b=clocks[label];minute=lambda t:int(t[:2])*60+int(t[3:]);slots.append(dict(weekday='월화수목금'.index(m[1])+1,startMinute=minute(a),endMinute=minute(b),classroom=room))
 apps=[];d=start
 while d<=end:
  if code not in closurekeys and d.isoformat() not in ['2026-10-03','2026-10-05','2026-10-09'] and not dt.date(2026,10,20)<=d<=dt.date(2026,10,26):apps.extend(dict(x,date=d.isoformat()) for x in slots if x['weekday']==d.isoweekday())
  d+=dt.timedelta(days=1)
 cs.append(dict(sourceId=f'yu/unknown/2026-2/roomchange-enrollment-{code}',campus='unknown',academicYear=2026,semester='2',courseCode='',section='',courseName=v['교과목명'],professor=v['담당교수'],classification=v['과정구분'],credits=None,departments=list(dict.fromkeys(x['values']['학부(과)명'] for x in native)),departmentCredits={},departmentClassifications={},sourceSchedule=v['강의시간'],sourceClassroom=room,remarks=notes+' 원문 수강번호: '+code+(' 비고: '+v['비 고'] if v['비 고'] else ''),scheduleStatus='scheduled' if apps else 'unrecognized',schedules=apps,period={'startDate':start.isoformat(),'endDate':dt.date(2026,int(period[3]),int(period[4])).isoformat()},metadata=dict(originalEducationalRecords=native,nativeEnrollmentCode=code,referenceKind='publishedEnrollmentCode',sourceCodePublished=False,sourceSectionPublished=False,sourceCreditsPublished=False,actualAttendanceConfirmed=False,physicalCampusConfirmed=False,currentWholeClosureVerified=False,publishedClosureMatch=code in closurekeys,deliveryModeStatus='unknown-user-choice',originalApplicablePeriod=v['변경 기간'],researchOnly=True)))
raw=dict(schemaVersion=2,universityId='yu',campus='unknown',campusName='물리 캠퍼스 미확인',academicYear=2026,semester='2',publishedDate='2026-09-22',sourceUrl=proof['noticeUrl'],researchOnly=True,completionClaim=False,courses=cs)
(R/'yu-unknown-2026-2.regular-planned-v1.json').write_text(json.dumps(raw,ensure_ascii=False,indent=2)+'\n');print(len(rows),len(cs),sum(len(c['schedules']) for c in cs))
