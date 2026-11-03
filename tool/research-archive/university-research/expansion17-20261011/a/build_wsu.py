"""Transcribe exact readable native PDF rows; never invent native course codes."""
import pathlib,json,hashlib
P=pathlib.Path(__file__).parent
rows=[
 ('EnglishforWorldCitizenship2','010','',2,'교양',[(1,630,720),(4,780,870)],'1학년'),
 ('AI기반실용대학글쓰기','','',2,'교양',[(2,540,630),(4,540,630)],'1학년'),
 ('자아발견과비전탐색2','001','김영호',1,'교양',[(2,780,840)],'1학년'),
 ('객체지향프로그래밍','001','왕중민',3,'전공',[(1,840,1020)],'1학년'),
 ('객체지향프로그래밍','002','유승선',3,'전공',[(5,540,720)],'1학년'),
 ('모바일앱실습','001','김태원',2,'전공',[(4,630,750)],'1학년'),
 ('모바일앱실습','002','김태원',2,'전공',[(4,870,990)],'1학년'),
 ('클라우드환경운영체제이해','001','조석형',2,'전공',[(2,840,960)],'1학년'),
 ('클라우드환경운영체제이해','002','조석형',2,'전공',[(3,600,720)],'1학년'),
 ('EnglishforWorldCitizenship4','025','',2,'교양',[(2,990,1080),(4,900,990)],'2학년'),
 ('우송비트프로그래밍&AI입문','001','최창민',6,'전공',[(d,1140,1320) for d in range(1,5)],'2학년; 필수 졸업요건'),
 ('AI시대소프트웨어공학','001','김영호',3,'전공',[(4,540,720)],'2학년'),
 ('SW·AI창업환경분석과사업타당성조사','001','김동혁',3,'트랙',[(5,540,720)],'2학년; SW·AI비즈니스창업융합부전공트랙 신청자만 수강 가능'),
]
# The notice's 12+4 restriction explicitly applies to first semester only.
rows += [
 ('AI활용메타버스기술','001','김영호',3,'전공',[(2,540,720)],'3학년'),
 ('머신러닝','001','양현식',3,'전공',[(3,840,1020)],'3학년'),
 ('안드로이드프로그래밍응용','001','소진',3,'전공',[(4,840,1020)],'3학년'),
 ('AI창의융합캡스톤디자인','001','임승철',3,'전공',[(5,600,780)],'4학년; IT융합학부 컴퓨터정보·보안전공 개설 과목으로 수강신청'),
 ('인공지능프로젝트','001','양현식',3,'전공',[(4,840,1020)],'4학년'),
 ('AI와메타버스융합실무','001','소진',3,'트랙',[(4,540,720)],'3학년; 비즈니스창업융합부전공트랙'),
]
held=['IoT자율주행실무(원문17;00 오기)','온라인/시각미정/사전폐강/일반교양제목만인행']
courses=[]
for name,section,prof,credit,kind,times,remark in rows:
 identity=json.dumps([name,section,prof,times,remark],ensure_ascii=False)
 courses.append({'sourceId':'wsu/unknown/2026/2/'+hashlib.sha256(identity.encode()).hexdigest()[:24],'universityId':'wsu','campus':'unknown','campusName':'캠퍼스 미표기','academicYear':2026,'semester':'2','courseCode':'','courseName':name,'section':section,'professor':prof,'credits':credit,'schedules':[{'weekday':d,'startMinute':a,'endMinute':b,'classroom':''} for d,a,b in times],'departments':['컴퓨터·소프트웨어전공'],'departmentCredits':{'컴퓨터·소프트웨어전공':credit},'departmentClassifications':{'컴퓨터·소프트웨어전공':kind},'departmentRemarks':{'컴퓨터·소프트웨어전공':remark+'; 분반 교차신청 불가; 강의실·과목코드 원문 미표기'},'sourcePages':[2], 'sourceSchedule':' / '.join('월화수목금토일'[d-1]+f' {a//60:02}:{a%60:02}~{b//60:02}:{b%60:02}' for d,a,b in times), 'sourceClassroom':'', 'period':{'startDate':'2026-09-01','endDate':'2026-12-14'}})
out={'schemaVersion':1,'universityId':'wsu','campus':'unknown','campusName':'캠퍼스 미표기','academicYear':2026,'semester':'2','sourceUrl':'https://it.wsu.ac.kr/board/read.jsp?code=it0301&id=268263','publishedDate':'2026-07-21','sourceSha256':hashlib.sha256((P/'wsu-software.pdf').read_bytes()).hexdigest(),'sourceRowCount':len(courses),'courses':courses,'heldRows':held,'periodEvidence':{'start':'2026-09-01','end':'2026-12-14','sourceUrl':'https://www.wsu.ac.kr/page/haksa_list.jsp','scope':'학부2학기개강~종강; 보강15~18제외'}}
(P/'wsu-unknown-2026-2.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
