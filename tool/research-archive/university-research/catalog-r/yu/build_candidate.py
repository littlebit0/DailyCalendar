"""Current official exam references, education whitelist only; no inferred weekly course plans."""
import datetime as dt,hashlib,json,re
from pathlib import Path
from openpyxl import load_workbook
from pypdf import PdfReader
R=Path(__file__).parent;T=Path('/private/tmp')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(n,v):(R/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
url='https://uni.yu.ac.kr/main/bachelor/bachelor-guide.do?articleNo=231865021&mode=view';sources=[];native=[]
for k,a in [('midterm-day',379003),('midterm-night',379004)]:
 p=T/f'daily-yu-{k}.xlsx';s=load_workbook(p,data_only=True).active;headers=list(next(s.iter_rows(min_row=4,max_row=4,values_only=True)));sources.append(dict(sourceKind=k,attachmentUrl=f'https://uni.yu.ac.kr/main/bachelor/bachelor-guide.do?mode=fileDownload&articleNo=231865021&attachNo={a}',sha256=sha(p),nativeHeading=s.cell(1,1).value,sheet=s.title,nativeHeaders=headers))
 for i in range(5,s.max_row+1):
  values=list(next(s.iter_rows(min_row=i,max_row=i,values_only=True)))
  if isinstance(values[0],int):native.append(dict(sourceKind=k,attachmentId=a,sheet=s.title,excelRow=i,values=dict(zip(headers,values))))
assert len(native)==536 and len({r['values']['수강번호'] for r in native})==536
p=T/'daily-yu-closures.xlsx';s=load_workbook(p,data_only=True).active;headers=list(next(s.values));closures=[]
for i,values in enumerate(list(s.values)[1:],2):
 if values[2] and re.fullmatch(r'\d{4}',str(values[2])):
  # Exclude unrelated or masked personnel fields from the public closure attachment.
  closures.append(dict(excelRow=i,values={headers[n]:values[n] for n in [0,1,2,3,4,6,7]}))
closurekeys={r['values']['수강번호'] for r in closures}
currentGuide=PdfReader(T/'daily-yu-guide.pdf');calendar=currentGuide.pages[3].extract_text();timetable=currentGuide.pages[20].extract_text() # locate precisely below
for page in currentGuide.pages:
 txt=page.extract_text() or ''
 if '▣ 수업시간표' in txt:timetable=txt[txt.index('▣ 수업시간표'):txt.index('▣ 강의동 번호')]
proof=dict(reviewDate='2026-10-08',noticeUrl=url,noticePublishedDate='2026-09-29',nativeCurrentDayAttachmentName='수정-20261008-붙임1. (주간) 2026학년도 2학기 교양, 일반선택 중간시험 시간표.xlsx',sources=sources,nativeRows=native,currentUndergraduateCalendar={'attachmentUrl':'https://uni.yu.ac.kr/main/bachelor/bachelor-guide.do?mode=fileDownload&articleNo=231118467&attachNo=375243','sha256':sha(T/'daily-yu-guide.pdf'),'nativePrintedPage4':calendar},currentNativePeriodClockText=timetable,closureProof={'noticeUrl':'https://www.yu.ac.kr/main/bachelor/bachelor-guide.do?articleNo=231597435&mode=view','attachmentUrl':'https://www.yu.ac.kr/main/bachelor/bachelor-guide.do?mode=fileDownload&articleNo=231597435&attachNo=377357','sha256':sha(p),'nativeRows':closures,'exportedColumns':[headers[n] for n in [0,1,2,3,4,6,7]],'wholeCurrentClosureVerified':False},campusEvidence={'physicalCampusConfirmed':False,'candidateCampus':'unknown','nativeBuildingCodesPreserved':True,'buildingCodeDoesNotAloneAssignCampus':True},currentWholeCatalogVerified=False,sourceAccess={'normalOfficialAttachmentsStatus':200,'authenticatedURPNotAccessed':True,'visibleWindowsOpened':False},completionClaim=False)
save('yu-current-midterm-educational-proof-v1.json',proof)
notes='중간시험 공개 예약 계획, 실제 출석 완료·일반 수업 운영 날짜 미확인. 2026-2 공식 주간/야간 중간시험 공지의 원문 수강번호·과목명·이수구분·담당교수·시험시각·고사실·수정사항을 보존합니다. 수강번호는 공식 등록 참조번호이며 정식 과목코드나 분반으로 변형하지 않습니다. 과목코드·분반·학점·대상학과/수강제한은 미공개입니다. 고사실에 복수 방이 공표된 경우 원문 그대로 표시하며 개인 고사실 배정을 추측하지 않습니다. 물리 캠퍼스는 확인되지 않아 미확인 범위로 둡니다. 실제 명시된 한 번의 시험 날짜만 예약하며 일반 주간 수업/보강/집중·원격운영을 만들지 않습니다. 원문이 담당교수 개별 공지이면 시험시각 또는 고사실 미확인으로 예약을 보류합니다. 공개 수강정정후 폐강 목록과 대조했으나 전체 최신변경·폐강 확인 완료는 아닙니다. 방식은 미지정으로 사용자 선택을 유지합니다.'
cs=[]
for r in native:
 v=r['values'];m=re.fullmatch(r'(\d+)\.\s*(\d+)\.\(([월화수목금토일])\)\s*(\d\d:\d\d)-(\d\d:\d\d)',v['시험시간']);reason='';appointments=[]
 if v['수강번호'] in closurekeys:reason='현재 공개 폐강 목록과 수강번호 일치'
 elif not m:reason='담당교수 개별 공지: 시험시각 미확인'
 elif not v['고사실'] or '개별 공지' in v['고사실']:reason='담당교수 개별 공지: 고사실 미확인'
 else:
  date=dt.date(2026,int(m[1]),int(m[2]));assert date.isoweekday()=='월화수목금토일'.index(m[3])+1;assert dt.date(2026,10,20)<=date<=dt.date(2026,10,26)
  minute=lambda s:int(s[:2])*60+int(s[3:]);a,b=minute(m[4]),minute(m[5]);assert b>a
  appointments=[dict(date=date.isoformat(),weekday=date.isoweekday(),startMinute=a,endMinute=b,classroom=v['고사실'])]
 cs.append(dict(sourceId=f"yu/unknown/2026-2/{r['sourceKind']}/enrollment-{v['수강번호']}",campus='unknown',academicYear=2026,semester='2',courseCode='',section='',courseName=v['교과목명'],professor=v['담당교수'],classification=v['이수구분'],credits=None,departments=[],departmentCredits={},departmentClassifications={},sourceSchedule=v['시험시간'],sourceClassroom=v['고사실'] or '',remarks=notes+' 원문 수강번호: '+v['수강번호']+(' / 원문 수정사항: '+v['수정사항'] if v.get('수정사항') else '')+(' / 예약 보류: '+reason if reason else ''),scheduleStatus='scheduled' if appointments else 'unrecognized',schedules=appointments,period={'startDate':'2026-09-01','endDate':'2026-12-18'},metadata=dict(originalEducationalRecord=r,sourceCodePublished=False,sourceSectionPublished=False,nativeEnrollmentCode=v['수강번호'],referenceKind='publishedEnrollmentCode',sourceClassificationPublished=True,sourceCreditsPublished=False,sourceNativeStudyType=r['sourceKind'],actualAttendanceConfirmed=False,deliveryModeStatus='unknown-user-choice',currentWholeClosureVerified=False,publishedClosureMatch=v['수강번호'] in closurekeys,heldReason=reason,physicalCampusConfirmed=False,researchOnly=True,reservationBasis='current-exact-midterm-examination-date-clock-room')))
save('yu-unknown-2026-2.midterm-planned-v1.json',dict(schemaVersion=2,universityId='yu',campus='unknown',campusName='물리 캠퍼스 미확인',academicYear=2026,semester='2',publishedDate='2026-10-08',sourceUrl=url,researchOnly=True,completionClaim=False,courses=cs))
print(json.dumps(dict(rows=len(cs),scheduled=sum(bool(c['schedules']) for c in cs),held=sum(not c['schedules'] for c in cs),closures=len(closures),closureMatches=sum(c['metadata']['publishedClosureMatch'] for c in cs))))
