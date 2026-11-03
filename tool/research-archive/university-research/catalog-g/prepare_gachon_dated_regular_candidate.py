"""Immutable date projection of audited regular plans; preserves individually blocked operation."""
import collections
import copy
import datetime as dt
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
NOTE = '학교 공시의 정규 수업 계획입니다. 시험·보강·변경 사항은 학교 공지를 확인하세요.'
SPECIAL_AI_HOLD = {'AIB04001', 'AIB06001'}
SPECIAL_WEEKEND = {'AIB02001', 'AIB03001', 'AIB05001'}


def load(name):
    return json.loads((ROOT / name).read_text())


def prepare():
    old_manifest = load('gachon-audited-20261008-sha-manifest.json')
    reports = load('gachon-full-operating-report-audit.json')
    by_key = {(r['campus'], r['sourceRow']['HAKSU_NO']): r for r in reports['reports']}
    audit = {'wholeCount': 3809, 'sourceManifest': 'gachon-audited-20261008-sha-manifest.json',
             'excludedNationalHolidays': sorted(HOLIDAYS),
             'nationalHolidaySource': 'https://www.kasa.go.kr/bbs/BBSMSTR_000000000010/view.do?nttId=B000000001860Pe2zT3',
             'schoolHolidayRule': 'gachon-current-undergraduate-holiday-rule-20261008.json:Article13',
             'currentCalendarProof': 'gachon-current-fall-calendar-boundary-proof-20261008.json',
             'ordinaryPeriod': {'startDate': '2026-09-01', 'endDate': '2026-12-14'},
             'conditionalOrdinaryMakeupExcluded': ['2026-12-15', '2026-12-21'],
             'exceptionPolicy': 'Current individualP4 teaching bounds11/24–12/21 are a separate explicitly published course plan, not invented ordinary makeup. Current AI weekend instruction explicitly includes Sunday; generic Sunday holiday does not delete those published special classes. No special exam/makeup events generated.',
             'newHeldOfferings': sorted(SPECIAL_AI_HOLD),
             'newHoldSource': 'https://aibootcamp.gachon.ac.kr/16/?idx=172992280&bmode=view',
             'newHoldReason': 'Current2026-2 program notice specifies AI301 and external classrooms for robotics/on-device; actual day/location allocation unresolved.',
             'datasets': [], 'courses': [], 'productionRegistered': False, 'completionClaim': False}
    for entry in old_manifest['datasets']:
        source = Path(entry['path'])
        assert hashlib.sha256(source.read_bytes()).hexdigest() == entry['sha256']
        original = json.loads(source.read_text())
        data = copy.deepcopy(original)
        for c in data['courses']:
            offering = c['courseCode'] + c['section']
            campus_code = '20' if c['campus'] == 'global' else '21'
            report = by_key[(campus_code, offering)]
            old_meetings = copy.deepcopy(c['schedules'])
            original_remarks = copy.deepcopy(c['departmentRemarks'])
            if c['scheduleStatus'] == 'scheduled':
                if offering in SPECIAL_AI_HOLD:
                    c.update(scheduleStatus='unrecognized', schedules=[])
                    reason = audit['newHoldReason']
                    c['unresolvedReasons'].append(reason)
                    c['departmentRemarks'] = {d: '\n'.join(x for x in [r, '수업 운영 미확인: AI관과 외부 현장 강의실에서 진행하는 각 날짜의 실제 시각·장소는 추가 확인이 필요합니다.'] if x)
                                              for d, r in original_remarks.items()}
                else:
                    assert report['educationalParserVersion'] == 6
                    assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
                    begin = dt.date.fromisoformat(c['period']['startDate'])
                    end = dt.date.fromisoformat(c['period']['endDate'])
                    if offering != '12718001':
                        weeks = report['weeklyRows']
                        assert all(w['activityPresent'] for w in weeks)
                        assert [w['week'] for w in weeks] == list(range(weeks[0]['week'], weeks[0]['week'] + len(weeks)))
                        bounds = [(dt.date(2026, *map(int, w['startMonthDay'].split('/'))), dt.date(2026, *map(int, w['endMonthDay'].split('/')))) for w in weeks]
                        assert bounds[0][0] <= begin <= bounds[0][1] and end == bounds[-1][1]
                        assert all((last - first).days == 6 for first, last in bounds)
                        assert all(bounds[i][0] == bounds[i - 1][1] + dt.timedelta(days=1) for i in range(1, len(bounds)))
                    meetings = []
                    removed = 0
                    for old in old_meetings:
                        if old.get('date'):
                            dates = [dt.date.fromisoformat(old['date'])]
                        else:
                            dates = []
                            day = begin
                            while day <= end:
                                if day.isoweekday() == old['weekday']:
                                    dates.append(day)
                                day += dt.timedelta(days=1)
                        for day in dates:
                            assert begin <= day <= end and day.isoweekday() == old['weekday']
                            if day.isoformat() in HOLIDAYS or (day.isoweekday() == 7 and offering not in SPECIAL_WEEKEND):
                                removed += 1
                                continue
                            meetings.append({**old, 'date': day.isoformat()})
                    assert meetings
                    assert len({(m['date'], m['startMinute'], m['endMinute'], m['classroom'], m.get('deliveryMode')) for m in meetings}) == len(meetings)
                    c['schedules'] = meetings
                    c['departmentRemarks'] = {d: '\n'.join(x for x in [r, NOTE] if x) for d, r in original_remarks.items()}
                    c['sourceDepartmentRemarks'] = original_remarks
                    c['sourceEducation'] = {'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                        'sourceDeliveryMode': 'publishedPerMeetingOverride' if any(m.get('deliveryMode') for m in meetings) else 'unknownUserSelectionRequired',
                        'sourceCampusExplicit': campus_code, 'dateProof': 'Current individual report weekly date bounds with actual operating semantics; original course-specific period preserved.',
                        'holidayProof': audit['schoolHolidayRule'], 'calendarProof': audit['currentCalendarProof'],
                        'specialSundayInstruction': offering in SPECIAL_WEEKEND,
                        'limits': 'Published planned class, not attendance confirmation. No invented final-exam or makeup time. User selects default delivery mode; exact published per-date overrides remain.'}
                    audit['courses'].append({'sourceId': c['sourceId'], 'offering': offering, 'campus': c['campus'],
                        'period': c['period'], 'publishedWeeklyRows': len(report['weeklyRows']), 'originalClockBlocks': old_meetings,
                        'datedMeetingCount': len(meetings), 'excludedClosedDayClockBlocks': removed})
            if c['scheduleStatus'] != 'scheduled':
                assert not c['schedules']
        name = f"gachon-{data['campus']}-2026-2.published-regular-1969-candidate-20261008.json"
        path = ROOT / name
        assert not path.exists(), 'Immutable output exists'
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        audit['datasets'].append({'file': name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'campus': data['campus'], 'courseCount': len(data['courses']),
            'counts': dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    audit['scheduledCount'] = len(audit['courses'])
    audit['datedMeetingCount'] = sum(c['datedMeetingCount'] for c in audit['courses'])
    assert audit['scheduledCount'] == 1969
    out = ROOT / 'gachon-dated-regular-1969-candidate-audit-20261008.json'
    assert not out.exists()
    out.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in audit.items() if k != 'courses'}, ensure_ascii=False))


if __name__ == '__main__':
    prepare()
