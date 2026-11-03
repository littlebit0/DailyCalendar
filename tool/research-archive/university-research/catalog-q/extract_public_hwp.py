"""Reuse local installed-free CFB research reader; retain educational paragraphs only."""
import json,re,runpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent
helper=ROOT.parent/'catalog-l/hwp_tables_research.py'
for path in ROOT.glob('cnue20*-curriculum.hwp'):
 sys.argv=[str(helper),str(path)];loaded=runpy.run_path(str(helper));clean=loaded['text_clean'];paragraphs=[]
 for tag,level,payload in loaded['records']:
  if tag!=67:continue
  text=clean(payload)
  if '@' in text or re.search(r'\b0\d{1,2}[-)]\d{3,4}[-]\d{4}\b',text):continue
  paragraphs.append({'text':text})
 path.with_suffix('.paragraphs.json').write_text(json.dumps(paragraphs,ensure_ascii=False,indent=2));path.with_suffix('.txt').write_text('\n'.join(x['text'] for x in paragraphs))
 print(path.name,len(paragraphs))
