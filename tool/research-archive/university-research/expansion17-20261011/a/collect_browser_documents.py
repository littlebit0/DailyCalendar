import requests,websocket,json,pathlib,time,base64
P=pathlib.Path(__file__).parent;pg=next(p for p in requests.get('http://localhost:64244/json').json()if p['type']=='page');w=websocket.create_connection(pg['webSocketDebuggerUrl'],origin='http://localhost:64244',timeout=30);i=0
def call(method,params):
 global i
 i+=1;w.send(json.dumps({'id':i,'method':method,'params':params}))
 while 1:
  r=json.loads(w.recv())
  if r.get('id')==i:return r
call('Page.navigate',{'url':'https://eulji.ac.kr/renewal/index.html?menuno=8069'});time.sleep(5)
r=call('Runtime.evaluate',{'expression':'document.documentElement.outerHTML','returnByValue':True});P.joinpath('eulji-calendar-browser.html').write_text(r['result']['result']['value']);print('Eulji calendar HTML acquired')
call('Page.navigate',{'url':'https://nursing.iccu.ac.kr/academic/timetable.php'});time.sleep(4)
r=call('Runtime.evaluate',{'expression':'fetch("/board/free/photo/k_202609020152270.pdf").then(async r=>({status:r.status,type:r.headers.get("content-type"),body:btoa(String.fromCharCode(...new Uint8Array(await r.arrayBuffer())))}))','returnByValue':True,'awaitPromise':True});val=r['result']['result'].get('value');print('ICCU',val and {k:v for k,v in val.items()if k!='body'});
if val:P.joinpath('iccu-nursing-final-browser.pdf').write_bytes(base64.b64decode(val['body']))
