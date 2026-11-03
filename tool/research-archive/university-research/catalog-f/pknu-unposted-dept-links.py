import urllib.request,re,html,urllib.parse,pathlib,json,time
p=pathlib.Path('work/university-research/catalog-f');out=[]
urls=['https://mbe.pknu.ac.kr/mbe/5478?action=view&no=9988417','https://induseng.pknu.ac.kr/ecoeng/5666?action=view&no=9990226']
for i,u in enumerate(urls):
 try:
  s=urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=35).read().decode('utf-8','replace');f=f'pknu-unposted-dept-entry-{i}.html';(p/f).write_text(s);links=[]
  for m in re.finditer(r'<a\b[^>]*href=[\"\']([^\"\']+)[\"\'][^>]*>(.*?)</a>',s,re.S|re.I):
   t=re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]+>',' ',m[2]))).strip()
   if any(x in t for x in ['시간표','교육과정','공지','수강']):links.append({'label':t,'url':urllib.parse.urljoin(u,html.unescape(m[1]))})
  out.append({'source':u,'file':f,'links':links});print(u,links,flush=True)
 except Exception as e:out.append({'source':u,'error':str(e)})
 time.sleep(.7)
(p/'pknu-unposted-department-published-links.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
