# coding: utf-8
"""Educational currency scope audit; never treats absent closure data as empty."""
import collections
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).parent

def load(name):
    return json.loads((ROOT / name).read_text())

def sha(name):
    return hashlib.sha256((ROOT / name).read_bytes()).hexdigest()

def prepare():
    candidate_name = 'kunsan-current-whole-operating-date-checkpoint-next-20261008.json'
    candidate = load(candidate_name)
    scheduled = [row for row in candidate['courses'] if row['scheduleStatus'] == 'scheduled']
    assert len(candidate['courses']) == 1718 and len(scheduled) == 800
    source_methods = collections.Counter(tuple(row['sourceTeachingMethods']) for row in scheduled)
    assert source_methods == {('대면',): 797, ('혼합',): 2, ('비대면',): 1}
    assert all(row['campus'] == 'unknown' for row in scheduled)
    package = load('kunsan-current-package-recheck-20261008.json')
    attachments = []
    for number, entry in enumerate(package[1:], 1):
        item = {'number': number, 'title': entry['title'], 'sourceURL': entry['url'],
                'sha256': entry['sha256'], 'sameBytesAsPreviouslyCollected': entry['sameAsOriginal'],
                'individualUploadDatePublished': None}
        if number > 1:
            with zipfile.ZipFile(ROOT / f'kunsan-2026-2-attachment-{number}.xlsx') as book:
                properties = ET.fromstring(book.read('docProps/core.xml'))
                item['internalWorkbookTimestamps'] = {
                    field.tag.split('}')[-1]: field.text
                    for field in properties
                    if field.tag.split('}')[-1] in ('created', 'modified')}
        attachments.append(item)
    identities = [{'courseCode': row['courseCode'], 'section': row['section'],
                   'courseName': row['courseName'], 'campus': row['campus'],
                   'sourceTeachingMethods': row['sourceTeachingMethods'],
                   'currentFinalActiveStatus': 'not-verified',
                   'individualCurrentPlanExceptionStatus': 'not-whole-reviewed'}
                  for row in scheduled]
    review = {
        'checkedAt': '2026-10-08', 'productionReady': False, 'completionClaim': False,
        'candidate': candidate_name, 'candidateSHA256': sha(candidate_name),
        'wholeCourseCount': 1718, 'ordinaryResearchCandidateCount': 800,
        'packageNoticePublishedDate': '2026-07-23', 'attachments': attachments,
        'attachmentTimestampLimits': 'Workbook modified timestamps are internal metadata, not published upload dates or proof no later closure/change. PDF and individual attachment upload dates are not claimed.',
        'actualClosureCriteria': {'first': '2026-09-04T18:00', 'second': '2026-09-09T18:00',
                                 'source': 'kunsan-current-enrollment-currency-excerpts-20261008.json'},
        'latestCentralPublicTitleSearch': 'kunsan-current-central-title-followup-20261008.json',
        'searchResultScope': 'Normal central actual board first current title-search page for 폐강, 시간표, 수강신청, 수업. Most recent observed 폐강 title is 2025 winter seasonal; current July regular enrollment notices and September winter course-demand notice are not current regular active lists. Earlier published 59-department/65-form searches retained separately.',
        'verifiedCurrentRegularClosureListFound': False,
        'closureMatch': {'actualClosureIdentitiesAvailable': None, 'matchedClosedCourseCount': None,
                         'confirmedActive800Count': None,
                         'reason': 'No actual current regular final closure identities observed in scoped normal public evidence. Null is unverified, never zero closures.'},
        'currentTimeRoomChangeIdentitiesAvailable': None,
        'normalAuthenticatedBoundary': 'kunsan-current-normal-query-boundary-20261008.json',
        'currencyWarning': 'Current official package expressly requires checking changed timetable in integrated information system; tested published kis root/portal normal path displays loginId/loginPwd/loginBtn. No login/private transactions attempted; not proof every public route impossible.',
        'ordinary800Verified': {
            'actualSourceModeCounts': {'대면': 797, '혼합': 2, '비대면': 1},
            'officialDefaultInPersonPolicy': 'kunsan-current-enrollment-currency-excerpts-20261008.json',
            'explicitLiveCourseIdentities': ['107053-01', '114591-01', '114281-01'],
            'rawModeClockRoomSourceEquality': True,
            'ordinaryPeriodSchoolClosuresAndExactMakeups': 'kunsan-operating-date-next-audit-20261008.json',
            'actualSourceCampusCounts': {'unknown': 800},
            'campusAssignmentByDepartmentOrBuildingGuess': False,
            'individualCurrentPlansWholeRead': False,
            'individualHolidayOverridesOrFieldExceptionsWholeVerified': False,
            'latestFinalActiveScopeVerified': False,
            'limits': 'Source literal 대면 plus current official default supports ordinary in-person mode. Generic evaluation weeks do not themselves imply no class, but separate published exam windows are not invented ordinary meetings. Explicit individualized exceptions remain unverified; no names-only exception conclusions.'},
        'candidateIdentitiesStillRequiringCurrentFinalActiveScope': identities,
        'permanentImpossible': False,
    }
    (ROOT / 'kunsan-current-currency-scope-review-20261008.json').write_text(
        json.dumps(review, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'whole': 1718, 'scheduledResearch': 800, 'currentActiveVerified': None,
                      'modeCounts': review['ordinary800Verified']['actualSourceModeCounts'],
                      'candidateUnchangedSHA256': review['candidateSHA256']}, ensure_ascii=False))

if __name__ == '__main__':
    prepare()
