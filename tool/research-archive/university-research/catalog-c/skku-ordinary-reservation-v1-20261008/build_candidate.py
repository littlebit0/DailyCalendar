"""Current fixed physical reservation blocks; known individual exceptions retained."""
import collections
import copy
import datetime
import hashlib
import json
import re
from pathlib import Path

P = Path(__file__).resolve().parent
G = P.parent.parent / 'catalog-g'
ROOT = P.parents[3]
CAMPUSES = ['humanities', 'naturalScience', 'icampus']
HELD = {
    'PSY3018-01': 'Current Monday native clock conflicts with explicit Tuesday offline method.',
    'GELT041-43': 'Explicitly no regular face-to-face meetings; initial advising date unpublished.',
    'GEDM001-02': 'Synchronous online OR offline alternative not individually mapped.',
    'GEDM001-C6': 'Synchronous online OR offline alternative not individually mapped.',
    'GEDI003-02': 'Native Friday vs method explicitly naming Wednesday first class; no resolution guessed.',
}
OMIT_WEEKS = {
    'GEDI012-01': [16],  # explicit15-week end, final alternatively15/16
    'GEDM001-A2': [16], 'GEDM001-A4': [16],  # take-home final
    'GEDT017-73': [8, 9],  # town-watching venue/clock not mapped
    'GEDW002-05': [8, 11, 12, 16], 'GEDW002-06': [8, 11, 12, 16],
    'GEDW001-47': [12, 13, 16], 'GEDW001-48': [12, 13, 16],
    'GEDW002-47': [8, 13, 14, 15, 16], 'GEDW002-48': [8, 13, 14, 15, 16],
}
REVIEW_NOTES = {
    'GEDI012-01': 'Explicit Thursday physical instruction; holiday/event online alternative conditional; explicit15-week end and uncertain final16 held.',
    'GEDM001-30': '100% offline is default; COVID switch is explicitly conditional, not current remote operation.',
    'GEDM001-E8': '100% offline is default; COVID switch is explicitly conditional, not current remote operation.',
    'GEDM001-A2': 'Explicit2h offline discussion after1h recorded preparation; take-home final16 excluded.',
    'GEDM001-A4': 'Explicit2h offline discussion after1h recorded preparation; take-home final16 excluded.',
    'GEDT017-73': 'Physical activities after online preparation; town-watching8/9 venue and individual clocks held, other printed weekly blocks retained.',
    'GEDW002-05': 'Concentration refers to attention, not intensive delivery; consultation weeks8/11/12 and conditional supplement16 held.',
    'GEDW002-06': 'Concentration refers to attention, not intensive delivery; consultation weeks8/11/12 and conditional supplement16 held.',
    'GEDW001-47': 'Face-to-face default; online makeup conditional; individual mixed consultation12/13 and take-home final16 held.',
    'GEDW001-48': 'Face-to-face default; online makeup conditional; individual mixed consultation12/13 and take-home final16 held.',
    'GEDW002-47': 'School requires offline instruction; individual consultation8/13/14/15 and conditional makeup16 held.',
    'GEDW002-48': 'School requires offline instruction; individual consultation8/13/14/15 and conditional makeup16 held.',
    'GEDI003-05': 'Chuseok and Hangulday remote/closure already excluded by own calendar; other literature lectures retained.',
    'GEDW013-04': 'Explicit9/28 and10/5 recorded substitutions already excluded by own closure calendar.',
    'GEDI029-03': '현장 means instructor classroom activity in the same passage, not announced external placement; no outside assignments.',
    'GEDI009-01': 'Explicit classroom face-to-face default; recorded makeup applies IF class cancelled, no actual cancellation announced.',
    'GEDI005-04': 'Recorded preparation then 현장 instruction; conditional class-size method adjustment, no actual changed clock.',
    'EEE2014-43': 'Weekly face-to-face quiz/problem session after recorded theory; conference cancellation/makeup only conditional, no fabricated weekend slots.',
    'BIO3004-41': 'Explicit offline default; recorded makeup is separate, not replacing regular meetings.',
}


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    body = (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()
    if path.exists() and path.read_bytes() != body:
        raise ValueError('Existing research artifact differs: ' + str(path))
    path.write_bytes(body)
    return hashlib.sha256(body).hexdigest()


def clock(value):
    return sorted((m[1], int(m[2])*60+int(m[3]), int(m[4])*60+int(m[5])) for m in
                  re.finditer(r'([월화수목금토일])(?:\[[^\]]+\])?(\d{2}):(\d{2})-(\d{2}):(\d{2})', value))


def main():
    targets = read(P / 'inline-physical-shortlist.json')['shortlist']
    current = read(P / 'current-inline-public-recheck.json')
    assert not current['stopped'] and len(current['records']) == 48
    live = {r['offeringCode']: r for r in current['records']}
    rules = read(G / 'skku-current-term-closure-rule-evidence.json')
    write(P / 'own-current-term-closure-evidence.json', rules)
    source = read(G / 'skku-final-current-educational-source.json')
    write(P / 'baseline-public-native-whole.json', source)
    native = {r['HAKSU_NO_BUNBAN']: r for r in source['records'] if r['JUKYONGHAKWI_GB'] != '05'}
    assert len(native) == 2782
    start = datetime.date.fromisoformat(rules['term']['startDate'])
    end = datetime.date.fromisoformat(rules['term']['endDate'])
    closed = set(rules['nationalHolidayDates']['dates']) | set(rules['closureRule']['schoolSpecificClosures'])
    proofs = {}
    decisions = []
    for target in targets:
        r = target['evidence']
        key = r['offeringCode']
        c = target['course']
        now = live[key]
        assert now['detail'] and r['detail']
        detail = now['detail'][0]
        fields = list(now['detail'][0])
        assert {f: str(r['detail'][0].get(f, '')) if f != 'privacySuppressedLineCount' else r['detail'][0].get(f, 0) for f in fields} == detail
        week_fields = list(now['weekly'][0]) if now['weekly'] else []
        old_weeks = [{f: str(w.get(f, '')) if f != 'privacySuppressedLineCount' else w.get(f, 0) for f in week_fields} for w in r['weekly']]
        canonical = lambda values: sorted(json.dumps(v, ensure_ascii=False, sort_keys=True) for v in values)
        assert canonical(old_weeks) == canonical(now['weekly']), key
        assert all(not x.get('privacySuppressedLineCount') for x in now['detail'] + now['weekly'])
        assert detail['GAESUL_YEAR'] == '2026' and detail['GAESUL_TERM'] == '20'
        assert detail['HAKSU_NO'] == c['courseCode'] and detail['BUNBAN'] == c['section']
        assert detail['PER_NAME'] == c['professor'] and r['currentDetailIdentityConfirmed']
        assert clock(c['sourceSchedule']) == clock(detail['SUUP_YOIL_GYOSI'])
        assert native[key]['GYOSI_NAME'] == c['sourceSchedule'] and native[key]['PER_NAME'] == c['professor']
        assert native[key]['HAKBU_JIBJUNG_GB'] == 'N' and native[key]['SUUP_TYPE_CD'] in ['31', '33']
        # Earlier general-course serializer represented four absent values as null.
        assert {k: v or '' for k, v in r['sourceRow'].items()} == {k: v or '' for k, v in native[key].items()}
        if key in HELD:
            decisions.append({'offeringCode': key, 'decision': 'held', 'basis': HELD[key]})
            continue
        raw = c['rawMeetingFrameForReviewOnly']
        assert raw and all(f['classroom'] and f['classroom'] in detail['SUUP_GANGUISIL'] for f in raw)
        omitted = OMIT_WEEKS.get(key, [])
        note = REVIEW_NOTES.get(key, 'Current independently reviewed method/assessment/weekly fields: recorded preparation or classroom material does not replace published physical instruction. Exact native offline block only; no individual-date absence whole hold.')
        proof = {'sourceId': c['sourceId'], 'offeringCode': key, 'nativeSourceRow': native[key],
                 'currentEducationalDetail': detail, 'currentWeeklyEducation': now['weekly'],
                 'nativeFrames': raw, 'excludedWeeks': omitted, 'sourceSemanticBasis': note,
                 'originalOperatingSignalsReviewed': True, 'publicEducationChangedFields': [],
                 'actualAttendanceConfirmed': False}
        proofs[c['sourceId']] = proof
        decisions.append({'offeringCode': key, 'decision': 'physicalPublishedReservation', 'basis': note, 'excludedWeeks': omitted})
    assert len(proofs) == 43
    totals = collections.Counter()
    audit = {'researchOnly': True, 'completionClaim': False, 'actualAttendanceConfirmed': False,
             'knownMixedOrIndividualExceptionsNotGuessed': True, 'priorScheduledPreserved': 1335,
             'reviewedCurrentPublicOfferingCount': 48, 'newOfferingCount': 43,
             'excludedReservationDates': sorted(closed), 'decisions': decisions,
             'proofs': list(proofs.values()), 'campuses': []}
    for campus in CAMPUSES:
        asset = ROOT / 'assets' / 'timetable' / f'skku-{campus}-2026-2.json'
        baseline = read(asset)
        write(P / f'baseline-skku-{campus}.json', baseline)
        after = copy.deepcopy(baseline)
        for c in after['courses']:
            proof = proofs.get(c['sourceId'])
            if not proof:
                continue
            assert not c['schedules']
            meetings = []
            day = start
            while day <= end:
                week = (day-start).days // 7 + 1
                if day.isoweekday() != 7 and day.isoformat() not in closed and week not in proof['excludedWeeks']:
                    meetings.extend({**f, 'date': day.isoformat()} for f in proof['nativeFrames'] if f['weekday'] == day.isoweekday())
                day += datetime.timedelta(days=1)
            assert meetings
            c.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[], researchOnly=False,
                     period={'startDate': start.isoformat(), 'endDate': end.isoformat()},
                     reservationEvidence=proof, scheduleEvidenceKind='plannedRegularTimetable',
                     actualAttendanceConfirmed=False, commonClosureDatesApplied=True)
            note = '공개 시간표의 실제 오프라인 칸에 학교 학기·휴업일을 적용한 예약 범위입니다. 사전 녹화·온라인 학습은 일정으로 만들지 않았으며 실제 휴·보강 및 시험 운영은 공지를 확인하세요.'
            if proof['excludedWeeks']:
                note += ' 개별·온라인·운영 미확인 주차 제외: ' + ', '.join(map(str, proof['excludedWeeks'])) + '주.'
            c['departmentRemarks'] = {k: v.replace('수업 운영 미확인: 실제 날짜·수업 방식·휴강·보강을 확인 중입니다.', note) for k, v in c['departmentRemarks'].items()}
        for old, new in zip(baseline['courses'], after['courses']):
            assert old['sourceId'] == new['sourceId']
            if old['sourceId'] not in proofs:
                assert old == new
        path = P / f'skku-{campus}-2026-2.ordinary-reservation-research-v1-20261008.json'
        digest = write(path, after)
        count = sum(bool(c.get('schedules')) for c in after['courses'])
        dates = sum(len(c.get('schedules', [])) for c in after['courses'])
        totals.update(whole=len(after['courses']), scheduled=count, meetings=dates)
        audit['campuses'].append({'campus': campus, 'candidateFile': path.name, 'candidateSHA256': digest,
                                 'baselineFile': f'baseline-skku-{campus}.json',
                                 'whole': len(after['courses']), 'scheduled': count, 'meetings': dates})
    audit['totals'] = dict(totals)
    assert totals['whole'] == 2782 and totals['scheduled'] == 1378
    write(P / 'candidate-audit.json', audit)
    print(audit['totals'])


if __name__ == '__main__':
    main()
