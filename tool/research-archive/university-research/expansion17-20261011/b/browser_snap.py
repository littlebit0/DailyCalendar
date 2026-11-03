import pathlib,json,websocket,time,sys
P=pathlib.Path(__file__).parent;c=json.loads((P/'browser-target.json').read_text());w=websocket.create_connection(c['webSocketDebuggerUrl'],origin='http://localhost:64244',timeout=25);idx=0

def call(method,params={}):
 global idx
 idx+=1;request_id=idx;w.send(json.dumps({'id':request_id,'method':method,'params':params}))
 while 1:
  m=json.loads(w.recv())
  if m.get('id')==request_id:return m.get('result',{})
expr="JSON.stringify({url:location.href,title:document.title,text:document.body.innerText,html:document.documentElement.outerHTML,links:Array.from(document.querySelectorAll('a')).map(x=>({text:x.innerText,url:x.href})),forms:Array.from(document.forms).map(x=>({action:x.action,method:x.method,text:x.innerText})),frames:Array.from(document.querySelectorAll('iframe')).map(x=>({src:x.src}))})"
for name,url in json.loads(sys.argv[1]).items():
 call('Page.navigate',{'url':url});time.sleep(5);r=call('Runtime.evaluate',{'expression':expr,'returnByValue':True});v=json.loads(r['result']['value']);(P/(name+'-browser.json')).write_text(json.dumps(v,ensure_ascii=False,indent=2));print(name,v['url'],v['text'][:250],flush=True)
