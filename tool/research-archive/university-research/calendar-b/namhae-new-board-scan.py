import urllib.request,urllib.parse,re,json,time,pathlib,html
p=pathlib.Path('work/university-research/calendar-b');out=[]
for d in json.loads((p/'namhae-new-department-published-links.json').read_text()):
 urls=list(dict.fromkeys(x['url'] for x in d['links'] if 'selectBoardList' in x['url']))
 for u in urls:
  for kw in ['학사','계절']:
   q=u+'&'+urllib.parse.urlencode({'searchCnd':'0','searchWrd':kw,'pageIndex':'1'})
   try:
    s=urllib.request.urlopen(urllib.request.Request(q,headers={'User-Agent':'Mozilla/5.0','Referer':d['url']}),timeout=35).read().decode('utf-8','replace');s=re.sub(r';jsessionid=[^?"\s<]+',';jsessionid=REDACTED',s)
    f=f"namhae-new-{d['dept']}-{kw}.html";(p/f).write_text(s)
    texts=[html.unescape(re.sub('<[^>]+>',' ',x)).strip() for x in re.findall(r'<tr\b[^>]*>(.*?)</tr>',s,re.S)]
    candidates=[re.sub(r'\s+',' ',x) for x in texts if kw in x and '검색' not in x and '제목' not in x]
    out.append({'dept':d['dept'],'url':q,'file':f,'candidateRows':candidates});print(d['dept'],kw,candidates,flush=True)
   except Exception as e:out.append({'dept':d['dept'],'url':q,'error':str(e)})
   time.sleep(.7)
(p/'namhae-new-department-search-audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
