import pathlib,json,urllib.request,urllib.parse,concurrent.futures,hashlib
from lxml import html
D=pathlib.Path(__file__).parent/'kmou-current-new-notices';D.mkdir(exist_ok=True)
allrows=json.loads((D.parent/'kmou-public-form-search/current-2026-education-leads.json').read_text());rows=[r for r in allrows if any(x in r['url'] for x in ['10377141','10377210','10375600','10377145'])]
def f(row):
 u=row['url'];u=urllib.parse.quote(u,safe=':/?&=%');key=urllib.parse.parse_qs(urllib.parse.urlparse(u).query)['nttSn'][0]
 try:
  try:
   with urllib.request.urlopen(u,timeout=20) as r:b=r.read();status=r.status
  except urllib.error.HTTPError as e:b=e.read();status=e.code
  (D/(key+'.html')).write_bytes(b);n=html.fromstring(b,parser=html.HTMLParser(encoding='utf-8'));(D/(key+'.txt')).write_text(n.text_content());links=[]
  for a in n.xpath('//a[@href]'):
   href=urllib.parse.urljoin(u,a.get('href'));txt=' '.join(a.text_content().split())
   if 'nttFileDownload' in href:links.append({'label':txt,'url':href})
  return {**row,'requestUrl':u,'status':status,'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'downloads':links}
 except Exception as e:return {**row,'error':str(e)}
out=list(concurrent.futures.ThreadPoolExecutor(4).map(f,rows));(D/'receipt.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False,indent=2))
