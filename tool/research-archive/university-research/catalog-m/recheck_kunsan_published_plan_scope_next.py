"""Bounded current normal public package check; no private accounts or raw HTML storage."""
import hashlib,json,time,urllib.request,http.cookiejar
from pathlib import Path
P=Path(__file__).parent
old=json.loads((P/'kunsan-current-package-recheck-20261008.json').read_text())
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
def get(url):
 req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0','Referer':'https://www.kunsan.ac.kr/'})
 with opener.open(req,timeout=40) as r:
  if r.status!=200:raise RuntimeError('Non200 normal public response')
  b=r.read();return b,r.geturl(),r.headers.get('Content-Type','')
get('https://www.kunsan.ac.kr/')
out={'checkedAt':'2026-10-08','normalPublicRequests':True,'privateAccountUsed':False,'rawHTMLOrCookiesPersisted':False,'wholeRecollected':False,'finalActiveScopeVerified':False,'attachments':[]}
for e in old[2:5]:
 time.sleep(1)
 b,url,ct=get(e['url'])
 if not b.startswith(b'PK'):raise RuntimeError('Unexpected non-workbook response: stop without retry')
 sha=hashlib.sha256(b).hexdigest()
 out['attachments'].append({'sourceURL':e['url'],'finalURL':url,'title':e['title'],'bytes':len(b),'sha256':sha,'matchesExistingEducationalSource':sha==e['sha256'],'currencyLimit':'Same public bytes confirms posted package, not final closures or individualized later changes.'})
assert all(x['matchesExistingEducationalSource'] for x in out['attachments'])
f=P/'kunsan-published-plan-package-recheck-next-20261008.json';assert not f.exists();f.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(out,ensure_ascii=False))
