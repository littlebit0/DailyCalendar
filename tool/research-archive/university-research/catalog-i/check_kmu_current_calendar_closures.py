import json
from pathlib import Path
import urllib.request
import time

root = Path(__file__).parent
sources = [
    ('kmu-current-calendar-2026.html', 'https://www.kmu.ac.kr/uni/main/page.jsp?mnu_uid=3373&parm_doc_year=2026'),
    ('kmu-current-closures-2026-2.html', 'https://www2.kmu.ac.kr/uni/main/page.jsp?cmd=2&mnu_uid=144&parm_bod_uid=270416'),
]
audit=[]
for filename, url in sources:
    try:
        response = urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'}), timeout=30)
        data=response.read(8000001)
        if response.status != 200 or len(data)>8000000:
            raise ValueError('Invalid public response')
        (root/filename).write_bytes(data)
        audit.append({'url':url,'file':filename,'status':response.status,'bytes':len(data)})
        print(filename, response.status, len(data), flush=True)
    except Exception as error:
        audit.append({'url':url,'file':filename,'error':type(error).__name__})
        print(filename,type(error).__name__,flush=True)
    time.sleep(.8)
(root/'kmu-current-calendar-closures-request-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
