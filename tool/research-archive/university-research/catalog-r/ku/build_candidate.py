"""Educational whitelist from current official Sejong department timetable."""
import collections,datetime as dt,hashlib,html,json,re
from pathlib import Path
R=Path(__file__).parent
URL='https://spa.korea.ac.kr/bbs/spa/149/271438/artclView.do'
ATT='https://spa.korea.ac.kr/bbs/spa/149/181339/download.do'
tables=json.loads(Path('/private/tmp/daily-ku-spa-current-tables.json').read_text())
calendar=[]
for month,filename in [(9,'daily-ku-sejong-calendar-9.html'),(10,'daily-ku-sejong-calendar.html'),(12,'daily-ku-sejong-calendar-12.html')]:
 b=Path('/private/tmp/'+filename).read_bytes();s=b.decode();s=s[s.find('id="schdulWrap"'):] if month==10 else s
 # The details table ends before site chrome; retain educational calendar only.
 s=s[s.find('상세일정'):];s=s[:s.find('</table>')+8]
 t=html.unescape(re.sub('<[^>]*>',' ',s));t=re.sub(r'\s+',' ',t).strip()
 calendar.append(dict(month=month,sourceUrl='https://env.korea.ac.kr/koreaSejong/7935/subview.do',normalMonthPost={'url':'https://env.korea.ac.kr/schdulMng/koreaSejong/2/monthSchdul.do','kind':'','year':'2026','month':str(month)},sourceSha256=hashlib.sha256(b).hexdigest(),nativeEducationalCalendarText=t))
proof=dict(reviewDate='2026-10-08',noticeUrl=URL,attachmentUrl=ATT,sourceSha256=hashlib.sha256(Path('/private/tmp/daily-ku-spa-current.hwp').read_bytes()).hexdigest(),nativeHeading='강 의 시 간 표 (2026학년도 2학기) 7월 30일 현재',tables=tables,nativeFooter='* 논문대체과목 - 시민사회와자치, 도시및지역개발론, 행정학특강, 지방정부론, 범죄수사학, 정책과철학, [서비스러닝]행정과리더십, 인적자원개발과CDP, 행동행정학',campusEvidence={'sourceUrl':URL,'nativeSiteName':'고려대학교 세종캠퍼스 정부행정학부','nativeEducationalLocation':'고려대학교 세종캠퍼스 공공정책관','roomPrefix':'2-','roomBuildingCodeMeaningVerified':False,'actualPhysicalAttendanceDatesConfirmed':False},calendars=calendar,midtermNotice={'sourceUrl':'https://spa.korea.ac.kr/bbs/spa/149/273443/artclView.do','publishedDate':'2026-10-07','nativeText':'일 정 : 10월20일(화)~10월26일(월). 모든 교과목의 시험은 이 기간 중에 별도의 휴강 없이 각 교과목의 담당 교수/강사 재량에 따라 시행함.','reservationPolicy':'No inferred individual exam or teaching dates in this week.'},currentWholeClosureVerified=False,sourceAccess={'publicListUrl':'https://sugang.korea.ac.kr/p/v/lectList?lang=ko','currentPublicListGetStatus':200,'officialSearchNeedsNetFunnelAdmission':True,'searchWithoutAdmissionAttempted':False,'historicalSample53NotReacquired':True,'currentSejongRegistrationNoticeUrl':'https://siae.korea.ac.kr/bbs/economics/158/270444/artclView.do','nativeClosureAnnouncementDates':['2026-08-26','2026-09-10','2026-09-23'],'wholeNativeRowsCollected':False})
proof['currentSejongClockGuide']={'sourceUrl':'https://siae.korea.ac.kr/bbs/economics/158/180360/download.do','sourceSha256':hashlib.sha256(Path('/private/tmp/daily-ku-sejong-reg.hwp').read_bytes()).hexdigest(),'nativeTable':json.loads(Path('/private/tmp/daily-ku-sejong-reg-tables.json').read_text())[6]}
(R/'ku-sejong-current-educational-proof-v1.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
# Extract only current educational curriculum table, keeping its distinct scope.
s=Path('/private/tmp/daily-ku-spa-table.html').read_text();i=s.find('이수구분');j=s.find('</table>',i);tab=s[i:j];txt=html.unescape(re.sub('<[^>]*>',' ',tab));txt=re.sub(r'\s+',' ',txt).strip()
refs={}
for m in re.finditer(r'(DPAD\d{3})\s+([^0-9]+?)\s+3\(3\)',txt):refs[m[2].strip()]=m[1]
(R/'ku-spa-current-curriculum-reference-v1.json').write_text(json.dumps(dict(sourceUrl='https://spa.korea.ac.kr/spa/12238/subview.do',nativeScope='2025~2026학년도 정부행정학부 교과과정표',nativeEducationalText=txt,sourceSha256=hashlib.sha256(Path('/private/tmp/daily-ku-spa-table.html').read_bytes()).hexdigest(),exactTitleCodeReferences=refs,offeringNativeCodeAssignmentAllowed=False,offeringClassificationAssignmentAllowed=False),ensure_ascii=False,indent=2)+'\n')
groups=collections.defaultdict(list);held=[]
for c in tables[0]['cells']:
 if not(c['row']>0 and c['col']>0):continue
 raw=' '.join(c['paragraphs']).strip()
 if not raw:continue
 if '창업과진로:' in raw:
  for m in re.finditer(r'\((\d{2})반\)(2-\d{3})\s*\(([^)]+)\)',raw):
   groups[('창업과진로',m[1])].append(dict(nativeCell=c,nativeRaw=raw,weekday=c['col'],period=c['row'],classroom=m[2],professor=m[3],title='창업과진로',section=m[1],heldReason='통합운영 강의실2-226와 분반별 강의실 운영 대응 미확인'))
  continue
 pos=0
 for m in re.finditer(r'(.*?)\s+(2-\d{3})\s*\(([^)]+)\)',raw):
  title=m[1].strip();sec=re.search(r'\((\d{2})반\)',title);section=sec[1] if sec else '';title=re.sub(r'\(\d{2}반\)','',title).strip()
  groups[(title,section)].append(dict(nativeCell=c,nativeRaw=raw,weekday=c['col'],period=c['row'],classroom=m[2],professor=m[3],title=title,section=section,heldReason=''));pos=m.end()
 assert pos==len(raw),raw
notes='공개 예약 계획, 실제 등교·집중이수/온라인 운영 날짜 미확인. 2026-07-30 현재 정부행정학부 공개 시간표의 원문 제목·실제 분반·교수·교시·강의실을 보존합니다. 과목코드·학점·개설분반 이수구분은 미공개이며 임의로 만들지 않습니다. 내부 식별자는 원문 표 위치 기반이며 공식 강좌번호가 아닙니다. 9월 이후 전체 폐강·최신 변경은 미확인입니다. 개별 집중이수·시험·보강·원격 운영 날짜는 미확인입니다. 방식은 미지정으로 사용자의 선택을 유지합니다. 세종캠퍼스 공식9월1일개강/12월18일종강, 중간10월20~26일/기말12월14~18일 및 공휴일을 기준으로 시험주·휴일 예약을 제외합니다. 중간고사 공지는 일괄 휴강 없이 교수 재량 운영임을 명시하므로 제외는 예약 보류이며 휴강 확정 주장이 아닙니다. 기말 직전12월13일까지의 일반 주간 예약만 생성하며 별도 보강을 만들지 않습니다.'
cs=[]
for (title,section),native in groups.items():
 first=native[0];cell=first['nativeCell'];reason=first['heldReason'];spans=[]
 if not reason:
  for x in native:spans.append(dict(weekday=x['weekday'],startMinute=(8+x['period'])*60,endMinute=(8+x['period'])*60+50,classroom=x['classroom']))
 appointments=[];d=dt.date(2026,9,1)
 while d<=dt.date(2026,12,13):
  if d.isoformat() not in ['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'] and not(dt.date(2026,10,20)<=d<=dt.date(2026,10,26)):
   appointments += [dict(x,date=d.isoformat()) for x in spans if x['weekday']==d.isoweekday()]
  d+=dt.timedelta(days=1)
 cs.append(dict(sourceId=f"korea/sejong/2026-2/spa-181339-t0-r{cell['row']}-c{cell['col']}-item{list(groups).index((title,section))+1}",campus='sejong',academicYear=2026,semester='2',courseCode='',section=section,courseName=title,professor=first['professor'],classification='',credits=None,departments=['정부행정학부'],departmentCredits={},departmentClassifications={},sourceSchedule=' / '.join(f"{'월화수목금'[x['weekday']-1]}{x['period']}교시" for x in native),sourceClassroom=' / '.join(dict.fromkeys(x['classroom'] for x in native)),remarks=notes+(' 원문 분반도 미공개입니다.' if not section else '')+(' 논문대체과목(원문). ' if title in ['시민사회와자치','도시및지역개발론','행정학특강','지방정부론','범죄수사학','정책과철학','[서비스러닝]행정과리더십','인적자원개발과CDP','행동행정학'] else '')+(' 예약 보류: '+reason if reason else ''),scheduleStatus='scheduled' if appointments else 'unrecognized',schedules=appointments,period={'startDate':'2026-09-01','endDate':'2026-12-18'},metadata=dict(originalEducationalCells=native,sourceCodePublished=False,sourceSectionPublished=bool(section),nativeSection=section,sourceNativeTitle=title,referenceKind='publishedCourseTitle',internalIdKind='source-document-native-cell-position',sourceClassificationPublished=False,sourceCreditsPublished=False,curriculumTitleReference=refs.get(title),curriculumReferenceIsOfferingCode=False,researchOnly=True,currentWholeClosureVerified=False,actualAttendanceConfirmed=False,actualPhysicalDatesConfirmed=False,deliveryModeStatus='unknown-user-choice',heldReason=reason)))
data=dict(schemaVersion=2,universityId='korea',campus='sejong',campusName='세종캠퍼스',academicYear=2026,semester='2',publishedDate='2026-07-30',sourceUrl=URL,researchOnly=True,completionClaim=False,courses=cs)
(R/'korea-sejong-2026-2.reservation-planned-v1.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');print(json.dumps(dict(rows=len(cs),scheduled=sum(bool(c['schedules']) for c in cs),appointments=sum(len(c['schedules']) for c in cs),nativeSlots=sum(len(c['metadata']['originalEducationalCells']) for c in cs),held=[c['courseName']+' '+c['section'] for c in cs if not c['schedules']]),ensure_ascii=False))
