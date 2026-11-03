exec(open('work/full-timetable-audit-20261012/sunmoon-other-depts-c/follow_links.py').read().split('o=list(')[0])
def g(row):
 vs=row.get('visited',[])
 if not vs:return row
 v=vs[-1];p=Path(v.get('file',''))
 if not p.is_file():return row
 s=p.read_text(errors='replace'); links=re.findall(r'href=[\'"]([^\'"]*main\.do[^\'"]*)',s)
 if not links:return {**row,'mainStatus':'no actual main link'}
 u=urllib.parse.urljoin(v['url'],links[0]);host=urllib.parse.urlparse(u).hostname.split('.')[0]
 try:
  rr=urllib.request.urlopen(u,timeout=15);b=rr.read();p=r/(host+'-main.html');p.write_bytes(b);pa=P();pa.feed(b.decode(errors='replace'))
  return {**row,'main':{'url':u,'file':str(p),'sha256':hashlib.sha256(b).hexdigest(),'links':pa.links}}
 except Exception as e:return {**row,'main':{'url':u,'blocked':str(e)}}
o=list(concurrent.futures.ThreadPoolExecutor(8).map(g,json.loads((r/'main-ledger.json').read_text())));(r/'notice-menu-ledger.json').write_text(json.dumps(o,ensure_ascii=False,indent=2))
for a in o:
 if a.get('main'):print(a['name'],a['main'].get('links',a['main']))
