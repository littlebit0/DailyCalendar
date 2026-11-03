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

RULES = {
    '13107002': {'omitWeeks': [13], 'heldDates': [], 'reason': 'A/B GIS Studio는 수업 시간 내 실습과 분석·피드백 방식입니다. 13주 논술고사 보강은 실제 대체 날짜·시각 미확정으로 그 주 원예약만 보류합니다. 60~120분은 수업 내 활동 구성으로 새 시작·종료 시각을 만들지 않습니다.'},
    '13453001': {'omitWeeks': [], 'heldDates': ['2026-11-30'], 'reason': '일반 이론·토론 수업이며 11/30 월요일만 Zoom 비대면으로 원교실 예약을 보류합니다. 같은 주 수요일은 원교시·교실 예약을 보존합니다.'},
    '13964001': {'omitWeeks': [], 'heldDates': ['2026-12-01'], 'reason': '이론과 Excel 실습의 정규 수업입니다. 12/1 비대면만 원교실 예약을 보류하며 16주 보강 가능 문구에서 별도 보강 날짜를 발명하지 않습니다.'},
    '13979002': {'omitWeeks': [], 'heldDates': ['2026-09-24'], 'reason': '이론 및 코딩 실습은 정규 수업입니다. 9/24 실시간 비대면 예정은 정규 교실 예약에서 제외하고 확정 실시간 일정을 생성하지 않습니다.'},
    '14200002': {'omitWeeks': [14], 'heldDates': [], 'reason': '강의 전반부/후반부는 한 수업의 내용 구성이며 집중 기간이 아닙니다. 실제 14주 비대면 수업만 원교실 예약에서 제외합니다.'},
    '14475001': {'omitWeeks': [], 'heldDates': ['2026-11-30', '2026-12-01'], 'reason': '강의실 수업이라고 직접 명시합니다. 11/30·12/1 보강 예정 원예약만 제외합니다. 원문 가천관-515,가천관-514를 한 원문 장소 목록으로 보존하고 요일별 배정이나 대표 강의실을 임의 선택하지 않습니다.'},
}

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
        path = CATALOG / f'gachon-{campus}-2026-2.published-regular-3191-studio-private-plan-next-20261008.json'
        old = read(path)
        actual = read(Path('assets/timetable') / f'gachon-{campus}-2026-2.json')
        assert old['courses'] == actual['courses'], 'actual product must match immutable course baseline'
        data = copy.deepcopy(old)
        audit['sourceFiles'][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
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
            assert campus == 'global' and course['scheduleStatus'] == 'unrecognized'
            base = bases[key]
            assert current_period_weekly_rows_consistent(report, base)
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
    assert old_scheduled == 3191 and old_meetings == 54092
    assert untouched == 3803 and len(audit['heldCensus']) == 614 and len(audit['promoted']) == 6
    audit.update(nativeCount=3809, preservedCourseObjects=3803, previousScheduledCount=3191,
        previousDatedMeetingCount=54092, newScheduledCount=6,
        newDatedMeetingCount=sum(c['datedMeetingCount'] for c in audit['promoted']))
    audit['verification']['pythonIndependentPreservation'] = True
    save('source-operating-audit.json', audit)
    print(json.dumps({k: audit[k] for k in ['nativeCount', 'newScheduledCount', 'newDatedMeetingCount', 'datasets']}, ensure_ascii=False))

if __name__ == '__main__':
    main()
