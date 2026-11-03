"""Source-only HUFS partial operating review; no network or product mutations."""
import copy
import hashlib
import json
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PRIOR = ROOT.parent

def load(path):
    return json.loads(path.read_text())

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save(name, data):
    (ROOT / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')

# Reviewed literal native day/period/room, not auto-selection from lexical flags.
REVIEWED = {
    'global/M01206101': (3, 4, 5, '0604', True, []),
    'global/M01308101': (1, 7, 8, '0311', True, []),
    'seoul/A10104101': (3, 1, 2, '1310', True, []),
    'seoul/A10104106': (2, 1, 2, '1202', True, []),
    'seoul/A10105101': (3, 3, 4, '1310', True, []),
    'seoul/A10106102': (1, 3, 4, '1404', False, []),
    'seoul/A10106104': (1, 1, 2, '1404', False, []),
    'seoul/A10106105': (2, 3, 4, '1202', False, []),
    'seoul/A08418101': (3, 7, 8, '3402', True, ['2026-10-28']),
    'seoul/A40152201': (3, 9, 10, '3402', True, ['2026-10-28']),
}
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
proofs = []
summary = {}
for campus in ['seoul', 'global']:
    baseline_path = PRIOR / f'hufs-{campus}-2026-2.checkpoint-review-3.json'
    prior = load(baseline_path)
    candidate = copy.deepcopy(prior)
    native = {c['sourceId']: c for c in load(PRIOR / f'hufs-{campus}-2026-2.whole-candidate.json')['courses']}
    for course in candidate['courses']:
        key = course['courseCode'] + course['section']
        review_key = campus + '/' + key
        if review_key not in REVIEWED:
            continue
        weekday, first, last, room, midterm, no_class = REVIEWED[review_key]
        assert not course['schedules']
        native_course = native[course['sourceId']]
        plan_path = PRIOR / 'hufs-public-operating-plans' / f"{'H1' if campus == 'seoul' else 'H2'}-{key}.json"
        plan = load(plan_path)
        assert plan['key'] == key and plan['checkedDate'] == '2026-10-08'
        assert plan['fields']['identity'].endswith(key)
        assert plan['fields']['schedule'].split('\n')[0] == course['sourceSchedule']
        assert plan['publicPlanMetadataStatus'] == 'published'
        # Current own-campus published table starts at 09:00 for numbered 1.
        start = (8 + first) * 60
        end = (8 + last) * 60 + 50
        rule = {'weekday': weekday, 'startMinute': start, 'endMinute': end, 'classroom': room}
        assert rule in native_course['schedules']
        excluded = set(HOLIDAYS) | set(no_class)
        if midterm:
            assert '고사' in plan['fields']['weekly']['8th'] or 'Midterm' in plan['fields']['weekly']['8th']
            excluded |= {(date(2026, 10, 20) + timedelta(days=i)).isoformat() for i in range(7)}
        cursor = date(2026, 9, 1)
        dates = []
        while cursor <= date(2026, 12, 7):
            if cursor.isoweekday() == weekday and cursor.isoformat() not in excluded:
                dates.append(cursor.isoformat())
            cursor += timedelta(days=1)
        course['schedules'] = [{**rule, 'date': value} for value in dates]
        course['scheduleStatus'] = 'scheduled'
        note = '공개 정규 주간 예약 계획; 개별 실제 출석일 미확정. 보강·기말시험 시각 미확정으로 추가하지 않음'
        if campus == 'global':
            note += '; 별도 목10/금10 녹화 차시는 예약 제외'
        if midterm:
            note += '; 개별 8주 시험과 자체 10/20–26 시험기간을 결합해 해당 정규 예약 제외(시험일·시각 생성 아님)'
        if no_class:
            note += '; 직접 10/28 휴강 제외'
        course['departmentRemarks'] = {
            department: value.removesuffix(' · 공개 운영 일정 확인 중: 자동 시간 생성 보류') + ' · ' + note
            for department, value in course['departmentRemarks'].items()
        }
        proofs.append({
            'sourceId': course['sourceId'], 'baselinePath': str(baseline_path), 'baselineSha256': sha(baseline_path),
            'nativeCourse': native_course, 'review3HeldCourse': next(c for c in prior['courses'] if c['sourceId'] == course['sourceId']),
            'planPath': str(plan_path), 'planSha256': sha(plan_path), 'educationPlan': plan,
            'rule': rule, 'ordinaryDates': dates, 'individualKnownNoClassDates': no_class,
            'individualWeek8Exam': midterm, 'examPeriodExcludedOnlyWhenIndividualWeek8Exam': ['2026-10-20', '2026-10-26'] if midterm else [],
            'explicitRemoteDayExcluded': native_course['schedules'][1] if campus == 'global' else None,
            'derivedDates': True, 'individuallyPrintedDates': False, 'attendanceConfirmed': False,
            'examTimeConfirmed': False, 'userDeliveryModeForced': False,
            'sourceSnapshotDate': '2026-10-08', 'freshRequeryPerformed': False,
        })
    name = f'hufs-{campus}-2026-2.partial-operation-v4-research.json'
    save(name, candidate)
    summary[campus] = {'whole': len(candidate['courses']), 'scheduled': sum(bool(c['schedules']) for c in candidate['courses']), 'reservations': sum(len(c['schedules']) for c in candidate['courses']), 'candidatePath': str(ROOT / name), 'sha256': sha(ROOT / name)}
save('reviewed-source-proofs.json', proofs)
# This is a next-review triage, never a lexical activation whitelist.
unresolved = load(PRIOR / 'hufs-registration-checkpoint-review-3-audit.json')['unresolved']
pool = []
for entry in unresolved:
    if entry['kind'] != 'reviewedOperatingProofUnresolved':
        continue
    contexts = entry['reviewedOperatingContexts']
    late_only = bool(contexts) and all(c['field'] == '15th' for c in contexts)
    pool.append({'sourceId': entry['sourceId'], 'reviewedOperatingContexts': contexts, 'triage': 'lateWeekOnlyNeedsFullPlanReview' if late_only else 'otherOperatingContextNeedsIndividualReview', 'activatedByTriage': False})
save('held956-next-review-triage.json', {'sourceOnly': True, 'completionClaim': False, 'counts': {'wholeOperatingHeldPool': len(pool), 'only15thFlaggedPool': sum(x['triage'] == 'lateWeekOnlyNeedsFullPlanReview' for x in pool)}, 'rows': pool})
save('candidate-audit.json', {'sourceOnly': True, 'completionClaim': False, 'modelValidated': False, 'sdkUsed': False, 'productEdited': False, 'newCourses': len(proofs), 'newReservations': sum(len(p['ordinaryDates']) for p in proofs), 'priorScheduled': 2196, 'campuses': summary, 'operatingReviewScope': '10 explicitly reviewed full retained education plans; 956-row remainder is triage only', 'currentCalendar': {'ordinaryStart': '2026-09-01', 'ordinaryEnd': '2026-12-07', 'ownMidtermPeriod': ['2026-10-20', '2026-10-26'], 'makeup': ['2026-12-08', '2026-12-14'], 'final': ['2026-12-15', '2026-12-21'], 'guideEvidence': 'catalogs/hufs-guide2-h2-latest.txt:45-78', 'schoolMidtermDoesNotMeanWholeSchoolNoLecture': True}, 'preliminaryRootWeekConversionCorrection': 'M012061 preliminary 10/21 omission is now independently justified by current own Oct20–26 midterm period plus individual week8 exam; no generic week-number date conversion used.'})
print(json.dumps(summary, ensure_ascii=False))
print('new', len(proofs), sum(len(p['ordinaryDates']) for p in proofs))
