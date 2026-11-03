import fitz,json,re
from pathlib import Path
p=Path(__file__).parent;doc=fitz.open(p/'download.raw');notes={};nonoffering=[]
for i in range(102,len(doc)):
 text=doc[i].get_text(sort=True)
 for fragment in text.split('※')[1:]:
  fragment=re.split(r'\n\s*-\s*\d+\s*-\s*$',fragment)[0].strip();refs=re.findall(r'\b([A-Z]{2}\d{5})\s*-\s*(\d{2})\b',fragment)
  if not refs:continue
  # The note ends at a following timetable or heading; preserve only its native paragraph.
  fragment=re.split(r'\n\s*[○◎]|\n\s*학년',fragment)[0].strip()
  for code,section in refs:notes.setdefault(f'{code}-{section}',[]).append({'page':i+1,'text':re.sub(r'\s+',' ',fragment)})
(p/'native-notes.json').write_text(json.dumps(notes,ensure_ascii=False,indent=2)+'\n')
print('Exact native code/section footnote references',len(notes))
