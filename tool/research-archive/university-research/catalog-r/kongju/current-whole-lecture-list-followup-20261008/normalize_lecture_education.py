"""Keep original9digit offering and each published table/row variant, no section split."""
from pathlib import Path
import json,re,collections
P=Path(__file__).parent
source=json.loads((P/'current-whole-undergraduate-lecture-education.json').read_text());rows=[]
def value(cells,row,col):
 hits=[c for c in cells if c['row']<=row<c['row']+c['rowSpan'] and c['col']<=col<c['col']+c['colSpan']]
 return hits[-1]['text'] if hits else ''
for t in source['educationalTables']:
 cells=t['cells'];header={re.sub(r'\s+','',c['text']):c['col'] for c in cells if c['row']==0}
 if '과목번호' not in header:continue
 keys={'classification':next((k for k in header if '이수구분' in k),None),'courseTitle':next((k for k in header if k in ['과목명','강좌명','교과목명','과,명']),None),'grade':next((k for k in header if k=='학년'),None),'credits':next((k for k in header if k=='학점'),None),'hours':next((k for k in header if k in ['시수','시간']),None),'professor':next((k for k in header if k=='담당교수'),None),'periodAndRoom':next((k for k in header if '강의시간' in k),None),'remarks':next((k for k in header if any(x in k for x in ['비고','주관학과','참고사항','소속학과','현장실습지원센터'])),None)}
 for cell in cells:
  if cell['col']!=header['과목번호'] or cell['row']==0 or not re.fullmatch(r'\d{9}',cell['text']):continue
  r={'nativeOffering':cell['text'],'sourceTable':t['sourceTable'],'sourceRow':cell['row'],'sourceContext':t['precedingEducationalContext']}
  for name,key in keys.items():r[name]=value(cells,cell['row'],header[key]) if key else ''
  timecol=header[keys['periodAndRoom']] if keys['periodAndRoom'] else None
  r['periodRaw']=value(cells,cell['row'],timecol) if timecol is not None else ''
  r['roomRaw']=value(cells,cell['row'],timecol+1) if timecol is not None else ''
  if r['roomRaw']==r['periodRaw']:r['roomRaw']=''
  rows.append(r)
(P/'current-undergraduate-native-2820-row-variants.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
groups=collections.defaultdict(list)
for r in rows:groups[r['nativeOffering']].append(r)
print('rows',len(rows),'native',len(groups),'roomempty',sum(not r['roomRaw'] for r in rows))
print('periodExamples',collections.Counter(r['periodRaw'] for r in rows).most_common(8))
conflicts=[]
for code,rs in groups.items():
 sigs={tuple(r[k] for k in ['courseTitle','professor','credits','periodRaw','roomRaw']) for r in rs}
 if len(sigs)>1:conflicts.append({'nativeOffering':code,'variants':len(rs),'sourceTables':[r['sourceTable'] for r in rs]})
(P/'native-duplicate-conflict-preflight.json').write_text(json.dumps({'wholeNative':len(groups),'originalEducationRows':len(rows),'duplicateNative':sum(len(v)>1 for v in groups.values()),'distinctScheduleOrFieldConflict':conflicts},ensure_ascii=False,indent=2)+'\n')
print('duplicatenative',sum(len(v)>1 for v in groups.values()),'conflicting',len(conflicts))
