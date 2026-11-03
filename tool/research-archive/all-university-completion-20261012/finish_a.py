import json,re
from pathlib import Path
from lxml import html
P=Path(__file__).parent;F=P/'program-groups-a.json';a=json.loads(F.read_text());entries=a['entries'];unresolved=a['unresolved']
def add(u,dept,group,url,file,evidence,college=None,kind='universityDirect',campus='*',**extra):
 entries.append(dict(university=u,campus=campus,sourceLabel=dept,department=dept,college=college,group=group,kind=kind,sourceUrl=url,sourceFile=str(file),evidence=evidence,**extra))
# Fresh direct official identity of international faculty, backed by current university rules with distinct academic unit column.
add('cbnu','국제학부','국제학부','https://www.cbnu.ac.kr/www/contents.do?key=1329',P/'a-sources/cbnu-international.html','공식 대학소개에 국제학부와 별도 행정실 직접 명시. 2026-2027 요람의 현재 학칙 별표7(75~76쪽) 대학 열에서 일반 단과대와 별개로 국제학부를 직접 명시. 단과대 발명 안 함')
for pg in json.loads((P/'a-sources/cbnu-law.pdf.tables.json').read_text()):
 for ti,t in enumerate(pg['tables']):
  for ri,r in enumerate(t):
   if len(r)!=3 or r[1] not in ['연계전공','융합전공','학생설계전공']:continue
   for dept in r[2].replace('\n','').split(','):
    dept=dept.strip()
    add('cbnu',dept,r[1],'https://graduate.cbnu.ac.kr/upload_file/bbs/00000004/2026/1777523280-1300-0.pdf',P/'a-sources/cbnu-law.pdf.html',f'2026-2027요람 현재 학칙 별표7 {pg["page"]}쪽 표{ti}행{ri}: 대학={r[1]}, 학부/전공={r[2]}, 학사학위={r[0]}. 대학원 교과를 학부로 추정한 것이 아니라 학칙 학사학위 표 직접 항목',kind='officialProgramSystem',officialGroups=[r[1]])
# Explicit 2026 college/academic-faculty sources, preserve legacy uncertainty separately.
for dept,college,key,evid in [('우주국방첨단융합학과','공과대학','hanbat-colleges','공식 대학소개 공과대학 아래 우주국방첨단융합학과 링크 직접 존재'),('정보기술AI융합학부','융합자율대학','hanbat-infotech','공식 학부소개 본문 “융합자율대학 정보기술AI융합학부” 직접 명시'),('한국어문화전공','노마드 칼리지','hanbat-korean-parent','2026 공식 교수 초빙 교육조직 표 “노마드칼리지 국제학부 / 한국어문화전공” 직접 명시')]:
 urls={'hanbat-colleges':'https://www.hanbat.ac.kr/kor/sub03_01.do','hanbat-infotech':'https://www.hanbat.ac.kr/infotech/sub01_01.do','hanbat-korean-parent':'https://fund.hanbat.ac.kr/prog/bbsArticle/BBSMSTR_000000000050/view.do?mno=sub07_01&nttId=B000000167249Cd1wW9v'}
 add('hanbat',dept,None,urls[key],P/'a-sources'/(key+'.html'),evid,college=college,kind='ordinaryCollege')
# Current exact official faculty/major row. No conversion of unrelated earlier major aliases.
for dept,parent,key,evid in [('글로벌경영전공','글로벌창의인재학부','hknu-global','공식 학부소개 전공소개에 글로벌경영전공 직접 포함'),('글로벌창의인재학부','글로벌창의인재학부','hknu-global','대학(안성캠퍼스) 공식 직접 학부 페이지'),('컴퓨터공학전공','컴퓨터응용수학부','hknu-selection','공식 전공자율선택제 캠퍼스별 학부/전공 표: 안성 / 컴퓨터응용수학부 / 컴퓨터공학전공'),('특수체육학전공','사회통합학부','hknu-selection','공식 전공자율선택제 캠퍼스별 학부/전공 표: 평택 / 사회통합학부 / 특수체육학전공'),('스마트에그리푸드시스템전공','AI융합학부','hknu-ai','공식 AI융합학부 페이지 전공소개 제목에 스마트에그리푸드시스템전공 정확 표기; 별도의 애그리 표기를 자동별칭으로 생성하지 않음')]:
 url={'hknu-global':'https://global.hknu.ac.kr/kor/4508/subview.do','hknu-selection':'https://bi.hknu.ac.kr/kor/7010/subview.do','hknu-ai':'https://bi.hknu.ac.kr/kor/4499/subview.do'}[key];file=P/('root-sources' if key=='hknu-ai' else 'a-sources')/(key+'.html')
 add('hknu',dept,parent,url,file,evid)
# PDF current2026 exact affiliation, explicit same-label university-direct department is not synthetic college.
for dept,parent,pg,ev in [('시각미디어디자인전공','디자인예술스포츠학부',1,'2026학년도 신입생 졸업요구 학점표 첫 페이지의 학부명/세부전공 열 직접 관계'),('레저스포츠매니지먼트전공','미래융합학부',2,'2026학년도 신입생 졸업요구 학점표2쪽 미래융합학부 아래 세부전공 레저스포츠매니지먼트전공 직접 관계'),('반도체공학과','반도체공학과',2,'2026학년도 신입생 졸업요구 학점표2쪽 학부명 반도체공학과가 독립행으로 명시; 전공열 -')]:
 add('hknu',dept,parent,'https://www.hknu.ac.kr/sites/kor/files/2026-Year-Admission.pdf',P/'a-sources/hknu-2026-parent.pdf.html',ev,sourcePage=pg)
# Parent-only campus autonomy bound is explicit in university program selection page.
add('hknu','HK자율전공학부(평택)','HK자율전공학부','https://bi.hknu.ac.kr/kor/7010/subview.do',P/'a-sources/hknu-selection.html','공식 본문 “평택캠퍼스 HK자율전공학부는 평택캠퍼스 내 전공 중 선택 가능” 직접 명시; 일반 단과대 아님',campus='pyeongtaek')
resolved={(e['university'],e['department']) for e in entries}
unresolved=[u for u in unresolved if (u['university'],u['department']) not in resolved]
for u in unresolved:
 if u['university']=='hknu' and u['department']=='노동복지전공':u.update(checkedSources=['https://www.hknu.ac.kr/sites/kor/files/2026-Year-Admission.pdf','https://hknu.ac.kr/bbs/hkict/278/102141/download.do','https://bi.hknu.ac.kr/kor/7010/subview.do'],reason='2026학년도 신입생 졸업요구 학점표2쪽에 동일 노동복지전공이 미래융합학부와 인문융합공공인재학부 양쪽에 공식 명시됨. 기존 시간표 원행에 소속 또는 대상학번이 없어 하나의 부모로 확정 불가. 두 부모 근거는 확인됐으나 사용자/원자료 대상 확인 필요.',researchComplete=True,confirmedParentCandidates=['미래융합학부','인문융합공공인재학부'])
 elif u['university']=='hanbat':u.update(checkedSources=['https://www.hanbat.ac.kr/kor/sub03_01.do','https://fund.hanbat.ac.kr/kor/sub05_030104.do','https://www.hanbat.ac.kr/electro/sitemap.do'],reason='회계학과는 기존원문 exact label, 현재 공식 조직은 회계세무학과/회계세무부동산학과. 해당 원자료의 학과명을 current name으로 치환할 공식 교차표 미확인.',researchComplete=False)
 elif u['university']=='hansei':u.update(checkedSources=['https://www.hansei.ac.kr/kor/2085/subview.do','https://graduate.hansei.ac.kr/kor/2085/subview.do','https://www.hansei.ac.kr/bbs/kor/57/22657/download.do','https://ipsi.hansei.ac.kr/kor/532/subview.do'],reason='2025 공식 뉴스에서 융합학부장을 명시하나 새 2026 교육과정편람/전공제도 페이지 직접 접근은 모두404 일반오류 본문. 실제 2026 융합학부 교육과정/구성 아직 확보 못함; 확인 없는 부모·전공 코드 연결 없음.',researchComplete=False)
a.update(entries=entries,unresolved=unresolved,final=False)
for row in a['coverage']:
 row.update(entries=len([e for e in entries if e['university']==row['university']]),unresolved=len([e for e in unresolved if e['university']==row['university']]))
F.write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print('entries',len(entries),'unresolved',[(u['university'],u['department']) for u in unresolved])
