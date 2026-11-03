import urllib.request,urllib.parse,json,time
from pathlib import Path
p=Path(__file__).parent
out=[]
for id in ['113631-103','113633-103','114694-105','111214-103']:
 j=json.loads((p/f'pknu-syllabus-{id}-decoded.json').read_text())
 fields={'opcode':'700','mrd_path':j['path'],'mrd_param':j['param'],'mrd_plain_param':'','mrd_data':'','runtime_param':'','mmlVersion':'0','protocol':'sync'}
 url='https://reporting.pknu.ac.kr/ReportingServer/service'
 req=urllib.request.Request(url,data=urllib.parse.urlencode(fields).encode(),headers={'Content-Type':'application/x-www-form-urlencoded','Referer':'https://reporting.pknu.ac.kr/ReportingServer/embed','User-Agent':'Mozilla/5.0'})
 try:
  with urllib.request.urlopen(req,timeout=60) as f:b=f.read();st=f.status
  (p/f'pknu-syllabus-{id}.mml').write_bytes(b);print(id,st,len(b),b[:120]);out.append({'id':id,'status':st,'bytes':len(b),'url':url,'fields':list(fields),'publishedReadOpcode':700})
 except Exception as e:print(id,e);out.append({'id':id,'error':str(e)})
 time.sleep(.5)
(p/'pknu-syllabus-mml-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
