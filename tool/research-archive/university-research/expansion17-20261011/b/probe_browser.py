import requests,websocket,json,time,pathlib
P=pathlib.Path(__file__).parent
info=requests.get('http://localhost:64244/json/version').json();bw=websocket.create_connection(info['webSocketDebuggerUrl'],origin='http://localhost:64244',timeout=25);idx=0

def call(w,method,params={}):
 global idx
 idx+=1;w.send(json.dumps({'id':idx,'method':method,'params':params}))
 while 1:
  m=json.loads(w.recv())
  if m.get('id')==idx:return m.get('result',{})
ctx=call(bw,'Target.createBrowserContext',{'disposeOnDetach':False})['browserContextId'];target=call(bw,'Target.createTarget',{'url':'about:blank','browserContextId':ctx,'background':True})['targetId'];page=next(p for p in requests.get('http://localhost:64244/json').json() if p['id']==target);w=websocket.create_connection(page['webSocketDebuggerUrl'],origin='http://localhost:64244',timeout=25);call(w,'Page.enable');call(w,'Runtime.enable');call(w,'Network.enable')
expression='''JSON.stringify({url:location.href,title:document.title,text:document.body.innerText,html:document.documentElement.outerHTML,links:Array.from(document.querySelectorAll('a')).map(x=>({text:x.innerText,url:x.href})),forms:Array.from(document.forms).map(x=>({action:x.action,method:x.method,text:x.innerText})),frames:Array.from(document.querySelectorAll('iframe')).map(x=>({src:x.src,text:(()=>{try{return x.contentDocument.body.innerText}catch(e){return 'cross-origin'}})(),html:(()=>{try{return x.contentDocument.documentElement.outerHTML}catch(e){return ''}})()}))})'''
for name,url in [('hansei-sugang','https://sugang.hansei.ac.kr/'),('sunmoon-sws','https://sws.sunmoon.ac.kr/'),('kentech-main','https://www.kentech.ac.kr/')]:
 call(w,'Page.navigate',{'url':url});time.sleep(6);r=call(w,'Runtime.evaluate',{'expression':expression,'returnByValue':True});v=json.loads(r['result']['value']);(P/(name+'-browser.json')).write_text(json.dumps(v,ensure_ascii=False,indent=2));print(name,v['url'],v['text'][:200],[(x['src'],x['text'][:300]) for x in v['frames']],flush=True)
(P/'browser-target.json').write_text(json.dumps({'targetId':target,'browserContextId':ctx,'webSocketDebuggerUrl':page['webSocketDebuggerUrl']}));w.close();bw.close()
