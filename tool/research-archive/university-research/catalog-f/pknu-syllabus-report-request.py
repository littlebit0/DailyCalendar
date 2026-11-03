import json,urllib.request,urllib.parse,http.cookiejar,time
from pathlib import Path
p=Path(__file__).parent
rows=json.loads((p/'pknu-latest-rows.json').read_text())
ids={'113631-103','113633-103','114694-105','111214-103'}
jar=http.cookiejar.CookieJar(); op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
entry='https://irumi.pknu.ac.kr/nxui/launch.html?screenid=Desktop_screen_quick&menuId=U020913'
op.open(entry,timeout=35).read()
records=[]
for r in rows:
 k=r['COURSE_NO']+'-'+r['DCLSS_NO']
 if k not in ids: continue
 enc=lambda x:urllib.parse.quote(urllib.parse.quote(x,safe=''),safe='')
 params={'YY':'2026','SHTM_CD':'U0003002','IN_PARAM':"('%s','%s','%s','U0253001')"%(r['COURSE_NO'],r['DCLSS_NO'],r['STAFF_NO']), '_CLIENT_USER_INFO':{},'_PROG_INFO':{'PGM_PATH':'uni::cour/open/LtPdocInq.xfdl','MENU_ID':'U020913','MENU_NM':'강의계획서조회'}}
 data={'reportPath':enc('uni/cour/open/LtPdocMngtPrn.mrd'),'reportParam':enc(json.dumps(params,ensure_ascii=False,separators=(',',':'))),'reportOption':enc('{"ds":"uni"}'),'beforeDraw':'','afterDraw':'','sessionId':next((c.value for c in jar if c.name=='JSESSIONID'),'')}
 req=urllib.request.Request('https://reporting.pknu.ac.kr/ReportingServer/embed',data=urllib.parse.urlencode({'report':json.dumps(data,separators=(',',':')),'key':''}).encode(),headers={'Referer':entry,'User-Agent':'Mozilla/5.0','Content-Type':'application/x-www-form-urlencoded'})
 try:
  with op.open(req,timeout=40) as f: raw=f.read(); status=f.status
  (p/('pknu-syllabus-'+k+'.html')).write_bytes(raw)
  records.append({'id':k,'status':status,'bytes':len(raw),'params':params}); print(k,status,len(raw))
 except Exception as e: records.append({'id':k,'error':str(e)}); print(k,str(e))
 time.sleep(.5)
(p/'pknu-syllabus-report-audit.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
