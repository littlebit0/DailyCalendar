"""Preserve every public teaching row; group identity without discarding variants."""
from pathlib import Path
import collections,json,re
ROOT=Path(__file__).resolve().parent
rows=json.loads((ROOT/'khu-public-all-query-rows.json').read_text())
groups=collections.defaultdict(list)
for row in rows:groups[(row['campus_nm'],row['class_cd'],row['lecture_cd'])].append(row)
categories={'11':'전공기초','04':'전공필수','05':'전공선택','06':'교직과','14':'중핵교과','15':'배분이수교과','16':'기초교과','17':'자유이수','20':'교직전선','24':'계절학기전공필수','27':'계절학기전공기초','08':'일반선택'}
unknown=set(r['field_gb'] for r in rows)-set(categories);assert not unknown,unknown
result=[]
for (campus,department,identity),variants in groups.items():
    # Identical display numbers may have separate instructor sessions or curricular aliases.
    # Keep those source variants, all times, remarks, and category mappings.
    distinct=[];seen=set()
    for row in variants:
        key=json.dumps({k:v for k,v in row.items() if k not in ['queryDepartment','queryDepartmentName','rowid']},ensure_ascii=False,sort_keys=True)
        if key not in seen:seen.add(key);distinct.append(row)
    result.append(dict(campus=campus,department=department,lectureIdentity=identity,displayCodes=sorted(set(r['lecture_cd_disp'] for r in variants)),queryDepartments=sorted(set(r['queryDepartment'] for r in variants)),sourceVariants=distinct))
(ROOT/'khu-public-unique-course-rows.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
audit=dict(queryDepartments=184,rawRows=len(rows),uniqueCampusDepartmentCourseSections=len(groups),campusUniqueCounts=dict(collections.Counter(x['campus'] for x in result)),noClockIdentities=sum(not any(re.search(r'\d{2}:\d{2}-\d{2}:\d{2}',v['timetable']) for v in x['sourceVariants']) for x in result),multipleScheduleIdentities=sum(len(set(v['timetable'] for v in x['sourceVariants']))>1 for x in result),categoryCodeLabels=categories,teachingPeriod={'start':'2026-09-01','end':'2026-12-21','evidence':'khu-calendar-2026.html; sample public PSC3064 syllabus 16주 12/15~12/21'},fullEnablingSafe=False,blockers=['Importer must union all source teaching sessions and preserve course aliases, instructor variants and per-query categories; selecting first duplicate loses 125 schedule identities.', 'No-clock source (- ()) must remain unscheduled; individual intensive/practice courses need their own period semantics.', 'This research collection has not been integrated or regression-tested in the app.'])
(ROOT/'khu-public-catalog-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(audit,ensure_ascii=False,indent=2))
