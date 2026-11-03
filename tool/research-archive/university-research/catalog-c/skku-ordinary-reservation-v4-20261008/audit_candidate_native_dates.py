"""Independent source-native clock/room and frozen prior union check."""
import datetime
import json
import re
from pathlib import Path

P = Path(__file__).resolve().parent

def read(path):
    return json.loads(path.read_text())

def main():
    audit = read(P / 'candidate-audit.json')
    whole, prior = [], []
    for campus in audit['campuses']:
        whole += read(P / campus['candidateFile'])['courses']
        prior += read(P / campus['baselineFile'])['courses']
    old = {r['sourceId']: r for r in prior}
    proofs = {r['sourceId']: r for r in audit['proofs']}
    native = {r['HAKSU_NO_BUNBAN']: r for r in read(P / 'baseline-public-native-whole.json')['records'] if r['JUKYONGHAKWI_GB'] != '05'}
    assert set(native) == {r['courseCode'] + '-' + r['section'] for r in whole}
    assert len(old) == len(whole) == 2782
    prior_supported = 0
    for row in whole:
        baseline = old[row['sourceId']]
        if baseline['schedules']:
            assert baseline == row
            prior_supported += 1
        if row['sourceId'] not in proofs:
            assert baseline == row
    assert prior_supported == 1534
    reviews = {r['offeringCode']: r for r in read(P / 'attached-semantic-review-checkpoint.json')['records']}
    operation_proofs = []
    for row in whole:
        if row['sourceId'] not in proofs:
            continue
        proof = proofs[row['sourceId']]
        code = row['courseCode'] + '-' + row['section']
        frames = []
        for match in re.finditer(r'([월화수목금토일])(\d\d):(\d\d)-(\d\d):(\d\d)【([^】]+)】', native[code]['GYOSI_NAME']):
            frames.append((match[1], int(match[2])*60+int(match[3]), int(match[4])*60+int(match[5]), match[6]))
        dates = []
        for value in row['schedules']:
            date = datetime.date.fromisoformat(value['date'])
            week = (date-datetime.date(2026, 8, 31)).days//7+1
            assert datetime.date(2026, 8, 31) <= date <= datetime.date(2026, 12, 18)
            assert date.isoweekday() == value['weekday']
            assert ('월화수목금토일'[date.weekday()], value['startMinute'], value['endMinute'], value['classroom']) in frames
            assert week not in proof['excludedWeeks'] and value['date'] not in proof['excludedExactDates']
            assert value['date'] not in audit['excludedReservationDates'] or value['date'] in proof['explicitOwnClosureOperatingDates']
            if proof['includedWeeksOnly'] is not None:
                assert week in proof['includedWeeksOnly']
            if proof['includedWeekdayWeeks'] is not None:
                assert week in proof['includedWeekdayWeeks'].get('월화수목금토일'[date.weekday()], [])
            dates.append((value['date'], value['startMinute'], value['endMinute'], value['classroom']))
        assert len(dates) == len(set(dates))
        operation_proofs.append({'offeringCode': code, 'sourceId': row['sourceId'], 'publishedNativeClockRoomVerifiedMeetingCount': len(dates), 'sourceSemanticReviewBasis': reviews[code]['basis'], 'dateRangeMin': min(v[0] for v in dates), 'dateRangeMax': max(v[0] for v in dates), 'everyExplicitExceptionExcluded': True})
    output = {'researchOnly': True, 'completionClaim': False, 'oldScheduledDeepEqual': prior_supported, 'sourceWholeNativeIdentityUnion': 2782, 'newAuditedOfferings': len(operation_proofs), 'sourceProofs': operation_proofs}
    (P / 'independent-candidate-native-date-audit.json').write_text(json.dumps(output, ensure_ascii=False, indent=2)+'\n')
    print({'whole': 2782, 'oldDeepEqual': prior_supported, 'newNativeDateAudited': len(operation_proofs)})

if __name__ == '__main__':
    main()
