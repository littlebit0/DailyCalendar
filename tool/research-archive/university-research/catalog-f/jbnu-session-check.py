import urllib.request,http.cookiejar,json
from pathlib import Path
R=Path(__file__).parent
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
for n,url,body in [('session-entry.html','https://jump.jbnu.ac.kr/link?div=sucrPlan',None),('session-onload.json','https://jump.jbnu.ac.kr/SCH/SucrLessnSbjctInq/onLoad.do',{'dmReqKey':{'strLanDivcd':'CCMN101.KOR','strLang':'ko'}}),('session-date.json','https://jump.jbnu.ac.kr/SCH/SucrLessnSbjctInq/date.do',{'dmReqKey':{'strYrsa':'2026','strSemstrCd':'SUSR016.020','strCertDivCd':'1','strLanDivcd':'CCMN101.KOR','strLang':'ko'}})]:
 q=op.open(urllib.request.Request(url,data=json.dumps(body).encode() if body else None,headers={'User-Agent':'Mozilla/5.0','Content-Type':'application/json'}),timeout=40);b=q.read();(R/('jbnu-'+n)).write_bytes(b);print(n,len(b),b[:200] if 'date' in n else '')
