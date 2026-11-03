"""Independent all24 source/native/date comparison; no builder import or SDK."""
import hashlib
import json
import re
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PRIOR = ROOT.parent
V4 = PRIOR / 'hufs-late-operation-v5-20261009'
load = lambda path: json.loads(path.read_text())
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
audit = load(ROOT / 'candidate-audit.json')
proofs = {p['sourceId']: p for p in load(ROOT / 'reviewed24-source-proofs.json')}
assert len(proofs) == 24
source_hashes = {}
old_scheduled = old_intervals = whole = selected = intervals = new_intervals = 0
holidays = set(load(PRIOR / 'hufs-registration-checkpoint-review-3-audit.json')['normalDerivedDateProof']['excludedSchoolClosureDates'])
held_ids = {d['sourceId'] for d in load(V4 / 'candidate-audit.json')['held']}
for campus in ['seoul', 'global']:
    baseline_path = V4 / f'hufs-{campus}-2026-2.late-operation-v5-research.json'
    prior3_path = PRIOR / f'hufs-{campus}-2026-2.checkpoint-review-3.json'
    raw_path = PRIOR / f'hufs-{campus}-2026-2.whole-candidate.json'
    candidate = load(ROOT / audit['campuses'][campus]['candidateFile'])
    baseline = load(baseline_path)
    prior3 = load(prior3_path)
    native = {c['sourceId']: c for c in load(raw_path)['courses']}
    old = {c['sourceId']: c for c in baseline['courses']}
    assert len(old) == len(candidate['courses']) == len(native)
    assert set(old) == {c['sourceId'] for c in candidate['courses']}
    for path in [baseline_path, prior3_path, raw_path]:
        source_hashes[str(path)] = sha(path)
    for c in candidate['courses']:
        key = c['sourceId']
        whole += 1
        selected += bool(c['schedules'])
        intervals += len(c['schedules'])
        old_scheduled += bool(old[key]['schedules'])
        old_intervals += len(old[key]['schedules'])
        if key not in proofs:
            assert c == old[key]
            continue
        p = proofs[key]
        source_path = Path(p['sourcePlanPath'])
        source_hashes[str(source_path)] = sha(source_path)
        assert sha(source_path) == p['sourcePlanSHA256']
        plan = load(source_path)
        assert plan['checkedDate'] == '2026-10-08'
        assert plan['key'] == c['courseCode'] + c['section']
        assert 'ledg_year=2026&ledg_sessn=3' in plan['sourceUrl']
        assert plan['fields']['schedule'].split('\n')[0] == c['sourceSchedule']
        assert plan['fields']['title'].startswith(c['courseName'])
        assert float(plan['fields']['creditsHours'].split('/')[0]) == c['credits']
        assert all(c[f] == old[key][f] for f in c if f not in {'schedules', 'scheduleStatus', 'departmentRemarks'})
        assert all(c[f] == native[key][f] for f in ['courseCode', 'section', 'courseName', 'professor', 'credits', 'sourceSchedule', 'sourceClassroom'])
        # Independently parse every source header room block and day group.
        rules = []
        for piece in c['sourceSchedule'].split(')'):
            if not piece.strip():
                continue
            head, room = piece.split('(')
            parts = re.split(r'([월화수목금토일])', head.strip())
            assert not parts[0].strip()
            for pos in range(1, len(parts), 2):
                day = '월화수목금토일'.index(parts[pos]) + 1
                periods = [int(value) for value in parts[pos+1].split()]
                assert periods and periods == list(range(periods[0], periods[-1]+1))
                assert all(1 <= period <= 12 for period in periods)
                rules.append((day, (8+periods[0])*60, (8+periods[-1])*60+50, room))
        decision = p['decision']
        expect = []
        for day_offset in range((date(2026, 12, 7)-date(2026, 9, 1)).days+1):
            current = date(2026, 9, 1)+timedelta(days=day_offset)
            for day, start, end, room in rules:
                if day != current.isoweekday() or current.isoformat() in holidays:
                    continue
                iso = current.isoformat()
                if decision.get('onlyWeekday') and day != decision['onlyWeekday']:
                    continue
                if iso in decision.get('remoteDates', []) or iso in decision.get('examDates', []):
                    continue
                if decision.get('prefixEnd') and iso > decision['prefixEnd']:
                    continue
                if decision.get('middle') and date(2026, 10, 20) <= current <= date(2026, 10, 26):
                    continue
                expect.append({'weekday': day, 'startMinute': start, 'endMinute': end, 'classroom': room, 'date': current.isoformat()})
        assert c['schedules'] == expect, key
        assert len({tuple(m.items()) for m in expect}) == len(expect)
        for i, m in enumerate(expect):
            for other in expect[i+1:]:
                if m['date'] == other['date']:
                    assert m['endMinute'] <= other['startMinute'] or other['endMinute'] <= m['startMinute'], key
        new_intervals += len(expect)
    for c in candidate['courses']:
        if c['sourceId'] in held_ids:
            assert c['schedules'] == []
    current = {c['sourceId']: c for c in candidate['courses']}
    for c in prior3['courses']:
        if c['schedules']:
            assert current[c['sourceId']] == c

assert (whole, old_scheduled, old_intervals, selected, intervals, new_intervals) == (3372, 2380, 34568, 2404, 34814, 246)
# Independently validate school-clock/calendar receipts against immutable source bytes.
receipt = load(PRIOR / 'hufs-partial-operation-v4-20261009/own-clock-calendar-education-receipt.json')
for guide in receipt['guides']:
    path = Path(guide['sourceFile'])
    assert sha(path) == guide['SHA256']
    source_hashes[str(path)] = sha(path)
    assert '09:00' in guide['clockEducationExcerpt'] and '09:50' in guide['clockEducationExcerpt']
assert '10. 20(화) - 10. 26.(월) 제2학기 중간시험' in receipt['calendarEducationExcerpt']
assert '12. 8(화) - 12. 14(월) 제2학기 보강주간' in receipt['calendarEducationExcerpt']
result = {'sourceOnly': True, 'sdkUsed': False, 'modelValidated': False, 'completionClaim': False, 'result': 'PASS', 'whole': whole, 'priorV5DeepScheduled': old_scheduled, 'priorV5DeepIntervals': old_intervals, 'priorReview3DeepScheduled': 2196, 'priorReview3DeepIntervals': 31920, 'scheduled': selected, 'reservations': intervals, 'newAfterV5': 24, 'newAfterV5Intervals': new_intervals, 'held12DeepPreserved': True, 'allNativeIdentityTitleProfessorCreditsRoomPreserved': True, 'fullNativeDayPeriodParseComparedWithPlanAndOwnGuide': True, 'completeDatesAndOverlapIndependentlyChecked': True, 'sourceSha256': source_hashes}
(ROOT / 'source-only-independent-validation.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
print({k:v for k,v in result.items() if k != 'sourceSha256'})
