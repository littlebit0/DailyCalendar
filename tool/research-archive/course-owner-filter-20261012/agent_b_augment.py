exec(open('work/course-owner-filter-20261012/agent_b_extract.py').read().split('gaps=[]')[0])
exec(open('work/course-owner-filter-20261012/agent_b_tree.py').read().split('out={}')[0])
from html import unescape
# Official nested college menu relationships.
menus=json.load(open(ROOT/'agent-b-menu-hierarchy.json'))
for u in ['kmou','knue']:
 byname=collections.defaultdict(set)
 for r in menus[u]:byname[r['department']].add(r['college'])
 for f,d in selected[u]:
  for label in {v for c in d['courses'] for v in c.get('departments',[])}:
   cols=byname.get(label,set())
   if len(cols)==1:add(u,d['campus'],label,next(iter(cols)),label,next(r['url'] for r in json.load(open(ROOT/'agent-b-official-page-receipts.json')) if r['university']==u),str(ROOT/(u+'-official-home.html')),'Official university navigation nests this exact department link under its college.')
# HUFS official college page exact department headings and current KMU organization table cells.
for r in json.load(open(ROOT/'agent-b-college-receipts.json')):
 if 'sourceFile' not in r:continue
 u=r['university'];s=re.sub('<!--.*?-->','',Path(r['sourceFile']).read_text(),flags=re.S)
 if u=='hufs':
  names=[unescape(re.sub('<[^>]*>','',x)).strip() for x in re.findall(r'<h[234][^>]*class="[^"]*dp-title[^"]*"[^>]*>(.*?)</h[234]>',s,re.S)]
  # Public page headings are affiliations; campus ambiguity cannot infer source association.
 elif u=='kmu':
  names=[unescape(re.sub('<[^>]*>','',x)).strip() for x in re.findall(r'<td[^>]*>(.*?)</td>',s,re.S)]
 for f,d in selected[u]:
  if u=='hufs':
   globalUrls={'15543','11240','11241','11242','11243','11244','11245','11246','11247','11249'}
   pageCampus='global' if any('/'+n+'/' in r['url'] for n in globalUrls) else 'seoul'
   if d['campus']!=pageCampus:continue
  labels={v for c in d['courses'] for v in c.get('departments',[])}
  for label in labels:
   if label in names:add(u,d['campus'],label,r['college'],label,r['url'],r['sourceFile'],'Official college overview explicitly lists exact department in '+('department heading' if u=='hufs' else 'department table cell')+'. Affiliation only.')
# Additional authoritative college overview headings.
for u,url in [('kongju','https://homepage.kongju.ac.kr/M00056/4931/subview.do'),('mokpo','https://www.mokpo.ac.kr/www/1456/subview.do')]:
 p=ROOT/(u+'-official-organization.html');s=re.sub('<!--.*?-->','',p.read_text(),flags=re.S);heads=list(re.finditer(r'<h[234][^>]*>(.*?)</h[234]>',s,re.S));sections=[]
 for i,m in enumerate(heads):
  title=unescape(re.sub('<[^>]+>','',m[1])).strip();colmatch=re.match(r'^([^\s]+대학)',title);end=heads[i+1].start() if i+1<len(heads) else len(s)
  if colmatch:sections.append((colmatch[1],unescape(re.sub('<[^>]+>',' ',s[m.end():end]))))
 for f,d in selected[u]:
  for label in {v for c in d['courses'] for v in c.get('departments',[])}:
   cols={col for col,txt in sections if label in txt}
   if len(cols)==1:add(u,d['campus'],label,next(iter(cols)),label,url,str(p),'Current official college overview lists exact department name beneath college heading. Historical aliases not invented.')
# Individually confirmed narrow institutions/department pages.
manual=[('iccu','간호학과','간호대학','간호학과','https://nursing.iccu.ac.kr/intro/introduce.php','Official nursing college introduction explicitly identifies nursing department.'),('iccu','ELPIS교양대학','ELPIS교양대학',None,'https://www.iccu.ac.kr/','Exact college name retained in official public timetable; direct unit, not a child department.'),('kaist','Department of AI Computing','College of AI','Department of AI Computing','https://www.kaist.ac.kr/en/html/edu/03.html','Current official academics page College of AI lists Department of AI Computing.'),('kaist','수리과학과','자연과학대학','수리과학과','https://www.kaist.ac.kr/en/html/edu/03.html','Official academics College of Natural Sciences lists Mathematical Sciences; Korean department label is retained official timetable wording.'),('kaist','전산학부','공과대학','전산학부','https://www.kaist.ac.kr/en/html/edu/03.html','Official College of Engineering lists School of Computing; retained timetable Korean department label.'),('kaist','전기및전자공학부','공과대학','전기및전자공학부','https://www.kaist.ac.kr/en/html/edu/03.html','Official College of Engineering lists Electrical Engineering; retained timetable Korean department label.'),('kaist','바이오및뇌공학과','공과대학','바이오및뇌공학과','https://www.kaist.ac.kr/en/html/edu/03.html','Official College of Engineering lists Bio and Brain Engineering; retained timetable Korean department label.'),('kaist','원자력및양자공학과','공과대학','원자력및양자공학과','https://www.kaist.ac.kr/en/html/edu/03.html','Official College of Engineering lists Nuclear and Quantum Engineering; retained timetable Korean department label.')]
mmunaval=['항해학부','해상운송학부','항해정보시스템학부','기관시스템공학부','해양경찰학부','해양메카트로닉스학부','해군사관학부']
for label in mmunaval:manual.append(('mmu',label,'해사대학',label,'https://mobility.mmu.ac.kr/admission/contents/naval','Official university admission college overview lists this exact department under 해사대학.'))
for label in ['컴퓨터공학과','조선해양공학과','환경·생명공학과','해양건설공학과','해양스포츠학과']:manual.append(('mmu',label,'해양공과대학',label,'https://mobility.mmu.ac.kr/upload/pdf/873/79623a54d0bd4761b2a1c7f25af7e9b7.pdf','Official 2026 transfer admission table explicitly places department under 해양공과대학.'))
for label in ['의학과 1학년','의학과 2학년','의학과 3학년','의학과 4학년']:manual.append(('jbnu',label,'의과대학','의학과','https://med.jbnu.ac.kr/','Published medical-school grade timetable source identifies 의학과; source grade labels remain original association keys.'))
for u,label,col,dep,url,why in manual:
 for f,d in selected[u]:
  if any(label in c.get('departments',[]) for c in d['courses']):add(u,d['campus'],label,col,dep,url,f,why)
# Campus-marked college labels remain original official identifiers.
for u,fs in selected.items():
 for f,d in fs:
  for label in {v for c in d['courses'] for v in c.get('departments',[])}:
   m=re.match(r'^([^/]+대학(?:\[[^]]+\]|\([^)]*\))?)\s*/\s*(.+)$',label)
   if m:add(u,d['campus'],label,m[1].strip(),m[2].strip(),d['sourceUrl'],f,'Exact official college/department query label includes explicit campus qualifier. Affiliation only.')
# Current official grouped option and description-list hierarchy.
for u,file,url in [('nsu','nsu-official-overview.html','https://www.nsu.ac.kr/?m1=page%25&menu_id=33'),('inje','inje-official-home.html','https://www.inje.ac.kr/kor/')]:
 p=ROOT/file;parser=Parser(p.read_text());byname={}
 for n in parser.nodes:
  if u=='nsu' and n.tag=='option' and n.parent.tag=='optgroup':
   col=n.parent.attrs.get('label','');name=n.text().strip()
   if col.endswith('대학'):byname[name]=col
  if u=='inje' and n.tag=='dl':
   dt=next((c for c in n.children if c.tag=='dt'),None);dd=next((c for c in n.children if c.tag=='dd'),None)
   if dt and dd:
    col=re.sub(r'\s+',' ',dt.text()).strip()
    if col.endswith('대학'):
     for a in dd.anchors():byname[re.sub(r'\s+',' ',a.text()).strip()]=col
 for f,d in selected[u]:
  for label in {v for c in d['courses'] for v in c.get('departments',[])}:
   dep=re.sub(r' \d학년$','',label)
   if dep in byname:add(u,d['campus'],label,byname[dep],dep,url,str(p),'Exact official department option is grouped under named college; original grade context retained as sourceLabel.')
# Korea official captions explicitly identify the college of each department table.
u='korea';p=ROOT/'korea-official-overview.html';markup=p.read_text()
for table in re.findall(r'<table[^>]*>(.*?)</table>',markup,re.S):
 cap=re.search(r'<caption[^>]*>(.*?)</caption>',table,re.S)
 if not cap:continue
 caption=unescape(re.sub('<[^>]*>','',cap[1])).strip();m=re.match(r'^([^\s]+대학)에 속한',caption)
 if not m:continue
 col=m[1];cells=[unescape(re.sub('<[^>]*>','',v)).strip() for v in re.findall(r'<(?:td|th)[^>]*>(.*?)</(?:td|th)>',table,re.S)]
 for f,d in selected[u]:
  if d['campus']!='seoul':continue
  for label in {v for c in d['courses'] for v in c.get('departments',[])}:
   if label in cells:add(u,'seoul',label,col,label,'https://www.korea.ac.kr/ko/418/subview.do',str(p),'Official university overview table caption explicitly says departments belonging to this college; exact table cell match.')
# Source category prefixes retain their known exact academic department affiliation.
for u,fs in selected.items():
 existing=list(mappings.values())
 for f,d in fs:
  for label in {v for c in d['courses'] for v in c.get('departments',[])}:
   dep=re.sub(r'^대학기초 · ','',label)
   matches=[m for m in existing if m['university']==u and m['campus']==d['campus'] and m['sourceLabel']==dep]
   if dep!=label and len(matches)==1:
    m=matches[0];add(u,d['campus'],label,m['college'],m['department'],m['sourceUrl'],m['sourceFile'],'Official source query category prefix 대학기초 retains exact academic unit '+dep+'; affiliation inherited from exact official unit evidence, not a host claim.')


# Explicit official structures without a college tier.
def standalone(u,label,dep,url,file,why):
 for f,d in selected[u]:
  if any(label in c.get('departments',[]) for c in d['courses']):
   mappings[(u,d['campus'],label)]=dict(university=u,campus=d['campus'],sourceLabel=label,college=None,department=dep,sourceUrl=url,sourceFile=file,evidence=why)
for u,fn,url,allowed in [
 ('koreatech','koreatech-official-overview.html','https://www.koreatech.ac.kr/kor/index.jsp',['기계공학부','메카트로닉스공학부','전기ㆍ전자ㆍ통신공학부','컴퓨터공학부','디자인공학과','건축공학과','에너지신소재화학공학부','경영학부','고용서비스정책학과','교양학부','HRD학과','미래융합학부','글로벌인재학부']),
 ('nambu','nambu-official-home.html','https://www.nambu.ac.kr/content/view.do?menuCd=KR002004001',['경찰행정학과','사회복지학과','한국어학과','AI경영학과','유아교육과','초등특수교육과','향장미용학과','호텔조리학과','식품영양학과','간호학과','방사선학과','물리치료학과','응급구조학과','AI전기공학과','스포츠레저학과','자유전공학부'])]:
 for label in allowed:standalone(u,label,label,url,str(ROOT/fn),'Official university academic organization lists this exact faculty/department directly under university (Nambu discipline 계열 are not colleges). No college layer in this published organization; affiliation only.')
# Kangnam current semester official published college / faculty / major table, pages6-7.
u='kangnam';f='work/university-research/expansion17-20261011/c/kangnam-timetable.txt';url=selected[u][0][1]['sourceUrl']
bycollege={'복지융합대학':['사회복지학부','사회복지학부(야)','사회복지학전공','사회서비스학전공','시니어비즈니스학과'],'경영관리대학':['상경학부','상경학부(야)','경영학전공','경영학전공(야)','경제금융학전공','국제무역학전공','법행정세무학부','법행정세무학부(야)','세무학전공','법행정학전공'],'글로벌문화콘텐츠대학':['문화콘텐츠학과','국제지역학과','중국콘텐츠비즈니스학과','기독교커뮤니케이션학과'],'공과대학':['컴퓨터공학부','소프트웨어전공','메타버스게임전공','인공지능융합공학부','데이터사이언스전공','인공지능전공','전자반도체공학부','전자공학전공','반도체공학전공','스마트모빌리티전공','부동산건설학부','부동산학전공','스마트도시공학전공','건축공학전공'],'예체능대학':['디자인학과','체육학과','음악학과'],'사범대학':['교육학과','유아교육과','초등특수교육과','중등특수교육과']}
for af,d in selected[u]:
 for label in {v for c in d['courses'] for v in c.get('departments',[])}:
  # Each component must be exactly evidenced in the same college table; no old-name guesses.
  parts=[x.strip() for x in label.split('/')]
  cols=[col for col,names in bycollege.items() if all(x in names for x in parts)]
  if len(cols)==1:add(u,d['campus'],label,cols[0],label,url,f,'2026-2 official timetable pages6-7 college/faculty/major organization table explicitly names each source-label component. Affiliation only.')
standalone(u,'자유전공학부','자유전공학부',url,f,'2026-2 timetable page6 explicitly places 자유전공학부 under 부총장직속, outside named colleges.')
# KAU official college overview blocks explicitly contain department/program links.
u='kau';f=ROOT/'kau-official-overview.html';markup=f.read_text();bounds=[('공과대학',81959,122348),('AI융합대학',122348,161078),('항공·경영대학',161078,200000)];byname=collections.defaultdict(set)
for col,start,end in bounds:
 for a in re.findall(r'<(?:th|h5)\b[^>]*>(.*?)</(?:th|h5)>',markup[start:end],re.S):
  name=unescape(re.sub('<[^>]+>',' ',a));name=re.sub(r'\s+',' ',name).strip()
  if name:byname[name].add(col)
for af,d in selected[u]:
 for label in {v for c in d['courses'] for v in c.get('departments',[])}:
  parts=[x.strip() for x in label.split('/')];cols=set.intersection(*(byname.get(x,set()) for x in parts))
  if len(cols)==1:add(u,d['campus'],label,next(iter(cols)),label,'https://www.kau.ac.kr/admission/univ.php',str(f),'Official college overview block explicitly names every source-label component as a department/program link. Affiliation only; no owner inference.')
# KMOU current2026 admission table explicitly links both grade-labelled majors.
for af,d in selected['kmou']:
 for label in {v for c in d['courses'] for v in c.get('departments',[])}:
  dep=re.sub(r' \d학년$','',label)
  if dep in ['전기전자공학전공','전자정보통신공학전공']:add('kmou',d['campus'],label,'해양과학기술융합대학',dep,'https://kmou.ac.kr/data/2026_kmou_susi_i.pdf',af,'Official2026 admissions college-contact table lists 전자전기정보공학부 and both exact majors under 해양과학기술융합대학; source grade association preserved.')

# Kumoh official current2026 table explicitly leaves college column blank for these units.
u='kumoh';f=ROOT/'kumoh2026.html';url='https://www.kumoh.ac.kr/sls/sub0302.do'
markup=f.read_text();tab=next(t for t in re.findall(r'<table[^>]*>.*?</table>',markup,re.S) if '기계공학부' in t)
for af,d in selected[u]:
 for label in {v for c in d['courses'] for v in c.get('departments',[])}:
  if label=='첨단방산공학전공':add(u,d['campus'],label,'에디슨칼리지',label,url,str(f),'Official 전공선택범위 table explicitly puts 첨단산업융합학부 major under 에디슨칼리지; 2025 entrant scope explicitly preserved.')
  elif label in ['건축공학전공','건축학전공','토목공학전공','환경공학전공','기계공학부','기계공학전공','기계시스템공학전공','산업·빅데이터공학부','산업공학전공','수리빅데이터전공','고분자공학전공','신소재공학전공','반도체시스템전공','전자시스템전공','소프트웨어전공','인공지능공학전공','컴퓨터공학전공','화학소재공학부','소재디자인공학전공','화학공학전공','화학생명소재전공','경영학과']:
   mappings[(u,d['campus'],label)]=dict(university=u,campus=d['campus'],sourceLabel=label,college=None,department=label,sourceUrl=url,sourceFile=str(f),evidence='Official current2026 전공선택범위 table names exact faculty/major under explicit blank college column (rowspan9), distinct from 에디슨칼리지 row; no future2027 college assignment inferred.')

# Kunsan retained native workbooks preserve explicit college / department / major columns.
u='kunsan';relations=collections.defaultdict(set);rawowners=collections.defaultdict(set);files={}
for num in [3,4,5]:
 f='work/university-research/catalog-m/kunsan-2026-2-attachment-'+str(num)+'-rows.json';sheets=json.load(open(f));sheets={'전체':sheets['전체']} if num==3 else sheets
 for sheet,rows in sheets.items():
  header=next((r for r in rows if any(str(v).replace(' ','')=='학수번호' for v in r)),None)
  if not header:continue
  hs=[re.sub(r'\s+','',str(v or '')) for v in header]
  for row in rows:
   v={k:x for k,x in zip(hs,row) if k};code=str(v.get('학수번호') or '');sec=str(v.get('분반') or '')
   if not re.fullmatch(r'\d{6}',code):continue
   col=str(v.get('대학') or '').strip();dep=str(v.get('전공') or v.get('학과(부)') or v.get('MCD과정') or v.get('MD과정') or v.get('학부') or '').strip()
   if dep=='전공없음':dep=str(v.get('학과(부)') or col).strip()
   if not col or not dep or not(col.endswith('대학') or col.endswith('대학부')):continue
   relations[dep].add((col,None if dep==col else dep));files[dep]=f
   # Main regular majors workbook represents actual opening; alternative curriculum workbook associations do not replace owner.
   if num==3:rawowners[(code,sec)].add((col,None if dep==col else dep,dep,f))
for af,d in selected[u]:
 for c in d['courses']:
  for label in c.get('departments',[]):
   pairs=relations.get(label,set())
   if len(pairs)==1:
    col,dep=next(iter(pairs));add(u,d['campus'],label,col,dep,d['sourceUrl'],files[label],'Official2026-2 native workbook separately supplies 대학 and exact 전공/학과(부)/MCD과정/MD과정. Academic curriculum association retained; administrative/target field excluded.',False)
  pairs=rawowners.get((c['courseCode'],c['section']),set())
  if len(pairs)==1:
   col,dep,label,f=next(iter(pairs));owner(c,col,dep,label,d['sourceUrl'],f,'Exact courseCode+section join with official regular 전공 전체 workbook row 대학/학과(부)/전공. Direct college when 전공없음 and 학과(부)==대학; no 교양 target field inference.')
# Kyonggi retained official current2026 major timetable explicitly uses bracketed academic headings.
u='kyonggi';f='work/university-research/catalog-g/kyonggi-external2026-2/2026-2_전공.txt';heads={x.strip() for x in re.findall(r'\[([^]\n]+)\]교과목명',Path(f).read_text())}
for af,d in selected[u]:
 for label in {v for c in d['courses'] for v in c.get('departments',[])}:
  if (u,d['campus'],label) in mappings or label not in heads:continue
  if label.endswith(('학과','학부','전공')) or label=='자유전공학부(수원)':
   mappings[(u,d['campus'],label)]=dict(university=u,campus=d['campus'],sourceLabel=label,college=None,collegeKnown=False,department=label,sourceUrl=d['sourceUrl'],sourceFile=f,evidence='Exact academic bracket heading in official2026-2 major timetable preserves department/curriculum association. Current college affiliation unconfirmed; official organization request redirect loop, no guessed college.')
# INHA exact official department-query labels, excluding other/admin filters and 융합전공지원실.
u='inha'
for af,d in selected[u]:
 for label in {v for c in d['courses'] for v in c.get('departments',[])}:
  if (u,d['campus'],label) in mappings:continue
  first=label.split(' / ')[0]
  if ' / ' in label and not first.endswith('지원실') and ('학과' in first or '학부' in first):
   mappings[(u,d['campus'],label)]=dict(university=u,campus=d['campus'],sourceLabel=label,college=None,collegeKnown=False,department=label,sourceUrl=d['sourceUrl'],sourceFile='tool/timetable/import_inha.py',evidence='Public importer preserves official ddlDept department-query label exactly, including faculty/major association; general ddlKita categories excluded. Currentcollege overview request closed connection; college remains unknown.')

# Parent-authorized fallback preserves explicitly named academic units when college remains unconfirmed.
# Only source academic suffixes; years/classes/general/OCR/category labels are not converted.
for u,fs in selected.items():
 if u in ['jnue']:continue
 for af,d in fs:
  for label in {v for c in d['courses'] for v in c.get('departments',[])}:
   key=(u,d['campus'],label)
   if key in mappings:continue
   dep=label
   if dep.startswith(('교양 ·','대학기초 ·')):continue
   dep=re.sub(r'^\[[^]]+\]\[[^]]+\]','',dep)
   dep=re.sub(r' \d학년$','',dep)
   if ' / ' in dep and u!='inha':dep=dep.split(' / ')[-1]
   clean=re.sub(r'\((야|수원|글로벌|2\+4|6년제|조선해양생산트랙)\)$','',dep)
   if clean.endswith(('학과','학부','전공')) and not any(x in clean for x in ['전체','공통','미게시','교육과정','사업단','지원실','교양·기타']):
    mappings[key]=dict(university=u,campus=d['campus'],sourceLabel=label,college=None,collegeKnown=False,department=dep,sourceUrl=d['sourceUrl'],sourceFile=af,evidence='Original public timetable retains an explicit named academic department/faculty/major association in departments. Official organization sources inspected but exact college affiliation remains unconfirmed; preserve association only under collegeKnown=false. No year/general/admin/OCR heading inferred.')
# Konkuk English course listing column explicitly identifies academic departments and direct colleges.
u='konkuk'
for af,d in selected[u]:
 for label in {v for c in d['courses'] for v in c.get('departments',[])}:
  if label in ['COLLEGE OF BUSINESS','SANG-HUH COLLEGE']:add(u,d['campus'],label,label,None,d['sourceUrl'],af,'Official university linked English course listing explicitly names college as source academic unit. Affiliation only; owner not inferred from association.')
  else:mappings[(u,d['campus'],label)]=dict(university=u,campus=d['campus'],sourceLabel=label,college=None,collegeKnown=False,department=label,sourceUrl=d['sourceUrl'],sourceFile=af,evidence='Exact academic department label retained from university public English course listing linked by official student guidebook. Official university organization redirects to SSO; college affiliation unconfirmed, label preserved without inferred college.')

for m in mappings.values():
 m.setdefault('isOfferingUnit',False)
 m.setdefault('collegeKnown',True)

gaps=[]
for u,fs in selected.items():
 for f,d in fs:
  labels=sorted({v for c in d['courses'] for v in c.get('departments',[])})
  unknown=[label for label in labels if (u,d['campus'],label) not in mappings]
  unowned=[c['sourceId'] for c in d['courses'] if c['sourceId'] not in owners]
  gaps.append(dict(university=u,campus=d['campus'],sourceFile=f,unmappedLabels=unknown,unmappedLabelCount=len(unknown),courseOwnerUnverifiedCount=len(unowned),coursesWithoutPublishedAssociation=[c['sourceId'] for c in d['courses'] if not c.get('departments')],reason='Unmapped labels omitted, not guessed. College affiliation insufficient to infer course host. Query/curriculum associations may now be used for department filter, never direct college-host filter.'))
(ROOT/'agent-b-organizations.json').write_text(json.dumps(dict(mappings=list(mappings.values()),courseOwners=list(owners.values()),gaps=gaps,scope=list(selected),completionClaim=False),ensure_ascii=False,indent=2)+'\n')
print('mappings',len(mappings),'owners',len(owners));print(collections.Counter(m['university'] for m in mappings.values()));print({g['university']+':'+g['campus']:g['unmappedLabelCount'] for g in gaps if g['unmappedLabelCount']})
