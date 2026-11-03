import urllib.request,urllib.parse,http.cookiejar,json
from pathlib import Path
ROOT=Path(__file__).parent
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
URL='https://swis.swu.ac.kr/ext.ccs.ExtCcsSOpenSubSearch.ex'
HEAD={'User-Agent':UA,'Content-Type':'application/x-www-form-urlencoded','req-protocol':'urlencoded','res-protocol':'json','eXria-Version':'eXria.1.0','req-charset':'UTF-8','res-charset':'utf-8','Referer':'https://swis.swu.ac.kr/json/ccs/extCcsSOpenSubSearch.xrf'}
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
with opener.open(urllib.request.Request(HEAD['Referer'],headers={'User-Agent':UA}),timeout=30)as r:r.read()
body={'strCommand':'onLoad'}
with opener.open(urllib.request.Request(URL,data=urllib.parse.urlencode(body).encode(),headers=HEAD),timeout=40)as r:b=r.read()
(ROOT/'swu-onload.json').write_bytes(b);print(len(b),b[:160])


data=json.loads(b)['root'];key=data['keyDate'];import time
summaries=[]
for div in data['listCode1']['row']:
 if div['CD']=='CCR00101':depts=[r['SA_CD']for r in data['listNetSa']['row']]
 elif div['CD']=='CCR00113':depts=[r['SA_CD']for r in data['listNetConnSa']['row']]
 elif div['CD']=='CCR00114':depts=[r['SA_CD']for r in data['listHybirdMajor']['row']]
 else:depts=['']
 for dept in depts:
  body={'strCommand':'list','strYearRcd':key['YEAR'],'strSmtRcd':key['SMT'],'strDivRcd':div['CD'],'strDepCd':dept,'strCode2':''}
  with opener.open(urllib.request.Request(URL,data=urllib.parse.urlencode(body).encode(),headers=HEAD),timeout=45)as r:b=r.read()
  filename='swu-list-'+div['CD']+'-'+(dept or 'all')+'.json';(ROOT/filename).write_bytes(b);root=json.loads(b)['root'];rows=root.get('openSubList',{}).get('row',[])
  summaries.append({'div':div['CD'],'label':div['CD_NM'],'department':dept,'file':filename,'rows':len(rows),'error':root.get('EXRIAERRMSG')})
  (ROOT/'swu-acquisition-index.json').write_text(json.dumps(summaries,ensure_ascii=False,indent=2)+'\n');print(div['CD'],dept,len(rows),bool(root.get('EXRIAERRMSG')));time.sleep(.15)
