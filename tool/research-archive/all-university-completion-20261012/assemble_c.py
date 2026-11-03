import pathlib,json,re,sys
P=pathlib.Path('work/all-university-completion-20261012');sys.path.insert(0,'work/college-major-filters-20261012');from html_tree_c import Tree
norm=lambda s:re.sub(r'\s+','',s or'')
assets={f.stem:json.loads(f.read_text())['mappings']for f in pathlib.Path('assets/timetable/organizations').glob('*.json')if f.stem>='postech'and f.stem!='smu'}
receipts={x['id']:x for x in json.loads((P/'c-receipts.json').read_text())}
entries={};coverage=[]
def put(u,r,college=None,group=None,source=None,evidence='',kind=None,**extra):
 e={'university':u,'department':r.get('department'),'sourceLabel':r.get('sourceLabel'),'campus':r.get('campus','*'),'college':college,'kind':kind or ('programGroup'if group else'college'),'sourceUrl':source['url'],'sourceFile':source['file'],'evidence':evidence,**extra}
 if group:e['group']=group
 entries[(u,e['sourceLabel'],e['campus'])]=e
# Reuse only actual ordinary academic organization evidence, never old program-to-host assignments.
old=json.load(open('work/college-major-filters-20261012/college-c.json'))['entries']
for e in old:
 u=e['university']
 if u not in assets or e['kind']=='programGroup':continue
 for r in assets[u]:
  if norm(r.get('department'))==norm(e['department']):
   put(u,r,college=e['college'],group=e.get('group'),source={'url':e['sourceUrl'],'file':e['sourceFile']},evidence=e['evidence'],kind=e['kind'])
def map_names(u,names,group,src,ev,**extra):
 src=receipts[src]
 for r in assets[u]:
  d=norm(r.get('department'));label=norm(r.get('sourceLabel'))
  if d in {norm(s)for s in names}or label in {norm(s)for s in names}:put(u,r,group=group,source=src,evidence=ev,affiliationStatus='officialProgramSystem',**extra)
def degree(u,names,col,src,ev,kind='college'):
 src=receipts[src]
 for r in assets[u]:
  if norm(r.get('department'))in {norm(s)for s in names}:put(u,r,college=col,source=src,evidence=ev,kind=kind)
# Header and current-list membership, not name suffix.
for uid,group in [('swu-linked','연계전공'),('swu-convergence','융합전공')]:
 root=Tree(pathlib.Path(receipts[uid]['file']).read_text()).root
 names=[n.txt()for n in root.nodes('h2')][4:]
 map_names('swu',names,group,uid,'공식 '+group+' 페이지 h1 제목 및 개별 h2 전공 목록: '+', '.join(names))
map_names('sookmyung',['스토리텔링전공','글로벌비즈니스개발학전공','글로벌환경학전공','빅데이터분석학전공','상담학전공','순헌융합인문학전공','통상학전공','문화예술기획전공'],'연계전공','sookmyung-system','2024학년도 공식 연계전공 교육과정 개편 안내의 연계전공명 표. 주관학과를 프로그램 단과대로 치환하지 않음.')
map_names('sejong',['융합창업전공'],'연계전공','sejong-system','공식 연계·융합전공 안내 문의처 표의 융합창업 연계전공, 연계전공1개. 프로그램명 ‘융합’만으로 융합전공 분류하지 않음.')
map_names('seoultech',['IT융합소프트웨어전공','빅데이터경영공학전공','지식재산기술경영전공','창업융합전공','ICT인공지능전공','반도체융합공학전공','핀테크AI경영전공','한국문화전공','인공지능반도체융합전공','웹툰창작전공'],'연계융합전공','seoultech-system','2025 대학요람 10.연계융합전공(245쪽) 아래 10개 전공의 공식 목록과 소개. 주관대학은 그룹으로 대체하지 않음.')
linked=['비교문화전공','일본학전공','글로컬문화콘텐츠전공','고전학연계전공','미래인문학연계전공','융합언어학연계전공','공익과법연계전공','국제통상학전공','앙트레프레너십연계전공','차세대반도체공학연계전공','반도체소부장인공지능시스템연계전공','컴바이오믹스연계전공','에너지과학연계전공','한국학연계전공','한국학전공']
map_names('skku',linked,'연계전공','skku-guide','2026 대학요람 목차 및 해당 교육과정의 명시적 ‘연 계 전 공’ 목록. suffix 포함 여부와 무관하게 공식 이름을 대조.')
tracks=['인구구조변화와회복사회 융합트랙','반도체소재부품장비패키징 융합트랙','반도체소자회로설계및시스템 융합트랙','첨단반도체 융합트랙','과학기술정책인재양성 융합트랙','차세대바이오헬스 융합트랙']
map_names('skku',tracks,'융합트랙','skku-guide','2026 대학요람의 명시적 ‘융 합 트 랙’ 목록; 대학 소속으로 치환하지 않음.')
# Current UOS undergraduate specialties are ordinary degree organization, not additional majors.
degree('uos',['지능형반도체전공','융합바이오헬스전공','첨단인공지능전공'],'인공지능융합대학','uos-ai','공식 인공지능융합대학 > 학부·과 > 첨단융합학부 > 연혁 및 일반현황: 2023.04 세 전공 신설,2026.03 정규학부 입학정원26/6/5명. 전공 이름만으로 프로그램 그룹화하지 않음.')
degree('sku',['전  자  공  학  과'],'이공대학','sku-ee','공식 학과소개 제목: 이공대학 전자공학과; 원자료 글자 사이 공백만 정규화.')
degree('sku',['컴 퓨 터 공 학 과'],'이공대학','sku-cs','공식 컴퓨터공학과 홈페이지 이공대학 표기; 원자료 글자 사이 공백만 정규화.')
degree('sungkyul',['파이데이아학부'],'파이데이아칼리지','sungkyul-paideia','공식 파이데이아학부 홈페이지: 성결대학교 파이데이아칼리지; 학부 공지에서도 파이데이아칼리지 파이데이아학부 명시.')
# SNU composite native query labels explicitly name the additional-major entity; cross-check official academic list.
if receipts.get('snu-colleges',{}).get('file'):
 s=pathlib.Path(receipts['snu-colleges']['file']).read_text();root=Tree(s).root
 txt=norm(root.txt())
 for r in assets['snu']:
  label=r.get('sourceLabel')or''
  m=re.search(r'(연계전공|연합전공)\s+([^()]+)',label)
  if m and norm(m.group(2))in txt:put('snu',r,group=m.group(1),source=receipts['snu-colleges'],evidence='공식 교육/대학 페이지의 '+m.group(1)+' 목록에 '+m.group(2)+' 명시. 원자료의 복합 조회 이름 '+label+' 유지; 괄호 밖 주관학과를 프로그램 단과대로 사용하지 않음.',affiliationStatus='officialProgramSystem')
# Additional direct academic organization and official system sources.
map_names('skku',['바이오융합연계전공'],'연계전공','skku-bioconv','공식 바이오융합연계전공 교육과정 페이지의 제목. 정규 자연과학대학 학과로 치환하지 않음.')
map_names('skku',['융합소프트웨어전공','융합소프트웨어연계전공','마이크로시스템기술전공','생명산업공학전공'],'연계전공','skku-guide','2026 대학요람 대학 연혁의 명시적 융합소프트웨어연계전공 신설, 마이크로시스템기술연계전공 신설 및 생명산업공학연계전공→생명공학연계전공 명칭변경. 과거 원자료 이름 보존.')
map_names('swu',['노년학전공','사회원예학전공','패션디자인·비즈니스전공','휴먼서비스전공','공공안전전공','스마트헬스케어전공'],'연계전공','swu-legacy','공식 자체평가보고서 대학 연혁 2016/2018의 연계전공/연계융합전공 설치·폐지 기록. 과거 원자료 이름 유지; 현재 모집 주장 아님.')
degree('swu',['소프트웨어융합학과'],'미래산업융합대학','swu-legacy','2016.03 직제개편: 멀티미디어학과는 소프트웨어융합학과로 명칭 변경하고 미래산업융합대학으로 소속 변경.')
degree('sookmyung',['자유전공학부'],'순헌칼리지','sookmyung-free','공식 자유전공학부 페이지의 순헌칼리지 제목 및 소속 학부 소개.')
degree('sookmyung',['융합학부'],'순헌칼리지','sookmyung-fusion','공식 소개 문장: 순헌칼리지 융합학부는 모든 재학생에게 다면적 연계전공을 통해 폭넓은 학문적 경험을 제공합니다. 학부 조직과 개별 연계전공 제도 구분.')
degree('tuk',['시스템디자인전공','데이터콘텐츠전공'],'국제미래공학부','tuk-global','공식 국제미래공학부 교육목표 표 두 전공. 대학 단위가 아닌 독립 학부가 공식 부모 조직.')
degree('tuk',['전력응용시스템전공'],'첨단융합대학','tuk-current','공식 메인 대학·학과 카드: 첨단융합대학 > 에너지·전기공학부 > 전력응용시스템전공.')
for r in assets['syu']:
 if norm(r.get('department'))=='글로벌자유전공학부':put('syu',r,group='글로벌자유전공학부',kind='universityDirect',source=receipts['syu-admission'],evidence='2026 외국인 모집요강 단과대학 열에 글로벌자유전공학부 독립 학부 명시. 단과대를 임의 생성하지 않음.')
map_names('uos',['빅데이터분석학전공','동아시아문화학전공','도시부동산기획경영학전공','운영형AI에이전트전공'],'융합형 복수전공','uos-fusion','공식 융합형 복수전공 페이지 통섭전공/AI융합전공 운영 전공 목록에 정확한 전공명 존재. 학과 주관 단과대로 치환하지 않음.')
degree('sogang',['글로벌한국학과'],'지식융합미디어대학','sogang-global','공식 지식융합미디어대학 사이트 글로벌한국학과 전공선택과목, 페이지 대학명/주소 명시. 글로벌한국학부와 혼동하지 않음.')
# Correct SCNU exact membership: economics is not agricultural economics.
scnu_src={'url':'https://www.scnu.ac.kr/haksa/cm/cntnts/cntntsView.do?cntntsId=1325&mi=1474','file':'work/college-major-filters-20261012/scnu-tuition.html'}
tr=Tree(pathlib.Path(scnu_src['file']).read_text()).root.nodes('table')[0]
parent=None
parents=['본부직속','그린스마트팜스쿨','애니메이션·문화콘텐츠스쿨','우주항공첨단소재스쿨','사범대학','약학대학','평생교육스쿨']
for row in tr.nodes('tr'):
 cells=[n for n in row.cs if n.tag in ['td','th']]
 if not cells:continue
 if cells[0].txt() in parents:parent=cells[0].txt()
 if not parent:continue
 tokens={norm(x).strip('*')for c in cells for x in re.split(r'[,/()]',c.txt())}
 for r in assets['scnu']:
  name=norm(r.get('department'))
  if name in tokens:
   put('scnu',r,college=None if parent=='본부직속'else parent,group=parent if parent=='본부직속'else None,kind='universityDirect'if parent=='본부직속'else'college',source=scnu_src,evidence='공식 2026 학부 수업료 표의 명시적 '+parent+' rowspan 아래 정확한 학과/전공 토큰 '+r['department']+'. 경제학과 농업경제학의 부분문자열 매칭 금지.')
degree('swu',['개인정보보호전공','정보보호학부'],'미래산업융합대학','swu-assignment','공식 2026-2 전공배정 가능인원 표53/54,60/61,62/63 및128/129행: 미래산업융합대학 정보보호/지능정보보호학부 개인정보보호전공. 별개 마이크로전공 동일명과 구분. 실제 원자료 PP00003/13/08/16/15/07/02/18 9강좌 전체는 정규 PP 학부 전공 목록이며 마이크로 교육과정과는 부분 중복.')
degree('sogang',['영미어문전공','미국문화전공'],'인문대학','sogang-2024-guide','공식 2024 외국인 모집요강 인문대학 > 영문학부 > 영미어문전공/미국문화전공 정확한 계층.')
degree('scnu',['동물생명산업전공','융합산업전공','스포츠레저전공'],'평생교육스쿨','scnu-2025-guide','2025 공식 모집요강 학부모집단위 표: 평생교육스쿨 > 미래융합학부 > 동물생명산업/융합산업/스포츠레저전공트랙. 정규 입학생 학부 전공트랙이며 추가 전공제도로 치환하지 않음.')
degree('scnu',['피아노학전공'],'애니메이션·문화콘텐츠스쿨','scnu-2025-guide','2025 공식 모집요강 학부모집단위 표의 예체능분야 피아노학전공 및 72쪽 행정실 연락처 소속 표. current tuition음악예술융합 명칭만으로 변환하지 않음.')
degree('scnu',['경제학전공'],'애니메이션·문화콘텐츠스쿨','scnu-org','독립 공식 조직도 이미지 alt: 사회과학분야-물류학과,경제학전공,무역학전공,법학과,행정학과,경영학과,회계학과,사회복지학부. 2026 수업료 표 소속을 별개 조직도에서 교차 확인.')
degree('sejong',['글로벌조리학과'],'호텔관광대학','sejong-legacy-rule','공식 학칙 별표2 학과별 학위수여 종류: 호텔관광대학 글로벌조리학과. 과거 원자료 학과명 그대로 유지.')
degree('sejong',['법학부 법학전공'],'법학부','sejong-legacy-rule','공식 학칙 별표2의 대학 열 법학부, 학부/전공 열 법학전공. 독립 학부 조직명 그대로 사용, 예체능대학으로 잘못 합치지 않음.')
degree('sejong',['데이터사이언스학과'],'소프트웨어융합대학','sejong-legacy-rule','공식 학칙 별표2: 소프트웨어융합대학 데이터사이언스학과 및 지능기전공학부(무인이동체공학전공/스마트기기공학전공). 원자료 역사적 학과명 유지; 현재 인공지능데이터사이언스 명칭으로 임의 교체하지 않음.')
degree('sejong',['전자정보통신공학과'],'전자정보공학대학','sejong-legacy-rule','공식 학칙 별표2: 전자정보공학대학 전자정보통신공학과, 원자료 과거 학과명 보존.')
degree('sejong',['환경에너지공간융합학과'],'공과대학','sejong-legacy-rule','공식 학칙 별표2 및 부칙2014/2015: 공과대학 환경에너지공간융합학과. 정규 학과이며 융합전공 제도로 분류하지 않음.')
degree('sejong',['국방시스템공학과'],'공과대학','sejong-rule','공식 계약학과 설치·운영 규정의 국방시스템공학과-공과대학 명시.')
degree('sejong',['지구자원시스템공학과'],'공과대학','sejong-major-intro','대양휴머니티칼리지 공식 학과소개 페이지의 공과대학 학과 목록 지구자원시스템공학과.')
degree('sch',['미래산업기술공학전공','미래바이오융합공학전공'],'창의라이프대학','sch-advanced','공식 산학협력단 계약학과 페이지 프로그램명 창의라이프대학 > 조기취업형 계약학과 > (2026년 이후) 첨단융합공학부 미래산업기술공학/미래바이오융합공학전공. 별개 official 학과 홈페이지2026-10-02 기사에서도 창의라이프대학 첨단융합공학부 확인.')
degree('swu',['교육심리학과'],'사회과학대학','swu-org2011','공식 대학 자체평가보고서 행정조직및기구 사회과학대학 목록의 교육심리학과. 별개 공식2023 전공진로로드맵(https://www.swu.ac.kr/www/m-pdf/2023_socienceg.pdf) 제목 사회과학대학 교육심리학과도 검색 원문 확인. 교원양성기관평가 표기만을 소속 근거로 사용하지 않음.')
# Historical Sejong evidence is not a confirmed CURRENT affiliation. Preserve in report, not an applicable mapping.
for k,e in list(entries.items()):
 if e['university']=='sejong'and e.get('sourceFile')==receipts['sejong-legacy-rule']['file']:del entries[k]
# User approved official EnterpriseSchool heading (2026-10-12), additional-major system not college.
es={'url':'https://home.sch.ac.kr/sch/03/011000.jsp','file':'work/college-major-filters-20261012/sch-es.html'}
estxt=norm(Tree(pathlib.Path(es['file']).read_text()).root.txt())
for r in assets['sch']:
 if norm(r.get('department'))in estxt and (r.get('college')=='엔터프라이즈스쿨' or entries.get(('sch',r.get('sourceLabel'),r.get('campus','*')),{}).get('college')=='엔터프라이즈스쿨'):
  put('sch',r,group='엔터프라이즈스쿨',source=es,evidence='공식 엔터프라이즈스쿨 페이지: 7학부/2학과 구성과 각 이름 및 「복수전공」 형태 운영 명시. 사용자 승인 공식 스쿨명 heading. 실재 학부/학과와 제도 연결을 보존하고 주관교수 단과대로 대체하지 않음.',affiliationStatus='officialProgramSystem',officialSystem='복수전공')
degree('sejong',['전자정보통신공학과','데이터사이언스학과','지능기전공학과','인공지능학과'],'인공지능융합대학','sejong-current-register','공식 수강신청 페이지 최종수정2026-01-05: 인공지능융합대학(전자정보공학대학, 소프트웨어융합대학 포함)의 전자정보통신공학과/데이터사이언스학과/지능기전공학(부)과/인공지능학과 명시. 현재 소속을 직접 확인한 exact legacy crosswalk.')
degree('sejong',['글로벌조리학과'],'호텔관광대학','sejong-cooking','현재 공식 조리서비스경영학과 교육과정 본문에 호텔관광대학 글로벌조리학과 명시; 2025→2026 학칙 개정신구대비표는 글로벌조리→조리서비스경영 학과명변경 명시. 기존 이름 보존.')
degree('sejong',['환경에너지공간융합학과'],'공과대학','sejong-environment','현재 공식 환경융합공학과 사이트 뉴스 제목 환경에너지공간융합학과 소개글. 현행 공과대학 대학소개·공학교육센터 페이지는 환경융합공학과(환경에너지공간융합학과)를 명시하여 동일 조직 확인.')
for r in assets['tuk']:
 d=norm(r.get('department'))
 if d in ['글로벌경영전공','디지털디자인전공','컴퓨터SW전공','한국어전공']:
  put('tuk',r,group='국제학부',kind='universityDirect',source=receipts['tuk-international'],evidence='공식 국제학부 교육과정 中/韓 병기 표의 네 전공 정확한 목록; 대학 소속 추정 없이 명시된 독립 학부 사용.')
 if d in ['시스템디자인전공','데이터콘텐츠전공']:
  put('tuk',r,group='국제미래공학부',kind='universityDirect',source=receipts['tuk-global'],evidence='공식 국제미래공학부 교육목표 표의 두 전공 정확한 목록. 명시된 학부 조직을 단과대학이라고 주장하지 않음.')
map_names('skku',['휴먼사이언스ㆍ사회융합전공'],'융합전공','skku-current-academic','공식 현재 대학 안내 융합전공 제목 아래 휴먼사이언스ㆍ사회융합전공 정확한 목록. 사회과학대학의 주관 정보로 제도 분류를 대체하지 않음.')
map_names('sogang',['공공인재전공','교육문화전공','디지털인문학전공','융합생명공학전공','빅데이터사이언스전공','스타트업전공','스포츠미디어전공','여성학전공','융합소프트웨어전공','인공지능전공','일본문화전공','정치/경제/철학전공','한국발전과국제개발협력전공','한국사회문화전공','차세대반도체전공','공동체혁신전공','가상융합전공','포용사회전공'],'연계전공','sogang-linked','공식 융합교육원 연계전공제도 설명 및 연계전공 현황표의 정확한 18개 이름. 주전공과 별도로 2~3전공 선택 이수, 일반 학위학과와 구분.')
map_names('uos',['디지털융합영어영문학전공'],'AI융합전공','uos-sw-curriculum','공식 AI·SW융합교육센터 교육과정 표: AI융합전공-통섭전공(복수전공·부전공) 디지털융합영어영문학, 융합전공학부 개설 공통기초4과목과 영어영문학과 참여9과목 구성. 주관 참여학과의 단과대로 대체하지 않음.')
map_names('sch',['글로벌디자인경영SC전공','의약신소재SC전공'],'엔터프라이즈스쿨','sch-sc-2026','2026-10-09 공식 SC전공 복수전공생 모집 공지: 학생기업학부 소속 두 SC전공 각각 설명자료 첨부 제목. 공식 ES 소개는 학생기업학부를 스쿨 구성학부로 명시. 사용자 승인 ES heading, 주관 교수 학과로 치환하지 않음.')
map_names('sch',['의료인공지능전공'],'엔터프라이즈스쿨','sch-major-hwp','2026학년도 제3차 공식 제도안내문 소단위전공 표: 엔터프라이즈스쿨 > 마이크로디그리 > 의료인공지능전공12학점. AI·빅데이터학과는 참여학과이며 소속 단과대 대체 근거 아님.')
for e in entries.values():
 if e['university']=='sch'and e.get('group')=='엔터프라이즈스쿨':
  d=norm(e['department']); systems=['복수전공']
  if d in ['디스플레이전공','AI융합학과']:systems+=['나노디그리','마이크로디그리','복합전공']
  elif d in ['첨단반도체전공','AI후보물질도출전공','바이오신약후보물질도출전공','정제·활성전공','후보물질최적화전공','독성평가전공','효능평가전공','바이오의약품생산공정전공','품질관리전공','디지털육종전공','생물소재전공','스마트팜운영전공','원료생산표준화전공','천연물프로파일링전공','바이오데이터전공','전임상지원전공','그린바이오마케팅전공']:systems+=['마이크로디그리']
  elif d=='의료인공지능전공':systems=['마이크로디그리']
  e['officialSystems']=systems
  e['additionalSourceUrls']=[receipts['sch-major-hwp']['url']]
degree('sch',['글로벌자유전공학과'],'국제대학','sch-international-2026','2026-10-02 공식 국제대학 글로벌자유전공학과 행정조교 채용 공고 제목과 본문 직접 소속 명시. 구 향설나눔대학으로 잘못 분류하지 않음.')
degree('scnu',['일본어일본문화학전공 글로벌중국학전공'],'애니메이션·문화콘텐츠스쿨','scnu-2025-guide','원자료 복합 조회 라벨의 두 구성 전공 일본어일본문화학전공/글로벌중국학전공 모두 공식2025 모집요강 및 현재2026 수업료 표에서 애니메이션·문화콘텐츠스쿨 동일 소속. 두 이름을 단일 새 학위명으로 만들지 않고 복합 sourceLabel 보존.')
degree('uos',['소방방재학과'],'도시과학대학','uos-urban-current','공식 대학 및 대학원 > 대학 > 도시과학대학 학과소개 소방방재학과. 도시과학대학 소개와 학과 소개가 같은 대학 페이지에 명시; 주임교수 소속으로 추정하지 않음.')
# Explicit user choices preserve system categories beside actual regular-degree affiliation.
map_names('sunmoon',['미래자동차융합전공'],'디지털혁신공유대학','sunmoon-futurecar','공식 미래자동차융합전공 페이지 제목 디지털혁신공유대학 및 전공소개. 사용자 승인 표시 제목 디지털혁신공유대학; 모듈과정은 별도 운영 설명.')
for r in assets['skku']:
 if norm(r.get('department')) in ['글로벌융합학부','데이터사이언스융합전공','인공지능융합전공','컬처앤테크놀로지융합전공','자기설계융합전공']:
  put('skku',r,college='소프트웨어융합대학',source=receipts['skku-current-academic'],evidence='2026 대학요람 정규 글로벌융합학부 학위 전공 및 현재 대학안내 융합전공 양쪽 공식 표기. 사용자 승인 양쪽 선택 가능; 실제 단과대 소속 유지하고 공식 제도 그룹 추가.',officialGroups=['융합전공'],additionalSourceUrls=[receipts['skku-guide']['url']])
degree('sch',['글로벌보건학과','글로벌산업공학과','글로벌스포츠경영학과'],'국제대학','sch-law-attachment-2-0','2026.3.1 학칙 신구대비표 개정 전/후 국제대학 4개학과 표 글로벌보건/산업공학 명시; 개정 사유2 국제대학 내 글로벌e스포츠산업학과→글로벌스포츠경영학과 명칭 변경 명시. 2026-10-02 국제대학 글로벌자유전공 채용 공고로 현행 단과대 운영 확인.')
for r in assets['snu']:
 if '교직연합' in (r.get('department')or'') or '교직연합' in (r.get('sourceLabel')or''):
  put('snu',r,group='교직연합전공',source=receipts['snu-teacher'],evidence='공식 교원양성혁신센터 공통안내 사범대학에 통합과학/통합사회 교원자격을 위한 교직 연합전공 설치 명시; 참여 교과 학과의 대학으로 제도 분류를 치환하지 않음.',affiliationStatus='officialProgramSystem')
map_names('skku',['법무정책학연계전공'],'연계전공','skku-foreign-guide','공식 외국인 유학생 대학생활 안내서 연계전공 목록 및 주관부서 표 법무정책학 정확히 명시. 주관 사회과학대학과 추가 전공제도 구분; 과거 조회 이름 보존.')
map_names('suwon',['창업학 융복합전공','시스템반도체융복합전공','클라우드융복합전공'],'융복합전공','suwon-major','2026 공식 전공교육과정에 세 융복합전공이 각각 독립 전공교육과정 표로 존재하고, 공식2021 학점배정표는 일반학위 대학 표와 별도로 융복합전공 제도 표 및 복수전공39학점 클라우드 과정 명시. 참여/운영 대학 소속으로 제도 분류를 대체하지 않음.',additionalSourceUrls=[receipts['suwon-credit2021']['url']])
# Inventory all actual supported mapping rows and report unresolved without fabricating completion.
for u,rows in sorted(assets.items()):
 coverage.append({'university':u,'mappingRowsReviewed':len(rows),'newEvidenceRows':sum(k[0]==u for k in entries),'hasOrdinaryEvidence':any(r.get('collegeKnown')or r.get('college')for r in rows),'status':'source-investigation-in-progress'})
remaining=[]
for u,rows in assets.items():
 for r in rows:
  k=(u,r.get('sourceLabel'),r.get('campus','*'))
  if not r.get('college')and not r.get('collegeKnown')and k not in entries:
   remaining.append({'university':u,'department':r.get('department'),'sourceLabel':r.get('sourceLabel'),'campus':r.get('campus','*'),'checkedSources':[r.get('sourceUrl')],'reason':'공식 전공제도/학위조직 후속 원자료 대조 진행 중; 명칭만으로 학부/단과대 또는 전공제도 분류를 만들지 않음.','researchComplete':False})
(P/'program-groups-c.json').write_text(json.dumps({'final':False,'entries':list(entries.values()),'unresolved':remaining,'coverage':coverage,'rules':'official system first, retain ordinary degree hierarchy; no governing professor/department substitution'},ensure_ascii=False,indent=2)+'\n')
print('entries',len(entries),'remaining',len(remaining));print([(u,sum(x['university']==u for x in remaining))for u in assets if any(x['university']==u for x in remaining)])
