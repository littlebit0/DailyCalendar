import urllib.request,urllib.parse,re,html,json,hashlib,time
from pathlib import Path
P=Path(__file__).resolve().parent;receipts=[]
urls=['https://www.syu.ac.kr/nursing/','https://www.syu.ac.kr/pharmacy/','https://www.syu.ac.kr/aice/']
for u in urls:
 time.sleep(.8)
 b=urllib.request.urlopen(u,timeout=35).read();s=b.decode();links=[]
 for href,label in re.findall(r'<a\b[^>]*href=["\']([^"\']+)["\'][^>]*>(.*?)</a>',s,re.S):
  t=re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]+>',' ',label))).strip()
  if re.search(r'시간표|수강|자료실|공지사항|학사공지|학부|교육과정',t) and '@' not in t:
   row={'label':t,'url':urllib.parse.urljoin(u,html.unescape(href))}
   if row not in links:links.append(row)
 receipts.append({'URL':u,'SHA256':hashlib.sha256(b).hexdigest(),'educationalLinks':links,'rawHTMLSaved':False})
(P/'observed-current-department-education-links.json').write_text(json.dumps(receipts,ensure_ascii=False,indent=2)+'\n');print(json.dumps(receipts,ensure_ascii=False,indent=2))
