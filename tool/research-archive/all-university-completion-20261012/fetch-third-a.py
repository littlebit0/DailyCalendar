import urllib.request,urllib.error,json,hashlib,concurrent.futures
from pathlib import Path
from lxml import html
p=Path(__file__).parent/'a-sources'
sources={'dgist-law': 'https://law.dgist.ac.kr/jsp/lkms3/jsp/_regulation/regulationView2.jsp?Obookid=10000600', 'hansei-2025-systems': 'https://graduate.hansei.ac.kr/bbs/vision/133/26441/artclView.do?layout=unknown', 'cbnu-law.pdf': 'https://graduate.cbnu.ac.kr/upload_file/bbs/00000004/2026/1777523280-1300-0.pdf'}
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
(p/'receipts-third.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False))
