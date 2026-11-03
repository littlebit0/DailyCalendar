import subprocess,json,concurrent.futures
from pathlib import Path
from lxml import html
from urllib.parse import urljoin
p=Path(__file__).parent
rows=json.loads((p/'department-home-receipts.json').read_text());targets=[]
for r in rows:
 for a in r.get('links',[]):
  if '공지' in a['text'] and a['href'] not in ['#','#a'] and 'articleNo' not in a['href']:
   u=urljoin(r['actualUrl'],a['href'])
   if '/community/' not in u: continue
   u=u.split('?')[0]+'?mode=list&srSearchKey=article_title&srSearchVal=%EC%8B%9C%EA%B0%84%ED%91%9C'
   if (r['host'],u) not in targets:targets.append((r['host'],u))
def run(x):
 h,u=x;f=p/f'{h}-search-time-{targets.index(x)}.html';r=subprocess.run(['curl','-L','--max-time','18','-sS','-o',str(f),'-w','%{http_code} %{url_effective}',u],capture_output=True,text=True)
 if r.returncode:return {'host':h,'url':u,'error':r.stderr}
 try:
  s=html.fromstring(f.read_bytes());l=[]
  for a in s.xpath('//a[@href]'):
   t=' '.join(a.text_content().split())
   if any(k in t for k in ['시간표','수강신청','개설','강의']):l.append({'text':t,'url':urljoin(u,a.get('href'))})
  return {'host':h,'url':u,'status':r.stdout,'links':l}
 except Exception as e:return {'host':h,'url':u,'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex: result=list(ex.map(run,targets))
(p/'department-search-time-receipts.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
for r in result:
 if r.get('links'):print(r['host'],r['links'])
print('pages',len(targets))
