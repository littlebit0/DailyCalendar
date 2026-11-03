"""Published actual architecture PDFs, only educational page coordinates retained."""
import urllib.request,pathlib,io,json,hashlib,time,sys
import pdfplumber
R=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(R.parent/'catalog-g'))
from skku_inline_private_education_filter import filter_education
for name,url in [('architecture','https://www.hknu.ac.kr/bbs/hkdesignarch/591/114907/download.do'),('architectural-engineering','https://www.hknu.ac.kr/bbs/hkdesignarch/295/114693/download.do')]:
 with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as response:
  assert response.status==200;data=response.read(5000000);assert data.startswith(b'%PDF')
 pages=[]
 with pdfplumber.open(io.BytesIO(data)) as document:
  for page in document.pages:
   words=[]
   for word in page.extract_words():
    safe,masked,removed=filter_education(word['text'])
    if safe and not masked and not removed:words.append({**{k:word[k] for k in ['x0','x1','top','bottom']},'text':safe})
   # No full page text or phone/contact token retained.
   pages.append({'page':page.page_number,'width':page.width,'height':page.height,'educationalWords':words,'gridEdges':[{k:e.get(k) for k in ['x0','x1','top','bottom','orientation']} for e in page.edges]})
 result={'researchOnly':True,'sourceUrl':url,'readDate':'2026-10-08','publicPdfSHA256':hashlib.sha256(data).hexdigest(),'pages':pages}
 (R/f'hknu-current-{name}-education-grid-coordinates-20261008.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(name,'pages',len(pages));time.sleep(.8)
