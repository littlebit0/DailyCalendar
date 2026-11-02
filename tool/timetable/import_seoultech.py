#!/usr/bin/env python3
"""Validate Seoultech's published regular clock; never infer half periods.

Basis: 서울과학기술대학교 학사관리 규정(2026. 7. 27. 개정, 2026학년도 2학기부터
시행) 제4조·[별표 1] 교시별 수업시간표 — 50분 수업은 제0교시 08:00~08:50부터
제14교시 22:00~22:50까지 매 정시 시작(교시 사이 10분 휴식은 표의 시각에 포함).
75분 수업은 별표가 제4~10교시에 10:00~11:15 등 별도 시각을 주지만, 공식 시간표
행에는 50분/75분 구분이 없어 교시 번호만으로 고를 수 없으므로 50분 수업 시각만
쓰고(학점 수와 교시 수가 일치), A/B 반교시 표기는 시각을 만들지 않는다.
https://www.seoultech.ac.kr/intro/uvstat/rules/ (조회 2026-10-24)
Dated future-faculty schedules must use their separately published clocks.
This helper alone does not establish exception dates or per-meeting classrooms.
"""
import re

DAYS = '월화수목금토일'


def regular_meetings(text):
    """Parse all published integer ranges, keeping disjoint same-day blocks.

    Classroom is intentionally blank: source aggregate room order is not a
    reliable association with the order of weekday groups. Keep the aggregate
    separately in sourceClassroom until an explicit association is available.
    """
    if not isinstance(text, str):
        raise ValueError('Invalid Seoultech schedule text')
    if not text.strip():
        return []
    groups = list(re.finditer(r'([월화수목금토일])\(([^()]*)\)', text))
    remainder = re.sub(r'[월화수목금토일]\([^()]*\)', '', text)
    if not groups or not re.fullmatch(r'[\s,]*', remainder):
        raise ValueError('Unrecognized Seoultech schedule')
    periods_by_day = {}
    for group in groups:
        day = DAYS.index(group[1]) + 1
        periods = periods_by_day.setdefault(day, set())
        for block in group[2].split(','):
            match = re.fullmatch(r'\s*(\d+)(?:\s*~\s*(\d+))?\s*', block)
            if not match:
                raise ValueError('Unverified Seoultech half-period clock')
            first, last = int(match[1]), int(match[2] or match[1])
            if not 0 <= first <= last <= 14:
                raise ValueError('Invalid Seoultech period range')
            added = set(range(first, last + 1))
            if periods.intersection(added):
                raise ValueError('Duplicate Seoultech period')
            periods.update(added)
    meetings = []
    for day, periods in sorted(periods_by_day.items()):
        for period in sorted(periods):
            start = 480 + period * 60
            previous = meetings[-1] if meetings else None
            if previous and previous['weekday'] == day and previous['endMinute'] + 10 == start:
                previous['endMinute'] = start + 50
            else:
                meetings.append({'weekday': day, 'startMinute': start,
                                 'endMinute': start + 50, 'classroom': ''})
    return meetings
