import urllib.request,urllib.parse,http.cookiejar,re,html
from pathlib import Path
ROOT=Path(__file__).parent
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
HEAD={'User-Agent':UA,'Accept':'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8','Accept-Language':'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7'}
for name,url in [('ssu','https://ecc.ssu.ac.kr/sap/bc/webdynpro/sap/zcmw2100?sap-language=KO')]:
 opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
 with opener.open(urllib.request.Request(url,headers=HEAD),timeout=30)as r:s=r.read().decode()
 (ROOT/f'{name}-initial.html').write_text(s)
 form=re.search(r'<form\b[^>]*action="([^"]+)"[^>]*>(.*?)</form>',s,re.S)
 action=urllib.parse.urljoin(url,html.unescape(form.group(1)))
 data={html.unescape(n):html.unescape(v)for n,v in re.findall(r'name="([^"]+)" value="([^"]*)"',form.group(2))}
 data['SAPEVENTQUEUE']='LoadingPlaceHolder_Load\ue002Id\ue004_loadingPlaceholder_\ue003\ue002ResponseData\ue004delta\ue005ClientAction\ue004submit\ue003\ue002\ue003'
 headers=dict(HEAD,Referer=url,Origin=urllib.parse.urlsplit(url).scheme+'://'+urllib.parse.urlsplit(url).netloc)
 headers.update({'X-Requested-With':'XMLHttpRequest','X-XHR-Logon':'accept','Content-Type':'application/x-www-form-urlencoded'})
 data['SAPEVENTQUEUE']=''.join(c if c in '0123456789abcdefghijklmnopqrstuvwxyzABCDEDFGHIJKLMNOPQRSTUVWXYZ-_.' else '~'+format(ord(c),'04X') for c in data['SAPEVENTQUEUE'])
 payload=urllib.parse.urlencode(data).encode()
 try:
  with opener.open(urllib.request.Request(action,data=payload,headers=headers),timeout=30)as r:b=r.read()
 except urllib.error.HTTPError as e:b=e.read();print(name,'HTTP',e.code)
 (ROOT/f'{name}-loaded.xml').write_bytes(b);print(name,len(b),b[:100])

 def event(control,event,params,label):
  global action,data
  content=''.join(re.findall(r'<!\[CDATA\[(.*?)\]\]>',b.decode(),re.S))
  form=re.search(r'<form\b[^>]*action="([^"]+)"[^>]*>(.*?)</form>',content,re.S)
  if form:
   action=urllib.parse.urljoin(url,html.unescape(form.group(1)))
   data={html.unescape(n):html.unescape(v)for n,v in re.findall(r'name="([^"]+)" value="([^"]*)"',form.group(2))}
  ev=control+'_'+event+'\ue002'+'\ue005'.join(k+'\ue004'+str(v)for k,v in params.items())+'\ue003\ue002ResponseData\ue004delta\ue005ClientAction\ue004submit\ue003\ue002\ue003'
  data['SAPEVENTQUEUE']=''.join(c if c in '0123456789abcdefghijklmnopqrstuvwxyzABCDEDFGHIJKLMNOPQRSTUVWXYZ-_.' else '~'+format(ord(c),'04X') for c in ev)
  with opener.open(urllib.request.Request(action,data=urllib.parse.urlencode(data).encode(),headers=headers),timeout=45) as r:out=r.read()
  (ROOT/f'{name}-{label}.xml').write_bytes(out);print(name,label,len(out));return out

 from html.parser import HTMLParser
 import json,time
 class Options(HTMLParser):
  def __init__(self,ident):super().__init__();self.ident=ident;self.depth=0;self.items=[]
  def handle_starttag(self,t,a):
   d=dict(a)
   if t=='div':
    if self.depth:self.depth+=1
    elif d.get('id')==self.ident:self.depth=1
   if self.depth and d.get('ct')=='LIB_I':self.items.append((d['data-itemkey'],d.get('data-itemvalue1','')))
  def handle_endtag(self,t):
   if t=='div' and self.depth:self.depth-=1
 def opts(raw,ident):
  parser=Options(ident);parser.feed(''.join(re.findall(r'<!\[CDATA\[(.*?)\]\]>',raw.decode(),re.S)));return parser.items
 colleges=opts(b,'WD0104');summary=[]
 for college,collegeName in colleges:
  b=event('ComboBox','Select',{'Id':'WD0103','Key':college,'ByEnter':'false'},'college-'+college)
  departments=opts(b,'WD0114')
  for dept,deptName in departments:
   b=event('ComboBox','Select',{'Id':'WD0113','Key':dept,'ByEnter':'false'},'department-'+dept)
   b=event('Button','Press',{'Id':'WD0119'},'courses-'+college+'-'+dept)
   summary.append({'college':college,'collegeName':collegeName,'department':dept,'departmentName':deptName,'file':'ssu-courses-'+college+'-'+dept+'.xml'})
   (ROOT/'ssu-acquisition-index.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n');time.sleep(.2)
 print('departments',len(summary))
