"""Current official ordinary/exam/makeup windows; metadata/clock unchanged."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).parent
old_path = ROOT / 'kunsan-current-whole-clock-checkpoint-next-20261008.json'
old_bytes = old_path.read_bytes()
obj = json.loads(old_bytes)
changes = []
for c in obj['courses']:
    before = c['schedules']
    # The current public calendar separately names these examination windows.
    # Do not generate examination attendance from the regular teaching rule.
    after = [m for m in before if not (
        '2026-10-19' <= m['date'] <= '2026-10-23'
        or '2026-12-11' <= m['date'] <= '2026-12-17')]
    if before != after:
        changes.append({'sourceId': c['sourceId'], 'before': len(before), 'after': len(after)})
    c['schedules'] = after
    if after:
        c['period'] = {'startDate': '2026-08-31', 'endDate': '2026-12-10'}
obj['ordinaryTeachingDatesReviewed'] = True
obj['finalActiveScopeVerified'] = False
obj['productionReady'] = False
obj['completionClaim'] = False
next_path = ROOT / 'kunsan-current-whole-operating-date-checkpoint-next-20261008.json'
next_path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n')
old_courses = json.loads(old_bytes)['courses']
for before, after in zip(old_courses, obj['courses']):
    for key in before:
        if key not in ['schedules', 'period']:
            assert before[key] == after[key]
    for m in after['schedules']:
        assert m in before['schedules']
        assert '2026-08-31' <= m['date'] <= '2026-12-10'
        assert m['date'] not in {'2026-09-24', '2026-09-25', '2026-10-05', '2026-10-09'}
        assert m['weekday'] not in [6, 7]
assert len(obj['courses']) == 1718
assert sum(bool(c['schedules']) for c in obj['courses']) == 800
makeup_counts = {day: sum(m['date'] == day for c in obj['courses'] for m in c['schedules'])
                 for day in ['2026-12-07', '2026-12-08', '2026-12-09', '2026-12-10']}
calendar_path = ROOT / 'kunsan-current-calendar-operating-review-20261008.json'
calendar = json.loads(calendar_path.read_text())
audit = {
    'reviewDate': '2026-10-08', 'wholeScope': 1718, 'scheduledResearchOnly': 800,
    'remainingUnrecognized': 820, 'publishedOCUKCUUntimed': 98,
    'originalSHA256': hashlib.sha256(old_bytes).hexdigest(),
    'candidateSHA256': hashlib.sha256(next_path.read_bytes()).hexdigest(),
    'currentCalendarEducationalProofSHA256': hashlib.sha256(calendar_path.read_bytes()).hexdigest(),
    'sourceURL': calendar['sourceURL'], 'sourceResponseSHA256': calendar['sourceResponseSHA256'],
    'ordinaryWindow': ['2026-08-31', '2026-12-06'],
    'excludedExamWindows': [['2026-10-19', '2026-10-23'], ['2026-12-11', '2026-12-17']],
    'makeupActualPublishedReplacement': {'2026-12-07': '2026-10-05 Monday',
        '2026-12-08': '2026-09-25 Friday', '2026-12-09': '2026-10-09 Friday',
        '2026-12-10': '2026-09-24 Thursday'},
    'makeupMeetingCounts': makeup_counts,
    'datedMeetingsBefore': sum(len(c['schedules']) for c in old_courses),
    'datedMeetingsAfter': sum(len(c['schedules']) for c in obj['courses']),
    'ordinaryMeetings': 17934, 'actualPublishedMakeupMeetings': sum(makeup_counts.values()),
    'removedMidtermMeetings': 1439, 'removedFinalMeetings': 1439,
    'changedCourses': changes, 'sourceMetadataMismatches': 0, 'clockChanges': 0, 'periodBoundsOnlyChange': 'research teaching window ends Dec10; original semester end Dec17 remains separately published',
    'schoolRules': 'kunsan-current-operating-rules-20261008.json',
    'limits': ['Final current cancellation/current whole active scope not yet verified; these800 remain research only.',
               'Circled521,11+27,intensive91,JST136,and43genericremote/mixed remain separately unresolved.',
               'A dated research teaching occurrence does not establish attendance in a separately posted examination week.',
               'No new whole data collection, private login, inferred intensive dates, campus guessing or clock extrapolation.'],
    'productionReady': False, 'completionClaim': False,
}
(ROOT / 'kunsan-operating-date-next-audit-20261008.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k:audit[k] for k in ['scheduledResearchOnly','datedMeetingsBefore','datedMeetingsAfter','makeupMeetingCounts','candidateSHA256']}))
