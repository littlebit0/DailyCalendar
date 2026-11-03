from html.parser import HTMLParser
from urllib.request import Request, build_opener, HTTPCookieProcessor
from urllib.parse import urlencode
from http.cookiejar import CookieJar
from pathlib import Path
import time
class Form(HTMLParser):
 def __init__(self,html):
  super().__init__(); self.fields={};self.selects={};self.current=None;self.option=None;self.feed(html)
 def handle_starttag(self,tag,attrs):
  a=dict(attrs)
  if tag=='input' and a.get('name'):
   if a.get('type') not in ('radio','checkbox') or 'checked' in a:self.fields[a['name']]=a.get('value','')
  elif tag=='select':self.current=a.get('name');self.selects[self.current]=[]
  elif tag=='option' and self.current:self.option={'value':a.get('value',''),'text':'','selected':'selected' in a}
 def handle_data(self,data):
  if self.option is not None:self.option['text']+=data
 def handle_endtag(self,tag):
  if tag=='option' and self.option is not None:self.selects[self.current].append(self.option);self.option=None
  if tag=='select':
   options=self.selects[self.current];self.fields[self.current]=next((o['value'] for o in options if o['selected']),options[0]['value'] if options else '');self.current=None
base='https://hakstd.jnu.ac.kr/web/Suup/TimeTable/Suup030_C.aspx'
prefix='ctl00$ctl00$ContentPlaceHolder$ContentPlaceHolderSub$'
opener=build_opener(HTTPCookieProcessor(CookieJar()))
def get():return opener.open(Request(base,headers={'User-Agent':'Mozilla/5.0'}),timeout=30).read().decode('utf-8')
def post(html,changes,event):
 f=Form(html);d=f.fields;d.update({prefix+k:v for k,v in changes.items()});d['__EVENTTARGET']=prefix+event;d['__EVENTARGUMENT']='';time.sleep(.35)
 return opener.open(Request(base,data=urlencode(d).encode(),headers={'User-Agent':'Mozilla/5.0','Referer':base}),timeout=30).read().decode('utf-8')
if __name__=='__main__':
 s=get();s=post(s,{'ddlSubj':'2'},'ddlSubj');Path('work/university-expansion/jnu-major.html').write_text(s)
 for k,v in Form(s).selects.items():print(k.split('$')[-1],[(o['value'],o['text']) for o in v][:30])
 s=post(s,{'ddlColl':'30000088'},'ddlColl');Path('work/university-expansion/jnu-engineering.html').write_text(s)
 print('DEPTS',Form(s).selects[prefix+'ddlDept'])
