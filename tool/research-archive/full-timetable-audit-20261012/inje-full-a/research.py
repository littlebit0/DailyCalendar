import subprocess,json,concurrent.futures
from pathlib import Path
from lxml import html
p=Path(__file__).parent
hosts=['aibigdata','biz','see','elec','cs','game','law','welfare','sangdam','police-pa','interior','bio','biomls','injept','ilac','emergency','rad','ipse','smartlogistics','webtoon','ev','contents','food','ot']
def run(host):
 u=f'https://{host}.inje.ac.kr/'
 try:
  out=p/f'{host}-home.html'; r=subprocess.run(['curl','-L','--max-time','18','-sS','-o',str(out),'-w','%{http_code} %{url_effective}',u],capture_output=True,text=True); content=out.read_bytes() if out.exists() else b''; meta=r.stdout.split(' ',1)
  if r.returncode: raise RuntimeError(r.stderr)
  s=html.fromstring(content);links=[]
  for a in s.xpath('//a[@href]'):
   t=' '.join(a.text_content().split());h=a.get('href')
   if any(x in t for x in ['시간표','수강','공지','학사','교육과정']):links.append({'text':t,'href':h})
  return {'host':host,'url':u,'actualUrl':meta[1],'status':int(meta[0]),'links':links}
 except Exception as e:return {'host':host,'url':u,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex: rows=list(ex.map(run,hosts))
(p/'department-home-receipts.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
for r in rows:
 print(r['host'],r.get('status',r.get('error','')))
 for a in r.get('links',[]):
  if any(x in a['text'] for x in ['시간표','수강']):print(' ',a)
