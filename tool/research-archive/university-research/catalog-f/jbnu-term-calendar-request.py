import urllib.request,urllib.parse,http.cookiejar,re,json
from pathlib import Path
r=Path(__file__).parent;op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()));url='https://www.jbnu.ac.kr/mobile/academic/schedule.do';t=op.open(url,timeout=30).read().decode();csrf=re.search(r'<meta[^>]+name="_csrf"[^>]+content="([^"]+)"',t)[1];url='https://www.jbnu.ac.kr/mobile/academic/schedule/dataAjax.do';body=urllib.parse.urlencode({'type':'yearly','acSemester':'2','acYear':'2026'}).encode()
with op.open(urllib.request.Request(url,data=body,headers={'X-CSRF-Token':csrf,'AJAX':'true','Content-Type':'application/x-www-form-urlencoded'}),timeout=30) as q:
 b=q.read();(r/'jbnu-2026-2-calendar.html').write_bytes(b);print(q.status,len(b))
