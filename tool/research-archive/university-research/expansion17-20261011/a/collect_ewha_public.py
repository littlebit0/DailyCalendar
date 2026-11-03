import requests,websocket,json,pathlib,xml.etree.ElementTree as E,time
P=pathlib.Path(__file__).parent
pg=next(p for p in requests.get('http://localhost:64244/json').json() if p['type']=='page');w=websocket.create_connection(pg['webSocketDebuggerUrl'],origin='http://localhost:64244',timeout=45);idx=0
v=json.loads(json.load(open(P/'ewha-runtime-codes.json'))['result']['value']);codes=[{c.attrib['id']:c.text or '' for c in r}for r in E.fromstring(v['universities']).findall('./Rows/Row')]
for c in codes:
 idx+=1;expr="new Promise((resolve,reject)=>{let f=application.mainframe.VFrameSet.WorkFrame.Child_.form.div_Work;f.srch.setColumn(0,'UNIV_CD',"+json.dumps(c['UNIV_CD'])+");f.tran('selectGrid').after(()=>resolve(JSON.stringify({columns:Array.from({length:f.dsGrid.colcount},(_,i)=>f.dsGrid.getColID(i)),rows:Array.from({length:f.dsGrid.rowcount},(_,r)=>Object.fromEntries(Array.from({length:f.dsGrid.colcount},(_,i)=>[f.dsGrid.getColID(i),f.dsGrid.getColumn(r,i)])))})));setTimeout(()=>reject('timeout'),30000);})"
 w.send(json.dumps({'id':idx,'method':'Runtime.evaluate','params':{'expression':expr,'returnByValue':True,'awaitPromise':True}}))
 while True:
  m=json.loads(w.recv())
  if m.get('id')==idx:break
 result=m.get('result',{}).get('result',{});xml=result.get('value')
 if not xml:print('FAILED',c['UNIV_CD'],str(m)[:160]);continue
 P.joinpath('ewha-native-'+c['UNIV_CD']+'.json').write_text(xml)
 rows=json.loads(xml)['rows'];print(c['UNIV_CD'],c['UNIV_NM_KOR'],len(rows),flush=True)
 time.sleep(.15)
