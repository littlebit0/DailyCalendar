import json
from pathlib import Path
P=Path(__file__).parent;F=P/'program-groups-a.json';d=json.loads(F.read_text())
notes={
'bnue':('심화과정','공식 교육과정13개 심화전공; 현재 조직 원명에 공식 심화과정 parent. 학년/반은 원자료 기존 대응 유지.'),
'cbnu':('연계전공,융합전공,학생설계전공','2026-2027 요람 학칙 학사학위 별표7의 대학/학부및전공 열 전체에서 특별전공 목록 확보. 국제학부는 일반 단과대와 별개 직접 학부. 대학원 교육목록은 제외.'),
'cje':('심화과정','2026 대학생되기 교육기구12개 학과 및 심화과정 직접 확인. 학과를 가짜 단과대로 변환하지 않음.'),
'dgist':('트랙,부전공','2026 현행학칙 및 공식2025이후 기계트랙 전공27/부전공18 이수체계. 최신2026-07-28 교육과정 ZIP 링크 확인, 원본 다운로드 경로 추가 확보 중; 예전8개로 최신목록 추정하지 않음.'),
'dnue':('심화과정','공식 대학 사이트맵13개 심화과정; 현재 원명 대응 직접 심화과정으로 구분.'),
'eulji':('창의융복합교육과정','공식6개 살아있는 과정과 참여학과 원문 확보;2023폐지실버케어 제외. 인공지능기반빅데이터의 운영예정 표시는 원문 그대로 보존하며 개설 강의는 별도 실제원자료로 판단.'),
'ginue':('심화과정','공식 심화과정변경 페이지에서 학과변경 정의/학과 전체목록 확인. 학년반→학과는 기존 source mapping.'),
'gist':('부전공','공식 분야별 이수요건14개 exact약칭 + AI융합부전공 공식실명 별도 확보. 일반전공처럼 이름 늘리지 않음. 인문사회 연계분야는 표안 정의 유지, 독립 fakemajor 미생성.'),
'gjue':('심화과정','공식 학과변경 페이지 심화과정 및 전체12학과. 직접학과/심화과정 모델.'),
'gnue':('학과,심화과정','기존 확보된 실제 공식메뉴12직속학과 근거 재사용. 현재 일반요청 WAF본문은 새근거로 채택안함.'),
'hansei':('융복합전공,마이크로디그리','신규 CMS 경로로2026편람308쪽 및2026MD5쪽 확보. 공식 융합학부 부모+4융복합전공(앤드기호 원명 별도)+5MD과정. MD교과목 코드와개설학과/이수구분 직접기록, 제목추측연결없음.'),
'hknu':('복수전공,부전공,연계전공,융합전공,융합부전공,학생설계전공,소단위전공과정','2026October 유연학사안내+첨부7AI융합과정/60MD/연계정의 확인. 연계는 다른정규전공9학점이수 경로라 추천28개를 독립전공으로 조작안함. 노동복지는2026공식표에2부모가 실제있어확정보류.'),
'gknu':('융합전공','공식 일반과정13개 + 대구경북혁신대학2개 목록. 참여/주관학과를 프로그램 단과대로 자동추정안함.'),
'hanbat':('융합전공,특화융합전공,연계전공,산학연계전공','공식27개 다중전공 전체표의 분류·전공명·단과대·주관학과 확보. 회계학과는2024통계 exact경상대학 부모로 유지, 최신학과명으로 치환안함.')}
extra={'dgist':['https://www.dgist.ac.kr/bbs/BBSMSTR_000000000463.do','https://www.dgist.ac.kr/college/sub03_04_03.do','https://law.dgist.ac.kr/jsp/lkms3/jsp/_regulation/regulationView2.jsp?Obookid=10000600'],'hknu':['https://hrd.hknu.ac.kr/bbs/kor/70/115736/download.do'],'hansei':['https://www.hansei.ac.kr/view.do?no=10226&pgMode=show&pstSn=30623'],'eulji':['https://www.eulji.ac.kr/?menuno=3131']}
for r in d['coverage']:
 u=r['university'];r.update(researchComplete=u!='dgist',ordinaryAffiliationScopeClosed=True,namedProgramScopeClosed=u!='dgist',officialSystems=notes[u][0].split(','),note=notes[u][1],checkedSources=list(dict.fromkeys([e['sourceUrl'] for e in d['entries'] if e['university']==u]+extra.get(u,[]))))
d['final']=False;d['remainingResearch']=[{'university':'dgist','item':'2026-07-28 최신교육과정표 ZIP 원본과 전체 트랙명','checkedSources':extra['dgist'],'reason':'공식 웹읽기로 실제 최신원본 게시물 확인; 일반HTTP연결 reset으로첨부URL원본 추가조사중','researchComplete':False}]
F.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');(P/'program-groups-a-scope-ledger.json').write_text(json.dumps(d['coverage'],ensure_ascii=False,indent=2)+'\n')
