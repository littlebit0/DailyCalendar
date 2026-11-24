#!/usr/bin/env python3
"""Confirm Suwon rows held for periods 9+ or operating mode (2026-11-23 decision).

The dataset's regular rows use the school's own table: period 1 at 09:30,
60-minute slots (50-minute class, 학칙시행세칙 제11조②). Night periods (제11조②:
45-minute class) plus a 15-minute break are also 60-minute slots, continuing
right after the last day period (period 8), so period 9 starts 17:30 (2026-11-23
decision). Saturday uses the same table. A slot that would end after midnight
(period 15 = 23:30-24:30) stays held, as do rows without a time.
Closed (폐강) rows follow the same rule as every other row.

    python3 tool/timetable/confirm_held_suwon.py
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import held_confirm_common as common  # noqa: E402

PATH = 'assets/timetable/suwon-unknown-2026-2.json'
DAYS = '월화수목금토일'
OLD_NOTE = common.DECISION + '. 9교시 이후·토요일은 1~8교시와 같은 60분 슬롯으로 이어 계산.'
NOTE = common.DECISION + '. 야간 교시(시행세칙 제11조② 45분 수업)는 쉬는 시간 15분을 더한 60분 슬롯으로 8교시 다음부터 이어 계산, 토요일도 같은 표.'
KEEP_UNTIL = '사용자 수업방식 선택 유지.'


def meetings(text):
    groups = list(re.finditer(r'([^(),]*)\(([^()]*)\)', text))
    if not groups or re.sub(r'[^(),]*\([^()]*\)', '', text).strip(','):
        raise ValueError(text)
    found = []
    for group in groups:
        room = group[1].strip()
        for token in group[2].split():
            match = re.fullmatch(r'([월화수목금토일])([\d,]+)', token)
            if not match:
                raise ValueError(text)
            for period in map(int, match[2].split(',')):
                start = 510 + period * 60
                if not 1 <= period or start + 60 > 1440:
                    raise ValueError(text)
                found.append({'weekday': DAYS.index(match[1]) + 1, 'startMinute': start,
                              'endMinute': start + 60, 'classroom': room})
    return common.merge(found)


def main():
    dataset = common.load(PATH)
    dates = common.weekday_dates(dataset)
    held = []
    for course in dataset['courses']:
        if course.get('scheduleStatus') != 'unrecognized':
            continue
        try:
            found = meetings(course['sourceSchedule'])
        except ValueError:
            held.append(course['sourceSchedule'])
            continue
        # The importer appends its hold tags after this sentence.
        tail = (course.get('remarks') or '').partition(KEEP_UNTIL)[2]
        common.confirm(course, common.expand(found, dates), NOTE, (tail,) if tail.strip() else ())
    for course in dataset['courses']:
        # Earlier runs wrote the previous basis sentence; keep one current note.
        if OLD_NOTE in (course.get('remarks') or ''):
            course['remarks'] = course['remarks'].replace(OLD_NOTE, NOTE)
    common.save(PATH, dataset, '수원대 9교시 이후·토요일·운영 방식 보류 강좌를 같은 60분 슬롯으로 확정(2026-11-23 사용자 결정)')
    print('held', held)


if __name__ == '__main__':
    main()
