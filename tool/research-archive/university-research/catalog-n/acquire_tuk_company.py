from pathlib import Path
from urllib.request import Request,urlopen
import json,re,time
P=Path(__file__).parent
requests=[]
for notice in json.loads((P/'tuk-company-timetable-published-attachments.json').read_text()):
 for item in notice['links']:
  path=re.search(r'href="([^"]+)"',item['attributes'])[1]
  url='https://contract.tukorea.ac.kr'+path;fileid=path.split('/')[-2]
  try:
   with urlopen(Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=35) as response:
    body=response.read();status=response.status
   if not body.startswith(b'%PDF'):raise ValueError('Not published PDF')
   (P/f'tuk-company-{fileid}.pdf').write_bytes(body)
   requests.append({'notice':notice['url'],'url':url,'label':item['label'],'bytes':len(body),'status':status})
   print(fileid,status,len(body),flush=True)
  except Exception as exc:
   requests.append({'url':url,'error':type(exc).__name__});print(fileid,type(exc).__name__,flush=True)
  time.sleep(.7)
(P/'tuk-company-attachment-requests.json').write_text(json.dumps(requests,ensure_ascii=False,indent=2))
