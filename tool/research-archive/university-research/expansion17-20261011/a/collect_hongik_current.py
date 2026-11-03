import requests,websocket,json,time,pathlib
P=pathlib.Path(__file__).parent;p=next(p for p in requests.get('http://localhost:64244/json').json() if p['type']=='page' and 'cn.hongik.ac.kr' in p.get('url',''));w=websocket.create_connection(p['webSocketDebuggerUrl'],origin='http://localhost:64244',timeout=35);seq=0
def ev(e):
 global seq
 seq+=1;w.send(json.dumps({'id':seq,'method':'Runtime.evaluate','params':{'expression':e,'returnByValue':True,'awaitPromise':True}}))
 while True:
  m=json.loads(w.recv())
  if m.get('id')==seq:return m['result']['result'].get('value')
links=ev("Array.from(document.querySelector('iframe').contentDocument.querySelectorAll('a')).map(a=>({text:a.innerText,href:a.getAttribute('href')})).filter(a=>a.href.startsWith('javascript:goDetail01'))")
P.joinpath('hongik-campus-links.json').write_text(json.dumps(links,ensure_ascii=False,indent=2))
import re
for i,l in enumerate(links):
 args=re.findall("'([^']*)'",l['href']);v=ev("""(async()=>{const a=%s,w=document.querySelector('iframe').contentWindow,f=w.document.forms[1];f.p_type.value='1';['p_ibhak','p_campus','p_gubun','p_dept','p_grade'].forEach((k,i)=>f.elements[k].value=a[i]);const r=await w.fetch(f.action,{method:'POST',body:new URLSearchParams(new FormData(f))});return {status:r.status,html:await r.text()}})()"""%json.dumps(args))
 P.joinpath('hongik-group-%02d.html'%i).write_text(v['html']);print(i,args,l['text'],v['status'],len(v['html']),flush=True);time.sleep(.25)
