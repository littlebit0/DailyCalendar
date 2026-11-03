import json,pathlib,glob,re,html,collections
P=pathlib.Path('work/course-owner-filter-20261012');G=collections.defaultdict(list)
for f in json.load(open('assets/timetable/catalog.json')):
 d=json.load(open(f));G[d['universityId']].append((f,d))
M=[];O=[];seen=set()
def add(u,l,col,dep,url,file,evidence,own=False,campus='*'):
 if (u,campus,l) in seen:return
 seen.add((u,campus,l));M.append(dict(university=u,campus=campus,sourceLabel=l,college=col,department=dep,sourceUrl=url,sourceFile=file,evidence=evidence,isOfferingUnit=own))
def owner(c,m,url,e):
 O.append(dict(sourceId=c['sourceId'],college=m['college'],department=m['department'],sourceLabel=m['sourceLabel'],sourceUrl=url,evidence=e))
for f,d in G['snu']:
 for c in d['courses']:
  for l in c['departments']:
   col,dep=l.split(' / ',1)
   if not col:continue
   add('snu',l,col,dep or None,d['sourceUrl'],'tool/timetable/import_snu.py:71','Native offering table cells[1] college and cells[2] department; joined literally by source parser.',True)
   owner(c,dict(college=col,department=dep or None,sourceLabel=l),d['sourceUrl'],'Source actual offering college/department cells, not query selections.')
# Source preserved college→department query relation, independent of offering ownership.
url=G['skku'][0][1]['sourceUrl'];base='work/university-research/catalog-g/'
cs=json.load(open(base+'skku-ko-major-colleges.json'))['dsTongHakbu'];byname={}
for col in cs:
 f=base+'skku-ko-major-departments-'+col['COM_CD']+'.json'
 if not pathlib.Path(f).exists():continue
 for dep in json.load(open(f))['dsHakgwa']:
  byname.setdefault(dep['CD_NM'],[]).append((col['CD_NM'],f))
for f,d in G['skku']:
 for l in sorted({l for c in d['courses'] for l in c['departments']}):
  options=byname.get(l,[])
  if len({x[0]for x in options})==1:
   col,ref=options[0];add('skku',l,col,l,url,ref,'Official dsTongHakbu COM_CD→selectBizType04 TONG_HAKBU→dsHakgwa CD_NM exact match. departments asset is query curriculum association, not offering owner.')
# SSU source index relates native college and department option IDs. Course raw 개설학과 is actual opening unit.
url=G['ssu'][0][1]['sourceUrl'];base='work/university-research/catalog-c/'
idx=json.load(open(base+'ssu-acquisition-index.json'));names=collections.defaultdict(set)
for r in idx:names[r['departmentName']].add(r['collegeName'])
rows=json.load(open(base+'ssu-all-2026-2.json'))['recordsByCode']
for f,d in G['ssu']:
 for c in d['courses']:
  raw=rows.get(c['sourceId'].split('/')[-1],[])
  rawlabels={r.get('개설학과')for r in raw}
  for l in c['departments']:
   if len(names[l])==1:
    col=next(iter(names[l]));add('ssu',l,col,l,url,base+'ssu-acquisition-index.json','Official college selection→department option index exact label relation; raw course 개설학과 verified.',l in rawlabels)
    if l in rawlabels:owner(c,dict(college=col,department=l,sourceLabel=l),url,'Raw 개설학과 opening unit exact match, independent of queryFile college.')
# Suwon raw affiliation hierarchy, no primary opening organization field in retained cell table.
for f,d in G['suwon']:
 for l in sorted({l for c in d['courses'] for l in c['departments']}):
  bits=l.split('>>')
  if len(bits)>1 and bits[0].endswith('대학'):
   add('suwon',l,bits[0],'>>'.join(bits[1:]) if bits[1:]!=[bits[0]] else None,d['sourceUrl'],'work/university-research/catalog-w/suwon/','Native source preserves >> organization structure; this is curriculum affiliation and may repeat same course under multiple organizations. No primary opening-unit proof.')
# Yonsei actual estblDeprtNm is independent of queried college/dept. Only actual college prefixes selected, not 교양/RC category groups.
base='work/university-research/catalog-d/';raw=json.load(open(base+'yonsei-2026-2-public-all.json'))
scopes=raw['scopes'];colnames=sorted({r['college']for r in scopes if re.search(r'대학(?:\(|$)',r['college']) and not r['college'].startswith('RC')},key=len,reverse=True)
rawowners=collections.defaultdict(set)
for r in raw['records']:
 label=r.get('estblDeprtNm','')
 for col in colnames:
  if label==col or label.startswith(col+' '):
   dep=label[len(col):].strip() or None
   rawowners[(r['subjtnb'],r['corseDvclsNo'],r['prctsCorseDvclsNo'])].add((label,col,dep));break
for f,d in G['yonsei']:
 for c in d['courses']:
  labels=c['departments']
  for l in labels:
   for col in colnames:
    if l==col or l.startswith(col+' '):
     add('yonsei',l,col,l[len(col):].strip() or None,d['sourceUrl'],base+'yonsei-2026-2-public-all.json','Exact native estblDeprtNm college prefix; ordinary college option validated separately; RC/교양 query categories excluded.', any(l in [r[0]for r in rr]for rr in rawowners.values()),d['campus']);break
  matches=set()
  for key,rs in rawowners.items():
   if key[0]==c['courseCode'] and key[1]==c['section'] and any(r[0]in labels for r in rs):matches.update(r for r in rs if r[0]in labels)
  if len(matches)==1:
   l,col,dep=next(iter(matches));owner(c,dict(college=col,department=dep,sourceLabel=l),d['sourceUrl'],'Native estblDeprtNm opening department, not search scope. Matched code/section plus exact asset department.')
# Current PKNU official college headings and listed department names. Parenthesized explicit submajors accepted, no fuzzy replacements.
f='work/course-owner-filter-20261012/c-sources/pknu.html';body=pathlib.Path(f).read_text();norm=lambda s:re.sub(r'\s+','',html.unescape(re.sub('<[^>]+>','',s)))
parts=re.split(r'<h4 class="subNameH4"[^>]*>(.*?)</h4>',body,flags=re.S);hier={}
for i in range(1,len(parts),2):
 col=norm(parts[i])
 if not col.endswith('대학'):continue
 for li in re.findall(r'<li[^>]*>(.*?)</li>',parts[i+1].split('<h4')[0],re.S):
  label=norm(li)
  for candidate in [label]+re.findall(r'\(([^()]+)\)',label):hier.setdefault(candidate,set()).add(col)
for f,d in G['pknu']:
 for l in {l for c in d['courses'] for l in c['departments']}:
  options=hier.get(norm(l),set())
  if len(options)==1:add('pknu',l,next(iter(options)),l,'https://www.pknu.ac.kr/main/107','work/course-owner-filter-20261012/c-sources/pknu.html','Current official college heading and department/member major literal match. Offering owner requires separate raw row proof.')
# Seoul SMU official college grouped table.
f='work/course-owner-filter-20261012/c-sources/smu.html';body=pathlib.Path(f).read_text();parts=re.split(r'<h4 class="h4-tit"[^>]*>(.*?)</h4>',body,flags=re.S);hier={}
for i in range(1,len(parts),2):
 col=norm(parts[i])
 if not col.endswith('대학'):continue
 for td in re.findall(r'<td class="td-left"[^>]*>(.*?)</td>',parts[i+1],re.S):
  label=norm(td)
  if label:hier.setdefault(label,set()).add(col)
for f,d in G['smu']:
 if d['campus']!='seoul':continue
 for l in {l for c in d['courses'] for l in c['departments']}:
  options=hier.get(norm(l),set())
  if len(options)==1:add('smu',l,next(iter(options)),l,'https://www.smu.ac.kr/ko/edu/seoul001.do','work/course-owner-filter-20261012/c-sources/smu.html','Current official Seoul college heading→학부 및 학과 table exact match. Source parser merges curriculum departments, no primary course-owner proof.',campus='seoul')
gaps=[]
for u in sorted(G)[66:]:
 labels={l for f,d in G[u]for c in d['courses']for l in c.get('departments',[])}
 mapped={r['sourceLabel']for r in M if r['university']==u}
 unknown=sorted(labels-mapped)
 gaps.append(dict(university=u,unmappedLabels=unknown,labelCount=len(labels),mappedLabels=len(mapped),reason='No source-grounded actual college relationship yet; do not invent generic college. Nonacademic query/eligible/category labels require separate handling.' if unknown else 'No unmapped labels in current mapping; actual course host proof remains independently scoped.'))
P.joinpath('agent-c-organizations.json').write_text(json.dumps(dict(mappings=M,courseOwners=O,gaps=gaps),ensure_ascii=False,indent=2)+'\n')
print('mappings',len(M),'owners',len(O));print([(g['university'],g['mappedLabels'],g['labelCount'])for g in gaps])
