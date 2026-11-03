exec(open('work/course-owner-filter-20261012/agent_b_tree.py').read().split('out={}')[0])
import urllib.request,urllib.parse,concurrent.futures
items=[]
for u,base in [('hufs','https://www.hufs.ac.kr'),('kmu','https://www.kmu.ac.kr')]:
 parser=Parser((root/(u+'-official-home.html')).read_text())
 seen=set()
 for n in parser.nodes:
  if n.tag!='a':continue
  label=re.sub(r'\s+',' ',n.text()).strip();url=urllib.parse.urljoin(base,n.attrs.get('href',''))
  if label.endswith('대학') and label not in ['대학','대학/대학원'] and (url,label) not in seen and url.startswith(base):items.append((u,label,url));seen.add((url,label))
def fetch(item):
 u,col,url=item
 try:
  s=urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=25).read().decode('utf-8');f=root/(u+'-college-'+re.sub(r'[^a-zA-Z0-9가-힣]','_',col)+'-'+str(items.index(item))+'.html');f.write_text(s);return dict(university=u,college=col,url=url,sourceFile=str(f),length=len(s))
 except Exception as e:return dict(university=u,college=col,url=url,error=str(e))
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 results=[]
 for r in pool.map(fetch,items):results.append(r);print(r['university'],r['college'],r.get('length',r.get('error')),flush=True)
(root/'agent-b-college-receipts.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
