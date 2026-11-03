import pathlib,urllib.request,re,html,urllib.parse,json,time
p=pathlib.Path('work/university-research/calendar-b');out=[]
for name,u in [('aerospace','https://www.changwon.ac.kr/aerospace/cm/cntnts/cntntsView.do?cntntsId=6642&mi=18400'),('central-sugang','https://chains.changwon.ac.kr/nonstop/suup/sugang/hakbu/index.php'),('gast','https://www.changwon.ac.kr/gast/main.do')]:
 try:
  s=urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'Mozilla/5.0'}),timeout=35).read().decode('utf-8','replace');s=re.sub(r';jsessionid=[^?"\s<]+',';jsessionid=REDACTED',s);f=f'changwon-sacheon-{name}.html';(p/f).write_text(s)
  links=[]
  for m in re.finditer('<a\\b[^>]*href=[\"\x27]([^\"\x27]+)[\"\x27][^>]*>(.*?)</a>',s,re.S|re.I):
   t=re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]+>',' ',m[2]))).strip()
   if any(x in t for x in ['학사일정','수강신청','학부공지']):links.append({'label':t,'url':urllib.parse.urljoin(u,html.unescape(m[1]))})
  out.append({'name':name,'source':u,'file':f,'publishedLinks':links});print(name,links,flush=True)
 except Exception as e:out.append({'name':name,'source':u,'error':str(e)})
 time.sleep(.7)
(p/'changwon-sacheon-scope-links.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
