from pathlib import Path
from urllib.request import Request,urlopen
import time,re,json
P=Path(__file__).parent
sources={'yongin-file-library':'https://www.yongin.ac.kr/js/wvtex/jquery.wvtex.file.user.js?ver=1','hknu-current-full-notice':'https://www.hknu.ac.kr/bbs/hkhuman/620/97264/artclView.do','hknu-current-registration-notice':'https://www.hknu.ac.kr/bbs/hkhuman/620/97262/artclView.do','tuk-2026-2-guide.pdf':'https://www.tukorea.ac.kr/bbs/ce/201/49831/download.do','tuk-2026-2-general.pdf':'https://www.tukorea.ac.kr/bbs/ce/201/49833/download.do','tuk-2026-2-fusion.pdf':'https://www.tukorea.ac.kr/bbs/ce/201/49834/download.do'}
a=[]
for key,u in sources.items():
 try:
  with urlopen(Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=40) as r:
   b=r.read();a.append({'key':key,'url':u,'status':r.status,'bytes':len(b),'contentType':r.headers.get('Content-Type')})
  if not key.endswith('.pdf'):
   b=re.sub(rb';jsessionid=[A-Za-z0-9._-]+',b';jsessionid=[REDACTED]',b,flags=re.I)
  (P/(key if key.endswith('.pdf') else key+'.html')).write_bytes(b); print(key,len(b),flush=True)
 except Exception as e:a.append({'key':key,'url':u,'error':str(e)[:160]}); print(key,type(e).__name__,flush=True)
 time.sleep(.7)
(P/'attachment-requests.json').write_text(json.dumps(a,ensure_ascii=False,indent=2))
