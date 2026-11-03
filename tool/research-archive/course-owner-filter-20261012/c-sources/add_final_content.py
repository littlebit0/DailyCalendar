exec(open('work/course-owner-filter-20261012/c-sources/add_c_homes.py').read().split('receipts=')[0])
strip=lambda s:html.unescape(re.sub('<[^>]+>','',s)).strip();rs=json.load(open(P/'c-sources/extra-receipts.json'));hs=collections.defaultdict(dict)
for r in rs:
 if 'file'not in r:continue
 u=r['university'];b=pathlib.Path(r['file']).read_text()
 if u=='sogang':
  col=None
  for row in re.findall('<tr[^>]*>(.*?)</tr>',b,re.S):
   cells=[strip(z)for z in re.findall('<t[dh][^>]*>(.*?)</t[dh]>',row,re.S)]
   if not cells:continue
   if cells[0].endswith('대학'):col=cells.pop(0)
   if col and cells and re.search('(학과|학부)$',norm(cells[0])):hs[u][norm(cells[0])]=(col,r)
 if u=='yu' and '교양학부'in b:hs[u][norm('교양학부')]=('천마학부대학',r)
for r in json.load(open(P/'c-sources/previous-more-receipts.json')):
 if r['university']!='scnu' or 'file'not in r or r['college']in ['스쿨','대학']:continue
 b=pathlib.Path(r['file']).read_text();block=b.split('<ul class="mjList">')[-1].split('</ul>')[0]
 for dep in re.findall('<em>(.*?)</em>',block,re.S):hs['scnu'][norm(strip(dep))]=(r['college'],r)
for u in hs:
 for d in G[u]:
  for l in {l for c in d['courses']for l in c.get('departments',[])}:
   if norm(l)in hs[u]:
    col,r=hs[u][norm(l)];add(u,l,col,l,r['sourceUrl'],r['file'],'Official college-row or named school major list explicitly places exact academic unit. School name retained as published; affiliation only.')
for a in out.get('courseAssociations',[]):a['isOfferingUnit']=False
# Do not silently adopt an undocumented cross-name alias.
invalid={m['sourceLabel']for m in M if m['university']=='pcu' and '글로벌자율융합학부'in m['sourceLabel']}
out['mappings'][:]=[m for m in M if not(m['university']=='pcu'and m['sourceLabel']in invalid)]
out['courseAssociations'][:]=[a for a in out.get('courseAssociations',[])if a['sourceLabel']not in invalid]
receipts=[]
for f in ['home-receipts.json','college-receipts.json','more-receipts.json','previous-more-receipts.json','extra-receipts.json']:
 receipts.extend(json.load(open(P/'c-sources'/f)))
for g in out['gaps']:
 u=g['university'];labels={l for d in G[u]for c in d['courses']for l in c.get('departments',[])};mapped={r['sourceLabel']for r in M if r['university']==u};remain=sorted(labels-mapped);g['unmappedLabels']=remain;g['mappedLabels']=len(mapped)
 g['nonDepartmentLabels']=[l for l in remain if re.search(r'(팀|처|센터|지원단|사업단|교직부|ROTC|R\s*[·․.]\s*O|교양|대학전체|OCU|자유선택)',l) or l.startswith('HUSS ')]
 g['unconfirmedAcademicLabels']=[l for l in remain if l not in g['nonDepartmentLabels']]
 g['officialOrganizationChecks']=[{k:r[k]for k in ['sourceUrl','file','error']if k in r}for r in receipts if r['university']==u]
 if not g['officialOrganizationChecks']:g['officialOrganizationChecks']=[dict(sourceUrl=d.get('sourceUrl'),sourceFile=d.get('sourceFile'),evidence='Retained public official course source metadata and parser examined.')for d in G[u]]
 g['status']='partial-evidence' if g['unconfirmedAcademicLabels'] else 'academic-labels-covered-or-nonacademic-only'
 g['gapReason']='Exact unresolved labels retained. Renamed or historical departments, composite curriculum headings and administrative/query categories were not assigned to a guessed college. Official hierarchy inspection is complete for available fetched pages; remaining affiliation is unconfirmed.'
 if u=='pcu':g['gapReason']='Native positioned handbook courses have academic page headings. Exact code+section page association retained for '+str(len(out.get('courseAssociations',[])))+' courses. General education pages and unmatched academic headings remain without inferred owner; actual offering host is not asserted.'
P.joinpath('agent-c-organizations.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print('mappings',len(M),'owners',len(out['courseOwners']),'associations',len(out['courseAssociations']));print([(g['university'],g['mappedLabels'],len(g['unconfirmedAcademicLabels']),len(g['nonDepartmentLabels']))for g in out['gaps']])
