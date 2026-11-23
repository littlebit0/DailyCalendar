#!/usr/bin/env python3
"""Confirm Seoultech rows held for operating exceptions or A/B halves (2026-11-23 decision).

Official clock: 학사관리 규정 [별표 1], period 0 at 08:00, every period on the
hour, 50-minute class + 10-minute break saved as a 60-minute slot (same as the
dataset's regular rows). A/B half periods are the first/second 30 minutes of
that slot (e.g. 4 ~ 5A = 12:00-13:30). Rooms follow the importer rule: one
distinct room is kept, several rooms in unknown order leave the room blank.

    python3 tool/timetable/confirm_held_seoultech.py
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import held_confirm_common as common  # noqa: E402

PATH = 'assets/timetable/seoultech-main-2026-2.json'
DAYS = '월화수목금토일'
NOTE = common.DECISION + '. A/B 반교시는 60분 교시 슬롯의 앞·뒤 30분으로 계산.'
DROP = ('공개 수업계획에 별도 시험·보강·녹화·혼합 수업 등 운영 예외가 있어 전체 날짜와 시각을 확정할 수 없습니다.',
        '현재 공식 자료에서 A/B 교시의 시각을 확인할 수 없습니다.')


def point(token, end):
    match = re.fullmatch(r'(\d+)([AB]?)', token.strip())
    if not match or not 0 <= int(match[1]) <= 14:
        raise ValueError(token)
    start = 480 + int(match[1]) * 60
    half = match[2]
    if end:
        return start + (30 if half == 'A' else 60)
    return start + (30 if half == 'B' else 0)


def single_room(text, groups):
    """The one room the aggregate repeats, else '' (several rooms, order unknown)."""
    text = text.strip()
    for k in range(8, 0, -1):
        size, rest = divmod(len(text) - (k - 1), k)
        room = text[:size]
        if rest == 0 and size > 0 and ' '.join([room] * k) == text:
            # Room names end in '-<number>'; two such endings are two rooms.
            return room if len(re.findall(r'-\S+(?:\s|$)', room)) == 1 else ''
    return ''


def meetings(text, rooms_text):
    groups = list(re.finditer(r'([월화수목금토일])\(([^()]*)\)', text))
    if not groups or not re.fullmatch(r'[\s,]*', re.sub(r'[월화수목금토일]\([^()]*\)', '', text)):
        raise ValueError(text)
    room = single_room(rooms_text, len(groups))
    found = []
    for group in groups:
        weekday = DAYS.index(group[1]) + 1
        for block in group[2].split(','):
            first, _, last = block.partition('~')
            found.append({'weekday': weekday, 'startMinute': point(first, False),
                          'endMinute': point(last or first, True), 'classroom': room})
    return common.merge(found)


def main():
    dataset = common.load(PATH)
    for course in dataset['courses']:
        if course.get('scheduleStatus') != 'unrecognized':
            continue
        common.confirm(course, meetings(course['sourceSchedule'], course.get('sourceClassroom') or ''), NOTE, DROP)
    common.save(PATH, dataset, '서울과기대 운영 예외·A/B 반교시 보류 강좌를 공식 60분 교시 슬롯으로 확정(2026-11-23 사용자 결정)')


if __name__ == '__main__':
    main()
