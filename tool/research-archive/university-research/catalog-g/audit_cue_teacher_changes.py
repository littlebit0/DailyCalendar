"""Research-only overlay from visually verified public August31 PDF table."""
from pathlib import Path
import json,re,unicodedata
P=Path(__file__).parent
records=[]
def add(grade,title,teacher,pairs):
 for section,weekday,periods in pairs:records.append(dict(grade=grade,title=title,teacher=teacher,section=section,weekday=weekday,periods=periods))
add(1,'한국사','김상현',[('A','화',[1,2]),('B','화',[1,2])])
add(1,'세계지리','조헌',[('A','화',[3,4]),('B','화',[3,4])])
add(1,'초등음악교육론','추상희',[('E','목',[5,6]),('F','목',[7,8])])
add(1,'회화표현','최경화',[('B','월',[3,4]),('C','월',[5,6])])
add(1,'Journey to English Excellence(JEE)','김재준',[('A','화',[3,4]),('D','수',[5,6]),('E','목',[1,2]),('F','목',[5,6])])
add(1,'컴퓨터의이해와활용','김준호',[('L','목',[7,8])])
add(2,'음악교육실기Ⅱ','김순진',[('F','금',[5])])
add(2,'국악과문화','김순진',[('A','금',[3,4])])
add(2,'교육과정','박창민',[('F','목',[7,8])])
add(2,'에듀테크와영어교육','배한숙',[('A','금',[3,4])])
add(3,'초등국어교육Ⅱ','김서율',[('E','금',[7,8]),('F','금',[7,8])])
add(3,'초등국어교육Ⅰ','김은선',[('D','목',[5,6]),('E','목',[7,8])])
add(3,'초등국어교육Ⅰ','박혜은',[('F','화',[7,8])])
add(3,'초등사회과교육론','박새롬',[('E','화',[2,3,4]),('F','화',[6,7,8])])
add(3,'초등체육교육론','박세원',[('F','목',[7,8])])
add(3,'한국미술비평','허나영',[('A','월',[7,8])])
add(3,'영어어휘이해와지도','김재준',[('A','월',[5,6])])
add(3,'디지털교육','정상목',[('E','목',[5]),('F','목',[6]),('G','목',[7]),('H','목',[8])])
add(3,'디지털교육','노상민',[('I','화',[7]),('J','화',[8])])
add(3,'디지털교육','여호주',[('K','금',[7]),('L','금',[8])])
add(4,'사회과교육연구방법론','이윤정',[('E','목',[5,6]),('F','목',[7,8])])
add(4,'초등체육','박세원',[('E','목',[3,4]),('F','목',[5,6])])
add(4,'색채학','최경화',[('A','월',[7,8])])
add(4,'생활지도및상담','김지민',[('B','화',[1,2])])
add(4,'생활지도및상담','최민성',[('F','목',[7,8])])
add(4,'영어과교육방법론','배한숙',[('A','월',[3,4]),('B','화',[3,4]),('C','화',[7,8])])
add(4,'멀티미디어영어교육','배한숙',[('A','월',[6,7])])
rows=json.loads((P/'cue2026-2-final-sections.json').read_text())
def norm(s):return re.sub(r'\s+','',unicodedata.normalize('NFKC',s))
matched=[];issues=[]
for change in records:
 candidates=[r for r in rows if r['학년']==str(change['grade'])+'학년' and norm(r['과목명'])==norm(change['title']) and r['분반']==change['section']]
 if len(candidates)!=1:issues.append(dict(change=change,candidateCount=len(candidates)));continue
 r=candidates[0];m=re.fullmatch(r'([월화수목금]) \((\d+)~(\d+)\)',r['강의시간']);same=m and m[1]==change['weekday'] and list(range(int(m[2]),int(m[3])+1))==change['periods']
 if not same:issues.append(dict(change=change,raw=r,problem='period mismatch'));continue
 matched.append(dict(change=change,sourceIdentity={'code':r['교과목 코드'],'section':r['분반'],'grade':r['학년']},oldTeacher=r['교수명']))
output={'researchOnly':True,'source':'https://www.cue.ac.kr/kor/ajx_json/UploadMgr/downloadRun.do?qcode=Qm9hcmQsNDA5NzUsWQ==','visualEvidence':'cue2026-2-change0831-visual.png','explicitSectionChanges':len(records),'matched':matched,'issues':issues}
(P/'cue2026-2-teacher-overlay-audit.json').write_text(json.dumps(output,ensure_ascii=False,indent=2));print('explicit',len(records),'matched',len(matched),'issues',len(issues));print(issues)
