import concurrent.futures,html,json,pathlib,urllib.request,hashlib
from PIL import Image,ImageOps
root=pathlib.Path('work/academic-region-logos-20261011');items=json.loads((root/'candidates.json').read_text());dest=pathlib.Path('assets/academic/logos');dest.mkdir(exist_ok=True)
def fetch(item):
 iid,entry=item;slug=iid.replace(':','-');raw=root/(slug+'.raw')
 try:
  if not raw.exists():
   req=urllib.request.Request(entry['url'],headers={'Referer':'https://m.academyinfo.go.kr/','User-Agent':'Mozilla/5.0'})
   raw.write_bytes(urllib.request.urlopen(req,timeout=30).read())
  image=Image.open(raw);image.load();image=ImageOps.exif_transpose(image).convert('RGBA');image.thumbnail((192,192),Image.Resampling.LANCZOS)
  asset=dest/(slug+'.png');image.save(asset)
  return iid,{**entry,'asset':str(asset),'sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'size':list(image.size)}
 except Exception as e:return iid,{'name':entry['name'],'error':str(e)}
with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
 results=dict(pool.map(fetch,items.items()))
(root/'download-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
print('success',sum('asset' in x for x in results.values()),'failures',[(k,v) for k,v in results.items() if 'error' in v])
