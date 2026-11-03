import json
from pathlib import Path
base=Path(__file__).parent;src=base/'root-followup-a-sources';out=base/'program-groups-root-followup-a.json';j=json.loads(out.read_text())
def append(s,defs,url,file,evidence):
 a=json.loads((Path('assets/timetable/organizations')/(s+'.json')).read_text())
 for m in a['mappings']:
  d=m.get('department')
  if m.get('college') is None and d in defs:
   j['entries'].append(dict(university=s,department=d,college=defs[d],campus=m.get('campus','*'),sourceLabel=m['sourceLabel'],sourceUrl=url,sourceFile=str(file.resolve()),evidence=evidence,kind='college'))
append('gachon',{'AI·소프트웨어학부':'IT융합대학','AI·소프트웨어학부(소프트웨어전공)':'IT융합대학','회화·조소전공':'예술·체육대학'},'https://www.gachon.ac.kr/bbs/kor/475/141901/download.do',src/'gachon-2026-orientation-program-web-evidence.json','2026 편입생 안내 PDF53·55: IT융합대학 AI·소프트웨어학부 소프트웨어/인공지능, 예술·체육대학 미술·디자인학부 회화·조소. 원명 보존.')
(src/'gachon-2026-orientation-program-web-evidence.json').write_text(json.dumps({'url':'https://www.gachon.ac.kr/bbs/kor/475/141901/download.do','webReference':'turn2703view0','pdfPages':[53,55],'quotes':['IT융합대학 AI·소프트웨어학부 소프트웨어 60 35 37 72 120 / 인공지능 60 35 37 72 120','예술·체육대학 미술・디자인학부 회화・조소 60 24 36 60 120']},ensure_ascii=False,indent=2))
defs={}
for c,ds in {'인문대학':['영어영문학부','역사문화학부'],'사회과학대학':['경영학부','무역학과','부동산학과','경제학과','행정학과','부동산세무경영학과'],'예술대학':['무용학과','패션학부','융복합디자인학부','인테리어디자인학과'],'공과대학':['전자정보공학과','IT응용시스템공학과','산업경영공학과','기계시스템공학과'],'미래플러스대학':['융합행정학과','호텔외식경영학과','비즈니스컨설팅학과','ICT융합디자인학과','AI·소프트웨어학과','뷰티매니지먼트학과','스마트제조혁신컨설팅학과','디지털콘텐츠디자인학과'],'글로벌인재대학':['영상엔터테인먼트학과'],'디자인대학':['뷰티디자인매니지먼트학과']}.items():
 for d in ds:defs[d]=c
append('hansung',defs,'https://rule.hansung.ac.kr/lmxsrv/law/lawFullContent.do?SEQ=104&SEQ_HISTORY=1640',src/'hansung-current-academic-rule.html','현행 학사운영규정 별표 대학·학부(과) 구분번호 표15(학과제 원모집단위),16(현행 트랙제 및 별도 학과) 정확 소속. 예전 학과명을 후속 학부로 임의 바꾸지 않고 학칙 경과조치로 유지한 원모집단위 부모 사용. 계약학과 표의 미래플러스대학 동일 부모.')
append('hansung',{'국어국문전공':'인문대학','문헌정보전공':'인문대학'},'https://rule.hansung.ac.kr/lmxsrv/law/lawFullContent.do?LAWGROUP=1&SEQ=20&SEQ_HISTORY=1623&hideBookMark=1',src/'hansung-current-law.html','현행 학칙 2020.5.20 경과조치 별표 표88: 트랙제가 아닌 학부(과)제 졸업생은 종전 학칙; 인문대학 응용인문학부 국어국문/문헌정보 exact 전공명. 현재 원자료의 학과제 원명에만 적용하며 현행 트랙으로 이름 변환하지 않음.')
append('hansung',{x:'크리에이티브인문예술대학' for x in ['동양화전공','서양화전공','한국무용전공','현대무용전공','발레전공']},'https://www.hansung.ac.kr',base/'b-sources/hansung-2026.pdf','공식 2026학년도1학기 트랙선택 안내 단과대학/학부/전공·트랙 표: 크리에이티브인문예술대학 예술학부 동양화·서양화·한국무용·현대무용·발레 exact 전공. 일반 예술학부 소속이며 별도 추가전공으로 분류하지 않음.')
keys={(e['university'],e['department']) for e in j['entries']};j['unresolved']=[r for r in j['unresolved'] if (r['university'],r['department']) not in keys]
for e in j['entries']:
 if e['sourceFile'].endswith('hansung-2026.pdf'):e['sourceUrl']='https://www.hansung.ac.kr/bbs/hansung/2127/30565/download.do'
out.write_text(json.dumps(j,ensure_ascii=False,indent=2));print('entries',len(j['entries']),'unresolved',len(j['unresolved']))
