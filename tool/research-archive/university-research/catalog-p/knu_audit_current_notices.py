"""Normal public board search; anonymous session values only in memory."""
from urllib.request import Request,build_opener,HTTPCookieProcessor
from urllib.parse import urlencode
from http.cookiejar import CookieJar
from html.parser import HTMLParser
import json
from pathlib import Path
import re

ROOT=Path(__file__).parent
URL='https://www.knu.ac.kr/wbbs/wbbs/bbs/btin/stdList.action'
class Board(HTMLParser):
    def __init__(self):super().__init__();self.row=None;self.cell=None;self.rows=[]
    def handle_starttag(self,t,attrs):
        a=dict(attrs)
        if t=='tr':self.row=[]
        if t=='td' and self.row is not None:self.cell=[]
        if t=='a' and self.cell is not None:
            match=re.search(r"doRead\('([^']*)',\s*'([^']*)',\s*'([^']*)'\)",a.get('onclick','')+a.get('href',''))
            if match:self.cell.append('BOARDKEY:'+','.join(match.groups()))
    def handle_data(self,s):
        if self.cell is not None and s.strip():self.cell.append(s.strip())
    def handle_endtag(self,t):
        if t=='td' and self.cell is not None:self.row.append(' '.join(self.cell));self.cell=None
        if t=='tr' and self.row is not None:
            if len(self.row)>=5:self.rows.append(self.row)
            self.row=None

opener=build_opener(HTTPCookieProcessor(CookieJar()))
headers={'User-Agent':'Mozilla/5.0','Referer':URL+'?menu_idx=42'}
with opener.open(Request(URL+'?menu_idx=42',headers=headers),timeout=40) as response:response.read()
for keyword in ['폐강','수업시간표','수강신청','변경','정정','재개설']:
    query={'menu_idx':'42','bbs_cde':'','page':'1','pageIndex':'1','popupDeco':'','search_type':'search_subject','search_text':keyword}
    with opener.open(Request(URL,data=urlencode(query).encode(),headers=headers),timeout=40) as response:
        body=response.read().decode('utf-8');status=response.status
    parser=Board();parser.feed(body)
    (ROOT/f'knu-current-{keyword}-notice-search.json').write_text(json.dumps({'sourceUrl':URL,'requestFields':query,'status':status,'rows':parser.rows},ensure_ascii=False,indent=2)+'\n')
    print(keyword,status,len(body),len(parser.rows),re.findall(r'<title>(.*?)</title>',body,re.S))
