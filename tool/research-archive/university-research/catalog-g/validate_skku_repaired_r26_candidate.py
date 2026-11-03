"""Independent whole-source, privacy, dated-plan and preserved-object checks."""
import argparse
import collections
import datetime
import hashlib
import json
from pathlib import Path
from skku_inline_private_education_filter import EMAIL, PHONE, CONTACT_EXTENSION, CONTACT_LOCAL_PHONE, REMAINING_PRIVATE
from prepare_skku_planned_regular_r25_candidate import frames

P = Path(__file__).resolve().parent


def read(name):
    return json.loads((P/name).read_text())


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--frozen', action='store_true')
    args = parser.parse_args()
    checkpoint = '20261008-r26' if args.frozen else '20261008-r26-draft'
    manifest = read(f'skku-partial-audited-{checkpoint}-sha-manifest.json')
    proof = {r['offeringCode']: r for r in read('skku-inline-privacy-education-repair-audit.json')['records']}
    current = {r['HAKSU_NO_BUNBAN']: r for r in read('skku-final-current-educational-source.json')['records'] if r['JUKYONGHAKWI_GB'] != '05'}
    rules = read('skku-current-term-closure-rule-evidence.json')
    start = datetime.date.fromisoformat(rules['term']['startDate'])
    end = datetime.date.fromisoformat(rules['term']['endDate'])
    closed = set(rules['nationalHolidayDates']['dates']) | set(rules['closureRule']['schoolSpecificClosures'])
    counts = collections.Counter()
    preserved = added = async_count = total = 0
    for entry in manifest['campuses']:
        path = Path(entry['path'])
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256']
        data = json.loads(path.read_text())
        old = {c['courseCode']+'-'+c['section']: c for c in read(f"skku-{entry['campus']}-2026-2.partial-audited-20261008-r25.json")['courses']}
        for course in data['courses']:
            key = course['courseCode']+'-'+course['section']
            before = old[key]
            row = current[key]
            for field in ['sourceId', 'courseName', 'professor', 'sourceSchedule', 'sourceClassroom', 'credits', 'departments', 'departmentCredits', 'departmentClassifications', 'sourceDegreeCode', 'sourceTeachingTypeCode', 'sourceConcentratedType', 'sourceEducationalMetadata', 'rawMeetingFrameForReviewOnly']:
                assert course[field] == before[field], (key, field)
            assert course['sourceSchedule'] == row['GYOSI_NAME'] and course['professor'] == row['PER_NAME']
            counts[course['scheduleStatus']] += 1
            if before['scheduleStatus'] == 'scheduled':
                assert course == before, key
                preserved += 1
            elif course['scheduleStatus'] == 'scheduled':
                record = proof[key]
                detail = record['detail'][0]
                assert record['currentDetailIdentityConfirmed']
                assert detail['PER_NAME'].strip() == row['PER_NAME'].strip()
                assert frames(detail['SUUP_YOIL_GYOSI']) == frames(row['GYOSI_NAME'])
                assert all(room in detail['SUUP_GANGUISIL'] for room in course['sourceClassroom'].split(',')), key
                assert not any(x.get('privacySuppressedLineCount') for x in [detail]+record['weekly'])
                assert not any(a.get('privacySuppressedLineCount') or a.get('contextLimitReached') or a.get('contextTruncated') for a in record['attachments'])
                assert course['scheduleEvidenceKind'] == 'plannedRegularTimetable'
                assert course['actualAttendanceConfirmed'] is False
                assert not any('deliveryMode' in m for m in course['schedules'])
                expected = []
                day = start
                while day <= end:
                    if day.weekday() != 6 and day.isoformat() not in closed:
                        expected.extend({**frame, 'date': day.isoformat()} for frame in before['rawMeetingFrameForReviewOnly'] if frame['weekday'] == day.isoweekday())
                    day += datetime.timedelta(days=1)
                assert course['schedules'] == expected, key
                added += 1
            else:
                assert not course['schedules']
            if course.get('scheduleEvidenceKind') == 'publishedPrerecordedWithoutLiveAttendanceClock':
                assert course['sourceTeachingTypeCode'] == '32' and course['sourceConcentratedType'] == 'N'
                assert course['scheduleStatus'] == 'unscheduled' and course['timetableImportSupported'] is False
                async_count += 1
            total += len(course['schedules'])
        assert not any(p.search(text) for text in strings(data) for p in [EMAIL, PHONE, CONTACT_EXTENSION, CONTACT_LOCAL_PHONE, REMAINING_PRIVATE])
    assert preserved == 1180 and added == 124 and async_count == 82
    assert sum(counts.values()) == 2782 and total == 38170
    output = {'checkpoint': checkpoint, 'counts': dict(counts), 'preservedR25ExactScheduledObjects': preserved,
              'preservedR21IndividualEvidenceIncluded': 422, 'newPlannedCurrentDetailClockTeacherRoomVerified': added,
              'wholeCurrentRawEducationalMetadataPreservedCount': 2782, 'datedMeetingCount': total,
              'source32UntimedClassificationCount': async_count, 'source32TimetableImportFunctionComplete': False,
              'privatePatternMatchCountInActualStringFields': 0, 'actualAttendanceConfirmed': False,
              'wholeOperatingAuditFinished': False}
    (P/f'skku-partial-audited-{checkpoint}-current-detail-validation.json').write_text(json.dumps(output, ensure_ascii=False, indent=2)+'\n')
    print(output)


if __name__ == '__main__':
    main()
