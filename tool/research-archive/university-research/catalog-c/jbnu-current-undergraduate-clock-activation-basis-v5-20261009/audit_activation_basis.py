import hashlib
import json
import re
from collections import Counter
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
OLD = OUT.parent / 'jbnu-current-20261008'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    metadata = sorted(OLD.glob('*current-metadata-20261008.json'))
    current = ROOT / 'assets/timetable/jbnu-unknown-2026-2.json'
    source_medical = OLD / 'jbnu-unknown-medical-document-2026-2.published-partial-20261008.json'
    preserved = metadata + [source_medical, current]
    before = {str(path.relative_to(ROOT)): sha(path) for path in preserved}
    rows = [row for path in metadata for row in json.loads(path.read_text())['courses']]
    assert len(rows) == 3571 and len({row['sourceId'] for row in rows}) == 3571
    clock_types = Counter(row['publicEducationRow'].get('LESSN_HR_DIVCDNM') for row in rows)
    timed = [row for row in rows if re.search(r'[월화수목금토일]\s*\d', row['sourceSchedule'])]
    normal_room = [row for row in rows if row['sourceClassroom'].strip(' :')]
    known_numeric_room = [row for row in timed if row['sourceClassroom'].strip(' :')]
    assert len(timed) == 3569 and len(normal_room) == 3338 and len(known_numeric_room) == 3338
    assert not any(re.search(r'\d{1,2}:\d{2}', row['sourceSchedule']) for row in rows)
    model = json.loads(current.read_text())
    assert len(model['courses']) == 33
    assert sum(bool(row['schedules']) for row in model['courses']) == 18
    assert sum(len(row['schedules']) for row in model['courses']) == 1098
    proof = {
        'nativeRows': 3571,
        'clockTypeCounts': {str(key): value for key, value in clock_types.items()},
        'numericWeekdayRows': len(timed), 'actualNonplaceholderRoomRows': len(normal_room),
        'numericWeekdayAndRoomRows': len(known_numeric_room),
        'professorEmptyRows': sum(not row['professor'].strip() for row in rows),
        'sourceDirectHHRows': 0,
        'firstLocalValidationFailure': 'Initial assertion counted colon-only placeholder rooms as actual rooms. Corrected only the census to3338 real rooms/233 empty or prefix-only; source objects untouched.',
        'sourceOperatingRemarkNonemptyRows': sum(bool(row['publicEducationRow'].get('LESSN_OPER_DRC_CN')) for row in rows),
        'roomUnpublishedRows': [{key: row[key] for key in ('sourceId', 'courseCode', 'section', 'courseName',
                                                   'professor', 'classification', 'sourceSchedule', 'sourceClassroom')}
                          for row in rows if row not in known_numeric_room],
        'minimumGeneralActivationGap': 'Current canonical undergraduate numeric A/B start/end clock, including0A/0B and separately75-minute scope.50분수업(30분단위) describes the unit/type but does not itself specify actual starts or where breaks/endpoints occur.',
        'notSoleHoldingCauses': ['professor absence', 'room absence for the3338 numeric-room rows',
                                'absence of individual actual-attendance dates alone'],
        'dateBasisAlreadyKnown': {'start': '2026-09-01', 'end': '2026-12-22',
                                  'source': 'catalog-f/jbnu-2026-2-calendar.html',
                                  'nativeMeaning': '제2학기 시작 / 제2학기 종강, 기말시험 완료',
                                  'notProven': 'All individual lessons, exams, makeup appointments and latest operating changes'},
        'existingPublicReportEvidence': {'sourceCache': 'catalog-f/jbnu-syllabus-page0-decoded.json and jbnu-syllabus-page0-text.txt',
                                        'sampleNativeIdentity': 'UDEN098-1', 'pages': 2,
                                        'meaning': '75-minute current course plan prints native A/B terms and room. It does not supply HH starts/ends or individual dates, so it is not a12-period clock legend.',
                                        'refetched': False},
        'existingMedical18ClockBasis': 'Medical document357005 explicit calendar cells and own numeric1–10 headers08:30–09:20 etc plus grade-specific lecture-room allocations; courses hold where17:00 override end/clinical site/assessment ambiguous. This is a separate medical source clock, not general undergraduate A/B evidence or official code join.',
        'existingExcludedClockSources': ['old2012', '2026-1 freshman starts only',
                                        'business graduate2026-2 night A/B', 'summer employment/training',
                                        'another university exchange-course clocks'],
        'boundedNewPublicSearch': [{'query': 'site:jbnu.ac.kr "2026" "2학기" "수업시간" "A" -site:gsba.jbnu.ac.kr -site:stat.jbnu.ac.kr',
                                   'newOwnUndergraduateClockAttachmentFound': False,
                                   'resultsExcluded': ['2026-1 Chungnam university exchanged course HH', 'generic registration policy with no numeric clock']},
                                  {'query': 'site:adti.jbnu.ac.kr "2026" "2학기" "시간표"',
                                   'result': 'No indexed results', 'knownFirstTermAttachmentNotRetried': True}],
        'newCurrentOfficialPolicyPath': {'url': 'https://www.jbnu.ac.kr/web/academic/class/sub01.do',
                                         'publicRead': True, 'lastModifiedPrinted': '2026-07-15',
                                         'educationMeaning': 'Registration uses semester offered timetable; actual class login procedure is described. General/liberal room distinguishes campus. Remote courses and seasonal/special programs are separate scopes.',
                                         'currentA_BHHPublished': False, 'protectedTargetsFollowed': False},
        'frozenBeforeAndAfterSHA256': before,
        'preservedCurrentDocumentCourses': 33, 'preservedScheduledCourses': 18,
        'preservedDatedMeetings': 1098, 'newEligibleSchedules': 0,
        'furtherValidation': 'One genuine applicable UG clock source can unlock exact numeric correspondence review; do not globally activate15 operating-note rows or recorded courses solely because clocks match. Retain exact campus/code-section/teacher/room/eligibility, latest closure limitations and own calendar. No fake code join from the309page code-unprinted snapshot.',
        'sdkUsed': False, 'productChanged': False, 'completionClaim': False, 'impossibleClaim': False
    }
    assert before == {str(path.relative_to(ROOT)): sha(path) for path in preserved}
    (OUT / 'current-native-clock-activation-gap-proof.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
    print('PASS3571/3338numeric+room/HH0; prior33/18/1098 unchanged')


if __name__ == '__main__':
    main()
