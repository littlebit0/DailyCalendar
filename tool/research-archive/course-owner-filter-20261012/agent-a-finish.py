import json,re,pathlib
from lxml import html
import openpyxl
O=pathlib.Path('work/course-owner-filter-20261012');S=O/'agent-a-sources';out=json.load(open(O/'agent-a-organizations.json'));maps=out['mappings'];ds=[json.load(open(p)) for p in json.load(open('assets/timetable/catalog.json'))];units={u:sorted({v for d in ds if d['universityId']==u for c in d['courses'] for v in c.get('departments',[])}) for u in out['scope']}
def norm(t):return re.sub(r'\s+','',t).replace('ㆍ','·').replace('・','·')
def add(u,cam,lab,col,dep,url,file,ev):
 if lab in units[u]:maps.append(dict(university=u,campus=cam,sourceLabel=lab,college=col,department=dep,sourceUrl=url,sourceFile=str(file) if file else None,evidence=ev,isOfferingUnit=False))
for key in ['mappings','courseOwners']:
 for m in out[key]:
  if m.get('college')=='대학(전체)':m['college']=None;m['collegeKnown']=False;m['collegeOnlyEligible']=False;m['evidence']+=' 대학(전체) is a generic query/source category, not a particular college; preserve department only.'
p=S/'hongik-colleges.html';r=html.fromstring(p.read_text());url='https://www.hongik.ac.kr/kr/education/intro-university.do'
for n in r.xpath('//div[@class="b-uni-box"]'):
 titles=n.xpath('./div[@class="b-title-box"]/div[@class="title-box"]/a');camp=n.xpath('./div[@class="b-title-box"]/div[@class="campus-box"]')
 if not titles:continue
 col=titles[0].text_content().strip();cam={'서울':'seoul','세종':'sejong'}.get(camp[0].text_content().strip() if camp else '', '*')
 if not col.endswith('대학'):continue
 for a in n.xpath('.//div[@class="b-dept-wrap"]//a[contains(@href,"deptCd=")]'):
  dep=a.text_content().strip()
  for lab in units['hongik']:
   if norm(lab)==norm(dep):add('hongik',cam,lab,col,dep,url,p,'Official undergraduate college section and exact department/major title; only punctuation/whitespace normalized.')
p=S/'dongguk-colleges.html';r=html.fromstring(p.read_text());url='https://www.dongguk.edu/page/853'
for n in r.xpath('//div[@class="item"][h3]'):
 col=n.xpath('./h3')[0].text_content().replace('홈페이지 바로가기','').strip()
 if not col.endswith('대학'):continue
 for a in n.xpath('.//ul[contains(@class,"univ_list")]//a/span[1]'):
  dep=a.text_content().strip()
  for lab in units['dongguk']:
   if norm(lab)==norm(dep):add('dongguk','seoul',lab,col,dep,url,p,'Official Seoul undergraduate college section lists this exact department.')
for p in S.glob('catholic-college-*.html'):
 r=html.fromstring(p.read_text());idx=p.stem.rsplit('-',1)[1];url='https://www.catholic.ac.kr/ko/academics/edu_undergraduate'+idx+'.do'
 for n in r.xpath('//div[@class="depart"]'):
  heads=n.xpath('./p');
  if not heads:continue
  group=heads[0].text_content().strip();col=group if group.endswith('대학') else None
  if col is None and group not in ['글로벌경영학부']:continue
  for a in n.xpath('.//span[@class="mj-name"]'):
   dep=a.text_content().strip()
   for lab in units['catholic']:
    if norm(lab)==norm(dep):add('catholic','*',lab,col,dep,url,p,'Official academic overview exact organizational section '+group+' and exact department; separate independent faculty section has no college label.')
url='https://law.dgist.ac.kr/jsp/lkms3/jsp/_regulation/regulationView2.jsp?Obookid=10000208'
for lab in ['기초학부','반도체공학과']:add('dgist','*',lab,'융복합대학',lab,url,None,'Official 사무분장요령 제20조 (2026-08-07) explicitly states 융복합대학의 기초학부, 교양학부, 반도체공학과.')
url='https://hansei.ac.kr/'
known='IT학부 간호학과 경영학전공 경찰행정학전공 공연예술전공 관광경영학전공 디자인학부 미디어커뮤니케이션전공 사회복지학전공 섬유패션디자인전공 시각정보디자인전공 신학과 실내건축디자인전공 영어전공 융합보안전공 음악전공 자유전공학부 중국어전공 컴퓨터공학전공'.split()
for lab in known:add('hansei','*',lab,None,lab,url,None,'Official 2026 undergraduate overview explicitly enumerates five faculties and sixteen departments/majors with no college layer; exact unit listed.')
url='https://hknu.ac.kr/hkce/index.do'
for cam in ['anseong','pyeongtaek']:
 p=pathlib.Path('work/university-research/catalog-n/hknu-2026-2-'+cam+'.xlsx')
 if not p.exists():continue
 wb=openpyxl.load_workbook(p,read_only=True,data_only=True)
 published={str(v).strip() for sh in wb for row in sh.iter_rows(values_only=True) for v in row[:2] if v}
 for lab in units['hknu']:
  if lab in published:add('hknu',cam,lab,None,lab,url,p,'Exact 2026-2 published opening faculty/major column; official university announcement states college system begins March 2027, current 2026 faculty system has no college layer.')
url='https://www.gachon.ac.kr/jajeon/10108/subview.do'
groups={'경영대학':'경영학과 회계세무학과 관광경영학과 의료산업경영학과','사회과학대학':'미디어커뮤니케이션학과 경제학과 응용통계학과 사회복지학과 심리학과 패션산업학과','AI인문대학':'한국어문학과 영미어문학과 중국어문학과 일본어문학과 유럽어문학과','법과대학':'법학과 경찰행정학과 행정학과','공과대학':'도시계획·조경학부 도시계획학전공 조경학전공 건축학부 실내건축학전공 건축학전공 건축공학과 화공생명배터리공학부 화공생명공학전공 배터리공학전공 기계공학부 기계공학전공 산업공학전공 설비·소방공학전공 건설환경공학과 신소재공학과','바이오나노대학':'바이오나노학과 식품생명공학과 식품영양학과 생명과학과 반도체물리학과 화학과','반도체대학':'전자공학과 반도체공학과 시스템반도체학과','IT융합대학':'인공지능학과 컴퓨터공학과 전기공학과 의공학과','예술·체육대학':'운동재활학과'}
for lab in units['gachon']:
 for part in lab.split('/'):
  base=re.sub(r'[1-4]$','',part.strip())
  for col,deps in groups.items():
   for dep in deps.split():
    if norm(base)==norm(dep):add('gachon','*',lab,col,dep,url,None,'Official 자유전공학과 전공선택학과 table explicitly publishes college and department/major; source query association composite split at / and trailing year marker removed only.')
ded={}
for m in maps:ded.setdefault((m['university'],m['campus'],m['sourceLabel'],m['college'],m['department'],m.get('isOfferingUnit',False)),m)
out['mappings']=list(ded.values());out['gaps']=[]
for u in out['scope']:
 have={m['sourceLabel'] for m in out['mappings'] if m['university']==u};mis=[x for x in units[u] if x not in have]
 if mis:out['gaps'].append(dict(university=u,unmappedLabels=mis,reason='Exact current college affiliation not yet verified. Cohort/year/eligible labels, administrative offices and interdisciplinary course categories must not be converted into real departments without official crosswalk.'))
 if not units[u]:out['gaps'].append(dict(university=u,unmappedLabels=[],reason='Current published courses contain no departments. Organization overview alone cannot establish course opening or queried department association.',courseCount=sum(len(d['courses']) for d in ds if d['universityId']==u)))
out['gaps'].append(dict(university='cau',unmappedLabels=['대학(전체)'],reason='381 source opening rows use generic 대학(전체), not a specific college. Existing department preserved, college unknown/null and college-only eligibility disabled.'))
json.dump(out,open(O/'agent-a-organizations.json','w'),ensure_ascii=False,indent=2)
print(len(out['mappings']),len(out['courseOwners']),sum(len(x['unmappedLabels']) for x in out['gaps']))
