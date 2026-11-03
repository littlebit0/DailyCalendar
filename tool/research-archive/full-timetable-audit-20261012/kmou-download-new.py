import pathlib,json,urllib.request,concurrent.futures,hashlib
from pypdf import PdfReader
D=pathlib.Path(__file__).parent/'kmou-current-new-notices';r=json.loads((D/'receipt.json').read_text());links=[]
for row in r:
 if '10377145' in row['url']:continue
 for a in row['downloads']:links.append({**a,'noticeUrl':row['url']})
def f(a):
 k=a['url'].split('fileKey=')[1];suffix='.xlsx' if a['label'].endswith('xlsx') else '.pdf';p=D/(k+suffix)
 try:
  with urllib.request.urlopen(a['url'],timeout=25) as r:b=r.read()
  p.write_bytes(b);out={**a,'file':str(p),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
  if suffix=='.pdf':
   pdf=PdfReader(p);tx=[]
   for i,page in enumerate(pdf.pages):tx.append({'page':i+1,'text':page.extract_text()})
   (D/(k+'.pages.json')).write_text(json.dumps(tx,ensure_ascii=False,indent=2));out['pages']=len(tx)
  return out
 except Exception as e:return {**a,'error':str(e)}
out=list(concurrent.futures.ThreadPoolExecutor(4).map(f,links));(D/'download-receipt.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False,indent=2))
