import json,pathlib,re
from lxml import html
O=pathlib.Path('work/course-owner-filter-20261012');x=json.load(open(O/'agent-a-organizations.json'));p=O/'agent-a-sources/gjue-official-header.html';r=html.fromstring(p.read_text());roster={a.text_content().strip():a.get('href') for a in r.xpath('//a[contains(@href,"major/view")]') if a.text_content().strip().endswith('과')};print(roster)
gap=next(g for g in x['gaps'] if g['university']=='gjue');base={'국어':'국어교육과','윤리':'윤리교육과','사회':'사회과교육과','수학':'수학교육과','과학':'과학교육과','실과':'실과교육과','체육':'체육교육과','음악':'음악교육과','미술':'미술교육과','영어':'영어교육과','교육':'교육학과','컴퓨터':'컴퓨터교육과'}
for lab in gap['unmappedLabels']:
 m=re.fullmatch(r'[1-4]학년 \d+반 (.+)',lab)
 if not m:continue
 dep=base.get(m[1]);url=roster.get(dep)
 if url:x['mappings'].append(dict(university='gjue',campus='*',sourceLabel=lab,college=None,department=dep,sourceUrl='https://www.gjue.ac.kr'+url,sourceFile=str(p),evidence='Official public homepage publishes /seqHtml/kor_header.html as its GET menu source. Current academic menu lists direct 학부 departments without college layer. Current 2026-2 final Excel year timetable row3 has class number, row4 separately printed 심화 department shorthand; source association uses row4, not inferred from class number. Workbook work/university-research/catalog-g/gjue2026-2-final0823.xlsx.',isOfferingUnit=False))
x['mappings']=[m for m in x['mappings'] if not(m['university']=='gachon' and '/' in m['sourceLabel'] and m['department'] is None)]
for m in x['mappings']:
 if m['university']=='gachon' and m['department'] is None:m['collegeOnlyEligible']='/' not in m['sourceLabel']
# Exact college-host-only entries require full original opening field to be the college plus optional grade.
for owner in x['courseOwners']:
 if owner.get('sourceId','').startswith('gachon/') and owner['department'] is None:owner['collegeOnlyEligible']=bool(owner['college'] and re.sub(r'[1-6]$','',owner['sourceLabel'])==owner['college'])
have={m['sourceLabel'] for m in x['mappings'] if m['university']=='gjue'};gap['unmappedLabels']=[v for v in gap['unmappedLabels'] if v not in have];gap['reason']='Official header menu route successfully recovered from published homepage AJAX URL; all48 exact cohort associations mapped using separate department-shorthand row and official roster. This is association-only, not opening host.'
x['gaps']=[g for g in x['gaps'] if g['unmappedLabels'] or g.get('courseCount')]
x['researchCompletion']['scopeInspected']=33;x['researchCompletion']['allAffiliationsVerified']=False;x['researchCompletion']['unknownCollegeDepartmentCount']=sum(m.get('collegeKnown') is False for m in x['mappings']);json.dump(x,open(O/'agent-a-organizations.json','w'),ensure_ascii=False,indent=2)
lines=['# Agent A sources final follow-up','',f'{len(x["mappings"])} mappings, {len(x["courseOwners"])} exact current opening-owner rows, {sum(len(g["unmappedLabels"]) for g in x["gaps"])} remaining original labels. 33 schools inspected; affiliation completeness remains false.','', 'Gachon source grid explicitly labels PRINT_DPT as 개설조직. Exact full department/faculty/major plus trailing grade is separated. Composite opening values never yield a direct college-only owner from an embedded college string. Multiple-unit composites were not assigned one guessed primary host.','', 'CNU source native opening OPEN_SUST_MJ_CD_NM is independent of TRGT_SHYR. Exact course COURSE_NO joins opening-owner rows. Explicit 예술대/자연대 academic structure links recovered. Small-unit microdegree category and 대학 학과공통 remain unassigned to real departments.','', 'GJUE official department roster successfully recovered through the published homepage GET /seqHtml/kor_header.html. 2026-2 original timetable separates year/class row3 and subject/심화 row4; all48 associations recovered. These remain isOfferingUnit:false.','', 'Remaining labels:']
for g in x['gaps']:lines.append('- '+g['university']+': '+str(len(g['unmappedLabels']))+'. '+g['reason'])
lines+=['','Product untouched; no tests/build/install/login. Official full source snapshots and Daegu 2026 roster retained. Daegu OCR abbreviation crosswalk never guessed.']
(O/'agent-a-missing.md').write_text('\n'.join(lines));print('final',len(x['mappings']),len(x['courseOwners']),sum(len(g['unmappedLabels']) for g in x['gaps']))
