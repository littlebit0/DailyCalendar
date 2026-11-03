"""Educational-only extraction from declared HWP table coordinates and merged spans."""
import json,re,pathlib,collections
D=pathlib.Path(__file__).parent/'scnu-current-20261008'
def read(f):return json.loads((D/f).read_text())
def write(f,x):(D/f).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
sections=read('notice-281319202-timetable-0824.hwp.tables.json');rows=[];context=[];department='';mode=''
for ti,t in enumerate(sections[2]['tables']):
 cells=t['cells'];grid={}
 for c in cells:
  value=' '.join(c['paragraphs']).strip()
  for r in range(c['row'],c['row']+c['rowSpan']):
   for col in range(c['column'],c['column']+c['columnSpan']):
    assert (r,col) not in grid,(ti,r,col)
    grid[r,col]=value
 headerrows=[r for r in {c['row'] for c in cells} if any(re.sub(r'\s+','',v)=='교과목명' for (rr,col),v in grid.items() if rr==r)]
 if not headerrows:
  values=[v for c in cells if (v:=' '.join(c['paragraphs']).strip())]
  if values:
   line=' '.join(values)
   if len(line)<100 and not line.startswith('❖'):
    if '야간강좌' in line:mode='야간'
    if '주간강좌' in line:mode='주간'
    if ti<48 and re.search(r'^1-|교직교과목|실용교육|군사학|KSL',line):context=[line]
    elif ti>=48 and len(values)==1:department=line
   elif line.startswith('❖'):context.append(line)
  continue
 hr=min(headerrows);headers={col:re.sub(r'\s+','',v) for (r,col),v in grid.items() if r==hr}
 codecols=[col for col,h in headers.items() if h in ('코드','교과목코드')];assert len(codecols)==1,(ti,headers)
 codecol=codecols[0]
 for r in sorted({c['row'] for c in cells}):
  if r<=hr:continue
  code=grid.get((r,codecol),'').strip()
  if not re.fullmatch('[A-Z]{2}[0-9]{4}',code):continue
  e={h:grid.get((r,col),'') for col,h in headers.items()}
  rows.append({'sourceSection':2,'sourceTable':ti,'sourceRow':r,'education':e,'sourceContext':context[:] if ti<48 else [department], 'publishedDayNight':mode if ti<48 else '', 'declaredMergedCells':[c for c in cells if c['row']<=r<c['row']+c['rowSpan']]})
for row in rows:
 if row['sourceTable'] in (188,201):
  record = 93482 if row['sourceTable']==188 else 96447
  row['sourceContext'].extend(p['text'] for p in sections[2]['paragraphs'] if p['record']==record)
write('educational-source-offerings.json',rows)
by=collections.defaultdict(list)
for r in rows:
 e=r['education'];by[(e.get('코드',e.get('교과목코드')),e['분반'])].append(r)
print('native rows',len(rows),'identities',len(by),'tables',len({r['sourceTable'] for r in rows}))
print('duplicate',[(k,len(v)) for k,v in by.items() if len(v)>1][:15])
print('categories',collections.Counter(r['education'].get('이수구분',r['education'].get('영역','[heading]')) for r in rows))
write('source-extraction-audit.json',{'nativeRows':len(rows),'nativeCodeSectionIdentities':len(by),'courseTables':len({r['sourceTable'] for r in rows}),'method':'HWP table LIST_HEADER col,row,colSpan,rowSpan and paragraph records; only declared merge cells propagated; no inferred fill-forward','mergedSourceCellsPreserved':True})
