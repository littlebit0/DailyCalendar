# coding: utf-8
import json,pathlib,re
p=pathlib.Path('work/course-owner-filter-20261012');f=p/'agent-c-organizations.json';o=json.load(open(f));page=p/'c-sources/smu-more-31dd7d3074a7.html';body=re.sub(r'<!--.*?-->','',page.read_text(),flags=re.S)
proof={'사진영상미디어전공':('예술대학','예술학부'),'연극전공':('예술대학','예술학부'),'영화영상전공':('예술대학','예술학부'),'텍스타일디자인전공':('디자인대학','디자인학부'),'커뮤니케이션디자인전공':('디자인대학','디자인학부'),'인더스트리얼디자인전공':('디자인대학','디자인학부')}
o['mappings']=[m for m in o['mappings'] if not(m['university']=='smu' and m['department']=='전체학과')]
for m in o['mappings']:
 if m['university']!='smu' or m['sourceLabel']not in proof:continue
 college,school=proof[m['sourceLabel']];label=m['sourceLabel'];assert label in body
 m.update(campus='cheonan',college=college,school=school,department=label,collegeKnown=True,isOfferingUnit=False,sourceUrl='https://www.smu.ac.kr/ko/edu/cheonan01.do',sourceFile=str(page),evidence='Official Cheonan campus education page, HTML comments excluded: '+college+' section explicitly lists '+school+' and '+label+'. Exact leaf heading also published in official 2026-2 Cheonan curriculum PDF (retained work/timetable-sources/cheonan.txt). Curriculum/query association only; no direct college hosting claim.')
 m['curriculumSourceUrl']='https://www.smu.ac.kr/kor/life/notice.do?articleNo=767028&attachNo=562397&mode=download';m['curriculumSourceFile']='work/timetable-sources/cheonan.txt'
g=next(g for g in o['gaps']if g['university']=='smu');ms=[m for m in o['mappings']if m['university']=='smu'];kn={m['sourceLabel']for m in ms if m['collegeKnown']};un={m['sourceLabel']for m in ms if not m['collegeKnown']};labels=set()
for path in json.load(open('assets/timetable/catalog.json')):
 d=json.load(open(path))
 if d['universityId']=='smu':labels.update(l for c in d['courses']for l in c.get('departments',[]))
g.update(collegeKnownMappedLabels=len(kn),collegeUnknownDepartmentLabels=sorted(un),mappedLabels=len(kn|un),unmappedLabels=sorted(labels-kn-un),unconfirmedAcademicLabels=sorted(set(g['unconfirmedAcademicLabels'])-set(proof)-{'전체학과'}),nonDepartmentLabels=sorted(set(g['nonDepartmentLabels'])|{'전체학과'}))
g['excludedNonDepartmentMappings']=[{'sourceLabel':'전체학과','reason':'Whole-institution curriculum query category; not one named academic department. Removed mapping and retained as gap.'}]
g['focusedCheonanReview']={'sourceUrl':'https://www.smu.ac.kr/ko/edu/cheonan01.do','sourceFile':str(page),'curriculumSourceFile':'work/timetable-sources/cheonan.txt','confirmed':proof,'microMajorPolicy':'Micro-majors have no inferred single college; existing unknown college remains unknown.'}
f.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
report=p/'agent-c-gaps.md';text=report.read_text();text=re.sub(r'^\| smu \|.*$', '| smu | '+str(len(kn))+' | '+str(len(un))+' | '+str(len(g['unmappedLabels']))+' |',text,flags=re.M);text+='\nFocused SMU follow-up: removed whole-department category. Six Cheonan majors confirmed in official Arts/Design college school lists and exact curriculum headings. Micro-majors remain without inferred single college.\n';report.write_text(text)
print('smu known',len(kn),'unknown',len(un),'unmapped',len(g['unmappedLabels']));print('total mappings',len(o['mappings']),'unknown',sum(not m['collegeKnown']for m in o['mappings']))
