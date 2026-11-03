import urllib.request,urllib.parse,pathlib,json,hashlib,re,concurrent.futures
base=pathlib.Path(__file__).parent
items=[('cs','1053','40285'),('physical','1230','41010')]
def get(x):
 k,b,m=x;u=f'https://{k}.sunmoon.ac.kr/{k}/na/ntt/selectNttList.do'; fields={'bbsId':b,'mi':m,'currPage':'','listCo':'50','searchType':'all','searchValue':'시간표'}
 try:
  req=urllib.request.Request(u,data=urllib.parse.urlencode(fields).encode());r=urllib.request.urlopen(req,timeout=20);d=r.read();p=base/(k+'-timetable-search.html');p.write_bytes(d);s=d.decode('utf-8','replace');rows=[]
  for id,t in re.findall(r'<a[^>]*data-id="(\d+)"[^>]*>(.*?)</a>',s,re.S):
   t=re.sub('<.*?>','',t,flags=re.S);t=' '.join(t.split());rows.append({'nttSn':id,'title':t})
  return {'url':u,'method':'POST read-only actual srchForm','fields':fields,'file':str(p),'bytes':len(d),'sha256':hashlib.sha256(d).hexdigest(),'rows':rows}
 except Exception as e:return {'url':u,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:r=list(ex.map(get,items))
(base/'receipt-search.json').write_text(json.dumps(r,ensure_ascii=False,indent=2));print(json.dumps(r,ensure_ascii=False,indent=2))
