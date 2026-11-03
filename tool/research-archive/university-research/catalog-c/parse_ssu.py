from pathlib import Path
import re,html,json,collections
ROOT=Path(__file__).parent
files=list(ROOT.glob('ssu-courses-*.xml'))
for label in ['required','elective','chapel','linked','convergence']:
 files+=list(ROOT.glob('ssu-'+label+'-courses-*.xml'))
files+=[ROOT/'ssu-teaching-courses.xml']
records=[];queries=[];unique={}
for file in files:
 s=file.read_text();table=re.search(r'ct="ST" lsdata="\{2:(\d+),3:(\d+)',s)
 if not table:continue
 count,columns=map(int,table.groups());headers=[]
 for raw in re.findall(r'<th\b[^>]*role="columnheader"[^>]*>(.*?)</th>',s,re.S):
  text=re.search(r'ct="CP"[^>]*>(.*?)</span>',raw,re.S)
  headers.append(html.unescape(re.sub('<[^>]+>',' ',text[1]if text else raw)).strip())
 assert len(headers)==columns,(file.name,headers,columns)
 mine=[]
 for raw in re.findall(r'<tr\b[^>]*>(.*?)</tr>',s,re.S):
  cells=re.findall(r'<td\b[^>]*role="gridcell"[^>]*>(.*?)</td>',raw,re.S)
  values=[html.unescape(re.sub('<[^>]+>',' ',x)).replace('\xa0',' ').strip()for x in cells]
  if len(values)==columns:
   r=dict(zip(headers,values))
   if re.fullmatch(r'\d{10}',r.get('과목번호','')):
    r['queryFile']=file.name;mine.append(r);unique.setdefault(r['과목번호'],[]).append(r)
 assert len(mine)==count,(file.name,len(mine),count)
 records+=mine;queries.append({'file':file.name,'reported':count,'received':len(mine),'headers':headers})
(ROOT/'ssu-all-2026-2.json').write_text(json.dumps({'queryRows':len(records),'uniqueSubjectSectionCodes':len(unique),'queries':queries,'records':records,'recordsByCode':unique},ensure_ascii=False,indent=2)+'\n')
print('queries',len(queries),'rows',len(records),'unique',len(unique),'untimed',sum(not rs[0].get('강의시간(강의실)')for rs in unique.values()))
