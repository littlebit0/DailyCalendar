import io,json,hashlib,re,urllib.request
from pathlib import Path
from pypdf import PdfReader
p=Path(__file__).parent
url='https://yonseirc.yonsei.ac.kr/uc/guidance/click-yonsei.do?articleNo=12472&attachNo=12827&mode=download'
data=urllib.request.urlopen(url,timeout=45).read()
assert data.startswith(b'%PDF')
reader=PdfReader(io.BytesIO(data));hits=[]
for i,page in enumerate(reader.pages,1):
 t=page.extract_text() or ''
 for term in ['parenthes','bracket','괄호','강의시간 확인','실습시간']:
  for m in re.finditer(term,t,re.I):
   text=t[max(0,m.start()-200):m.end()+350]
   text=re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}','[contact omitted]',text)
   text=re.sub(r'0(?:2|[3-6]\d)[- )]*\d{3,4}[- ]*\d{4}','[contact omitted]',text)
   hits.append({'page':i,'term':term,'educationContext':text})
r={'researchOnly':True,'completionClaim':False,'sourceUrl':url,'sourceSha256':hashlib.sha256(data).hexdigest(),'pages':len(reader.pages),'wholePdfSaved':False,'educationalLegendKeywordHits':hits,'currentNativeRowProof':False}
(p/'official-click-yonsei-2026-legend-search-receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
print('officialmanual pages',len(reader.pages),'keywordhits',len(hits))
for h in hits:print(h)
