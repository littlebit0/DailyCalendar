"""Expand reviewed ordinary prefixes; source-only no network or SDK."""
import copy
import hashlib
import json
import re
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PRIOR = ROOT.parent
V4 = PRIOR / 'hufs-partial-operation-v4-20261009'
load = lambda path: json.loads(path.read_text())
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()

def save(name, value):
    (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

# Explicit current own table, not a borrowed duration or inferred start.
CLOCK = {1: (540, 590), 2: (600, 650), 3: (660, 710), 4: (720, 770), 5: (780, 830), 6: (840, 890), 7: (900, 950), 8: (960, 1010), 9: (1020, 1070), 10: (1080, 1130), 11: (1140, 1190), 12: (1200, 1250)}

def parse_literal(literal):
    rules = []
    offset = 0
    for match in re.finditer(r'([^()]+)\(([^()]+)\)', literal):
        assert not literal[offset:match.start()].strip()
        offset = match.end()
        for day in re.finditer(r'([월화수목금토일])\s+([0-9 ]+)', match[1]):
            periods = [int(x) for x in day[2].split()]
            assert periods == list(range(min(periods), max(periods) + 1))
            assert all(p in CLOCK for p in periods)
            rules.append({'weekday': '월화수목금토일'.index(day[1]) + 1, 'startMinute': CLOCK[periods[0]][0], 'endMinute': CLOCK[periods[-1]][1], 'classroom': match[2]})
    assert not literal[offset:].strip() and rules, literal
    return rules

review = load(ROOT / 'late186-full-operation-decisions.json')
eligible = {d['sourceId']: d for d in review['decisions'] if d['decision'] == 'ordinaryReservationEligible'}
holidays = set(load(PRIOR / 'hufs-registration-checkpoint-review-3-audit.json')['normalDerivedDateProof']['excludedSchoolClosureDates'])
new_proofs = []
campuses = {}
for campus in ['seoul', 'global']:
    base_path = V4 / f'hufs-{campus}-2026-2.partial-operation-v4-research.json'
    baseline = load(base_path)
    candidate = copy.deepcopy(baseline)
    for c in candidate['courses']:
        if c['sourceId'] not in eligible:
            continue
        d = eligible[c['sourceId']]
        assert not c['schedules']
        assert c['period'] == {'startDate': '2026-09-01', 'endDate': '2026-12-07'}
        rules = parse_literal(c['sourceSchedule'])
        assert rules == d['nativeCourse']['schedules'], c['sourceId']
        dates = []
        excluded = []
        cursor = date(2026, 9, 1)
        while cursor <= date(2026, 12, 7):
            for rule in rules:
                if cursor.isoweekday() != rule['weekday']:
                    continue
                midterm_day = d['individualMidtermExclude'] and date(2026, 10, 20) <= cursor <= date(2026, 10, 26) and (d['midtermExceptionWeekdays'] is None or rule['weekday'] in d['midtermExceptionWeekdays'])
                if cursor.isoformat() in holidays or midterm_day:
                    excluded.append({'date': cursor.isoformat(), 'weekday': rule['weekday'], 'reason': 'ownHoliday' if cursor.isoformat() in holidays else 'individualExamInOwnMidtermPeriod'})
                else:
                    dates.append({**rule, 'date': cursor.isoformat()})
            cursor += timedelta(days=1)
        c['schedules'] = dates
        c['scheduleStatus'] = 'scheduled'
        note = '공개 정규 주간 예약 계획; 실제 개별 출석일 미확정. 보강·기말시험·별도 배정은 추가하지 않음'
        if d['individualMidtermExclude']:
            note += '; 개별 중간평가와 자체 10/20–26 시험기간을 결합해 해당 정규 예약 제외(시험 시각 생성 아님)'
        if d['midtermExceptionWeekdays'] is not None:
            note += '; 원문 수요일 중간시험만 제외, 화요일 정규 예약 유지'
        c['departmentRemarks'] = {dep: value.removesuffix(' · 공개 운영 일정 확인 중: 자동 시간 생성 보류') + ' · ' + note for dep, value in c['departmentRemarks'].items()}
        new_proofs.append({'sourceId': c['sourceId'], 'poolIndex': d['poolIndex'], 'baselinePath': str(base_path), 'baselineSHA256': sha(base_path), 'sourcePlanPath': d['planPath'], 'sourcePlanSHA256': d['planSha256'], 'nativeHeader': c['sourceSchedule'], 'sourceNativeRules': rules, 'derivedReservations': dates, 'excludedNativeSlots': excluded, 'operationDecision': d, 'derivedDates': True, 'individuallyPrintedDates': False, 'attendanceConfirmed': False, 'examEventsGenerated': False, 'freshRequeryPerformed': False, 'sourceSnapshotDate': '2026-10-08'})
    name = f'hufs-{campus}-2026-2.late-operation-v5-research.json'
    save(name, candidate)
    campuses[campus] = {'candidateFile': name, 'SHA256': sha(ROOT / name), 'whole': len(candidate['courses']), 'scheduled': sum(bool(c['schedules']) for c in candidate['courses']), 'reservations': sum(len(c['schedules']) for c in candidate['courses'])}
save('added174-source-proofs.json', new_proofs)
save('candidate-audit.json', {'sourceOnly': True, 'completionClaim': False, 'modelValidated': False, 'sdkUsed': False, 'productEdited': False, 'nativeWhole': 3372, 'priorV4Scheduled': 2206, 'priorV4Reservations': 32048, 'baseReview3Scheduled': 2196, 'baseReview3Reservations': 31920, 'newAfterV4': len(new_proofs), 'newAfterV4Reservations': sum(len(p['derivedReservations']) for p in new_proofs), 'cumulativeNewAfterReview3': 184, 'cumulativeNewReservationsAfterReview3': 128 + sum(len(p['derivedReservations']) for p in new_proofs), 'reviewPoolCounts': review['counts'], 'campuses': campuses, 'held': [d for d in review['decisions'] if d['decision'] != 'ordinaryReservationEligible'], 'outsideReviewedPoolUnchanged': True, 'userDeliveryModeForced': False, 'noWeekNumberDateInference': True})
print(json.dumps(campuses, ensure_ascii=False))
print('new174 reservations', sum(len(p['derivedReservations']) for p in new_proofs))
