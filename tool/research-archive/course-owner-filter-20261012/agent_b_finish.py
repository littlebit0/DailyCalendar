# coding: utf-8
from pathlib import Path
p=Path('work/course-owner-filter-20261012/agent_b_augment.py')
s=p.read_text()
block=r'''
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
 for a in re.findall(r'<a\b[^>]*>(.*?)</a>',markup[start:end],re.S):
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
'''
if '# Explicit official structures without a college tier.' not in s:s=s.replace('\ngaps=[]\n','\n'+block+'\ngaps=[]\n');p.write_text(s)
