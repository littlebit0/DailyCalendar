# coding: utf-8
import json,pathlib,re
p=pathlib.Path('work/course-owner-filter-20261012');f=p/'agent-c-organizations.json';o=json.load(open(f));G={}
for file in json.load(open('assets/timetable/catalog.json')):
 d=json.load(open(file))
 if d['universityId']in ['ut','sunmoon']:G[d['universityId']]=d
seen={(m['university'],m['sourceLabel'])for m in o['mappings']}
def add(u,label,college,department,url,source,evidence,known=True,**extra):
 if (u,label)in seen:return
 o['mappings'].append(dict(university=u,campus='unknown',sourceLabel=label,college=college,department=department,sourceUrl=url,sourceFile=source,evidence=evidence,collegeKnown=known,isOfferingUnit=False,**extra));seen.add((u,label))
labels={x for c in G['ut']['courses']for x in c['departments']}
for l in sorted(labels):
 if l.startswith('생명공학전공 '):
  add('ut',l,'보건생명대학','생명공학전공','https://www.ut.ac.kr/biotech/sub01_01.do',str(p/'c-sources/ut-biotech-focus.html'),'Official department greeting explicitly states 보건생명대학 식품생명학부 생명공학전공. Native retained XLS title is 2026학년도 2학기 생명공학전공 강의 시간표. build_ut_partial_20261008.py and blank-room source_builder.py append nativeStudyColumn (grade/group) to actual department; suffix is not department identity.',school='식품생명학부',studyColumn=l[len('생명공학전공 '):],curriculumSourceFile='work/university-research/catalog-c/ut-current-20261008/biotech-original-educational-grid.json')
 elif l.startswith('전기공학과 '):
  add('ut',l,'공과대학','전기공학과','https://www.ut.ac.kr/electri/sub01_01.do',str(p/'c-sources/ut-electri-focus.html'),'Current official department site college breadcrumb sim=공과대학; official 공과대학 homepage academic menu also lists 전기공학과. source_builder.py explicitly constructs 전기공학과 + grade + 학년 from official department timetable PDF. Grade is preserved separately; earlier 2026 early admissions 융합기술대학 name is not used over current official organization.',studyColumn=l[len('전기공학과 '):],curriculumSourceFile='work/university-research/catalog-c/ut-current-electri-exact-75-block-v2-20261009/source_builder.py')
add('sunmoon','미래자동차융합전공',None,'미래자동차융합전공','https://www.kookmin.ac.kr/user/kmuNews/notice/4/12155/view.do','work/university-research/public8-20261012/a/[선문대] 2026-2학기 미래자동차융합전공 학점교류 교과목 목록.xlsx','Official 2026-2 consortium file explicitly names 미래자동차융합전공. Sunmoon official smartcar history confirms this academic major introduced under IT융합학부 in 2021/2022; current college-layer assignment is not explicitly established. Preserve actual major flat; do not infer from parent 미래자동차공학부 or consortium name.',known=False,organizationSourceUrl='https://smartcar.sunmoon.ac.kr/smartcar/cm/cntnts/cntntsView.do?cntntsId=239024&mi=40310',organizationSourceFile=str(p/'c-sources/sunmoon-car-history-focus.html'))
add('sunmoon','교양학부','자유전공대학','교양학부','https://ecrl.sunmoon.ac.kr/initium/cm/cntnts/cntntsView.do?cntntsId=239321&mi=41071',str(p/'c-sources/sunmoon-dla-org-focus.html'),'Current official 자유전공대학 site explicitly lists 교양학부. Importer assigns department from official 교양학부 notice-owning site dla.sunmoon.ac.kr, not from eligibility 컴퓨터공학부 or 이수구분 교필영어 column: current second table headers are 이수구분/과목코드/교과목명/분반/요일시간/담당교수. This is publication/query association; an independent raw offering-owner column is absent.',curriculumSourceUrl='https://dla.sunmoon.ac.kr/dla/na/ntt/selectNttInfo.do?bbsId=1256&mi=41117&nttSn=1324974',curriculumSourceFile=str(p/'c-sources/sunmoon-dla-focus.html'),linkResolutionFile=str(p/'c-sources/sunmoon-link.js'))
for u in G:
 g=next(g for g in o['gaps']if g['university']==u);ms=[m for m in o['mappings']if m['university']==u];known={m['sourceLabel']for m in ms if m['collegeKnown']};unknown={m['sourceLabel']for m in ms if not m['collegeKnown']};alllabels={l for c in G[u]['courses']for l in c['departments']};remaining=alllabels-known-unknown
 g.update(collegeKnownMappedLabels=len(known),collegeUnknownDepartmentLabels=sorted(unknown),mappedLabels=len(known|unknown),unmappedLabels=sorted(remaining),unconfirmedAcademicLabels=sorted(unknown),nonDepartmentLabels=sorted(remaining),status='college-unconfirmed-only'if unknown else'published-academic-labels-covered')
 if u=='ut':g['focusedReview']='All 12 original labels explicitly combine a real department name and a native grade/group column. Real department identity preserved without grade. Current official department affiliation: 생명공학전공→보건생명대학 식품생명학부; 전기공학과→공과대학. Course physical campus remains unknown.'
 else:g['focusedReview']='Future-mobility major explicitly published, current college unknown. 교양학부 official institutional site belongs to current 자유전공대학. Source course table does not itself have an offering-department column; importer uses publishing academic unit. HUSS project categories remain nondepartment. JS link definitions resolved under lily.sunmoon.ac.kr to real HTTPS college/unit URLs; stale descriptive 이니티움 name not used over current site heading.'
f.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
report=p/'agent-c-gaps.md';s=report.read_text();total=len(o['mappings']);unk=sum(not m['collegeKnown']for m in o['mappings']);s=re.sub(r'\d+ mappings: \d+ college-known, \d+ college-unconfirmed\.',f'{total} mappings: {total-unk} college-known, {unk} college-unconfirmed.',s)
for u in G:
 g=next(g for g in o['gaps']if g['university']==u);s=re.sub(r'^\| '+u+r' \|.*$',f"| {u} | {g['collegeKnownMappedLabels']} | {len(g['collegeUnknownDepartmentLabels'])} | {len(g['unmappedLabels'])} |",s,flags=re.M)
s=s.replace('UT grade-level source labels were not converted into departments.','UT grade suffixes are confirmed importer additions to actual named academic units; 12 original labels map to two actual departments.')
s+='\nFocused UT/Sunmoon correction: UT native grade/group suffixes split from actual department identity. Sunmoon current General Education department college confirmed, future mobility major preserved with unknown college. HUSS project categories remain unmapped.\n';report.write_text(s)
print('Total',total,'college unknown',unk)
for u in G:print(u,[(m['sourceLabel'],m['college'],m['department'])for m in o['mappings']if m['university']==u])
