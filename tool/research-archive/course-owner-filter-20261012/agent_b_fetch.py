import urllib.request,json,concurrent.futures
from pathlib import Path
urls={'hufs':'https://www.hufs.ac.kr/hufs/index.do','inha':'https://www.inha.ac.kr/','inje':'https://www.inje.ac.kr/kor/','kmu':'https://www.kmu.ac.kr/','kangnam':'https://web.kangnam.ac.kr/','kau':'https://www.kau.ac.kr/','kmou':'https://www.kmou.ac.kr/kmou/main.do','knue':'https://www.knue.ac.kr/www/index.do','kongju':'https://www.kongju.ac.kr/','konkuk':'https://www.konkuk.ac.kr/konkuk/index.do','korea':'https://www.korea.ac.kr/','koreatech':'https://www.koreatech.ac.kr/','kumoh':'https://www.kumoh.ac.kr/ko/index.do','kunsan':'https://www.kunsan.ac.kr/','kyonggi':'https://www.kyonggi.ac.kr/','mju':'https://www.mju.ac.kr/','mmu':'https://www.mmu.ac.kr/','mokpo':'https://www.mokpo.ac.kr/','nambu':'https://www.nambu.ac.kr/content/view.do?menuCd=KR002004001','nsu':'https://www.nsu.ac.kr/','iccu':'https://www.iccu.ac.kr/','jnue':'https://www.jnue.kr/'}
root=Path('work/course-owner-filter-20261012');result=[]
def fetch(pair):
 u,url=pair
 try:
  r=urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=35);raw=r.read();encoding=r.headers.get_content_charset() or 'utf-8'
  try:s=raw.decode(encoding)
  except UnicodeDecodeError:s=raw.decode('euc-kr',errors='replace')
  f=root/(u+'-official-home.html');f.write_text(s);return {'university':u,'url':url,'finalUrl':r.url,'sourceFile':str(f),'length':len(s)}
 except Exception as e:return {'university':u,'url':url,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 for r in pool.map(fetch,urls.items()):result.append(r);print(r['university'],r.get('length',r.get('error')),flush=True)
(root/'agent-b-official-page-receipts.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
