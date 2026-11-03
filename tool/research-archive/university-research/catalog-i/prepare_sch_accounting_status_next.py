"""Immutable missing-time correction; original five-course checkpoint unchanged."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).parent
OLD = ROOT / 'sch-unknown-2026-2.accounting-five-candidate.json'
OLD_SHA = '3c06f4bd3153e056bf4595fa1fadcd196ef16adca0f1c4c6a45203d3d8b5238f'
assert hashlib.sha256(OLD.read_bytes()).hexdigest() == OLD_SHA
obj = json.loads(OLD.read_text())
changed = []
for c in obj['courses']:
    if not c['sourceSchedule']:
        assert c['schedules'] == [] and c['sourceEducationalMetadata']['DAY_TM_NM'] is None
        c['scheduleStatus'] = 'unscheduled'
        changed.append({'code': c['courseCode'], 'section': c['section'], 'scope': c['sourceEducationalMetadata']['operatingReviewScope']})
assert len(changed) == 235
assert sum(r['scope'] == 'no-published-time-operating-mode-unresolved' for r in changed) == 126
assert sum(r['scope'] == 'official-OCU-query' for r in changed) == 109
next_path = ROOT / 'sch-unknown-2026-2.accounting-five-status-next.json'
next_path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')
calendar_path = ROOT / 'sch-2026-calendar-dom.json'
calendar = json.loads(calendar_path.read_text())
raw_rows = [r for r in calendar['rows'] if r['title'] in [
    '2026학년도 2학기 개강일', '2026학년도 2학기 중간평가(중간고사)',
    '2026학년도 2학기 기말평가(기말고사)', '2026학년도 2학기 보강주간']]
assert len(raw_rows) == 4
old_courses = json.loads(OLD.read_text())['courses']
for before, after in zip(old_courses, obj['courses']):
    for key in before:
        if key != 'scheduleStatus':
            assert before[key] == after[key]
    if before['sourceSchedule']:
        assert before == after
proof = {
    'sourceUrl': calendar['sourceUrl'], 'sourceKind': calendar['sourceKind'],
    'calendarSHA256': hashlib.sha256(calendar_path.read_bytes()).hexdigest(),
    'exactDOMTextVerification': calendar['exactDOMTextVerification'],
    'officialCalendarRows': raw_rows,
    'ordinaryRangeDerivation': 'Actual start Aug31 until day before finals Dec7; exclude independently posted midterm Oct19–23. Dec6 end is derived ordinary-window cutoff, not verbatim published semester-end.',
    'ordinaryWindow': ['2026-08-31', '2026-12-06'],
    'originalCandidateSHA256': OLD_SHA,
    'nextCandidateSHA256': hashlib.sha256(next_path.read_bytes()).hexdigest(),
    'statusChangeOnly': 235, 'noPublishedTimeOther': 126, 'noPublishedTimeOCU': 109,
    'scheduledUnchanged': 5, 'datedMeetingsUnchanged': 124,
    'remainingUnrecognized': 2358, 'statusChanges': changed,
    'productionRegistered': False, 'completionClaim': False,
}
(ROOT / 'sch-accounting-five-status-next-audit-20261008.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k:proof[k] for k in ['originalCandidateSHA256','nextCandidateSHA256','calendarSHA256','statusChangeOnly','remainingUnrecognized']}))
