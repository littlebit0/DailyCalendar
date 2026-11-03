import pathlib,json,urllib.request,urllib.parse,concurrent.futures,hashlib
from lxml import html
D=pathlib.Path(__file__).parent/'kmou-new-department-discovery';D2=D.parent/'kmou-new-department-https-discovery';boards=[]
for p in [D/'main-receipt.json',D2/'main-receipt.json']:
 for r in json.loads(p.read_text()):
  for b in r.get('observedBoards',[]):boards.append((r['label'],b['url']))
boards=list(dict.fromkeys(boards));B=D.parent/'kmou-observed-boards';B.mkdir(exist_ok=True)
def f(kv):
 label,url=kv;key=urllib.parse.urlparse(url).path.split('/')[1]
 try:
  with urllib.request.urlopen(url,timeout=18) as r:b=r.read();status=r.status
  (B/(key+'.html')).write_bytes(b);n=html.fromstring(b,parser=html.HTMLParser(encoding='utf-8'));leads=[]
  for a in n.xpath('//a[@href]'):
   text=' '.join(a.text_content().split());href=urllib.parse.urljoin(url,a.get('href'))
   if '시간표' in text or ('2026' in text and ('수강' in text or '개설' in text)):leads.append({'label':text,'url':href})
  return {'label':label,'url':url,'status':status,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'leads':leads}
 except Exception as e:return {'label':label,'url':url,'error':str(e)}
r=list(concurrent.futures.ThreadPoolExecutor(8).map(f,boards));(B/'receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2));print(json.dumps(r,ensure_ascii=False,indent=2))
