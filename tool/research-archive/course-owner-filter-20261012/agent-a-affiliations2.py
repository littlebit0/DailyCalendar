import json,pathlib,re,urllib.request
from lxml import html
O=pathlib.Path('work/course-owner-filter-20261012');S=O/'agent-a-sources';out=json.load(open(O/'agent-a-organizations.json'));maps=out['mappings'];cat=json.load(open('assets/timetable/catalog.json'));ds=[(p,json.load(open(p))) for p in cat];units={u:sorted({v for p,d in ds if d['universityId']==u for c in d['courses'] for v in c.get('departments',[])}) for u in out['scope']}
def add(u,cam,label,col,dep,url,file,ev):
 if label in units[u]:maps.append(dict(university=u,campus=cam,sourceLabel=label,college=col,department=dep,sourceUrl=url,sourceFile=file,evidence=ev,isOfferingUnit=False))
p=S/'hanbat-sitemap.html';r=html.fromstring(p.read_text());url='https://www.hanbat.ac.kr/electro/sitemap.do'
for a in r.xpath('//a'):
 label=' '.join(a.text_content().split())
 if label not in units['hanbat']:continue
 for li in a.iterancestors('li'):
  aa=li.xpath('./a');names=[' '.join(x.text_content().split()) for x in aa]
  cols=[n for n in names if n.endswith('대학') or n=='노마드 칼리지']
  if cols:add('hanbat','daejeon',label,cols[0],None if label==cols[0] else label,url,str(p),'Official whole-university college/department link hierarchy; exact matching published label.');break
p=S/'changwon-guide.html';r=html.fromstring(p.read_text());url='https://www.changwon.ac.kr/portal/cm/cntnts/cntntsView.do?cntntsId=6630&mi=18410';col=None
for table in r.xpath('//table'):
 if 'College of Humanities' not in table.text_content():continue
 for tr in table.xpath('.//tr'):
  cells=tr.xpath('./td');
  if not cells:continue
  name=' '.join(cells[0].text_content().split())
  if name.endswith('대학'):col=name
  if col:
   candidates=[name]
   if name.endswith(' (주/야)'):candidates.append(name[:-6])
   for lab in candidates:add('changwon','*',lab,col,None if lab==col else lab,url,str(p),'Official organization nomenclature table groups subsequent departments under explicit college row.')
# Hansei complete current undergraduate roster explicitly lists five faculties and independent departments.
p=S/'hansei-main.html';r=html.fromstring(p.read_text());text=' '.join(r.text_content().split());url='https://hansei.ac.kr/'
for lab in units['hansei']:
 if lab in text and lab not in ['대학','교양학부','멀티미디어사운드&뮤직']:
  add('hansei','*',lab,None,lab,url,str(p),'Official 2026 academic organization overview enumerates five faculties and sixteen departments/majors with no college layer; exact published unit label.')
# Chosun current 2026 curriculum explicitly locates future faculty under future society convergence college.
url='https://www4.chosun.ac.kr/pdfView/future/114/fileDownload.do'
for lab in units['chosun']:
 if '미래융합학부' in lab:add('chosun','*',lab,'미래사회융합대학',lab,url,None,'Official 2026 course profile title explicitly 미래사회융합대학 미래융합학부. Source label year/track cohort retained; no claim of actual host.')
# Hongik real linked university overview downloaded, retaining college section structure.
url='https://www.hongik.ac.kr/kr/education/intro-university.do'
try:
 q=urllib.request.urlopen(url,timeout=20);s=q.read().decode('utf-8',errors='replace');p=S/'hongik-colleges.html';p.write_text(s);r=html.fromstring(s)
 for a in r.xpath('//a'):
  label=' '.join(a.text_content().split())
  if label not in units['hongik']:continue
  for n in a.iterancestors():
   headings=n.xpath('./h2|./h3|./h4|./h5|./div/h2|./div/h3|./div/h4|./div/h5')
   names=[' '.join(x.text_content().split()) for x in headings];cols=[x for x in names if x.endswith('대학')]
   if len(cols)==1:add('hongik','*',label,cols[0],label,url,str(p),'Official academic overview heading and exact department anchor association.');break
except Exception as e:print('hongik',e)
ded={}
for m in maps:
 key=(m['university'],m['campus'],m['sourceLabel'],m['college'],m['department'],m.get('isOfferingUnit',False));ded.setdefault(key,m)
out['mappings']=list(ded.values());out['gaps']=[]
for u in out['scope']:
 have={m['sourceLabel'] for m in out['mappings'] if m['university']==u};mis=[x for x in units[u] if x not in have]
 if mis:out['gaps'].append(dict(university=u,unmappedLabels=mis,reason='Exact affiliation not verified; many original labels are eligibility/class-cohort associations rather than organizer.'))
json.dump(out,open(O/'agent-a-organizations.json','w'),ensure_ascii=False,indent=2);print(len(out['mappings']),sum(len(x['unmappedLabels']) for x in out['gaps']))
