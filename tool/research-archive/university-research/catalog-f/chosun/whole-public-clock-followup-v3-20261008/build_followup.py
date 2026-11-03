"""Research-only bounded current public education follow-up. No source edits."""
from pathlib import Path
from datetime import date
import hashlib, json, re
R = Path(__file__).parent
S = R.parent
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(name, value):
    (R / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
baseline = S / 'chosun-unknown-2026-2.future-nurse-native135-partial-v2.json'
a = json.loads(baseline.read_text())
assert sha(baseline) == 'e7cc3ca9e41982726aca7e2c711fa51aa72d2e023918ac59205bcb94144400ee'
assert len(a['courses']) == 135
assert sum(bool(c['schedules']) for c in a['courses']) == 62
assert sum(len(c['schedules']) for c in a['courses']) == 724
rows = json.loads((S / 'chosun-nurse-current-education-source-20261008.json').read_text())['educationRows']
upper = [r for r in rows if r['heldReasons'] == ['upperGradeClinicalIntensiveDatesUnverified']]
assert len(upper) == 20
pdf = Path('/private/tmp/chosun-2026-2-guide-current.pdf')
from pypdf import PdfReader
text = PdfReader(pdf).pages[22].extract_text()
assert '매 교시 강의시간 : 30분' in text
assert '14A22:00~22:30' in text
clocks = []
for match in re.finditer(r'(\d{1,2}[AB])(\d{2}):(\d{2})~(\d{2}):(\d{2})', text):
    period, h1, m1, h2, m2 = match.groups()
    clocks.append({'nativePeriod': period, 'startMinute': int(h1)*60+int(m1), 'endMinute': int(h2)*60+int(m2)})
assert len(clocks) == 27
save('current-central-clock-education.json', {
    'entryUrl': 'https://acguide.chosun.ac.kr/acguide/9252/subview.do',
    'sourceUrl': 'https://acguide.chosun.ac.kr/sites/acguide/20262%ED%95%99%EA%B8%B0%EC%88%98%EA%B0%95%EC%8B%A0%EC%B2%AD/2026-2%ED%95%99%EA%B8%B0%20%EC%88%98%EA%B0%95%EA%B0%80%EC%9D%B4%EB%93%9C.pdf',
    'sourceSHA256': sha(pdf), 'academicYear': 2026, 'semester': '2',
    'pdfPageOneBased': 23, 'printedPage': 15,
    'nativeScope': 'Ⅳ. 수업 및 성적 / 1. 수업시간 / 월·화·수·목·금(30분 단위 수업)',
    'minimumInstructionWeeks': 15, 'nativeMinutesPerPeriod': 30,
    'periods': clocks, 'wednesdayCuTime': {'startMinute': 720, 'endMinute': 780, 'nativeNoClass': True},
    'saturdayApplicabilityProven': False, 'courseOfferingRowsInGuide': False,
    'note': '교육과정 과목번호 목록은 현재 개설분반·교수·요일·실이 함께 공개된 whole 강좌 목록으로 계산하지 않는다. 14B는 표에 없으므로 만들지 않는다.'
})
save('normal-public-whole-and-closure-boundary.json', {
    'checkedDate': '2026-10-08', 'completionClaim': False,
    'officialEntryUrl': 'https://acguide.chosun.ac.kr/acguide/9252/subview.do',
    'nativeLinkLabel': '개설교과목 및 수업계획서 조회',
    'actualGuestLink': 'https://a.chosun.ac.kr/S/sugang/gaeseol',
    'normalLinkObservation': 'Official navigation link opened once; explicit website connection blocked. Stopped without retrying scripts, API, cookies, alternate host, proxy, or admission keys.',
    'guestWholeEducationRowsAcquired': 0,
    'closureNotice': {'sourceUrl': 'https://acguide.chosun.ac.kr/bbs/acguide/793/234663/artclView.do', 'publishedDate': '2026-09-07', 'updatedDate': '2026-09-08', 'nativeTitle': '2026학년도 2학기 폐강교과목 및 폐강에 따른 수강신청 정정기간 안내', 'normalHttpStatus': 200, 'rawResponseSHA256': sha('/private/tmp/chosun-closure-234663.html'), 'wholeClosedCourseRowsPublishedOnNotice': False, 'attachmentPresent': False, 'nativeWholeLookup': ['포털시스템', '종합정보', '수업', '교육과정/과목', '개설교과목조회', '대학/학부(과) 전체', '개설구분 폐강'], 'lookupPerformed': False},
    'latestWholeClosureCompared': False, 'universityProvenImpossible': False,
    'priorScreenCountIsNotWholeEducationRows': True,
    'alternativeSourcesChecked': ['current central 2026-2 registration guide', 'current undergraduate nursing timetable notice', 'current 2026 nursing curricular arrangement', 'current nuclear engineering timetable-change notice', 'official public department timetable search'],
    'excludedAlternativeScopes': ['graduate timetable', 'admission interview and applicant lists', 'credit-bank courses', 'other universities', 'first-semester timetable']
})
save('nuclear-current-change-education.json', {
    'sourceUrl': 'https://nuclear.chosun.ac.kr/bbs/nuclear/539/234365/artclView.do',
    'rawResponseSHA256': sha('/private/tmp/chosun-nuclear-234365.html'),
    'publishedDate': '2026-09-01', 'updatedDate': '2026-09-01',
    'nativeTitle': '[안내] 공학수학2 시간표 변경 안내', 'nativeCourseTitle': '공학수학2',
    'nativeCurrentClock': [{'weekday': 1, 'startMinute': 780, 'endMinute': 840}, {'weekday': 3, 'startMinute': 600, 'endMinute': 720}],
    'nativeProposedClock': [{'weekday': 1, 'startMinute': 780, 'endMinute': 840}, {'weekday': 3, 'startMinute': 960, 'endMinute': 1080}],
    'changeIsFutureConditional': True, 'changeCompletionPublished': False,
    'courseCode': '', 'section': '', 'professor': '', 'classroom': '', 'campus': 'unknown',
    'scheduled': False, 'heldReasons': ['change completion unconfirmed', 'native code/section/professor/room unpublished'],
    'note': '수강취소 후 변경 예정 공지다. 예정 시각을 실제 적용 완료나 다른 과목 열유체역학/핵주기공학의 시간으로 연결하지 않는다.'
})
save('nursing-upper-grade-operating-audit.json', {
    'currentNoticeUrl': 'https://nurse.chosun.ac.kr/bbs/nurse/694/233477/artclView.do',
    'freshNormalHttpUpdatedDate': '2026-09-07', 'freshRawResponseSHA256': sha('/private/tmp/chosun-nurse-233477-fresh.html'),
    'currentAttachUrl': 'https://nurse.chosun.ac.kr/bbs/nurse/694/168052/download.do',
    'searchCacheUpdatedDateIsStale': '2026-08-28',
    'curricularSourceUrl': 'https://www4.chosun.ac.kr/bbs/nurse/693/162002/download.do',
    'curricularYear': 2026, 'curricularOfferingCountIsNotActualCurrentWhole': True,
    'currentUpperGradeClockRoomCellsHeldOnlyForOperatingDates': upper,
    'reviewCount': 20, 'intensiveOperationProvenByGradeAlone': False,
    'candidateStillHeld': True,
    'crossSourceCaution': [
        {'nativeCurriculumTitle': '지역사회간호학1', 'nativeCode': '21541', 'credits': 2, 'theoryHours': 2, 'practicalHours': 0, 'nativeTimetableBlockMinutes': 180},
        {'nativeCurriculumTitle': '모성간호학2', 'nativeCode': '21532', 'credits': 2, 'theoryHours': 2, 'practicalHours': 0, 'nativeTimetableBlockMinutes': 180},
        {'nativeCurriculumTitle': '지역사회간호학3', 'nativeCode': '21543', 'credits': 1, 'theoryHours': 1, 'practicalHours': 0, 'nativeTimetableBlockMinutes': 120},
        {'nativeCurriculumTitle': '간호관리학2', 'nativeCode': '47362', 'credits': 1, 'theoryHours': 1, 'practicalHours': 0, 'nativeTimetableBlockMinutes': 120}
    ],
    'interpretation': 'Printed current theory hours differ from weekly timetable block duration. This is a caution requiring the actual theory/clinical operating date plan, not proof of specific intensive weeks. No title-only official code join or grade-only definitive intensive claim.',
    'clinicalRuleSourceUrl': 'https://nurse.chosun.ac.kr/nurse/8439/subview.do',
    'clinicalRuleScope': 'actual clinical practice placement table is made by department; may operate during vacation when placements are scarce',
    'clinicalRuleDoesNotProveTheoryCourseOperatingDates': True,
    'nursingAcademicCalendarMenuLinksToCentralSchoolCalendar': True,
    'exactIndividualTheoryClinicalCalendarAcquired': False
})
assert not any(s['weekday'] == 3 and s['startMinute'] < 780 and s['endMinute'] > 720 for c in a['courses'] for s in c['schedules'])
save('verification.json', {'baselineSHA256': sha(baseline), 'historicalSourceUnchanged': True, 'preservedNativeDocumentBlocks': 135, 'preservedScheduledBlocks': 62, 'preservedDatedSlots': 724, 'newEligibleScheduledBlocks': 0, 'nativeCentralPeriodsIndependentlyRead': 27, 'existingCuTimeConflicts': 0, 'upperGradeReviewCells': 20, 'newDartOrFlutterExecuted': False, 'productionChanged': False, 'completionClaim': False})
print('Bounded source verification passed: 135 / 62 / 724 preserved; 27 direct current periods; new eligible 0; 20 upper-grade date gaps.')
