exec(open('work/course-owner-filter-20261012/c-sources/add_c_homes.py').read().split('receipts=')[0])
add('unist','Computer Science and Engineering','AI융합대학','Computer Science and Engineering','https://ax.unist.ac.kr/ib/introduction/status.do',str(P/'c-sources/unist-current.html'),'Current AI융합대학 official status table includes 컴퓨터공학과; official freshman department introduction renders same unit Computer Science & Engineering. Updated college name; older 정보바이오융합대학 not used.')
add('wsu','컴퓨터·소프트웨어전공','소프트웨어(SW)융합대학','컴퓨터·소프트웨어전공','https://ent.wsu.ac.kr/page/index.jsp?code=eguide0100',str(P/'c-sources/wsu-current.html'),'Official current academic-unit list: marker ▶소프트웨어(SW)융합대학◀ followed by 소프트웨어학부(컴퓨터‧소프트웨어전공), before next college marker. Interpunct typography only differs.')
for l in ['소프트웨어학과','컴퓨터공학과','글로벌융합학부']:
 add('skku',l,'소프트웨어융합대학',l,'https://skb.skku.edu/sw/under_computer_intro.do',None,'Official current college page title and 학사과정 navigation explicitly list department under 소프트웨어융합대학. Verified official indexed page; direct download returned 404.')
for m in M:m['collegeKnown']=True
unknown=[]
for g in out['gaps']:
 u=g['university'];already={m['sourceLabel']for m in M if m['university']==u};non=set(g.get('nonDepartmentLabels',[]))
 for d in G[u]:
  for l in {l for c in d['courses']for l in c.get('departments',[])}-already-non:
   # Atomic source-designated department only. Exclude college-prefixed OCR concatenations, multi-labels, grades and curriculum/category headings.
   z=norm(l)
   if not re.fullmatch(r'[가-힣A-Za-z·ㆍ&\-]+(?:학과|학부|전공)',z):continue
   if '대학'in z or '학년'in z or '교양'in z or '연계'in z or '융합전공'in z or (u=='smu' and ('학과'in z[:-2]or '학부'in z[:-2])):continue
   add(u,l,None,l,d.get('sourceUrl'),None,'Published source departments entry retained as department/query association. Official organization routes were inspected, but current college affiliation remains unconfirmed; no college-only selection. collegeKnown=false.')
   M[-1]['collegeKnown']=False;unknown.append((u,l))
for g in out['gaps']:
 u=g['university'];allm=[m for m in M if m['university']==u];known={m['sourceLabel']for m in allm if m['collegeKnown']};un={m['sourceLabel']for m in allm if not m['collegeKnown']};labels={l for d in G[u]for c in d['courses']for l in c.get('departments',[])}
 g['collegeKnownMappedLabels']=len(known);g['collegeUnknownDepartmentLabels']=sorted(un);g['mappedLabels']=len(known|un);g['unmappedLabels']=sorted(labels-known-un)
 g['status']='partial-affiliation-evidence' if un or g.get('unconfirmedAcademicLabels')else'academic-labels-covered-or-nonacademic-only'
P.joinpath('agent-c-organizations.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print('mapping',len(M),'unknown',len(unknown),'owners',len(out['courseOwners']),'assoc',len(out['courseAssociations']))
