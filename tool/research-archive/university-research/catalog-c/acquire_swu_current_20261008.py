import urllib.request,urllib.parse,http.cookiejar,json
from pathlib import Path
ROOT=Path(__file__).parent/'swu-current-20261008'
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
URL='https://swis.swu.ac.kr/ext.ccs.ExtCcsSOpenSubSearch.ex'
HEAD={'User-Agent':UA,'Content-Type':'application/x-www-form-urlencoded','req-protocol':'urlencoded','res-protocol':'json','eXria-Version':'eXria.1.0','req-charset':'UTF-8','res-charset':'utf-8','Referer':'https://swis.swu.ac.kr/json/ccs/extCcsSOpenSubSearch.xrf'}
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
with opener.open(urllib.request.Request(HEAD['Referer'],headers={'User-Agent':UA}),timeout=30)as r:r.read()
body={'strCommand':'onLoad'}
with opener.open(urllib.request.Request(URL,data=urllib.parse.urlencode(body).encode(),headers=HEAD),timeout=40)as r:b=r.read()
data=json.loads(b)['root']; safe={};
for k,v in data.items():
 safe[k]={'row':[{a:z for a,z in r.items() if a in {'CD','CD_NM','SA_CD','SA_NM'}} for r in v['row']]} if isinstance(v,dict) and isinstance(v.get('row'),list) else v
(ROOT/'swu-onload.json').write_text(json.dumps({'root':safe},ensure_ascii=False,indent=2)+'\n');print('public educational selectors',flush=True)


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
  filename='swu-list-'+div['CD']+'-'+(dept or 'all')+'.json';root=json.loads(b)['root'];rows=root.get('openSubList',{}).get('row',[]); whitelist={'SB_CD','DIVCLS_CD','SB_CD_NM','PROF_NM','CLASS','LECT_ROOM_CD','PNT','CMP_DIV_RCD','CMP_DIV_RCD_NM','CMP_DIV_SUB_NM','CMP_DIV_DBL_NM','SB_LVL','PERMIT_LIMIT_NM','COCO_NM','COCO_4_NM','PRE_CURI_NM','DCL_RCD_NM','DCL_NM_FOR_ENG','TRACK_CURI','REF_KEY','THEO_EPAC_TC'}; root={'openSubList':{'row':[{k:v for k,v in row.items() if k in whitelist} for row in rows]},'EXRIAERRMSG':root.get('EXRIAERRMSG')}; (ROOT/filename).write_text(json.dumps({'root':root},ensure_ascii=False,indent=2)+'\n')
  summaries.append({'div':div['CD'],'label':div['CD_NM'],'department':dept,'file':filename,'rows':len(rows),'error':root.get('EXRIAERRMSG')})
  (ROOT/'swu-acquisition-index.json').write_text(json.dumps(summaries,ensure_ascii=False,indent=2)+'\n');print(div['CD'],dept,len(rows),bool(root.get('EXRIAERRMSG')),flush=True);time.sleep(.15)
