import fitz,json,re,hashlib
from pathlib import Path
out=Path(__file__).parent
source=out.parent/'c/kangnam-timetable.html'
doc=fitz.open(source); rows=[];holds=[]
for pi in range(102,len(doc)):
 page=doc[pi];text=page.get_text(sort=True)
 heading=' / '.join(x.strip() for x in text.splitlines() if x.strip().startswith(('○','◎')))
 for table in page.find_tables().tables:
  extracted=table.extract()
  if not extracted:continue
  labels=extracted[0];columns=[(label,cell)for label,cell in zip(labels,table.rows[0].cells)if label and cell]
  if not {'학수번호','교과목명','분반','강의시간'}.issubset({x[0]for x in columns}):continue
  for row in table.rows[1:]:
   boxes=[b for b in row.cells if b]
   if not boxes:continue
   ymin=min(b[1]for b in boxes); ymax=max(b[3]for b in boxes)
   data={}
   for label,cell in columns:
    value=page.get_textbox(fitz.Rect(cell[0],ymin,cell[2],ymax)).strip()
    data[label]=re.sub(r'\s*\n\s*',' ',value)
   if not re.fullmatch('[A-Z]{2}[0-9]{5}',data.get('학수번호','')):continue
   rows.append({'page':pi+1,'heading':heading,'native':data})
(out/'native-rows.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
print('Native full-book rows',len(rows),'unique',len({(x['native']['학수번호'],x['native']['분반'])for x in rows}))
