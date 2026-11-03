import collections
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[5]
OUT = pathlib.Path(__file__).resolve().parent
BASE = ROOT / 'work/university-research/catalog-r/gnu'

def read(path):
    return json.loads(path.read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def normalize_research_flag(value):
    if isinstance(value, dict):
        return {k: (True if k == 'researchOnly' else normalize_research_flag(v)) for k, v in value.items()}
    if isinstance(value, list):
        return [normalize_research_flag(v) for v in value]
    return value

census_path = BASE / 'blank-room-and-live-source-followup-v6-20261009/held1880-native-scope-census.json'
census = {row['sourceId']: row for row in read(census_path)['rows']}
inputs = [census_path, BASE / 'remaining-campus-clock-followup-v5-20261008/own-term-makeup-education.json', BASE / 'unpublished-night-clock-followup-v7-20261009/HANDOFF.md']
whole = []
for frozen_path in sorted((BASE / 'native-note-preservation-v8-20261009').glob('gnu-*.native-note-v8.json')):
    asset = ROOT / 'assets/timetable' / frozen_path.name.replace('.native-note-v8', '')
    original = {row['sourceId']: row for row in read(frozen_path)['courses']}
    current = {row['sourceId']: row for row in read(asset)['courses']}
    assert original.keys() == current.keys()
    for key in original:
        assert normalize_research_flag(original[key]) == normalize_research_flag(current[key]), key
    whole.extend(current.values())
    inputs.extend([frozen_path, asset])
assert len(whole) == len({row['sourceId'] for row in whole}) == 4842
held = [row for row in whole if not row['schedules']]
assert len(held) == 1837
assert sum(bool(row['schedules']) for row in whole) == 3005
assert sum(len(row['schedules']) for row in whole) == 53869
rows = []
for course in held:
    previous = census[course['sourceId']]
    assert course['metadata']['originalEducationalFields'] == previous['originalEducationalFields']
    refined = previous['reason']
    if refined == 'nativeRoomOrSyntaxUnresolved':
        periods = [int(v) for v in re.findall(r'\d+', course['sourceSchedule'])]
        assert any(v > 11 for v in periods)
        assert '[' not in course['sourceSchedule']
        refined = 'blankRoomAndUnpublishedPeriod12Or13EndClock'
    rows.append({'sourceId': course['sourceId'], 'previousReason': previous['reason'], 'refinedReason': refined,
                 'decision': 'retainedHeld', 'originalCourseWhole': course})
assert all(row['originalCourseWhole']['professor'].strip() for row in rows)
counts = dict(collections.Counter(row['refinedReason'] for row in rows))
assert counts['blankRoomAndUnpublishedPeriod12Or13EndClock'] == 14
result = {
    'researchOnly': True, 'completionClaim': False, 'impossibleClaim': False,
    'sourcePublicationScope': 'Existing July24/July29 2026-2 public educational snapshots; no new publication or live portal update claim.',
    'currentNativeCount': 4842, 'currentScheduledCount': 3005, 'currentClassDateCount': 53869,
    'heldCount': 1837, 'newEligibleCount': 0, 'professorUnknownOnlyHoldCount': 0,
    'blankRoomOnlyWithinKnownClockHoldCount': 0, 'reasonCounts': counts,
    'wholePreservation': 'All 4842 current course objects equal frozen v8 after only recursively normalizing the documented researchOnly flag. All other fields exact.',
    'clockScope': 'Current general undergraduate 0–11; no published general period12/13 end clock. Industry-specific Friday/Saturday clocks remain scoped to matching published native offerings.',
    'calendarScope': 'Own Sep1–Dec21 term; ordinary through Dec7, makeup Dec8–14, final Dec15–21. Existing source-specific appointments remain unchanged.',
    'inputs': [{'path': str(p.relative_to(ROOT)), 'sha256': digest(p)} for p in inputs], 'rows': rows,
    'remainingEvidenceNeeded': [
        'Current undergraduate explicit HH:mm end clocks for exact native period12/13 and night offerings.',
        'Exact current code/section/title/professor resolution of four printed industry correction conflicts; title-only aliases prohibited.',
        'Individual operating dates/HH for intensive, remote or mixed native offerings and native weekly time absent rows.',
        'Official clarification of duplicated native periods in 11010319-001; no silent deduplication.'
    ],
    'verification': {'pythonAssertions': 'PASS', 'flutterSdkUsed': False, 'newNetworkQueries': 0, 'productWrites': 0,
                     'actualThreeModeDriveExecuted': False, 'reason': 'Zero new appointment candidates; source-only lossless audit.'}
}
(OUT / 'held1837-native-professor-room-audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'result': 'PASS', 'native': 4842, 'scheduled': 3005, 'dates': 53869, 'held': 1837, 'newEligible': 0, 'reasons': counts}, ensure_ascii=False))
