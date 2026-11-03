"""Review existing published Jeju catalog; never infer subject codes or meetings."""
import collections
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def read_json(name):
    return json.loads((ROOT / name).read_text())


def compact_title(value):
    return ''.join(str(value).split())


def prepare():
    whole = read_json('jeju-2026-2-all-20260729.xls.json')[0]['rows'][6:]
    restriction_source_rows = read_json('jeju-2026-2-restrictions-20260729.xls.json')[0]['rows'][4:]
    total_row = restriction_source_rows[-1]
    assert total_row[1] == '계:' and total_row[2] == 531
    restriction_rows = restriction_source_rows[:-1]
    restrictions = collections.defaultdict(list)
    current_number = None
    for row in restriction_rows:
        if row[1]:
            current_number = str(row[1])
        if not current_number:
            raise ValueError('Unassigned restriction continuation')
        # Every scope restriction is educational. These dates govern enrollment,
        # not attendance; keep their semantic role explicit.
        restrictions[current_number].append({
            'publishedEnrollmentNumber': str(row[1]),
            'subjectCode': str(row[2]),
            'includesDoubleMajor': row[3],
            'title': row[4],
            'classification': row[5],
            'discipline': row[6],
            'targetDepartment': row[7],
            'grade': row[8],
            'genderRestriction': row[9],
            'enrollmentRestrictionStartDate': row[10],
            'enrollmentRestrictionStartTime': row[11],
            'enrollmentRestrictionEndDate': row[12],
            'enrollmentRestrictionEndTime': row[13],
            'studentCategory': row[14],
        })
    courses = []
    problems = []
    for row in whole:
        number = str(row[6])
        joined = restrictions.get(number, [])
        codes = {r['subjectCode'] for r in joined if r['subjectCode']}
        title_matches = all(compact_title(r['title']) == compact_title(row[7]) for r in joined)
        code = next(iter(codes)) if len(codes) == 1 and title_matches else None
        if joined and (len(codes) != 1 or not title_matches):
            problems.append({'enrollmentNumber': number, 'subjectCodes': sorted(codes), 'titleMatches': title_matches})
        raw_time = str(row[13])
        if raw_time == '시간표자료없음':
            scope = 'published-time-unavailable'
        elif raw_time == '시간표에러발생':
            scope = 'published-timetable-error'
        elif any(s in raw_time for s in ['블렌디드', 'Blended']):
            scope = 'blended-attendance-period-review'
        elif any(s in raw_time for s in ['원격', 'K-MOOC', '거점국립대', 'JOY', 'OCU']):
            scope = 'remote-actual-attendance-or-assessment-review'
        else:
            scope = 'ordinary-clock-current-operation-review'
        courses.append({
            'enrollmentNumber': number,
            'subjectCode': code,
            'section': None,
            'department': row[1],
            'grade': row[2],
            'classification': row[3],
            'area': row[4],
            'title': row[7],
            'liberalAdminDepartment': row[8],
            'rawOperatingMethod': row[9],
            'credits': row[10],
            'hours': row[11],
            'professor': row[12],
            'rawTimeAndRoom': row[13],
            'campus': None,
            'enrollmentRestrictions': joined,
            'operatingReview': scope,
            'currentActiveStatusVerified': False,
            'meetings': [],
        })
    assert len(courses) == 3095
    assert len({c['enrollmentNumber'] for c in courses}) == 3095
    output = {
        'sourceSnapshotDate': '2026-07-29',
        'reviewDate': '2026-10-08',
        'productionReady': False,
        'school': '제주대학교',
        'sourceUrl': 'https://jejunu.ac.kr/ara/noticesurvey/outEvent.htm?category=321&act=view&seq=278363',
        'sectionPolicy': 'Never derive section or canonical subject code from enrollment number.',
        'restrictionDatePolicy': 'Restriction dates govern enrollment eligibility, never teaching dates.',
        'remotePolicy': 'Guide differentiates remote printed exam reservation from blended weekly in-person attendance; no dated exam invented.',
        'courses': courses,
    }
    path = ROOT / 'jeju-current-whole-educational-review-20261008.json'
    path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
    audit = {
        'sourceWholeCount': len(courses),
        'sourceRestrictionRows': len(restriction_rows),
        'excludedSummaryRows': 1,
        'publishedSummaryEnrollmentCount': total_row[2],
        'explicitRestrictionEnrollmentNumbers': len(restrictions),
        'exactEnrollmentTitleCodeVerified': sum(c['subjectCode'] is not None for c in courses),
        'codeJoinConflicts': problems,
        'unmatchedRestrictionNumbers': sorted(set(restrictions) - {c['enrollmentNumber'] for c in courses}),
        'operatingReviewCounts': dict(collections.Counter(c['operatingReview'] for c in courses)),
        'allRawOperatingMethodEmpty': all(c['rawOperatingMethod'] == '' for c in courses),
        'scheduled': 0,
        'universityImpossible': False,
        'productionReady': False,
        'candidateSha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'excludedNonEducationFields': ['applicationCount', 'capacity'],
        'remaining': ['Current whole activity/closures and time changes', 'Actual published subject code/section for remaining rows', 'Current ordinary period and individual operating exceptions', 'Source campus building attribution'],
    }
    (ROOT / 'jeju-current-whole-educational-review-audit-20261008.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    return output, audit


if __name__ == '__main__':
    _, result = prepare()
    print(json.dumps(result, ensure_ascii=False, indent=2))
