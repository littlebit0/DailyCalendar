"""Six individually reviewed online preparation/assignment distinctions; public plan only."""
import collections
import copy
import datetime
import importlib.util
import json
from pathlib import Path

P = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('base', P/'prepare_skku_planned_regular_r25_candidate.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
KEYS = {'BUS2018-01', 'ECO2004-01', 'ECO2011-01', 'ECO2011-02', 'IKS2053-01', 'DKL2009-02', 'GLD3026-01', 'CON3043-01'}


def read(name):
    return json.loads((P/name).read_text())


def main():
    notes = {r['offeringCode']: r for r in read('skku-repaired-education-individual-review-notes.json')['reviewed']}
    proof = {r['offeringCode']: r for r in read('skku-inline-education-repaired-20261008-r28-privacy-proof.json')['records']}
    review = {'researchOnly': True, 'actualAttendanceConfirmed': False,
              'reviewed': [notes[k] for k in sorted(KEYS)]}
    review_path = P/'skku-assessment-policy-r33-review-proof.json'
    review_sha = base.immutable(review_path, review)
    rules = read('skku-current-term-closure-rule-evidence.json')
    start = datetime.date.fromisoformat(rules['term']['startDate'])
    end = datetime.date.fromisoformat(rules['term']['endDate'])
    closed = set(rules['nationalHolidayDates']['dates']) | set(rules['closureRule']['schoolSpecificClosures'])
    manifest = {'universityId': 'skku', 'semester': '2026-2', 'completionClaim': False,
                'actualAttendanceConfirmed': False, 'wholeOperatingAuditFinished': False,
                'proof': {'path': str(review_path), 'sha256': review_sha}, 'campuses': []}
    added = set()
    counts = collections.Counter()
    dates = 0
    for campus in base.CAMPUSES:
        before = read(f'skku-{campus}-2026-2.partial-audited-20261008-r32.json')
        after = copy.deepcopy(before)
        for c in after['courses']:
            key = c['courseCode']+'-'+c['section']
            if key not in KEYS:
                continue
            r = proof[key]
            row = r['sourceRow']
            detail = r['detail'][0]
            assert r['currentDetailIdentityConfirmed'] and row['SUUP_TYPE_CD'] in ('31', '33') and row['HAKBU_JIBJUNG_GB'] == 'N'
            assert base.frames(row['GYOSI_NAME']) == base.frames(detail['SUUP_YOIL_GYOSI'])
            assert row['PER_NAME'] == detail['PER_NAME'] == c['professor']
            assert c['sourceSchedule'] == row['GYOSI_NAME']
            assert all(not a.get('privacySuppressedLineCount') and not a.get('contextLimitReached') and not a.get('contextTruncated') for a in r['attachments'])
            assert notes[key]['decision'] == 'normalCurrentPublishedPlannedTimetable'
            frames = c['rawMeetingFrameForReviewOnly']
            assert frames and all(f['classroom'] and f['classroom'] != '미지정' for f in frames)
            meetings = []
            day = start
            while day <= end:
                if day.isoformat() not in closed:
                    meetings.extend({**f, 'date': day.isoformat()} for f in frames if f['weekday'] == day.isoweekday())
                day += datetime.timedelta(days=1)
            c.update(scheduleStatus='scheduled', schedules=meetings,
                     period={'startDate': start.isoformat(), 'endDate': end.isoformat()},
                     unresolvedReasons=[], researchOnly=False, actualAttendanceConfirmed=False,
                     scheduleEvidenceKind='plannedRegularTimetable', commonClosureDatesApplied=True,
                     operatingReviewBasis=notes[key]['basis'],
                     sourceEducationalOperatingEvidenceReference={'file': review_path.name, 'offeringCode': key})
            added.add(key)
        for old, new in zip(before['courses'], after['courses']):
            assert old['sourceEducationalMetadata'] == new['sourceEducationalMetadata']
            assert old['departmentRemarks'] == new['departmentRemarks']
            if old['courseCode']+'-'+old['section'] not in KEYS:
                assert old == new
        counts.update(c['scheduleStatus'] for c in after['courses'])
        dates += sum(len(c.get('schedules', [])) for c in after['courses'])
        path = P/f'skku-{campus}-2026-2.partial-audited-20261008-r33.json'
        sha = base.immutable(path, after)
        manifest['campuses'].append({'campus': campus, 'path': str(path), 'sha256': sha, 'courseCount': len(after['courses'])})
    assert added == KEYS and dates == 38893
    manifest.update(counts=dict(counts), datedMeetings=dates, newPlannedCodes=sorted(added), preservedR32Scheduled=1327)
    base.immutable(P/'skku-partial-audited-20261008-r33-sha-manifest.json', manifest)
    print({'counts': dict(counts), 'dated': dates, 'newPlanned': len(added)})


if __name__ == '__main__':
    main()
