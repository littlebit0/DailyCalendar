"""Refresh packaged coverage, keeping historical and live verification distinct."""
import hashlib
import json
from collections import Counter
from pathlib import Path

root = Path.cwd()
out = root / 'work/university-research/resume-20261011'
status_file = root / 'docs/UNIVERSITY_SUPPORT_STATUS_2026-10-06.json'
status = json.loads(status_file.read_text())
catalog = json.loads((root / 'assets/timetable/catalog.json').read_text())
by_school = {}
for filename in catalog:
    path = root / filename
    data = json.loads(path.read_text())
    by_school.setdefault(data['universityId'], []).append((filename, data))

schools = []
for school in status['universities']:
    timetable = school['timetable']
    university = timetable.get('universityId') or school['academicCalendar'].get('sourceId')
    datasets = by_school.get(university, [])
    rows = [course for _, data in datasets for course in data['courses']]
    scheduled = sum(bool(course.get('schedules')) for course in rows)
    meetings = sum(len(course.get('schedules', [])) for course in rows)
    held = Counter(course.get('scheduleStatus', 'unspecified') for course in rows if not course.get('schedules'))
    snapshot = {
        'requestedName': school['requestedName'], 'universityId': university,
        'checkedAt': '2026-10-11', 'courses': len(rows),
        'scheduleBearingOfferings': scheduled, 'serializedMeetings': meetings,
        'withoutReservationsByPublishedStatus': dict(held),
        'wholeOperatingVerified': False,
        'assetFiles': [{'file': filename, 'sha256': hashlib.sha256((root / filename).read_bytes()).hexdigest()}
                       for filename, _ in datasets],
    }
    timetable['currentPackagedSnapshot'] = snapshot
    timetable['currentRemainingSummary'] = (
        f'Current packaged {len(rows)} offerings / {scheduled} schedule-bearing / '
        f'{meetings} serialized reservations; partial, whole operating support not verified.'
        if datasets else 'No packaged timetable. Own current teaching-clock/source mapping remains unresolved; not proven impossible.'
    )
    schools.append(snapshot)

snapshot = {
    'checkedAt': '2026-10-11', 'completionClaim': False,
    'sourceIntegrationIsNotWholeOperatingSupport': True,
    'academicSourceIntegrationsRecordedPreviously': 85,
    'academicSourcesLiveRecheckedThisPass': False,
    'timetableUniversitiesWithPackagedRows': sum(bool(s['assetFiles']) for s in schools),
    'unconnected': [s['requestedName'] for s in schools if not s['assetFiles']],
    'withoutReservationsDoesNotAutomaticallyMeanUnprocessedOrBug': True,
    'universities': schools,
}
status['completionClaim'] = False
status['latestSourceProcessingReceipt'] = 'work/university-research/resume-20261011/integration-receipt.json'
status_file.write_text(json.dumps(status, ensure_ascii=False, indent=2) + '\n')
(out / 'current-packaged-coverage.json').write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: v for k, v in snapshot.items() if k != 'universities'}, ensure_ascii=False))
