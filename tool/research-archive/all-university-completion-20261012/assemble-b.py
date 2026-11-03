import sys,json,re
from pathlib import Path
sys.path.insert(0,'/private/tmp/daily-college-source-parser')
from bs4 import BeautifulSoup
O=Path('work/all-university-completion-20261012');P=O/'b-sources';out={};checked={};unclear=[]
a={f.stem:json.load(open(f))for f in Path('assets/timetable/organizations').glob('*.json')if 'ajou'<=f.stem<='pnu'and f.stem!='dju'}
def norm(s):return re.sub(r'[\s·ㆍ‧&/()\[\]‐–,-]','',s).lower()
def source(n,k):
 r=next(x for x in json.load(open(P/'receipts.json'))if x['key']==n and 'sourceFile'in x);f=Path(r['sourceFile']);s=BeautifulSoup(f.with_suffix('.txt').read_text() if f.suffix=='.pdf' else f.read_text(errors='replace'),'html.parser');checked.setdefault(k,[]).append({'url':r['url'],'sourceFile':str(f)});return r,f,s

def decide(k,m,groups,r,f,evidence,college=None,kind='officialProgramSystem'):
 key=(k,m.get('campus','*'),m['sourceLabel']);out[key]={'university':k,'campus':m.get('campus','*'),'sourceLabel':m['sourceLabel'],'department':m['department'],'college':college,'group':groups[0]if groups else None,'officialGroups':groups,'kind':kind,'sourceUrl':r['url'],'sourceFile':str(f),'evidence':evidence}
# Actual exact K-Cloud table cell names; do not use responsible professor's college.
r,f,s=source('kmu-kcloud','kmu');names=[]
for table in s.find_all('table'):
 if '참여학과'in table.get_text()and'책임교수'in table.get_text():
  for row in table.select('tr'):
   cs=[x.get_text(' ',strip=True)for x in row.find_all('td')]
   if cs:
    d=cs[1]if cs[0]=='융합전공'else cs[0];d=re.split(r'\s*＊',d)[0];names.append(d)
for m in a['kmu']['mappings']:
 if m.get('department')in names:decide('kmu',m,['융합전공'],r,f,'K-Cloud College 공식 전공제도 표 구분=융합전공, 전공명='+m['department']+'; 참여학과/책임교수 소속은 프로그램 분류로 변환하지 않음')
# KNU official convergence system and new/old published enrollment notices.
r,f,s=source('knu-system','knu');texts=[s.get_text(' ',strip=True)]
for n in ['knu-2026','knu-2023']:
 rr,ff,ss=source(n,'knu');texts.append(ss.get_text(' ',strip=True))
for m in a['knu']['mappings']:
 d=m.get('department')or''
 if not d:continue
 target=d if d.endswith('융합전공')else d[:-2]+'융합전공'if d in['핀테크전공']else None
 if target and any(norm(target)in norm(t)for t in texts):
  decide('knu',m,['융합전공'],r,f,'공식 학사 전공제도 융합전공 소개 및2023/2026 선발 목록에 '+target+' 명시; 전공 주관대학은 분류에 사용하지 않음')
# KOREA exact first column names of program-system listing.
r,f,s=source('korea-system','korea');names=[]
for table in s.find_all('table'):
 if '전공명'in table.get_text()and'주관대학'in table.get_text():
  for row in table.find_all('tr'):
   cells=row.find_all('td')
   if cells:names.append(cells[0].get_text(' ',strip=True).split('(')[0].strip())
for m in a['korea']['mappings']:
 d=m.get('department')or'';base=re.sub(r'융합전공$','',d).strip()
 if any(norm(base)==norm(n)for n in names):decide('korea',m,['융합전공'],r,f,'공식 교육정보 → 전공 → 제2전공 → 융합전공의 전공명 표: '+base+'; 표 주관대학은 프로그램 분류로 변환하지 않음')
# KHU source has explicit 융합전공 heading and program rows. Native composite prefix preserves system.
r,f,s=source('khu-system','khu');t=s.get_text(' ',strip=True)
for m in a['khu']['mappings']:
 d=m.get('department')or''
 if d.startswith('융합 '):
  title=d.split(' ',2)[1];
  if norm(title)in norm(t):decide('khu',m,['융합전공'],r,f,'공식 졸업학점 교육과정 표 융합전공 영역에 '+title+' 명시; 원자료 융합 구분과 일치')
# Jeju current2026 official list supersedes older raw 연계 labels where same exact title persists.
r,f,s=source('jeju-multi','jeju');t=s.get_text(' ',strip=True)
for m in a['jeju']['mappings']:
 d=m.get('department')or''
 if d.startswith('제주대학교 연계전공 ')or d.startswith('제주대학교 융합전공 '):
  base=d.split(' ',2)[2];base=re.sub('전공$','',base);base={'지식재산융합':'지식재산','종자산업융합':'종자산업','해양기상학융합':'해양기상학','반도체융합':'반도체'}.get(base,base)
  if norm(base)in norm(t):decide('jeju',m,['융합전공'],r,f,'공식 복수전공 제도 융합전공 개설 현황(2026학년도 기준)의 연계·융합전공명: '+base+'; 이전 원자료 명칭 유지')
# Kookmin official navigation separately enumerates every system; multi-category records kept.
r,f,s=source('kookmin-hat','kookmin');index={}
for aTag in s.find_all('a'):
 href=aTag.get('href','');d=aTag.get_text(' ',strip=True)
 if any(href.startswith('/'+p+'/')for p in ['link','fusion','self','ondemand']):
  path=href.split('/')[1];g={'link':'연계전공','fusion':'융합전공','self':'자기설계연계·융합전공','ondemand':'On-Demand연계·융합전공'}[path];index.setdefault(norm(d),set()).add(g)
for m in a['kookmin']['mappings']:
 d=m.get('department')or'';base=d.removeprefix('연계전공 ')
 if norm(base)in index:
  gs=sorted(index[norm(base)]);decide('kookmin',m,gs,r,f,'인문기술융합학부 공식 홈페이지 전공제도별 내비게이션 목록: '+base+' → '+', '.join(gs)+'; 동일 전공 복수 제도 등장 시 모두 기록')
# Current Kyonggi authoritative exact college blocks, no2027future plan use.
r,f,s=source('kyonggi-colleges','kyonggi')
for div in s.select('.agency_link .link_item'):
 anchor=div.select_one('a.link_anchor');c=anchor.get_text(' ',strip=True)if anchor else''
 if not c.endswith('대학'):continue
 for m in a['kyonggi']['mappings']:
  d=m.get('department')or''
  if not d:continue
  for x in div.find_all(['a','span']):
   label=x.get_text(' ',strip=True).strip('[]')
   if norm(d)==norm(label):decide('kyonggi',m,[],r,f,'공식 대학·조직 학부/학과 목록 '+c+' → '+label,c,'ordinaryCollege')
# Additional exact official system lists.
for k,n,g,suffix in [('inu','inu-linked','연계전공','연계전공'),('kyonggi','kyonggi-2026','융합전공',''),('jnu','jnu-linked','연계전공','연계전공')]:
 r,f,ss=source(n,k)
 if f.suffix=='.pdf':
  text=f.with_suffix('.txt').read_text();names=['AI경영융합전공','심리상담융합전공','융합데이터공학전공','창업융합전공'];names=[x for x in names if norm(x)in norm(text)]
 else:
  names=[]
  for table in ss.find_all('table'):
   for row in table.find_all('tr'):
    cells=row.find_all(['td','th'])
    if cells:names.append(cells[0].get_text(' ',strip=True))
 for m in a[k]['mappings']:
  d=m.get('department')or'';base=d[:-len(suffix)]if suffix and d.endswith(suffix)else d
  if any(norm(base)==norm(x)for x in names):decide(k,m,[g],r,f,'공식 전공제도 '+g+' 전공명 표: '+base+'; 주관학과/교수 대학은 그룹 기준으로 사용하지 않음')
r,f,ss=source('jnu-systems','jnu');heads=[x.get_text(' ',strip=True)for x in ss.find_all(['h3','h4','h5','dt'])];text=ss.get_text(' ',strip=True)
# Only the nine titles explicitly inside the system's 융합전공 subsection.
jnu_names=['로봇공학융합전공','미래에너지공학융합전공','빅데이터금융공학융합전공','IoT인공지능융합전공','지능형모빌리티융합전공','지능실감미디어융합전공','데이터사이언스융합전공','지식재산융합전공','국제개발협력학융합전공']
for m in a['jnu']['mappings']:
 if m.get('department')in jnu_names and norm(m['department'])in norm(text):decide('jnu',m,['융합전공'],r,f,'AI융합대학 공식 소개는 인공지능학부·빅데이터융합학과·미래모빌리티학과와 별도로 융합전공 하위에 '+m['department']+' 나열')
r,f,ss=source('gachon-system','gachon');text=ss.get_text(' ',strip=True)
for m in a['gachon']['mappings']:
 if m.get('department')in ['미래사회혁신융합전공','바이오로직스 부트캠프 융합전공','이차전지혁신융합전공','창업융합전공'] and norm(m['department'])in norm(text):decide('gachon',m,['융합전공'],r,f,'공식 학사제도 융합전공 소개·교육과정 및 이수학점 표에 '+m['department']+' 명시')
r,f,ss=source('dku-system','dku')
for table in ss.find_all('table'):
 heading=table.find_previous('h3');g=heading.get_text(' ',strip=True)if heading else None
 campus=table.find_previous('h4').get_text(' ',strip=True).replace('캠퍼스','')
 if g not in ['융합전공','연계전공']:continue
 names=[x.get_text(' ',strip=True)for row in table.find_all('tr')for x in row.find_all('td')]
 for m in a['dku']['mappings']:
  d=m.get('department')or'';last=d.split(' / ')[-1]
  if m.get('campus')and {'죽전':'jukjeon','천안':'cheonan'}.get(campus)!=m.get('campus'):continue
  if any(norm(last)==norm(n)for n in names):decide('dku',m,[g],r,f,'공식 융합/연계전공 제도 '+campus+'캠퍼스 '+g+' 표의 정확한 전공명 '+last+'; 주관대학은 제도 그룹과 구별')
r,f,ss=source('cau-2026-alt','cau');text=f.with_suffix('.txt').read_text()
# Full 2026 freshman academic guide explicitly labels each of these system headings.
cau_names=['게임·인터렉티브미디어융합전공','금융AI 융합전공','나노융합전공','데이터프라이버시 융합전공','문화다양성 융합전공','문화콘텐츠융합전공','사이버보안융합전공','소프트웨어·인문융합전공','인공지능인문 융합전공','창업학융합전공','테크놀로지아트융합전공','한류문화 융합전공']
for m in a['cau']['mappings']:
 d=m.get('department')or''
 if d in cau_names and norm(d)in norm(text):decide('cau',m,['융합전공'],r,f,'2026학년도 신입생 학사가이드 전공제도 융합전공 개별 교육과정 제목: '+d+'; 관련대학/주임교수는 분류 기준에서 제외')
r,f,ss=source('khu-all-alt','khu');text=ss.get_text(' ',strip=True)
for m in a['khu']['mappings']:
 d=m.get('department')or''
 if d.startswith('융합 '):
  name=d.split(' ',2)[1]+'융합전공'
  if norm(name)in norm(text):decide('khu',m,['융합전공'],r,f,'공식 대학 목록에서 일반 단과대·학과와 별도 융합전공 구분 아래 '+name+' 명시')
r,f,ss=source('catholic-glocal','catholic')
for m in a['catholic']['mappings']:
 if m.get('department')=='글로컬문화스토리텔링융복합전공':decide('catholic',m,['융복합전공'],r,f,'공식 융합전공학부 사이트 융복합전공 메뉴 및 교육목적 분류 표에 글로컬문화스토리텔링융복합전공 명시')
r,f,ss=source('hansung-2026','hansung');text=f.with_suffix('.txt').read_text()
for m in a['hansung']['mappings']:
 if m.get('department')=='자기설계전공'and'자기설계전공'in text:decide('hansung',m,['자기설계전공'],r,f,'2026학년도1학기 트랙선택 공식 안내에서 자기설계전공을 별도 제도로 명시. 사용자 결정: 일반 공식 트랙은 단과대·학부 아래 유지하고 별도 제도만 분류')
# Existing 2026-2 university handbook has official system type rows, independent of ownercollege.
f=Path('work/college-major-filters-20261012/b-sources/kangnam-handbook.txt');text=f.read_text();r={'url':'https://app.kangnam.ac.kr/knumis/sb/sbm1050DownloadAll.jsp?schl_smst=2&schl_year=2026'}
checked.setdefault('kangnam',[]).append({'url':r['url'],'sourceFile':str(f)})
for m in a['kangnam']['mappings']:
 d=m.get('department')or''
 if d in ['Wel-Tech융합전공','반도체시스템융합전공']and norm(d)in norm(text):decide('kangnam',m,['융합전공'],r,f,'공식2026-2수강편람 융합전공 제도 표의 Wel-Tech/반도체시스템; 주관학부·참여학과와 제도 분리')
r,f,ss=source('khu-2026','khu');text=ss.get_text(' ',strip=True)
for m in a['khu']['mappings']:
 d=m.get('department')or''
 if d.startswith('융합 '):
  base=d.split(' ',2)[1]
  if norm(base)in norm(text):decide('khu',m,['융합전공'],r,f,'공식2026 전공별 교육과정 기본구조 표 대학명=융합전공 영역의 학과/전공 '+base+'; 주관 단과대와 제도 분리')
r,f,ss=source('hufs-2026-seoul','hufs');text=f.with_suffix('.txt').read_text()
hufs_names={'브릭스전공':'BRICs(브릭스)전공','EU전공':'EU(유럽연합)전공','동북아외교통상전공':'동북아외교통상전공','문화콘텐츠학전공':'문화콘텐츠학전공','국가리더전공':'국가리더전공','국가리더전공(글로벌)':'국가리더전공','세계문화예술경영전공':'세계문화예술경영전공','상담·UX심리전공':'상담·UX심리전공','Business & AI 전공':'Business & AI 전공','융복합소프트웨어전공':'융복합소프트웨어전공'}
for m in a['hufs']['mappings']:
 d=m.get('department')or''
 if d in hufs_names and norm(hufs_names[d])in norm(text):decide('hufs',m,['일반융합전공'],r,f,'2026학년도1학기 공식 수강편람 제4항 융합전공 → 일반융합전공 개설전공 목록 '+hufs_names[d]+'; 원자료 이름 별칭 명시, AI융합대학 실제 입학전공은 이 목록과 별개')
r,f,ss=source('cnu-linked','cnu');names=[]
for table in ss.find_all('table'):
 for row in table.find_all('tr'):
  cells=row.find_all('td')
  if len(cells)>=3:names.append(cells[2].get_text(' ',strip=True))
for m in a['cnu']['mappings']:
 d=m.get('department')or''
 if not d.startswith('연계전공학과 '):continue
 base=d.split(' ',1)[1]+'전공'
 if any(norm(base)==norm(n)for n in names):decide('cnu',m,['연계전공'],r,f,'공식 학사제도 연계전공 현황 표 전공명='+base+'; 표 주관학과는 그룹 기준에서 제외')
# Formal 2025 curriculum academic-regulation appendices preserve legacy source aliases.
r,f,ss=source('cnu-2025-book','cnu');text=f.with_suffix('.txt').read_text()
for m in a['cnu']['mappings']:
 d=m.get('department')or''
 aliases={'연계전공학과 도덕.윤리':'도덕‧윤리','연계전공학과 스마트이트레이드':'스마트이트레이드','연계전공학과 창업경영학':'창업경영학'}
 if d in aliases and aliases[d]in text:decide('cnu',m,['연계전공'],r,f,'공식2025교육과정 학사운영규정 별표1-3 연계전공 설치현황 및 학위종별 표: '+aliases[d]+'; 도덕.윤리 원자료 구두점 별칭을 명시함')
 if d.startswith('융합학과 '):
  base=d.split(' ',1)[1]
  if norm(base)in [norm(x)for x in ['개인정보보호','바이오의약품 실무','블록체인','사이버보안','클라우드']]:decide('cnu',m,['융합전공'],r,f,'공식2025교육과정 p179 별표1-4 융합전공 설치현황: '+base+'; 참여대학/주관학과가 아닌 공식제도 분류')
r,f,ss=source('cnu-2026-modules','cnu');text=f.with_suffix('.txt').read_text()
for m in a['cnu']['mappings']:
 d=m.get('department')or''
 if d in ['융합학과 디지털 그린바이오 소재','융합학과 디지털 그린바이오 시스템'] and norm(d.split(' ',1)[1]+'융합전공')in norm(text):decide('cnu',m,['융합전공'],r,f,'공식2026교육과정 마이크로디그리 편람 사업단 표기 '+d.split(' ',1)[1]+'융합전공; 사업단/농생대 주관을 소속으로 추론하지 않음')
# PNU official linked-program list explicitly includes integrated social studies.
r,f,ss=source('pnu-linked','pnu');text=ss.get_text(' ',strip=True)
for m in a['pnu']['mappings']:
 if m.get('department')=='통합사회전공' and '통합사회'in text:decide('pnu',m,['연계전공'],r,f,'부산대학교 공식 연계전공 개설현황: 통합사회. 사범대학 참여학과와 별도 제도')
r,f,ss=source('hoseo-mobility','hoseo')
for m in a['hoseo']['mappings']:
 if m.get('department')=='스마트모빌리티융합전공':decide('hoseo',m,['공유대학 융합전공'],r,f,'호서대학교 RISE 공식2026 공지는 충남RISE공유대학 스마트모빌리티융합전공 명시; 일반 호서 학부와 별도 공유대학 프로그램')
r,f,ss=source('khu-2026-guide','khu');text=f.with_suffix('.txt').read_text()
for m in a['khu']['mappings']:
 if m.get('department')=='융합 우주탐사 우주탐사융합전공'and'우주탐사'in text:decide('khu',m,['융합전공'],r,f,'공식2026-1 학사 안내 전공별교육과정 기본구조 표 국제캠퍼스 융합전공 영역 우주탐사')
# Exact official 2026 program announcements, explicit names rather than hostcollege.
r,f,ss=source('ajou-bio-system','ajou')
for m in a['ajou']['mappings']:
 if 'AI바이오의약품융합 연계전공(과)'in(m.get('department')or''):
  decide('ajou',m,['융합연계전공'],r,f,'아주대학교 공식2026.02.26 보도는 AI-바이오의약품 융합연계전공 신설을 명시. 주관 첨단바이오융합대학을 프로그램 분류로 대체하지 않음')
r,f,ss=source('jnu-nextcomm-system','jnu')
for m in a['jnu']['mappings']:
 if m.get('department')=='양자보안차세대통신융합전공':
  decide('jnu',m,['융합전공'],r,f,'전남대학교 차세대통신혁신융합대학사업단 공식 자료실: 양자보안차세대통신융합전공 이수 지침(2025.12.08.) 명시')
# Official list review records even when catalog has no matching programs.
for k,n in [('mokpo','mokpo-systems'),('pnu','pnu-linked'),('changwon','changwon-systems'),('gnu','gnu-systems'),('pknu','pknu-systems'),('ajou','ajou-system'),('jbnu','jbnu-systems')]:
 source(n,k)
r,f,ss=source('kangwon-program-gangneung','kangwon');names=[]
for t in ss.find_all('table'):
 if '복수전공 학위'not in t.get_text():continue
 for row in t.find_all('tr'):
  cs=row.find_all('td')
  if cs:names.append(cs[0].get_text(' ',strip=True))
for m in a['kangwon']['mappings']:
 d=m.get('department')or''
 if any(norm(d)==norm(n)for n in names):decide('kangwon',m,['미래융합가상학과'],r,f,'공식 학사안내 미래융합가상학과 개설 교육과정 표 구분='+d+'; 본과 주관/참여학과와 별도 복수·부전공 제도')
# GNU native grouped source includes system umbrella rather than its individual programs.
r,f,ss=source('gnu-programs','gnu')
for m in a['gnu']['mappings']:
 if m.get('department')=='연계전공':decide('gnu',m,['연계전공'],r,f,'공식 교육과정 연계·융합·학생설계 전공 메뉴 중 연계전공 제도 명시. 원자료는 개별 전공이 아닌 제도 상위 항목이며 이름 추측으로 하위 항목을 만들지 않음')
source('hanbat-program','hanbat')
# University official制度 documents resolve legacy exact program labels.
for n,ds in [('korea-regulation',['소프트웨어벤처융합전공']),('korea-ai',['인공지능융합전공']),('korea-human-digital',['인문사회디지털융합전공']),('korea-2026-alt',['인문학과문화산업융합전공'])]:
 r,f,ss=source(n,'korea')
 for m in a['korea']['mappings']:
  if m.get('department')in ds:decide('korea',m,['융합전공'],r,f,'공식 전공제도 개설표/개별 제도 소개에 원자료 '+m['department']+' 명칭을 명시. 명칭 유사성으로 다른 전공을 합치지 않고 정확한 기존 명칭의 근거 보존')
r,f,ss=source('kunsan-mcd','kunsan');text=ss.get_text(' ',strip=True)
for m in a['kunsan']['mappings']:
 d=m.get('department')or''
 if '(MCD)'not in d:continue
 base=d.replace('(MCD)','');base=re.sub(r'전공$','',base)
 if norm(base)in norm(text):decide('kunsan',m,['모듈형 컨버전스 학사학위과정(MCD)'],r,f,'공식 학사안내 MCD 목록의 '+base+' (원자료 전공명에 MCD 명시). 참여/책임 교수 소속을 단과대 분류로 사용하지 않음; 2027 폐지예고는 현재2026 이수 가능')
r,f,ss=source('jnu-greenbio-home','jnu');text=ss.get_text(' ',strip=True)
for m in a['jnu']['mappings']:
 d=m.get('department')or''
 if d in ['디지털그린바이오소재융합전공','디지털그린바이오시스템융합전공']:
  decide('jnu',m,['융합전공'],r,f,'공식 사업단2026.08.03 수강신청 공지는 디지털그린바이오 시스템/소재 융합전공 신청자를 명시; 주관 농생대가 아닌 제도명 적용')
r,f,ss=source('jnu-greenbio-2026','jnu');text=f.with_suffix('.txt').read_text()
for m in a['jnu']['mappings']:
 if m.get('department')=='디지털그린바이오시스템연계전공':decide('jnu',m,['연계전공'],r,f,'공식2026 그린바이오 교육과정 안내 발표자료는 디지털 그린바이오 시스템 연계전공과 이수 학위 명시. 동명 융합전공과 원자료 행을 임의 통합하지 않음')
for k,n in [('hongik','hongik-program'),('mju','mju-program'),('iccu','iccu-program'),('kumoh','kumoh-program')]:source(n,k)
r,f,ss=source('hongik-convergence-2026','hongik');text=f.with_suffix('.txt').read_text()
for m in a['hongik']['mappings']:
 if m.get('department')in ['디자인엔지니어링전공','문화예술경영전공','미래모빌리티전공']:decide('hongik',m,['융합전공'],r,f,'홍익 공식2026-2 융합전공 신청 안내 p2 캠퍼스/구분/주관학과 표 구분='+m['department']+'; 실제 융합제도 목록에 존재하며 주관학과는 소속으로 사용하지 않음')
r,f,ss=source('hongik-micro-2026','hongik')
r,f,ss=source('pnu-shared-2026','pnu')
for m in a['pnu']['mappings']:
 if m.get('department')in ['미래모빌리티전공','해양미래산업전공','클린에너지전공','AI혁신전공']:decide('pnu',m,['부산공유대학 융합전공'],r,f,'부산대 공식2026 부산공유대학 공지: 4개의 융합전공 미래모빌리티/해양미래산업/클린에너지/AI혁신; 대학간 공동교육 별도제도')
for n,d in [('kunsan-media','미디어리터러시교육(MCD)'),('kunsan-character','입체캐릭터전공(MCD)'),('kunsan-brand','패션디자인&브랜딩커뮤니케이션전공(MCD)')]:
 r,f,ss=source(n,'kunsan')
 for m in a['kunsan']['mappings']:
  if m.get('department')==d:decide('kunsan',m,['모듈형 컨버전스 학사학위과정(MCD)'],r,f,'공식 학사안내 MCD 개별 교육과정 페이지: '+d+'; 원자료 브랜딩/공식 브랜드커뮤니케이션 표기차이는 패션브랜딩 학위명·과정소개에서 명시확인')
for k,n in [('pcu','pcu-program-list'),('nsu','nsu-program-list'),('hyupsung','hyupsung-program-list'),('kwangwoon','kwangwoon-program-list'),('kau','kau-micro')]:source(n,k)
r={'url':'https://inhabioedu.com/major/requirement'};f=P/'inha-bio-web-evidence.txt';checked.setdefault('inha',[]).append({'url':r['url'],'sourceFile':str(f),'acquisition':'official page indexed text; live TLS expired; no insecure TLS bypass'})
for m in a['inha']['mappings']:
 if m.get('department')=='생명공학과 / AI 바이오공정융합전공':decide('inha',m,['융합전공'],r,f,'인하대학교 바이오특성화대학사업단 공식 졸업요건: 학위수여 AI바이오공정 융합전공·부전공, 주전공과 융합전공2개학위; 참여 생명공학과 아닌 공식 전공제도 분류')
r,f,ss=source('cnu-2025-book','cnu');text=f.with_suffix('.txt').read_text()
for m in a['cnu']['mappings']:
 d=m.get('department')or''
 if d=='자기설계 스포츠심리상담':decide('cnu',m,['자기설계전공'],r,f,'공식2025교육과정 별표1-2 자기설계전공 설치현황 및 p489 자기설계전공 교육과정 스포츠심리상담 명시')
 for parent in ['지식융합학부','국가안보융합학부','국제학부','기술경영건설학부']:
  if d==parent or d.startswith(parent+' '):decide('cnu',m,[],r,f,'공식2025편람 학칙 학사조직 및 p71 단과대학 수19개(지식융합학부,국가안보융합학부,국제학부,기술경영건설학부 포함). 실제 공식학부 하위전공으로 별도 융합제도와 구별',college=parent,kind='ordinaryCollege')
for k,n in [('kaist','kaist-minor-systems'),('kmou','kmou-programs'),('koreatech','koreatech-programs')]:source(n,k)
r,f,ss=source('jeju-2025-program-rules','jeju');text=f.with_suffix('.txt').read_text()
for m in a['jeju']['mappings']:
 d=m.get('department')or''
 if d in ['제주대학교 연계전공 사회복지전공','제주대학교 연계전공 중국비지니스무역전공']:decide('jeju',m,['연계전공'],r,f,'공식2025 제5차 교무회의 자료 학위종별 표 '+d.split('연계전공 ',1)[1]+'(연계) 명시; 현행 융합신청 목록에 없다는 이유로 기존연계 분류 삭제하지 않음')
r,f,ss=source('jnu-2024-yearbook','jnu');text=f.with_suffix('.txt').read_text()
for m in a['jnu']['mappings']:
 if m.get('department')in ['아시아문화학연계전공','인문기반융합연계전공','통합사회연계전공']:decide('jnu',m,['연계전공'],r,f,'전남대학교 공식2024통계연보 교육·연구 대학별전공 표 별도 연계전공 아래 '+m['department']+' 정확히명시')
r,f,ss=source('jnu-integrated-social','jnu')
for k,n in [('kongju','kongju-program-guide'),('nambu','nambu-handbook-encoded')]:source(n,k)
for n,d in [('jnu-battery-system','이차전지융합전공'),('jnu-semiconductor-system','반도체융합전공')]:
 r,f,ss=source(n,'jnu')
 for m in a['jnu']['mappings']:
  if m.get('department')==d:decide('jnu',m,['융합전공'],r,f,'공식 특성화대학사업단 모집/이수설명은 '+d+'를 별도 복수전공 이수제도로 명시. 사업단의 대학명칭을 실제 단과대로 사용하지 않음')
r,f,ss=source('hufs-ai-college','hufs');text=ss.get_text(' ',strip=True)
for m in a['hufs']['mappings']:
 if m.get('department')in ['AI데이터융합전공','Finance & AI융합전공','Language & AI융합전공','Social Science & AI융합전공']:
  decide('hufs',m,[],r,f,'공식 AI융합대학 소개는 서울Language&AI/SocialScience&AI, 글로벌Finance&AI/AI데이터 4개 학부로 구성됨을 직접명시. 실제 입학학부의 전공원자료 별칭이며 일반융합전공제도 목록과 구별',college='AI융합대학',kind='ordinaryCollege')
checked.setdefault('mmu',[]).append({'url':'https://www.mmu.ac.kr/','sourceFile':'work/university-research/catalog-j/mmu-2026-2-guide.txt','evidence':'2026-2공식수강편람 연계전공 크루즈레저산업 및 모듈형해양레저공학·스마트해양ICT 명시; native13학부학과에는 이 제도명 없음'})
checked.setdefault('pknu',[]).append({'url':'https://www.pknu.ac.kr/upload/raonkeditordata/2025/09/22/20250922_140343492_62128.jpg','sourceFile':str(P/'pknu-program-image.jpg'),'evidence':'공식제도 이미지 검토: 융합7개 글로벌외국어/사회복지/지능형로봇/글로벌블루수산/데이터비즈니스/데이터사이언스/의공학IT, 학생설계1아시아경제. native125rowsexact제도일치없음'})
for k,n in [('baekseok','baekseok-program-guide'),('konkuk','konkuk-program-guide')]:source(n,k)
r,f,ss=source('mokpo-computer-major','mokpo')
for m in a['mokpo']['mappings']:
 if m.get('department')=='융합소프트웨어전공':decide('mokpo',m,[],r,f,'공식 공과대학 컴퓨터학부 전공소개 본문: 컴퓨터학부 융합소프트웨어 전공, 일반 학위전공으로 별도융합제도 아님; 2026학기 편입모집인원표에서도 공과대학 컴퓨터학부 하위전공 명시',college='공과대학',kind='ordinaryCollege')
source('mokpo-2026-admission','mokpo')
r,f,ss=source('mju-future-college','mju')
for m in a['mju']['mappings']:
 if m.get('department')=='사회복지학과':decide('mju',m,[],r,f,'공식 미래융합대학 소개 본문은 11번째 단과대학과 실제 학위과정 사회복지학과 명시. 휴먼복지행정 융합전공(舊사회복지학)과 같은 이름만으로 동일과정 판단하지 않음',college='미래융합대학',kind='ordinaryCollege')
for n,parent,names,campus in [
 ('international','국제학부',['국제학부','국제학전공'],'seoul'),
 ('ld','Language & Diplomacy학부',['Language & Diplomacy학부','Language & Diplomacy전공'],'seoul'),
 ('lt','Language & Trade학부',['Language & Trade학부','Language & Trade전공'],'seoul'),
 ('kfl','KFL학부',['KFL학부','외국어로서의한국어교육전공','외국어로서의한국어통번역전공'],'seoul'),
 ('biomedical','바이오메디컬공학부',['바이오메디컬공학전공'],'global'),
 ('climate','기후변화융합학부',['기후변화융합전공'],'global')]:
 r,f,ss=source('hufs-direct-'+n,'hufs')
 for m in a['hufs']['mappings']:
  if m['campus']==campus and m.get('department')in names:decide('hufs',m,[parent],r,f,'공식 대학구조 단과대학 아래 아닌 독립학부로 기재되고 '+parent+' 전용학부소개/교육과정 확인. 실제 학위학부 내부전공이며 별도 융합제도·가상단과대로 변환하지 않음',kind='universityDirect')
r,f,ss=source('hufs-2025-2026-book','hufs')
# Official printed p71 university organization explicitly lists parenthesized degree majors.
hufs_roster={'FATI전공':'서양어대학','중국언어문화전공':'중국학대학','중국외교통상전공':'중국학대학','일본언어문화전공':'일본학대학','융합일본지역전공':'일본학대학','언론·정보전공':'사회과학대학','광고·PR·브랜딩전공':'사회과학대학','방송·영상·뉴미디어전공':'사회과학대학','경제학전공':'상경대학','경영학전공':'경영대학','동아프리카어전공':'국가전략언어대학','서아프리카어전공':'국가전략언어대학','남아프리카어전공':'국가전략언어대학','Global Business & Technology전공':'경상대학','컴퓨터공학전공':'공과대학','TESOL영어학전공':'통번역대학','영미문학·번역전공':'통번역대학'}
for m in a['hufs']['mappings']:
 d=m.get('department')
 if d in hufs_roster:decide('hufs',m,[],r,f,'공식2025-2026일람 p71 학사조직/소속학부 괄호 내부세부전공 정확명 명시(통번역 TESOL/영미문학은 p105). 2025기준이므로2026공식단과대본부 조직과도 동일부모 확인; 융합일본지역 등 일반학위전공을 별도융합제도로 오인하지 않음',college=hufs_roster[d],kind='ordinaryCollege')
r,f,ss=source('hufs-culture-college','hufs')
source('hufs-sport-history','hufs')
for m in a['hufs']['mappings']:
 if m['campus']=='global' and m.get('department')in ['디지털콘텐츠학부','투어리즘 & 웰니스학부','글로벌스포츠산업학부','글로벌스포츠산업전공','글로벌e스포츠매니지먼트전공']:
  decide('hufs',m,[],r,f,'현재 공식 Culture & Technology융합대학 소개 본문 학부소개: 디지털콘텐츠/투어리즘웰니스/글로벌스포츠산업학부. 스포츠 전용공식연혁2024.10 e스포츠매니지먼트 세부전공 신설. 2021독립학부 이력을 현행소속으로 오용하지 않음',college='Culture & Technology융합대학',kind='ordinaryCollege')
for m in a['inha']['mappings']:
 if m.get('department')=='연계전공(SCSC)':
  r={'url':m['sourceUrl']};f=Path(m['sourceFile']);checked.setdefault('inha',[]).append({'url':r['url'],'sourceFile':str(f),'evidence':'현재2026-2 공식 시간표query department=연계전공(SCSC), college query=소프트웨어융합대학(SCSC)'})
  decide('inha',m,['연계전공'],r,f,'현재2026-2 학교공식시간표 query가 department=연계전공(SCSC)로 직접 제도구분 명시. college query 소프트웨어융합대학(SCSC)는 행정조회경로로 보존하며 소속단과대라고 치환하지 않음')
r={'url':'https://ee.kgu.ac.kr/NFUpload/nfupload_down.php?bo_idx=1&name=%EB%B6%99%EC%9E%84+2022+%EA%B5%90%EC%9C%A1%EA%B3%BC%EC%A0%95+%EC%95%88%EB%82%B4%EC%B1%85%EC%9E%90+%EC%B5%9C%EC%A2%85%EB%B3%B8.pdf&tmp_name=3422095375_696a1571.pdf&userchk=Y&userid='};f=P/'kyonggi-2022-indexed-evidence.txt'
checked.setdefault('kyonggi',[]).append({'url':r['url'],'sourceFile':str(f),'acquisition':'official indexed printedp16; live original PDF unavailable'})
for m in a['kyonggi']['mappings']:
 if m.get('department')=='융합데이터공학전공':decide('kyonggi',m,['융합전공'],r,f,'공식2022교육과정 printedp16 연계 및 융합전공 교육과정 표 구분 융합전공에 융합데이터공학전공 직접명시. 공식indexed원문 증거이고 live원본PDF는110byteHTML. 현재학기원자료 동일legacy명을 분류하며 AI빅데이터로 명칭추정/교체하지 않음')
r,f,ss=source('hufs-2025-yearbook','hufs')
for m in a['hufs']['mappings']:
 if m['campus']=='global'and m.get('department')=='영어통번역학전공':decide('hufs',m,[],r,f,'공식2025통계연보 대학별학과학생표 PDFindex79에서 통번역대학 영어통번역학전공 정확행 직접명시; 현행학부에 기존legacy교과가 남는 경우를 삭제/임의명칭변환하지 않음',college='통번역대학',kind='ordinaryCollege')
r,f,ss=source('pknu-fedu-2026','pknu')
for m in a['pknu']['mappings']:
 if (m.get('department')or'').startswith('수해양산업교육과 '):decide('pknu',m,[],r,f,'공식 학과2026교육과정 본문 수해양산업교육과 세부전공 기관/냉동/식품/양식/어업/항해 명시. 공식 본교 교육과정 안내의 수산과학대학 학과배치와 연결; 타과 수강가능성으로 다른단과대에 배치하지 않음',college='수산과학대학',kind='ordinaryCollege')
checked.setdefault('pknu',[]).append({'url':'https://www.pknu.ac.kr/','sourceFile':'work/course-owner-filter-20261012/c-sources/pknu.html','evidence':'공식학부별 교육과정안내 수산과학대학 아래 수해양산업교육과 명시'})
# Import ordinary source corrections only; program classifications supersede.
old=json.load(open('work/college-major-filters-20261012/college-b.json'))
for e in old['entries']:
 if e['university']not in a or e['kind']=='programGroup':continue
 for m in a[e['university']]['mappings']:
  if m.get('department')!=e['department']or e['campus']not in ['*',m.get('campus')]:continue
  key=(e['university'],m.get('campus','*'),m['sourceLabel'])
  if key not in out:out[key]={**e,'sourceLabel':m['sourceLabel'],'campus':m.get('campus','*'),'kind':'ordinaryCollege'if e['college']else'universityDirect'}
old_a=json.load(open('work/college-major-filters-20261012/college-a.json'))
for e in old_a['entries']:
 if e['university']not in a or e['university']=='cau' or e['kind']!='college':continue
 for m in a[e['university']]['mappings']:
  if m.get('department')!=e['department']or e['campus']not in ['*',m.get('campus')]:continue
  key=(e['university'],m.get('campus','*'),m['sourceLabel'])
  if key not in out:out[key]={**e,'sourceLabel':m['sourceLabel'],'campus':m.get('campus','*'),'kind':'ordinaryCollege'}
for e in json.load(open(O/'kangwon-exact-b.json'))['entries']:
 key=(e['university'],e['campus'],e['sourceLabel'])
 if key not in out:out[key]=e
ewha=json.load(open(O/'ewha-ordinary-b.json'))
for e in ewha['entries']:out[(e['university'],e['campus'],e['sourceLabel'])]=e
checked['ewha']=ewha['checkedSources']
for e in json.load(open(O/'konkuk-exact-b.json'))['entries']:out[(e['university'],e['campus'],e['sourceLabel'])]=e
for k,n in [('konkuk','konkuk-english-2026'),('knue','knue-shared-programs'),('knue','knue-program-systems')]:source(n,k)

extra=json.load(open(O/'extra-ordinary-b.json'))
for e in extra['entries']:
 key=(e['university'],e['campus'],e['sourceLabel'])
 if key not in out or out[key]['kind']!='officialProgramSystem':out[key]=e
for k,rs in extra['checkedSources'].items():checked.setdefault(k,[]).extend(rs)
r,f,ss=source('kongju-program-guide','kongju')
for m in a['kongju']['mappings']:
 if m.get('department')=='농산업창업전공':decide('kongju',m,['연계전공'],r,f,'공식2025-1 강의일람표 printed7 학과별 이수학점 표 농산업창업전공 행 졸업학점 열에 연계전공 직접명시; 산업과학대학 주관행정소속을 별도제도 분류로 사용하지 않음')

r,f,ss=source('kongju-2022-guide','kongju')
for m in a['kongju']['mappings']:
 if m.get('department')in ['통합사회전공','통합과학전공']:decide('kongju',m,['연계전공'],r,f,'공식2022-1 강의일람표 printed81(PDFindex88) 사범대학 학과별 이수학점 표 통합사회전공/통합과학전공/교육행정전공 3행의 우측 연계전공 병합셀 직접명시. PNG 표 시각검토로 병합범위 확인. 주관 사범대학을 프로그램제도 그룹으로 사용하지 않음')
(O/'program-groups-b.json').write_text(json.dumps({'final':False,'entries':list(out.values()),'checkedSources':checked,'unresolved':unclear,'scope':list(a)},ensure_ascii=False,indent=2))
print('entries',len(out));print({k:sum(v['university']==k and v['kind']=='officialProgramSystem'for v in out.values())for k in checked})
