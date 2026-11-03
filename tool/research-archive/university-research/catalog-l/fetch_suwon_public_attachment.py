"""Follow the published anonymous board form's download action; no login."""
import urllib.request,urllib.parse,http.cookiejar,pathlib,re
from html.parser import HTMLParser
P=pathlib.Path(__file__).parent
class Fields(HTMLParser):
 def __init__(self):super().__init__();self.on=False;self.fields={}
 def handle_starttag(self,t,a):
  d=dict(a)
  if t=='form':self.on=d.get('id')=='frontBoardVo'
  if t=='input' and self.on and d.get('name'):self.fields[d['name']]=d.get('value','')
 def handle_endtag(self,t):
  if t=='form':self.on=False
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
u='https://www.suwon.ac.kr/index.html?act=view&bbsno=88333&boardno=667&menuno=674&siteno=37'
s=op.open(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=25).read().decode()
h=Fields();h.feed(s);h.fields.update({'act':'down','fno':'33082'})
req=urllib.request.Request('https://www.suwon.ac.kr/skin/board/Valid.html',data=urllib.parse.urlencode(h.fields).encode(),headers={'User-Agent':'Mozilla/5.0','Referer':u})
with op.open(req,timeout=30) as resp:b=resp.read()
assert b.startswith(b'%PDF'), 'The actual public download did not return PDF'
(P/'suwon-current-smart-registration-manual.pdf').write_bytes(b)
print('Downloaded official manual bytes:',len(b))
