"""Append official 'GraduateLinked' (학석사연계교과목) offerings to the Kookmin 2026-2 timetable.
Usage: python3 add_graduate_linked.py <repo-worktree> ; reads data/credit-scope-20261023.json and commoncodes-20261023.json."""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]) / 'tool/timetable'))
from import_kookmin import meetings_for, DAY_LABELS
repo = Path(sys.argv[1]); data = Path(__file__).resolve().parent.parent / 'data'
rows = json.loads((data/'credit-scope-20261023.json').read_text())['records']
cc = json.loads((data/'commoncodes-20261023.json').read_text())
dep = {r['deptCd']: r for r in cc['departmentList']}
cat = {r['cmmnCdVal']: r['cdValNm'] for r in cc['commonCdList'] if r['cmmnCd'] == 'SCUR0100'}
BASIS = '학칙 제26조 제3항, 학·석사 연계과정 운영요강 제10조: 학부생 대학원 강좌 수강신청 가능, 대학원 과목'
URL = 'https://sugang.kookmin.ac.kr/front/enrollment/course-catalog'
AFF_URL = 'https://sugang.kookmin.ac.kr/api/subject/public/commoncodes/all'
AFF_FILE = 'work/issue-587-kookmin-timetable/kookmin/data/commoncodes-20261023.json'
cpath = repo/'assets/timetable/kookmin-main-2026-2.json'; opath = repo/'assets/timetable/organizations/kookmin.json'
cd = json.loads(cpath.read_text()); od = json.loads(opath.read_text())
have = {c['sourceId'] for c in cd['courses']}
added, closed, mappings, owners = [], [], {}, []
for r in sorted((r for r in rows if r['type'] == 'GraduateLinked'), key=lambda r: (r['subjectId'], r['classSequence'])):
    if r['closed']: closed.append(r['id']); continue
    code, sec = r['subjectId'], r['classSequence']
    sid = f'kookmin/main/2026/2/{code}/{sec}'
    assert sid not in have
    ms = meetings_for(r)
    college = dep[r['standardDeptCode']]['deptNm']          # official 대학원 단위명
    unit = dep[r['assignedDepartmentCode']]
    assert unit['univCd'] == r['standardDeptCode'] or unit['deptCd'] == r['standardDeptCode']
    own = unit['deptCd'] == r['standardDeptCode']
    label = college if own else f"{college} {unit['deptNm']}"
    remark = '\n'.join(x for x in [r['remark'] or '', BASIS] if x)
    category = cat[r['categoryCode']]
    c = {'sourceId': sid, 'universityId': 'kookmin', 'campus': 'main', 'academicYear': 2026, 'semester': '2',
         'courseCode': code, 'section': sec, 'courseName': r['subjectNm'], 'professor': r['professorName'] or '',
         'credits': r['credits']['credit'],
         'sourceSchedule': '\n'.join(f"{DAY_LABELS[m['weekday']-1]}요일 {m['startMinute']//60:02}:{m['startMinute']%60:02}~{m['endMinute']//60:02}:{m['endMinute']%60:02}" for m in ms),
         'sourceClassroom': '\n'.join(dict.fromkeys(m['classroom'] for m in ms if m['classroom'])),
         'scheduleStatus': 'scheduled' if ms else 'unscheduled', 'schedules': ms, 'departments': [label],
         'departmentCredits': {label: r['credits']['credit']}, 'departmentClassifications': {label: category},
         'departmentRemarks': {label: remark}}
    cd['courses'].append(c); added.append(sid)
    m = {'college': college, 'department': None if own else unit['deptNm'], 'sourceLabel': label, 'sourceUrl': URL,
         'evidence': '현재 공식 시간표 자료의 개설·학과 라벨을 그대로 보존.' if own else 'Official public departmentList univCd identifies exact college ancestry; not query provenance.',
         'sourceFile': None if own else 'work/university-research/catalog-c/kookmin-commoncodes.json',
         'isOfferingUnit': own, 'campus': 'main', 'collegeKnown': True,
         'affiliationSourceUrl': AFF_URL, 'affiliationSourceFile': AFF_FILE,
         'affiliationEvidence': f"국민대학교 공식 수강신청 공개 대학·학과 목록(commoncodes)에서 deptCd {unit['deptCd']} '{unit['deptNm']}'의 상위 단위(univCd {unit['univCd']})가 '{college}'. 공식 개설강좌 조회의 유형 'GraduateLinked'(학석사연계교과목) 강좌."}
    mappings[label] = m
    owners.append({'sourceId': sid, 'units': [dict(m, **{'isOfferingUnit': True}) | {'evidence': 'Actual assignedDepartmentCode joined to official departmentList univCd; exact subjectId/classSequence.', 'sourceFile': AFF_FILE, 'sourceUrl': URL}]})
    for k in ('affiliationSourceUrl', 'affiliationSourceFile', 'affiliationEvidence', 'collegeKnown', 'campus'):
        owners[-1]['units'][0].pop(k, None)
existing = {m['sourceLabel'] for m in od['mappings']}
assert not existing & set(mappings), existing & set(mappings)
od['mappings'] += list(mappings.values()); od['courseOwners'] += owners
cd['coverage'] += '; plus official GraduateLinked(학석사연계교과목) graduate offerings'
cpath.write_text(json.dumps(cd, ensure_ascii=False, indent=2) + '\n'); opath.write_text(json.dumps(od, ensure_ascii=False, indent=2) + '\n')
print(len(added), 'added;', len(mappings), 'mappings; closed skipped', closed)
