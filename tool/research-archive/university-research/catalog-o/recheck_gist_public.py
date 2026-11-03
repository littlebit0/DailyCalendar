"""Actual current public notices and term; education text only, no sessions."""
from pathlib import Path
import urllib.request,json,datetime,time,re,sys
from html.parser import HTMLParser
p=Path(__file__).parent;sys.path.insert(0,str(p.parent/'catalog-g'))
from skku_inline_private_education_filter import filter_education
class Text(HTMLParser):
 def __init__(self):super().__init__();self.parts=[]
 def handle_data(self,d):self.parts.append(d)
urls=['https://www.gist.ac.kr/kr/html/sub05/050209.html?mode=V&no=222987','https://www.gist.ac.kr/kr/html/sub05/050209.html?mode=V&no=222414','https://www.gist.ac.kr/kr/html/sub05/050209.html?mode=V&no=223893','https://www.gist.ac.kr/kr/html/sub05/05020302.html','https://www.gist.ac.kr/kr/html/sub05/0501.html','https://www.gist.ac.kr/kr/html/sub05/050209.html']
out={'researchOnly':True,'completionClaim':False,'checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pages':[]}
for u in urls:
 time.sleep(.8)
 r=urllib.request.urlopen(u,timeout=40);b=r.read()
 if r.status!=200:raise RuntimeError('Non-success protection response')
 s=b.decode('utf8');start=s.find('<div class="bd_detail_content">')
 if start>=0:s=s[start:s.find('<div class="bd_btn',start) if s.find('<div class="bd_btn',start)>start else s.find('<!-- footer',start)]
 else:
  s=re.sub(r'<script\b.*?</script>|<style\b.*?</style>','',s,flags=re.S|re.I)
 t=Text();t.feed(s);value='\n'.join(z.strip() for z in t.parts if z.strip());safe,masked,lost=filter_education(value)
 links=[z.replace('&amp;','&') for z in re.findall(r'href=[\'\"]([^\'\"]+)[\'\"]',s) if 'mode=D' in z or 'mode=V' in z]
 out['pages'].append({'url':u,'status':r.status,'educationalText':safe,'publicLinks':links,'maskedContacts':masked,'lostPrivateLines':lost})
 (p/'gist-public-current-recheck-20261008.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(u,r.status,len(b),len(safe),flush=True)
