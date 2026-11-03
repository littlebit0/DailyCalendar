exec(open('work/course-owner-filter-20261012/c-sources/add_c_homes.py').read().split('receipts=')[0])
rs=json.load(open(P/'c-sources/college-receipts.json'));hier=collections.defaultdict(lambda:collections.defaultdict(set));refs={};strip=lambda s:html.unescape(re.sub('<[^>]+>','',s)).strip()
for r in rs:
 if 'file'not in r:continue
 u=r['university'];col=r['college'];b=pathlib.Path(r['file']).read_text();deps=[]
 if u=='pnu':
  for block in re.findall(r'<ul class="gradu-list"[^>]*>(.*?)</ul>',b,re.S):deps.extend(strip(x)for x in re.findall(r'<a[^>]*>(.*?)</a>',block,re.S))
 elif u=='sookmyung':
  block=re.search(r'<select class="tab-sel"[^>]*>(.*?)</select>',b,re.S)
  if block:deps=[strip(x)for x in re.findall(r'<option[^>]*>(.*?)</option>',block[1],re.S)]
 elif u=='syu':deps=[strip(x)for x in re.findall(r'<h3 class="md_b_tit mb5"[^>]*>(.*?)</h3>',b,re.S)]
 for dep in deps:
  hier[u][norm(dep)].add(col);refs[(u,col)]=r
for u in hier:
 for d in G[u]:
  for l in {l for c in d['courses']for l in c.get('departments',[])}:
   candidates=[norm(l)]
   if u=='pnu':candidates.append(norm(re.sub(r'\s*\([^)]*(?:\d|\+82)[^)]*\)$','',l)))
   if u=='syu':candidates.append(norm(re.sub(r'\s*\((?:4년|5년|6년제)\)$','',l)))
   cs=set().union(*(hier[u].get(a,set())for a in candidates))
   if len(cs)==1:
    col=next(iter(cs));r=refs[(u,col)];add(u,l,col,l,r['sourceUrl'],r['file'],'Official college-page academic unit list; exact label after removing only published phone number/degree-duration suffix. Affiliation only.')
# Native Sungkyul 2026 current admissions table, table rowspan gives academic college.
r=next(r for r in rs if r['university']=='sungkyul-table');b=pathlib.Path(r['file']).read_text();block=b.split('모집단위[신입학 기준]')[-1].split('등록금')[0];col=None;hs={}
for row in re.findall(r'<tr[^>]*>(.*?)</tr>',block,re.S):
 cells=[strip(c)for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',row,re.S)]
 if not cells:continue
 if cells[0].endswith('대학'):col=cells.pop(0)
 if col and cells and re.search(r'(학과|학부|과)$',cells[0]):hs[cells[0]]=col
for d in G['sungkyul']:
 for l in {l for c in d['courses']for l in c.get('departments',[])}:
  clean=re.sub(r'\(2부\)$','',l);col=hs.get(clean)
  if col:add('sungkyul',l,col,clean,r['sourceUrl'],r['file'],'Official 2026 admissions academic college table with rowspan carries college; (2부) denotes day/evening track of same named department.')
for g in out['gaps']:
 u=g['university'];labels={l for d in G[u]for c in d['courses']for l in c.get('departments',[])};mapped={r['sourceLabel']for r in M if r['university']==u};g['unmappedLabels']=sorted(labels-mapped);g['mappedLabels']=len(mapped)
P.joinpath('agent-c-organizations.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print([(g['university'],g['mappedLabels'],g['labelCount'])for g in out['gaps']])
