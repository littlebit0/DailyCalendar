"""Independent current DGIST native theory screen; creates research files only."""
from pathlib import Path
import collections
import copy
import datetime as dt
import hashlib
import json
import re

D = Path(__file__).resolve().parent
C = D.parent
R = D.parents[3]
base_path = C / 'dgist-theory-weekly-reservations-20261008/dgist-unknown-2026-2.theory-weekly-reservations-v1.json'
base = json.loads(base_path.read_text())
candidate = copy.deepcopy(base)
plans_path = C / 'dgist-current-published-plans-educational.json'
plans = {(p['code'], p['section']): p for p in json.loads(plans_path.read_text())}
raw_by_curriculum = {}
for year in ['2020', '2024', '2014']:
    path = C / f'dgist2026-2-{year}-current-recheck-20261008.json'
    raw_by_curriculum[year] = {(r['SBJT_NO'], r['CLSS_NO']): r for r in json.loads(path.read_text())}
clock = re.compile(r'([월화수목금토일])(\d{2}):(\d{2})-(\d{2}):(\d{2})\(([^()]*)\)')
start, end = dt.date(2026, 8, 24), dt.date(2026, 12, 11)
excluded = {dt.date(2026, 9, d) for d in [24, 25, 26]} | {dt.date(2026, 10, d) for d in [3, 5, 9]}
excluded |= {dt.date(2026, 10, d) for d in range(12, 17)} | {dt.date(2026, 12, d) for d in range(7, 12)}
reviewed_lab_offerings = {'BS102a-01', 'PHY301-01', 'BS202a-01', 'BS101-04', 'BS101-02', 'LS205-01', 'BE206-03', 'LS202-01', 'MSE309-01', 'SE211b-01', 'BS106a-03', 'EE405-01', 'BE206-01', 'BS106a-04', 'BS106a-05', 'BS115-06', 'BS106a-02', 'BS106a-01', 'BR303-01', 'BE206-05', 'CE201a-01', 'BS113-07', 'BS101-03', 'BS113-08', 'BS106a-06', 'CHEM302-01', 'BR406-01', 'LS202-02', 'BR407-01', 'BE206-06', 'BS115-03', 'BS101-01', 'BS113-04', 'BS113-06', 'BE206-02', 'BS115-02', 'BS115-04', 'BS115-05', 'BS101-05', 'BS113-05', 'BS115-01', 'ENT301-01', 'BS113-03', 'BS113-01', 'BS113-02'}
receipts, classification = [], []
for before, course in zip(base['courses'], candidate['courses']):
    key = (course['courseCode'], course['section'])
    variants = course['sourceEducationalMetadata']['curriculumVariants']
    for variant in variants:
        assert variant['fields'] == raw_by_curriculum[variant['curriculum']][key]
        fields = variant['fields']
        assert fields['SHYY'] == '2026' and fields['SHTM_DCD'] == 'CMN17.20' and fields['ORGN_CLSF_NM'] == '대학'
    reasons = []
    theory = all(v['fields']['LT_PRAC_NM'] == '이론' and float(v['fields']['PRAC_TMCNT']) == 0 for v in variants)
    text = course['sourceSchedule']
    matches = list(clock.finditer(text))
    complete_geometry = matches and not clock.sub('', text).replace(',', '').strip() and all(m[6].strip() for m in matches)
    source = plans.get(key, {})
    plan = source.get('fields', {})
    individual_exclusions = set()
    if before['schedules']:
        status = 'existing150Preserved'
    else:
        if not theory and '-'.join(key) not in reviewed_lab_offerings:
            reasons.append('practiceOrMixedActualAllocationNotReviewed')
        if course['courseCode'].startswith(('RP', 'INT')):
            reasons.append('individualResearchOrInternshipAllocationMeaningNotReviewed')
        if not complete_geometry:
            reasons.append('incompleteActualClockRoom')
        if key == ('LS313a', '01'):
            reasons.append('sourceWarnsActualLabEndBeyondPublishedTwoHourSlotUnallocated')
        if plan:
            assert plan['SBJT_NO'] == key[0] and plan['CLSS_NO'] == key[1]
            if plan['INFO'].replace(' ', '') != text.replace(' ', ''):
                reasons.append('currentPlanNativeClockRoomConflict')
            operation = '\n'.join(str(plan.get(f, '')) for f in ['LSN_MTHD', 'LT_POLY', 'ETC', 'SCHETCHUL'])
            if re.search(r'온라인\s*강의|비대면\s*(?:강의|수업)|비동기|녹화\s*(?:강의|수업)|집중\s*(?:강의|수업)|asynchronous|online\s+(?:lecture|class)|intensive\s+(?:class|course)', operation, re.I):
                reasons.append('explicitRemoteIntensiveOrAsynchronousOperation')
            if key in [('HSS109a', '04'), ('HSS109a', '05')]:
                assert '12월 4일' in operation and '휴강' in operation
                individual_exclusions.add(dt.date(2026, 12, 4))
            if key == ('HSS116', '01'):
                assert '(11/23)' in operation and '개별 면담' in operation
                individual_exclusions.add(dt.date(2026, 11, 23))
        status = 'heldKnownOrUnreviewedException' if reasons else 'ordinaryNativeWeeklyReservation'
    classification.append({'offering': '-'.join(key), 'status': status, 'reasons': reasons, 'sourceSchedule': text, 'allVariantsTheoryAndZeroPractice': theory})
    if status != 'ordinaryNativeWeeklyReservation':
        assert course == before
        continue
    meetings = []
    for offset in range((end-start).days+1):
        date = start + dt.timedelta(days=offset)
        if date in excluded | individual_exclusions:
            continue
        for m in matches:
            weekday = '월화수목금토일'.index(m[1])+1
            if date.isoweekday() != weekday:
                continue
            sm, em = int(m[2])*60+int(m[3]), int(m[4])*60+int(m[5])
            assert 0 <= sm < em <= 1440
            meetings.append({'weekday': weekday, 'startMinute': sm, 'endMinute': em, 'classroom': m[6].strip(), 'date': date.isoformat()})
    assert meetings
    course['schedules'] = meetings
    course['scheduleStatus'] = 'scheduled'
    course['period'] = {'startDate': str(start), 'endDate': str(end)}
    course['reservationEvidence'] = {'dateMeaning': 'derivedRegularWeeklyReservationNotSourcePublishedAttendance', 'nativeWeeklyClockRoom': text, 'sourceWeekIndexUsed': False, 'sourcePublishedIndividualDatesClaim': False, 'ownTermStart': str(start), 'ownTermEnd': str(end), 'excludedIndividualDates': sorted(map(str, individual_exclusions))}
    note = '현재2026-2 대학 공개native요일·정확시각·강의실과 자체8/24개강~12/11종강 범위의 정규 주간 예약입니다. 개별원문에 직접 게시된 실제출석 날짜가 아닙니다. 시험주간·공휴일·직접게시개별휴강/면담일은 제외하고 보강·시험시각은 추정하지 않습니다. 주차번호 날짜변환 없음. 개별별도배정/원격/집중/실제종료미확정 예외는 별도 보류하며 사용자3종강의방식은 유지합니다.'
    course['remarks'] = note
    # Preserve source department notes as educational provenance, replace only obsolete blanket hold wording.
    course['departmentRemarks'] = {k: v.replace('실제 주차별 운영 검증 전으로 시간표 자동 추가를 보류합니다.', note) for k, v in course['departmentRemarks'].items()}
    receipts.append({'offering': '-'.join(key), 'sourceId': course['sourceId'], 'nativeEducationalVariants': variants, 'genericLabOrMixedLabelAloneDoesNotBlock': '-'.join(key) in reviewed_lab_offerings, 'sourcePlanPresent': bool(plan), 'sourcePlanIdentityChecked': bool(plan), 'sourceClockRoom': text, 'individualExcludedDates': sorted(map(str, individual_exclusions)), 'reservationCount': len(meetings), 'physicalCampusClaim': False})
    for field in ['sourceId', 'sourceEducationalMetadata', 'courseCode', 'section', 'courseName', 'professor', 'credits', 'classification', 'sourceSchedule', 'sourceClassroom', 'campus']:
        assert course.get(field) == before.get(field)
candidate.update(researchOnly=True, productionIntegrationEnabled=False, completionClaim=False, wholeOperatingAuditFinished=False)
p = D / 'dgist-unknown-2026-2.lab-weekly-reservations-v2.json'
p.write_text(json.dumps(candidate, ensure_ascii=False, indent=2)+'\n')
for name, value in [('all569-classification-v2.json', classification), ('ordinary-lab-source-receipts-v2.json', receipts)]:
    (D/name).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')
counts = collections.Counter(x['status'] for x in classification)
audit = {'researchOnly': True, 'completionClaim': False, 'baseFile': str(base_path.relative_to(R)), 'baseSHA256': hashlib.sha256(base_path.read_bytes()).hexdigest(), 'candidateFile': p.name, 'candidateSHA256': hashlib.sha256(p.read_bytes()).hexdigest(), 'nativeWhole': 569, 'prior150Courses3244MeetingsDeepEqual': True, 'classificationCounts': dict(counts), 'newReservationCourses': len(receipts), 'newReservationMeetings': sum(r['reservationCount'] for r in receipts), 'totalScheduled': sum(bool(c['schedules']) for c in candidate['courses']), 'totalMeetings': sum(len(c['schedules']) for c in candidate['courses']), 'heldReasonCountsOverlapping': dict(collections.Counter(r for c in classification for r in c['reasons'])), 'globalExcludedDates': sorted(map(str, excluded)), 'wholeNativeCurriculumFieldsIndependentlyMatched': True, 'sourceNativeFiles': [f'dgist2026-2-{y}-current-recheck-20261008.json' for y in raw_by_curriculum], 'sdkCalls': 0, 'actualModelFixture': 'not run; research only pending SDK slot', 'productEdited': False}
(D/'lab-weekly-audit-v2.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(audit, ensure_ascii=False))
