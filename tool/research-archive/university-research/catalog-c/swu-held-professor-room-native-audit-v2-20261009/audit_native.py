import collections
import hashlib
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[4]
OUT = pathlib.Path(__file__).resolve().parent
BASE = ROOT / 'work/university-research/catalog-c'
CURRENT = BASE / 'swu-current-20261008'
def read(path):
    return json.loads(path.read_text())
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
asset = ROOT / 'assets/timetable/swu-main-2026-2.json'
frozen = CURRENT / 'swu-main-2026-2.published-safe-next-20261008.json'
courses = read(asset)['courses']
assert courses == read(frozen)['courses']
assert len(courses) == len({c['sourceId'] for c in courses}) == 1511
assert sum(bool(c['schedules']) for c in courses) == 1281
assert sum(len(c['schedules']) for c in courses) == 20406
index_path = CURRENT / 'swu-acquisition-index.json'
index = read(index_path)
assert len(index) == 172
raw = {}
raw_records = collections.Counter()
source_record_variants = 0
raw_row_count = 0
duplicate_query_ref_rows = 0
inputs = [asset, frozen, index_path, CURRENT / 'SWU_NEXT_HANDOFF_20261008.md', BASE / 'swu-manifest.json', BASE / 'swu-final-cancellations.json']
for q in index:
    path = CURRENT / q['file']
    inputs.append(path)
    rows = read(path)['root']['openSubList']['row']
    assert len(rows) == q['rows']
    for row in rows:
        key = (q['div'], q['label'], q['department'], row['REF_KEY'])
        raw_row_count += 1
        if key in raw:
            duplicate_query_ref_rows += 1
            if row not in raw[key]:
                source_record_variants += 1
        raw.setdefault(key, []).append(row)
        raw_records[json.dumps([list(key), row], sort_keys=True, ensure_ascii=False)] += 1
assert raw_row_count == 2705
seen = set()
seen_records = collections.Counter()
for c in courses:
    for selection in c['publicEducationBySelection']:
        q = selection['query']
        e = selection['education']
        key = (q['div'], q['label'], q['department'], e['REF_KEY'])
        assert e in raw[key]
        seen_records[json.dumps([list(key), e], sort_keys=True, ensure_ascii=False)] += 1
        assert e['SB_CD'] == c['courseCode'] and e['DIVCLS_CD'] == c['section']
        assert e['CLASS'] == c['sourceSchedule'] and e['PROF_NM'] == c['professor']
        seen.add(key)
assert seen == raw.keys()
assert seen_records == raw_records
held = [c for c in courses if not c['schedules']]
assert len(held) == 230
reasons = dict(collections.Counter(c['datesMeaning'] for c in held))
unknown = [c for c in held if c['professor'] in ('', '미정', '교수미정', '강사미정')]
assert len(unknown) == 116
assert all(c['datesMeaning'] == 'source blank or zero-period notation has no published fixed teaching time' for c in unknown)
rows = []
for c in held:
    if c['datesMeaning'] == 'source blank or zero-period notation has no published fixed teaching time':
        assert not c['sourceSnapshotSchedules']
    rows.append({'sourceId': c['sourceId'], 'reason': c['datesMeaning'], 'decision': 'retainedHeld', 'originalCourseWhole': c})
result = {'researchOnly': True, 'completionClaim': False, 'impossibleClaim': False,
          'currentNative': 1511, 'scheduled': 1281, 'appointmentDates': 20406, 'remainingHeld': 230,
          'newEligible': 0, 'newDates': 0, 'professorUnknownCount': 116, 'professorOnlyHoldCount': 0,
          'ordinaryKnownClockBlankRoomOnlyHoldCount': 0, 'reasons': reasons,
          'sourceScope': {'queryPairs': 172, 'educationRows': 2705, 'nativeRefIdentities': 1511, 'uniqueQueryReferencePairs': len(raw), 'duplicateQueryReferenceRows': duplicate_query_ref_rows, 'nonidenticalVariantRowsAmongDuplicateQueryReferences': source_record_variants,
                          'snapshotDateMeaning': '2026-10-08 acquisition, not publication of new classes',
                          'campus': 'main institution 본교 scope only; source has no campus selector',
                          'physicalCampusOrWholeOperatingCompletionClaim': False,
                          'closureScope': '66 published final closure sections absent in the existing current acquisition; further latest changes unknown'},
          'clockAndCalendar': {'clockSource': 'Official timetable PDF printed144: 1–6 75min;7–11 50min. Special chapel50min not ordinary75min.',
                              'term': ['2026-09-01','2026-12-21'], 'ordinaryThrough': '2026-12-07',
                              'makeupNativeWeekdays': {'2026-12-08':1,'2026-12-09':5,'2026-12-10':4,'2026-12-11':5},
                              'heldSpecialDates': 'Autonomous makeup Dec14, final Dec15–21 require individual dates; exact published Bahrom nonresidential dates already retained.'},
          'rows': rows, 'inputs': [{'path':str(p.relative_to(ROOT)), 'sha256':sha(p)} for p in inputs],
          'verification': {'all1511WholeCourseExactFrozenPreservation': True, 'all2705EducationSelectionRawEquality': True,
                           'pythonAssertions':'PASS', 'sdkUsed':False,'networkQueries':0,'productWrites':0,
                           'newThreeModeDriveTestExecuted':False},
          'remainingEvidenceNeeded': ['Fixed native HH/weekday for172 blank/zero-period rows (including116 professor미정).',
                                      'Actual activity allocation dates/times for41 residential/camp Bahrom sections; native weekly reservation differs from official activities.',
                                      'Actual dated10week course plan for8 explicitly intensive sections.',
                                      'Session-specific dates for5 special chapel50min sections; original Sunday alias does not establish same operation.',
                                      'Actual current vacation dates/clock forAG02032-01.']}
(OUT/'held230-whole-native-professor-room-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'result':'PASS','native':1511,'rawEducation':2705,'held':230,'newEligible':0,'reasons':reasons},ensure_ascii=False))
