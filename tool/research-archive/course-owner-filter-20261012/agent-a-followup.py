import json,re,pathlib,collections
O=pathlib.Path('work/course-owner-filter-20261012');x=json.load(open(O/'agent-a-organizations.json'));ds=[(p,json.load(open(p))) for p in json.load(open('assets/timetable/catalog.json'))];units={u:sorted({v for p,d in ds if d['universityId']==u for c in d['courses'] for v in c.get('departments',[])}) for u in ['gachon','cnu']};evg='Official ssu1000q.clx.js grid colIndex8 header 개설조직 binds PRINT_DPT; trailing 1..6 is attached academic year marker, never used alone to infer department. ';gfile='work/university-research/catalog-g/gachon-public-ssu1000q.clx.js'
def add(u,lab,col,dep,url,file,ev,known=True,off=True):
 m=dict(university=u,campus='*',sourceLabel=lab,college=col,department=dep,sourceUrl=url,sourceFile=file,evidence=ev,isOfferingUnit=off)
 if not known:m.update(collegeKnown=False,collegeOnlyEligible=False)
 x['mappings'].append(m)
roster={'간호학과':('간호대학',1017),'물리치료학과':('의과학대학',1018),'치위생학과':('의과학대학',1018),'방사선학과':('의과학대학',1018),'응급구조학과':('의과학대학',1018),'약학과':('약학대학',1016),'바이오로직스학과':('약학대학',1016),'연기예술학과':('예술·체육대학',1013),'음악학부':('예술·체육대학',1013),'미술·디자인학부':('예술·체육대학',1013)}
for maj in ['산업디자인전공','시각디자인전공','조소전공','회화전공']:roster['미술·디자인학부('+maj+')']=('예술·체육대학',1013)
for maj in ['성악전공','작곡전공','기악전공']:roster[maj]=('예술·체육대학',1013)
for lab in units['gachon']:
 for part in lab.split('/'):
  dep=re.sub(r'[1-6]$','',part.strip())
  if dep in roster:
   col,idx=roster[dep];add('gachon',lab,col,dep,'https://www.gachon.ac.kr/kor/'+str(idx)+'/subview.do',gfile,evg+'Official current college page explicitly lists this department/faculty/major.')
  elif dep in ['AI인문대학','반도체대학','법과대학','가천리버럴아츠칼리지']:
   idx={'AI인문대학':1007,'반도체대학':1019,'법과대학':1008,'가천리버럴아츠칼리지':1003}[dep];add('gachon',lab,dep,None,'https://www.gachon.ac.kr/kor/1016/subview.do',gfile,evg+'Official current navigation explicitly lists this college; source printed college/year directly, not inferred from child departments.')
  elif re.fullmatch(r'[^/\n0-9]+(?:학과|학부|전공)(?:\([^()]+(?:전공|학제)\))?',dep) and not dep.startswith('교양'):
   add('gachon',lab,None,dep,'https://info.gachon.ac.kr/ssu/showTimetable.do',gfile,evg+'Exact opening department/major component is published; college unknown after current roster research, preserve source name without inferred affiliation.',False)
# CNU current native response explicitly separates OPEN_SUST_MJ_CD_NM from TRGT_SHYR.
cf='work/university-research/catalog-f/cnu-selectList01.json';rows=json.load(open(cf))['ds_out'];native={r['OPEN_SUST_MJ_CD_NM'] for r in rows};url='https://cnuit.cnu.ac.kr/checkMenu.jsp?p0=M69r16057e79Y231';current={m['sourceLabel'] for m in x['mappings'] if m['university']=='cnu'}
for lab in units['cnu']:
 if lab in current or lab not in native:continue
 ev='Official native row OPEN_SUST_MJ_CD_NM opening unit is separate from TRGT_SHYR target year; exact source label retained. '
 if lab.startswith('예술대 '):add('cnu',lab,'예술대학',lab[4:],url,cf,ev+'Official 관현악과 website footer names 예술대학; source grouping abbreviation 예술대 retained in sourceLabel. https://orch.cnu.ac.kr/orch/intro/career.do')
 elif lab.startswith('자연대 무용학과 '):add('cnu',lab,'자연과학대학',lab[4:],url,cf,ev+'Official CNU current natural sciences roster identifies 무용학과 in 자연과학대학; source submajor explicit.')
 elif not lab.startswith('소단위 전공과정') and lab!='대학 학과공통':
  col=None;dep=lab.removeprefix('충남대학교 ')
  if dep=='창의융합대학':col=dep;dep=None
  add('cnu',lab,col,dep,url,cf,ev+'Actual full opening faculty/department/program preserved; college layer unknown unless explicit college title.',col is not None)
# Promote verified Gachon mappings to actual opening semantics. No college host inference from children.
for m in x['mappings']:
 if m['university']=='gachon':m['isOfferingUnit']=True;m['evidence']+=' Native original PRINT_DPT is officially labelled 개설조직 (retained '+gfile+').'
# Single unambiguous native unit per course only; composite or conflicting affiliations do not yield guessed primary owners.
indices={u:collections.defaultdict(list) for u in units}
for m in x['mappings']:
 if m['university'] in indices:indices[m['university']][m['sourceLabel']].append(m)
rawc={r['COURSE_NO']:r for r in rows};added=collections.Counter()
for p,d in ds:
 u=d['universityId']
 if u not in indices:continue
 for c in d['courses']:
  labels=c.get('departments',[])
  if u=='cnu':
   row=rawc.get(c['courseCode']+'-'+c['section']);labels=[row['OPEN_SUST_MJ_CD_NM']] if row else []
  if len(labels)!=1 or '/' in labels[0]:continue
  lab=labels[0];ms=indices[u].get(lab,[]);verified=[m for m in ms if m.get('isOfferingUnit')]
  if u=='cnu':verified=ms # source returned opening field independently proves organizer.
  pairs={(m['college'],m['department']) for m in verified}
  # Known affiliation takes precedence over earlier unknown-parent preservation of exact same unit.
  known={pair for pair in pairs if pair[0] is not None}
  if len(known)==1:pairs=known
  if len(pairs)!=1:continue
  col,dep=next(iter(pairs));m=next(m for m in verified if (m['college'],m['department'])==(col,dep));owner=dict(sourceId=c['sourceId'],college=col,department=dep,sourceLabel=lab,sourceUrl=d['sourceUrl'],sourceFile=cf if u=='cnu' else gfile,evidence=('CNU exact COURSE_NO joins returned OPEN_SUST_MJ_CD_NM. ' if u=='cnu' else 'Gachon exact current course has one PRINT_DPT opening organization. ')+m['evidence'])
  if col is None:owner.update(collegeKnown=False,collegeOnlyEligible=False)
  x['courseOwners'].append(owner);added[u]+=1
md={}
for m in x['mappings']:md.setdefault((m['university'],m['campus'],m['sourceLabel'],m['college'],m['department'],m['isOfferingUnit']),m)
x['mappings']=list(md.values());od={}
for m in x['courseOwners']:od.setdefault((m['sourceId'],m['college'],m['department']),m)
x['courseOwners']=list(od.values())
for g in x['gaps']:
 if g['university'] in units:
  have={m['sourceLabel'] for m in x['mappings'] if m['university']==g['university']};g['unmappedLabels']=[v for v in g['unmappedLabels'] if v not in have]
  if g['university']=='cnu':g['reason']='Remaining source labels are 소단위 전공과정/microdegree categories or 대학 학과공통. OPEN_SUST_MJ_CD_NM is actual opening-field, but these course/program categories do not establish a real department or named college; retain course fields without invented department.'
  else:g['reason']='Remaining opening PRINT_DPT strings consist of shorthand legacy department names, year suffixes, or mixed aliases. Current roster checked; exact full department components normalized where available, no abbreviation-to-full-name guess. More official legacy alias crosswalk needed.'
json.dump(x,open(O/'agent-a-organizations.json','w'),ensure_ascii=False,indent=2);print(len(x['mappings']),len(x['courseOwners']),added,sum(len(g['unmappedLabels']) for g in x['gaps']))
