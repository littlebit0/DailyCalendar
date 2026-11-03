"""Current public CELL metadata only; exam clock is never a lecture clock."""
import hashlib,json,pathlib,re
from html.parser import HTMLParser
D=pathlib.Path(__file__).parent/'donga-cell-extension-20261008';D.mkdir(exist_ok=True)
base=pathlib.Path(__file__).parent/'donga-current-20261008'
def write(f,x):(D/f).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
class Text(HTMLParser):
 def __init__(self):super().__init__();self.lines=[]
 def handle_data(self,d):
  if d.strip():self.lines.append(d.strip())
for n in ['8464186','8464181']:
 p=pathlib.Path('/private/tmp/donga-expand-'+n+'.html');b=p.read_text();start=b.index('<h1 class="cms-article__title"');end=b.find('<nav class="cms-article__siblings',start)
 t=Text();t.feed(b[start:end]);lines=t.lines
 if n=='8464186':lines=lines[:lines.index('4. 기타')]
 else:lines=lines[:lines.index('3. 기타사항')]
 write('notice-'+n+'-educational-receipt.json',{'url':'https://wwwnew.donga.ac.kr/article/bbs-62/'+n+'?from=%2Fcommunity%2Facademic-notices','originalSha256':hashlib.sha256(b.encode()).hexdigest(),'publishedDate':'2026-08-04','educationalLines':lines,'rawRetained':False,'contactsExcluded':True})
 p.unlink()
closed={(r['nativeSubjectCode'],r['nativeSection']) for r in json.loads((base/'closure-educational-rows.json').read_text())}
examGroups=[('10',1,['2026-09-19','2026-10-03']),('11',6,['2026-10-24','2026-11-07']),('12',11,['2026-11-28','2026-12-12'])]
courses=[]
for section,week,dates in examGroups:
 if ('01COR146',section) in closed:continue
 remark='2026-08-04 공식 CELL-집중수업 공개 일부입니다. 전체 대학·실시간 변경 완전성 미확인. 5주 온라인(LMS) 1학점 강좌이며 '+str(week)+'주차 개설 '+section+'분반입니다. 고정 실시간 강의 clock 미공개로 수업 일정 미생성. 공개 시험 예정일은 '+', '.join(dates)+' 각15:00~15:30이나 최종 시험일은 분반 공지에서 확인해야 합니다. 시험을 정규 강의시간으로 사용하지 않았습니다. 전체 재학생 대상, 1차8/7까지4학년 우선; 정원미달시2차8/20~21부터전학년추가모집. 무도와인성(유도 및 태권도) 대체교과목. 강의 물리캠퍼스 미공개.'
 courses.append({'sourceId':f'donga-2026-2-01COR146-{section}','referenceKind':'교과목번호','canonicalSubjectCodePublished':True,'nativeSectionPublished':True,'academicYear':2026,'semester':'2','campus':'unknown','nativeCampus':'unknown','sourceOperatingInstitution':'동아대학교 교양대학','courseCode':'01COR146','courseName':'여행과삶:느리게,깊게,다르게','section':section,'professor':'','credits':1,'classification':'중핵교양(1영역)','classificationGroup':'교양','sourceClassificationAliases':['중핵교양','1영역'],'departments':['교양대학'],'departmentCredits':{'교양대학':1},'departmentClassifications':{'교양대학':'중핵교양(1영역)'},'departmentRemarks':{'교양대학':remark},'remarks':remark,'sourceSchedule':'온라인(LMS), '+str(week)+'주차 개설, 5주 진행','sourceClassroom':'온라인(LMS)','scheduleStatus':'unrecognized','period':{'startDate':'2026-09-01','endDate':'2026-12-18'},'schedules':[],'publishedOperatingWeekStart':week,'publishedOperatingWeekCount':5,'publishedExamPlans':[{'date':date,'startMinute':900,'endMinute':930,'kind':'중간고사' if i==0 else '기말고사','finalDateRequiresSectionNotice':True} for i,date in enumerate(dates)],'publicEducationRows':[{'sourceNotice':'8464186','nativeSubjectCode':'01COR146','nativeSection':section,'credits':1,'nativeClassification':'중핵교양(1영역)','nativeWeekStart':week,'sourceDelivery':'온라인(LMS)','sourceCapacity':100}]})
f='donga-unknown-cell-2026-2.published-partial-20261008.json';write(f,{'schemaVersion':2,'universityId':'donga','campus':'unknown','campusName':'캠퍼스 미확인·외부대학 운영','academicYear':2026,'semester':'2','publishedDate':'2026-08-04','sourceUrl':'https://wwwnew.donga.ac.kr/article/bbs-62/8464186?from=%2Fcommunity%2Facademic-notices','courses':courses})
refs=[('01COR153','(DSU)신화와인류문화',2,'중핵교양(1영역)','정규희','월7-10교시(11-13시)','국제협력관1403'),('01COR150','(DSU)클래식스토리텔링',2,'중핵교양(1영역)','정혜영','목5-8교시(10-12시)','UIT003'),('01COR151','(DSU)감수성의탄생:음악',2,'중핵교양(1영역)','김해리','금15-18교시(15-17시)','강의실미정'),('01COR328','(DSU)AI와함께하는대학수학',3,'중핵교양(3영역)','이민아','O2O1시간대면2시간비대면, 월11-12교시(13-14시)','국제협력관1404'),('01COR459','(DSU)한국문화와K-POP',3,'중핵교양(4영역)','오세준','비대면(LMS),대면시험미정','동서대센텀캠퍼스시험'),('01COR331','(DSU)공생:세포에서사회까지',3,'중핵교양(3영역)','정혜영','비대면(LMS),대면시험미정','동서대(주례)시험')]
write('integrated-liberal-education-native-subjects.json',{'sourceNotice':'8464181','rows':[dict(zip(['nativeSubjectCode','courseName','credits','nativeClassification','professor','sourceSchedule','sourceClassroom'],r),nativeSectionPublished=False,section='',sourceOperatingInstitution='동서대학교',candidateIncluded=False) for r in refs],'reason':'Native course number published but course offering section absent; do not fabricate section, teach periods, Dong-A campus or external university actual instruction clock/calendar.','enrollmentAndCredits':'Dong-A enrollment system; Dong-A credit recognition; all external in-person and LMS subjects have Dongseo in-person midterm/final exams.'})
write('extension-audit.json',{'completionClaim':False,'candidate':{'file':f,'sha256':hashlib.sha256((D/f).read_bytes()).hexdigest()},'cellNativePublishedIdentities':3,'cellClosedJoin':[x for x in examGroups if ('01COR146',x[0]) in closed],'candidateClasses':len(courses),'scheduledClasses':0,'publishedExamPlanCount':6,'examPlanUsedAsLecture':False,'integratedNativeSubjects':6,'integratedNativeSectionPublished':False,'productionChanged':False})
print('CELL',len(courses),'integrated subject-only',len(refs))
