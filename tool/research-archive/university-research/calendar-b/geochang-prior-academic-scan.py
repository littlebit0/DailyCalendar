import urllib.request,urllib.parse,re,json,time,pathlib,html
p=pathlib.Path('work/university-research/calendar-b');out=[];u='https://www.gc.ac.kr/CW0401/101001.asp'
for kw in ['학사','성적','2025학년도 2학기','2026학년도 1학기']:
 try:
  req=urllib.request.Request(u,data=urllib.parse.urlencode({'select1':'title','s_text':kw}).encode(),headers={'User-Agent':'Mozilla/5.0','Referer':u})
  s=urllib.request.urlopen(req,timeout=35).read().decode('utf-8','replace');f='geochang-central-prior-'+str(len(out))+'.html';(p/f).write_text(s)
  matches=[]
  for m in re.finditer(r'<a\b[^>]*href=[\"\']([^\"\']*bno=[^\"\']+)[\"\'][^>]*>(.*?)</a>',s,re.S|re.I):
   title=re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]+>',' ',m[2]))).strip();matches.append({'title':title,'url':urllib.parse.urljoin(u,html.unescape(m[1]))})
  out.append({'keyword':kw,'method':'POST','url':u,'parameters':{'select1':'title','s_text':kw},'file':f,'items':matches});print(kw,matches,flush=True)
 except Exception as e:out.append({'keyword':kw,'error':str(e)})
 time.sleep(.7)
(p/'geochang-prior-academic-search-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
