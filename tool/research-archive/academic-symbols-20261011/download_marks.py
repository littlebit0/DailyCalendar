import pathlib,json,urllib.request,concurrent.futures,re,html
root=pathlib.Path('work/academic-symbols-20261011');raw=root/'marks';raw.mkdir(exist_ok=True)
j=json.load(open(root/'adiga-candidates.json'))
def fetch(item):
 k,v=item;p=raw/(k.split(':')[-1]+'.raw')
 try:
  if not p.exists():p.write_bytes(urllib.request.urlopen(urllib.request.Request(v['url'],headers={'Referer':v['page'],'User-Agent':'Mozilla/5.0'}),timeout=20).read())
  return k,{'raw':str(p),**v}
 except Exception as e:return k,{'error':str(e),**v}
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:rs=dict(pool.map(fetch,j.items()))
(root/'mark-downloads.json').write_text(json.dumps(rs,ensure_ascii=False,indent=2)+'\n');print('Collected',sum('raw' in x for x in rs.values()),'images')
s=pathlib.Path('work/academic-symbols-20261011/jungseok-official-news.html').read_text();m=re.search(r'<img[^>]+src="([^\"]+)"[^>]+alt="정석대학-제-18회-졸업식"',s)
if m:(root/'jungseok-official-photo.jpg').write_bytes(urllib.request.urlopen(html.unescape(m[1]),timeout=20).read())
