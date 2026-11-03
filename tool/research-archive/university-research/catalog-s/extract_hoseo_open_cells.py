"""Read unbordered outer PDF code cells using published header bounds/row section.

pdfplumber omits an outer body cell when no vertical outside border exists. The
actual text remains present. This extracts characters inside the header's column
bounds and actual section cell's row bounds, without inferred course identities.
"""
import json,re
from pathlib import Path
import pdfplumber
ROOT=Path(__file__).parent
compact=lambda v:re.sub(r'\s+','',v or '')
records=[];restored=[]
with pdfplumber.open(ROOT/'hoseo-current-full-guide.pdf') as document:
 for pi,page in enumerate(document.pages,1):
  for ti,table in enumerate(page.find_tables()):
   rows=table.extract();header=None
   for hi,labels in enumerate(rows[:4]):
    names=[compact(v) for v in labels]
    if all(k in names for k in ('학수번호','분반','학점')):
     header=hi,names;break
   if not header:continue
   hi,names=header;ci,si,cr=[names.index(k) for k in ('학수번호','분반','학점')]
   box=table.rows[hi].cells[ci]
   if box is None:continue
   for ri,row in enumerate(rows[hi+1:],hi+1):
    if len(row)<=max(ci,si,cr):continue
    code,section,credit=compact(row[ci]),compact(row[si]),compact(row[cr])
    anchor=table.rows[ri].cells[si]
    if not code and anchor:
     bounds=(box[0],anchor[1],box[2],anchor[3])
     value=page.crop(bounds).extract_text() or ''
     code=compact(value)
     if re.fullmatch(r'0[A-Z0-9]{7}',code):restored.append({'page':pi,'table':ti,'row':ri,'column':ci,'bounds':bounds,'actualText':value})
    if re.fullmatch(r'0[A-Z0-9]{7}',code) and section and re.fullmatch(r'\d+(?:\.\d+)?',credit):
     records.append({'code':code,'section':section,'credit':credit,'page':pi,'table':ti,'row':ri,'labels':rows[hi],'values':row,'codeRestoredFromActualText':not bool(row[ci])})
(ROOT/'hoseo-pdf-restored-exact-credit-rows.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
(ROOT/'hoseo-pdf-restored-code-cell-evidence.json').write_text(json.dumps(restored,ensure_ascii=False,indent=2))
print('Actual rows',len(records),'restored outer codes',len(restored))
