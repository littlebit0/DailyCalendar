import json,re,html,urllib.request,concurrent.futures,pathlib
root=pathlib.Path('work/academic-region-ui-20261011');cache=root/'addresses';cache.mkdir(exist_ok=True)
j=json.load(open('assets/academic/universities.json'))
rows=[r for r in j['universities'] if r['kind']=='fourYear' and r.get('selectable',True)]
def fetch(r):
 sid=r.get('sourceSchoolId');
 if not sid:return (r['id'],None)
 p=cache/(sid+'.html')
 try:
  if not p.exists():p.write_bytes(urllib.request.urlopen('https://m.academyinfo.go.kr/pubinfo/pubinfo0020/list.do?schlId='+sid,timeout=25).read())
  s=p.read_text();m=re.search(r'MAP.html\?addr=([^&]+)&',s)
  return (r['id'],html.unescape(m.group(1)).strip() if m else None)
 except Exception as e:return (r['id'],None)
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:res=dict(pool.map(fetch,rows))
(root/'source-addresses.json').write_text(json.dumps(res,ensure_ascii=False,indent=2))
print('selectable rows',len(rows),'addresses',sum(x is not None for x in res.values()));print('missing',[(r['id'],r['name'],r.get('region')) for r in rows if res[r['id']] is None])
