# coding: utf-8
"""Source-only current operating review; no network, SDK, or product mutation."""
import collections
import copy
import datetime as dt
import hashlib
import json
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent
CATALOG = ROOT.parent
sys.path.insert(0, str(CATALOG))
from validate_gachon_individual_weekly_period import current_period_weekly_rows_consistent
from prepare_gachon_dated_regular_candidate import HOLIDAYS, NOTE

def read(path):
    return json.loads(path.read_text())

def save(name, value):
    (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

RULES = read(ROOT / 'individual-source-review-rules.json')

def main():
    report_path = CATALOG / 'gachon-full-operating-report-audit.json'
    base_path = CATALOG / 'gachon-full-normalized-source-candidates.json'
    reports = {(r['campus'], r['sourceRow']['HAKSU_NO']): r for r in read(report_path)['reports']}
    bases = {(r['campusSourceCode'], r['officialOfferingCode']): r for r in read(base_path)['courses']}
    audit = {'researchOnly': True, 'completionClaim': False, 'productionRegistered': False,
             'sourceSnapshotDate': '2026-10-08', 'newWholeAcquisition': False,
             'verification': {'pythonIndependentPreservation': False, 'actualModelThreeModeDrive': False},
             'promoted': [], 'heldCensus': [], 'sourceFiles': {}, 'datasets': []}
    for path in [report_path, base_path, CATALOG / 'gachon-current-scope-clock-term-manifest.json',
                 CATALOG / 'gachon-current-undergraduate-holiday-rule-20261008.json',
                 CATALOG / 'gachon-current-fall-calendar-boundary-proof-20261008.json']:
        audit['sourceFiles'][str(path.relative_to(CATALOG))] = hashlib.sha256(path.read_bytes()).hexdigest()
    untouched = 0
    old_scheduled = old_meetings = 0
    for campus, code in [('global', '20'), ('medical', '21')]:
        path = CATALOG / 'conditional-operating-followup-v2-20261009' / f'gachon-{campus}-2026-2.json'
        old = read(path)
        data = copy.deepcopy(old)
        audit['sourceFiles'][str(path.relative_to(CATALOG))] = hashlib.sha256(path.read_bytes()).hexdigest()
        for before, course in zip(old['courses'], data['courses']):
            old_scheduled += bool(before['schedules'])
            old_meetings += len(before['schedules'])
            offering = course['courseCode'] + course['section']
            key = code, offering
            report = reports.get(key)
            if course['scheduleStatus'] == 'unrecognized':
                audit['heldCensus'].append({'sourceId': course['sourceId'], 'title': course['courseName'],
                    'sourceSchedule': course['sourceSchedule'], 'sourceClassroom': course['sourceClassroom'],
                    'reasons': course['unresolvedReasons'], 'teachingMethod': report.get('teachingMethodEducationalExcerpt', '') if report else '',
                    'selectedForThisReview': offering in RULES})
            if offering not in RULES:
                assert before == course
                untouched += 1
                continue
            assert course['scheduleStatus'] == 'unrecognized'
            base = bases[key]
            assert current_period_weekly_rows_consistent(report, base)
            assert not any(w['operatingContextTruncationDetected'] or w['operatingContextLimitReached'] for w in report['weeklyRows'])
            assert len(report['weeklyRows']) == 15 and not report['potentialDifferentTermStatement']
            assert all(report['report'][k] for k in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport'])
            assert report['sourceRow']['CYBER_YN'] is None
            assert report['sourceRow']['PROFNM'] == course['professor']
            assert report['sourceRow']['TIME'] == base['rawSchedule']
            assert report['sourceRow']['LOC_NM'] == course['sourceClassroom']
            rule = RULES[offering]
            blocks = copy.deepcopy(base['schedules'])
            if not blocks:
                assert offering == '13107002'
                slots = base['publishedActualSlots']
                assert [s['period'] for s in slots] == [5, 6, 7, 8]
                assert all(s['weekday'] == 1 for s in slots)
                blocks = [{'weekday': 1, 'startMinute': slots[0]['startMinute'],
                    'endMinute': slots[-1]['endMinute'], 'classroom': base['rawRoom']}]
            omitted = [w for w in report['weeklyRows'] if w['week'] in rule['omitWeeks']]
            ranges = [(dt.date(2026, *map(int, w['startMonthDay'].split('/'))),
                       dt.date(2026, *map(int, w['endMonthDay'].split('/')))) for w in omitted]
            meetings = []
            day = dt.date.fromisoformat(course['period']['startDate'])
            end = dt.date.fromisoformat(course['period']['endDate'])
            while day <= end:
                for block in blocks:
                    if day.isoweekday() != block['weekday']:
                        continue
                    if day.isoformat() in HOLIDAYS | set(rule['heldDates']) or any(a <= day <= z for a, z in ranges):
                        continue
                    meeting = {k: v for k, v in block.items() if k not in ['firstPeriod', 'lastPeriod']}
                    meeting['date'] = day.isoformat()
                    meetings.append(meeting)
                day += dt.timedelta(days=1)
            assert meetings
            prior = copy.deepcopy(course['departmentRemarks'])
            note = NOTE + '\n' + rule['reason'] + '\n실제 출석·최신 변경·시험/보강 운영은 미확인입니다. 원문 교시 예약 범위이며 실제 수업량을 확정하지 않습니다.\n현재 원문 수업 방식: ' + report['teachingMethodEducationalExcerpt']
            course.update(scheduleStatus='scheduled', schedules=meetings, unresolvedReasons=[],
                sourceDepartmentRemarks=prior,
                departmentRemarks={k: '\n'.join(line for line in v.split('\n') if line != '수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.') + '\n' + note for k, v in prior.items()},
                sourceEducation={'projection': 'publishedRegularTimetable', 'actualAttendanceConfirmed': False,
                    'sourceDeliveryMode': 'unknownUserSelectionRequired', 'sourceSnapshotDate': '2026-10-08',
                    'heldDateScope': rule['heldDates'], 'omittedUnresolvedOperatingWeeks': omitted,
                    'individualWeeklyOperationConfirmed': False, 'currentTeachingMethodReviewed': True})
            audit['promoted'].append({'sourceId': course['sourceId'], 'offering': offering,
                'previousReasons': before['unresolvedReasons'], 'rule': rule, 'report': report,
                'originalClockBlocks': blocks, 'datedMeetingCount': len(meetings), 'period': course['period']})
        save(f'gachon-{campus}-2026-2.json', data)
        audit['datasets'].append({'file': f'gachon-{campus}-2026-2.json', 'courseCount': len(data['courses']),
            'scheduledCount': sum(bool(c['schedules']) for c in data['courses']),
            'datedMeetingCount': sum(len(c['schedules']) for c in data['courses'])})
    assert old_scheduled == 3225 and old_meetings == 54866
    assert untouched == 3809 - len(RULES) and len(audit['heldCensus']) == 580 and len(audit['promoted']) == len(RULES)
    audit.update(nativeCount=3809, preservedCourseObjects=3803, previousScheduledCount=3225,
        previousDatedMeetingCount=54866, newScheduledCount=len(RULES),
        newDatedMeetingCount=sum(c['datedMeetingCount'] for c in audit['promoted']))
    audit['verification']['pythonIndependentPreservation'] = True
    save('source-operating-audit.json', audit)
    print(json.dumps({k: audit[k] for k in ['nativeCount', 'newScheduledCount', 'newDatedMeetingCount', 'datasets']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
