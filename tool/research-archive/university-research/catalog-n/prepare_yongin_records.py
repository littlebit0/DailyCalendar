from pathlib import Path
import re,json
P=Path(__file__).parent
T=json.loads((P/'yongin-2026-2-current-tables.json').read_text())
PAGES=(P/'yongin-2026-2-current.txt').read_text().split('\f')
records=[];continuation_count=0
for t in T:
 if not 98<=t['page']<=178:continue
 hi=next((i for i,r in enumerate(t['rows'][:3]) if any(re.sub(r'\s+','',x or '')=='학수번호' for x in r)),None)
 if hi is None:continue
 header=[re.sub(r'\s+','',x or '') for x in t['rows'][hi]]
 ci=header.index('학수번호'); last=None;lastroom='';target=''
 page=PAGES[t['page']-1]
 title=next(line.strip() for line in page.strip().splitlines() if not re.fullmatch(r'-\s*\d+\s*-',line.strip()))
 if '학년' in title:raise ValueError(f'No page title {t["page"]}: {title}')
 course_positions=list(re.finditer(r'[A-Z0-9]{6}-\d{2}',page))
 notes={}
 for i,m in enumerate(course_positions):
  end=course_positions[i+1].start() if i+1<len(course_positions) else len(page)
  chunk=page[m.end():end];star=chunk.find('*')
  notes[m[0]]=chunk[star:].strip() if star>=0 else ''
 for row in t['rows'][hi+1:]:
  if len(row)!=len(header):raise ValueError('Row width')
  code=(row[ci]or'').strip()
  identity=re.match(r'([A-Z0-9]{6}-\d{2})(?:\s|$)',code)
  if identity:
   code=identity[1]
   name=row[ci+1] or row[ci][identity.end():].split('*',1)[0].strip()
   if '수강대상' in header:target=row[2]or target
   lastroom='';last={'page':t['page'],'department':title,'codeSection':code,'name':name,
   'creditsCapacity':row[ci+2],'classification':row[1],'grade':row[0], 'target':target,
   'professors':[], 'meetings':[], 'notes':notes.get(code,''), 'sourceRows':[]}
   records.append(last)
  elif not any(row):continue
  elif last is None:raise ValueError(f'Orphan continuation {t["page"]}: {row}')
  else:continuation_count+=1
  last['sourceRows'].append(row)
  # A continuation can contain an extra professor and extra real meeting.
  teacher=row[ci+3]
  if teacher and teacher not in last['professors']:last['professors'].append(teacher)
  if '강의시간' in header:
   time=row[header.index('강의시간')]or'';room=row[header.index('강의실')]or lastroom
   lastroom=room
   if time:last['meetings'].append({'rawTime':time,'rawRoom':room})
  elif row[-1]:last['notes']+='\n'+row[-1]
# Consortium table is separate from own remote courses (own21 also in core).
remote=[]
text='\n'.join(PAGES[89:91])
pattern=re.compile(r'(\d+)\s+(교양선택\s*\(4영역\)|일반선택)\s+(W\d{5}[A-Z]\d{2})\s+(.*?)(?=\n\d+\s+(?:교양선택|일반선택)|\Z)',re.S)
for m in pattern.finditer(text):
 chunk=m[4];credit=re.search(r'\s+([1-9])\s+(\d+)\s+(\S+)\s+',chunk)
 if not credit:raise ValueError('Remote credits missing')
 name=chunk[:credit.start()].strip();note=''
 if '＊' in name:name,note=name.split('＊',1)
 remote.append({'sequence':int(m[1]),'rawCode':m[3],'name':re.sub(r'\s+','',name),
 'classification':re.sub(r'\s+','',m[2]),'credits':int(credit[1]),'professor':credit[3],
 'notes':note+'\n'+chunk[credit.end():].strip(),'department':'OCU 컨소시엄'})
if [x['sequence'] for x in remote]!=list(range(1,22)):raise ValueError('Incomplete OCU21')
for t in T:
 if t['page']==94:
  r=t['rows'][1];remote.append({'rawCode':r[1],'name':r[2],'classification':re.sub(r'\s+','',r[0]),'credits':int(r[3]),'professor':r[5],'notes':'소속대학: '+r[6],'department':'KCU 컨소시엄'})
(P/'yongin-partial-debug.json').write_text(json.dumps(records,ensure_ascii=False))
if len(remote)!=22:raise ValueError(f'Incomplete opened scope {len(records)} / {len(remote)}')
(P/'yongin-prepared-source-records.json').write_text(json.dumps({'records':records,'remote':remote,'continuationRowCount':continuation_count},ensure_ascii=False,indent=2))
print('core',len(records),'continuations',continuation_count,'meetings',sum(len(r['meetings']) for r in records),'remote',len(remote))
print('intensive',[(r['codeSection'],r['notes'][:180]) for r in records if re.search('집중|수업일정|학과.*문의',r['notes'])])
