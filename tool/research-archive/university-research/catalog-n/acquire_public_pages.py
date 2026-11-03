from urllib.request import Request,urlopen
from pathlib import Path
import time,re,html,json
P=Path(__file__).parent
sources={'yongin-current-notice':'https://www.yongin.ac.kr/cmn/board/SYSTEM_DEFAULT000001/6761noticeDetail.do?currentMenuNo=106100000','hknu-current-board':'https://www.hknu.ac.kr/hkhuman/6082/subview.do','tuk-current-notice':'https://www.tukorea.ac.kr/ce/1850/subview.do?enc=Zm5jdDF8QEB8JTJGYmJzJTJGY2UlMkYyMDElMkYxNTE3MDMlMkZhcnRjbFZpZXcuZG8lM0Y%3D'}
a=[]
for key,url in sources.items():
 try:
  with urlopen(Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as r:
   b=r.read();(P/f'{key}.html').write_bytes(b);a.append({'key':key,'url':url,'status':r.status,'bytes':len(b)}); print(key,r.status,len(b),flush=True)
  s=b.decode('utf-8');links=[]
  for attrs,body in re.findall(r'<a\b([^>]+)>(.*?)</a>',s,re.S):
   label=re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]+>',' ',body))).strip()
   if any(x in label for x in ['2026','시간표','교과','수강신청']) or any(x in attrs for x in ['download','fileDown']):links.append({'attributes':attrs,'label':label})
  (P/f'{key}-published-links.json').write_text(json.dumps(links,ensure_ascii=False,indent=2))
 except Exception as e:a.append({'key':key,'url':url,'error':str(e)[:150]});print(key,type(e).__name__,flush=True)
 time.sleep(.7)
(P/'requests.json').write_text(json.dumps(a,ensure_ascii=False,indent=2))
