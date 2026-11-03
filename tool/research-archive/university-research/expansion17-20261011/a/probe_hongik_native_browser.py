import requests,websocket,json,time,pathlib
P=pathlib.Path(__file__).parent;pg=next(p for p in requests.get('http://localhost:64244/json').json()if p['type']=='page');w=websocket.create_connection(pg['webSocketDebuggerUrl'],origin='http://localhost:64244',timeout=12);idx=0
def send(method,p):
 global idx
 idx+=1;w.send(json.dumps({'id':idx,'method':method,'params':p}));return idx
send('Page.enable',{});send('Page.navigate',{'url':'https://cn.hongik.ac.kr/app/timetable/hak02.jsp'});time.sleep(3)
send('Runtime.evaluate',{'expression':"document.detail01.target='_self';goDetail01('2022','1','2','A200','0')"});end=time.time()+8;dialogs=[]
while time.time()<end:
 try:
  m=json.loads(w.recv())
  if m.get('method')=='Page.javascriptDialogOpening':
   dialogs.append(m['params']['message']);send('Page.handleJavaScriptDialog',{'accept':True})
 except websocket.WebSocketTimeoutException:break
n=send('Runtime.evaluate',{'expression':'JSON.stringify({url:location.href,text:document.body.innerText,html:document.documentElement.outerHTML})','returnByValue':True})
while 1:
 m=json.loads(w.recv())
 if m.get('id')==n:break
v=json.loads(m['result']['result']['value']);v['dialogs']=dialogs;P.joinpath('hongik-native-browser.json').write_text(json.dumps(v,ensure_ascii=False,indent=2));print(v['url'],v['text'][:200],dialogs)
