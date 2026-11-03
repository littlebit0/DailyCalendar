"""Current printed undergraduate reference rows, no invented canonical code/section/time."""
import copy,hashlib,json,pathlib
from pypdf import PdfReader
import re
ROOT=pathlib.Path(__file__).resolve().parents[4];OUT=pathlib.Path(__file__).parent;BASE=OUT.parent
RAW=pathlib.Path('/private/tmp/mju-2026-2-business-public-increase.pdf')
text=PdfReader(RAW).pages[0].extract_text()
rows=[]
for line in text.splitlines():
 if re.match(r'^\d{4}\s',line):
  a=line.split();assert len(a)==8,(line,len(a))
  rows.append({'nativeLectureNumber':a[0],'courseName':a[1],'nativeKoreanCourseCode':a[2],'professor':a[3],'sourcePage':1,'sourceEducationalRow':len(rows)+1})
assert len(rows)==44 and len({x['nativeLectureNumber'] for x in rows})==44
online=json.loads((BASE/'mju-current-online-education-20261008.json').read_text())['educationRows'];by={x['nativeLectureNumber']:x for x in online}
closed=json.loads((BASE/'mju-current-final-closure-education-20261008.json').read_text())['closedCourses']
closure=[x for x in rows if any(y['nativeLectureNumber']==x['nativeLectureNumber'] and y['courseName']==x['courseName'] for y in closed)]
assert not closure
alias=[];courses=[]
for r in rows:
 if r['nativeLectureNumber'] in by:
  old=by[r['nativeLectureNumber']];assert old['courseName']==r['courseName'] and old['professor']==r['professor']
  alias.append({'currentPrintedRow':r,'existingReference':{'nativeLectureNumber':old['nativeLectureNumber'],'nativeCourseCode':old['nativeCourseCode'],'campus':old['campus']},'join':'Exact current native lecture number, title and professor; new provenance only, existing original object remains byte-unchanged.'});continue
 note='2026-2 경영대학 전공 증원 공지의 공개 교육 참조입니다. 실제 인쇄 강좌번호 '+r['nativeLectureNumber']+' 및 한글코드 '+r['nativeKoreanCourseCode']+'를 보존했습니다. 정식 8문자 교과목코드/숫자 분반/학점/강의실/요일/시각/개별 캠퍼스는 해당 원문에 미공개입니다. 강좌번호를 분반으로 변형하지 않았습니다. 현재 최종폐강9/9 목록 native강좌번호·제목 대조에서 일치 없음; 이후 MSI변경 미확인. 정규 일정은 미생성입니다.'
 courses.append({'sourceId':'mju/unknown/2026-2/lecture-'+r['nativeLectureNumber'],'campus':'unknown','academicYear':2026,'semester':'2','courseCode':'','section':'','courseName':r['courseName'],'professor':r['professor'],'classification':'전공','classificationGroup':'전공','credits':None,'departments':['경영대학'],'departmentCredits':{},'departmentClassifications':{'경영대학':'전공'},'departmentRemarks':{'경영대학':note},'remarks':note,'sourceSchedule':'','sourceClassroom':'','scheduleStatus':'unrecognized','schedules':[],'referenceKind':'nativeLectureNumber','canonicalSubjectCodePublished':False,'nativeSectionPublished':False,'nativeLectureNumber':r['nativeLectureNumber'],'sourceEducation':{**r,'printedCodeKind':'한글코드','sourceCodePublished':True,'canonicalEightCharacterCodePublished':False,'sourceCampusPublished':False,'sourceCreditsPublished':False,'classificationEvidence':'공식 제목 전공 교과목 목록','nativeColumns':['강좌번호','교과목명','한글코드','담당교수'],'aggregateCapacityColumnsOmitted':True,'actualOperatingVerified':False,'wholeLatestChangesConfirmed':False}})
assert len(courses)==41 and len(alias)==3
(OUT/'business-current-printed-education.json').write_text(json.dumps({'researchOnly':True,'completionClaim':False,'noticeUrl':'https://www.mju.ac.kr/bbs/sba/99/234756/artclView.do','sourceUrl':'https://www.mju.ac.kr/bbs/sba/99/179947/download.do','publishedDate':'2026-08-28','sourceSHA256':hashlib.sha256(RAW.read_bytes()).hexdigest(),'academicYear':2026,'semester':'2','nativeHeading':'2026-2학기 경영대학 수강신청 증원 예정 교과목 목록(전공)_공지용','educationRows':rows,'aggregateCapacityColumnsOmitted':True,'sourceRawSaved':False},ensure_ascii=False,indent=2)+'\n')
(OUT/'mju-unknown-2026-2.business-reference-v2.json').write_text(json.dumps({'schemaVersion':2,'universityId':'mju','campus':'unknown','campusName':'개별 캠퍼스 미공개','academicYear':2026,'semester':'2','sourceUrl':'https://www.mju.ac.kr/bbs/sba/99/234756/artclView.do','publishedDate':'2026-08-28','researchOnly':True,'completionClaim':False,'wholeSchoolCourseCoverageComplete':False,'wholeOperatingVerified':False,'courses':courses},ensure_ascii=False,indent=2)+'\n')
(OUT/'cross-source-native-aliases.json').write_text(json.dumps(alias,ensure_ascii=False,indent=2)+'\n')
oldfiles=[BASE/'mju-humanities-2026-2.art-online-partial-v1.json',BASE/'mju-natural-2026-2.art-online-partial-v1.json']
(OUT/'candidate-audit.json').write_text(json.dumps({'researchOnly':True,'completionClaim':False,'sourceRows':44,'nativeReferences':44,'newUniqueReferenceObjects':41,'existingNativeAliases':3,'priorObjects':100,'unionNativeReferenceObjects':141,'scheduledObjectsUnchanged':7,'datedReservationsUnchanged':172,'newScheduledObjects':0,'sourceScope':'Current business capacity-increase subset, not a whole-catalog query or first page','closuresExactNativeReferenceJoin':closure,'original100CandidatesSHA':{x.name:hashlib.sha256(x.read_bytes()).hexdigest() for x in oldfiles},'actualModelTest':'pending SDK slot; metadata-only new rows','noProductOrSDKUse':True},ensure_ascii=False,indent=2)+'\n')
print('44 printed / 41 new / 3 source aliases / existing100 preserved')
