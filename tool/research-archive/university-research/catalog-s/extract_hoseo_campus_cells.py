"""Read only explicit campus group labels inside printed horizontal boundaries."""
import json,re
from pathlib import Path
import pdfplumber
ROOT=Path(__file__).parent
n=lambda x:re.sub(r'\s+','',x or '')
records=[]
with pdfplumber.open(ROOT/'hoseo-current-full-guide.pdf') as document:
 for pi,page in enumerate(document.pages,1):
  for ti,table in enumerate(page.find_tables()):
   rows=table.extract();h=None
   for hi,labels in enumerate(rows[:4]):
    names=[n(v) for v in labels]
    if all(k in names for k in ('캠퍼스','학수번호','분반')):h=hi,names;break
   if not h:continue
   hi,names=h;ca,ci,si=[names.index(k) for k in ('캠퍼스','학수번호','분반')]
   box=table.rows[hi].cells[ca]
   if box is None:continue
   ys=[box[3],table.bbox[3]]
   for edge in page.horizontal_edges:
    y=edge['top']
    if box[3]<y<table.bbox[3] and edge['x0']<=box[0]+1 and edge['x1']>=box[2]-1:ys.append(y)
   ys=sorted(set(round(y,3) for y in ys))
   groups=[]
   for start,end in zip(ys,ys[1:]):
    if end-start<2:continue
    raw=page.crop((box[0],start,box[2],end)).extract_text() or ''
    label=n(raw)
    if label in ('아산','천안','산학융합'):
     groups.append((start,end,{'아산':'asan','천안':'cheonan','산학융합':'industrial'}[label],raw))
   for ri,row in enumerate(rows[hi+1:],hi+1):
    if len(row)<=max(ci,si):continue
    code,section=n(row[ci]),n(row[si]);anchor=table.rows[ri].cells[si]
    if not re.fullmatch(r'0[A-Z0-9]{7}',code) or not section.isdigit() or not anchor:continue
    middle=(anchor[1]+anchor[3])/2
    matches=[g for g in groups if g[0]<=middle<=g[1]]
    if len(matches)==1:
     g=matches[0];records.append({'code':code,'section':section.zfill(2),'campus':g[2],'page':pi,'table':ti,'row':ri,'actualCampusText':g[3],'printedCampusBounds':[box[0],g[0],box[2],g[1]]})
(ROOT/'hoseo-current-pdf-explicit-campus-rows.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
print('Explicit current campus rows',len(records))
