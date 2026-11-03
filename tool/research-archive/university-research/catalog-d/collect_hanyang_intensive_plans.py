from pathlib import Path
import urllib.request,json,time,http.cookiejar
p=Path(__file__).parent;raw=p/'hanyang-2026-2-intensive-plans-raw';raw.mkdir(exist_ok=True)
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()));op.addheaders=[('User-Agent','Mozilla/5.0')];op.open('https://portal.hanyang.ac.kr/sugang/sulg.do',timeout=30).read()
a={}
for g in ['seoul','seoul-medicine','erica']:
 for r in json.loads((p/f'hanyang-2026-2-{g}-all.json').read_text())['records']:
  if r['jipjungGanguiYn']=='1':a[r['suupNo']]=r
for code,r in a.items():
 b=op.open(urllib.request.Request('https://portal.hanyang.ac.kr/haksa/SughAct/findCoursePlanInfo.do',data=json.dumps(dict(pCourseId='',pSuupYear='2026',pSuupTerm='20',pSuupNo=code,pHaksuNo='')).encode(),headers={'Content-Type':'application/json+sua; charset=utf-8'}),timeout=30).read()
 obj=json.loads(b)
 if 'exception' in obj:raise RuntimeError(str(obj)[:200])
 exclude={'insertIp','updateIp','insertMan','updateMan','gyosuHpNo','gyosuEmail','gyogangsaNo','gyosuHomepage','profHomepage','pGaeinNo'}
 def clean(x):
  if isinstance(x,dict):return {k:clean(v) for k,v in x.items() if k not in exclude}
  if isinstance(x,list):return [clean(v) for v in x]
  return x
 (raw/(code+'.json')).write_text(json.dumps(clean(obj),ensure_ascii=False,indent=2))
 print(code,r['gwamokNm'],len(b),flush=True);time.sleep(.3)
