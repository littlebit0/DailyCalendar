"""Preserve frozen v1; add independently reviewed current attached reservations."""
import collections
import copy
import datetime
import hashlib
import json
import re
from pathlib import Path

P = Path(__file__).resolve().parent
V1 = P.parent / 'skku-ordinary-reservation-v1-20261008'
OMITTED = {
    'BUS2027-01': [8, 9, 16],
    'HFS2005-01': [8],
    'HIS3024-01': [16],
    'CHI2027-01': [15], 'CHI2028-01': [15],
    'DKL3017-02': [8, 15, 16],
    'CNT2014-01': [8, 15, 16],
    'CNT2018-01': [16],
}
EXTRA_DATES = {'DKL3017-02': ['2026-09-23', '2026-10-21']}


def read(path):
    return json.loads(path.read_text())


def save(path, value):
    body = (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()
    if path.exists() and path.read_bytes() != body:
        raise ValueError('Existing candidate differs; choose a new revision.')
    path.write_bytes(body)
    return hashlib.sha256(body).hexdigest()


def clock(value):
    return sorted((m[1], int(m[2])*60+int(m[3]), int(m[4])*60+int(m[5])) for m in
                  re.finditer(r'([월화수목금토일])(?:\[[^\]]+\])?(\d{2}):(\d{2})-(\d{2}):(\d{2})', value))


def main():
    review = read(P / 'attached-semantic-review-checkpoint.json')
    latest = read(P / 'current-attached-public-recheck.json')
    assert len(latest['records']) == 31 and not latest['stopped']
    current = {r['offeringCode']: r for r in latest['records']}
    chosen = {r['offeringCode']: r for r in review['records'] if r['decision'] != 'held'}
    assert len(chosen) == 25
    rules = read(V1 / 'own-current-term-closure-evidence.json')
    save(P / 'own-current-term-closure-evidence.json', rules)
    native_source = read(V1 / 'baseline-public-native-whole.json')
    save(P / 'baseline-public-native-whole.json', native_source)
    native = {r['HAKSU_NO_BUNBAN']: r for r in native_source['records'] if r['JUKYONGHAKWI_GB'] != '05'}
    start = datetime.date.fromisoformat(rules['term']['startDate'])
    end = datetime.date.fromisoformat(rules['term']['endDate'])
    closed = set(rules['nationalHolidayDates']['dates']) | set(rules['closureRule']['schoolSpecificClosures'])
    audit = {'researchOnly': True, 'completionClaim': False, 'actualAttendanceConfirmed': False,
             'priorScheduledPreserved': 1378, 'allPriorV1CoursesDeepPreserved': True,
             'currentObservedAttachmentsReviewed': 31, 'newOfferingCount': 25,
             'wholeCatalogRequeried': False, 'excludedReservationDates': sorted(closed),
             'held': [{'offeringCode': r['offeringCode'], 'basis': r['basis']} for r in review['records'] if r['decision'] == 'held'],
             'proofs': [], 'campuses': []}
    totals = collections.Counter()
    for campus in ['humanities', 'naturalScience', 'icampus']:
        filename = f'skku-{campus}-2026-2.ordinary-reservation-research-v1-20261008.json'
        baseline = read(V1 / filename)
        save(P / f'baseline-skku-{campus}-v1.json', baseline)
        after = copy.deepcopy(baseline)
        for c in after['courses']:
            key = c['courseCode'] + '-' + c['section']
            if key not in chosen:
                continue
            assert not c['schedules']
            evidence = current[key]
            assert evidence['currentDetailIdentityConfirmed'] and len(evidence['detail']) == 1
            detail = evidence['detail'][0]
            assert detail['GAESUL_YEAR'] == '2026' and detail['GAESUL_TERM'] == '20'
            assert detail['HAKSU_NO'] == c['courseCode'] and detail['BUNBAN'] == c['section']
            assert detail['PER_NAME'] == c['professor']
            assert c['sourceSchedule'] == native[key]['GYOSI_NAME']
            assert clock(c['sourceSchedule']) == clock(detail['SUUP_YOIL_GYOSI'])
            assert native[key]['HAKBU_JIBJUNG_GB'] == 'N' and native[key]['SUUP_TYPE_CD'] == '31'
            fields = ['GAESUL_YEAR', 'GAESUL_TERM', 'HAKSU_NO', 'BUNBAN', 'PER_NAME', 'SUUP_YOIL_GYOSI', 'SUUP_GANGUISIL', 'CLASS_INFO', 'BIGO']
            old = chosen[key]['originalPublicEducationalEvidence']['detail'][0]
            assert all(old.get(f) == detail.get(f) for f in fields)
            assert all(not d.get('privacySuppressedLineCount') for d in evidence['detail'] + evidence['weekly'])
            assert evidence['attachments'] and all(not a.get('privacySuppressedLineCount') and not a.get('contextLimitReached') and not a.get('contextTruncated') and not a.get('protectionPresent') for a in evidence['attachments'])
            frames = c['rawMeetingFrameForReviewOnly']
            assert frames and all(f['classroom'] and f['classroom'] in detail['SUUP_GANGUISIL'] for f in frames)
            proof = {'sourceId': c['sourceId'], 'offeringCode': key,
                     'nativeSourceRow': native[key], 'currentPublicEducationalEvidence': evidence,
                     'sourceSemanticBasis': chosen[key]['basis'], 'nativeFrames': frames,
                     'excludedWeeks': OMITTED.get(key, []), 'excludedExactDates': EXTRA_DATES.get(key, []),
                     'currentIdentityTeacherClockRoomChangedFields': [],
                     'attachmentsRecheckedRatherThanAssumedFromCache': True,
                     'actualAttendanceConfirmed': False}
            meetings = []
            day = start
            while day <= end:
                week = (day-start).days // 7 + 1
                if day.isoweekday() != 7 and day.isoformat() not in closed and week not in proof['excludedWeeks'] and day.isoformat() not in proof['excludedExactDates']:
                    meetings.extend({**f, 'date': day.isoformat()} for f in frames if f['weekday'] == day.isoweekday())
                day += datetime.timedelta(days=1)
            assert meetings
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[], researchOnly=False,
                     period={'startDate': start.isoformat(), 'endDate': end.isoformat()},
                     reservationEvidenceV2=proof, scheduleEvidenceKind='plannedRegularTimetable',
                     actualAttendanceConfirmed=False, commonClosureDatesApplied=True)
            note = '현재 공개 계획서와 시간표의 정규 강의실 예약 범위입니다. 실제 휴·보강 및 시험 운영은 공지를 확인하세요. 비동기·개별·보강 시각은 추정하지 않았습니다.'
            if proof['excludedWeeks'] or proof['excludedExactDates']:
                note += ' 원문 운영 예외 제외 주차/날짜: ' + ', '.join(map(str, proof['excludedWeeks'] + proof['excludedExactDates'])) + '.'
            c['departmentRemarks'] = {k: v.replace('수업 운영 미확인: 실제 날짜·수업 방식·휴강·보강을 확인 중입니다.', note) for k, v in c['departmentRemarks'].items()}
            audit['proofs'].append(proof)
        for old, new in zip(baseline['courses'], after['courses']):
            assert old['sourceId'] == new['sourceId']
            if old['courseCode'] + '-' + old['section'] not in chosen:
                assert old == new
        output = P / f'skku-{campus}-2026-2.ordinary-reservation-research-v2-20261008.json'
        digest = save(output, after)
        count = sum(bool(c['schedules']) for c in after['courses'])
        dates = sum(len(c['schedules']) for c in after['courses'])
        totals.update(whole=len(after['courses']), scheduled=count, meetings=dates)
        audit['campuses'].append({'campus': campus, 'candidateFile': output.name,
                                 'candidateSHA256': digest, 'baselineFile': f'baseline-skku-{campus}-v1.json',
                                 'whole': len(after['courses']), 'scheduled': count, 'meetings': dates})
    assert len(audit['proofs']) == 25 and totals['whole'] == 2782 and totals['scheduled'] == 1403
    audit['totals'] = dict(totals)
    save(P / 'candidate-audit.json', audit)
    print(audit['totals'])


if __name__ == '__main__':
    main()
