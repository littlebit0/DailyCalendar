exec(open('work/all-university-completion-20261012/assemble-b.py').read().split('# Import ordinary')[0])
colleges={'liberal-arts':'인문과학대학','social-sciences':'사회과학대학','natural-sciences':'자연과학대학','engineering':'공과대학','music':'음악대학','art-design':'조형예술대학','education':'사범대학','business-administration':'경영대학','convergence':'신산업융합대학','medicine':'의과대학','nursing':'간호대학','pharmacy':'약학대학','scranton':'스크랜튼대학','Al-Intelgence':'인공지능대학','hokma':'호크마교양대학'}
for slug,c in colleges.items():
 r,f,ss=source('ewha-'+slug,'ewha');labels=set()
 for t in ss.find_all('table'):
  if '소속학과'not in (t.get('summary','')+t.get_text(' ',strip=True))and'소속 학과'not in t.get_text(' ',strip=True):continue
  for td in t.find_all(['td','th']):
   x=td.get_text(' ',strip=True)
   if x and len(x)<35:labels.add(x)
 # Explicit clickable roster (not global nav) has popup #view links.
 for anchor in ss.select('a[href="#view"], a[href="#dep-view"]'):labels.add(anchor.get_text(' ',strip=True))
 for m in a['ewha']['mappings']:
  d=m.get('department')or''
  matches=[x for x in labels if d and (norm(d)==norm(x) or (x.endswith('전공')and norm(d)==norm(x[:-2]))or(x.endswith('학과')and norm(d)in[norm(x[:-1]),norm(x[:-2])]))]
  if matches:decide('ewha',m,[],r,f,'공식 '+c+' 페이지 소속 학과/전공 표 및 개별 전공 목록 '+matches[0]+' (원자료 단축명 '+d+')'+'; 기존 응답 GROUP_CD 혼입 교정',c,'ordinaryCollege')
# Explicit published introductions/history provide remaining native and retired aliases.
manual={
 'medicine':['의예과','의학과'],
 'Al-Intelgence':['인공지능데이터사이언스학부','인공지능학과','데이터사이언스학과'],
 'engineering':['휴먼기계바이오공학부'],
}
for slug,ds in manual.items():
 r,f,ss=source('ewha-'+slug,'ewha');text=ss.get_text(' ',strip=True)
 for m in a['ewha']['mappings']:
  d=m.get('department')
  if d in ds and norm(d)in norm(text):decide('ewha',m,[],r,f,'공식 대학 소개/연혁에 '+d+' 구성 또는 명칭개편 명시; 기존 일괄 음악대학 분류 교정',colleges[slug],'ordinaryCollege')
for n,c,ds in [('ewha-sports','신산업융합대학',['글로벌스포츠산업','스포츠과학']),('ewha-pharm-system','약학대학',['미래산업약학']),('ewha-science-ed','사범대학',['물리교육','화학교육','생물교육','지구과학교육']),('ewha-social-ed','사범대학',['사회교육','역사교육','지리교육'])]:
 r,f,ss=source(n,'ewha');text=ss.get_text(' ',strip=True)
 for m in a['ewha']['mappings']:
  if m.get('department')in ds and m['department']in text:decide('ewha',m,[],r,f,'공식 '+c+' 소속 전공 소개/교과목 안내에 '+m['department']+' 명시',c,'ordinaryCollege')
for slug,c in colleges.items():
 r,f,ss=source('ewha-'+slug,'ewha')
 for m in a['ewha']['mappings']:
  if not m.get('department')and m.get('college')==c:decide('ewha',m,[],r,f,'공식 대학 소개 '+c+'; 학과 없는 원자료 단과대 항목',c,'ordinaryCollege')
(O/'ewha-ordinary-b.json').write_text(json.dumps({'entries':[v for v in out.values()if v['university']=='ewha'],'checkedSources':checked.get('ewha',[])},ensure_ascii=False,indent=2))
print('ewha',len([v for v in out.values()if v['university']=='ewha']))
