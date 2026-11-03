"""Publish source regular plans, without asserting actual attendance/delivery."""
import collections
import datetime as dt
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
SOURCE = 'cuk-current-whole-exact-section-credit-next-20261008.json'
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
FIRST, LAST = dt.date(2026, 8, 31), dt.date(2026, 12, 18)
DAYS = '월화수목금토일'
BLANK_ROOM_REGULAR = {('00097', '01'), ('05642', '01'), ('05911', '01'), ('06539', '01')}
ROOM_NOTE = '강의실은 학교 공시 자료에 미표기되어 확인이 필요합니다.'
REGULAR_NOTE = '학교 공시의 정규 수업 계획입니다. 시험·보강·변경 사항은 학교 공지를 확인하세요.'
MUSIC_SIX = {('06359', '01'), ('00599', '01'), ('06358', '01'), ('01115', '01'), ('01117', '01'), ('01119', '01')}
BLANK_ROOM_REGULAR |= MUSIC_SIX


def load(name):
    return json.loads((ROOT / name).read_text())


def prepare():
    source = load(SOURCE)
    changes = load('cuk-current-all-eight-public-change-audit-20261008.json')
    closed = {(m['code'], m['section']) for r in changes['sourceChangeRows'] if r['closure']
              for m in r['exactCurrentMatches']}
    gbs = load('cuk-current-gbs-major-change-20261008.json')
    for table in gbs['educationTables']:
        for row in table:
            if len(row) == 5 and row[3] == '폐강':
                code = re.search(r'\((\d{5})\)', row[1])
                if code:
                    closed.add((code.group(1), row[2]))
    original_groups = load('cuk-current-clock-and-operation-review-groups-20261008.json')['educationReviewGroups']
    parsed = {(r['code'], r['section']) for r in original_groups['regularClockParsedButModeStillUnverified']}
    period10 = load('cuk-current-period10-source-candidate-review-20261008.json')
    period10_ids = {(r['code'], r['section']) for r in period10['currentCourses']}
    parsed |= period10_ids
    rows, audit_rows = [], []
    for course in source['courses']:
        key = (course['code'], course['section'])
        reason = None
        if key in closed:
            reason = 'explicitCurrentPublicClosure'
        elif not course['rawTimeAndRoom']:
            reason = 'sourceUnscheduled'
        elif key not in parsed and key not in BLANK_ROOM_REGULAR:
            reason = next(k for k, values in original_groups.items() if any((r['code'], r['section']) == key for r in values))
        elif course['department'] in ['국제경영학과', 'IT파이낸스학과', '세무회계금융학과'] or '글로벌경영대학 전용' in course['remarks']:
            reason = 'publishedGBSMixedWeekOperation'
        elif course['code'] in ['06022', '06166']:
            reason = 'publishedVolunteerNonWeeklyOperation'
        elif course['code'] == '07183' and course['section'] in ['06', '36']:
            reason = 'currentAIBootcampConcentratedAndEarlyEnd'
        elif course['code'] == '00765' and course['section'] in ['03', '04']:
            reason = 'currentRoomVersusPublishedChangeConflict'
        elif '현장실습' in course['title'] or '전공실기' in course['title']:
            reason = 'fieldOrIndividuallyArrangedOperationNeedsExactDates'
        meetings = []
        blocks = []
        if reason is None:
            for day, begin, finish, room in re.findall(r'([월화수목금토일])(\d+)(?:~(\d+))?\(([^()]*)\)', course['rawTimeAndRoom']):
                first, last = int(begin), int(finish or begin)
                if first > last:
                    raise ValueError('Invalid source period order')
                blocks.append({'weekday': DAYS.index(day) + 1, 'firstPeriod': first, 'lastPeriod': last, 'classroom': room})
            day = FIRST
            while day <= LAST:
                date = day.isoformat()
                if date not in HOLIDAYS:
                    for block in blocks:
                        if day.isoweekday() != block['weekday']:
                            continue
                        periods = list(range(block['firstPeriod'], block['lastPeriod'] + 1))
                        if date == '2026-09-09':
                            periods = [x for x in periods if x not in (2, 3)]
                        groups = []
                        for period in periods:
                            if not groups or period != groups[-1][-1] + 1:
                                groups.append([])
                            groups[-1].append(period)
                        for group in groups:
                            meetings.append({'weekday': day.isoweekday(), 'startMinute': (group[0] + 8) * 60,
                                             'endMinute': (group[-1] + 8) * 60 + 50, 'classroom': block['classroom'], 'date': date})
                day += dt.timedelta(days=1)
        department = course['department']
        rows.append({'sourceId': f"catholic/unknown/2026/2/{course['code']}-{course['section']}",
                     'campus': 'unknown', 'academicYear': 2026, 'semester': '2',
                     'courseCode': course['code'], 'section': course['section'], 'courseName': course['title'],
                     'professor': course['professor'], 'credits': course['credits'], 'departments': [department],
                     'classification': course['classification'],
                     'departmentCredits': {department: course['credits']} if course['credits'] is not None else {},
                     'departmentClassifications': {department: course['classification']},
                     'departmentRemarks': {department: '\n'.join(x for x in [course['remarks'], REGULAR_NOTE if meetings else '', ROOM_NOTE if key in BLANK_ROOM_REGULAR else '', '연주2는 학교가 수강생을 일괄 입력하는 과목입니다.' if key == ('00599', '01') else '', '합창2·합창4·합창6은 동시 수강할 수 없으며 한 과목만 수강 가능합니다.' if course['code'] in ['01115', '01117', '01119'] else ''] if x)},
                     'sourceRemarks': course['remarks'],
                     'sourceSchedule': course['rawTimeAndRoom'],
                     'sourceClassroom': '; '.join(room for _, _, _, room in re.findall(r'([월화수목금토일])(\d+)(?:~(\d+))?\(([^()]*)\)', course['rawTimeAndRoom'])),
                     'sourceCreditMetadata': course.get('sourceCreditMetadata', []),
                     'sourceEducation': {'projection': 'publishedRegularTimetable', 'sourceDeliveryMode': 'unknown',
                                         'actualAttendanceConfirmed': False, 'sourceCampus': course['campus'],
                                         'clockProofScope': 'School2026 general freshman clock directly includes period10; current2026-2 independently confirms1–9; no year/semester mislabel' if key in period10_ids else 'Current2026-2 school own1–9 period table',
                                         'limits': 'User must choose actual delivery mode. Current regular plan is not individual attendance or confirmed exam event. No invented makeup.'},
                     'period': {'startDate': FIRST.isoformat(), 'endDate': LAST.isoformat()},
                     'scheduleStatus': 'scheduled' if meetings else ('unscheduled' if not course['rawTimeAndRoom'] else 'unrecognized'),
                     'schedules': meetings})
        audit_rows.append({'code': course['code'], 'section': course['section'], 'reason': reason,
                           'sourceClockBlocks': blocks, 'datedPlannedMeetings': len(meetings)})
    result = {'schemaVersion': 2, 'universityId': 'catholic', 'campus': 'unknown', 'campusName': '캠퍼스 미표기',
              'academicYear': 2026, 'semester': '2', 'publishedDate': '2026-10-08',
              'sourceUrl': 'https://www.catholic.ac.kr/ko/support/subject.do', 'courses': rows}
    name = 'catholic-unknown-2026-2.published-regular-1013-candidate-20261008.json'
    path = ROOT / name
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    audit = {'wholeCount': len(rows), 'scheduleCounts': dict(collections.Counter(r['scheduleStatus'] for r in rows)),
             'reasonCounts': dict(collections.Counter(r['reason'] or 'plannedRegularTimetable' for r in audit_rows)),
             'datedPlannedMeetings': sum(len(r['schedules']) for r in rows), 'actualAttendanceConfirmed': False,
             'forcedDeliveryModeCount': 0, 'excludedNationalHolidays': sorted(HOLIDAYS),
             'holidaySource': 'https://www.kasa.go.kr/bbs/BBSMSTR_000000000010/view.do?nttId=B000000001860Pe2zT3',
             'schoolHolidayRule': 'cuk-current-regular-timetable-rule-proof-20261008.json:schoolRuleArticle8',
             'schoolCurrentTermClockSource': 'cuk-current-school-own-term-clock-confirmation-20261008.json',
             'additionalPeriod10SourceScope': '2026general school freshman notice268547:10period18:00–18:50; current2 guide directly agrees1–9; source first-term notice not relabeled current2',
             'additionalPeriod10Courses': len(period10_ids),
             'massReplacement': {'date': '2026-09-09', 'periods': [2, 3], 'sourceNotice': 275275,
                                 'policy': 'Remove only affected source periods; no makeup requirement and no invented mass event'},
             'examWindowPolicy': 'School current term explicitly includes exams. Preserve ordinary published planned rule; do not create special exam events or invent their time/place.',
             'campusPolicy': 'unknown preserved; no inference from department/building',
             'candidateFile': name, 'candidateSha256': hashlib.sha256(path.read_bytes()).hexdigest(),
             'courses': audit_rows, 'productionRegistered': False, 'completionClaim': False}
    (ROOT / 'cuk-published-regular-1013-candidate-audit-20261008.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    return result, audit


if __name__ == '__main__':
    _, audit = prepare()
    print(json.dumps({k: v for k, v in audit.items() if k != 'courses'}, ensure_ascii=False))
