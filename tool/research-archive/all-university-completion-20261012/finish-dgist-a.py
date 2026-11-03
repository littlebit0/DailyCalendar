import json
from pathlib import Path
P=Path(__file__).parent;F=P/'program-groups-a.json';d=json.loads(F.read_text());E=d['entries'];E[:]=[e for e in E if e['university']!='dgist']
url='https://www.dgist.ac.kr/synapsoft/FileViewer.do?atchFileId=FILE_000000167385Jr7&fileSn=0'
for name in ['물리학','화학','생명과학','뇌과학','기계공학','재료공학','전자공학','컴퓨터공학','화학공학','자율']:
 E.append(dict(university='dgist',campus='*',sourceLabel=name,department=name,college='융복합대학',group='기초학부',kind='officialProgramSystem',officialGroups=['트랙'],sourceUrl=url,sourceFile=str(P/'a-sources/dgist-2026-preview-page2.png'),evidence='공식2026-07-07 융복합대학 기초학부 교육과정표 실제23페이지 중2쪽의 트랙목록 직접 명시: 물리학,화학,생명과학,뇌과학,기계공학,재료공학,전자공학,컴퓨터공학,화학공학,자율. 전공27학점/부전공18학점, 복수전공허용.1쪽제목 실제부모 융복합대학 기초학부 직접. 교수분야/예전8개를 최신목록으로 추측하지않음.',sourcePage=2,sourceAcademicYear=2026,documentVersion='2026-07-07',publishedDate='2026-07-28',additionalEvidenceFiles=[str(P/'a-sources/dgist-2026-preview-page1.png'),str(P/'a-sources/dgist-2026-preview-index.xml'),str(P/'a-sources/dgist-preview-pages-receipts.json'),str(P/'a-sources/dgist-2026-preview-ocr.json')]))
for r in d['coverage']:
 if r['university']=='dgist':r.update(researchComplete=True,namedProgramScopeClosed=True,entries=10,note='2026-07-28게시 최신2026-07-07교육과정표 공식미리보기23페이지 확보/OCR+1~2쪽 실제육안확인. 정확10트랙목록(자율포함)과 공식부모 융복합대학 기초학부 확정. 원FileDown오류본문을PDF로채택않고공식미리보기실문서근거사용.',checkedSources=r['checkedSources']+[url])
d['remainingResearch']=[];d['final']=True;d['scopeConclusion']='담당14대학 공식 부모/전공제도 조사 닫음. 한경노동복지는 두 공식부모중선택 근거없어 명시미확정1건(추정없음). 제품미적용·전체검증미실시.'
F.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');(P/'program-groups-a-scope-ledger.json').write_text(json.dumps(d['coverage'],ensure_ascii=False,indent=2)+'\n')
bad=P/'a-sources/dgist-2026-curriculum.pdf'
if bad.exists() and not bad.read_bytes().startswith(b'%PDF'):bad.rename(P/'a-sources/dgist-2026-curriculum-download-error.html')
print('final',d['final'],'entries',len(E),'unresolved',[(x['university'],x['department']) for x in d['unresolved']])
