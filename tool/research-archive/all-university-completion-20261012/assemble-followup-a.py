import json
from pathlib import Path
base=Path(__file__).parent;src=base/'root-followup-a-sources'
def load(s):return json.loads((Path('assets/timetable/organizations')/(s+'.json')).read_text())
entries=[]; resolved={}
u='https://www.gachon.ac.kr/bbs/cs/929/137326/download.do';f=str((src/'gachon-2026-transfer-web-evidence.json').resolve())
data={
'법과대학':['경찰행정학과','행정학과'],
'공과대학':['도시계획·조경학부','건축학부','화공생명배터리공학부','화공생명공학전공','배터리공학전공','기계공학부','기계공학전공','산업공학전공','설비·소방공학전공','설비·소방공학과','기계·스마트·산업공학부(기계공학전공)','기계·스마트·산업공학부(산업공학전공)','기계·스마트·산업공학부(스마트팩토리전공)','화공생명공학부(화공생명공학전공)','화공생명공학부(배터리공학전공)'],
'IT융합대학':['AI·소프트웨어학부(인공지능전공)','컴퓨터공학부(컴퓨터공학전공)','컴퓨터공학부(스마트보안전공)','스마트시티융합학과'],
'반도체대학':['반도체·전자공학부','전자공학부(전자공학전공)','전자공학부(시스템반도체전공)','전자공학전공']}
for c,ds in data.items():
 for d in ds:resolved[d]=(c,u,f,'2026-1학기 전과여석 표의 대학/학과 및 재학생 학부명 교차표. 현행 부모 확인이며 원래 개설조직명 보존; 일반명 유사성 치환 아님.')
u2='https://www.gachon.ac.kr/bbs/kor/475/141901/download.do';f2=str((src/'gachon-2026-orientation-web-evidence.json').resolve())
for c,ds in {'공과대학':['건축공학과','스마트팩토리학과','미래자동차학과'],'국제대학':['한국학전공','한국어교육학과']}.items():
 for d in ds:resolved[d]=(c,u2,f2,'2026학년도 편입생 오리엔테이션 PDF93~94의 대학/학과 사무실 표에서 정확한 학과명과 부모를 확인. 건물 소재를 부모로 해석하지 않음.')
# Actual 2026 모집단위 officialtable separately corroborates 건설환경 exactname (orientation has typo 건축환경).
d='건설환경공학과';resolved[d]=('공과대학','https://www.gachon.ac.kr/kor/1103/subview..do',str((src/'gachon-2026-p-semester-web-evidence.json').resolve()),'공식 2026년 P학기제 참여 학과 표: 공과대학 행에 건설환경공학과 정확 명칭이 명시.')
for m in load('gachon')['mappings']:
 d=m.get('department')
 if m.get('college') is None and d in resolved:
  c,u,f,e=resolved[d];entries.append(dict(university='gachon',department=d,college=c,campus=m.get('campus','*'),sourceLabel=m['sourceLabel'],sourceUrl=u,sourceFile=f,evidence=e,kind='college'))
packet={'final':False,'wholeCompletion':False,'assignedUniversities':['gachon','cau','chosun','daegu','dku','donga','gnu','hansung'],'entries':entries,'unresolved':[], 'notes':['2026 official Gachon source crosswalk used; 2013 tables not treated as current parent evidence. No product assets edited. Other assigned-school audit still in progress.']}
for s in packet['assignedUniversities']:
 done=set(resolved) if s=='gachon' else set()
 for d in sorted({m.get('department') for m in load(s)['mappings'] if m.get('college') is None}-done):packet['unresolved'].append({'university':s,'department':d,'researchComplete':False,'reason':'Continuing current affiliation and official program-system source audit; not an exhausted-source conclusion.'})
(base/'program-groups-root-followup-a.json').write_text(json.dumps(packet,ensure_ascii=False,indent=2))
(src/'gachon-2026-p-semester-web-evidence.json').write_text(json.dumps({'url':'https://www.gachon.ac.kr/kor/1103/subview..do','title':'P-학기제 2026년 53개 학과 참여','webReference':'turn2698view2','exactQuote':'공과대학 | 도시계획·조경학부(도시계획학, 조경학), 건축학부(건축학, 실내건축학), 건축공학과, 화공생명배터리공학부(화공생명공학, 배터리공학), 기계공학부(기계공학, 산업공학, 설비·소방공학), 스마트팩토리학과, 건설환경공학과, 신소재공학과'},ensure_ascii=False,indent=2))
print('candidate rows',len(entries),'unique',len({e['department'] for e in entries}))
