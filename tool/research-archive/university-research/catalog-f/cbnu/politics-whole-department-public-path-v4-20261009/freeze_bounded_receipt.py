import hashlib
import json
import pathlib
import re

out = pathlib.Path(__file__).resolve().parent
base = out.parent
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def save(name, value):
    (out / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
receipts = json.loads((out / 'politics-public-path-education.json').read_text())
assert len(receipts) == 3 and all(r['normalStatus'] == 200 for r in receipts)
curriculum = receipts[2]['educationTablesOnly'][0]
codes = [v for row in curriculum for v in row if re.fullmatch(r'\d{7}', v)]
assert len(codes) == len(set(codes)) == 36
v3 = base / 'current-whole-public-path-and-politics-partial-v3-20261009/cbnu-main-2026-2.politics-partial-v3.json'
prior = json.loads(v3.read_text())
assert len(prior['courses']) == 14
assert sum(len(c['schedules']) for c in prior['courses']) == 555
save('bounded-whole-department-scope-audit.json', {
    'researchOnly': True, 'completionClaim': False, 'impossibleClaim': False,
    'focus': 'Existing current political-science freshman notice → observed undergraduate notice board → actual2026-2 registration notice and current2026 curriculum; one bounded department route.',
    'freshNormalBoardObservation': {
        'url': receipts[0]['sourceUrl'], 'normalStatus': 200,
        'currentNewestObservedTitle': '2026-2학기 정치외교학과 학부 졸업시험 안내',
        'newestObservedDate': '10-06',
        'firstPageScope': '25 published notice entries including pinned duplicates plus header; bounded visible first page, not whole archive census.',
        'currentSemesterOfferingTimeTableSeen': 'Known freshman designated3 row notice only; no broader current offering timetable title/link observed in this bounded list.',
        'excludedAsCourse': ['학부 졸업시험', '학점교류 다른 대학', '직업특강', '장학/등록/인턴/졸업신청'],
    },
    'currentRegistrationNotice': {
        'url': receipts[1]['sourceUrl'], 'title': '2026학년도 2학기 수강신청 일정 안내',
        'publishedDate': '2026-07-16',
        'observedAttachmentLabelsFromRenderedPage': ['붙임1_2025-2학기_수강신청_안내_학부생.hwp',
            '붙임2_개신누리_수강신청_매뉴얼(학생).hwp', '붙임3_개신누리_초과_수강신청_매뉴얼(학생).hwp'],
        'boundary': '2026-2 notice body contains registration/change/cancellation dates and directs 개신누리; first attachment label itself2025-2. No whole current course schedule attachment/link observed. Stale-labeled guide/manual not downloaded or substituted for current native teaching.',
        'automaticAttachmentExtractionReturned': 0,
        'attachmentLabelEvidenceMethod': 'Public rendered page visible text; HTML helper did not recognize this site attachment control, so zero machine extraction is not claimed to mean no attachments.',
    },
    'currentCurriculum': {
        'url': receipts[2]['sourceUrl'], 'nativeHeading': '현 교육과정(2026학년도)',
        'nativeUniqueCurriculumCodeCount': 36,
        'printedFields': ['학년', '학기', '이수구분', '교과목 번호', '교과목명', '학점'],
        'missingOfferingFields': ['개설강좌 분반', '현재 개설 확정 여부', '담당교수', '요일/교시/HH:mm', '강의실', '현재 폐강/정정'],
        'referenceOnly': True, 'addedAsCurrentOffering': 0,
        'worldDiplomaticHistoryReference': {'nativeCode': '5666079', 'nativeTitle': '*세계외교사(World Diplomatic History)', 'nativeCreditTheoryPractice': '3-3-0',
            'use': 'Separate curriculum reference, not added to frozen source candidate or inferred sections/professor.'},
    },
    'preservation': {
        'v3CandidateSha256': digest(v3), 'existingNative': 14, 'existingAppointments': 555,
        'newEligibleNative': 0, 'newDatedAppointments': 0,
        'knownClosure65Sha256': digest(base / 'cbnu-current-closure-education-20261008.json'),
        'oldCandidateRewritten': False, 'existingCalendarClockUnchanged': True,
        'nativeCurriculumCodesNotMergedAsOfferings': True,
    },
    'boundaries': {'loginPortalOpened': False, 'hiddenEndpointGuessed': False, 'protectedRetry': False,
        'sdkUsed': False, 'productModified': False, 'AGENT_MEMORYModified': False,
        'fullHtmlOrContactsSaved': False, 'newCandidateRequired': False},
    'remainingEvidence': ['Current department all-year actual offered timetable with sections/teachers/weekdays/rooms',
        'Current undergraduate whole offered course export and exact filters/pages', 'Latest full closure/changes',
        'Offering-specific physical campus and individual operation exceptions'],
    'verification': 'PASS normal200 educational receipt3, current curriculum36 unique code rows, v3 existing14/555 unchanged read-only census. No new scheduled support asserted.',
})
save('SHA256SUMS.json', {'files': {p.name: digest(p) for p in sorted(out.iterdir())
    if p.is_file() and p.name != 'SHA256SUMS.json'}, 'newEligibleNative': 0,
    'sdkUsed': False, 'completionClaim': False, 'impossibleClaim': False})
print('PASS bounded receipt/nativecurriculum36/new0', digest(out/'SHA256SUMS.json'))
