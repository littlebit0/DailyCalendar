"""10/23 직접 조회에서 원문이 바뀐 항목만 PR #591 자산에 반영한다."""
import json, sys
from pathlib import Path

alt = Path(sys.argv[1]); files = [Path(p) for p in sys.argv[2:]]
rows = {r['COURSE_NO'] + '-' + r['DCLSS_NO']: r for r in json.loads((alt / 'latest-rows.json').read_text())}
diff = json.loads((alt / 'diff-vs-pr591.json').read_text())
room = {x['identity']: x['diff']['강의실'] for x in diff['changed']}
assert set(room) == {'113730-101'} and all(set(x['diff']) == {'강의실'} for x in diff['changed'])
noplan = {x['identity'] for x in diff['unavailable'] if x['assetHadPlan']}
assert noplan == {'105096-101', '106474-101'}
NOTE = (' 2026-10-23 재조회: 공개 강의계획서 버튼이 없어져 새 원문이 없습니다. 10/7 공개 강의계획서와 7/30 개설교과목 현황에 같은 시간·강의실이 '
        '적혀 있어 그 값을 유지합니다.')
done = []
for f in files:
    d = json.loads(f.read_text())
    for c in d['courses']:
        ident = c['courseCode'] + '-' + c['section']; r = rows[ident]
        if c['professor'] != r['STAFF_NM']:
            c['professor'] = r['STAFF_NM']; c['sourceCurrentEducation']['STAFF_NM'] = r['STAFF_NM']; done.append((ident, 'professor'))
        if ident in room:
            old, new = room[ident]; assert c['sourceClassroom'] == old and not c['schedules']
            s = json.loads((alt / 'syllabus' / (ident + '.json')).read_text())
            c['sourceClassroom'] = new
            c['publicPlanEducation']['fields'] = {k: s['fields'][k] for k in c['publicPlanEducation']['fields']}
            c['publicPlanEducation']['verifiedAt'] = s['verifiedAt']; done.append((ident, 'room'))
        if ident in noplan:
            c['remarks'] += NOTE
            c['departmentRemarks'] = {k: v + NOTE for k, v in c['departmentRemarks'].items()}; done.append((ident, 'noplan'))
    f.write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
print(done)
