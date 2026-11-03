import concurrent.futures, hashlib, json, pathlib, urllib.request
from html.parser import HTMLParser
P=pathlib.Path('work/all-university-completion-20261012/root-sources')
sources={
 'changwon-current-colleges':'https://www.changwon.ac.kr/portal/cm/cntnts/cntntsView.do?cntntsId=7049&mi=13529',
 'catholic-current-colleges':'https://www.catholic.ac.kr/ko/academics/college.do',
 'gachon-2013-statistics':'https://www.gachon.ac.kr/bbs/kor/488/310/download.do',
 'gachon-current-ai-sw':'https://sw.gachon.ac.kr/cms/?p=14',
 'daegu-major-systems':'https://www1.daegu.ac.kr/page/130',
}
class Text(HTMLParser):
 def __init__(self):super().__init__();self.parts=[]
 def handle_data(self,s):
  if s.strip():self.parts.append(s.strip())
def fetch(item):
 name,url=item
 try:
  with urllib.request.urlopen(url,timeout=35) as r:data=r.read();ct=r.headers.get('Content-Type','');final=r.url
  ext='.pdf' if data.startswith(b'%PDF') else '.html'
  path=P/(name+ext);path.write_bytes(data)
  if ext=='.html':
   p=Text();p.feed(data.decode('utf-8',errors='replace'));(P/(name+'.txt')).write_text('\n'.join(p.parts))
  return {'id':name,'url':url,'finalUrl':final,'file':str(path),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'contentType':ct}
 except Exception as e:return {'id':name,'url':url,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:out=list(pool.map(fetch,sources.items()))
(P/'receipts-fourth.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(out,ensure_ascii=False))
