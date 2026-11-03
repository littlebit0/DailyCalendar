"""Preserve frozen v1; add independently reviewed current attached reservations."""
import collections
import copy
import datetime
import hashlib
import json
import re
from pathlib import Path

P = Path(__file__).resolve().parent
V1 = P.parent / 'skku-ordinary-reservation-v3-20261008'


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
    latest = read(P / 'current-flipped-educational-operation-recheck.json')
    assert len(latest['records']) == 215 and not latest['stopped']
    current = {r['offeringCode']: r for r in latest['records']}
    chosen = {r['offeringCode']: r for r in review['records'] if r['decision'] in ['eligible', 'eligiblePartialIntroduction']}
    assert review['reviewedCount'] == 215 and review['remainingCount'] == 0
    assert all(r['actualFullOperatingTableReviewed'] for r in chosen.values())
    classification = {r['offeringCode']: r for r in read(P / 'flipped-remaining-pool-classification.json')['records']}
    enrichment = {}
    for file in ['incomplete-educational-enrichment-recheck.json','incomplete-educational-enrichment-v2-recheck.json']:
        content = read(P / file)
        assert not content['stopped']
        for r in content['records']:
            enrichment[r['offeringCode']] = r
    rules = read(V1 / 'own-current-term-closure-evidence.json')
    save(P / 'own-current-term-closure-evidence.json', rules)
    native_source = read(V1 / 'baseline-public-native-whole.json')
    save(P / 'baseline-public-native-whole.json', native_source)
    native = {r['HAKSU_NO_BUNBAN']: r for r in native_source['records'] if r['JUKYONGHAKWI_GB'] != '05'}
    start = datetime.date.fromisoformat(rules['term']['startDate'])
    end = datetime.date.fromisoformat(rules['term']['endDate'])
    closed = set(rules['nationalHolidayDates']['dates']) | set(rules['closureRule']['schoolSpecificClosures'])
    audit = {'researchOnly': True, 'completionClaim': False, 'actualAttendanceConfirmed': False,
             'priorScheduledPreserved': 1534, 'allPriorV3CoursesDeepPreserved': True,
             'currentObservedAttachmentsReviewed': 215, 'newOfferingCount': len(chosen),
             'wholeCatalogRequeried': False, 'excludedReservationDates': sorted(closed),
             'held': [{'offeringCode': r['offeringCode'], 'basis': r['basis']} for r in review['records'] if r['decision'] not in ['eligible', 'eligiblePartialIntroduction']],
             'proofs': [], 'campuses': []}
    totals = collections.Counter()
    for campus in ['humanities', 'naturalScience', 'icampus']:
        filename = f'skku-{campus}-2026-2.ordinary-reservation-research-v3-20261008.json'
        baseline = read(V1 / filename)
        save(P / f'baseline-skku-{campus}-v3.json', baseline)
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
            assert native[key]['HAKBU_JIBJUNG_GB'] == 'N' and native[key]['SUUP_TYPE_CD'] == '33'
            fields = ['GAESUL_YEAR', 'GAESUL_TERM', 'HAKSU_NO', 'BUNBAN', 'PER_NAME', 'SUUP_YOIL_GYOSI', 'SUUP_GANGUISIL', 'CLASS_INFO', 'BIGO']
            old = classification[key]['originalPublicEducationalEvidence']['detail'][0]
            assert all(old.get(f) == detail.get(f) for f in fields)
            assert all(not d.get('privacySuppressedLineCount') for d in evidence['detail'] + evidence['weekly'])
            assert evidence['attachments'] and all(not a.get('privacySuppressedLineCount') and not a.get('contextTruncated') and not a.get('protectionPresent') for a in evidence['attachments'])
            frames = c['rawMeetingFrameForReviewOnly']
            assert frames and all(f['classroom'] and f['classroom'] in detail['SUUP_GANGUISIL'] for f in frames)
            proof = {'sourceId': c['sourceId'], 'offeringCode': key,
                     'nativeSourceRow': native[key], 'currentPublicEducationalEvidence': evidence,
                     'sourceSemanticBasis': chosen[key]['basis'], 'nativeFrames': frames,
                     'excludedWeeks': chosen[key].get('excludedWeeks', []), 'excludedExactDates': chosen[key].get('excludedExactDates', []),
                     'includedWeeksOnly': chosen[key].get('includedWeeksOnly'),
                     'includedWeekdayWeeks': chosen[key].get('includedWeekdayWeeks'),
                     'explicitOwnClosureOperatingDates': chosen[key].get('explicitOwnClosureOperatingDates', []),
                     'fullOperatingTableIndependentReview': {'actualFullOperatingTableReviewed': chosen[key]['actualFullOperatingTableReviewed'], 'basis': chosen[key]['basis'], 'independentAdditionalNormalPublicRecheck': enrichment.get(key)},
                     'currentIdentityTeacherClockRoomChangedFields': [],
                     'attachmentsRecheckedRatherThanAssumedFromCache': True,
                     'actualAttendanceConfirmed': False}
            meetings = []
            day = start
            while day <= end:
                week = (day-start).days // 7 + 1
                if day.isoweekday() != 7 and (day.isoformat() not in closed or day.isoformat() in proof['explicitOwnClosureOperatingDates']) and week not in proof['excludedWeeks'] and day.isoformat() not in proof['excludedExactDates']:
                    meetings.extend({**f, 'date': day.isoformat()} for f in frames if f['weekday'] == day.isoweekday()
                                    and (proof['includedWeeksOnly'] is None or week in proof['includedWeeksOnly'])
                                    and (proof['includedWeekdayWeeks'] is None or week in proof['includedWeekdayWeeks'].get('월화수목금토일'[day.weekday()], [])))
                day += datetime.timedelta(days=1)
            assert meetings
            proof['plannedMeetingCount'] = len(meetings)
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[], researchOnly=False,
                     period={'startDate': start.isoformat(), 'endDate': end.isoformat()},
                     reservationEvidenceV4=proof, scheduleEvidenceKind='plannedRegularTimetable',
                     actualAttendanceConfirmed=False, commonClosureDatesApplied=True)
            note = '현재 공개 계획서와 시간표의 정규 강의실 예약 범위입니다. 실제 휴·보강 및 시험 운영은 공지를 확인하세요. 비동기·개별·보강 시각은 추정하지 않았습니다.'
            if proof['excludedWeeks'] or proof['excludedExactDates']:
                note += ' 원문 운영 예외 제외 주차/날짜: ' + ', '.join(map(str, proof['excludedWeeks'] + proof['excludedExactDates'])) + '.'
            if proof['includedWeeksOnly'] is not None:
                note += ' 원문이 대면수업을 지정한 주차만 예약했습니다: ' + ', '.join(map(str, proof['includedWeeksOnly'])) + '.'
            if proof['includedWeekdayWeeks'] is not None:
                note += ' 월요일 대면수업과 13~15주 수요일 대면 발표만 예약했습니다. 다른 수요일 온라인 수업은 제외했습니다.'
            if proof['explicitOwnClosureOperatingDates']:
                note += ' 이 강좌는 원문에 9월 28일 수업 예정이 명시되어 해당 날짜를 포함했습니다.'
            if key in ['GEDW003-53','GEDW003-54']:
                note += ' 원문은 10월 6일을 추석연휴로 표기했습니다. 날짜를 고치지 않고 그날 명시된 온라인 수업만 제외했습니다.'
            if key == 'GEDW014-07':
                note += ' 원문의 14주 날짜 12월 30일은 학기 밖이며 요일도 다릅니다. 11월 30일로 고치지 않고 14주 예약을 보류했습니다.'
            if key in ['GELT075-02','GELT075-04']:
                note += ' 개별 소그룹 면담이 시작하는 11주부터 빈 운영칸이 이어지는 14주까지는 실제 배정을 확인하지 못해 예약에서 제외했습니다.'
            c['departmentRemarks'] = {k: v.replace('수업 운영 미확인: 실제 날짜·수업 방식·휴강·보강을 확인 중입니다.', note) for k, v in c['departmentRemarks'].items()}
            audit['proofs'].append(proof)
        for old, new in zip(baseline['courses'], after['courses']):
            assert old['sourceId'] == new['sourceId']
            if old['courseCode'] + '-' + old['section'] not in chosen:
                assert old == new
        output = P / f'skku-{campus}-2026-2.ordinary-reservation-research-v4-20261008.json'
        digest = save(output, after)
        count = sum(bool(c['schedules']) for c in after['courses'])
        dates = sum(len(c['schedules']) for c in after['courses'])
        totals.update(whole=len(after['courses']), scheduled=count, meetings=dates)
        audit['campuses'].append({'campus': campus, 'candidateFile': output.name,
                                 'candidateSHA256': digest, 'baselineFile': f'baseline-skku-{campus}-v3.json',
                                 'whole': len(after['courses']), 'scheduled': count, 'meetings': dates})
    assert len(audit['proofs']) == len(chosen) and totals['whole'] == 2782 and totals['scheduled'] == 1534+len(chosen)
    audit['totals'] = dict(totals)
    save(P / 'candidate-audit.json', audit)
    print(audit['totals'])


if __name__ == '__main__':
    main()
