"""Normal anonymous public restriction popup requests; resume from saved per-course files."""
from pathlib import Path
import urllib.request,http.cookiejar,json,time
p=Path(__file__).parent;raw=p/'hanyang-2026-2-restrictions-raw';raw.mkdir(exist_ok=True)
base='https://portal.hanyang.ac.kr/sugang/'
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
op.addheaders=[('User-Agent','Mozilla/5.0')];op.open(base+'sulg.do',timeout=30).read()
a={}
for group in ['seoul','seoul-medicine','erica']:
 for r in json.loads((p/f'hanyang-2026-2-{group}-all.json').read_text())['records']:
  if str(r['isuJehanYn']).startswith('O'):a[r['suupNo']]=r
print('restriction offering count',len(a),flush=True)
for i,(code,r) in enumerate(a.items(),1):
 name=raw/(code+'.json')
 endpoint='findSuupSugangIsuGbGongtong.do' if r['ilbanCommonGb']=='1' else 'findSuupSugangIsuGbHakgwa.do'
 if not name.exists():
  body=dict(strSuupYear='2026',strSuupTerm='20',strSuupNo=code)
  req=urllib.request.Request(base+'SgscAct/'+endpoint,data=json.dumps(body).encode(),headers={'Content-Type':'application/json+sua; charset=utf-8'})
  b=op.open(req,timeout=30).read();obj=json.loads(b)
  if 'exception' in obj:raise RuntimeError(str(obj)[:200])
  name.write_bytes(b);time.sleep(.2)
 if i%100==0:print('saved',i,'/',len(a),flush=True)
print('DONE',len(a),flush=True)
