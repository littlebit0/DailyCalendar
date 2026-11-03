import json
from pathlib import Path
p=Path(__file__).parent;src=p/'root-followup-a-sources';f=p/'program-groups-root-followup-a.json';j=json.loads(f.read_text());u='https://www.gachon.ac.kr/bbs/kwcivil/981/118365/download.do'
ev={'url':u,'title':'2024년 조교설명회 재학생 만족도조사','webReference':'turn2723view0','relevantPagesOnly':[2,3],'exactCrosswalkQuotes':['IT융합대학 의공학과(의용생체공학과 포함)','IT융합대학 바이오의료기기학과(첨단의료기기학과포함)','반도체대학 반도체·전자공학부(반도체공학전공) (시스템반도체전공, 차세대반도체전공포함)','반도체대학 반도체·디스플레이학과(반도체공학부(반도체·디스플레이전공),디스플레이학과포함)','반도체대학 반도체설계학과(반도체공학부(반도체설계전공)포함)'],'scope':'Official 2024 legacy inclusion crosswalk, corroborated by 2026 exact successor college roster. Not a statement that all historical college parents equal 2026 parents; original name retained.'}
(sf:=src/'gachon-official-legacy-inclusion-crosswalk-evidence.json').write_text(json.dumps(ev,ensure_ascii=False,indent=2))
rs={'의용생체공학과':'IT융합대학','첨단의료기기학과':'IT융합대학','디스플레이학과':'반도체대학','반도체공학부(반도체디스플레이전공)':'반도체대학','반도체공학부(반도체설계전공)':'반도체대학','전자공학부(차세대반도체전공)':'반도체대학'}
a=json.loads(Path('assets/timetable/organizations/gachon.json').read_text())
for m in a['mappings']:
 d=m.get('department')
 if m.get('college')is None and d in rs:
  j['entries'].append(dict(university='gachon',department=d,college=rs[d],campus='global',sourceLabel=m['sourceLabel'],sourceUrl=u,sourceFile=str(sf.resolve()),evidence='공식 2024 단과대학별 재학생 표에서 현재 학과 및 이전 학과/전공 포함 관계를 명시; 2026 편입생 학과 사무실 표·현행 단과대 roster의 동일 후속학과 부모로 추가 확인. 원래 명칭을 바꾸지 않으며 공식 글로벌캠퍼스 소속에만 적용.',kind='college',checkedSources=[u,'https://www.gachon.ac.kr/bbs/kor/475/141901/download.do']))
for m in a['mappings']:
 if m.get('college')is None and m.get('department')=='약학과(2+4학제)':
  sf=src/'gachon-medical-native-depts-Y53000.json';j['entries'].append(dict(university='gachon',department=m['department'],college='약학대학',campus='medical',sourceLabel=m['sourceLabel'],sourceUrl='https://info.gachon.ac.kr/ssu/showTimetable.do',sourceFile=str(sf.resolve()),evidence='공개 대학콤보 약학대학(M) Y53000, Medical groupType21 실제 선택 응답: 약학과(2+4학제)(M), DPT_CD Y53110, UNIV_CD Y53000. M은 공식 메디컬 표기이며 2+4학제 원명 보존.',kind='college'))
# Campus guard all native global evidence rather than broad wildcard. Catalog currently maps these original sourceLabel only globally.
for e in j['entries']:
 if e['university']=='gachon' and e['sourceFile'].split('/')[-1].startswith('gachon-native-depts-'):e['campus']='global'
resolved={(e['university'],e['department'])for e in j['entries']};j['unresolved']=[r for r in j['unresolved']if(r['university'],r['department'])not in resolved];f.write_text(json.dumps(j,ensure_ascii=False,indent=2));print('candidateRows',len(j['entries']),'remaining',j['unresolved'])
