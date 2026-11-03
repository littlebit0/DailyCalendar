import urllib.request,urllib.parse,re,json,time,pathlib,html
p=pathlib.Path('work/university-research/calendar-b'); out=[]
for dep in ['airhotel','hotelcook','garden_01','energy','avifix','defai']:
 u=f'https://www.namhae.ac.kr/{dep}/web/main/mainPage.do'
 try:
  req=urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0','Referer':'https://univ.namhae.ac.kr/namhae_01/web/main/mainPage.do'})
  s=urllib.request.urlopen(req,timeout=35).read().decode('utf-8','replace');s=re.sub(r';jsessionid=[^?"\s<]+',';jsessionid=REDACTED',s)
  (p/f'namhae-new-{dep}-main.html').write_text(s)
  links=[]
  for m in re.finditer(r'<a\b[^>]*href=[\"\']([^\"\']+)[\"\'][^>]*>(.*?)</a>',s,re.S|re.I):
   label=html.unescape(re.sub('<[^>]+>','',m[2])).strip(); h=html.unescape(m[1])
   if any(t in label for t in ['공지','학사','시간표']): links.append({'label':label,'url':urllib.parse.urljoin(u,h)})
  out.append({'dept':dep,'url':u,'bytes':len(s.encode()),'links':links}); print(dep,len(s),links[:12],flush=True)
 except Exception as e: out.append({'dept':dep,'url':u,'error':str(e)})
 time.sleep(.7)
(p/'namhae-new-department-published-links.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
