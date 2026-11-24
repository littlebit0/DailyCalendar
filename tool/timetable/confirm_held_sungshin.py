#!/usr/bin/env python3
"""Confirm Sungshin rows held for blended/recorded/intensive types (2026-11-23 decision).

Uses the importer's official clock (시행세칙 제11조, 1교시 09:00, 60-minute
slots) and the 2026-2 수강신청 안내 p5 teaching dates (weeks 1-15). Intensive
courses whose official remark names their weeks (e.g. '8~15주차') get only
those weeks; the rest get all 15 weeks. When the remark also states an explicit
start date ('(10/26~12월 중순)'), the course starts on that date and keeps at
most that many sessions per weekday (8~15주차 = 8) from the official teaching
dates. No date outside the guide's 15-week table is added: after 10/26 the table
has 8 Mondays but only 7 Tuesdays/Wednesdays (last 12/08, 12/09).

    python3 tool/timetable/confirm_held_sungshin.py
"""
import datetime as dt
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import held_confirm_common as common  # noqa: E402
import import_sungshin as source  # noqa: E402

PATHS = ['assets/timetable/sungshin-sujeong-2026-2.json', 'assets/timetable/sungshin-unjung-2026-2.json']
NOTE = common.DECISION + '. 수업일은 2026-2 수강신청 안내 5쪽 주차별 수업일 기준.'


def weeks_for(remark):
    match = re.search(r'(\d+)\s*[~-]\s*(\d+)주차', remark)
    return (int(match[1]), int(match[2])) if match else (1, 15)


def main():
    for path in PATHS:
        dataset = common.load(path)
        for course in dataset['courses']:
            if course.get('scheduleStatus') != 'unrecognized':
                continue
            parsed = source.blocks(course['sourceSchedule'])
            if parsed is None:
                raise ValueError(course['sourceId'])
            department = course['departments'][0]
            remark = course['departmentRemarks'][department]
            first, last = weeks_for(remark) if '집중' in remark else (1, 15)
            dates = {w: v[first - 1:last] for w, v in source.TEACHING_DATES.items()}
            start = re.search(r'\((\d{1,2})/(\d{1,2})~', remark) if '집중' in remark else None
            if start:
                begin = dt.date(2026, int(start[1]), int(start[2]))
                dates = {w: [d for d in v if d >= begin][:last - first + 1]
                         for w, v in source.TEACHING_DATES.items()}
            rooms = source.rooms_for(course.get('sourceClassroom') or '', len(parsed))
            meetings = source.meetings_for(parsed, rooms, dates)
            pieces = [p for p in remark.split(' · ') if not p.startswith('시각 보류: ')]
            if any(m['date'] in ('2026-10-16', '2026-10-17') for m in meetings) and source.ADMISSION_NOTE not in pieces:
                pieces.append(source.ADMISSION_NOTE)
            course['departmentRemarks'][department] = ' · '.join(pieces)
            common.confirm(course, meetings, NOTE)
        common.save(path, dataset, '성신여대 블렌디드·원격·집중이수 보류 강좌를 공식 교시·수업일로 확정(2026-11-23 사용자 결정)')


if __name__ == '__main__':
    main()
