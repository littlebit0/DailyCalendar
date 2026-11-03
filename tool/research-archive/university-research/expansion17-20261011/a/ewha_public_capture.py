import requests,websocket,json,time,pathlib
P=pathlib.Path(__file__).parent
page=next(p for p in requests.get('http://localhost:64244/json').json() if p['type']=='page');ws=websocket.create_connection(page['webSocketDebuggerUrl'],origin='http://localhost:64244',timeout=5);idx=0;events=[]
def send(method,params={}):
 global idx
 idx+=1;ws.send(json.dumps({'id':idx,'method':method,'params':params}));return idx
send('Network.enable',{'maxPostDataSize':1000000});send('Runtime.enable');send('Page.navigate',{'url':'https://eureka.ewha.ac.kr/eureka/my/public.do?pgId=P531005519'})
end=time.time()+15
while time.time()<end:
 try:
  msg=json.loads(ws.recv());method=msg.get('method')
  if method=='Network.requestWillBeSent':
   r=msg['params']['request']
   if 'eureka.ewha.ac.kr' in r['url'] and r.get('postData'):
    events.append({'url':r['url'],'postData':r['postData']})
 except websocket.WebSocketTimeoutException:pass
P.joinpath('ewha-public-requests.json').write_text(json.dumps(events,ensure_ascii=False,indent=2))
print('public request count',len(events));print([(e['url'].split('/eureka/')[-1],e['postData'][:120].replace('\x1e','|'))for e in events if 'cmmController' in e['url']][:3])
# Keep browser open for native read-only lookup. No personal profile, no login.
