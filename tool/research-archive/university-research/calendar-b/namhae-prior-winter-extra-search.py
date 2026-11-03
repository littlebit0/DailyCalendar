import urllib.request,urllib.parse,re,html,json,pathlib,time
p=pathlib.Path('work/university-research/calendar-b');out=[]
for kw in ['겨울','동기','방학','학점교류']:
 u='https://univ.namhae.ac.kr/namhae_01/web/searchTotal.do?'+urllib.parse.urlencode({'searchCnd':'0','searchWrd':kw,'pageIndex':'1'})
 try:
  s=urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0','Referer':'https://univ.namhae.ac.kr/namhae_01/web/main/mainPage.do'}),timeout=35).read().decode('utf-8','replace');s=re.sub(r';jsessionid=[^?"\s<]+',';jsessionid=REDACTED',s);f=f'namhae-prior-winter-extra-{len(out)}.html';(p/f).write_text(s)
  matches=[]
  for m in re.finditer(r'<li[^>]*class="tt"[^>]*onclick="location.href=\x27([^\x27]+)\x27"[^>]*>(.*?)</li>',s,re.S):matches.append({'title':html.unescape(re.sub('<[^>]+>',' ',m[2])).strip(),'url':urllib.parse.urljoin(u,html.unescape(m[1]))})
  out.append({'keyword':kw,'url':u,'file':f,'matches':matches});print(kw,matches,flush=True)
 except Exception as e:out.append({'keyword':kw,'url':u,'error':str(e)})
 time.sleep(.7)
(p/'namhae-prior-winter-additional-search-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
