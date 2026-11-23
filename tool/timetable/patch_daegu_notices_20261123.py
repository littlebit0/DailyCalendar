"""대구대 미확정 강좌를 2026-11-23 조회한 공식 공지로 확정하거나 시간 미정으로 둔다.

- 2204 진로·취업설계(공공안전법): 법학부 공지 225363(2026-09-03, 225151보다 최신)
  "공공안전법학전공 진로취업설계 변경 수업시간: 금요일 10:00~10:50 / 9월 첫째 주 휴강".
  강의실은 공지가 바꾸지 않았으므로 원문 강의실을 쓰고 9/4는 뺀다.
- 3903·4005·4036·4137 가족법(미선임, 월 공공인재-230): 원문 요일·시각으로 확정한다.
  강의실 변경 공지 225362는 분반 없이 "법학부 가족법 → 공공인재1-1314"만 적어
  이 분반(원문 공공인재-230)에 해당하는지 알 수 없으므로 원문 강의실을 유지한다.
- HUSS 포용사회융합학부 21강좌: DU-HUSS 공지 224170(첨부 교과목 목록)이 HUSS LMS(lms.hussis.ac.kr) 온라인
  수강과 시험 일정만 공개하고 주간 수업 시각이 없으므로 시간 미정(unscheduled)으로 둔다.
- 2951 디지털트윈응용설계: 원문 강의시간·강의실 줄 짝대로 월=공학6관-6508, 수=공학6관-6201(PR 1162 리뷰).

    python3 tool/timetable/patch_daegu_notices_20261123.py   # 다시 실행해도 결과 동일
"""
import datetime as dt
import json
from pathlib import Path

ASSET = Path('assets/timetable/daegu-main-2026-2.json')
# candidate-audit.json excludedHolidays (기존 확정 강좌와 같은 제외일)
HOLIDAYS = {'2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', '2026-10-09'}
FIRST, LAST = dt.date(2026, 9, 1), dt.date(2026, 12, 7)
CONFIRMED = '공식 시각 확정(2026-11-23)'
# 224170 첨부 「2026학년 2학기 HUSS교과목 강좌 시험 일정」에 수강번호가 적힌 HUSS 사업단장 강좌.
# 3869·3871·3872·3874는 이 목록에 없어 미확정으로 남긴다.
HUSS_EXAM_LIST = (
    '3868', '3870', '3873', '3875', '3876', '3877', '3878', '3879', '3880', '3881', '3882',
    '3884', '3887', '3888', '3889', '3891', '3892', '3893', '3894', '3895', '3896',
)

NOTICE_2204 = (
    ' / 2026-11-23 확인: 법학부 공지 「진로취업설계 교과목 수업시간 변경 및 휴강 안내」'
    '(https://law.daegu.ac.kr/article/table_01/detail/225363, 2026-09-03 등록)의 '
    '"공공안전법학전공 진로취업설계 변경 수업시간: 금요일 10:00~10:50", "9월 첫째 주 휴강"을 '
    '적용했습니다(공지 시각 금(10:00-10:50), 휴강 2026-09-04). 앞선 공지 225151(2026-08-31)의 '
    '"금 10:00~10:45"보다 최신 공지를 따랐고, 강의실은 공지가 바꾸지 않아 원문 강의실을 썼습니다. '
    '225151은 담당교수를 이상학으로 안내합니다.'
)
NOTICE_FAMILY = (
    ' / 2026-11-23 확인: 원문 요일·시각으로 확정했습니다. 법학부 공지 「2026-2 강의실 변경 안내」'
    '(https://law.daegu.ac.kr/article/table_01/detail/225362)는 분반 없이 "법학부 가족법 공공인재1-1314"만 '
    '적어 이 분반(원문 강의실 공공인재-230)에 해당하는지 확인되지 않으므로 원문 강의실을 유지했습니다.'
)
NOTICE_HUSS = (
    ' / 2026-11-23 확인: DU-HUSS 공지 「2026년 2학기 HUSS교과목 오프라인 시험 일정」'
    '(https://du-huss.daegu.ac.kr/article/HUSS_004/detail/224170)는 HUSS 교과목을 HUSS LMS'
    '(lms.hussis.ac.kr)에서 온라인으로 수강하고 시험 일정만 안내하며 주간 수업 시각을 공개하지 않으므로 '
    '요일·시각이 없는 강좌로 둡니다.'
)


def drop_hold(text):
    """'일정 미생성: <영문 사유> ' 문구를 확정 표시로 바꾼다."""
    i = text.find('일정 미생성:')
    if i < 0:
        return text
    j = text.find('수강 대상:', i)
    return text[:i] + CONFIRMED + ' ' + text[j:]


def dates(weekday, skip=()):
    day = FIRST
    while day <= LAST:
        key = day.isoformat()
        if day.isoweekday() == weekday and key not in HOLIDAYS and key not in skip:
            yield key
        day += dt.timedelta(days=1)


def schedule(blocks, skip=()):
    rows = [
        {'weekday': w, 'startMinute': s, 'endMinute': e, 'classroom': room, 'date': d}
        for w, s, e, room in blocks
        for d in dates(w, skip)
    ]
    return sorted(rows, key=lambda r: (r['date'], r['startMinute']))


def confirm(course, blocks, note, skip=()):
    if course['scheduleStatus'] == 'scheduled':
        return False
    course['remarks'] = drop_hold(course['remarks']) + note
    course['departmentRemarks'] = {
        k: drop_hold(v) + note for k, v in course['departmentRemarks'].items()
    }
    course['schedules'] = schedule(blocks, skip)
    course['scheduleStatus'] = 'scheduled'
    return True


def main():
    asset = json.loads(ASSET.read_text(encoding='utf-8'))
    by_code = {c['courseCode']: c for c in asset['courses']}
    changed = []

    c = by_code['2204']
    assert c['courseName'] == '진로·취업설계' and c['sourceClassroom'] == '공공인재-131'
    if confirm(c, [(5, 600, 650, c['sourceClassroom'])], NOTICE_2204, skip={'2026-09-04'}):
        changed.append('2204')

    for code in ('3903', '4005', '4036', '4137'):
        c = by_code[code]
        assert c['courseName'] == '가족법' and c['professor'] == '미선임'
        assert c['sourceSchedule'] == '월(10:30-11:45) 월(12:00-13:15)'
        snap = c['sourceSnapshotSchedules']
        blocks = [(s['weekday'], s['startMinute'], s['endMinute'], s['classroom']) for s in snap]
        assert blocks == [(1, 630, 705, '공공인재-230'), (1, 720, 795, '공공인재-230')]
        if confirm(c, blocks, NOTICE_FAMILY):
            changed.append(code)

    huss = [by_code[code] for code in HUSS_EXAM_LIST if by_code[code]['scheduleStatus'] == 'unrecognized']
    for c in huss:
        assert ''.join(c['professor'].split()) == 'HUSS사업단장'
        assert c['sourceSchedule'] == '' and c['sourceClassroom'] == '' and not c['schedules']
        c['scheduleStatus'] = 'unscheduled'
        c['remarks'] += NOTICE_HUSS
        c['departmentRemarks'] = {k: v + NOTICE_HUSS for k, v in c['departmentRemarks'].items()}
        changed.append(c['courseCode'])

    # 2951 디지털트윈응용설계: 원문 강의시간·강의실 칸이 줄마다 짝지어 있다(273쪽 '월(12:00-13:15)'↔'공학6관-6508',
    # '수(12:00-13:15)'↔'공학6관-6201'; 같은 수업의 4306도 이 짝으로 확정됨). 두 강의실을 한 문자열로 붙이지 않는다.
    c = by_code['2951']
    cells = [r['sourceCells'] for r in c['publicEducationRows'] if r['sourcePage'] == 273][0]
    times, rooms = cells[8].split('\n'), cells[9].split('\n')
    assert times == ['월(12:00-13:15)', '수(12:00-13:15)'] and rooms == ['공학6관-6508', '공학6관-6201']
    per_day = {'월화수목금토일'.index(t[0]) + 1: r for t, r in zip(times, rooms)}
    for m in c['schedules']:
        room = per_day[m['weekday']]
        if m['classroom'] != room:
            m['classroom'] = room
            if '2951' not in changed:
                changed.append('2951')

    ASSET.write_text(json.dumps(asset, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'changed': len(changed), 'huss': len(huss), 'codes': changed}, ensure_ascii=False))


if __name__ == '__main__':
    main()
