import copy
import datetime
import hashlib
import json
import pathlib

out = pathlib.Path(__file__).resolve().parent
base = out.parent
root = out.parents[3]
def read(path):
    return json.loads(path.read_text())
def save(name, value):
    (out / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
key = 'kunsan/unknown/2026/2/116289/01'
next_path = base / 'kunsan-unknown-2026-2.published-regular-1125-late-numeric-partial-next-20261008.json'
proposal = copy.deepcopy(next(c for c in read(next_path)['courses'] if c['sourceId'] == key))
proposal['sourceEducation']['nativePublishedWeekday'] = 5
proposal['sourceEducation']['makeupNativeWeekdayByActualDate'] = {'2026-12-08': 5, '2026-12-09': 5}
proposal['sourceEducation']['currentClockReviewReceipt'] = 'kunsan-current-circled-late-clock-department-path-v2-20261009/current-clock-scope-and-remaining-audit.json'
proposal['sourceEducation']['publishedPartialScope'] = 'Literal9/10 only; originalFriday11 current HH unknown held. No entire-class operating/end claim.'
originals = []
candidates = []
entries = []
for campus in ('unknown', 'saemangeum'):
    path = root / f'assets/timetable/kunsan-{campus}-2026-2.json'
    original = read(path)
    original_name = f'prior-kunsan-{campus}-2026-2.json'
    save(original_name, original)
    originals.extend(original['courses'])
    candidate = copy.deepcopy(original)
    if campus == 'unknown':
        index = next(i for i, row in enumerate(candidate['courses']) if row['sourceId'] == key)
        candidate['courses'][index] = proposal
    candidates.extend(candidate['courses'])
    candidate['counts'] = {status: sum(c['scheduleStatus'] == status for c in candidate['courses'])
        for status in ('scheduled', 'unrecognized', 'unscheduled')}
    candidate.update({'researchOnly': True, 'productionRegistered': False, 'productionReady': False,
        'completionClaim': False, 'appDatasetProjectionReady': False,
        'productionProjectionPermitted': 'rootReviewKnown9And10PartialOnlyNotApplied',
        'candidateRevision': 'known9-10-pending-partial-root-review-v3-20261009'})
    candidate_name = f'kunsan-{campus}-2026-2.known9-10-root-review-v3.json'
    save(candidate_name, candidate)
    entries.append({'campus': campus, 'file': candidate_name, 'priorFile': original_name,
        'originalAssetSha256': digest(path)})
old_by_id = {c['sourceId']: c for c in originals}
new_by_id = {c['sourceId']: c for c in candidates}
assert len(old_by_id) == len(new_by_id) == 1718
assert old_by_id.keys() == new_by_id.keys()
assert [source_id for source_id in old_by_id if old_by_id[source_id] != new_by_id[source_id]] == [key]
assert sum(bool(c['schedules']) for c in originals) == 1124
assert sum(len(c['schedules']) for c in originals) == 22971
assert sum(bool(c['schedules']) for c in candidates) == 1125
assert sum(len(c['schedules']) for c in candidates) == 22984
native_fields = ['sourceId', 'universityId', 'campus', 'academicYear', 'semester', 'courseCode', 'section',
    'courseName', 'sourceNames', 'credits', 'professor', 'departments', 'classification',
    'departmentCredits', 'departmentClassifications', 'departmentRemarks', 'sourceSchedule',
    'sourceClassroom', 'sourceTeachingMethods', 'sourceOccurrences', 'sourceScheduleStatus',
    'sourceDepartmentRemarks', 'sourceRemarks']
assert all(proposal[field] == old_by_id[key][field] for field in native_fields)
expected_dates = ['2026-09-04', '2026-09-11', '2026-09-18', '2026-10-02', '2026-10-16',
    '2026-10-30', '2026-11-06', '2026-11-13', '2026-11-20', '2026-11-27', '2026-12-04',
    '2026-12-08', '2026-12-09']
assert [meeting['date'] for meeting in proposal['schedules']] == expected_dates
for meeting in proposal['schedules']:
    assert meeting['weekday'] == datetime.date.fromisoformat(meeting['date']).isoweekday()
    assert (meeting['startMinute'], meeting['endMinute'], meeting['classroom']) == (1030, 1140, '예술관-5403')
assert proposal['schedules'][-2]['weekday'] == 2
assert proposal['schedules'][-1]['weekday'] == 3
calendar_path = base / 'kunsan-current-calendar-operating-review-20261008.json'
calendar = read(calendar_path)
makeup_row = next(row for row in calendar['educationalOperatingRows'] if row[0] == '12/07(월) ~ 12/10(목)')
assert '12.8.(화): 추석 9.25.(금)' in makeup_row[1]
assert '12.9.(수): 한글날 10.9.(금)' in makeup_row[1]
save('native-clock-date-calendar-and-preservation-proof.json', {
    'researchOnly': True, 'completionClaim': False, 'productionApplied': False,
    'datasets': entries, 'sourceId': key, 'sourceNativeWeekday': 5,
    'independentLiteralClock': {'9': {'startMinute': 1030, 'endMinute': 1080},
        '10': {'startMinute': 1090, 'endMinute': 1140}, '11': None},
    'combinedPublishedReservationBoundary': [1030, 1140],
    'tenMinuteBreakBetween9And10': True,
    'calendarSource': calendar, 'exactMakeupEducationalRow': makeup_row,
    'independentLiteralDates': expected_dates,
    'makeupActualVsNativeWeekday': {'2026-12-08': {'actualWeekday': 2, 'sourceNativeWeekday': 5},
        '2026-12-09': {'actualWeekday': 3, 'sourceNativeWeekday': 5}},
    'prior': {'native': 1718, 'scheduled': 1124, 'appointments': 22971},
    'candidate': {'native': 1718, 'scheduled': 1125, 'appointments': 22984},
    'addedNativeSchedules': 1, 'addedAppointments': 13,
    'other1717WholeObjectsExact': True, 'sameCourseNativeFieldsExact': native_fields,
    'existingPendingProposalCloneScope': 'Existing Oct8 course/schedules exactly retained; sourceEducation only adds review provenance/nativeFriday/makeup interpretation. Historical candidate and v2 receipts unchanged.',
    'publishedModePolicy': 'Existing proposed literalinPerson deliveryMode retained exactly, consistent with original published대면 and current numeric reservations. Three default modes are each tested; exact published overrides remain, never coerced to whichever default is chosen.',
    'sourceInputSha256': {'existingFrozenNext': digest(next_path),
        'currentOwnCalendar': digest(calendar_path),
        'currentClockScopeV2': digest(base/'kunsan-current-circled-late-clock-department-path-v2-20261009/current-clock-scope-and-remaining-audit.json')},
    'pythonVerification': 'PASS', 'actualDartVerification': 'PREPARED_NOT_RUN_SDK0',
    'wholeClassOperatingConfirmed': False, 'wholeClassEndConfirmed': False,
})
print('PASS1717whole/native1718/1125/22984;13dateactualweekday matches')
