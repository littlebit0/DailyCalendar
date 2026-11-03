import urllib.request,urllib.parse,http.cookiejar,re,html
from pathlib import Path
ROOT=Path(__file__).parent
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
HEAD={'User-Agent':UA,'Accept':'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8','Accept-Language':'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7'}
for name,url in [('ssu','https://ecc.ssu.ac.kr/sap/bc/webdynpro/sap/zcmw2100?sap-language=KO'),('sogang','https://sis109.sogang.ac.kr/sap/bc/webdynpro/sap/zcmw9016?sap-language=KO')]:
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
 if name=='ssu':
  b=event('TabStrip','TabSelect',{'Id':'WDF4','ItemId':'WD0132','ItemIndex':9,'FirstVisibleItemIndex':0},'subject-tab')
  b=event('Button','Press',{'Id':'WD01E8'},'search')
 else:
  b=event('ComboBox','Select',{'Id':'WD88','Key':'30000002','ByEnter':'false'},'undergraduate')
  b=event('Button','Press',{'Id':'WDCA'},'search')
