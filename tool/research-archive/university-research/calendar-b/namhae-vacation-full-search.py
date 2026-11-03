import urllib.request,urllib.parse,pathlib,re,html,time,json
p=pathlib.Path('work/university-research/calendar-b');out=[]
for i in range(2,16):
 u='https://univ.namhae.ac.kr/namhae_01/web/searchTotal.do?'+urllib.parse.urlencode({'searchCnd':'0','searchWrd':'방학','pageIndex':i})
 try:
  s=urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0','Referer':'https://univ.namhae.ac.kr/namhae_01/web/main/mainPage.do'}),timeout=35).read().decode('utf-8','replace');s=re.sub(r';jsessionid=[^?"\s<]+',';jsessionid=REDACTED',s);f=f'namhae-vacation-search-page-{i}.html';(p/f).write_text(s)
  rows=[]
  for block in re.findall(r'<ul class="search_all_board">(.*?)</ul>',s,re.S):
   m=re.search(r'<li[^>]*class="tt"[^>]*onclick="location.href=\x27([^\x27]+)\x27"[^>]*>(.*?)</li>',block,re.S)
   if not m:continue
   t=html.unescape(re.sub('<[^>]+>',' ',m[2])).strip();d=re.search(r'<li class="date">(.*?)</li>',block,re.S);rows.append({'title':t,'date':d[1].strip() if d else None,'url':urllib.parse.urljoin(u,html.unescape(m[1]))})
  out.append({'page':i,'url':u,'file':f,'rows':rows});print(i,rows,flush=True)
 except Exception as e:out.append({'page':i,'url':u,'error':str(e)})
 time.sleep(.7)
(p/'namhae-vacation-full-search-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
