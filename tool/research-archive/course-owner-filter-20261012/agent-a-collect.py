import json,pathlib,re,urllib.request,concurrent.futures
from lxml import html
R=pathlib.Path('.'); O=R/'work/course-owner-filter-20261012'; S=O/'agent-a-sources'
cat=json.load(open('assets/timetable/catalog.json'));ds=[(p,json.load(open(p))) for p in cat]; ids=sorted({d['universityId'] for p,d in ds})[:33]
units={u:sorted({v for p,d in ds if d['universityId']==u for c in d['courses'] for v in c.get('departments',[])}) for u in ids}
urls={'ajou':'https://www.ajou.ac.kr/kr/index.do','baekseok':'https://www.bu.ac.kr/sites/web/intro.do','catholic':'https://www.catholic.ac.kr','changwon':'https://www.changwon.ac.kr','daegu':'https://www.daegu.ac.kr','dongguk':'https://www.dongguk.edu','ewha':'https://www.ewha.ac.kr/ewha/index.do','gachon':'https://www.gachon.ac.kr/kor/index.do','hanbat':'https://www.hanbat.ac.kr','hansei':'https://www.hansei.ac.kr','hansung':'https://www.hansung.ac.kr','hanyang':'https://www.hanyang.ac.kr','hknu':'https://www.hknu.ac.kr','hongik':'https://www.hongik.ac.kr','hoseo':'https://www.hoseo.ac.kr','chosun':'https://www.chosun.ac.kr','gknu':'https://www.gknu.ac.kr/main/html.do?menu_idx=687'}
def fetch(t):
 u,url=t;p=S/(u+'-official-home.html')
 try:
  q=urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=25);b=q.read();cs=q.headers.get_content_charset() or 'utf-8';txt=b.decode(cs,errors='replace');p.write_text(txt);return u,url,str(p),txt,None
 except Exception as e:return u,url,None,None,str(e)
fetches=list(concurrent.futures.ThreadPoolExecutor(max_workers=8).map(fetch,urls.items()));json.dump([{ 'university':u,'url':url,'file':p,'error':err} for u,url,p,t,err in fetches],open(S/'fetch-index.json','w'),ensure_ascii=False,indent=2)
mappings=[];owners=[];gaps=[]
def add(u,cam,label,col,dep,url,file,ev,off=False):
 if label not in units[u]:return
 v={'university':u,'campus':cam,'sourceLabel':label,'college':col,'department':dep,'sourceUrl':url,'sourceFile':file,'evidence':ev,'isOfferingUnit':off}
 if v not in mappings:mappings.append(v)
# Retained CAU public row opening identity, independently of query filters.
known={c['sourceId']:c for p,d in ds if d['universityId']=='cau' for c in d['courses']}
for p in pathlib.Path('work/university-expansion/cau-2026-2').glob('courses-*.json'):
 for r in json.load(open(p)).get('selectSust',[]):
  cam={'1':'seoul','2':'davinci'}.get(r.get('campcd'));cid=f"cau/{cam}/2026/2/{r.get('sust')}/{r.get('sbjtno')}/{r.get('clssno')}"
  if cid not in known or not r.get('colgnm'):continue
  col=r['colgnm'];dep=r.get('sustnm') or None;lab=dep or col;url='https://mportal.cau.ac.kr/std/usk/sUskSif001/search.do';ev='Returned row colgnm and sustnm/sust explicitly identify opening unit, distinct from query college/department.'
  add('cau',cam,lab,col,dep,url,str(p),ev,True)
  o={'sourceId':cid,'college':col,'department':dep,'sourceLabel':lab,'sourceUrl':url,'sourceFile':str(p),'evidence':ev}
  if not any(x['sourceId']==cid for x in owners):owners.append(o)
# GNU source spreadsheet has college and department fields; joins only exact code+section+campus+label.
u='gnu';p='work/university-research/catalogs/gnu-public-course-rows.json';rr=json.load(open(p));camp={'가좌캠퍼스':'gajwa','칠암캠퍼스':'chilam','통영캠퍼스':'tongyeong','내동캠퍼스':'naedong','창원캠퍼스':'changwon','함안캠퍼스':'haman'}
for ap,d in ds:
 if d['universityId']!=u:continue
 for c in d['courses']:
  matches=[r for r in rr if str(r.get('code'))==c['courseCode'] and str(r.get('section'))==c['section'] and camp.get(r.get('campus'))==d['campus']]
  org={(r.get('college'),r.get('department')) for r in matches if r.get('college') and r.get('department') in c.get('departments',[])}
  for col,dep in org:add(u,d['campus'],dep,col,dep,d['sourceUrl'],p,'Official source college/department columns in same printed course row; source curriculum/organizer semantics need header confirmation.',False)
# Hoseo same native spreadsheet row college+department. No course owner until source header distinction verified.
u='hoseo';p='work/university-research/catalog-s/hoseo-current-actual-rows.json';url=next(d['sourceUrl'] for ap,d in ds if d['universityId']==u)
for r in json.load(open(p)):
 v=r['values']
 if v[0] and v[1]:add(u,'*',v[1],v[0],v[1],url,p,f"Official 개설현황 spreadsheet retained row {r['sourceRow']} sheet {r['sourceSheet']}: separate college and department columns.",False)
# Exact explicitly published college-prefixed labels: hierarchy only, no organizer assertion.
for ap,d in ds:
 u=d['universityId']
 if u not in ids:continue
 for label in units[u]:
  m=re.match(r'^(.+?대학)(?:\s*/\s*|\s+)(.+)$',label)
  if m and m[1] not in ['대학','공유대학']:add(u,d['campus'],label,m[1],m[2],d['sourceUrl'],ap,'Original published department label explicitly includes college hierarchy. This is affiliation evidence only.',False)
# Official website nested menu: accept only exact current label anchors with an ancestor college anchor.
for u,url,p,txt,err in fetches:
 if txt is None:continue
 try:root=html.fromstring(txt)
 except Exception:continue
 for a in root.xpath('//a'):
  label=' '.join(a.text_content().split())
  if label not in units[u]:continue
  for li in a.iterancestors('li'):
   aa=li.xpath('./a | ./div/a | ./h3/a | ./h4/a')
   names=[' '.join(v.text_content().split()) for v in aa]
   cols=[v for v in names if v.endswith('대학') and v not in ['대학','대학원','사이버대학']]
   if cols:
    col=cols[0];add(u,'*',label,col,None if label==col else label,url,p,'Official page nested navigation places exact department anchor beneath this college anchor.',False);break
# Individually checked official CBNU affiliations.
add('cbnu','main','정치외교학과','사회과학대학','정치외교학과','https://sscollege.chungbuk.ac.kr/department/politics',None,'Official social sciences college department page identifies 정치외교학과 and footer college.',False)
add('cbnu','main','행정학과','사회과학대학','행정학과','https://public.chungbuk.ac.kr/department/social',None,'Official department footer explicitly 사회과학대학 행정학과.',False)
# Export unresolved exact labels; do not invent unknown college.
for u in ids:
 mapped={m['sourceLabel'] for m in mappings if m['university']==u};missing=[x for x in units[u] if x not in mapped]
 if missing:gaps.append({'university':u,'unmappedLabels':missing,'reason':'No exact official college affiliation verified yet; unknown must not be substituted with null or guessed group.'})
out={'mappings':mappings,'courseOwners':owners,'gaps':gaps,'scope':ids}
json.dump(out,open(O/'agent-a-organizations.json','w'),ensure_ascii=False,indent=2)
print('mappings',len(mappings),'owners',len(owners),'gaps',sum(len(g['unmappedLabels']) for g in gaps));print([(u,len([m for m in mappings if m['university']==u])) for u in ids])
