from urllib.request import Request,urlopen
from urllib.parse import urlencode
from pathlib import Path
import time,json
P=Path(__file__).parent
a=[]
u='https://www.yongin.ac.kr/cmn/cmm/fms/selectFileListJson.do'
try:
 with urlopen(Request(u,data=urlencode({'atchFileId':'FILE_000000000018610'}).encode(),headers={'User-Agent':'Mozilla/5.0','Referer':'https://www.yongin.ac.kr/cmn/board/SYSTEM_DEFAULT000001/6761noticeDetail.do?currentMenuNo=106100000'}),timeout=30) as r:b=r.read();print('yongin list',r.status,len(b),flush=True)
 (P/'yongin-current-attachments.json').write_bytes(b)
except Exception as e:print(type(e).__name__,flush=True)
for key,no in [('hknu-2026-2-anseong.xlsx',113582),('hknu-2026-2-pyeongtaek.xlsx',113583),('hknu-2026-2-credit-exceptions.xlsx',113584)]:
 u=f'https://www.hknu.ac.kr/bbs/hkhuman/620/{no}/download.do'
 try:
  with urlopen(Request(u,headers={'User-Agent':'Mozilla/5.0','Referer':'https://www.hknu.ac.kr/bbs/hkhuman/620/97264/artclView.do'}),timeout=30) as r:b=r.read();a.append({'file':key,'url':u,'status':r.status,'bytes':len(b)})
  (P/key).write_bytes(b);print(key,len(b),flush=True)
 except Exception as e:a.append({'file':key,'url':u,'error':str(e)[:150]});print(key,type(e).__name__,flush=True)
 time.sleep(.7)
(P/'attachment-requests2.json').write_text(json.dumps(a,ensure_ascii=False,indent=2))
