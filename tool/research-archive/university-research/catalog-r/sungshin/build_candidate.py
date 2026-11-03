"""Freeze educational fields from official current undergraduate public attachments."""
import datetime as dt, hashlib, html, json, re
from pathlib import Path
from openpyxl import load_workbook
from pypdf import PdfReader
R=Path(__file__).parent
T=Path('/private/tmp')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def clean(s): return re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]*>',' ',s))).strip()
def save(name,value): (R/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
notice='https://sungshin.ac.kr/bbs/main_eng/4941/158286/artclView.do'
attachment='https://sungshin.ac.kr/bbs/main_eng/4941/112810/download.do'
w=load_workbook(T/'daily-sungshin-foreign-xlsx.xlsx',data_only=True);s=w['Sheet1'];headers=[c.value for c in s[3]]
native=[dict(excelRow=i,values=dict(zip(headers,[c.value for c in s[i]]))) for i in range(4,33)]
pdf=PdfReader(T/'daily-sungshin-guide-pdf.pdf');p5=pdf.pages[4].extract_text();p20=pdf.pages[19].extract_text();p7=pdf.pages[6].extract_text()
calendarbody=p5.split('※ 2026학년도 2학기 수업 제외일')[0]
cells=re.findall(r'(\d+)월(\d+)일\(([월화수목금토])\)',calendarbody)
assert len(cells)==90,len(cells)
weeks=[dict(week=i//6+1,sourceWeekdayColumn=i%6+1,nativeText=f'{m}월{d}일({day})',date=f'2026-{int(m):02}-{int(d):02}',actualWeekday=dt.date(2026,int(m),int(d)).isoweekday()) for i,(m,d,day) in enumerate(cells)]
clockbody=(T/'daily-sungshin-clock.html').read_text(encoding='utf-8-sig')
clocks=[dict(nativePeriod=int(n),nativeStart=a,nativeEnd=b) for n,a,b in re.findall(r'(\d+)교시<BR>\((\d\d:\d\d)~(\d\d:\d\d)\)',clockbody,re.I)]
assert len(clocks)==12
cal=[]
for m in [9,10,12]:
 b=(T/f'daily-sungshin-calendar-{m}.html').read_bytes();txt=b.decode();txt=txt[txt.index('id="cal"'):]
 cal.append(dict(month=m,sourceUrl='https://www.sungshin.ac.kr/main_kor/10999/subview.do',normalPublicMonthPost={'url':'https://www.sungshin.ac.kr/schdulmanage/main_kor/25/yearSchdul.do','year':'2026','kind':'N','month':str(m)},sha256=hashlib.sha256(b).hexdigest(),nativeEvents=[clean(x) for x in re.findall(r'<dl[^>]*>(.*?)</dl>',txt,re.S)]))
closures=[]
for phase,id_ in [(1,158631),(2,159070)]:
 p=T/f'daily-sungshin-closures{phase}.html';body=p.read_text();rows=[]
 for t in re.findall(r'<table\b.*?</table>',body,re.S):
  if '학수번호' not in clean(t):continue
  for row in re.findall(r'<tr\b.*?</tr>',t,re.S):
   values=[clean(v) for v in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>',row,re.S)]
   if len(values)==7 and re.fullmatch(r'[A-Z]{2}\d{6}',values[3]):rows.append(values)
 closures.append(dict(phase=phase,sourceUrl=f'https://www.sungshin.ac.kr/bbs/main_kor/3181/{id_}/artclView.do',sha256=sha(p),nativeColumns=['연번','과목구분','개설학과','학수번호','분반','교과목명','시간표'],nativeRows=rows,wholeCurrentClosureVerified=False))
assert [len(x['nativeRows']) for x in closures]==[15,12]
keys={(x[3],int(x[4])) for p in closures for x in p['nativeRows']}
assert not any((x['values']['학수번호'],int(x['values']['분반'])) in keys for x in native)
proof=dict(reviewDate='2026-10-08',universityId='sungshin',nativeScope='2026-2학기 국제학생 전용 학부 공개 과목 부분',noticeUrl=notice,noticePublishedDate='2026-08-12',noticeModifiedDate='2026-08-13',attachmentUrl=attachment,attachmentSha256=sha(T/'daily-sungshin-foreign-xlsx.xlsx'),sheet='Sheet1',nativeHeaders=headers,nativeRows=native,currentUndergraduateGuide={'noticeUrl':'https://www.sungshin.ac.kr/bbs/main_kor/3181/157409/artclView.do','attachmentUrl':'https://www.sungshin.ac.kr/bbs/main_kor/3181/112213/download.do','modifiedDate':'2026-07-23','sha256':sha(T/'daily-sungshin-guide-pdf.pdf'),'nativePage5':p5,'nativeWeekdayTeachingCells':weeks,'nativeUndergraduateScope':'2026학년도 2학기 수강신청 안내(학부)','nativeTimeGuideInstruction':'시간표: 강의시간편성표 메뉴에서 시간 확인 가능(예: 1교시 - 09:00~09:50)','nativeCampusBuildingLegend':p20[p20.index('캠퍼스 (약어)'):p20.index('2. 개설강좌조회')],'nativeIntensiveInstruction':'2026학년도 2학기 집중이수제 시범운영. 대상 강좌는 별도 공지 예정. 상세 수업시간은 대상 교과목별 수업계획서 참고(학기당 8주 수업).'},currentPublicClock={'sourceUrl':'https://sugang.sungshin.ac.kr/html/timeRef.htm','sha256':sha(T/'daily-sungshin-clock.html'),'nativeRows':clocks},academicCalendars=cal,examProof={'sourceUrl':notice,'nativeText':'기말고사 2026.12.8.~12.28. / Final Test Period 2026.12.8.~12.28.','sourceCalendarNativeLabel':'성적평가','midtermDatesPublishedInInspectedSources':False,'reservationPolicy':'12월8일 이후 모든 예약 보류; 중간 개별 시험/수업 구분 미확인'},closureNotices=closures,sourceAccess={'normalAnonymousLandingStatus':200,'normalAnonymousQueryPageStatus':200,'nativePublicInstruction':'수강신청시스템에 로그인하지 않아도 개설강좌조회 메뉴에서 개설학과전공 선택 후 개설강좌를 조회할 수 있음','publishedQueryNeedsAdmission':'NetFunnel_Action({action_id:"act_1"}, callback) guards OnLoad, ByDept, Main and plan requests','directQueryWithoutAdmissionAttempted':False,'loginAttempted':False},completionClaim=False)
save('sungshin-current-educational-proof-v1.json',proof)
notes='공개 예약 계획, 실제 등교·집중이수/온라인 운영 날짜 미확인. 외국인 전용 학부 공개 과목의 원문 학수번호·숫자 분반·학점/이론/실습·언어·지정내용·수정/운정 캠퍼스를 보존합니다. 교수·강의실·개설분반 이수구분은 미공개입니다. 2026-2 학부 안내 p5의 개별 공표 요일별 수업일만 예약하며 일반 주간 반복이나 별도 보강을 만들지 않습니다. 12/8 이후 공식 기말고사/성적평가 기간 예약은 보류합니다. 중간고사 개별 시행 날짜와 실제 수업/시험 구분은 미확인입니다. 10/16 입학전형으로 대면수업 불가 가능성이 공지되어 방식/보강 미확인인 해당 예약은 보류합니다. 집중이수제 8주 대상 여부·개별 운영·시험·보강·최신 시간표 변경은 미확인입니다. 1차/2차 공개 폐강 목록과 대조했으나 별도 학과 폐강·최신 전체 폐강 여부는 미확인입니다. 수업 방식은 미지정으로 사용자의 선택을 유지합니다.'
cs=[]
for x in native:
 v=x['values'];m=re.fullmatch(r'([월화수목금])/([0-9]+)-([0-9]+)',v['시간표']);assert m
 weekday='월화수목금'.index(m[1])+1;periods=list(range(int(m[2]),int(m[3])+1));appointments=[]
 for c in weeks:
  if c['sourceWeekdayColumn']!=weekday or c['date']>='2026-12-08' or c['date']=='2026-10-16':continue
  for period in periods:
   clock=clocks[period-1];a,b=clock['nativeStart'],clock['nativeEnd'];minute=lambda t:int(t[:2])*60+int(t[3:]);appointments.append(dict(date=c['date'],weekday=c['actualWeekday'],startMinute=minute(a),endMinute=minute(b),classroom=''))
 campus='sujeong' if v['캠퍼스']=='수정' else 'unjung';assert v['캠퍼스'] in ['수정','운정']
 cs.append(dict(sourceId=f"sungshin/{campus}/2026-2/112810-Sheet1-row{x['excelRow']}",campus=campus,academicYear=2026,semester='2',courseCode=v['학수번호'],section=str(v['분반']),courseName=v['교과목명'],professor='',classification='',credits=float(v['학점/이론/실습'].split('/')[0]),departments=[v['개설학과전공']],departmentCredits={},departmentClassifications={},sourceSchedule=v['시간표'],sourceClassroom='',remarks=notes+' 강의언어: '+v['강의언어']+' / 외국인 전용; 수강안내 및 지정내용: '+v['수강안내 및 지정내용'],scheduleStatus='scheduled',schedules=appointments,period={'startDate':'2026-09-01','endDate':'2026-12-22'},metadata=dict(originalEducationalRecord=x,sourceCodePublished=True,sourceSectionPublished=True,sourceClassificationPublished=False,sourceProfessorPublished=False,sourceRoomPublished=False,actualAttendanceConfirmed=False,deliveryModeStatus='unknown-user-choice',publishedCampus=v['캠퍼스'],eligibilityScope='외국인 전용',sourceNativeLanguage=v['강의언어'],sourceNativeRestrictions=v['수강안내 및 지정내용'],currentWholeClosureVerified=False,publishedClosureMatch=False,individualIntensiveScopeVerified=False,individualMidtermDatesVerified=False,researchOnly=True,internalIdKind='source-document-sheet-native-row',reservationBasis='current-undergraduate-guide-p5-native-date-cells')))
for campus,name in [('sujeong','수정캠퍼스'),('unjung','운정그린캠퍼스')]:
 save(f'sungshin-{campus}-2026-2.reservation-planned-v1.json',dict(schemaVersion=2,universityId='sungshin',campus=campus,campusName=name,academicYear=2026,semester='2',publishedDate='2026-08-13',sourceUrl=notice,researchOnly=True,completionClaim=False,courses=[c for c in cs if c['campus']==campus]))
print(json.dumps(dict(rows=len(cs),appointments=sum(len(c['schedules']) for c in cs),campuses={c:sum(x['campus']==c for x in cs) for c in ['sujeong','unjung']},closures=[len(x['nativeRows']) for x in closures]),ensure_ascii=False))
