import requests,websocket,json,time,pathlib
P=pathlib.Path(__file__).parent;pg=next(p for p in requests.get('http://localhost:64244/json').json()if p['type']=='page');w=websocket.create_connection(pg['webSocketDebuggerUrl'],origin='http://localhost:64244',timeout=8);i=0
for name,url in [('eulji','https://www.eulji.ac.kr/'),('iccu-pdf','https://nursing.iccu.ac.kr/academic/timetable.php'),('hongik','https://cn.hongik.ac.kr/app/timetable/hak02.jsp')]:
 i+=1;w.send(json.dumps({'id':i,'method':'Page.navigate','params':{'url':url}}));time.sleep(5)
 i+=1;w.send(json.dumps({'id':i,'method':'Runtime.evaluate','params':{'expression':'JSON.stringify({url:location.href,title:document.title,text:document.body.innerText,html:document.documentElement.outerHTML,frames:Array.from(document.querySelectorAll("iframe")).map(x=>x.src)})','returnByValue':True}}))
 while 1:
  m=json.loads(w.recv())
  if m.get('id')==i:break
 try:v=json.loads(m['result']['result']['value']);P.joinpath(name+'-browser.json').write_text(json.dumps(v,ensure_ascii=False,indent=2));print(name,v['title'],v['text'][:180],flush=True)
 except Exception:print(name,'error',str(m)[:100],flush=True)
