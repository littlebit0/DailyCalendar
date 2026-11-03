import requests,websocket,json,time,pathlib
P=pathlib.Path(__file__).parent;pg=next(p for p in requests.get('http://localhost:64244/json').json()if p['type']=='page');w=websocket.create_connection(pg['webSocketDebuggerUrl'],origin='http://localhost:64244',timeout=5);idx=0;dialogs=[]
def send(method,params):
 global idx
 idx+=1;w.send(json.dumps({'id':idx,'method':method,'params':params}));return idx
send('Page.handleJavaScriptDialog',{'accept':True});send('Page.navigate',{'url':'https://cn.hongik.ac.kr/app/timetable/'});time.sleep(3)
send('Runtime.evaluate',{'expression':"document.querySelector('a[href=\"hak03.jsp\"]').click()"});end=time.time()+6
while time.time()<end:
 try:
  m=json.loads(w.recv())
  if m.get('method')=='Page.javascriptDialogOpening':dialogs.append(m['params']['message']);send('Page.handleJavaScriptDialog',{'accept':True})
 except websocket.WebSocketTimeoutException:break
n=send('Runtime.evaluate',{'expression':'JSON.stringify({url:location.href,html:document.querySelector("iframe").contentDocument.documentElement.outerHTML,text:document.querySelector("iframe").contentDocument.body.innerText})','returnByValue':True})
while 1:
 m=json.loads(w.recv())
 if m.get('id')==n:break
v=json.loads(m['result']['result']['value']);v['dialogs']=dialogs;P.joinpath('hongik-official-root-ui.json').write_text(json.dumps(v,ensure_ascii=False,indent=2));print(v['text'][:200],dialogs)
