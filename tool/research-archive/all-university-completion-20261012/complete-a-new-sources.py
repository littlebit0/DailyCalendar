import json,re
from pathlib import Path
P=Path(__file__).parent;F=P/'program-groups-a.json';d=json.loads(F.read_text());E=d['entries']
def add(u,n,g,url,file,evidence,kind='officialProgramSystem',groups=None,**extra):
 if any(x['university']==u and x.get('sourceLabel')==n and x.get('sourceUrl')==url for x in E):return
 E.append(dict(university=u,campus='*',sourceLabel=n,department=n,college=None,group=g,kind=kind,officialGroups=groups or [],sourceUrl=url,sourceFile=str(file),evidence=evidence,**extra))
# Preserve exact legacy source name with official source-time college evidence.
if not any(x['university']=='hanbat' and x['department']=='회계학과' for x in E):
 E.append(dict(university='hanbat',campus='*',sourceLabel='회계학과',department='회계학과',college='경상대학',group=None,kind='ordinaryCollege',sourceUrl='https://www.hanbat.ac.kr/thumbnail/dataDetail/STAT_202502171054223730.pdf',sourceFile=str(P/'a-sources/hanbat-2024-stat.pdf.html.evidence.json'),evidence='2024 통계연보28쪽 경상대학: 경제학과,융합경영학과,회계학과 직접 표기. exact회계학과 원명을 유지하며 최신학과명으로 치환 안함.',sourcePage=28,sourceAcademicYear=2024))
d['unresolved']=[x for x in d['unresolved'] if x['university']!='hanbat']
add('hansei','융합학부','융합학부','https://www.hansei.ac.kr/index.do',P/'a-sources/hansei-faculty-menu-evidence.json','현재 공식 메뉴 트리 대학·대학원→학부및학과→융합학부→융복합전공/스포츠헬스케어/청소년/글로벌외국어통상무역/멀티미디어사운드뮤직 직접. 2026교육과정편람 실제 개설학과(부) 열 융합학부 직접 표기(260~261,291~292 PDF쪽). 단과대 발명 없이 공식 학부로 유지.',kind='universityDirect')
for n in ['스포츠헬스케어전공','청소년전공','글로벌외국어통상무역전공','멀티미디어사운드뮤직전공','멀티미디어사운드&뮤직전공']:
 add('hansei',n,'융합학부','https://www.hansei.ac.kr/view.do?no=12084',P/'a-sources/hansei-multi.html','공식 융복합전공 소개 탭에서 정확 전공명 직접 표기. 스포츠헬스케어/청소년/글로벌외국어통상무역/멀티미디어사운드&뮤직; &없는 원명은 현재 융합학부 메뉴에도 직접 표기. 교수의 원소속을 프로그램 단과대로 추정하지 않음.',groups=['융복합전공'],additionalEvidenceFiles=[str(P/'a-sources/hansei-2026-full.pdf'),str(P/'a-sources/hansei-faculty-menu-evidence.json')])
N=['블록체인 보안 과정','디지털범죄과학(Major in Digital Crime Science)전공 과정','디지털마케팅 전문가 과정','창의융합예술교육 전문가 과정','HSK 전문가 과정'];url='https://www.hansei.ac.kr/view.do?no=12443'
T=json.loads((P/'a-sources/hansei-micro.pdf.tables.json').read_text())
C=[['15904','15901',None,'15446'],['15434','15895','15896','14979','12963'],['14433','10562','14447','13191'],['15271','12151','14402','15794','14519',None],['13772','15923','15927','15926']]
for i,n in enumerate(N):
 rows=next(t for t in T[i]['tables'] if t and t[0][0]=='교과목번호');members=[]
 for j,r in enumerate(rows[1:]):members.append({'courseCode':C[i][j],'title':r[1],'sourceOwner':r[3],'sourceCategory':r[4],'credits':r[2],'note':'코드가 없는 신규교과/선택묶음은 추측하지 않음' if C[i][j] is None else 'PDF 본문 교과목번호 직접 확인'})
 if i==3:members[-1].update(courseCodes=['12610','12611','12905','15175','15858','15859','15176'],note='선택택1묶음의 원문코드7개. 각 코드별 개별제목대응은 추정안함')
 add('hansei',n,'마이크로디그리',url,P/'a-sources/hansei-micro.pdf.html',f'새 공식 마이크로디그리 메뉴 첨부 2026학년도 안내 PDF {i+1}쪽 ({i+1}) {n} 실제명; 참여과목 코드·개설학과·이수구분 원문 직접 기록. 개설학과가 여러 개라고 프로그램 부모를 임의설정하지 않음.',groups=['마이크로디그리'],sourcePage=i+1,courseMembership=members,sourceAcademicYear=2026)
d['unresolved']=[x for x in d['unresolved'] if x['university']!='hansei']
add('gist','AI융합부전공','부전공','https://college.gist.ac.kr/ai/sub03_06_03.do',P/'a-sources/gist-ai-system.html','공식 학부 부전공 과정 커리큘럼 표 과목구분 AI융합부전공 직접 명시; 기존 부전공페이지 AI융합 약칭과 원문명 각각 유지',groups=['부전공'])
add('dgist','기계공학 트랙','트랙','https://mech.dgist.ac.kr/sub2_1_c.php',P/'a-sources/dgist-track.html','공식 기계트랙 사이트 기계공학트랙 명시; 2025학번 이후 심화 전공 트랙27학점/부전공18학점 교과과정 직접 명시. 전체 트랙수는 새2026공식목록 확보후 확정',groups=['트랙'],sourceAcademicParent='융복합대학 기초학부',additionalEvidenceFiles=[str(P/'a-sources/dgist-mechanical-main.html')],additionalSourceUrls=['https://mech.dgist.ac.kr/'])
# Source metadata record is a system definition, not a synthetic organization. HKNU linkedmajor is another ordinarymajor chosen bystudent.
d['officialSystemDefinitions']=[{'university':'hknu','system':'연계전공','sourceUrl':'https://hrd.hknu.ac.kr/bbs/kor/70/99049/artclView.do','sourceFile':str(P/'root-sources/hknu-linked-3-1.pdf'),'evidence':'실제 이미지 PDF 확인: 원전공 이외에 다른 전공에서 정한 교과목을 이수하는 전공제도. 2020이후 원소속전공78(인문사회72)+다른학과전공9학점이상. 28개전공 추천과목맵은 정규전공의 다른 이수경로이며 새로운 이름 붙은 독립전공 목록이 아님. 대학/학부 원소속 유지','namedProgramsFile':str(P/'root-sources/hknu-linked-3-2.txt')}]
for r in d['coverage']:r.update(entries=sum(x['university']==r['university'] for x in E),unresolved=sum(x['university']==r['university'] for x in d['unresolved']))
F.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print('entries',len(E),'unresolved',[(x['university'],x['department']) for x in d['unresolved']])
