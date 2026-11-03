exec(open('work/course-owner-filter-20261012/c-sources/add_c_homes.py').read().split('receipts=')[0])
rs=json.load(open(P/'c-sources/more-receipts.json'));strip=lambda s:html.unescape(re.sub('<[^>]+>','',s)).strip();h=collections.defaultdict(dict);refs={}
for r in rs:
 if 'file'not in r:continue
 u=r['university'];b=pathlib.Path(r['file']).read_text();refs[u]=r
 if u=='sch':
  for block in re.findall('<ul class="ui_tab_handle">(.*?)</ul>',b,re.S):
   for a in re.findall('<a[^>]*>(.*?)</a>',block,re.S):h[u][norm(strip(a))]=(r['college'],r)
 if u=='uos':
  for row in re.findall('<tr[^>]*>(.*?)</tr>',b,re.S):
   th=re.search('<th[^>]*>(.*?)</th>',row,re.S)
   if not th:continue
   col=strip(th[1]).replace('다운로드','').strip()
   if not col.endswith('대학'):continue
   td=re.search('<td[^>]*>(.*?)</td>',row,re.S)
   if td:
    for a in re.findall('<a[^>]*>(.*?)</a>',td[1],re.S):h[u][norm(strip(a).replace('다운로드',''))]=(col,r)
 if u=='smu':
  cols=re.findall('<h4 class="h4-tit"[^>]*>([^<]+대학)</h4>',b)
  for d in G[u]:
   if d['campus']!='cheonan':continue
   for l in {l for c in d['courses']for l in c.get('departments',[])}:
    for col in cols:
     if l.startswith(col):add(u,l,col,l[len(col):].strip()or None,r['sourceUrl'],r['file'],'Exact source curriculum encoded college prefix, confirmed by official Cheonan college page. Curriculum association.',campus='cheonan');break
 if u=='postech':
  units={strip(x)for x in re.findall('<h[23][^>]*>(.*?)</h[23]>',b,re.S)}
  for d in G[u]:
   for l in {l for c in d['courses']for l in c.get('departments',[])}:
    if l in units:add(u,l,None,l,r['sourceUrl'],r['file'],'Official education page lists academic departments directly under undergraduate/graduate divisions; institution has no college layer in this organization.')
 if u=='ulsan':
  if '자율전공학부'in b and '아산아너스칼리지'in b:h[u][norm('자율전공학부')]=('아산아너스칼리지',r)
for u in h:
 for d in G[u]:
  for l in {l for c in d['courses']for l in c.get('departments',[])}:
   if norm(l)in h[u]:
    col,r=h[u][norm(l)];add(u,l,col,l,r['sourceUrl'],r['file'],'Official college-specific tab list / college-row curriculum table gives exact department affiliation; association only.')
for g in out['gaps']:
 u=g['university'];labels={l for d in G[u]for c in d['courses']for l in c.get('departments',[])};mapped={r['sourceLabel']for r in M if r['university']==u};g['unmappedLabels']=sorted(labels-mapped);g['mappedLabels']=len(mapped)
P.joinpath('agent-c-organizations.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print([(g['university'],g['mappedLabels'],g['labelCount'])for g in out['gaps']])
