import json,pathlib,re,collections
P=pathlib.Path('work/course-owner-filter-20261012');f='work/university-research/expansion17-20261011/c/pcu-native-positioned-pages.json';pages=json.load(open(f));out=json.load(open(P/'agent-c-organizations.json'));url='https://hakgwa.pcu.ac.kr/ce/article/depart_ce_notice/37507';deptcollege={};colleges=['인문사회대학','경영대학','생명보건대학','AI·SW창의융합대학','문화예술대학','아펜젤러공유대학','주시경교양대학']
# Explicit final department/college contact table; ignore outdated alternating page running headers.
for p in pages:
 if p['page']not in [315,316]:continue
 for e in p['elements']:
  if e['x']>=150:continue
  col=next((c for c in colleges if e['text'].startswith(c)),None)
  if not col:continue
  rest=e['text'][len(col):].strip()
  deps=[rest]if rest else [x['text']for x in p['elements']if 165<=x['x']<=185 and abs(x['y']-e['y'])<=12]
  for dep in deps:
   if dep:deptcollege[dep]=col
assoc=collections.defaultdict(set);current=None;mapheads={};coursekeys={c['courseCode']+'-'+c['section']:c for c in json.load(open('assets/timetable/pcu-main-2026-2.json'))['courses']}
for p in pages:
 if not 185<=p['page']<=243:continue
 for e in sorted(p['elements'],key=lambda x:(x['y'],x['x'])):
  h=re.match(r'^<([^>]+)>',e['text'])
  if h:current=h[1].strip()
  if not current:continue
  m=re.search(r'\b([A-Z]{2,6}\d{4,})\b',e['text'])
  if not m:continue
  row=sorted([x for x in p['elements']if abs(x['y']-e['y'])<=2],key=lambda x:x['x']);txt=' '.join(x['text']for x in row)
  r=re.match(r'^(\d+)\s+(교필선|교필|교선필|교선|전필|전선|자선|교직|공필|공선)\s+([A-Z]{2,6}\d{4,})\s+(.+?)\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s+(\d{2})\s+(.+)$',txt)
  if not r:continue
  key=r[3]+'-'+r[7]
  if key not in coursekeys:continue
  assoc[key].add((current,p['page'],e['y']))
for key,vs in assoc.items():
 for label,page,y in vs:
  base=label.split('-')[0];base=re.sub(r'\((공학|이학)\)$','',base);base=base.replace('소프트웨어학부','소프트웨어공학부').replace('글로벌자율융합학부','글로벌융합학부')
  col=deptcollege.get(base)
  if not col:continue
  mapheads[label]=(col,label)
  out.setdefault('courseAssociations',[]).append(dict(sourceId=coursekeys[key]['sourceId'],college=col,department=label,sourceLabel=label,sourceUrl=url,sourceFile=f,evidence=f'Official positioned PDF preview page {page} (printed {page-6}), academic table heading <{label}> precedes exact code+section row at y={y}; college relationship explicit printed309/310 organization table. Association retained independent of actual host.'))
for label,(col,dep)in mapheads.items():out['mappings'].append(dict(university='pcu',campus='main',sourceLabel=label,college=col,department=dep,sourceUrl=url,sourceFile=f,evidence='Official academic timetable table heading; explicit printed309/310 college/department organization table. Some prior degree labels mapped only via explicit same source parent continuity.',isOfferingUnit=False))
for g in out['gaps']:
 if g['university']=='pcu':g.update(mappedLabels=len(mapheads),courseAssociations=len(assoc),reason='Native parser omitted all departments despite official page-level curriculum headings. Added sourceId courseAssociations. General/교직 rows without explicit academic owner remain unmapped; do not infer from course title or eligible departments.')
P.joinpath('agent-c-organizations.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print('pcu mappings',len(mapheads),'courses with associations',len(assoc),'mapped associations',len(out.get('courseAssociations',[])))
