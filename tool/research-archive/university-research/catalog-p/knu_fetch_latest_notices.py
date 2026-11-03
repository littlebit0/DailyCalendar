from urllib.request import Request,urlopen
from urllib.parse import urlencode
from html.parser import HTMLParser
from pathlib import Path
import json,re
ROOT=Path(__file__).parent
class Links(HTMLParser):
 def __init__(self):super().__init__();self.links=[];self.link=None
 def handle_starttag(self,t,a):
  d=dict(a)
  if t=='a' and ('fileMngr' in d.get('href','') or 'fileSeq=' in d.get('href','')):self.link=[d['href'],'']
 def handle_data(self,s):
  if self.link:self.link[1]+=s
 def handle_endtag(self,t):
  if t=='a' and self.link:self.links.append(self.link);self.link=None
for key in ['11789375936295','11788165320350','11785737876426']:
 url='https://www.knu.ac.kr/wbbs/wbbs/bbs/btin/stdViewBtin.action?'+urlencode({'menu_idx':'42','bltn_no':key,'note_div':'row'})
 with urlopen(Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=40) as r:body=r.read().decode('utf-8')
 body=re.sub(r';(?:wbbssessionid|jsessionid)=[^\s\'\"<>?]*','',body,flags=re.I)
 (ROOT/f'knu-current-notice-{key}.html').write_text(body)
 parser=Links();parser.feed(body)
 (ROOT/f'knu-current-notice-{key}-attachments.json').write_text(json.dumps(parser.links,ensure_ascii=False,indent=2)+'\n')
 for i,(link,title) in enumerate(parser.links):
  if '.xlsx' not in title:continue
  with urlopen(Request(link,headers={'User-Agent':'Mozilla/5.0','Referer':url}),timeout=40) as r:data=r.read()
  (ROOT/f'knu-current-notice-{key}-{i}.xlsx').write_bytes(data)
  print(key,i,title,len(data))
