import urllib.request,json,sys
from pathlib import Path
R=Path(__file__).parent
name,url,body,typ=sys.argv[1:]
try:
 req=urllib.request.Request(url,data=body.encode(),headers={'User-Agent':'Mozilla/5.0','Content-Type':typ})
 with urllib.request.urlopen(req,timeout=45) as q:
  b=q.read();(R/name).write_bytes(b);r={'file':name,'method':'POST','url':url,'body':body,'contentType':typ,'finalUrl':q.url,'status':q.status,'bytes':len(b)}
except Exception as e:r={'file':name,'url':url,'error':str(e)}
a=json.loads((R/'requests.json').read_text());a.append(r);(R/'requests.json').write_text(json.dumps(a,ensure_ascii=False,indent=2));print(r)
