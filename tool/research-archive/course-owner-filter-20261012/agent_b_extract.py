import json,re,collections
from pathlib import Path
ROOT=Path('work/course-owner-filter-20261012'); universities=collections.defaultdict(list)
for f in json.load(open('assets/timetable/catalog.json')):
 d=json.load(open(f));universities[d['universityId']].append((f,d))
selected=dict(sorted(universities.items())[33:66]); mappings={}; owners={}; evidence=[]
def add(u,ca,label,col,dep,url,file,why,off=False):
 if not col or not label:return
 item=dict(university=u,campus=ca,sourceLabel=label,college=col,department=dep,sourceUrl=url,sourceFile=file,evidence=why)
 if off:item['isOfferingUnit']=True
 k=(u,ca,label); prev=mappings.get(k)
 if prev and (prev['college'],prev['department'])!=(col,dep):return
 mappings[k]=item

def owner(c,col,dep,label,url,file,why):
 if not col:return
 owners[c['sourceId']]=dict(sourceId=c['sourceId'],college=col,department=dep,sourceLabel=label,sourceUrl=url,sourceFile=file,evidence=why)
# Explicit public college/department pairs retained in source labels are affiliation only.
for u,fs in selected.items():
 for f,d in fs:
  for c in d['courses']:
   for label in c.get('departments',[]):
    m=re.match(r'^([^/]+대학)\s*/\s*(.+)$',label) or re.match(r'^([^\s/]+대학)\s+(.+)$',label)
    if m:add(u,d['campus'],label,m[1].strip(),m[2].strip(),d['sourceUrl'],f,'Original published department label explicitly contains college and department; affiliation only, not an organizer claim.')
   education=c.get('sourceEducation',{})
   cells=education.get('nativePublicCells',{}) if isinstance(education,dict) else {}
   if u=='inu':
    col=cells.get('대학(원)');dep=cells.get('학과(부)')
    if col and ('대학' in col):
     for label in c.get('departments',[]):add(u,d['campus'],label,col,dep if dep!=col else None,d['sourceUrl'],f,'Public timetable native row separately prints 대학(원) and 학과(부).',True)
     owner(c,col,dep if dep!=col else None,dep or col,d['sourceUrl'],f,'Exact native public course row: 대학(원)/학과(부), separate from 수강대상.')
   if u=='mju':
    col=cells.get('college');dep=cells.get('department')
    if col and col.endswith('대학'):
     for label in c.get('departments',[]):add(u,d['campus'],label,col,dep if dep!=col else None,d['sourceUrl'],f,'Public educational row explicitly retains college and department; affiliation mapping.')
# Actual opening college/department columns from KNU current public rows.
f='work/university-research/catalog-p/knu-2026-2-current-public-owner-course-rows.json';rows=json.load(open(f)); idx=collections.defaultdict(list)
for r in rows:idx[(r['sbjetCd'],r['sbjetDvnno'])].append(r)
for af,d in selected['knu']:
 for c in d['courses']:
  rr=idx.get((c['courseCode'],c['section']),[]);pairs={(r.get('estblUnivNm'),r.get('estblDprtnNm')) for r in rr}
  if len(pairs)!=1:continue
  col,dep=next(iter(pairs))
  if not col or not col.endswith('대학'):continue
  for label in c.get('departments',[]):
   if label==dep or label==col or label.startswith(dep+' ('):add('knu',d['campus'],label,col,dep if dep!=col else None,d['sourceUrl'],f,'Exact subject+section join; estblUnivNm and estblDprtnNm are opening university/department, distinct from query aliases.',True)
  owner(c,col,dep if dep!=col else None,dep,d['sourceUrl'],f,'Exact subject+section join; source opening fields estblUnivNm / estblDprtnNm.')
# Kangwon explicit source college; never use target strings as host.
f='work/university-research/catalog-q/kangwon-current-whole-source-rows.json';rows=json.load(open(f));idx={(r['campus'],r['code'],r['section']):r for r in rows}
for af,d in selected['kangwon']:
 for c in d['courses']:
  r=idx.get((c['campus'],c['courseCode'],c['section']))
  if not r:continue
  col=r.get('sourceCollege');dep=r.get('department')
  if not col or not col.endswith('대학'):continue
  for label in c.get('departments',[]):
   if label==dep or label.startswith(dep+' '):add('kangwon',d['campus'],label,col,dep,d['sourceUrl'],f,'Official course sourceRawCells retains sourceCollege and department separately from target eligibility column.',True)
  owner(c,col,dep,dep,d['sourceUrl'],f,'Exact campus+code+section; sourceCollege and department fields from native sourceRawCells, target not used.')
# Kookmin official organization dictionary, assigned department on actual course row.
f='work/university-research/catalog-c/kookmin-commoncodes.json';codes=json.load(open(f)); org={r['deptCd']:r for r in codes['departmentList']}; colleges={r['deptCd']:r for r in codes['collegeList']}
byname=collections.defaultdict(list)
for r in org.values():
 col=colleges.get(r.get('univCd'));name=r['deptNm']
 if col and (col['deptNm'].endswith('대학') or 'College' in col['deptNm'] or 'School' in col['deptNm']):byname[name].append((col['deptNm'],name))
for af,d in selected['kookmin']:
 for c in d['courses']:
  for label in c.get('departments',[]):
   ps=set(byname.get(label,[]))
   if len(ps)==1:
    col,dep=next(iter(ps));add('kookmin',d['campus'],label,col,None if col==dep else dep,d['sourceUrl'],f,'Official public departmentList univCd identifies exact college ancestry; not query provenance.')
frows='work/university-research/catalog-c/kookmin-current-college-scope.json';rows=json.load(open(frows))['records'];idx={(r['subjectId'],r['classSequence']):r for r in rows}
for af,d in selected['kookmin']:
 for c in d['courses']:
  r=idx.get((c['courseCode'],c['section']));unit=org.get(r.get('assignedDepartmentCode')) if r else None
  if not unit:continue
  col=colleges.get(unit.get('univCd'))
  if not col or not (col['deptNm'].endswith('대학') or 'College' in col['deptNm'] or 'School' in col['deptNm']):continue
  dep=unit['deptNm'];owner(c,col['deptNm'],None if dep==col['deptNm'] else dep,dep,d['sourceUrl'],frows,'Actual assignedDepartmentCode joined to official departmentList univCd; exact subjectId/classSequence; query college ignored.')
# Official current pages, remove HTML comments so obsolete units never map.
for u,url in [('hyupsung','https://www.uhs.ac.kr/uhs/122/subview.do'),('kwangwoon','https://www.kw.ac.kr/ko/univ/glance.jsp')]:
 p=ROOT/(u+'-official-organization.html');s=re.sub(r'<!--.*?-->','',p.read_text(),flags=re.S);heads=list(re.finditer(r'<h[34][^>]*>(.*?)</h[34]>',s,re.S));sections=[]
 for i,m in enumerate(heads):
  title=re.sub('<[^>]+>','',m[1]).strip(); end=heads[i+1].start() if i+1<len(heads) else len(s)
  if title.endswith('대학') and title not in ['광운대학교 로그인']:sections.append((title,re.sub('<[^>]+>',' ',s[m.end():end])))
 for af,d in selected[u]:
  for label in {v for c in d['courses'] for v in c.get('departments',[])}:
   matches=[col for col,txt in sections if label in txt]
   # Avoid spillover navigation section at tail.
   if u=='kwangwoon':matches=[col for col in matches if col!='인제니움대학']
   if len(set(matches))==1:add(u,d['campus'],label,matches[0],label,url,str(p),'Current official university overview/course curriculum heading explicitly lists department under college; HTML comments excluded.')
gaps=[]
for u,fs in selected.items():
 for f,d in fs:
  labels=sorted({v for c in d['courses'] for v in c.get('departments',[])})
  unknown=[label for label in labels if (u,d['campus'],label) not in mappings]
  unowned=[c['sourceId'] for c in d['courses'] if c['sourceId'] not in owners]
  gaps.append(dict(university=u,campus=d['campus'],sourceFile=f,unmappedLabels=unknown,unmappedLabelCount=len(unknown),courseOwnerUnverifiedCount=len(unowned),reason='Unmapped labels omitted, not guessed. Existing curriculum/query/eligible labels do not establish actual offering unit. Requires further official hierarchy/host evidence.'))
out=dict(mappings=list(mappings.values()),courseOwners=list(owners.values()),gaps=gaps,scope=list(selected),completionClaim=False)
(ROOT/'agent-b-organizations.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n'); print('mappings',len(mappings),'owners',len(owners));print(collections.Counter(m['university'] for m in mappings.values()));print(collections.Counter(o['sourceId'].split('/')[0] for o in owners.values()))
