import pathlib,json,urllib.request,urllib.parse,concurrent.futures,hashlib,re
from lxml import html
base=pathlib.Path(__file__).parent;D=base/'kmou-public-form-search';D.mkdir(exist_ok=True);boards=[]
for sub in ['kmou-new-department-discovery','kmou-new-department-https-discovery','kmou-maritime-department-discovery']:
 for r in json.loads((base/sub/'main-receipt.json').read_text()):
  for b in r.get('observedBoards',[]):boards.append((r['label'],b['url']))
boards=list(dict.fromkeys(boards))
def fetch(req):
 try:
  with urllib.request.urlopen(req,timeout=18) as r:return r.status,r.read()
 except urllib.error.HTTPError as e:return e.code,e.read()
def f(kv):
 label,url=kv;key=urllib.parse.urlparse(url).path.split('/')[1]
 try:
  status,b=fetch(url);(D/(key+'-list.html')).write_bytes(b);n=html.fromstring(b,parser=html.HTMLParser(encoding='utf-8'));forms=n.xpath('//form[@name="srchForm"]')
  if not forms:return {'label':label,'url':url,'status':status,'reason':'Normal public response has no observed search form'}
  form=forms[0];fields={c.get('name'):c.get('value','') for c in form.xpath('.//input[@name]')};opts=form.xpath('.//select[@name="searchType"]/option/@value')
  if 'all'not in opts:return {'label':label,'url':url,'reason':'Observed title/body option unavailable'}
  fields.update(searchType='all',searchValue='시간표');m=re.search(r'forms\.action\s*=\s*["\']([^"\']+)',b.decode('utf-8','replace'))
  action=urllib.parse.urljoin(url,m.group(1) if m else form.get('action') or url)
  req=urllib.request.Request(action,data=urllib.parse.urlencode(fields).encode());s,raw=fetch(req);(D/(key+'-search.html')).write_bytes(raw);root=html.fromstring(raw,parser=html.HTMLParser(encoding='utf-8'));leads=[]
  for row in root.xpath('//div[contains(@class,"BD_list")]//tr'):
   for a in row.xpath('.//a[contains(@href,"selectNttInfo")]'):
    leads.append({'label':' '.join(a.text_content().split()),'url':urllib.parse.urljoin(action,a.get('href')),'visibleRow':' '.join(row.text_content().split())})
  return {'label':label,'observedListUrl':url,'listStatus':status,'normalListReadable':bool(forms),'observedPublicFormAction':action,'postedVisibleFields':fields,'searchStatus':s,'responseSHA256':hashlib.sha256(raw).hexdigest(),'leads':leads}
 except Exception as e:return {'label':label,'url':url,'error':str(e)}
r=list(concurrent.futures.ThreadPoolExecutor(6).map(f,boards));(D/'receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2));print(json.dumps([x for x in r if x.get('leads')],ensure_ascii=False,indent=2));print('total',len(r),'withLeads',sum(bool(x.get('leads')) for x in r))
