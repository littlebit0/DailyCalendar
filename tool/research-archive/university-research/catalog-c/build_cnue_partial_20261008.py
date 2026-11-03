from pathlib import Path
import json,re,html,hashlib,datetime
p=Path('work/university-research/catalog-c/cnue-current-20261008')
def save(n,v):(p/n).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
s=Path('/private/tmp/cnue-cpr-fresh.html').read_text()
tables=re.findall(r'<table\b[^>]*>.*?</table>',s,re.S)
table=next(t for t in tables if '실습일자' in t)
def plain(t):return re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]+>',' ',t))).strip()
rows=[]
for row in re.findall(r'<tr\b[^>]*>.*?</tr>',table,re.S):
 cells=[plain(x) for x in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>',row,re.S)]
 rows.append(cells)
print(rows)
receipt={'sourceUrl':'https://www.cnue.ac.kr/cnue/news/notice02.do?mode=view&articleNo=41588','tableRows':rows,'tableEducationalHtml':table,'room':'체육관 102호','studentConditions':'3학년 학과별 일괄배정; 부득이한 경우 개별 변경 가능, 개별 신청기간 9/30까지 연장. 졸업 및 교원자격 무시험검정 합격기준 실습 2회 이상 이수. 개인 변경·참석 확정은 공개하지 않음.','educationalBody':plain(s[s.index('실습일자'):s.index('문의:',s.index('실습일자'))])}
save('cpr-educational-receipt.json',receipt)
raw=json.loads((p/'cnue-unknown-2026-2.document-metadata-only-20261008.json').read_text())
plans=[('2026-09-14',840,1020,['국어','컴퓨터','음악']),('2026-10-02',600,780,['교육','수학']),('2026-10-02',840,1020,['과학','미술','사회']),('2026-10-14',600,780,['윤리']),('2026-10-22',600,780,['실과','체육','영어'])]
for i,(date,a,b,deps) in enumerate(plans,1):
 raw['courses'].append({'sourceId':f'cnue-document41588-table-row{i}','referenceKind':'공개 공지 표 행 내부 위치(공식 과목번호 아님)','canonicalSubjectCodePublished':False,'nativeSectionPublished':False,'academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','section':'','courseName':'응급처치 및 심폐소생술 실습','professor':'','credits':None,'classification':'','classificationGroup':'','departments':['3학년 '+d for d in deps],'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{},'sourceSchedule':date+' '+f'{a//60:02}:00~{b//60:02}:00','sourceClassroom':'체육관 102호','sourceNoticeTableRow':i,'nativeActivityKind':'졸업·교원자격 무시험검정 요건 실습(정규 교과목 여부 미공개)','remarks':'춘천교대 공식 공개 2026년 2학기 응급처치 및 심폐소생술 실습의 학과별 기본 배정입니다. 정규 교과목 여부·과목코드·분반·학점·강사·이수구분 미공개. 공식 과목번호 아닌 공개 공지 표 행 위치를 내부 식별자로 사용했습니다. 3학년 학과별 일괄배정이며 부득이한 경우 개별 변경 가능(개별 신청기간 9/30까지 연장), 개인 참석·변경 내역은 확인하지 않았습니다. 졸업 및 교원자격 무시험검정 요건으로 실습 2회 이상 이수해야 합니다. 공개 날짜·시간·체육관 102호만 보존하며 캠퍼스명 미공개. 정규 강의 교시 시각의 근거로 사용하지 않았습니다.','period':{'startDate':date,'endDate':date},'scheduleStatus':'scheduled','schedules':[{'date':date,'weekday':datetime.date.fromisoformat(date).isoweekday(),'startMinute':a,'endMinute':b,'classroom':'체육관 102호'}]})
f='cnue-unknown-2026-2.published-partial-20261008.json';save(f,raw)
a={'candidate':{'file':f,'sha256':hashlib.sha256((p/f).read_bytes()).hexdigest()},'documentMetadata':203,'totalMetadata':208,'scheduled':5,'datedPlans':5,'held':203,'completionClaim':False,'nativeOfferingCountClaim':False,'regularClassPeriodClocksVerified':False,'scheduledKind':'졸업·교원자격 요건 실습의 학과별 공개 기본 배정, 개인 참석 확정 아님'};save('partial-audit.json',a)
closed=json.loads(Path('work/university-research/catalog-q/cnue2026-2-cancelled-courses.json').read_text())
closed['freshOriginalSha256']=hashlib.sha256(Path('/private/tmp/cnue-cancelled-fresh.xlsx').read_bytes()).hexdigest();closed['freshByteEqualPrior']=Path('/private/tmp/cnue-cancelled-fresh.xlsx').read_bytes()==Path('work/university-research/catalog-q/cnue2026-2-cancelled.xlsx').read_bytes()
closed['exactSameGradeTitleDocumentMetadataMatches']=[]
for c in closed['courses']:
 for x in raw['courses'][:203]:
  if x['courseName']==c['교과목명'] and x['departments'][0].startswith(c['학년']):closed['exactSameGradeTitleDocumentMetadataMatches'].append(x['sourceId'])
closed['joinLimitation']='공식 과목코드·분반 미공개로 전체 폐강 identity 정합성은 미확인. 203 단일 문서 항목에는 동일 학년·정확 과목명의 폐강 목록 매치 없음. 다중 선택 셀은 이미 보류; 제목 기반 폐강 없음 주장 아님.'
save('closure-educational-receipt.json',closed)
s=Path('/private/tmp/cnue-calendar-fresh.html').read_text();s=s[s.index('<span>2026</span>'):];s=s[:s.index('개인정보 처리방침')];save('calendar-educational-receipt.json',{'sourceUrl':'https://www.cnue.ac.kr/cnue/info/schedule.do?mode=list&cYear=2026&allYn=Y','educationalText':plain(s)})
print(a)
