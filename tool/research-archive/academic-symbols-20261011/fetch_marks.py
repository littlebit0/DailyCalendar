import concurrent.futures,pathlib,json,re,html,urllib.request
root=pathlib.Path('work/academic-symbols-20261011');cache=root/'adiga';cache.mkdir(exist_ok=True)
old=json.load(open('assets/academic/university_logo_sources.json'))['logos'];rows={k:v for k,v in old.items() if k.startswith('institution:academyinfo:')}
def fetch(item):
 iid,row=item;sid=iid.split(':')[-1];url='https://www.adiga.kr/ucp/uvt/uni/univDetailSelection.do?menuId=PCUVTINF2000&searchSyr=2026&unvCd='+sid
 try:
  p=cache/(sid+'.html')
  if not p.exists():p.write_bytes(urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=20).read())
  s=p.read_text();m=re.search(r'<img[^>]+src="([^"]+)"[^>]+class="logoImg"',s)
  return iid,{'name':row['name'],'page':url,'url':'https://www.adiga.kr'+html.unescape(m[1]) if m else None}
 except Exception as e:return iid,{'name':row['name'],'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:results=dict(pool.map(fetch,rows.items()))
(root/'adiga-candidates.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print('Retrieved school logo sources:',sum(bool(x.get('url')) for x in results.values()),'of',len(results))
print('Missing:',[(x['name'],x.get('error','no mark')) for x in results.values() if not x.get('url')])
