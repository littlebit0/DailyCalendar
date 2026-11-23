"""서경대 2026-2 시간표 자산의 2026-11-23 재조사 결과를 반영한다.

- EGM025-01 영어회화: 최신 공개 시간표 책(20260826v2)의 '화 22'를 같은 슬롯 규칙
  (21~26교시 75분 수업+15분=90분)으로 예약한다. 시간 3·학점 3과 맞지 않지만
  공개 자료 중 더 최신 값이 없다(서경포탈 강좌 조회는 로그인 필요).
- OCU 학점교류 강좌: OCU 공개 수업계획서에도 주간 요일·시각이 없어 시간 미정 유지.
- 요일·교시가 비어 있는 강좌: 공개 경로를 다 찾아도 시각이 없어 보류 유지.

여러 번 실행해도 결과가 같다. 실행 후 `python3 tool/timetable/minify_assets.py`.

    python3 tool/timetable/patch_sku_2026_2_recheck.py
"""
import json
from pathlib import Path

MAIN = Path('assets/timetable/sku-main-2026-2.json')
UNKNOWN = Path('assets/timetable/sku-unknown-2026-2.json')
TAG = '2026-11-23 재확인'

EGM_NOTE = (
    f' / {TAG}: 공개 최신 자료인 2026-2학기 강의시간표_20260826v2.hwp'
    '(https://www.skuniv.ac.kr/notice/65877 첨부, 공지 본문 "서경포탈시스템의 내용이 최종 수정본임"; '
    '서경포탈 강좌 조회는 로그인 필요)의 요일ㆍ교시 "화 22"를 같은 슬롯 규칙(21~26교시 75분 수업+15분)으로 '
    '10:30~12:00에 예약합니다. 원문 시간 3·학점 3과 맞지 않는 점은 원문 그대로 둡니다.'
)
OCU_NOTE = (
    f' / {TAG}: OCU 공개 수업계획서(https://cons.ocu.ac.kr/crs/creCrsPopWin/Form/lectPlanForm, '
    '2026.2학기)에는 주간 요일·교시가 없고 시험 응시 기간만 있어 시간 미정을 유지합니다.'
)
BLANK_NOTE = (
    f' / {TAG}: 시간표 책 20260826v2·학교 공지 검색·학칙 학사내규에 요일·교시가 없고 '
    '서경포탈 강좌 조회(https://sportal.skuniv.ac.kr/sportal/education/ucs/lecture-classes)는 '
    '로그인 필요(401)라 보류합니다.'
)


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def save(path, data):
    path.write_text(
        json.dumps(data, ensure_ascii=False, separators=(',', ':')),
        encoding='utf-8',
    )


def add_note(course, note):
    if TAG not in course['remarks']:
        course['remarks'] += note


def patch_main(data):
    courses = data['courses']
    egm = next(c for c in courses if c['courseCode'] == 'EGM025' and c['section'] == '01')
    assert egm['sourceSchedule'] == '화 22', egm['sourceSchedule']
    # 같은 화요일 21~26교시 강좌의 예약 날짜(중간시험·공휴일 제외)를 그대로 쓴다.
    template = next(
        c for c in courses
        if c['sourceSchedule'] == '화 21.22' and c['scheduleStatus'] == 'scheduled'
    )
    dates = [m['date'] for m in template['schedules']]
    assert template['schedules'][0]['startMinute'] == 540  # 21교시 09:00
    egm['scheduleStatus'] = 'scheduled'
    egm['schedules'] = [
        {'weekday': 2, 'startMinute': 630, 'endMinute': 720,
         'classroom': egm['sourceClassroom'], 'date': d}
        for d in dates
    ]
    egm['metadata']['heldReason'] = ''
    egm['remarks'] = egm['remarks'].split(' / 예약 보류:')[0]
    add_note(egm, EGM_NOTE)


def patch_unknown(data):
    for c in data['courses']:
        if c['scheduleStatus'] == 'unscheduled' and c['sourceClassroom'].replace('\n', '') == '원격강좌':
            add_note(c, OCU_NOTE)
        elif c['scheduleStatus'] == 'unrecognized' and not c['sourceSchedule'].strip():
            add_note(c, BLANK_NOTE)


def main():
    main_data = load(MAIN)
    patch_main(main_data)
    save(MAIN, main_data)
    unknown = load(UNKNOWN)
    patch_unknown(unknown)
    save(UNKNOWN, unknown)


if __name__ == '__main__':
    main()
