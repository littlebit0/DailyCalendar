"""Independent native lexical/guide/date verification, without Flutter or network."""
import copy
import hashlib
import json
import re
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PRIOR = ROOT.parent
CATALOGS = PRIOR.parent / 'catalogs'
load = lambda p: json.loads(p.read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
proofs = load(ROOT / 'reviewed-source-proofs.json')
by_id = {x['sourceId']: x for x in proofs}
assert len(by_id) == 10
holidays = set(load(PRIOR / 'hufs-registration-checkpoint-review-3-audit.json')['normalDerivedDateProof']['excludedSchoolClosureDates'])
total = scheduled = reservations = prior_scheduled = prior_reservations = 0
source_hashes = {}
for campus in ['seoul', 'global']:
    old_path = PRIOR / f'hufs-{campus}-2026-2.checkpoint-review-3.json'
    native_path = PRIOR / f'hufs-{campus}-2026-2.whole-candidate.json'
    candidate = load(ROOT / f'hufs-{campus}-2026-2.partial-operation-v4-research.json')
    old = load(old_path)
    native = {c['sourceId']: c for c in load(native_path)['courses']}
    prior_by_id = {c['sourceId']: c for c in old['courses']}
    assert {c['sourceId'] for c in candidate['courses']} == set(prior_by_id)
    assert len(candidate['courses']) == len(prior_by_id)
    assert {k: v for k, v in candidate.items() if k != 'courses'} == {k: v for k, v in old.items() if k != 'courses'}
    source_hashes[str(old_path)] = sha(old_path)
    source_hashes[str(native_path)] = sha(native_path)
    for course in candidate['courses']:
        source_id = course['sourceId']
        old_course = prior_by_id[source_id]
        prior_scheduled += bool(old_course['schedules'])
        prior_reservations += len(old_course['schedules'])
        total += 1
        scheduled += bool(course['schedules'])
        reservations += len(course['schedules'])
        if source_id not in by_id:
            assert course == old_course, source_id
            continue
        proof = by_id[source_id]
        source_path = Path(proof['planPath'])
        plan = load(source_path)
        assert sha(source_path) == proof['planSha256']
        source_hashes[str(source_path)] = sha(source_path)
        assert plan['fields']['schedule'].split('\n')[0] == course['sourceSchedule']
        assert plan['fields']['identity'].endswith(course['courseCode'] + course['section'])
        assert plan['fields']['title'].startswith(course['courseName'])
        assert float(plan['fields']['creditsHours'].split('/')[0]) == course['credits']
        assert all(course[k] == old_course[k] for k in course if k not in {'schedules', 'scheduleStatus', 'departmentRemarks'})
        assert all(old_course[k] == native[source_id][k] for k in ['professor', 'credits', 'courseName', 'sourceSchedule', 'sourceClassroom', 'courseCode', 'section'])
        # Parse exact native header independently of builder's approved numerical rule.
        literal = course['sourceSchedule']
        if campus == 'global':
            literal = literal.split(' 목' if course['courseCode'] == 'M012061' else ' 금')[0] + ' (' + course['sourceClassroom'] + ')'
        match = re.fullmatch(r'([월화수목금토일])\s+([0-9 ]+)\s+\(([^)]+)\)', literal)
        assert match, literal
        weekday = '월화수목금토일'.index(match[1]) + 1
        periods = [int(x) for x in match[2].split()]
        assert periods == list(range(min(periods), max(periods) + 1))
        assert all(1 <= x <= 12 for x in periods)
        start = (8 + min(periods)) * 60
        end = (8 + max(periods)) * 60 + 50
        room = match[3]
        expected = []
        cursor = date(2026, 9, 1)
        while cursor <= date(2026, 12, 7):
            is_midterm = proof['individualWeek8Exam'] and date(2026, 10, 20) <= cursor <= date(2026, 10, 26)
            if cursor.isoweekday() == weekday and cursor.isoformat() not in holidays and cursor.isoformat() not in proof['individualKnownNoClassDates'] and not is_midterm:
                expected.append({'weekday': weekday, 'startMinute': start, 'endMinute': end, 'classroom': room, 'date': cursor.isoformat()})
            cursor += timedelta(days=1)
        assert course['schedules'] == expected
        assert len({m['date'] for m in expected}) == len(expected)
        assert course['scheduleStatus'] == 'scheduled'
        assert all('주간 예약 계획' in value for value in course['departmentRemarks'].values())
        if campus == 'global':
            assert '대부분 녹화강의' in plan['fields']['methods']
            assert all(m['weekday'] == weekday for m in expected)

for code, line_range in [('h1', (5643, 5649)), ('h2', (3889, 3898))]:
    path = CATALOGS / f'hufs-guide2-{code}-latest.txt'
    lines = path.read_text().splitlines()
    excerpt = '\n'.join(lines[line_range[0]-1:line_range[1]])
    assert '09:00' in excerpt and '09:50' in excerpt and '20:50' in excerpt
    source_hashes[str(path)] = sha(path)
calendar = (CATALOGS / 'hufs-guide2-h2-latest.txt').read_text().splitlines()[44:78]
assert any('10. 20(화) - 10. 26.(월)' in line and '중간시험' in line for line in calendar)
assert any('12. 8(화) - 12. 14(월)' in line for line in calendar)
assert (total, prior_scheduled, scheduled, reservations - prior_reservations) == (3372, 2196, 2206, 128)
result = {'sourceOnly': True, 'modelValidated': False, 'sdkUsed': False, 'completionClaim': False, 'result': 'PASS', 'wholeNative': total, 'priorScheduledDeepPreserved': prior_scheduled, 'scheduled': scheduled, 'priorReservationsDeepPreserved': prior_reservations, 'newCourses': 10, 'newReservations': reservations - prior_reservations, 'reservations': reservations, 'sourceSha256': source_hashes, 'independentChecks': ['whole native IDs and fields', '2196 prior scheduled exact deep equality', 'unchanged held outside 10', 'public source identity/title/credit/native header', 'literal native own-campus numbered HH table', 'own current midterm dates combined only with individual exam', 'full exact expected ordinary date list and specific cancellation', 'partial recorded weekdays omitted without borrowing rooms']}
(ROOT / 'source-only-independent-validation.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(result, ensure_ascii=False)[:850])
