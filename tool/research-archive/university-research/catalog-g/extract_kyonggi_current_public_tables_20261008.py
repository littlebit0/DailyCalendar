"""Read original PDF table cells. Inherit only actual enclosing merged cells."""
import hashlib,json,pathlib,re
import pdfplumber
R=pathlib.Path(__file__).resolve().parent
result=[];pages=[]
for filename in ['2026-2_교양.pdf','2026-2_전공.pdf']:
 pdf=R/'kyonggi-external2026-2'/filename;sha=hashlib.sha256(pdf.read_bytes()).hexdigest()
 with pdfplumber.open(pdf) as doc:
  for pi,page in enumerate(doc.pages):
   vertical=[e for e in page.edges if e['orientation']=='v' and e['height']>30 and e['object_type']=='line']
   header=None
   for top in sorted({e['top'] for e in vertical}):
    xs=sorted({e['x0'] for e in vertical if abs(e['top']-top)<1})
    if len(xs)==13:
     header=(top,xs);break
   if header:
    top,xs=header
    horizontal=[e for e in page.edges if e['orientation']=='h' and e['object_type']=='line']
    tables=page.crop((xs[0],top,xs[-1],page.height)).find_tables({'vertical_strategy':'explicit','explicit_vertical_lines':xs,'horizontal_strategy':'explicit','explicit_horizontal_lines':horizontal})
   else:tables=[]
   page_count=0
   for table in tables:
    extracted=table.extract();groups=[];current=None
    for ri,row in enumerate(table.rows):
     text=extracted[ri]
     if len(text)!=12:continue
     native=text[6]
     if native and re.fullmatch(r'\d{4}',native.strip()):
      current={'registrationNumber':native.strip(),'sourcePDF':filename,'sourceSHA256':sha,'page':pi+1,'tableRow':ri,'cells':[],'continuedRows':[]};groups.append(current)
     elif current is None:continue
     elif native not in (None,''):continue
     center=(row.bbox[1]+row.bbox[3])/2
     cells=[]
     for ci,box in enumerate(row.cells):
      enclosing=False
      if box is None:
       # Actual column boundaries are taken from other rows, not invented widths.
       alternatives=[r.cells[ci] for r in table.rows if r.cells[ci] is not None]
       if not alternatives:cells.append({'column':ci,'text':'','unresolved':True});continue
       mid=(alternatives[0][0]+alternatives[0][2])/2
       possible=[b for b in table.cells if b[0]<=mid<=b[2] and b[1]<=center<=b[3]]
       if len(possible)==1:box=possible[0];enclosing=True
      value=page.crop(box).extract_text() or '' if box else ''
      cells.append({'column':ci,'text':value.replace('\\n','\n'),'bbox':list(box) if box else None,'mergedCellEnclosesActualRow':enclosing})
     if native:current['cells']=cells
     else:current['continuedRows'].append(cells)
    for group in groups:
     columns={c['column']:c for c in group['cells']}
     general=filename.endswith('교양.pdf');mapping={'classification':0 if general else 4,'title':1 if general else 0,'courseCode':2 if general else 1,'credits':3 if general else 2,'hours':4 if general else 3,'year':5,'professor':7,'weekday':8,'period':9,'classroom':10,'remarks':11}
     group['educationalFields']={name:columns[index]['text'].strip() for name,index in mapping.items()}
     result.append(group);page_count+=1
   pages.append({'file':filename,'page':pi+1,'tableCount':len(tables),'offeringCount':page_count})
print('extracted',len(result),'unique',len({x['registrationNumber'] for x in result}))
# Completeness explicitly compared below; partial extraction never implies absence.
(R/'kyonggi-current-public-education-tables-20261008.json').write_text(json.dumps({'researchOnly':True,'extractedRows':len(result),'sourceExpectedRegistrationRows':1640,'wholeExtractionComplete':len(result)==1640,'rows':result,'pages':pages},ensure_ascii=False,indent=2)+'\n')
print('actual rows',len(result),'actual code',sum(bool(re.fullmatch(r'[A-Z]{2,4}\d{3,4}',x['educationalFields']['courseCode'])) for x in result),'continuations',sum(bool(x['continuedRows']) for x in result))
