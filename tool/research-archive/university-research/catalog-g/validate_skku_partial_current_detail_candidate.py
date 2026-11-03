"""Network-free current-detail, source-slot and closure audit of a frozen candidate."""
import argparse
import datetime
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CLOCK = re.compile(r'([월화수목금토일])(?:\[[^\]]*\])?(\d{2}):(\d{2})[-~](\d{2}):(\d{2})')


def frames(value):
    return sorted(
        (m[1], int(m[2]) * 60 + int(m[3]), int(m[4]) * 60 + int(m[5]))
        for m in CLOCK.finditer(value)
    )


def validate(checkpoint, expected_count):
    manifest = json.loads((ROOT / f'skku-partial-audited-{checkpoint}-sha-manifest.json').read_text())
    assert manifest['wholeOperatingAuditFinished'] is False, 'Collection completion must not claim whole operating review.'
    audit = json.loads((ROOT / 'skku-public-operating-plan-audit.json').read_text())
    proof = {r['offeringCode']: r for r in audit['records']}
    rules = json.loads((ROOT / 'skku-current-term-closure-rule-evidence.json').read_text())
    closed = set(rules['nationalHolidayDates']['dates']) | set(rules['closureRule']['schoolSpecificClosures'])
    keys = []
    meeting_count = 0
    suppressed_count = 0
    for campus in manifest['campuses']:
        path = Path(campus['path'])
        assert hashlib.sha256(path.read_bytes()).hexdigest() == campus['sha256']
        data = json.loads(path.read_text())
        assert data['wholeOperatingAuditFinished'] is False, 'Campus collection completion is not operating completion.'
        for course in data['courses']:
            if course['scheduleStatus'] != 'scheduled':
                assert not course['schedules']
                continue
            key = course['courseCode'] + '-' + course['section']
            evidence = proof[key]
            detail = evidence['detail'][0]
            assert evidence['currentDetailIdentityConfirmed'], key
            assert frames(course['sourceSchedule']) == frames(detail['SUUP_YOIL_GYOSI']), key
            assert course['professor'].strip() == detail['PER_NAME'].strip(), key
            assert detail['INPUT_TYPE_GB'] == '0', key + ' requires separate full attachment review'
            assert evidence['sourceRow']['SUUP_TYPE_CD'] in ['31', '33']
            assert evidence['sourceRow']['HAKBU_JIBJUNG_GB'] == 'N'
            suppressed_count += detail['privacySuppressedLineCount']
            suppressed_count += sum(w['privacySuppressedLineCount'] for w in evidence['weekly'])
            original_frames = course['rawMeetingFrameForReviewOnly']
            assert all(f['classroom'] and '미지정' not in f['classroom'] for f in original_frames)
            expected = []
            day = datetime.date.fromisoformat(rules['term']['startDate'])
            end = datetime.date.fromisoformat(rules['term']['endDate'])
            start = day
            individual = course.get('individualClosedWeekEvidence', {})
            excluded_weeks = individual.get('excludedSchoolWeeks', [])
            if excluded_weeks:
                verified = json.loads((ROOT / 'skku-individual-closed-week-evidence.json').read_text())['individualExclusions'][key]
                assert individual == verified, key
                assert individual['sourceWeeklyEducation'] == evidence['weekly'], key
            while day <= end:
                if day.weekday() != 6 and day.isoformat() not in closed and ((day - start).days // 7 + 1) not in excluded_weeks:
                    expected.extend({**f, 'date': day.isoformat()} for f in original_frames if f['weekday'] == day.isoweekday())
                day += datetime.timedelta(days=1)
            assert course['schedules'] == expected, key
            keys.append(key)
            meeting_count += len(expected)
    assert len(keys) == expected_count
    assert suppressed_count == 0
    result = {
        'checkpoint': checkpoint,
        'approvedCount': len(keys),
        'currentIdentityConfirmedCount': len(keys),
        'currentSourceClockMatchesActualDetailCount': len(keys),
        'currentTeacherMatchesCount': len(keys),
        'exactOriginalClockRoomAndClosureBoundedMeetingCount': meeting_count,
        'approvedEducationPrivacySuppressedLineCount': suppressed_count,
        'approvedOfferingCodes': keys,
        'wholeOperatingAuditFinished': False,
        'completionClaim': False,
        'latestCollectedCountAtCheck': audit['count'],
        'allApprovedEvidenceType': 'Full current public screen educational fields and published topic groups',
    }
    output = ROOT / f'skku-partial-audited-{checkpoint}-current-detail-validation.json'
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print({k: v for k, v in result.items() if k != 'approvedOfferingCodes'})


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--checkpoint', required=True)
    parser.add_argument('--expected-count', required=True, type=int)
    arguments = parser.parse_args()
    if not re.fullmatch(r'\d{8}(?:-r\d+)?', arguments.checkpoint):
        raise SystemExit('Invalid immutable checkpoint name')
    validate(arguments.checkpoint, arguments.expected_count)
