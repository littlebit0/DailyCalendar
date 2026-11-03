import urllib.request,json,concurrent.futures
from pathlib import Path
R=Path(__file__).parent
def get(c):
 b={'data':{'dmReqKey':{'strYrsa':'2026','strSemstrCd':'SUSR016.020','strCertDivCd':str(c),'strLanDivcd':'CCMN101.KOR','strLang':'ko'}}};url='https://jump.jbnu.ac.kr/SCH/SucrLessnSbjctInq/list.do';name=f'jbnu-type{c}.json'
 try:
  with urllib.request.urlopen(urllib.request.Request(url,data=json.dumps(b).encode(),headers={'User-Agent':'Mozilla/5.0','Content-Type':'application/json'}),timeout=50) as q:
   t=q.read();(R/name).write_bytes(t);return dict(file=name,url=url,method='POST',body=b,status=q.status,bytes=len(t))
 except Exception as e:return dict(file=name,error=str(e),body=b)
a=list(concurrent.futures.ThreadPoolExecutor(3).map(get,[2,3,4,7,10]));j=json.loads((R/'requests.json').read_text());j.extend(a);(R/'requests.json').write_text(json.dumps(j,ensure_ascii=False,indent=2));print(a)
