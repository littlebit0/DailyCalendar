import urllib.request,http.cookiejar,json
from pathlib import Path
r=Path(__file__).parent;op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()));entry='https://jump.jbnu.ac.kr/link?div=sucrPlan';op.open(entry,timeout=30).read();url='https://jump.jbnu.ac.kr/Report/print.do'
with op.open(urllib.request.Request(url,data=b'reportFile=sucs%2FSucsLctrPldocPrtLesnSbj',headers={'Content-Type':'application/x-www-form-urlencoded','User-Agent':'Mozilla/5.0','Referer':entry}),timeout=30) as q:
 b=q.read();(r/'jbnu-public-session-report-metadata.txt').write_bytes(b);print(q.status,len(b),b[:450])
