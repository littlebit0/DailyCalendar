import json,pathlib,re,collections,html
from html.parser import HTMLParser
P=pathlib.Path('work/course-owner-filter-20261012');out=json.load(open(P/'agent-c-organizations.json'));M=out['mappings'];seen={(m['university'],m['campus'],m['sourceLabel'])for m in M};G=collections.defaultdict(list)
for f in json.load(open('assets/timetable/catalog.json')):
 d=json.load(open(f));G[d['universityId']].append(d)
norm=lambda s:re.sub(r'\s+','',s)
def add(u,l,col,dep,url,file,ev,campus='*',own=False):
 if (u,campus,l)in seen:return
 seen.add((u,campus,l));M.append(dict(university=u,campus=campus,sourceLabel=l,college=col,department=dep,sourceUrl=url,sourceFile=file,evidence=ev,isOfferingUnit=own))
class Node:
 def __init__(self,tag='',attrs={}):self.tag=tag;self.attrs=attrs;self.ch=[]
 def text(self):return ''.join(x if isinstance(x,str)else x.text() for x in self.ch if isinstance(x,str)or x.tag not in ['script','style'])
 def descendants(self):
  for x in self.ch:
   if not isinstance(x,str):yield x;yield from x.descendants()
class Tree(HTMLParser):
 def __init__(self):super().__init__();self.root=Node();self.stack=[self.root]
 def handle_starttag(self,t,a):
  n=Node(t,dict(a));self.stack[-1].ch.append(n)
  if t not in ['br','hr','img','input','meta','link','source','wbr']:self.stack.append(n)
 def handle_endtag(self,t):
  for i in range(len(self.stack)-1,0,-1):
   if self.stack[i].tag==t:self.stack=self.stack[:i];break
 def handle_data(self,d):self.stack[-1].ch.append(d)
receipts=json.load(open(P/'c-sources/home-receipts.json'))+json.load(open(P/'c-sources/college-receipts.json'))+json.load(open(P/'c-sources/more-receipts.json'));proof=[]
for r in receipts:
 u=r['university']
 if 'file'not in r or u not in G:continue
 p=Tree();p.feed(pathlib.Path(r['file']).read_text());hier=collections.defaultdict(set)
 for n in p.root.descendants():
  if n.tag not in ['li','div']:continue
  direct=[x for x in n.ch if not isinstance(x,str)and x.tag in ['a','span','h3','h4','button','p']]
  for a in direct:
   col=a.text().strip()
   if not re.fullmatch(r'[가-힣A-Za-z·ㆍ&()\- ]{1,35}대학',col):continue
   for sub in n.descendants():
    if sub.tag=='a' and sub is not a:
     dep=sub.text().strip()
     if re.search(r'(?:학과|학부|전공|과)$',dep)and len(dep)<65:hier[norm(dep)].add(col)
 matched=0
 for d in G[u]:
  for l in {l for c in d['courses']for l in c.get('departments',[])}:
   cs=hier.get(norm(l),set())
   if len(cs)==1:
    add(u,l,next(iter(cs)),l,r['sourceUrl'],r['file'],'Official current homepage navigation tree: named college li contains exact department anchor. Affiliation only; raw offering owner not inferred.');matched+=1
 proof.append((u,matched,len(hier)))
# Seoultech retains explicit native dashed college group headings.
f='work/university-research/catalog-h/seoultech-departments.json';hier={};col=None
for r in json.load(open(f))['ds_less']:
 l=r['ORGN_NM'];h=re.fullmatch(r'-+(.+?)-+',l)
 if h:col=h[1] if h[1].endswith('대학') else None
 elif col:hier[l]=col
for d in G['seoultech']:
 for l in {l for c in d['courses']for l in c.get('departments',[])}:
  if l in hier:add('seoultech',l,hier[l],l,d['sourceUrl'],f,'Native ORGN_NM list explicit dashed college heading groups; exact department label within group. Offering field proof separate.')
# SMU preserves explicit source college prefix in curriculum PDF labels.
body=pathlib.Path('work/course-owner-filter-20261012/c-sources/smu.html').read_text();colnames=re.findall(r'<h4 class="h4-tit"[^>]*>([^<]+대학)</h4>',body)
for d in G['smu']:
 if d['campus']!='seoul':continue
 for l in {l for c in d['courses']for l in c.get('departments',[])}:
  for col in colnames:
   if l.startswith(col):add('smu',l,col,l[len(col):].strip() or None,'https://www.smu.ac.kr/ko/edu/seoul001.do','work/course-owner-filter-20261012/c-sources/smu.html','Source curriculum PDF department header encodes full college+department; college independently confirmed by official Seoul education page. Curriculum association only.',campus='seoul');break
for g in out['gaps']:
 u=g['university'];labels={l for d in G[u]for c in d['courses']for l in c.get('departments',[])};mapped={r['sourceLabel']for r in M if r['university']==u};g['unmappedLabels']=sorted(labels-mapped);g['mappedLabels']=len(mapped)
P.joinpath('agent-c-organizations.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(proof);print([(g['university'],g['mappedLabels'],g['labelCount'])for g in out['gaps']])
