"""Current published merged educational cells; no invented section or faculty."""
import json,re,pathlib,sys,importlib.util,collections
from openpyxl import load_workbook
R=pathlib.Path(__file__).resolve().parent
original=json.loads((R/'hknu-2026-2-prepared-candidate.json').read_text())['courses']
courses=[c for c in original if c['departments']==['안전공학전공']]
professors={c['professor'] for c in original if c['professor'] not in ['미정','']}

def norm(s):return re.sub(r'\s+','',str(s or ''))
def titlekey(s):return re.sub(r'[ⅠⅡⅢⅣ]+$','',norm(s))
w=load_workbook(R/'hknu-safety2026-2-Jul22.xlsx',data_only=True);s=w.worksheets[0];blocks=[]
for merged in s.merged_cells.ranges:
 cell=s.cell(merged.min_row,merged.min_col);text=cell.value
 if not text or not 3<=merged.min_col<=18 or merged.min_row<4 or '대학원' in str(text):continue
 first=s.cell(merged.min_row,2).value;last=s.cell(merged.max_row,2).value
 if not isinstance(first,(int,float)) or not isinstance(last,(int,float)):continue
 rawlines=[line.strip() for line in str(text).splitlines() if line.strip()]
 lines=[line for line in rawlines if not line.startswith('[') and line!='(학부)']
 prof_index=next((i for i,line in enumerate(lines) if re.sub(r'\(대강\)$','',line) in professors or line.endswith('(대강)')),None)
 if prof_index is not None:title=''.join(lines[:prof_index]);professor=lines[prof_index];room=' '.join(lines[prof_index+1:])
 else:
  room_index=next((i for i,line in enumerate(lines) if re.search(r'\d',line)),len(lines));title=''.join(lines[:room_index]);professor='';room=' '.join(lines[room_index:])
 weekday=(merged.min_col-3)//4+1
 base=titlekey(title);possible=[c for c in courses if titlekey(c['courseName'])==base]
 if not possible and title.endswith(('1','2')):possible=[c for c in courses if titlekey(c['courseName'])==titlekey(title[:-1])]
 matches=[]
 for c in possible:
  dayparts=[p.strip() for p in c['sourceSchedule'].split(' / ') if p.startswith('('+('월화수목금토일'[weekday-1])+')')]
  if not dayparts:continue
  if len(possible)>1:
   if base=='산업의료원':
    if professor!=c['professor']:continue
   else:
    found=False
    for p in dayparts:
     m=re.search(r'(\d+(?:\.5)?)~(\d+(?:\.5)?)',p)
     if m and float(m[1])==float(first) and float(m[2])==float(last):found=True
    if not found:continue
  matches.append(c['sourceId'])
 if not matches and len(possible)>1:
  same_day=[c for c in possible if '('+('월화수목금토일'[weekday-1])+')' in c['sourceSchedule'] and c['professor']==professor]
  if len(same_day)==1:matches=[same_day[0]['sourceId']]
 blocks.append({'sourceCellRange':str(merged),'actualPublishedClassTitle':title,'actualPublishedProfessor':professor,'actualPublishedRoomLiteral':room,'nativeWeekday':weekday,'nativeFirstPeriod':first,'nativeLastPeriod':last,'sourceEducationalCell':str(text),'originalIdentityCandidates':matches,'identityNotAutomaticallyApplied':True})
blocks.sort(key=lambda x:(x['nativeWeekday'],x['nativeFirstPeriod'],x['sourceCellRange']))
(R/'hknu-current-safety-merged-education-grid-20261008.json').write_text(json.dumps({'researchOnly':True,'sourceUrl':'https://www.hknu.ac.kr/bbs/hksystem/243/97127/artclView.do','sourceFile':'hknu-safety2026-2-Jul22.xlsx','sourceDate':'2026-07-22','originalDepartmentRows':len(courses),'graduateCellsExcluded':True,'blocks':blocks},ensure_ascii=False,indent=2)+'\n')
print('current undergraduate educational blocks',len(blocks),'candidate identity counts',dict(collections.Counter(len(b['originalIdentityCandidates']) for b in blocks)))
for b in blocks:
 if len(b['originalIdentityCandidates'])!=1:print(b['sourceCellRange'],b['actualPublishedClassTitle'],b['actualPublishedProfessor'],b['nativeWeekday'],b['nativeFirstPeriod'],b['nativeLastPeriod'],b['originalIdentityCandidates'])
