import urllib.request,urllib.error,json,hashlib,concurrent.futures
from pathlib import Path
from lxml import html
p=Path(__file__).parent/'a-sources'
sources={'ginue-deepen': 'https://www.ginue.ac.kr/kor/CMS/Contents/Contents.do?mCode=MN075', 'gjue-deepen': 'https://www.gjue.ac.kr/kor/contents/44', 'eulji-multi': 'https://www.eulji.ac.kr/?menuno=3131', 'eulji-convergence': 'https://www.eulji.ac.kr/?menuno=7054', 'cbnu-curriculum': 'https://www.cbnu.ac.kr/www/contents.do?key=457', 'hansei-main': 'https://www.hansei.ac.kr/'}
def one(k,u):
 r={'key':k,'url':u}
 try:
  with urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=35) as res:b=res.read();r['status']=res.status
 except urllib.error.HTTPError as e:b=e.read();r['status']=e.code
 except Exception as e:r['error']=str(e);return r
 f=p/(k+'.html');f.write_bytes(b);r.update(path=str(f),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
 try:
  d=html.fromstring(b);txt='\n'.join(x.strip() for x in d.text_content().splitlines() if x.strip());(p/(k+'.txt')).write_text(txt)
  links=[{'label':x.text_content().strip(),'url':urllib.parse.urljoin(u,x.get('href'))} for x in d.xpath('//a[@href]') if any(s in x.text_content() for s in ['전공','심화','교육과정','학과','PDF','부전공','학부','융합'])];(p/(k+'-links.json')).write_text(json.dumps(links,ensure_ascii=False,indent=2))
 except Exception as e:r['parseError']=str(e)
 return r
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:out=list(ex.map(lambda kv:one(*kv),sources.items()))
(p/'receipts-more.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False))
