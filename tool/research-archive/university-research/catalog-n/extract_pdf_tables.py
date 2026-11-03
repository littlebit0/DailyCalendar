from pathlib import Path
import pdfplumber,json
P=Path(__file__).parent
for name in ['yongin-2026-2-current','tuk-2026-2-general','tuk-2026-2-fusion']:
 a=[]
 with pdfplumber.open(P/f'{name}.pdf') as d:
  for n,p in enumerate(d.pages,1):
   for index,t in enumerate(p.extract_tables()):a.append({'page':n,'table':index,'rows':t})
 (P/f'{name}-tables.json').write_text(json.dumps(a,ensure_ascii=False,indent=2));print(name,len(a),flush=True)
 for t in a:
  if any('과목코드' in str(r) or '학수번호' in str(r) for r in t['rows']):
   print('schema',t['page'],str(t['rows'][:3])[:1100],flush=True)
   if t['page']>45 or name.startswith('tuk'):break
